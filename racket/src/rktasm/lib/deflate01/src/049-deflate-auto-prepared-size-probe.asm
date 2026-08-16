// ============================================================
// 049-deflate-auto-prepared-size-probe.asm
// ============================================================
//
// Experimental fixed/stored-vs-dynamic selector that prepares dynamic Huffman
// metadata once, estimates the encoded size, and reuses that prepared metadata
// when the dynamic path wins.
//
// This intentionally preserves 045 and 048 as separate usable versions:
//   - 045 remains the direct dynamic-Huffman LZ77 encoder;
//   - 048 remains the size-probe selector that tail-calls 045;
//   - 049 tests the prepared-emission shape without changing either one.

.extern asmp_deflate_raw_auto
.extern asmp_deflate_dynamic_lz77_freq_count
.extern asmp_deflate_dynamic_litlen_huffman
.extern asmp_deflate_dynamic_distlen_huffman
.extern asmp_deflate_dynamic_canonical_codes
.extern asmp_deflate_dynamic_reverse_codes
.extern asmp_deflate_dynamic_code_length_rle
.extern asmp_deflate_dynamic_blfreq_count
.extern asmp_deflate_dynamic_bllen_huffman
.extern asmp_deflate_dynamic_code_counts

// Scratch layout, 16-byte aligned:
//   +0       ll_freq[286]        uint32_t    1144 bytes
//   +1144    ll_len[286]         uint8_t      286 bytes
//   +1430    ll_code[286]        uint16_t     572 bytes
//   +2002    ll_bit_code[286]    uint16_t     572 bytes
//   +2574    dist_freq[30]       uint32_t     120 bytes
//   +2694    dist_len[30]        uint8_t       30 bytes
//   +2724    dist_code[30]       uint16_t      60 bytes
//   +2784    dist_bit_code[30]   uint16_t      60 bytes
//   +2844    combined_len[316]   uint8_t      316 bytes
//   +3160    rle_events[316]     4 bytes     1264 bytes
//   +4424    bl_freq[19]         uint32_t      76 bytes
//   +4500    bl_len[19]          uint8_t       19 bytes
//   +4520    bl_code[19]         uint16_t      38 bytes
//   +4558    bl_bit_code[19]     uint16_t      38 bytes
//   +4596    canon_scratch                    128 bytes
//   +4728    event_count_slot    uint64_t       8 bytes
//   +4736    lcodes_slot         uint64_t       8 bytes
//   +4744    dcodes_slot         uint64_t       8 bytes
//   +4752    ll_huff_scratch                6864 bytes
//   +11616   bl_huff_scratch                 456 bytes
//   +12080   dist_huff_scratch              8304 bytes
//   +20384   lz77_scratch                 262144 bytes
//   total = 282528 bytes

.function dlh_flush8 (inout: x.out, x.bitbuf, w.bit_count)
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

.function dlh_write_raw (in: x.bits, w.nbits, inout: x.out, x.bitbuf, w.bit_count)
entry:
  cbz w.nbits, write_done
  lsl x.tmp, x.bits, x.bit_count
  orr x.bitbuf, x.bitbuf, x.tmp
  add w.bit_count, w.bit_count, w.nbits
  .inline dlh_flush8 (x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
write_done:
  .return
.end

.function dlh_write_symbol (
  in: x.len_ptr, x.bit_code_ptr, w.symbol,
  inout: x.out, x.bitbuf, w.bit_count
)
entry:
  add x.table_offset, x.symbol, x.symbol
  ldrh w.bits, [x.bit_code_ptr, x.table_offset]
  ldrb w.nbits, [x.len_ptr, w.symbol, uxtw]
  .inline dlh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .return
.end

.function dlh_write_len (
  in: x.ll_len_ptr, x.ll_bit_code_ptr, w.len,
  inout: x.out, x.bitbuf, w.bit_count
)
entry:
  mov w.extra_bits, #0
  mov w.extra_value, #0

  cmp w.len, #258
  b.eq len_258
  cmp w.len, #10
  b.hi len_extra

  add w.symbol, w.len, #254
  b write_len_symbol

len_258:
  mov w.symbol, #285
  b write_len_symbol

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
  lsl w.tmp, w.slot, w.extra_bits
  sub w.extra_value, w.local, w.tmp
  b write_len_symbol

write_len_symbol:
  .inline dlh_write_symbol (x.len_ptr=x.ll_len_ptr, x.bit_code_ptr=x.ll_bit_code_ptr, w.symbol=w.symbol, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  cbz w.extra_bits, len_done
  mov x.bits, x.extra_value
  mov w.nbits, w.extra_bits
  .inline dlh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

len_done:
  .return
.end

.function dlh_write_dist (
  in: x.dist_len_ptr, x.dist_bit_code_ptr, w.dist,
  inout: x.out, x.bitbuf, w.bit_count
)
entry:
  mov w.extra_bits, #0
  mov w.extra_value, #0

  sub w.n, w.dist, #1
  cmp w.n, #4
  b.hs dist_long

  mov w.symbol, w.n
  b write_dist_symbol

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

  add w.base_n, w.bit, #2
  lsl w.base_n, w.base_n, w.extra_bits
  sub w.extra_value, w.n, w.base_n
  b write_dist_symbol

write_dist_symbol:
  .inline dlh_write_symbol (x.len_ptr=x.dist_len_ptr, x.bit_code_ptr=x.dist_bit_code_ptr, w.symbol=w.symbol, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  cbz w.extra_bits, dist_done
  mov x.bits, x.extra_value
  mov w.nbits, w.extra_bits
  .inline dlh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

dist_done:
  .return
.end

.function dlh_insert_hash_pos (in: x.src, x.head, x.prev, x.pos)
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

.function dlh_search_chain (
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

.function dpsp_len_extra_bits (in: w.symbol, out: x.extra_bits)
entry:
  mov x.extra_bits, #0
  cmp w.symbol, #265
  b.lo len_extra_done
  cmp w.symbol, #269
  b.lo len_extra_1
  cmp w.symbol, #273
  b.lo len_extra_2
  cmp w.symbol, #277
  b.lo len_extra_3
  cmp w.symbol, #281
  b.lo len_extra_4
  cmp w.symbol, #285
  b.lo len_extra_5
  b len_extra_done

len_extra_1:
  mov x.extra_bits, #1
  b len_extra_done

len_extra_2:
  mov x.extra_bits, #2
  b len_extra_done

len_extra_3:
  mov x.extra_bits, #3
  b len_extra_done

len_extra_4:
  mov x.extra_bits, #4
  b len_extra_done

len_extra_5:
  mov x.extra_bits, #5

len_extra_done:
  .return
.end

.function dpsp_dist_extra_bits (in: w.symbol, out: x.extra_bits)
entry:
  mov x.extra_bits, #0
  cmp w.symbol, #4
  b.lo dist_extra_done
  ubfm w.half, w.symbol, #1, #31
  sub w.bits, w.half, #1
  mov x.extra_bits, #0
  add x.extra_bits, x.extra_bits, w.bits, uxtw #0

dist_extra_done:
  .return
.end

.function dpsp_fixed_ll_nbits (in: w.symbol, out: x.nbits)
entry:
  mov x.nbits, #8
  cmp w.symbol, #144
  b.lo fixed_ll_done
  cmp w.symbol, #256
  b.lo fixed_ll_9
  cmp w.symbol, #280
  b.lo fixed_ll_7
  b fixed_ll_done

fixed_ll_9:
  mov x.nbits, #9
  b fixed_ll_done

fixed_ll_7:
  mov x.nbits, #7

fixed_ll_done:
  .return
.end

.function dpsp_dynamic_ll_bits (
  in: x.freq_ptr, x.len_ptr,
  out: x.bits, w.status
)
entry:
  .save all
  mov x.bits, #0
  mov w.index, #0

dynamic_ll_loop:
  cmp w.index, #286
  b.hs dynamic_ll_ok

  ldr w.freq, [x.freq_ptr, w.index, uxtw #2]
  cbz w.freq, dynamic_ll_next

  ldrb w.len, [x.len_ptr, w.index, uxtw]
  cbz w.len, dynamic_ll_bad
  cmp w.len, #15
  b.hi dynamic_ll_bad

  mov x.freq64, #0
  add x.freq64, x.freq64, w.freq, uxtw #0
  mov x.nbits, #0
  add x.nbits, x.nbits, w.len, uxtw #0
  .inline dpsp_len_extra_bits (w.symbol=w.index, x.extra_bits=x.extra_bits)
  add x.nbits, x.nbits, x.extra_bits
  mul x.term, x.freq64, x.nbits
  add x.bits, x.bits, x.term

dynamic_ll_next:
  add w.index, w.index, #1
  b dynamic_ll_loop

dynamic_ll_ok:
  mov w.status, #0
  b dynamic_ll_done

dynamic_ll_bad:
  mov w.status, #3

dynamic_ll_done:
  .restore all
  ret
.end

.function dpsp_fixed_ll_bits (in: x.freq_ptr, out: x.bits)
entry:
  .save all
  mov x.bits, #0
  mov w.index, #0

fixed_ll_loop:
  cmp w.index, #286
  b.hs fixed_ll_done

  ldr w.freq, [x.freq_ptr, w.index, uxtw #2]
  cbz w.freq, fixed_ll_next

  mov x.freq64, #0
  add x.freq64, x.freq64, w.freq, uxtw #0
  .inline dpsp_fixed_ll_nbits (w.symbol=w.index, x.nbits=x.nbits)
  .inline dpsp_len_extra_bits (w.symbol=w.index, x.extra_bits=x.extra_bits)
  add x.nbits, x.nbits, x.extra_bits
  mul x.term, x.freq64, x.nbits
  add x.bits, x.bits, x.term

fixed_ll_next:
  add w.index, w.index, #1
  b fixed_ll_loop

fixed_ll_done:
  .restore all
  ret
.end

.function dpsp_dynamic_dist_bits (
  in: x.freq_ptr, x.len_ptr,
  out: x.bits, w.status
)
entry:
  .save all
  mov x.bits, #0
  mov w.index, #0

dynamic_dist_loop:
  cmp w.index, #30
  b.hs dynamic_dist_ok

  ldr w.freq, [x.freq_ptr, w.index, uxtw #2]
  cbz w.freq, dynamic_dist_next

  ldrb w.len, [x.len_ptr, w.index, uxtw]
  cbz w.len, dynamic_dist_bad
  cmp w.len, #15
  b.hi dynamic_dist_bad

  mov x.freq64, #0
  add x.freq64, x.freq64, w.freq, uxtw #0
  mov x.nbits, #0
  add x.nbits, x.nbits, w.len, uxtw #0
  .inline dpsp_dist_extra_bits (w.symbol=w.index, x.extra_bits=x.extra_bits)
  add x.nbits, x.nbits, x.extra_bits
  mul x.term, x.freq64, x.nbits
  add x.bits, x.bits, x.term

dynamic_dist_next:
  add w.index, w.index, #1
  b dynamic_dist_loop

dynamic_dist_ok:
  mov w.status, #0
  b dynamic_dist_done

dynamic_dist_bad:
  mov w.status, #3

dynamic_dist_done:
  .restore all
  ret
.end

.function dpsp_fixed_dist_bits (in: x.freq_ptr, out: x.bits)
entry:
  .save all
  mov x.bits, #0
  mov w.index, #0

fixed_dist_loop:
  cmp w.index, #30
  b.hs fixed_dist_done

  ldr w.freq, [x.freq_ptr, w.index, uxtw #2]
  cbz w.freq, fixed_dist_next

  mov x.freq64, #0
  add x.freq64, x.freq64, w.freq, uxtw #0
  .inline dpsp_dist_extra_bits (w.symbol=w.index, x.extra_bits=x.extra_bits)
  add x.nbits, x.extra_bits, #5
  mul x.term, x.freq64, x.nbits
  add x.bits, x.bits, x.term

fixed_dist_next:
  add w.index, w.index, #1
  b fixed_dist_loop

fixed_dist_done:
  .restore all
  ret
.end

.function dpsp_event_bits (
  in: x.event_ptr, x.event_count, x.bl_len_ptr,
  out: x.bits, w.status
)
entry:
  .save all
  mov x.bits, #0
  mov x.cursor, x.event_ptr
  mov x.remaining, x.event_count

event_bits_loop:
  cbz x.remaining, event_bits_ok

  ldrb w.symbol, [x.cursor]
  cmp w.symbol, #18
  b.hi event_bits_bad

  ldrb w.len, [x.bl_len_ptr, w.symbol, uxtw]
  cbz w.len, event_bits_bad
  cmp w.len, #7
  b.hi event_bits_bad

  ldrb w.extra_bits, [x.cursor, #2]
  cmp w.extra_bits, #7
  b.hi event_bits_bad

  mov x.nbits, #0
  add x.nbits, x.nbits, w.len, uxtw #0
  add x.nbits, x.nbits, w.extra_bits, uxtw #0
  add x.bits, x.bits, x.nbits

  add x.cursor, x.cursor, #4
  sub x.remaining, x.remaining, #1
  b event_bits_loop

event_bits_ok:
  mov w.status, #0
  b event_bits_done

event_bits_bad:
  mov w.status, #3

event_bits_done:
  .restore all
  ret
.end

.function dpsp_blcodes_count (in: x.bl_len_ptr, out: x.blcodes, w.status)
entry:
  .save all
  adrp x.order, :pg_hi21:deflate_auto_prepared_size_probe_bl_order
  add x.order, x.order, :lo12:deflate_auto_prepared_size_probe_bl_order

  mov x.index, #0
  mov x.blcodes, #4

blcodes_loop:
  cmp x.index, #19
  b.hs blcodes_ok

  ldrb w.symbol, [x.order, x.index]
  ldrb w.len, [x.bl_len_ptr, w.symbol, uxtw]
  cmp w.len, #7
  b.hi blcodes_bad
  cbz w.len, blcodes_next
  cmp x.index, #3
  b.ls blcodes_next
  add x.blcodes, x.index, #1

blcodes_next:
  add x.index, x.index, #1
  b blcodes_loop

blcodes_ok:
  mov w.status, #0
  b blcodes_done

blcodes_bad:
  mov w.status, #3

blcodes_done:
  .restore all
  ret
.end

.function dpsp_stored_bytes (in: x.src_len, out: x.bytes)
entry:
  mov x.remaining, x.src_len
  mov x.overhead, #0
  mov x.limit, #65535

stored_len_loop:
  add x.overhead, x.overhead, #5
  cmp x.remaining, x.limit
  b.ls stored_len_done
  sub x.remaining, x.remaining, x.limit
  b stored_len_loop

stored_len_done:
  add x.bytes, x.src_len, x.overhead
  .return
.end

.function dpsp_prepare_size_aarch64_asm (
  in: x.src, x.src_len, x.scratch, x.scratch_len,
  out: w.use_dynamic, w.status
)
entry:
  .save all
  mov fp, sp

  cmp x.src_len, #96
  b.lo model_choose_auto

  cbz x.scratch, model_choose_auto
  movz x.required_scratch, #0x4fa0
  movk x.required_scratch, #0x4, lsl #16
  cmp x.scratch_len, x.required_scratch
  b.lo model_choose_auto

  mov x.ll_freq_ptr, x.scratch
  add x.ll_len_ptr, x.scratch, #1144
  mov x.off, #2574
  add x.dist_freq_ptr, x.scratch, x.off
  mov x.off, #2694
  add x.dist_len_ptr, x.scratch, x.off
  mov x.off, #2844
  add x.combined_len_ptr, x.scratch, x.off
  mov x.off, #3160
  add x.event_ptr, x.scratch, x.off
  mov x.off, #4424
  add x.bl_freq_ptr, x.scratch, x.off
  mov x.off, #4500
  add x.bl_len_ptr, x.scratch, x.off
  mov x.off, #4728
  add x.event_count_ptr, x.scratch, x.off
  mov x.off, #4736
  add x.lcodes_ptr, x.scratch, x.off
  mov x.off, #4744
  add x.dcodes_ptr, x.scratch, x.off
  mov x.off, #4752
  add x.ll_huff_scratch_ptr, x.scratch, x.off
  mov x.off, #11616
  add x.bl_huff_scratch_ptr, x.scratch, x.off
  mov x.off, #12080
  add x.dist_huff_scratch_ptr, x.scratch, x.off
  mov x.off, #20384
  add x.lz77_scratch_ptr, x.scratch, x.off

  mov x0, x.src
  mov x1, x.src_len
  mov x2, x.ll_freq_ptr
  mov x3, #1144
  mov x4, x.dist_freq_ptr
  mov x5, #120
  mov x6, x.lz77_scratch_ptr
  mov x7, #262144
  bl asmp_deflate_dynamic_lz77_freq_count
  cbnz w0, model_choose_auto

  mov x0, x.ll_freq_ptr
  mov x1, #1144
  mov x2, x.ll_len_ptr
  mov x3, #286
  mov x4, x.ll_huff_scratch_ptr
  mov x5, #6864
  bl asmp_deflate_dynamic_litlen_huffman
  cbnz w0, model_choose_auto

  mov x0, x.dist_freq_ptr
  mov x1, #120
  mov x2, x.dist_len_ptr
  mov x3, #30
  mov x4, x.dist_huff_scratch_ptr
  mov x5, #8304
  bl asmp_deflate_dynamic_distlen_huffman
  cbnz w0, model_choose_auto

  mov x0, x.ll_len_ptr
  mov x1, #286
  mov x2, x.dist_len_ptr
  mov x3, #30
  mov x4, x.lcodes_ptr
  mov x5, x.dcodes_ptr
  bl asmp_deflate_dynamic_code_counts
  cbnz w0, model_choose_auto

  ldr x.lcodes, [x.lcodes_ptr]
  ldr x.dcodes, [x.dcodes_ptr]

  mov x.srcp, x.ll_len_ptr
  mov x.dstp, x.combined_len_ptr
  mov x.count, x.lcodes

copy_ll_len_loop:
  cbz x.count, copy_dist_len_start
  ldrb w.tmp, [x.srcp]
  strb w.tmp, [x.dstp]
  add x.srcp, x.srcp, #1
  add x.dstp, x.dstp, #1
  sub x.count, x.count, #1
  b copy_ll_len_loop

copy_dist_len_start:
  mov x.srcp, x.dist_len_ptr
  mov x.count, x.dcodes

copy_dist_len_loop:
  cbz x.count, rle_start
  ldrb w.tmp, [x.srcp]
  strb w.tmp, [x.dstp]
  add x.srcp, x.srcp, #1
  add x.dstp, x.dstp, #1
  sub x.count, x.count, #1
  b copy_dist_len_loop

rle_start:
  add x.combined_count, x.lcodes, x.dcodes
  mov x0, x.combined_len_ptr
  mov x1, x.combined_count
  mov x2, x.event_ptr
  mov x3, #316
  mov x4, x.event_count_ptr
  bl asmp_deflate_dynamic_code_length_rle
  cbnz w0, model_choose_auto

  ldr x.event_count, [x.event_count_ptr]

  mov x0, x.event_ptr
  mov x1, x.event_count
  mov x2, x.bl_freq_ptr
  mov x3, #76
  bl asmp_deflate_dynamic_blfreq_count
  cbnz w0, model_choose_auto

  mov x0, x.bl_freq_ptr
  mov x1, #76
  mov x2, x.bl_len_ptr
  mov x3, #19
  mov x4, x.bl_huff_scratch_ptr
  mov x5, #456
  bl asmp_deflate_dynamic_bllen_huffman
  cbnz w0, model_choose_auto

  .call dpsp_blcodes_count (
    x.bl_len_ptr=x.bl_len_ptr,
    x.blcodes=x.blcodes,
    w.status=w.status
  )
  cbnz w.status, model_choose_auto

  .call dpsp_event_bits (
    x.event_ptr=x.event_ptr,
    x.event_count=x.event_count,
    x.bl_len_ptr=x.bl_len_ptr,
    x.bits=x.event_bits,
    w.status=w.status
  )
  cbnz w.status, model_choose_auto

  .call dpsp_dynamic_ll_bits (
    x.freq_ptr=x.ll_freq_ptr,
    x.len_ptr=x.ll_len_ptr,
    x.bits=x.dynamic_ll_bits,
    w.status=w.status
  )
  cbnz w.status, model_choose_auto

  .call dpsp_dynamic_dist_bits (
    x.freq_ptr=x.dist_freq_ptr,
    x.len_ptr=x.dist_len_ptr,
    x.bits=x.dynamic_dist_bits,
    w.status=w.status
  )
  cbnz w.status, model_choose_auto

  mov x.dynamic_bits, #17
  add x.bl_header_bits, x.blcodes, x.blcodes
  add x.bl_header_bits, x.bl_header_bits, x.blcodes
  add x.dynamic_bits, x.dynamic_bits, x.bl_header_bits
  add x.dynamic_bits, x.dynamic_bits, x.event_bits
  add x.dynamic_bits, x.dynamic_bits, x.dynamic_ll_bits
  add x.dynamic_bits, x.dynamic_bits, x.dynamic_dist_bits
  add x.dynamic_bytes, x.dynamic_bits, #7
  ubfm x.dynamic_bytes, x.dynamic_bytes, #3, #63

  .call dpsp_fixed_ll_bits (
    x.freq_ptr=x.ll_freq_ptr,
    x.bits=x.fixed_bits
  )
  .call dpsp_fixed_dist_bits (
    x.freq_ptr=x.dist_freq_ptr,
    x.bits=x.fixed_dist_bits
  )
  add x.fixed_bits, x.fixed_bits, x.fixed_dist_bits
  add x.fixed_bits, x.fixed_bits, #3
  add x.fixed_bytes, x.fixed_bits, #7
  ubfm x.fixed_bytes, x.fixed_bytes, #3, #63

  .call dpsp_stored_bytes (
    x.src_len=x.src_len,
    x.bytes=x.stored_bytes
  )

  mov x.auto_bytes, x.stored_bytes
  cmp x.fixed_bytes, x.stored_bytes
  b.hs compare_sizes
  mov x.auto_bytes, x.fixed_bytes

compare_sizes:
  cmp x.dynamic_bytes, x.auto_bytes
  b.lo model_choose_dynamic

model_choose_auto:
  mov w.use_dynamic, #0
  mov w.status, #0
  b model_done

model_choose_dynamic:
  mov w.use_dynamic, #1
  mov w.status, #0
  b model_done

model_done:
  .restore all
  ret
.end

.function dpsp_emit_prepared_aarch64_asm (
  in: x.dst, x.src, x.src_len, x.scratch,
  out: x.written, w.status
)
entry:
  .save all
  mov x29, sp

  mov x.ll_freq_ptr, x.scratch
  add x.ll_len_ptr, x.scratch, #1144
  add x.ll_code_ptr, x.scratch, #1430
  add x.ll_bit_code_ptr, x.scratch, #2002
  mov x.off, #2574
  add x.dist_freq_ptr, x.scratch, x.off
  mov x.off, #2694
  add x.dist_len_ptr, x.scratch, x.off
  mov x.off, #2724
  add x.dist_code_ptr, x.scratch, x.off
  mov x.off, #2784
  add x.dist_bit_code_ptr, x.scratch, x.off
  mov x.off, #2844
  add x.combined_len_ptr, x.scratch, x.off
  mov x.off, #3160
  add x.event_ptr, x.scratch, x.off
  mov x.off, #4424
  add x.bl_freq_ptr, x.scratch, x.off
  mov x.off, #4500
  add x.bl_len_ptr, x.scratch, x.off
  mov x.off, #4520
  add x.bl_code_ptr, x.scratch, x.off
  mov x.off, #4558
  add x.bl_bit_code_ptr, x.scratch, x.off
  mov x.off, #4596
  add x.canon_scratch, x.scratch, x.off
  mov x.off, #4728
  add x.event_count_ptr, x.scratch, x.off
  mov x.off, #4736
  add x.lcodes_ptr, x.scratch, x.off
  mov x.off, #4744
  add x.dcodes_ptr, x.scratch, x.off
  mov x.off, #4752
  add x.ll_huff_scratch_ptr, x.scratch, x.off
  mov x.off, #11616
  add x.bl_huff_scratch_ptr, x.scratch, x.off
  mov x.off, #12080
  add x.dist_huff_scratch_ptr, x.scratch, x.off
  mov x.off, #20384
  add x.lz77_scratch_ptr, x.scratch, x.off
  mov x.table_bytes, #131072
  add x.prev_ptr, x.lz77_scratch_ptr, x.table_bytes

  ldr x.lcodes, [x.lcodes_ptr]
  ldr x.dcodes, [x.dcodes_ptr]
  ldr x.event_count, [x.event_count_ptr]

  mov x0, x.ll_len_ptr
  mov x1, #286
  mov x2, x.ll_code_ptr
  mov x3, #572
  mov x4, x.canon_scratch
  mov x5, #128
  bl asmp_deflate_dynamic_canonical_codes
  mov w.status, w0
  cbnz w.status, return_status

  mov x0, x.ll_len_ptr
  mov x1, #286
  mov x2, x.ll_code_ptr
  mov x3, #572
  mov x4, x.ll_bit_code_ptr
  mov x5, #572
  bl asmp_deflate_dynamic_reverse_codes
  mov w.status, w0
  cbnz w.status, return_status

  mov x0, x.dist_len_ptr
  mov x1, #30
  mov x2, x.dist_code_ptr
  mov x3, #60
  mov x4, x.canon_scratch
  mov x5, #128
  bl asmp_deflate_dynamic_canonical_codes
  mov w.status, w0
  cbnz w.status, return_status

  mov x0, x.dist_len_ptr
  mov x1, #30
  mov x2, x.dist_code_ptr
  mov x3, #60
  mov x4, x.dist_bit_code_ptr
  mov x5, #60
  bl asmp_deflate_dynamic_reverse_codes
  mov w.status, w0
  cbnz w.status, return_status

  mov x0, x.bl_len_ptr
  mov x1, #19
  mov x2, x.bl_code_ptr
  mov x3, #38
  mov x4, x.canon_scratch
  mov x5, #128
  bl asmp_deflate_dynamic_canonical_codes
  mov w.status, w0
  cbnz w.status, return_status

  mov x0, x.bl_len_ptr
  mov x1, #19
  mov x2, x.bl_code_ptr
  mov x3, #38
  mov x4, x.bl_bit_code_ptr
  mov x5, #38
  bl asmp_deflate_dynamic_reverse_codes
  mov w.status, w0
  cbnz w.status, return_status

  adrp x.order, :pg_hi21:deflate_auto_prepared_size_probe_bl_order
  add x.order, x.order, :lo12:deflate_auto_prepared_size_probe_bl_order

  mov x.index, #0
  mov x.blcodes, #4

scan_blcodes_loop:
  cmp x.index, #19
  b.hs write_header_start
  ldrb w.symbol, [x.order, x.index]
  ldrb w.len, [x.bl_len_ptr, w.symbol, uxtw]
  cmp w.len, #7
  b.hi bad_argument
  cbz w.len, scan_blcodes_next
  cmp x.index, #3
  b.ls scan_blcodes_next
  add x.blcodes, x.index, #1

scan_blcodes_next:
  add x.index, x.index, #1
  b scan_blcodes_loop

write_header_start:
  mov x.dst_base, x.dst
  mov x.out, x.dst
  mov x.bitbuf, #0
  mov w.bit_count, #0

  mov x.bits, #5
  mov w.nbits, #3
  .inline dlh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  sub x.bits, x.lcodes, #257
  mov w.nbits, #5
  .inline dlh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  sub x.bits, x.dcodes, #1
  mov w.nbits, #5
  .inline dlh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  sub x.bits, x.blcodes, #4
  mov w.nbits, #4
  .inline dlh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  mov x.index, #0

write_bl_lengths_loop:
  cmp x.index, x.blcodes
  b.hs write_events_start
  ldrb w.symbol, [x.order, x.index]
  ldrb w.bits, [x.bl_len_ptr, w.symbol, uxtw]
  mov w.nbits, #3
  .inline dlh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  add x.index, x.index, #1
  b write_bl_lengths_loop

write_events_start:
  mov x.event_cursor, x.event_ptr
  mov x.remaining, x.event_count

write_events_loop:
  cbz x.remaining, payload_start
  ldrb w.symbol, [x.event_cursor]
  cmp w.symbol, #18
  b.hi bad_argument

  ldrb w.nbits, [x.bl_len_ptr, w.symbol, uxtw]
  cbz w.nbits, bad_argument
  cmp w.nbits, #7
  b.hi bad_argument

  ldrh w.bits, [x.bl_bit_code_ptr, w.symbol, uxtw #1]
  .inline dlh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  ldrb w.extra_bits, [x.event_cursor, #2]
  cmp w.extra_bits, #7
  b.hi bad_argument
  cbz w.extra_bits, event_next

  ldrb w.bits, [x.event_cursor, #1]
  mov w.nbits, w.extra_bits
  .inline dlh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

event_next:
  add x.event_cursor, x.event_cursor, #4
  sub x.remaining, x.remaining, #1
  b write_events_loop

payload_start:
  mov x.clear_ptr, x.lz77_scratch_ptr
  mov x.clear_count, #8192

clear_head_loop:
  stp xzr, xzr, [x.clear_ptr]
  add x.clear_ptr, x.clear_ptr, #16
  subs x.clear_count, x.clear_count, #1
  b.ne clear_head_loop

  mov x.len, x.src_len
  mov x.pos, #0
  cmp x.len, #4
  b.lo tail_literals
  sub x.last_hash_pos, x.len, #4

main_loop:
  cmp x.pos, x.last_hash_pos
  b.hi tail_literals

  ldr w.word, [x.src, x.pos]
  eor w.hash, w.word, w.word, lsr #16
  ubfm w.hash, w.hash, #0, #14
  ldr w.candidate_plus1, [x.lz77_scratch_ptr, w.hash, uxtw #2]
  ubfm w.ring, w.pos, #0, #14
  str w.candidate_plus1, [x.prev_ptr, w.ring, uxtw #2]
  add w.store_pos, w.pos, #1
  str w.store_pos, [x.lz77_scratch_ptr, w.hash, uxtw #2]

  .inline dlh_search_chain (x.src=x.src, x.len=x.len, x.find_pos=x.pos, x.prev=x.prev_ptr, w.word=w.word, w.candidate_plus1=w.candidate_plus1, w.best_len=w.best_len, w.best_dist=w.best_dist)

  cmp w.best_len, #3
  b.hs emit_match

emit_literal:
  ldrb w.symbol, [x.src, x.pos]
  .inline dlh_write_symbol (x.len_ptr=x.ll_len_ptr, x.bit_code_ptr=x.ll_bit_code_ptr, w.symbol=w.symbol, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
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
  ldr w.lazy_candidate_plus1, [x.lz77_scratch_ptr, w.lazy_hash, uxtw #2]
  .inline dlh_search_chain (x.src=x.src, x.len=x.len, x.find_pos=x.lazy_pos, x.prev=x.prev_ptr, w.word=w.lazy_word, w.candidate_plus1=w.lazy_candidate_plus1, w.best_len=w.lazy_len, w.best_dist=w.lazy_dist)
  cmp w.lazy_len, w.best_len
  b.hi emit_literal

emit_current_match:
  .call dlh_write_len (x.ll_len_ptr=x.ll_len_ptr, x.ll_bit_code_ptr=x.ll_bit_code_ptr, w.len=w.best_len, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .call dlh_write_dist (x.dist_len_ptr=x.dist_len_ptr, x.dist_bit_code_ptr=x.dist_bit_code_ptr, w.dist=w.best_dist, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  add x.next_pos, x.pos, x.best_len
  add x.insert_pos, x.pos, #1

reinsert_skipped_loop:
  cmp x.insert_pos, x.next_pos
  b.hs reinsert_skipped_done
  cmp x.insert_pos, x.last_hash_pos
  b.hi reinsert_skipped_done
  .inline dlh_insert_hash_pos (x.src=x.src, x.head=x.lz77_scratch_ptr, x.prev=x.prev_ptr, x.pos=x.insert_pos)
  add x.insert_pos, x.insert_pos, #1
  b reinsert_skipped_loop

reinsert_skipped_done:
  mov x.pos, x.next_pos
  b main_loop

tail_literals:
  cmp x.pos, x.len
  b.hs finish_payload
  ldrb w.symbol, [x.src, x.pos]
  .inline dlh_write_symbol (x.len_ptr=x.ll_len_ptr, x.bit_code_ptr=x.ll_bit_code_ptr, w.symbol=w.symbol, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  add x.pos, x.pos, #1
  b tail_literals

finish_payload:
  mov w.symbol, #256
  .inline dlh_write_symbol (x.len_ptr=x.ll_len_ptr, x.bit_code_ptr=x.ll_bit_code_ptr, w.symbol=w.symbol, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  cbz w.bit_count, return_ok
  strb w.bitbuf, [x.out]
  add x.out, x.out, #1

return_ok:
  sub x.written, x.out, x.dst_base
  mov w.status, #0
  b return_done

bad_argument:
  mov w.status, #3
  b return_status

return_status:
  mov x.written, #0

return_done:
  .restore all
  ret
.end

.function asmp_deflate_raw_auto_dynamic_prepared_size_probe_bound export profile=c-aapcs64 (
  in: x.src_len,
  out: x.bound
)
entry:
  add x.bound, x.src_len, x.src_len
  mov x.extra, #4096
  add x.bound, x.bound, x.extra
  ret
.end

.function asmp_deflate_raw_auto_dynamic_prepared_size_probe_scratch_size export profile=c-aapcs64 (
  out: x.size
)
entry:
  movz x.size, #0x4fa0
  movk x.size, #0x4, lsl #16
  ret
.end

.function asmp_deflate_raw_auto_dynamic_prepared_size_probe_scratch_align export profile=c-aapcs64 (
  out: x.align
)
entry:
  mov x.align, #16
  ret
.end

.function asmp_deflate_raw_auto_dynamic_prepared_size_probe export profile=c-aapcs64 (
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
  movz x.required_scratch, #0x4fa0
  movk x.required_scratch, #0x4, lsl #16
  cmp x.scratch_len, x.required_scratch
  b.lo public_call_auto

  add x.required, x.src_len, x.src_len
  mov x.extra, #4096
  add x.required, x.required, x.extra
  cmp x.dst_cap, x.required
  b.lo public_call_auto

  .call dpsp_prepare_size_aarch64_asm (
    x.src=x.src,
    x.src_len=x.src_len,
    x.scratch=x.scratch,
    x.scratch_len=x.scratch_len,
    w.use_dynamic=w.use_dynamic,
    w.status=w.status
  )
  cbnz w.status, public_call_auto
  cbz w.use_dynamic, public_call_auto

  .call dpsp_emit_prepared_aarch64_asm (
    x.dst=x.dst,
    x.src=x.src,
    x.src_len=x.src_len,
    x.scratch=x.scratch,
    x.written=x.written,
    w.status=w.status
  )
  cbnz w.status, public_failed

  str x.written, [x.dst_len]
  mov w.status, #0
  b public_done

public_call_auto:
  mov x0, x.dst
  mov x1, x.dst_cap
  mov x2, x.dst_len
  mov x3, x.src
  mov x4, x.src_len
  mov x5, x.scratch
  mov x6, x.scratch_len
  bl asmp_deflate_raw_auto
  mov w.status, w0
  b public_done

public_failed:
  str xzr, [x.dst_len]
  b public_done

public_bad_argument:
  mov w.status, #3
  b public_done

public_done:
  .restore all
  ret
.end

.data
.p2align 3
deflate_auto_prepared_size_probe_bl_order:
  .byte 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
