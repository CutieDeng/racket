// ============================================================
// 047-deflate-auto-cost-probe.asm
// ============================================================
//
// Experimental raw-deflate selector that probes the LZ77 stream before choosing
// between the stable fixed/stored auto wrapper and the 045 dynamic-Huffman LZ77
// block.
//
// This is intentionally still a versioned probe entry, not the stable
// asmp_deflate_raw_auto symbol. The policy is deliberately small:
//   - inputs below 96 bytes use the stable 019 auto wrapper;
//   - if the dynamic scratch area is not available, use the stable wrapper;
//   - otherwise run the 043 frequency pass and require a minimum number of
//     match tokens before selecting 045 dynamic Huffman.

.extern asmp_deflate_raw_auto
.extern asmp_deflate_raw_dynamic_lz77_huffman
.extern asmp_deflate_dynamic_lz77_freq_count

.function asmp_deflate_raw_auto_dynamic_cost_probe_bound export profile=c-aapcs64 (
  in: x.src_len,
  out: x.bound
)
entry:
  add x.bound, x.src_len, x.src_len
  mov x.extra, #4096
  add x.bound, x.bound, x.extra
  ret
.end

.function asmp_deflate_raw_auto_dynamic_cost_probe_scratch_size export profile=c-aapcs64 (
  out: x.size
)
entry:
  movz x.size, #0x4fa0
  movk x.size, #0x4, lsl #16
  ret
.end

.function asmp_deflate_raw_auto_dynamic_cost_probe_scratch_align export profile=c-aapcs64 (
  out: x.align
)
entry:
  mov x.align, #16
  ret
.end

.function asmp_deflate_raw_auto_dynamic_cost_probe export profile=c-aapcs64 (
  in: x.dst, x.dst_cap, x.dst_len, x.src, x.src_len, x.scratch, x.scratch_len,
  out: w.status
)
entry:
  .save x0, x1, x2, x3, x4, x5, x6, x7, x19, x20, fp, lr

  cmp x.src_len, #96
  b.lo choose_auto

  cbz x.scratch, choose_auto
  movz x.required_scratch, #0x4fa0
  movk x.required_scratch, #0x4, lsl #16
  cmp x.scratch_len, x.required_scratch
  b.lo choose_auto

  mov x.ll_freq_ptr, x.scratch
  mov x.off, #2574
  add x.dist_freq_ptr, x.scratch, x.off
  mov x.off, #20384
  add x.lz77_scratch_ptr, x.scratch, x.off

  mov x0, x.src
  mov x1, x.src_len
  mov x2, x.ll_freq_ptr
  mov x3, #1144
  mov x4, x.dist_freq_ptr
  mov x5, #120
  mov x6, x.lz77_scratch_ptr
  mov x7, #262144
  bl asmp_deflate_dynamic_lz77_freq_count
  cbnz w0, choose_auto

  mov x.scan, x.dist_freq_ptr
  mov x.remaining, #30
  mov x.match_count, #0

sum_dist_loop:
  ldr w.freq, [x.scan]
  add x.match_count, x.match_count, w.freq, uxtw #0
  add x.scan, x.scan, #4
  subs x.remaining, x.remaining, #1
  b.ne sum_dist_loop

  ubfm x.required_matches, x.src_len, #10, #63
  cmp x.required_matches, #1
  b.hs required_ready
  mov x.required_matches, #1

required_ready:
  cmp x.match_count, x.required_matches
  b.lo choose_auto

choose_dynamic:
  .restore x0, x1, x2, x3, x4, x5, x6, x7, x19, x20, fp, lr
  b asmp_deflate_raw_dynamic_lz77_huffman

choose_auto:
  .restore x0, x1, x2, x3, x4, x5, x6, x7, x19, x20, fp, lr
  b asmp_deflate_raw_auto
.end
