// ============================================================
// 044-deflate-dynamic-distlen-huffman.asm - frequency distance lengths
// ============================================================
//
// Builds Deflate distance Huffman code lengths from dist_freq[30].
//
// Distance codes use the same 15-bit Deflate limit as literal/length codes, so
// this helper deliberately reuses the 039 LL Huffman builder instead of
// duplicating another tree implementation.  Nonzero distance frequencies are
// copied into a temporary 286-symbol frequency table, 039 builds the lengths,
// and the first 30 lengths are copied back to the caller.
//
// If all distance frequencies are zero, all output lengths remain zero. This
// preserves the literal-only dynamic-block case where no distance symbols are
// used.
//
// Public API:
//   int asmp_deflate_dynamic_distlen_huffman(void *freq_ptr,
//                                           uint64_t freq_len,
//                                           void *len_ptr,
//                                           uint64_t len_len,
//                                           void *scratch_ptr,
//                                           uint64_t scratch_len);
//
// Scratch layout, 16-byte aligned:
//   +0      temp_ll_freq[286]  uint32_t  1144 bytes
//   +1144   temp_ll_len[286]   uint8_t    286 bytes
//   +1430   padding                       10 bytes
//   +1440   ll_huff_scratch              6864 bytes
//   total = 8304 bytes

.extern asmp_deflate_dynamic_litlen_huffman

.function deflate_dynamic_distlen_huffman_aarch64_asm export profile=c-aapcs64 visibility=hidden no-header (
  in: x.freq_ptr, x.len_ptr, x.scratch_ptr,
  out: w.status
)
entry:
  .save all

  mov x.temp_freq_ptr, x.scratch_ptr
  mov x.off, #1144
  add x.temp_len_ptr, x.scratch_ptr, x.off
  mov x.off, #1440
  add x.huff_scratch_ptr, x.scratch_ptr, x.off

  mov x.ptr, x.len_ptr
  mov x.remaining, #30
  mov w.zero, #0

clear_dist_len_loop:
  strb w.zero, [x.ptr]
  add x.ptr, x.ptr, #1
  subs x.remaining, x.remaining, #1
  b.ne clear_dist_len_loop

  mov x.ptr, x.temp_freq_ptr
  mov x.remaining, #286

clear_temp_freq_loop:
  str w.zero, [x.ptr]
  add x.ptr, x.ptr, #4
  subs x.remaining, x.remaining, #1
  b.ne clear_temp_freq_loop

  mov x.index, #0
  mov x.active_count, #0

copy_dist_freq_loop:
  cmp x.index, #30
  b.hs copy_dist_freq_done
  ldr w.freq, [x.freq_ptr, x.index, lsl #2]
  cbz w.freq, copy_dist_freq_next
  add x.active_count, x.active_count, #1
  str w.freq, [x.temp_freq_ptr, x.index, lsl #2]

copy_dist_freq_next:
  add x.index, x.index, #1
  b copy_dist_freq_loop

copy_dist_freq_done:
  cbz x.active_count, return_ok

  mov x0, x.temp_freq_ptr
  mov x1, #1144
  mov x2, x.temp_len_ptr
  mov x3, #286
  mov x4, x.huff_scratch_ptr
  mov x5, #6864
  bl asmp_deflate_dynamic_litlen_huffman
  mov w.status, w0
  cbnz w.status, return_done

  mov x.index, #0

copy_len_loop:
  cmp x.index, #30
  b.hs return_ok
  ldrb w.len, [x.temp_len_ptr, x.index]
  strb w.len, [x.len_ptr, x.index]
  add x.index, x.index, #1
  b copy_len_loop

return_ok:
  mov w.status, #0
  b return_done

return_done:
  .restore all
  ret
.end

.function asmp_deflate_dynamic_distlen_huffman export profile=c-aapcs64 (
  in: x.freq_ptr, x.freq_len, x.len_ptr, x.len_len, x.scratch_ptr, x.scratch_len,
  out: w.status
)
entry:
  .save all

  cbz x.freq_ptr, public_bad_argument
  cbz x.len_ptr, public_bad_argument
  cbz x.scratch_ptr, public_bad_argument

  mov x.required_freq, #120
  cmp x.freq_len, x.required_freq
  b.lo public_scratch_too_small

  mov x.required_len, #30
  cmp x.len_len, x.required_len
  b.lo public_scratch_too_small

  mov x.required_scratch, #8304
  cmp x.scratch_len, x.required_scratch
  b.lo public_scratch_too_small

  .call deflate_dynamic_distlen_huffman_aarch64_asm (
    x.freq_ptr=x.freq_ptr,
    x.len_ptr=x.len_ptr,
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
