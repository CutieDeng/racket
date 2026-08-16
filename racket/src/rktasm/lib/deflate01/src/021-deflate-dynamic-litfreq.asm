// ============================================================
// 021-deflate-dynamic-litfreq.asm - dynamic Huffman literal frequency helper
// ============================================================
//
// This file is the next assembly step after 020. It does not emit a deflate
// stream yet. Instead, it builds the literal/length frequency table that the
// dynamic-Huffman tree builder will consume:
//
//   ll_freq[0..255] = literal byte counts
//   ll_freq[256]    = EOB count, always one
//   ll_freq[257..285] = zero in this literal-only milestone
//
// Keeping this as a preserved numbered example gives the future tree builder a
// native, tested scratch layout without mixing histogram bugs with dynamic
// header and bitstream bugs.

.function deflate_dynamic_litfreq_count_aarch64_asm export profile=c-aapcs64 visibility=hidden no-header (
  in: x.src, x.src_len, x.freq_ptr,
  out: x.active_count
)
entry:
  .save all

  mov x.ptr, x.freq_ptr
  mov x.remaining, #286
  mov w.zero, #0

clear_loop:
  str w.zero, [x.ptr]
  add x.ptr, x.ptr, #4
  subs x.remaining, x.remaining, #1
  b.ne clear_loop

  mov x.pos, #0
  mov x.active_count, #0

count_loop:
  cmp x.pos, x.src_len
  b.hs add_eob
  ldrb w.symbol, [x.src, x.pos]
  ldr w.freq, [x.freq_ptr, w.symbol, uxtw #2]
  cbnz w.freq, count_existing
  add x.active_count, x.active_count, #1

count_existing:
  add w.freq, w.freq, #1
  str w.freq, [x.freq_ptr, w.symbol, uxtw #2]
  add x.pos, x.pos, #1
  b count_loop

add_eob:
  mov w.symbol, #256
  ldr w.freq, [x.freq_ptr, w.symbol, uxtw #2]
  cbnz w.freq, eob_existing
  add x.active_count, x.active_count, #1

eob_existing:
  add w.freq, w.freq, #1
  str w.freq, [x.freq_ptr, w.symbol, uxtw #2]

  .restore all
  ret
.end

.function asmp_deflate_dynamic_litfreq_count export profile=c-aapcs64 (
  in: x.src, x.src_len, x.freq_ptr, x.freq_len,
  out: w.status
)
entry:
  .save all

  cbz x.freq_ptr, public_bad_argument
  cbz x.src_len, public_src_ok
  cbz x.src, public_bad_argument

public_src_ok:
  mov x.required, #1144
  cmp x.freq_len, x.required
  b.lo public_scratch_too_small

  .call deflate_dynamic_litfreq_count_aarch64_asm (
    x.src=x.src,
    x.src_len=x.src_len,
    x.freq_ptr=x.freq_ptr,
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
