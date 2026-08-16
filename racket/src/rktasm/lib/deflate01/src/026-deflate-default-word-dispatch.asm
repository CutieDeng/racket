// ============================================================
// 026-deflate-default-word-dispatch.asm - strong default selector for 023
// ============================================================
//
// Strong stable raw-deflate entrypoints that tail-branch to the versioned
// word-extend wrappers from 023-deflate-fixed-chain-word-extend.asm.
//
// This is the sibling of 025-deflate-default-neon-dispatch.asm. A build can
// choose which default implementation it wants by linking exactly one strong
// selector object while keeping implementation versions preserved separately.

.extern asmp_deflate_word_extend_raw_bound
.extern asmp_deflate_word_extend_raw_scratch_size
.extern asmp_deflate_word_extend_raw_scratch_align
.extern asmp_deflate_raw_fixed_word_extend
.extern asmp_deflate_raw_stored_word_extend
.extern asmp_deflate_raw_auto_word_extend

.function asmp_deflate_raw_bound export profile=c-aapcs64 ()
entry:
  b asmp_deflate_word_extend_raw_bound
.end

.function asmp_deflate_raw_scratch_size export profile=c-aapcs64 ()
entry:
  b asmp_deflate_word_extend_raw_scratch_size
.end

.function asmp_deflate_raw_scratch_align export profile=c-aapcs64 ()
entry:
  b asmp_deflate_word_extend_raw_scratch_align
.end

.function asmp_deflate_raw_fixed export profile=c-aapcs64 ()
entry:
  b asmp_deflate_raw_fixed_word_extend
.end

.function asmp_deflate_raw_stored export profile=c-aapcs64 ()
entry:
  b asmp_deflate_raw_stored_word_extend
.end

.function asmp_deflate_raw_auto export profile=c-aapcs64 ()
entry:
  b asmp_deflate_raw_auto_word_extend
.end
