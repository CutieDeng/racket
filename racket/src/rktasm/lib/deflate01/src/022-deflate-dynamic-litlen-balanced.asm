// ============================================================
// 022-deflate-dynamic-litlen-balanced.asm - balanced LL code lengths
// ============================================================
//
// This is a deliberately conservative stepping stone toward the real
// frequency-sorted Huffman tree builder. It consumes ll_freq[286] and writes a
// valid complete literal/length code-length table ll_len[286].
//
// The lengths are balanced by active symbol count, not frequency-optimal:
//   n active symbols, k = ceil(log2(n))
//   short_count = 2^k - n symbols get length k-1
//   remaining active symbols get length k
//
// For n <= 2, active symbols get length 1. If only one symbol is active, a
// dummy literal is assigned length 1 as well, matching the Racket reference's
// min-codes rule.

.function deflate_dynamic_litlen_balanced_aarch64_asm export profile=c-aapcs64 visibility=hidden no-header (
  in: x.freq_ptr, x.len_ptr,
  out: x.active_count
)
entry:
  .save all

  mov x.ptr, x.len_ptr
  mov x.remaining, #286
  mov w.zero, #0

clear_len_loop:
  strb w.zero, [x.ptr]
  add x.ptr, x.ptr, #1
  subs x.remaining, x.remaining, #1
  b.ne clear_len_loop

  mov w.symbol, #0
  mov x.active_count, #0

count_active_loop:
  cmp w.symbol, #286
  b.hs active_count_done
  ldr w.freq, [x.freq_ptr, w.symbol, uxtw #2]
  cbz w.freq, count_active_next
  add x.active_count, x.active_count, #1

count_active_next:
  add w.symbol, w.symbol, #1
  b count_active_loop

active_count_done:
  cbz x.active_count, return_done
  cmp x.active_count, #2
  b.hi compute_multi_lengths

  mov w.long_len, #1
  mov w.short_len, #1
  mov x.short_remaining, #0
  b assign_lengths

compute_multi_lengths:
  mov x.pow2, #1
  mov w.long_len, #0

ceil_log_loop:
  cmp x.pow2, x.active_count
  b.hs ceil_log_done
  add x.pow2, x.pow2, x.pow2
  add w.long_len, w.long_len, #1
  b ceil_log_loop

ceil_log_done:
  sub w.short_len, w.long_len, #1
  sub x.short_remaining, x.pow2, x.active_count
  b assign_lengths

assign_lengths:
  mov w.symbol, #0

assign_loop:
  cmp w.symbol, #286
  b.hs maybe_add_dummy
  ldr w.freq, [x.freq_ptr, w.symbol, uxtw #2]
  cbz w.freq, assign_next
  cbz x.short_remaining, assign_long

  strb w.short_len, [x.len_ptr, w.symbol, uxtw]
  sub x.short_remaining, x.short_remaining, #1
  b assign_next

assign_long:
  strb w.long_len, [x.len_ptr, w.symbol, uxtw]
  b assign_next

assign_next:
  add w.symbol, w.symbol, #1
  b assign_loop

maybe_add_dummy:
  cmp x.active_count, #1
  b.ne return_done
  ldr w.freq, [x.freq_ptr]
  cbnz w.freq, dummy_symbol_1
  mov w.tmp, #1
  strb w.tmp, [x.len_ptr]
  add x.active_count, x.active_count, #1
  b return_done

dummy_symbol_1:
  mov w.tmp, #1
  strb w.tmp, [x.len_ptr, #1]
  add x.active_count, x.active_count, #1
  b return_done

return_done:
  .restore all
  ret
.end

.function asmp_deflate_dynamic_litlen_balanced export profile=c-aapcs64 (
  in: x.freq_ptr, x.freq_len, x.len_ptr, x.len_len,
  out: w.status
)
entry:
  .save all

  cbz x.freq_ptr, public_bad_argument
  cbz x.len_ptr, public_bad_argument

  mov x.required_freq, #1144
  cmp x.freq_len, x.required_freq
  b.lo public_scratch_too_small

  mov x.required_len, #286
  cmp x.len_len, x.required_len
  b.lo public_scratch_too_small

  .call deflate_dynamic_litlen_balanced_aarch64_asm (
    x.freq_ptr=x.freq_ptr,
    x.len_ptr=x.len_ptr,
    x.active_count=x.active_count
  )

  mov w.status, #0
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
