// ============================================================
// 043-deflate-dynamic-lz77-freq.asm - LZ77 token frequency helper
// ============================================================
//
// Counts dynamic-Huffman literal/length and distance frequencies from the
// same bounded hash-chain parser policy used by 019:
//   - 32 KiB window;
//   - 15-bit hash head table plus prev ring;
//   - 32-node chain search;
//   - one-byte lazy lookahead;
//   - skipped-byte reinsertion after emitting a match.
//
// This helper does not emit a deflate stream. It prepares the native frequency
// input needed before wiring LZ77 matches into the dynamic-Huffman payload.
//
// Public API:
//   uint64_t asmp_deflate_dynamic_lz77_freq_scratch_size(void);
//   uint64_t asmp_deflate_dynamic_lz77_freq_scratch_align(void);
//   int asmp_deflate_dynamic_lz77_freq_count(const uint8_t *src,
//                                           uint64_t src_len,
//                                           void *ll_freq_ptr,
//                                           uint64_t ll_freq_len,
//                                           void *dist_freq_ptr,
//                                           uint64_t dist_freq_len,
//                                           void *scratch_ptr,
//                                           uint64_t scratch_len);
//
// Scratch layout, 16-byte aligned:
//   +0       head[32768]  uint32_t  131072 bytes
//   +131072  prev[32768]  uint32_t  131072 bytes
//   total = 262144 bytes

.function dlf_count_ll_symbol (in: x.ll_freq, w.symbol)
entry:
  ldr w.freq, [x.ll_freq, w.symbol, uxtw #2]
  add w.freq, w.freq, #1
  str w.freq, [x.ll_freq, w.symbol, uxtw #2]
  .return
.end

.function dlf_count_len (in: x.ll_freq, w.len)
entry:
  cmp w.len, #258
  b.eq len_258

  cmp w.len, #10
  b.hi len_extra

  add w.symbol, w.len, #254
  .inline dlf_count_ll_symbol (x.ll_freq=x.ll_freq, w.symbol=w.symbol)
  b len_done

len_258:
  mov w.symbol, #285
  .inline dlf_count_ll_symbol (x.ll_freq=x.ll_freq, w.symbol=w.symbol)
  b len_done

len_extra:
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
  b len_build

len_build:
  sub w.local, w.n, w.threshold
  lsr w.slot, w.local, w.extra_bits
  add w.symbol, w.first_code, w.slot
  .inline dlf_count_ll_symbol (x.ll_freq=x.ll_freq, w.symbol=w.symbol)
  b len_done

len_done:
  .return
.end

.function dlf_count_dist_symbol (in: x.dist_freq, w.symbol)
entry:
  ldr w.freq, [x.dist_freq, w.symbol, uxtw #2]
  add w.freq, w.freq, #1
  str w.freq, [x.dist_freq, w.symbol, uxtw #2]
  .return
.end

.function dlf_count_dist (in: x.dist_freq, w.dist)
entry:
  sub w.n, w.dist, #1
  cmp w.n, #4
  b.hs dist_long

  mov w.symbol, w.n
  .inline dlf_count_dist_symbol (x.dist_freq=x.dist_freq, w.symbol=w.symbol)
  b dist_done

dist_long:
  clz w.extra_bits, w.n
  mov w.tmp, #31
  sub w.extra_bits, w.tmp, w.extra_bits
  sub w.extra_bits, w.extra_bits, #1

  lsr w.bit, w.n, w.extra_bits
  and w.bit, w.bit, #1

  add w.symbol, w.extra_bits, w.extra_bits
  add w.symbol, w.symbol, #2
  add w.symbol, w.symbol, w.bit
  .inline dlf_count_dist_symbol (x.dist_freq=x.dist_freq, w.symbol=w.symbol)
  b dist_done

dist_done:
  .return
.end

.function dlf_insert_hash_pos (in: x.src, x.head, x.prev, x.pos)
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

.function dlf_search_chain (
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
  sub w.dist, w.find_pos, w.candidate
  cbz w.dist, next_candidate
  cmp w.dist, #32768
  b.hi search_done

  ldr w.candidate_word, [x.src, w.candidate, uxtw]
  eor w.prefix_diff, w.candidate_word, w.word
  ubfm w.prefix_diff, w.prefix_diff, #0, #23
  cbnz w.prefix_diff, next_candidate

  sub x.max_len, x.len, x.find_pos
  mov x.tmp, #258
  cmp x.max_len, x.tmp
  b.ls max_len_ready
  mov x.max_len, #258

max_len_ready:
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

.function deflate_dynamic_lz77_freq_count_aarch64_asm export profile=c-aapcs64 visibility=hidden no-header (
  in: x.src, x.src_len, x.ll_freq, x.dist_freq, x.head, x.prev,
  out: x.token_count
)
entry:
  .save all

  mov x.ptr, x.ll_freq
  mov x.remaining, #286
  mov w.zero, #0

clear_ll_loop:
  str w.zero, [x.ptr]
  add x.ptr, x.ptr, #4
  subs x.remaining, x.remaining, #1
  b.ne clear_ll_loop

  mov x.ptr, x.dist_freq
  mov x.remaining, #30

clear_dist_loop:
  str w.zero, [x.ptr]
  add x.ptr, x.ptr, #4
  subs x.remaining, x.remaining, #1
  b.ne clear_dist_loop

  mov x.clear_ptr, x.head
  mov x.clear_count, #8192

clear_head_loop:
  stp xzr, xzr, [x.clear_ptr]
  add x.clear_ptr, x.clear_ptr, #16
  subs x.clear_count, x.clear_count, #1
  b.ne clear_head_loop

  mov x.len, x.src_len
  mov x.pos, #0
  mov x.token_count, #0

  cmp x.len, #4
  b.lo tail_literals
  sub x.last_hash_pos, x.len, #4

main_loop:
  cmp x.pos, x.last_hash_pos
  b.hi tail_literals

  ldr w.word, [x.src, x.pos]
  eor w.hash, w.word, w.word, lsr #16
  ubfm w.hash, w.hash, #0, #14

  ldr w.candidate_plus1, [x.head, w.hash, uxtw #2]
  ubfm w.ring, w.pos, #0, #14
  str w.candidate_plus1, [x.prev, w.ring, uxtw #2]
  add w.store_pos, w.pos, #1
  str w.store_pos, [x.head, w.hash, uxtw #2]

  .inline dlf_search_chain (x.src=x.src, x.len=x.len, x.find_pos=x.pos, x.prev=x.prev, w.word=w.word, w.candidate_plus1=w.candidate_plus1, w.best_len=w.best_len, w.best_dist=w.best_dist)

  cmp w.best_len, #3
  b.hs count_match

count_literal:
  ldrb w.symbol, [x.src, x.pos]
  .inline dlf_count_ll_symbol (x.ll_freq=x.ll_freq, w.symbol=w.symbol)
  add x.token_count, x.token_count, #1
  add x.pos, x.pos, #1
  b main_loop

count_match:
  cmp w.best_len, #258
  b.eq count_current_match
  add x.lazy_pos, x.pos, #1
  cmp x.lazy_pos, x.last_hash_pos
  b.hi count_current_match

  ldr w.lazy_word, [x.src, x.lazy_pos]
  eor w.lazy_hash, w.lazy_word, w.lazy_word, lsr #16
  ubfm w.lazy_hash, w.lazy_hash, #0, #14
  ldr w.lazy_candidate_plus1, [x.head, w.lazy_hash, uxtw #2]
  .inline dlf_search_chain (x.src=x.src, x.len=x.len, x.find_pos=x.lazy_pos, x.prev=x.prev, w.word=w.lazy_word, w.candidate_plus1=w.lazy_candidate_plus1, w.best_len=w.lazy_len, w.best_dist=w.lazy_dist)
  cmp w.lazy_len, w.best_len
  b.hi count_literal

count_current_match:
  .call dlf_count_len (x.ll_freq=x.ll_freq, w.len=w.best_len)
  .call dlf_count_dist (x.dist_freq=x.dist_freq, w.dist=w.best_dist)
  add x.token_count, x.token_count, #1
  add x.next_pos, x.pos, x.best_len
  add x.insert_pos, x.pos, #1

reinsert_skipped_loop:
  cmp x.insert_pos, x.next_pos
  b.hs reinsert_skipped_done
  cmp x.insert_pos, x.last_hash_pos
  b.hi reinsert_skipped_done
  .inline dlf_insert_hash_pos (x.src=x.src, x.head=x.head, x.prev=x.prev, x.pos=x.insert_pos)
  add x.insert_pos, x.insert_pos, #1
  b reinsert_skipped_loop

reinsert_skipped_done:
  mov x.pos, x.next_pos
  b main_loop

tail_literals:
  cmp x.pos, x.len
  b.hs finish_counts
  ldrb w.symbol, [x.src, x.pos]
  .inline dlf_count_ll_symbol (x.ll_freq=x.ll_freq, w.symbol=w.symbol)
  add x.token_count, x.token_count, #1
  add x.pos, x.pos, #1
  b tail_literals

finish_counts:
  mov w.symbol, #256
  .inline dlf_count_ll_symbol (x.ll_freq=x.ll_freq, w.symbol=w.symbol)
  add x.token_count, x.token_count, #1

  .restore all
  ret
.end

.function asmp_deflate_dynamic_lz77_freq_scratch_size export profile=c-aapcs64 (
  out: x.size
)
entry:
  mov x.size, #262144
  ret
.end

.function asmp_deflate_dynamic_lz77_freq_scratch_align export profile=c-aapcs64 (
  out: x.align
)
entry:
  mov x.align, #16
  ret
.end

.function asmp_deflate_dynamic_lz77_freq_count export profile=c-aapcs64 (
  in: x.src, x.src_len, x.ll_freq_ptr, x.ll_freq_len,
      x.dist_freq_ptr, x.dist_freq_len, x.scratch, x.scratch_len,
  out: w.status
)
entry:
  .save all

  cbz x.ll_freq_ptr, bad_argument
  cbz x.dist_freq_ptr, bad_argument
  cbz x.scratch, bad_argument
  cbz x.src_len, src_ok
  cbz x.src, bad_argument

src_ok:
  mov x.required, #1144
  cmp x.ll_freq_len, x.required
  b.lo scratch_too_small
  mov x.required, #120
  cmp x.dist_freq_len, x.required
  b.lo scratch_too_small
  mov x.required, #262144
  cmp x.scratch_len, x.required
  b.lo scratch_too_small

  mov x.table_bytes, #131072
  add x.prev, x.scratch, x.table_bytes
  .call deflate_dynamic_lz77_freq_count_aarch64_asm (
    x.src=x.src,
    x.src_len=x.src_len,
    x.ll_freq=x.ll_freq_ptr,
    x.dist_freq=x.dist_freq_ptr,
    x.head=x.scratch,
    x.prev=x.prev,
    x.token_count=x.token_count
  )

  mov w.status, #0
  b done

scratch_too_small:
  mov w.status, #2
  b done

bad_argument:
  mov w.status, #3
  b done

done:
  .restore all
  ret
.end
