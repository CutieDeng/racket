// ============================================================
// 048-deflate-auto-size-probe.asm
// ============================================================
//
// Experimental raw-deflate selector that models the encoded byte size before
// choosing between the stable fixed/stored auto wrapper and the 045 dynamic
// Huffman LZ77 block.
//
// Unlike 046/047, this probe estimates the actual dynamic header and payload
// bit cost from generated code lengths. It remains a versioned experimental
// entry; the stable asmp_deflate_raw_auto ABI is unchanged.

.extern asmp_deflate_raw_auto
.extern asmp_deflate_raw_dynamic_lz77_huffman
.extern asmp_deflate_dynamic_lz77_freq_count
.extern asmp_deflate_dynamic_litlen_huffman
.extern asmp_deflate_dynamic_distlen_huffman
.extern asmp_deflate_dynamic_code_counts
.extern asmp_deflate_dynamic_code_length_rle
.extern asmp_deflate_dynamic_blfreq_count
.extern asmp_deflate_dynamic_bllen_huffman

// Scratch layout matches 045 exactly:
//   +0       ll_freq[286]        uint32_t    1144 bytes
//   +1144    ll_len[286]         uint8_t      286 bytes
//   +2574    dist_freq[30]       uint32_t     120 bytes
//   +2694    dist_len[30]        uint8_t       30 bytes
//   +2844    combined_len[316]   uint8_t      316 bytes
//   +3160    rle_events[316]     4 bytes     1264 bytes
//   +4424    bl_freq[19]         uint32_t      76 bytes
//   +4500    bl_len[19]          uint8_t       19 bytes
//   +4728    event_count_slot    uint64_t       8 bytes
//   +4736    lcodes_slot         uint64_t       8 bytes
//   +4744    dcodes_slot         uint64_t       8 bytes
//   +4752    ll_huff_scratch                6864 bytes
//   +11616   bl_huff_scratch                 456 bytes
//   +12080   dist_huff_scratch              8304 bytes
//   +20384   lz77_scratch                 262144 bytes
//   total = 282528 bytes

.function dsp_len_extra_bits (in: w.symbol, out: x.extra_bits)
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

.function dsp_dist_extra_bits (in: w.symbol, out: x.extra_bits)
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

.function dsp_fixed_ll_nbits (in: w.symbol, out: x.nbits)
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

.function dsp_dynamic_ll_bits (
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
  .inline dsp_len_extra_bits (w.symbol=w.index, x.extra_bits=x.extra_bits)
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

.function dsp_fixed_ll_bits (in: x.freq_ptr, out: x.bits)
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
  .inline dsp_fixed_ll_nbits (w.symbol=w.index, x.nbits=x.nbits)
  .inline dsp_len_extra_bits (w.symbol=w.index, x.extra_bits=x.extra_bits)
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

.function dsp_dynamic_dist_bits (
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
  .inline dsp_dist_extra_bits (w.symbol=w.index, x.extra_bits=x.extra_bits)
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

.function dsp_fixed_dist_bits (in: x.freq_ptr, out: x.bits)
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
  .inline dsp_dist_extra_bits (w.symbol=w.index, x.extra_bits=x.extra_bits)
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

.function dsp_event_bits (
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

.function dsp_blcodes_count (in: x.bl_len_ptr, out: x.blcodes, w.status)
entry:
  .save all
  adrp x.order, :pg_hi21:deflate_auto_size_probe_bl_order
  add x.order, x.order, :lo12:deflate_auto_size_probe_bl_order

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

.function dsp_stored_bytes (in: x.src_len, out: x.bytes)
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

.function asmp_deflate_raw_auto_dynamic_size_probe_bound export profile=c-aapcs64 (
  in: x.src_len,
  out: x.bound
)
entry:
  add x.bound, x.src_len, x.src_len
  mov x.extra, #4096
  add x.bound, x.bound, x.extra
  ret
.end

.function asmp_deflate_raw_auto_dynamic_size_probe_scratch_size export profile=c-aapcs64 (
  out: x.size
)
entry:
  movz x.size, #0x4fa0
  movk x.size, #0x4, lsl #16
  ret
.end

.function asmp_deflate_raw_auto_dynamic_size_probe_scratch_align export profile=c-aapcs64 (
  out: x.align
)
entry:
  mov x.align, #16
  ret
.end

.function dsp_should_use_dynamic_size (
  in: x.src, x.src_len, x.scratch, x.scratch_len,
  out: w.use_dynamic
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

  .call dsp_blcodes_count (
    x.bl_len_ptr=x.bl_len_ptr,
    x.blcodes=x.blcodes,
    w.status=w.status
  )
  cbnz w.status, model_choose_auto

  .call dsp_event_bits (
    x.event_ptr=x.event_ptr,
    x.event_count=x.event_count,
    x.bl_len_ptr=x.bl_len_ptr,
    x.bits=x.event_bits,
    w.status=w.status
  )
  cbnz w.status, model_choose_auto

  .call dsp_dynamic_ll_bits (
    x.freq_ptr=x.ll_freq_ptr,
    x.len_ptr=x.ll_len_ptr,
    x.bits=x.dynamic_ll_bits,
    w.status=w.status
  )
  cbnz w.status, model_choose_auto

  .call dsp_dynamic_dist_bits (
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

  .call dsp_fixed_ll_bits (
    x.freq_ptr=x.ll_freq_ptr,
    x.bits=x.fixed_bits
  )
  .call dsp_fixed_dist_bits (
    x.freq_ptr=x.dist_freq_ptr,
    x.bits=x.fixed_dist_bits
  )
  add x.fixed_bits, x.fixed_bits, x.fixed_dist_bits
  add x.fixed_bits, x.fixed_bits, #3
  add x.fixed_bytes, x.fixed_bits, #7
  ubfm x.fixed_bytes, x.fixed_bytes, #3, #63

  .call dsp_stored_bytes (
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
  b model_done

model_choose_dynamic:
  mov w.use_dynamic, #1
  b model_done

model_done:
  .restore all
  ret
.end

.function asmp_deflate_raw_auto_dynamic_size_probe export profile=c-aapcs64 (
  in: x.dst, x.dst_cap, x.dst_len, x.src, x.src_len, x.scratch, x.scratch_len,
  out: w.status
)
entry:
  .save x0, x1, x2, x3, x4, x5, x6, x7, fp, lr

  .call dsp_should_use_dynamic_size (
    x.src=x.src,
    x.src_len=x.src_len,
    x.scratch=x.scratch,
    x.scratch_len=x.scratch_len,
    w.use_dynamic=w.use_dynamic
  )
  cbnz w.use_dynamic, choose_dynamic

choose_auto:
  .restore x0, x1, x2, x3, x4, x5, x6, x7, fp, lr
  b asmp_deflate_raw_auto

choose_dynamic:
  .restore x0, x1, x2, x3, x4, x5, x6, x7, fp, lr
  b asmp_deflate_raw_dynamic_lz77_huffman
.end

.data
.p2align 3
deflate_auto_size_probe_bl_order:
  .byte 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
