// ============================================================
// 037-deflate-dynamic-code-counts.asm - dynamic HLIT/HDIST counts
// ============================================================
//
// Computes the compact dynamic-header declaration counts from literal/length
// and distance length tables:
//   lcodes = max(257, last_nonzero_ll_index + 1)
//   dcodes = max(1,   last_nonzero_dist_index + 1)
//
// This is intentionally small and independent from the bit writer.  It gives
// later dynamic block encoders one place to trim the combined code-length
// sequence before running the Deflate RLE pass.

.function deflate_dynamic_code_counts_aarch64_asm (
  in: x.ll_len_ptr, x.dist_len_ptr,
  out: x.lcodes, x.dcodes, w.status
)
entry:
  .save all

  ldrb w.len, [x.ll_len_ptr, #256]
  cbz w.len, bad_argument
  cmp w.len, #15
  b.hi bad_argument

  mov x.lcodes, #257
  mov x.index, #0

scan_ll_loop:
  cmp x.index, #286
  b.hs scan_dist_start

  ldrb w.len, [x.ll_len_ptr, x.index]
  cmp w.len, #15
  b.hi bad_argument
  cbz w.len, scan_ll_next

  add x.candidate, x.index, #1
  cmp x.candidate, x.lcodes
  b.ls scan_ll_next
  mov x.lcodes, x.candidate

scan_ll_next:
  add x.index, x.index, #1
  b scan_ll_loop

scan_dist_start:
  mov x.dcodes, #1
  mov x.index, #0

scan_dist_loop:
  cmp x.index, #30
  b.hs return_ok

  ldrb w.len, [x.dist_len_ptr, x.index]
  cmp w.len, #15
  b.hi bad_argument
  cbz w.len, scan_dist_next

  add x.candidate, x.index, #1
  cmp x.candidate, x.dcodes
  b.ls scan_dist_next
  mov x.dcodes, x.candidate

scan_dist_next:
  add x.index, x.index, #1
  b scan_dist_loop

return_ok:
  mov w.status, #0
  b return_done

bad_argument:
  mov w.status, #3
  mov x.lcodes, #0
  mov x.dcodes, #0

return_done:
  .restore all
  ret
.end

.function asmp_deflate_dynamic_code_counts export profile=c-aapcs64 (
  in: x.ll_len_ptr, x.ll_len_len, x.dist_len_ptr, x.dist_len_len, x.lcodes_ptr, x.dcodes_ptr,
  out: w.status
)
entry:
  .save all

  cbz x.ll_len_ptr, public_bad_argument
  cbz x.dist_len_ptr, public_bad_argument
  cbz x.lcodes_ptr, public_bad_argument
  cbz x.dcodes_ptr, public_bad_argument

  mov x.required_len, #286
  cmp x.ll_len_len, x.required_len
  b.lo public_scratch_too_small

  mov x.required_len, #30
  cmp x.dist_len_len, x.required_len
  b.lo public_scratch_too_small

  .call deflate_dynamic_code_counts_aarch64_asm (
    x.ll_len_ptr=x.ll_len_ptr,
    x.dist_len_ptr=x.dist_len_ptr,
    x.lcodes=x.lcodes,
    x.dcodes=x.dcodes,
    w.status=w.status
  )
  cbnz w.status, public_zero_done

  str x.lcodes, [x.lcodes_ptr]
  str x.dcodes, [x.dcodes_ptr]
  b public_done

public_scratch_too_small:
  mov w.status, #2
  b public_done

public_bad_argument:
  mov w.status, #3
  b public_done

public_zero_done:
  str xzr, [x.lcodes_ptr]
  str xzr, [x.dcodes_ptr]
  b public_done

public_done:
  .restore all
  ret
.end
