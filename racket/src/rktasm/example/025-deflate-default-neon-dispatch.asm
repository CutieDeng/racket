// ============================================================
// 025-deflate-default-neon-dispatch.asm - strong default selector for 024
// ============================================================
//
// This file is intentionally tiny. It provides strong stable raw-deflate
// entrypoints and tail-branches to the versioned NEON-extend wrappers from
// 024-deflate-fixed-chain-neon-extend.asm.
//
// Link shape:
//   024 object: weak  asmp_deflate_raw_* defaults -> NEON-extend wrappers
//   025 object: strong asmp_deflate_raw_* defaults -> NEON-extend wrappers
//
// When both are linked, the strong symbols in this file override 024's weak
// defaults. This gives the library build a concrete place to express
// build-time implementation selection without duplicating the compressor body.

.extern asmp_deflate_neon_extend_raw_bound
.extern asmp_deflate_neon_extend_raw_scratch_size
.extern asmp_deflate_neon_extend_raw_scratch_align
.extern asmp_deflate_raw_fixed_neon_extend
.extern asmp_deflate_raw_stored_neon_extend
.extern asmp_deflate_raw_auto_neon_extend

.function asmp_deflate_raw_bound export profile=c-aapcs64 ()
entry:
  b asmp_deflate_neon_extend_raw_bound
.end

.function asmp_deflate_raw_scratch_size export profile=c-aapcs64 ()
entry:
  b asmp_deflate_neon_extend_raw_scratch_size
.end

.function asmp_deflate_raw_scratch_align export profile=c-aapcs64 ()
entry:
  b asmp_deflate_neon_extend_raw_scratch_align
.end

.function asmp_deflate_raw_fixed export profile=c-aapcs64 ()
entry:
  b asmp_deflate_raw_fixed_neon_extend
.end

.function asmp_deflate_raw_stored export profile=c-aapcs64 ()
entry:
  b asmp_deflate_raw_stored_neon_extend
.end

.function asmp_deflate_raw_auto export profile=c-aapcs64 ()
entry:
  b asmp_deflate_raw_auto_neon_extend
.end
