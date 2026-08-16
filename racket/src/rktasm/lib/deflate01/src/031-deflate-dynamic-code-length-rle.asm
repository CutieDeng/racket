// ============================================================
// 031-deflate-dynamic-code-length-rle.asm - dynamic code-length RLE
// ============================================================
//
// Converts a deflate code-length sequence into RLE events over symbols 0..18.
// Each output event is four bytes:
//   +0 symbol      uint8_t  (0..18)
//   +1 extra       uint8_t
//   +2 extra_bits  uint8_t  (0, 2, 3, or 7)
//   +3 reserved    uint8_t  zero
//
// This is the native step between a length table and the future bit-length
// tree builder. It deliberately does not emit bits and does not build the
// code-length Huffman tree.

// ------------------------------------------------------------
// clr_emit
// ------------------------------------------------------------
.function clr_emit (
  in: w.symbol, w.extra, w.extra_bits,
  inout: x.event_ptr, x.event_count
)
entry:
  strb w.symbol, [x.event_ptr]
  strb w.extra, [x.event_ptr, #1]
  strb w.extra_bits, [x.event_ptr, #2]
  mov w.zero, #0
  strb w.zero, [x.event_ptr, #3]
  add x.event_ptr, x.event_ptr, #4
  add x.event_count, x.event_count, #1
  .return
.end

// ------------------------------------------------------------
// deflate_dynamic_code_length_rle_aarch64_asm
// ------------------------------------------------------------
.function deflate_dynamic_code_length_rle_aarch64_asm (
  in: x.len_ptr, x.count, x.event_ptr, x.event_cap,
  out: x.event_count, w.status
)
entry:
  .save all

  mov x.len_cursor, x.len_ptr
  mov x.remaining, x.count
  mov x.event_count, #0

rle_loop:
  cbz x.remaining, return_ok
  ldrb w.len, [x.len_cursor]
  cmp w.len, #15
  b.hi bad_argument

  mov x.run, #1
  add x.scan, x.len_cursor, #1
  sub x.scan_remaining, x.remaining, #1

scan_run_loop:
  cbz x.scan_remaining, scan_done
  ldrb w.scan_len, [x.scan]
  cmp w.scan_len, w.len
  b.ne scan_done
  add x.run, x.run, #1
  add x.scan, x.scan, #1
  sub x.scan_remaining, x.scan_remaining, #1
  b scan_run_loop

scan_done:
  cbz w.len, zero_run

  mov w.symbol, w.len
  mov w.extra, #0
  mov w.extra_bits, #0
  cmp x.event_count, x.event_cap
  b.hs dst_too_small
  .inline clr_emit (w.symbol=w.symbol, w.extra=w.extra, w.extra_bits=w.extra_bits, x.event_ptr=x.event_ptr, x.event_count=x.event_count)

  sub x.left, x.run, #1

nonzero_repeat_loop:
  cmp x.left, #3
  b.lo nonzero_tail
  mov x.chunk, #6
  cmp x.left, x.chunk
  b.hs nonzero_chunk_ready
  mov x.chunk, x.left

nonzero_chunk_ready:
  mov w.symbol, #16
  sub w.extra, w.chunk, #3
  mov w.extra_bits, #2
  cmp x.event_count, x.event_cap
  b.hs dst_too_small
  .inline clr_emit (w.symbol=w.symbol, w.extra=w.extra, w.extra_bits=w.extra_bits, x.event_ptr=x.event_ptr, x.event_count=x.event_count)
  sub x.left, x.left, x.chunk
  b nonzero_repeat_loop

nonzero_tail:
  cbz x.left, advance_run
  mov w.symbol, w.len
  mov w.extra, #0
  mov w.extra_bits, #0
  cmp x.event_count, x.event_cap
  b.hs dst_too_small
  .inline clr_emit (w.symbol=w.symbol, w.extra=w.extra, w.extra_bits=w.extra_bits, x.event_ptr=x.event_ptr, x.event_count=x.event_count)
  sub x.left, x.left, #1
  b nonzero_tail

zero_run:
  mov x.left, x.run

zero_long_loop:
  cmp x.left, #11
  b.lo zero_mid_loop
  mov x.chunk, #138
  cmp x.left, x.chunk
  b.hs zero_long_chunk_ready
  mov x.chunk, x.left

zero_long_chunk_ready:
  mov w.symbol, #18
  sub w.extra, w.chunk, #11
  mov w.extra_bits, #7
  cmp x.event_count, x.event_cap
  b.hs dst_too_small
  .inline clr_emit (w.symbol=w.symbol, w.extra=w.extra, w.extra_bits=w.extra_bits, x.event_ptr=x.event_ptr, x.event_count=x.event_count)
  sub x.left, x.left, x.chunk
  b zero_long_loop

zero_mid_loop:
  cmp x.left, #3
  b.lo zero_tail
  mov x.chunk, #10
  cmp x.left, x.chunk
  b.hs zero_mid_chunk_ready
  mov x.chunk, x.left

zero_mid_chunk_ready:
  mov w.symbol, #17
  sub w.extra, w.chunk, #3
  mov w.extra_bits, #3
  cmp x.event_count, x.event_cap
  b.hs dst_too_small
  .inline clr_emit (w.symbol=w.symbol, w.extra=w.extra, w.extra_bits=w.extra_bits, x.event_ptr=x.event_ptr, x.event_count=x.event_count)
  sub x.left, x.left, x.chunk
  b zero_mid_loop

zero_tail:
  cbz x.left, advance_run
  mov w.symbol, #0
  mov w.extra, #0
  mov w.extra_bits, #0
  cmp x.event_count, x.event_cap
  b.hs dst_too_small
  .inline clr_emit (w.symbol=w.symbol, w.extra=w.extra, w.extra_bits=w.extra_bits, x.event_ptr=x.event_ptr, x.event_count=x.event_count)
  sub x.left, x.left, #1
  b zero_tail

advance_run:
  add x.len_cursor, x.len_cursor, x.run
  sub x.remaining, x.remaining, x.run
  b rle_loop

return_ok:
  mov w.status, #0
  b return_done

bad_argument:
  mov w.status, #3
  b return_done

dst_too_small:
  mov w.status, #1
  b return_status

return_status:
  mov x.event_count, #0

return_done:
  .restore all
  ret
.end

.function asmp_deflate_dynamic_code_length_rle export profile=c-aapcs64 (
  in: x.len_ptr, x.count, x.event_ptr, x.event_cap, x.event_count_ptr,
  out: w.status
)
entry:
  .save all

  cbz x.len_ptr, public_bad_argument
  cbz x.event_ptr, public_bad_argument
  cbz x.event_count_ptr, public_bad_argument

  .call deflate_dynamic_code_length_rle_aarch64_asm (
    x.len_ptr=x.len_ptr,
    x.count=x.count,
    x.event_ptr=x.event_ptr,
    x.event_cap=x.event_cap,
    x.event_count=x.event_count,
    w.status=w.status
  )
  cbnz w.status, public_zero_done

  str x.event_count, [x.event_count_ptr]
  b public_done

public_bad_argument:
  mov w.status, #3
  b public_done

public_zero_done:
  str xzr, [x.event_count_ptr]
  b public_done

public_done:
  .restore all
  ret
.end
