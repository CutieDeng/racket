// ============================================================
// 035-deflate-dynamic-compact-header.asm - compact dynamic header
// ============================================================
//
// Writes the compact dynamic-Huffman block header from already-built helper
// tables:
//   bl_len[19]       code-length alphabet lengths
//   bl_bit_code[19]  code-length alphabet codes in deflate bit order
//   events[]         031 code-length RLE events
//
// Public params struct:
//   +0   bl_len_ptr        const uint8_t *
//   +8   bl_bit_code_ptr   const uint16_t *
//   +16  event_ptr         const uint8_t *  four bytes per event
//   +24  event_count       uint64_t
//   +32  lcodes            uint64_t         257..286
//   +40  dcodes            uint64_t         1..30

// ------------------------------------------------------------
// dch_flush8
// ------------------------------------------------------------
.function dch_flush8 (
  in: x.dst_base, x.dst_cap,
  inout: x.out, x.bitbuf, w.bit_count,
  out: w.status
)
entry:
  mov w.status, #0

flush_loop:
  cmp w.bit_count, #8
  b.lt flush_done

  sub x.written, x.out, x.dst_base
  cmp x.written, x.dst_cap
  b.hs flush_dst_too_small

  strb w.bitbuf, [x.out]
  add x.out, x.out, #1
  ubfm x.bitbuf, x.bitbuf, #8, #63
  sub w.bit_count, w.bit_count, #8
  b flush_loop

flush_dst_too_small:
  mov w.status, #1

flush_done:
  .return
.end

// ------------------------------------------------------------
// dch_write_raw
// ------------------------------------------------------------
.function dch_write_raw (
  in: x.bits, w.nbits, x.dst_base, x.dst_cap,
  inout: x.out, x.bitbuf, w.bit_count,
  out: w.status
)
entry:
  mov w.status, #0
  cbz w.nbits, write_done

  lsl x.tmp, x.bits, x.bit_count
  orr x.bitbuf, x.bitbuf, x.tmp
  add w.bit_count, w.bit_count, w.nbits

  .inline dch_flush8 (x.dst_base=x.dst_base, x.dst_cap=x.dst_cap, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count, w.status=w.status)

write_done:
  .return
.end

// ------------------------------------------------------------
// deflate_dynamic_compact_header_aarch64_asm
// ------------------------------------------------------------
.function deflate_dynamic_compact_header_aarch64_asm (
  in: x.dst, x.dst_cap, x.params,
  out: x.written, w.status
)
entry:
  .save all

  ldr x.bl_len_ptr, [x.params]
  ldr x.bl_bit_code_ptr, [x.params, #8]
  ldr x.event_ptr, [x.params, #16]
  ldr x.event_count, [x.params, #24]
  ldr x.lcodes, [x.params, #32]
  ldr x.dcodes, [x.params, #40]

  cbz x.bl_len_ptr, bad_argument
  cbz x.bl_bit_code_ptr, bad_argument
  cbz x.event_count, event_ptr_ok
  cbz x.event_ptr, bad_argument

event_ptr_ok:
  cmp x.lcodes, #257
  b.lo bad_argument
  cmp x.lcodes, #286
  b.hi bad_argument

  cmp x.dcodes, #1
  b.lo bad_argument
  cmp x.dcodes, #30
  b.hi bad_argument

  adrp x.order, :pg_hi21:deflate_dynamic_header_bl_order
  add x.order, x.order, :lo12:deflate_dynamic_header_bl_order

  mov x.dst_base, x.dst
  mov x.out, x.dst
  mov x.bitbuf, #0
  mov w.bit_count, #0

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
  // BFINAL=1, BTYPE=10.
  mov x.bits, #5
  mov w.nbits, #3
  .inline dch_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.dst_base=x.dst_base, x.dst_cap=x.dst_cap, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count, w.status=w.status)
  cbnz w.status, return_status

  sub x.bits, x.lcodes, #257
  mov w.nbits, #5
  .inline dch_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.dst_base=x.dst_base, x.dst_cap=x.dst_cap, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count, w.status=w.status)
  cbnz w.status, return_status

  sub x.bits, x.dcodes, #1
  mov w.nbits, #5
  .inline dch_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.dst_base=x.dst_base, x.dst_cap=x.dst_cap, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count, w.status=w.status)
  cbnz w.status, return_status

  sub x.bits, x.blcodes, #4
  mov w.nbits, #4
  .inline dch_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.dst_base=x.dst_base, x.dst_cap=x.dst_cap, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count, w.status=w.status)
  cbnz w.status, return_status

  mov x.index, #0

write_bl_lengths_loop:
  cmp x.index, x.blcodes
  b.hs write_events_start
  ldrb w.symbol, [x.order, x.index]
  ldrb w.bits, [x.bl_len_ptr, w.symbol, uxtw]
  mov w.nbits, #3
  .inline dch_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.dst_base=x.dst_base, x.dst_cap=x.dst_cap, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count, w.status=w.status)
  cbnz w.status, return_status
  add x.index, x.index, #1
  b write_bl_lengths_loop

write_events_start:
  mov x.event_cursor, x.event_ptr
  mov x.remaining, x.event_count

write_events_loop:
  cbz x.remaining, flush_partial

  ldrb w.symbol, [x.event_cursor]
  cmp w.symbol, #18
  b.hi bad_argument

  ldrb w.nbits, [x.bl_len_ptr, w.symbol, uxtw]
  cbz w.nbits, bad_argument
  cmp w.nbits, #7
  b.hi bad_argument

  ldrh w.bits, [x.bl_bit_code_ptr, w.symbol, uxtw #1]
  .inline dch_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.dst_base=x.dst_base, x.dst_cap=x.dst_cap, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count, w.status=w.status)
  cbnz w.status, return_status

  ldrb w.extra_bits, [x.event_cursor, #2]
  cmp w.extra_bits, #7
  b.hi bad_argument
  cbz w.extra_bits, event_next

  ldrb w.bits, [x.event_cursor, #1]
  mov w.nbits, w.extra_bits
  .inline dch_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.dst_base=x.dst_base, x.dst_cap=x.dst_cap, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count, w.status=w.status)
  cbnz w.status, return_status

event_next:
  add x.event_cursor, x.event_cursor, #4
  sub x.remaining, x.remaining, #1
  b write_events_loop

flush_partial:
  cbz w.bit_count, return_ok
  sub x.written, x.out, x.dst_base
  cmp x.written, x.dst_cap
  b.hs dst_too_small
  strb w.bitbuf, [x.out]
  add x.out, x.out, #1

return_ok:
  sub x.written, x.out, x.dst_base
  mov w.status, #0
  b return_done

bad_argument:
  mov w.status, #3
  b return_status

dst_too_small:
  mov w.status, #1
  b return_status

return_status:
  mov x.written, #0

return_done:
  .restore all
  ret
.end

.function asmp_deflate_dynamic_compact_header export profile=c-aapcs64 no-header (
  in: x.dst, x.dst_cap, x.dst_len, x.params,
  out: w.status
)
entry:
  .save all

  cbz x.dst, public_bad_argument
  cbz x.dst_len, public_bad_argument
  cbz x.params, public_bad_argument

  .call deflate_dynamic_compact_header_aarch64_asm (
    x.dst=x.dst,
    x.dst_cap=x.dst_cap,
    x.params=x.params,
    x.written=x.written,
    w.status=w.status
  )
  cbnz w.status, public_zero_done

  str x.written, [x.dst_len]
  b public_done

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
deflate_dynamic_header_bl_order:
  .byte 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
