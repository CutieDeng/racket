// ============================================================
// 042-deflate-dynamic-compact-dual-huffman-litonly.asm
// ============================================================
//
// Literal-only dynamic-Huffman pipeline with frequency-driven LL and BL trees:
//   - LL lengths from 039;
//   - BL lengths from 041;
//   - compact code-length RLE header from 031/032;
//   - trimmed HLIT/HDIST counts from 037.
//
// The payload is still literal-only.  This version removes the remaining
// balanced-tree scaffold from the dynamic header path.

.extern asmp_deflate_dynamic_litfreq_count
.extern asmp_deflate_dynamic_litlen_huffman
.extern asmp_deflate_dynamic_canonical_codes
.extern asmp_deflate_dynamic_reverse_codes
.extern asmp_deflate_dynamic_code_length_rle
.extern asmp_deflate_dynamic_blfreq_count
.extern asmp_deflate_dynamic_bllen_huffman
.extern asmp_deflate_dynamic_code_counts

// Scratch layout, 16-byte aligned:
//   +0      ll_freq[286]       uint32_t  1144 bytes
//   +1144   ll_len[286]        uint8_t    286 bytes
//   +1430   ll_code[286]       uint16_t   572 bytes
//   +2002   ll_bit_code[286]   uint16_t   572 bytes
//   +2574   dist_len[30]       uint8_t     30 bytes
//   +2604   combined_len[316]  uint8_t    316 bytes
//   +2920   rle_events[316]    4 bytes   1264 bytes
//   +4184   bl_freq[19]        uint32_t    76 bytes
//   +4260   bl_len[19]         uint8_t     19 bytes
//   +4280   bl_code[19]        uint16_t    38 bytes
//   +4318   bl_bit_code[19]    uint16_t    38 bytes
//   +4356   canon_scratch                  128 bytes
//   +4488   event_count_slot   uint64_t      8 bytes
//   +4496   lcodes_slot        uint64_t      8 bytes
//   +4504   dcodes_slot        uint64_t      8 bytes
//   +4512   ll_huff_scratch               6864 bytes
//   +11376  bl_huff_scratch                456 bytes
//   total = 11832 bytes

.function dcd_flush8 (inout: x.out, x.bitbuf, w.bit_count)
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

.function dcd_write_raw (in: x.bits, w.nbits, inout: x.out, x.bitbuf, w.bit_count)
entry:
  cbz w.nbits, write_done
  lsl x.tmp, x.bits, x.bit_count
  orr x.bitbuf, x.bitbuf, x.tmp
  add w.bit_count, w.bit_count, w.nbits
  .inline dcd_flush8 (x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
write_done:
  .return
.end

.function deflate_dynamic_compact_dual_huffman_trimmed_litonly_aarch64_asm (
  in: x.dst, x.src, x.src_len, x.scratch,
  out: x.written, w.status
)
entry:
  .save all
  mov x29, sp

  mov x.freq_ptr, x.scratch
  add x.len_ptr, x.scratch, #1144
  add x.code_ptr, x.scratch, #1430
  add x.bit_code_ptr, x.scratch, #2002
  add x.dist_len_ptr, x.scratch, #2574
  mov x.off, #2604
  add x.combined_len_ptr, x.scratch, x.off
  mov x.off, #2920
  add x.event_ptr, x.scratch, x.off
  mov x.off, #4184
  add x.bl_freq_ptr, x.scratch, x.off
  mov x.off, #4260
  add x.bl_len_ptr, x.scratch, x.off
  mov x.off, #4280
  add x.bl_code_ptr, x.scratch, x.off
  mov x.off, #4318
  add x.bl_bit_code_ptr, x.scratch, x.off
  mov x.off, #4356
  add x.canon_scratch, x.scratch, x.off
  mov x.off, #4488
  add x.event_count_ptr, x.scratch, x.off
  mov x.off, #4496
  add x.lcodes_ptr, x.scratch, x.off
  mov x.off, #4504
  add x.dcodes_ptr, x.scratch, x.off
  mov x.off, #4512
  add x.huff_scratch_ptr, x.scratch, x.off
  mov x.off, #11376
  add x.bl_huff_scratch_ptr, x.scratch, x.off

  mov x0, x.src
  mov x1, x.src_len
  mov x2, x.freq_ptr
  mov x3, #1144
  bl asmp_deflate_dynamic_litfreq_count
  mov w.status, w0
  cbnz w.status, return_status

  mov x0, x.freq_ptr
  mov x1, #1144
  mov x2, x.len_ptr
  mov x3, #286
  mov x4, x.huff_scratch_ptr
  mov x5, #6864
  bl asmp_deflate_dynamic_litlen_huffman
  mov w.status, w0
  cbnz w.status, return_status

  mov x0, x.len_ptr
  mov x1, #286
  mov x2, x.code_ptr
  mov x3, #572
  mov x4, x.canon_scratch
  mov x5, #128
  bl asmp_deflate_dynamic_canonical_codes
  mov w.status, w0
  cbnz w.status, return_status

  mov x0, x.len_ptr
  mov x1, #286
  mov x2, x.code_ptr
  mov x3, #572
  mov x4, x.bit_code_ptr
  mov x5, #572
  bl asmp_deflate_dynamic_reverse_codes
  mov w.status, w0
  cbnz w.status, return_status

  mov x.dstp, x.dist_len_ptr
  mov x.count, #30
  mov w.zero, #0

zero_dist_len_loop:
  cbz x.count, count_codes
  strb w.zero, [x.dstp]
  add x.dstp, x.dstp, #1
  sub x.count, x.count, #1
  b zero_dist_len_loop

count_codes:
  mov x0, x.len_ptr
  mov x1, #286
  mov x2, x.dist_len_ptr
  mov x3, #30
  mov x4, x.lcodes_ptr
  mov x5, x.dcodes_ptr
  bl asmp_deflate_dynamic_code_counts
  mov w.status, w0
  cbnz w.status, return_status

  ldr x.lcodes, [x.lcodes_ptr]
  ldr x.dcodes, [x.dcodes_ptr]

  mov x.srcp, x.len_ptr
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
  mov w.status, w0
  cbnz w.status, return_status

  ldr x.event_count, [x.event_count_ptr]

  mov x0, x.event_ptr
  mov x1, x.event_count
  mov x2, x.bl_freq_ptr
  mov x3, #76
  bl asmp_deflate_dynamic_blfreq_count
  mov w.status, w0
  cbnz w.status, return_status

  mov x0, x.bl_freq_ptr
  mov x1, #76
  mov x2, x.bl_len_ptr
  mov x3, #19
  mov x4, x.bl_huff_scratch_ptr
  mov x5, #456
  bl asmp_deflate_dynamic_bllen_huffman
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

  adrp x.order, :pg_hi21:deflate_dynamic_compact_dual_huffman_bl_order
  add x.order, x.order, :lo12:deflate_dynamic_compact_dual_huffman_bl_order

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
  .inline dcd_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  sub x.bits, x.lcodes, #257
  mov w.nbits, #5
  .inline dcd_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  sub x.bits, x.dcodes, #1
  mov w.nbits, #5
  .inline dcd_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  sub x.bits, x.blcodes, #4
  mov w.nbits, #4
  .inline dcd_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  mov x.index, #0

write_bl_lengths_loop:
  cmp x.index, x.blcodes
  b.hs write_events_start
  ldrb w.symbol, [x.order, x.index]
  ldrb w.bits, [x.bl_len_ptr, w.symbol, uxtw]
  mov w.nbits, #3
  .inline dcd_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
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
  .inline dcd_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  ldrb w.extra_bits, [x.event_cursor, #2]
  cmp w.extra_bits, #7
  b.hi bad_argument
  cbz w.extra_bits, event_next

  ldrb w.bits, [x.event_cursor, #1]
  mov w.nbits, w.extra_bits
  .inline dcd_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

event_next:
  add x.event_cursor, x.event_cursor, #4
  sub x.remaining, x.remaining, #1
  b write_events_loop

payload_start:
  mov x.pos, #0

literal_loop:
  cmp x.pos, x.src_len
  b.hs literal_done
  ldrb w.lit, [x.src, x.pos]

  add x.table_offset, x.lit, x.lit
  add x.table_entry, x.bit_code_ptr, x.table_offset
  ldrh w.bits, [x.table_entry]

  add x.table_entry, x.len_ptr, x.lit
  ldrb w.nbits, [x.table_entry]

  .inline dcd_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  add x.pos, x.pos, #1
  b literal_loop

literal_done:
  ldrh w.bits, [x.bit_code_ptr, #512]
  ldrb w.nbits, [x.len_ptr, #256]
  .inline dcd_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

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

.function asmp_deflate_raw_dynamic_compact_dual_huffman_trimmed_bound export profile=c-aapcs64 (
  in: x.src_len,
  out: x.bound
)
entry:
  ubfm x.extra, x.src_len, #3, #63
  add x.bound, x.src_len, x.extra
  add x.bound, x.bound, #768
  ret
.end

.function asmp_deflate_raw_dynamic_compact_dual_huffman_trimmed_scratch_size export profile=c-aapcs64 (
  out: x.size
)
entry:
  mov x.size, #11832
  ret
.end

.function asmp_deflate_raw_dynamic_compact_dual_huffman_trimmed_scratch_align export profile=c-aapcs64 (
  out: x.align
)
entry:
  mov x.align, #16
  ret
.end

.function asmp_deflate_raw_dynamic_compact_dual_huffman_trimmed export profile=c-aapcs64 (
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
  mov x.required_scratch, #11832
  cmp x.scratch_len, x.required_scratch
  b.lo public_scratch_too_small

  ubfm x.required, x.src_len, #3, #63
  add x.required, x.src_len, x.required
  add x.required, x.required, #768
  cmp x.dst_cap, x.required
  b.lo public_dst_too_small

  .call deflate_dynamic_compact_dual_huffman_trimmed_litonly_aarch64_asm (
    x.dst=x.dst,
    x.src=x.src,
    x.src_len=x.src_len,
    x.scratch=x.scratch,
    x.written=x.written,
    w.status=w.status
  )
  cbnz w.status, public_zero_done

  str x.written, [x.dst_len]
  b public_done

public_dst_too_small:
  mov w.status, #1
  b public_zero_done

public_scratch_too_small:
  mov w.status, #2
  b public_zero_done

public_bad_argument:
  mov w.status, #3
  b public_done

public_zero_done:
  str xzr, [x.dst_len]
  b public_done

public_done:
  .restore all
  ret
.end

.section .rodata
deflate_dynamic_compact_dual_huffman_bl_order:
  .byte 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
