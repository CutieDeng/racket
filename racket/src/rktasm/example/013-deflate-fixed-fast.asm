// ============================================================
// 013-deflate-fixed-fast.asm - GNU-ish AArch64 fixed-Huffman deflate core
// ============================================================
//
// This is the same bootstrap algorithm as 009-deflate-fixed-fast.d, written in
// the new GNU input syntax so the syntax and semantic gaps are easier to read.
//
// Prototype:
//   uint64_t deflate_fixed_fast_aarch64_asm(uint8_t *dst,
//                                           const uint8_t *src,
//                                           uint64_t len,
//                                           uint32_t *head);
//
// Contract:
//   x0 = output buffer, large enough for a fixed-Huffman deflate stream
//   x1 = input bytes
//   x2 = input length, expected to fit in 32 bits for the hash table
//   x3 = scratch head table, 32768 uint32_t entries
//   return x0 = bytes written
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
//   - Constants such as 32768, 8192, 258, and fixed-code thresholds are places
//     where compile-time definitions and static assertions would help.
//   - A future template form should declare inputs, outputs, inouts, clobbers,
//     compile-time constants, and assertions near the template header instead
//     of repeating bindings at every call site.

// ------------------------------------------------------------
// df_flush8
// Template formals:
//   inout x.out       = output cursor
//   inout x.bitbuf    = bit buffer, least-significant bits are pending
//   inout w.bit_count = pending bit count
// Clobbers:
//   flags
// ------------------------------------------------------------
.function df_flush8 (inout: x.out, x.bitbuf, w.bit_count)
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
// df_write_raw
// Template formals:
//   in    x.bits
//   in    w.nbits
//   inout x.out, x.bitbuf, w.bit_count
// ------------------------------------------------------------
.function df_write_raw (in: x.bits, w.nbits, inout: x.out, x.bitbuf, w.bit_count)
entry:
  lsl x.tmp, x.bits, x.bit_count
  orr x.bitbuf, x.bitbuf, x.tmp
  add w.bit_count, w.bit_count, w.nbits
  .inline df_flush8 (x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .return
.end

// ------------------------------------------------------------
// df_write_huff
// Template formals:
//   inout w.code
//   in    w.nbits
//   inout x.out, x.bitbuf, w.bit_count
// ------------------------------------------------------------
.function df_write_huff (inout: w.code, x.out, x.bitbuf, w.bit_count, in: w.nbits)
entry:
  rbit w.code, w.code
  mov w.tmp, #32
  sub w.tmp, w.tmp, w.nbits
  lsr w.code, w.code, w.tmp
  .inline df_write_raw (x.bits=x.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .return
.end

// ------------------------------------------------------------
// df_write_fixed_lit
// Template formals:
//   in    w.lit
//   inout x.out, x.bitbuf, w.bit_count
// ------------------------------------------------------------
.function df_write_fixed_lit (in: w.lit, inout: x.out, x.bitbuf, w.bit_count)
entry:
  cmp w.lit, #144
  b.hs lit_high

  // Literals 0..143: canonical code = 0x30 + literal, length = 8.
  add w.code, w.lit, #48
  mov w.nbits, #8
  .inline df_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .return

lit_high:
  // Literals 144..255: canonical code = 0x190 + literal - 144,
  // equivalently literal + 256, length = 9.
  add w.code, w.lit, #256
  mov w.nbits, #9
  .inline df_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .return
.end

// ------------------------------------------------------------
// df_write_eob
// Emits fixed-Huffman end-of-block code 256.
// Template formals:
//   inout x.out, x.bitbuf, w.bit_count
// ------------------------------------------------------------
.function df_write_eob (inout: x.out, x.bitbuf, w.bit_count)
entry:
  mov w.code, #0
  mov w.nbits, #7
  .inline df_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .return
.end

// ------------------------------------------------------------
// df_write_len
// Template formals:
//   in    w.len = match length, 3..258
//   inout x.out, x.bitbuf, w.bit_count
// ------------------------------------------------------------
.function df_write_len (in: w.len, inout: x.out, x.bitbuf, w.bit_count)
entry:
  cmp w.len, #258
  b.eq len_258

  cmp w.len, #10
  b.hi len_extra

  // Lengths 3..10 map to codes 257..264, no extra bits.
  add w.code, w.len, #254
  mov w.nbits, #7
  .inline df_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .return

len_258:
  // Length 258 uses code 285, no extra bits, 8-bit fixed code.
  mov w.code, #197
  mov w.nbits, #8
  .inline df_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
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
  .inline df_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  b len_extra_bits

len_code_8:
  sub w.code, w.code, #280
  add w.code, w.code, #192
  mov w.nbits, #8
  .inline df_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

len_extra_bits:
  cbz w.extra_bits, len_done
  .inline df_write_raw (x.bits=x.extra_value, w.nbits=w.extra_bits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
len_done:
  .return
.end

// ------------------------------------------------------------
// df_write_dist
// Template formals:
//   in    w.dist = match distance, 1..32768
//   inout x.out, x.bitbuf, w.bit_count
// ------------------------------------------------------------
.function df_write_dist (in: w.dist, inout: x.out, x.bitbuf, w.bit_count)
entry:
  // n = distance - 1
  sub w.n, w.dist, #1
  cmp w.n, #4
  b.hs dist_long

  // Distances 1..4 map directly to codes 0..3, no extra bits.
  mov w.code, w.n
  mov w.nbits, #5
  .inline df_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
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
  .inline df_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  cbz w.extra_bits, dist_done
  .inline df_write_raw (x.bits=x.extra_value, w.nbits=w.extra_bits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

dist_done:
  .return
.end

// ------------------------------------------------------------
// deflate_fixed_fast_aarch64_asm
// ------------------------------------------------------------
.asmp.function deflate_fixed_fast_aarch64_asm abi=aapcs64 export
entry:
  // ABI boundary: copy physical arguments into virtual working registers.
  mov x.dst_base, x0
  mov x.out, x0
  mov x.src, x1
  mov x.len, x2
  mov x.head, x3

  mov x.bitbuf, #0
  mov w.bit_count, #0
  mov x.pos, #0

  // Clear 32768 uint32_t hash buckets. Zero means "empty"; stored values are
  // positions plus one.
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

  // Deflate block header: BFINAL=1, BTYPE=01. Bits are raw LSB-first: 0b011.
  mov x.bits, #3
  mov w.nbits, #3
  .inline df_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

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

  // candidate = head[hash] - 1; then head[hash] = pos + 1.
  ldr w.candidate_plus1, [x.head, w.hash, uxtw #2]
  add w.store_pos, w.pos, #1
  str w.store_pos, [x.head, w.hash, uxtw #2]
  cbz w.candidate_plus1, emit_literal
  sub w.candidate, w.candidate_plus1, #1

  // distance = pos - candidate; reject candidates outside the 32 KiB window.
  sub w.dist, w.pos, w.candidate
  cbz w.dist, emit_literal
  cmp w.dist, #32768
  b.hi emit_literal

  // Check the first three bytes before entering the byte-by-byte extender.
  ldr w.candidate_word, [x.src, w.candidate, uxtw]
  eor w.prefix_diff, w.candidate_word, w.word
  ubfm w.prefix_diff, w.prefix_diff, #0, #23
  cbnz w.prefix_diff, emit_literal

  // Compute max_len = min(258, len - pos).
  sub x.max_len, x.len, x.pos
  mov x.tmp, #258
  cmp x.max_len, x.tmp
  b.ls max_len_ready
  mov x.max_len, #258
max_len_ready:

  // We already know the first three bytes match.
  mov w.match_len, #3
  add x.scan_pos, x.pos, #3
  add x.candidate_scan, x.candidate, #3

extend_match_loop:
  cmp x.match_len, x.max_len
  b.hs emit_match
  ldrb w.left_byte, [x.src, x.scan_pos]
  ldrb w.right_byte, [x.src, x.candidate_scan]
  cmp w.left_byte, w.right_byte
  b.ne emit_match
  add x.scan_pos, x.scan_pos, #1
  add x.candidate_scan, x.candidate_scan, #1
  add w.match_len, w.match_len, #1
  b extend_match_loop

emit_match:
  .inline df_write_len (w.len=w.match_len, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .inline df_write_dist (w.dist=w.dist, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  add x.pos, x.pos, x.match_len
  b main_loop

emit_literal:
  ldrb w.lit, [x.src, x.pos]
  .inline df_write_fixed_lit (w.lit=w.lit, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  add x.pos, x.pos, #1
  b main_loop

tail_literals:
  cmp x.pos, x.len
  b.hs finish_block
  ldrb w.lit, [x.src, x.pos]
  .inline df_write_fixed_lit (w.lit=w.lit, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  add x.pos, x.pos, #1
  b tail_literals

finish_block:
  .inline df_write_eob (x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  cbz w.bit_count, return_size
  strb w.bitbuf, [x.out]
  add x.out, x.out, #1

return_size:
  sub x0, x.out, x.dst_base
  ret
.asmp.end_function
