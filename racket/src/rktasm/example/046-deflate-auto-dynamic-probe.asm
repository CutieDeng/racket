// ============================================================
// 046-deflate-auto-dynamic-probe.asm
// ============================================================
//
// Experimental raw-deflate selector that keeps the stable 019 auto path for
// tiny inputs and uses the 045 dynamic-Huffman LZ77 block for larger inputs.
//
// This is intentionally a versioned probe entry, not the stable
// asmp_deflate_raw_auto symbol. It exists so benchmark and quality gates can
// exercise stored/fixed/dynamic policy without changing the installed default.

.extern asmp_deflate_raw_auto
.extern asmp_deflate_raw_dynamic_lz77_huffman

.function asmp_deflate_raw_auto_dynamic_probe_bound export profile=c-aapcs64 (
  in: x.src_len,
  out: x.bound
)
entry:
  add x.bound, x.src_len, x.src_len
  mov x.extra, #4096
  add x.bound, x.bound, x.extra
  ret
.end

.function asmp_deflate_raw_auto_dynamic_probe_scratch_size export profile=c-aapcs64 (
  out: x.size
)
entry:
  movz x.size, #0x4fa0
  movk x.size, #0x4, lsl #16
  ret
.end

.function asmp_deflate_raw_auto_dynamic_probe_scratch_align export profile=c-aapcs64 (
  out: x.align
)
entry:
  mov x.align, #16
  ret
.end

.function asmp_deflate_raw_auto_dynamic_probe export profile=c-aapcs64 (
  in: x.dst, x.dst_cap, x.dst_len, x.src, x.src_len, x.scratch, x.scratch_len,
  out: w.status
)
entry:
  cmp x.src_len, #96
  b.lo use_fixed_stored_auto

  b asmp_deflate_raw_dynamic_lz77_huffman

use_fixed_stored_auto:
  b asmp_deflate_raw_auto
.end
