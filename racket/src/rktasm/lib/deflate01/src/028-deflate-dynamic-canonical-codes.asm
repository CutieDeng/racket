// ============================================================
// 028-deflate-dynamic-canonical-codes.asm - dynamic Huffman canonical codes
// ============================================================
//
// This is the next dynamic-Huffman helper after 022. It consumes a code-length
// table and writes canonical Huffman codes in symbol order. Codes are not bit
// reversed here; the deflate bit writer reverses them when emitting bits.
//
// Scratch layout:
//   scratch[0..63]    = bl_count[16]   uint32_t
//   scratch[64..127]  = next_code[16]  uint32_t

.function deflate_dynamic_canonical_codes_aarch64_asm export profile=c-aapcs64 visibility=hidden no-header (
  in: x.len_ptr, x.count, x.code_ptr, x.scratch_ptr,
  out: w.status
)
entry:
  .save all

  add x.next_code, x.scratch_ptr, #64
  mov w.zero, #0

  mov x.ptr, x.code_ptr
  mov x.remaining, x.count

clear_code_loop:
  cbz x.remaining, clear_scratch_start
  strh w.zero, [x.ptr]
  add x.ptr, x.ptr, #2
  sub x.remaining, x.remaining, #1
  b clear_code_loop

clear_scratch_start:
  add x.code_bytes, x.count, x.count
  sub x.code_base, x.ptr, x.code_bytes
  mov x.ptr, x.scratch_ptr
  mov x.remaining, #32

clear_scratch_loop:
  str w.zero, [x.ptr]
  add x.ptr, x.ptr, #4
  subs x.remaining, x.remaining, #1
  b.ne clear_scratch_loop

  mov x.len_cursor, x.len_ptr
  mov x.remaining, x.count

count_lengths_loop:
  cbz x.remaining, build_next_codes
  ldrb w.len, [x.len_cursor]
  cmp w.len, #15
  b.hi bad_argument
  cbz w.len, count_lengths_next
  ldr w.tmp, [x.scratch_ptr, w.len, uxtw #2]
  add w.tmp, w.tmp, #1
  str w.tmp, [x.scratch_ptr, w.len, uxtw #2]

count_lengths_next:
  add x.len_cursor, x.len_cursor, #1
  sub x.remaining, x.remaining, #1
  b count_lengths_loop

build_next_codes:
  mov w.code, #0
  mov w.bits, #1

next_code_loop:
  cmp w.bits, #16
  b.hs assign_codes_start
  sub w.prev_bits, w.bits, #1
  ldr w.count_at_bits, [x.scratch_ptr, w.prev_bits, uxtw #2]
  add w.code, w.code, w.count_at_bits
  add w.code, w.code, w.code
  str w.code, [x.next_code, w.bits, uxtw #2]
  add w.bits, w.bits, #1
  b next_code_loop

assign_codes_start:
  mov x.len_cursor, x.len_ptr
  mov x.code_cursor, x.code_base
  mov x.remaining, x.count

assign_codes_loop:
  cbz x.remaining, return_ok
  ldrb w.len, [x.len_cursor]
  cbz w.len, assign_codes_next
  ldr w.code, [x.next_code, w.len, uxtw #2]
  strh w.code, [x.code_cursor]
  add w.code, w.code, #1
  str w.code, [x.next_code, w.len, uxtw #2]

assign_codes_next:
  add x.len_cursor, x.len_cursor, #1
  add x.code_cursor, x.code_cursor, #2
  sub x.remaining, x.remaining, #1
  b assign_codes_loop

return_ok:
  mov w.status, #0
  .restore all
  ret

bad_argument:
  mov w.status, #3
  .restore all
  ret
.end

.function asmp_deflate_dynamic_canonical_codes export profile=c-aapcs64 (
  in: x.len_ptr, x.count, x.code_ptr, x.code_len, x.scratch_ptr, x.scratch_len,
  out: w.status
)
entry:
  .save all

  cbz x.len_ptr, public_bad_argument
  cbz x.code_ptr, public_bad_argument
  cbz x.scratch_ptr, public_bad_argument

  add x.required_code, x.count, x.count
  cmp x.code_len, x.required_code
  b.lo public_scratch_too_small

  mov x.required_scratch, #128
  cmp x.scratch_len, x.required_scratch
  b.lo public_scratch_too_small

  .call deflate_dynamic_canonical_codes_aarch64_asm (
    x.len_ptr=x.len_ptr,
    x.count=x.count,
    x.code_ptr=x.code_ptr,
    x.scratch_ptr=x.scratch_ptr,
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
