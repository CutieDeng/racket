// ============================================================
// 029-deflate-dynamic-reverse-codes.asm - deflate bit-order codes
// ============================================================
//
// The canonical-code helper in 028 stores codes in ordinary MSB-first canonical
// form. Deflate transmits Huffman codes least-significant bit first, so a bit
// writer either reverses on every symbol write or consumes a pre-reversed table.
// This helper builds that pre-reversed table from len[] and code[].

.function deflate_dynamic_reverse_codes_aarch64_asm export profile=c-aapcs64 visibility=hidden no-header (
  in: x.len_ptr, x.count, x.code_ptr, x.bit_code_ptr,
  out: w.status
)
entry:
  .save all

  mov x.len_cursor, x.len_ptr
  mov x.code_cursor, x.code_ptr
  mov x.bit_code_cursor, x.bit_code_ptr
  mov x.remaining, x.count
  mov w.zero, #0

reverse_loop:
  cbz x.remaining, return_ok
  ldrb w.len, [x.len_cursor]
  cmp w.len, #15
  b.hi bad_argument
  cbz w.len, store_zero

  ldrh w.code, [x.code_cursor]
  rbit w.rev, w.code
  mov w.shift, #32
  sub w.shift, w.shift, w.len
  lsr w.rev, w.rev, w.shift
  strh w.rev, [x.bit_code_cursor]
  b reverse_next

store_zero:
  strh w.zero, [x.bit_code_cursor]
  b reverse_next

reverse_next:
  add x.len_cursor, x.len_cursor, #1
  add x.code_cursor, x.code_cursor, #2
  add x.bit_code_cursor, x.bit_code_cursor, #2
  sub x.remaining, x.remaining, #1
  b reverse_loop

return_ok:
  mov w.status, #0
  .restore all
  ret

bad_argument:
  mov w.status, #3
  .restore all
  ret
.end

.function asmp_deflate_dynamic_reverse_codes export profile=c-aapcs64 (
  in: x.len_ptr, x.count, x.code_ptr, x.code_len, x.bit_code_ptr, x.bit_code_len,
  out: w.status
)
entry:
  .save all

  cbz x.len_ptr, public_bad_argument
  cbz x.code_ptr, public_bad_argument
  cbz x.bit_code_ptr, public_bad_argument

  add x.required_code, x.count, x.count
  cmp x.code_len, x.required_code
  b.lo public_scratch_too_small

  cmp x.bit_code_len, x.required_code
  b.lo public_scratch_too_small

  .call deflate_dynamic_reverse_codes_aarch64_asm (
    x.len_ptr=x.len_ptr,
    x.count=x.count,
    x.code_ptr=x.code_ptr,
    x.bit_code_ptr=x.bit_code_ptr,
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
