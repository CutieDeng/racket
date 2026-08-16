// ============================================================
// 032-deflate-dynamic-blfreq.asm - dynamic code-length frequency helper
// ============================================================
//
// Consumes the 031 code-length RLE event table and fills bl_freq[19], the
// frequency table for deflate's code-length alphabet symbols 0..18.
//
// Event layout, shared with 031:
//   +0 symbol      uint8_t
//   +1 extra       uint8_t
//   +2 extra_bits  uint8_t
//   +3 reserved    uint8_t

.function deflate_dynamic_blfreq_count_aarch64_asm (
  in: x.event_ptr, x.event_count, x.freq_ptr,
  out: w.status
)
entry:
  .save all

  mov x.ptr, x.freq_ptr
  mov x.remaining, #19
  mov w.zero, #0

clear_loop:
  str w.zero, [x.ptr]
  add x.ptr, x.ptr, #4
  subs x.remaining, x.remaining, #1
  b.ne clear_loop

  mov x.event_cursor, x.event_ptr
  mov x.remaining, x.event_count

count_loop:
  cbz x.remaining, return_ok
  ldrb w.symbol, [x.event_cursor]
  cmp w.symbol, #18
  b.hi bad_argument

  ldr w.freq, [x.freq_ptr, w.symbol, uxtw #2]
  add w.freq, w.freq, #1
  str w.freq, [x.freq_ptr, w.symbol, uxtw #2]

  add x.event_cursor, x.event_cursor, #4
  sub x.remaining, x.remaining, #1
  b count_loop

return_ok:
  mov w.status, #0
  b return_done

bad_argument:
  mov w.status, #3

return_done:
  .restore all
  ret
.end

.function asmp_deflate_dynamic_blfreq_count export profile=c-aapcs64 (
  in: x.event_ptr, x.event_count, x.freq_ptr, x.freq_len,
  out: w.status
)
entry:
  .save all

  cbz x.event_ptr, public_bad_argument
  cbz x.freq_ptr, public_bad_argument

  mov x.required, #76
  cmp x.freq_len, x.required
  b.lo public_scratch_too_small

  .call deflate_dynamic_blfreq_count_aarch64_asm (
    x.event_ptr=x.event_ptr,
    x.event_count=x.event_count,
    x.freq_ptr=x.freq_ptr,
    w.status=w.status
  )
  b public_done

public_scratch_too_small:
  mov w.status, #2
  b public_done

public_bad_argument:
  mov w.status, #3
  b public_done

public_done:
  .restore all
  ret
.end
