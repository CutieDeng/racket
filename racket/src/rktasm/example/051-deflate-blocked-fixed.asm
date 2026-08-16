// ============================================================
// 051-deflate-blocked-fixed.asm - blocked fixed-Huffman deflate
// ============================================================
//
// This is the first real split-block raw-deflate experiment. It keeps the
// fixed-Huffman LZ77 matcher from 019, but moves x.out/x.bitbuf/w.bit_count to
// the outer function so adjacent blocks share one bitstream. That avoids the
// invalid "compress chunks independently, clear BFINAL, then concatenate"
// shortcut, where single-stream byte padding would become stray block headers.
//
// Prototype:
//   int asmp_deflate_raw_blocked_fixed(uint8_t *dst, uint64_t dst_cap,
//                                      uint64_t *dst_len,
//                                      const uint8_t *src, uint64_t src_len,
//                                      void *scratch, uint64_t scratch_len);
//
// Syntax/semantic discussion anchors:
//   - Helper blocks use `.function`; call sites decide whether to expand them
//     with `.inline` or branch to them with `.call`.
//   - Helpers declare only their interface virtual registers. Undeclared
//     virtual registers inside a helper are local temporaries and are freshly
//     renamed at each inline site.
//   - Call sites must use named `.inline helper (formal=actual, ...)` bindings.
//     There are no positional arguments and no implicit same-name bindings.
//   - Physical registers should appear only at ABI boundaries or in explicitly
//     pinned low-level code. Template state such as x.out/x.bitbuf/w.bit_count
//     is virtual and visible to regalloc after inline expansion.
//   - Constants such as 32768, 8192, 258, chain depth, and fixed-code
//     thresholds are places where compile-time definitions and static
//     assertions would help.
//   - A future template form should declare inputs, outputs, inouts, clobbers,
//     compile-time constants, and assertions near the template header instead
//     of repeating bindings at every call site.

// ------------------------------------------------------------
// db_flush8
// Template formals:
//   inout x.out       = output cursor
//   inout x.bitbuf    = bit buffer, least-significant bits are pending
//   inout w.bit_count = pending bit count
// Clobbers:
//   flags
// ------------------------------------------------------------
.function db_flush8 (inout: x.out, x.bitbuf, w.bit_count)
entry:
flush_loop:
  cmp w.bit_count, #8
  b.lt flush_done
  strb w.bitbuf, [x.out]
  add x.out, x.out, #1
  ubfm x.bitbuf, x.bitbuf, #8, #63
  sub w.bit_count, w.bit_count, #8
  b flush_loop
flush_done:
  .return
.end

// ------------------------------------------------------------
// db_write_raw
// Template formals:
//   in    x.bits
//   in    w.nbits
//   inout x.out, x.bitbuf, w.bit_count
// ------------------------------------------------------------
.function db_write_raw (in: x.bits, w.nbits, inout: x.out, x.bitbuf, w.bit_count)
entry:
  lsl x.tmp, x.bits, x.bit_count
  orr x.bitbuf, x.bitbuf, x.tmp
  add w.bit_count, w.bit_count, w.nbits
  .inline db_flush8 (x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .return
.end

// ------------------------------------------------------------
// db_write_huff
// Template formals:
//   inout w.code
//   in    w.nbits
//   inout x.out, x.bitbuf, w.bit_count
// ------------------------------------------------------------
.function db_write_huff (inout: w.code, x.out, x.bitbuf, w.bit_count, in: w.nbits)
entry:
  rbit w.code, w.code
  mov w.tmp, #32
  sub w.tmp, w.tmp, w.nbits
  lsr w.code, w.code, w.tmp
  .inline db_write_raw (x.bits=x.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .return
.end

// ------------------------------------------------------------
// db_write_fixed_lit
// Template formals:
//   in    w.lit
//   inout x.out, x.bitbuf, w.bit_count
// ------------------------------------------------------------
.function db_write_fixed_lit (in: w.lit, inout: x.out, x.bitbuf, w.bit_count)
entry:
  cmp w.lit, #144
  b.hs lit_high

  // Literals 0..143: canonical code = 0x30 + literal, length = 8.
  add w.code, w.lit, #48
  mov w.nbits, #8
  .inline db_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .return

lit_high:
  // Literals 144..255: canonical code = 0x190 + literal - 144,
  // equivalently literal + 256, length = 9.
  add w.code, w.lit, #256
  mov w.nbits, #9
  .inline db_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .return
.end

// ------------------------------------------------------------
// db_write_eob
// Emits fixed-Huffman end-of-block code 256.
// Template formals:
//   inout x.out, x.bitbuf, w.bit_count
// ------------------------------------------------------------
.function db_write_eob (inout: x.out, x.bitbuf, w.bit_count)
entry:
  mov w.code, #0
  mov w.nbits, #7
  .inline db_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .return
.end

// ------------------------------------------------------------
// db_write_len
// Template formals:
//   in    w.len = match length, 3..258
//   inout x.out, x.bitbuf, w.bit_count
// ------------------------------------------------------------
.function db_write_len (in: w.len, inout: x.out, x.bitbuf, w.bit_count)
entry:
  cmp w.len, #258
  b.eq len_258

  cmp w.len, #10
  b.hi len_extra

  // Lengths 3..10 map to codes 257..264, no extra bits.
  add w.code, w.len, #254
  mov w.nbits, #7
  .inline db_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .return

len_258:
  // Length 258 uses code 285, no extra bits, 8-bit fixed code.
  mov w.code, #197
  mov w.nbits, #8
  .inline db_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .return

len_extra:
  // n = length - 11
  sub w.n, w.len, #11

  cmp w.n, #8
  b.lo len_e1
  cmp w.n, #24
  b.lo len_e2
  cmp w.n, #56
  b.lo len_e3
  cmp w.n, #120
  b.lo len_e4
  b len_e5

len_e1:
  mov w.extra_bits, #1
  mov w.first_code, #265
  mov w.threshold, #0
  b len_build

len_e2:
  mov w.extra_bits, #2
  mov w.first_code, #269
  mov w.threshold, #8
  b len_build

len_e3:
  mov w.extra_bits, #3
  mov w.first_code, #273
  mov w.threshold, #24
  b len_build

len_e4:
  mov w.extra_bits, #4
  mov w.first_code, #277
  mov w.threshold, #56
  b len_build

len_e5:
  mov w.extra_bits, #5
  mov w.first_code, #281
  mov w.threshold, #120

len_build:
  // local = n - threshold
  sub w.local, w.n, w.threshold
  // slot = local >> extra_bits
  lsr w.slot, w.local, w.extra_bits
  // code = first_code + slot
  add w.code, w.first_code, w.slot
  // extra_value = local - (slot << extra_bits)
  lsl w.tmp, w.slot, w.extra_bits
  sub w.extra_value, w.local, w.tmp

  // Fixed literal/length code: 257..279 are 7 bits; 280..287 are 8 bits.
  cmp w.code, #280
  b.hs len_code_8
  sub w.code, w.code, #256
  mov w.nbits, #7
  .inline db_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  b len_extra_bits

len_code_8:
  sub w.code, w.code, #280
  add w.code, w.code, #192
  mov w.nbits, #8
  .inline db_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

len_extra_bits:
  cbz w.extra_bits, len_done
  .inline db_write_raw (x.bits=x.extra_value, w.nbits=w.extra_bits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
len_done:
  .return
.end

// ------------------------------------------------------------
// db_write_dist
// Template formals:
//   in    w.dist = match distance, 1..32768
//   inout x.out, x.bitbuf, w.bit_count
// ------------------------------------------------------------
.function db_write_dist (in: w.dist, inout: x.out, x.bitbuf, w.bit_count)
entry:
  // n = distance - 1
  sub w.n, w.dist, #1
  cmp w.n, #4
  b.hs dist_long

  // Distances 1..4 map directly to codes 0..3, no extra bits.
  mov w.code, w.n
  mov w.nbits, #5
  .inline db_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .return

dist_long:
  // extra = floor(log2(n)) - 1
  clz w.extra_bits, w.n
  mov w.tmp, #31
  sub w.extra_bits, w.tmp, w.extra_bits
  sub w.extra_bits, w.extra_bits, #1

  // bit = (n >> extra_bits) & 1
  lsr w.bit, w.n, w.extra_bits
  and w.bit, w.bit, #1

  // code = 2 * extra_bits + 2 + bit
  add w.code, w.extra_bits, w.extra_bits
  add w.code, w.code, #2
  add w.code, w.code, w.bit

  // base_n = (2 + bit) << extra_bits
  add w.base_n, w.bit, #2
  lsl w.base_n, w.base_n, w.extra_bits
  // extra_value = n - base_n
  sub w.extra_value, w.n, w.base_n

  mov w.nbits, #5
  .inline db_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  cbz w.extra_bits, dist_done
  .inline db_write_raw (x.bits=x.extra_value, w.nbits=w.extra_bits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

dist_done:
  .return
.end

// ------------------------------------------------------------
// db_insert_hash_pos
// Inserts one source position into the hash chain.
// Template formals:
//   in x.src, x.head, x.prev
//   in x.pos = position with at least four readable bytes
// ------------------------------------------------------------
.function db_insert_hash_pos (in: x.src, x.head, x.prev, x.pos)
entry:
  ldr w.word, [x.src, x.pos]
  eor w.hash, w.word, w.word, lsr #16
  ubfm w.hash, w.hash, #0, #14
  ldr w.prev_plus1, [x.head, w.hash, uxtw #2]
  ubfm w.ring, w.pos, #0, #14
  str w.prev_plus1, [x.prev, w.ring, uxtw #2]
  add w.store_pos, w.pos, #1
  str w.store_pos, [x.head, w.hash, uxtw #2]
  .return
.end

// ------------------------------------------------------------
// db_search_chain
// Finds the best match for one already-hashed position.
// Template formals:
//   in  x.src, x.len, x.find_pos, x.prev
//   in  w.word = four bytes at find_pos
//   in  w.candidate_plus1 = first chain node, biased by one
//   out w.best_len, w.best_dist
// ------------------------------------------------------------
.function db_search_chain (
  in: x.src, x.len, x.find_pos, x.prev, w.word, w.candidate_plus1,
  out: w.best_len, w.best_dist
)
entry:
  mov w.scan_plus1, w.candidate_plus1
  mov w.best_len, #0
  mov w.best_dist, #0
  mov w.chain_left, #32

search_loop:
  cbz w.scan_plus1, search_done
  cbz w.chain_left, search_done

  sub w.candidate, w.scan_plus1, #1

  // distance = find_pos - candidate. Since chains are time-ordered, too far
  // means later candidates are too old as well.
  sub w.dist, w.find_pos, w.candidate
  cbz w.dist, next_candidate
  cmp w.dist, #32768
  b.hi search_done

  // Check the first three bytes before entering the byte-by-byte extender.
  ldr w.candidate_word, [x.src, w.candidate, uxtw]
  eor w.prefix_diff, w.candidate_word, w.word
  ubfm w.prefix_diff, w.prefix_diff, #0, #23
  cbnz w.prefix_diff, next_candidate

  // Compute max_len = min(258, len - find_pos).
  sub x.max_len, x.len, x.find_pos
  mov x.tmp, #258
  cmp x.max_len, x.tmp
  b.ls max_len_ready
  mov x.max_len, #258
max_len_ready:

  // We already know the first three bytes match.
  mov w.match_len, #3
  add x.scan_pos, x.find_pos, #3
  add x.candidate_scan, x.candidate, #3

extend_match_loop:
  cmp x.match_len, x.max_len
  b.hs score_match
  ldrb w.left_byte, [x.src, x.scan_pos]
  ldrb w.right_byte, [x.src, x.candidate_scan]
  cmp w.left_byte, w.right_byte
  b.ne score_match
  add x.scan_pos, x.scan_pos, #1
  add x.candidate_scan, x.candidate_scan, #1
  add w.match_len, w.match_len, #1
  b extend_match_loop

score_match:
  cmp w.best_len, w.match_len
  b.hs next_candidate
  mov w.best_len, w.match_len
  mov w.best_dist, w.dist
  cmp w.best_len, #258
  b.eq search_done

next_candidate:
  ubfm w.candidate_ring, w.candidate, #0, #14
  ldr w.next_plus1, [x.prev, w.candidate_ring, uxtw #2]
  sub w.chain_left, w.chain_left, #1
  cmp w.next_plus1, w.scan_plus1
  b.eq search_done
  mov w.scan_plus1, w.next_plus1
  b search_loop

search_done:
  .return
.end

// ------------------------------------------------------------
// deflate_blocked_fixed_block_aarch64_asm
// ------------------------------------------------------------
.function deflate_blocked_fixed_block_aarch64_asm (
  in: x.src, x.src_len, x.head, x.prev, w.bfinal,
  inout: x.out, x.bitbuf, w.bit_count
)
entry:
  .save all

  mov x.len, x.src_len
  mov x.pos, #0

  // Clear 32768 uint32_t hash buckets. prev entries are filled lazily when a
  // ring slot is inserted, so stale prev values are never read from an empty
  // head chain.
  //
  // Compile-time wish:
  //   .asmp.const HEAD_BUCKETS = 32768
  //   .asmp.const HEAD_CLEAR_PAIRS = HEAD_BUCKETS * 4 / 16
  //   .asmp.assert HEAD_CLEAR_PAIRS == 8192
  mov x.clear_ptr, x.head
  mov x.clear_count, #8192
clear_head_loop:
  stp xzr, xzr, [x.clear_ptr]
  add x.clear_ptr, x.clear_ptr, #16
  subs x.clear_count, x.clear_count, #1
  b.ne clear_head_loop

  // Deflate block header: BFINAL, BTYPE=01. Bits are raw LSB-first.
  mov x.bits, #2
  add x.bits, x.bits, w.bfinal, uxtw #0
  mov w.nbits, #3
  .inline db_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  // Need four readable input bytes for the hash load.
  cmp x.len, #4
  b.lo tail_literals
  sub x.last_hash_pos, x.len, #4

main_loop:
  cmp x.pos, x.last_hash_pos
  b.hi tail_literals

  // Hash the next 4 bytes. Unaligned word loads are legal on AArch64.
  ldr w.word, [x.src, x.pos]
  eor w.hash, w.word, w.word, lsr #16
  ubfm w.hash, w.hash, #0, #14

  // Insert current position into the hash chain:
  //   prev[pos & 32767] = head[hash]
  //   head[hash] = pos + 1
  // Zero means "empty", so stored positions are biased by one.
  ldr w.candidate_plus1, [x.head, w.hash, uxtw #2]
  ubfm w.ring, w.pos, #0, #14
  str w.candidate_plus1, [x.prev, w.ring, uxtw #2]
  add w.store_pos, w.pos, #1
  str w.store_pos, [x.head, w.hash, uxtw #2]

  .inline db_search_chain (x.src=x.src, x.len=x.len, x.find_pos=x.pos, x.prev=x.prev, w.word=w.word, w.candidate_plus1=w.candidate_plus1, w.best_len=w.best_len, w.best_dist=w.best_dist)

  cmp w.best_len, #3
  b.hs emit_match

emit_literal:
  ldrb w.lit, [x.src, x.pos]
  .inline db_write_fixed_lit (w.lit=w.lit, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  add x.pos, x.pos, #1
  b main_loop

emit_match:
  cmp w.best_len, #258
  b.eq emit_current_match
  add x.lazy_pos, x.pos, #1
  cmp x.lazy_pos, x.last_hash_pos
  b.hi emit_current_match

  ldr w.lazy_word, [x.src, x.lazy_pos]
  eor w.lazy_hash, w.lazy_word, w.lazy_word, lsr #16
  ubfm w.lazy_hash, w.lazy_hash, #0, #14
  ldr w.lazy_candidate_plus1, [x.head, w.lazy_hash, uxtw #2]
  .inline db_search_chain (x.src=x.src, x.len=x.len, x.find_pos=x.lazy_pos, x.prev=x.prev, w.word=w.lazy_word, w.candidate_plus1=w.lazy_candidate_plus1, w.best_len=w.lazy_len, w.best_dist=w.lazy_dist)
  cmp w.lazy_len, w.best_len
  b.hi emit_literal

emit_current_match:
  .inline db_write_len (w.len=w.best_len, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .inline db_write_dist (w.dist=w.best_dist, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  add x.next_pos, x.pos, x.best_len
  add x.insert_pos, x.pos, #1

reinsert_skipped_loop:
  cmp x.insert_pos, x.next_pos
  b.hs reinsert_skipped_done
  cmp x.insert_pos, x.last_hash_pos
  b.hi reinsert_skipped_done
  .inline db_insert_hash_pos (x.src=x.src, x.head=x.head, x.prev=x.prev, x.pos=x.insert_pos)
  add x.insert_pos, x.insert_pos, #1
  b reinsert_skipped_loop

reinsert_skipped_done:
  mov x.pos, x.next_pos
  b main_loop

tail_literals:
  cmp x.pos, x.len
  b.hs finish_block
  ldrb w.lit, [x.src, x.pos]
  .inline db_write_fixed_lit (w.lit=w.lit, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  add x.pos, x.pos, #1
  b tail_literals

finish_block:
  .inline db_write_eob (x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  .restore all
  ret
.end

.function asmp_deflate_raw_blocked_fixed_bound export profile=c-aapcs64 (
  in: x.src_len,
  out: x.bound
)
entry:
  ubfm x.extra, x.src_len, #3, #63
  add x.bound, x.src_len, x.extra
  add x.bound, x.bound, #64
  mov x.chunk_bias, #32767
  add x.chunks, x.src_len, x.chunk_bias
  ubfm x.chunks, x.chunks, #15, #63
  cbnz x.chunks, bound_chunks_ready
  mov x.chunks, #1
bound_chunks_ready:
  add x.bound, x.bound, x.chunks, lsl #3
  ret
.end

.function asmp_deflate_raw_blocked_fixed_scratch_size export profile=c-aapcs64 (
  out: x.size
)
entry:
  mov x.size, #262144
  ret
.end

.function asmp_deflate_raw_blocked_fixed_scratch_align export profile=c-aapcs64 (
  out: x.align
)
entry:
  mov x.align, #16
  ret
.end

.function asmp_deflate_raw_blocked_fixed export profile=c-aapcs64 (
  in: x.dst, x.dst_cap, x.dst_len, x.src, x.src_len, x.scratch, x.scratch_len,
  out: w.status
)
entry:
  .save all

  cbz x.dst, public_bad_argument
  cbz x.dst_len, public_bad_argument
  cbz x.scratch, public_bad_argument
  cbz x.src_len, public_src_ok
  cbz x.src, public_bad_argument

public_src_ok:
  cmp x.scratch_len, #262144
  b.lo public_scratch_too_small

  ubfm x.required, x.src_len, #3, #63
  add x.required, x.src_len, x.required
  add x.required, x.required, #64
  mov x.chunk_bias, #32767
  add x.chunks, x.src_len, x.chunk_bias
  ubfm x.chunks, x.chunks, #15, #63
  cbnz x.chunks, required_chunks_ready
  mov x.chunks, #1
required_chunks_ready:
  add x.required, x.required, x.chunks, lsl #3
  cmp x.dst_cap, x.required
  b.lo public_dst_too_small

  mov x.dst_base, x.dst
  mov x.out, x.dst
  mov x.cursor, x.src
  mov x.remaining, x.src_len
  mov x.bitbuf, #0
  mov w.bit_count, #0
  mov x.table_bytes, #131072
  add x.prev, x.scratch, x.table_bytes

  cbz x.remaining, emit_empty_final

block_loop:
  mov x.chunk_limit, #32768
  cmp x.remaining, x.chunk_limit
  b.hi emit_nonfinal_block

  mov x.chunk_len, x.remaining
  mov w.bfinal, #1
  b emit_block

emit_nonfinal_block:
  mov x.chunk_len, x.chunk_limit
  mov w.bfinal, #0
  b emit_block

emit_block:
  .call deflate_blocked_fixed_block_aarch64_asm (
    x.src=x.cursor,
    x.src_len=x.chunk_len,
    x.head=x.scratch,
    x.prev=x.prev,
    w.bfinal=w.bfinal,
    x.out=x.out,
    x.bitbuf=x.bitbuf,
    w.bit_count=w.bit_count
  )

  add x.cursor, x.cursor, x.chunk_len
  sub x.remaining, x.remaining, x.chunk_len
  cbnz x.remaining, block_loop
  b flush_final_bits

emit_empty_final:
  mov x.chunk_len, #0
  mov w.bfinal, #1
  .call deflate_blocked_fixed_block_aarch64_asm (
    x.src=x.cursor,
    x.src_len=x.chunk_len,
    x.head=x.scratch,
    x.prev=x.prev,
    w.bfinal=w.bfinal,
    x.out=x.out,
    x.bitbuf=x.bitbuf,
    w.bit_count=w.bit_count
  )
  b flush_final_bits

flush_final_bits:
  cbz w.bit_count, write_public_len
  strb w.bitbuf, [x.out]
  add x.out, x.out, #1

write_public_len:
  sub x.written, x.out, x.dst_base
  str x.written, [x.dst_len]
  mov w.status, #0
  b public_done

public_dst_too_small:
  str xzr, [x.dst_len]
  mov w.status, #1
  b public_done

public_scratch_too_small:
  str xzr, [x.dst_len]
  mov w.status, #2
  b public_done

public_bad_argument:
  mov w.status, #3
  b public_done

public_done:
  .restore all
  ret
.end
