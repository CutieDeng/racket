// ============================================================
// 027-deflate-runtime-dispatch.asm - runtime selector for 023/024
// ============================================================
//
// Strong stable raw-deflate entrypoints that choose between the 023
// word-extend wrappers and the 024 NEON-extend wrappers through cached
// function-pointer slots.
//
// Runtime feature word:
//   bit 0 set   -> use NEON-extend wrappers
//   bit 0 clear -> use word-extend wrappers
//
// Setter path:
//   choose a target table, then copy six function pointers into the selected
//   slots consumed by the stable entrypoints.
//
// This is an MVP selector. It does not probe optional host CPU features yet.
// The selector slots are initialized to NEON because NEON is baseline AArch64.
// The no-header init/setter entrypoints exist so tests and future platform
// probes can update them.

.extern asmp_deflate_word_extend_raw_bound
.extern asmp_deflate_word_extend_raw_scratch_size
.extern asmp_deflate_word_extend_raw_scratch_align
.extern asmp_deflate_raw_fixed_word_extend
.extern asmp_deflate_raw_stored_word_extend
.extern asmp_deflate_raw_auto_word_extend

.extern asmp_deflate_neon_extend_raw_bound
.extern asmp_deflate_neon_extend_raw_scratch_size
.extern asmp_deflate_neon_extend_raw_scratch_align
.extern asmp_deflate_raw_fixed_neon_extend
.extern asmp_deflate_raw_stored_neon_extend
.extern asmp_deflate_raw_auto_neon_extend

.function asmp_deflate_runtime_set_features export profile=c-aapcs64 visibility=hidden no-header ()
entry:
  adrp x16, :pg_hi21:asmp_deflate_runtime_features
  add x16, x16, #:lo12:asmp_deflate_runtime_features
  str x0, [x16]
  adrp x16, :pg_hi21:asmp_deflate_runtime_selected_bound
  add x16, x16, #:lo12:asmp_deflate_runtime_selected_bound
  adrp x17, :pg_hi21:asmp_deflate_runtime_word_slots
  add x17, x17, #:lo12:asmp_deflate_runtime_word_slots
  tbnz w0, #0, use_neon_table

copy_table:
  mov w8, #6
copy_loop:
  ldr x9, [x17], #8
  str x9, [x16], #8
  subs w8, w8, #1
  b.ne copy_loop
  ret

use_neon_table:
  adrp x17, :pg_hi21:asmp_deflate_runtime_neon_slots
  add x17, x17, #:lo12:asmp_deflate_runtime_neon_slots
  b copy_table
.end

.function asmp_deflate_runtime_detect_features export weak profile=c-aapcs64 visibility=hidden no-header ()
entry:
  mov x0, #1
  ret
.end

.function asmp_deflate_runtime_init export profile=c-aapcs64 visibility=hidden no-header ()
entry:
  .save fp, lr
  mov fp, sp
  bl asmp_deflate_runtime_detect_features
  .restore fp, lr
  b asmp_deflate_runtime_set_features
.end

.function asmp_deflate_raw_bound export profile=c-aapcs64 ()
entry:
  adrp x16, :pg_hi21:asmp_deflate_runtime_selected_bound
  ldr x16, [x16, :lo12:asmp_deflate_runtime_selected_bound]
  br x16
.end

.function asmp_deflate_raw_scratch_size export profile=c-aapcs64 ()
entry:
  adrp x16, :pg_hi21:asmp_deflate_runtime_selected_scratch_size
  ldr x16, [x16, :lo12:asmp_deflate_runtime_selected_scratch_size]
  br x16
.end

.function asmp_deflate_raw_scratch_align export profile=c-aapcs64 ()
entry:
  adrp x16, :pg_hi21:asmp_deflate_runtime_selected_scratch_align
  ldr x16, [x16, :lo12:asmp_deflate_runtime_selected_scratch_align]
  br x16
.end

.function asmp_deflate_raw_fixed export profile=c-aapcs64 ()
entry:
  adrp x16, :pg_hi21:asmp_deflate_runtime_selected_fixed
  ldr x16, [x16, :lo12:asmp_deflate_runtime_selected_fixed]
  br x16
.end

.function asmp_deflate_raw_stored export profile=c-aapcs64 ()
entry:
  adrp x16, :pg_hi21:asmp_deflate_runtime_selected_stored
  ldr x16, [x16, :lo12:asmp_deflate_runtime_selected_stored]
  br x16
.end

.function asmp_deflate_raw_auto export profile=c-aapcs64 ()
entry:
  adrp x16, :pg_hi21:asmp_deflate_runtime_selected_auto
  ldr x16, [x16, :lo12:asmp_deflate_runtime_selected_auto]
  br x16
.end

.data
.align 3
.globl asmp_deflate_runtime_features
asmp_deflate_runtime_features:
  .byte8 1
.align 3
asmp_deflate_runtime_selected_bound:
  .byte8 asmp_deflate_neon_extend_raw_bound
.align 3
asmp_deflate_runtime_selected_scratch_size:
  .byte8 asmp_deflate_neon_extend_raw_scratch_size
.align 3
asmp_deflate_runtime_selected_scratch_align:
  .byte8 asmp_deflate_neon_extend_raw_scratch_align
.align 3
asmp_deflate_runtime_selected_fixed:
  .byte8 asmp_deflate_raw_fixed_neon_extend
.align 3
asmp_deflate_runtime_selected_stored:
  .byte8 asmp_deflate_raw_stored_neon_extend
.align 3
asmp_deflate_runtime_selected_auto:
  .byte8 asmp_deflate_raw_auto_neon_extend

.align 3
asmp_deflate_runtime_word_slots:
  .byte8 asmp_deflate_word_extend_raw_bound
  .byte8 asmp_deflate_word_extend_raw_scratch_size
  .byte8 asmp_deflate_word_extend_raw_scratch_align
  .byte8 asmp_deflate_raw_fixed_word_extend
  .byte8 asmp_deflate_raw_stored_word_extend
  .byte8 asmp_deflate_raw_auto_word_extend

.align 3
asmp_deflate_runtime_neon_slots:
  .byte8 asmp_deflate_neon_extend_raw_bound
  .byte8 asmp_deflate_neon_extend_raw_scratch_size
  .byte8 asmp_deflate_neon_extend_raw_scratch_align
  .byte8 asmp_deflate_raw_fixed_neon_extend
  .byte8 asmp_deflate_raw_stored_neon_extend
  .byte8 asmp_deflate_raw_auto_neon_extend
