// ============================================================
// 034-deflate-dynamic-blcodes-count.asm - dynamic BL code count
// ============================================================
//
// Computes the compact dynamic-header code-length-code count from bl_len[19].
// Deflate stores this value as HCLEN = blcodes - 4, using the fixed order:
//   16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
//
// The helper also validates that each code-length alphabet length is <= 7.

.function deflate_dynamic_blcodes_count_aarch64_asm (
  in: x.len_ptr,
  out: x.blcodes, w.status
)
entry:
  .save all

  adrp x.order, :pg_hi21:deflate_dynamic_bl_order
  add x.order, x.order, :lo12:deflate_dynamic_bl_order

  mov x.index, #0
  mov x.blcodes, #4

scan_loop:
  cmp x.index, #19
  b.hs return_ok

  ldrb w.symbol, [x.order, x.index]
  ldrb w.len, [x.len_ptr, w.symbol, uxtw]
  cmp w.len, #7
  b.hi bad_argument
  cbz w.len, scan_next

  cmp x.index, #3
  b.ls scan_next
  add x.blcodes, x.index, #1

scan_next:
  add x.index, x.index, #1
  b scan_loop

return_ok:
  mov w.status, #0
  b return_done

bad_argument:
  mov w.status, #3
  mov x.blcodes, #0

return_done:
  .restore all
  ret
.end

.function asmp_deflate_dynamic_blcodes_count export profile=c-aapcs64 (
  in: x.len_ptr, x.len_len, x.blcodes_ptr,
  out: w.status
)
entry:
  .save all

  cbz x.len_ptr, public_bad_argument
  cbz x.blcodes_ptr, public_bad_argument

  mov x.required_len, #19
  cmp x.len_len, x.required_len
  b.lo public_scratch_too_small

  .call deflate_dynamic_blcodes_count_aarch64_asm (
    x.len_ptr=x.len_ptr,
    x.blcodes=x.blcodes,
    w.status=w.status
  )
  cbnz w.status, public_zero_done

  str x.blcodes, [x.blcodes_ptr]
  b public_done

public_scratch_too_small:
  mov w.status, #2
  b public_done

public_bad_argument:
  mov w.status, #3
  b public_done

public_zero_done:
  str xzr, [x.blcodes_ptr]
  b public_done

public_done:
  .restore all
  ret
.end

.section .rodata
deflate_dynamic_bl_order:
  .byte 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
