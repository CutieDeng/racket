// ============================================================
// 041-deflate-dynamic-bllen-huffman.asm - frequency BL lengths
// ============================================================
//
// Builds Deflate code-length alphabet Huffman lengths from bl_freq[19].
//
// This is the 19-symbol counterpart to 039.  It uses the same simple O(n^2)
// tree builder and repairs raw depths over Deflate's 7-bit BL limit by
// adjusting bit-length counts and reassigning lengths by frequency.

// Scratch layout, 16-byte aligned:
//   +0      work_freq[38]  uint64_t   304 bytes
//   +304    parent[38]     uint16_t    76 bytes
//   +380    tie[38]        uint16_t    76 bytes
//   total = 456 bytes

.function deflate_dynamic_bllen_huffman_aarch64_asm export profile=c-aapcs64 visibility=hidden no-header (
  in: x.freq_ptr, x.len_ptr, x.scratch_ptr,
  out: w.status
)
entry:
  .save all

  mov x.work_freq_ptr, x.scratch_ptr
  mov x.off, #304
  add x.parent_ptr, x.scratch_ptr, x.off
  mov x.off, #380
  add x.tie_ptr, x.scratch_ptr, x.off

  mov w.root, #0xffff
  mov w.inactive, #0xfffe
  mov w.zero, #0

  mov x.ptr, x.len_ptr
  mov x.remaining, #19

clear_len_loop:
  strb w.zero, [x.ptr]
  add x.ptr, x.ptr, #1
  subs x.remaining, x.remaining, #1
  b.ne clear_len_loop

  mov x.index, #0
  mov x.active_count, #0

init_leaf_loop:
  cmp x.index, #19
  b.hs init_leaf_done

  add x.freq_off, xzr, x.index, lsl #3
  ldr w.freq32, [x.freq_ptr, x.index, lsl #2]
  mov x.freq64, #0
  str x.freq64, [x.work_freq_ptr, x.freq_off]
  strh w.inactive, [x.parent_ptr, x.index, lsl #1]
  strh w.zero, [x.tie_ptr, x.index, lsl #1]

  cbz w.freq32, init_leaf_next
  mov x.freq64, x.freq32
  str x.freq64, [x.work_freq_ptr, x.freq_off]
  strh w.root, [x.parent_ptr, x.index, lsl #1]
  strh w.index, [x.tie_ptr, x.index, lsl #1]
  add x.active_count, x.active_count, #1

init_leaf_next:
  add x.index, x.index, #1
  b init_leaf_loop

init_leaf_done:
  cbz x.active_count, bad_argument
  cmp x.active_count, #1
  b.ne build_tree_start

  mov x.index, #0

find_dummy_loop:
  cmp x.index, #19
  b.hs bad_argument
  ldrh w.parent, [x.parent_ptr, x.index, lsl #1]
  cmp w.parent, w.inactive
  b.eq add_dummy
  add x.index, x.index, #1
  b find_dummy_loop

add_dummy:
  mov x.freq64, #1
  add x.freq_off, xzr, x.index, lsl #3
  str x.freq64, [x.work_freq_ptr, x.freq_off]
  strh w.root, [x.parent_ptr, x.index, lsl #1]
  strh w.index, [x.tie_ptr, x.index, lsl #1]
  add x.active_count, x.active_count, #1

build_tree_start:
  mov x.next_node, #19
  mov x.remaining, x.active_count

build_tree_loop:
  cmp x.remaining, #1
  b.ls compute_lengths_start

  mov x.best, #0
  mov x.best_set, #0
  mov x.scan, #0

select_first_loop:
  cmp x.scan, x.next_node
  b.hs select_second_start
  ldrh w.parent, [x.parent_ptr, x.scan, lsl #1]
  cmp w.parent, w.root
  b.ne select_first_next

  add x.freq_off, xzr, x.scan, lsl #3
  ldr x.scan_freq, [x.work_freq_ptr, x.freq_off]
  ldrh w.scan_tie, [x.tie_ptr, x.scan, lsl #1]

  cbz x.best_set, take_first
  cmp x.scan_freq, x.best_freq
  b.lo take_first
  b.hi select_first_next
  cmp w.scan_tie, w.best_tie
  b.hs select_first_next

take_first:
  mov x.best, x.scan
  mov x.best_freq, x.scan_freq
  mov w.best_tie, w.scan_tie
  mov x.best_set, #1
  b select_first_next

select_first_next:
  add x.scan, x.scan, #1
  b select_first_loop

select_second_start:
  cbz x.best_set, bad_argument
  mov x.second, #0
  mov x.second_set, #0
  mov x.scan, #0

select_second_loop:
  cmp x.scan, x.next_node
  b.hs merge_pair
  cmp x.scan, x.best
  b.eq select_second_next
  ldrh w.parent, [x.parent_ptr, x.scan, lsl #1]
  cmp w.parent, w.root
  b.ne select_second_next

  add x.freq_off, xzr, x.scan, lsl #3
  ldr x.scan_freq, [x.work_freq_ptr, x.freq_off]
  ldrh w.scan_tie, [x.tie_ptr, x.scan, lsl #1]

  cbz x.second_set, take_second
  cmp x.scan_freq, x.second_freq
  b.lo take_second
  b.hi select_second_next
  cmp w.scan_tie, w.second_tie
  b.hs select_second_next

take_second:
  mov x.second, x.scan
  mov x.second_freq, x.scan_freq
  mov w.second_tie, w.scan_tie
  mov x.second_set, #1
  b select_second_next

select_second_next:
  add x.scan, x.scan, #1
  b select_second_loop

merge_pair:
  cbz x.second_set, bad_argument

  mov w.parent_node, w.next_node
  strh w.parent_node, [x.parent_ptr, x.best, lsl #1]
  strh w.parent_node, [x.parent_ptr, x.second, lsl #1]

  add x.parent_freq, x.best_freq, x.second_freq
  add x.freq_off, xzr, x.next_node, lsl #3
  str x.parent_freq, [x.work_freq_ptr, x.freq_off]
  strh w.root, [x.parent_ptr, x.next_node, lsl #1]

  cmp w.best_tie, w.second_tie
  b.ls use_best_tie
  mov w.parent_tie, w.second_tie
  b store_parent_tie

use_best_tie:
  mov w.parent_tie, w.best_tie
  b store_parent_tie

store_parent_tie:
  strh w.parent_tie, [x.tie_ptr, x.next_node, lsl #1]
  add x.next_node, x.next_node, #1
  sub x.remaining, x.remaining, #1
  b build_tree_loop

compute_lengths_start:
  mov x.symbol, #0
  mov w.max_depth, #0

compute_length_loop:
  cmp x.symbol, #19
  b.hs raw_lengths_done

  ldrh w.parent, [x.parent_ptr, x.symbol, lsl #1]
  cmp w.parent, w.inactive
  b.eq compute_length_next

  mov x.node, x.symbol
  mov w.depth, #0

depth_loop:
  ldrh w.parent, [x.parent_ptr, x.node, lsl #1]
  cmp w.parent, w.root
  b.eq depth_done
  add w.depth, w.depth, #1
  mov x.node, x.parent
  b depth_loop

depth_done:
  strb w.depth, [x.len_ptr, x.symbol]
  cmp w.depth, w.max_depth
  b.ls compute_length_next
  mov w.max_depth, w.depth

compute_length_next:
  add x.symbol, x.symbol, #1
  b compute_length_loop

raw_lengths_done:
  cmp w.max_depth, #7
  b.ls return_ok

repair_start:
  mov x.bl_count_ptr, x.tie_ptr
  mov x.index, #0
  mov w.zero, #0

clear_bl_count_loop:
  cmp x.index, #8
  b.hs count_lengths_start
  str w.zero, [x.bl_count_ptr, x.index, lsl #2]
  add x.index, x.index, #1
  b clear_bl_count_loop

count_lengths_start:
  mov x.symbol, #0
  mov w.overflow, #0

count_lengths_loop:
  cmp x.symbol, #19
  b.hs repair_overflow_start

  ldr w.freq32, [x.freq_ptr, x.symbol, lsl #2]
  cbz w.freq32, count_lengths_next

  ldrb w.len, [x.len_ptr, x.symbol]
  cmp w.len, #7
  b.ls count_in_range

  mov w.len, #7
  add w.overflow, w.overflow, #1

count_in_range:
  ldr w.count_at_len, [x.bl_count_ptr, w.len, uxtw #2]
  add w.count_at_len, w.count_at_len, #1
  str w.count_at_len, [x.bl_count_ptr, w.len, uxtw #2]
  b count_lengths_next

count_lengths_next:
  add x.symbol, x.symbol, #1
  b count_lengths_loop

repair_overflow_start:
  cmp w.overflow, #0
  b.le assign_repaired_start

  mov w.bits, #6

find_repair_bits_loop:
  cbz w.bits, bad_argument
  ldr w.count_at_bits, [x.bl_count_ptr, w.bits, uxtw #2]
  cbnz w.count_at_bits, repair_at_bits
  sub w.bits, w.bits, #1
  b find_repair_bits_loop

repair_at_bits:
  sub w.count_at_bits, w.count_at_bits, #1
  str w.count_at_bits, [x.bl_count_ptr, w.bits, uxtw #2]

  add w.next_bits, w.bits, #1
  ldr w.count_next_bits, [x.bl_count_ptr, w.next_bits, uxtw #2]
  add w.count_next_bits, w.count_next_bits, #2
  str w.count_next_bits, [x.bl_count_ptr, w.next_bits, uxtw #2]

  mov w.max_bits, #7
  ldr w.count_max_bits, [x.bl_count_ptr, w.max_bits, uxtw #2]
  sub w.count_max_bits, w.count_max_bits, #1
  str w.count_max_bits, [x.bl_count_ptr, w.max_bits, uxtw #2]

  sub w.overflow, w.overflow, #2
  b repair_overflow_start

assign_repaired_start:
  mov x.symbol, #0
  mov w.zero, #0
  mov w.assigned, #1

init_assign_markers_loop:
  cmp x.symbol, #19
  b.hs assign_bits_start

  strb w.zero, [x.len_ptr, x.symbol]
  ldr w.freq32, [x.freq_ptr, x.symbol, lsl #2]
  cbz w.freq32, mark_inactive

  strh w.zero, [x.parent_ptr, x.symbol, lsl #1]
  b init_assign_next

mark_inactive:
  strh w.assigned, [x.parent_ptr, x.symbol, lsl #1]
  b init_assign_next

init_assign_next:
  add x.symbol, x.symbol, #1
  b init_assign_markers_loop

assign_bits_start:
  mov w.bits, #7

assign_bits_loop:
  cbz w.bits, return_ok
  ldr w.to_assign, [x.bl_count_ptr, w.bits, uxtw #2]

assign_one_loop:
  cbz w.to_assign, assign_next_bits

  mov x.scan, #0
  mov x.best_set, #0
  mov x.best, #0

select_repair_symbol_loop:
  cmp x.scan, #19
  b.hs assign_selected_symbol

  ldrh w.marker, [x.parent_ptr, x.scan, lsl #1]
  cbnz w.marker, select_repair_next

  ldr w.scan_freq32, [x.freq_ptr, x.scan, lsl #2]
  cbz x.best_set, take_repair_symbol
  cmp w.scan_freq32, w.best_freq32
  b.lo take_repair_symbol
  b.hi select_repair_next
  cmp x.scan, x.best
  b.ls select_repair_next

take_repair_symbol:
  mov x.best, x.scan
  mov w.best_freq32, w.scan_freq32
  mov x.best_set, #1
  b select_repair_next

select_repair_next:
  add x.scan, x.scan, #1
  b select_repair_symbol_loop

assign_selected_symbol:
  cbz x.best_set, bad_argument
  strb w.bits, [x.len_ptr, x.best]
  strh w.assigned, [x.parent_ptr, x.best, lsl #1]
  sub w.to_assign, w.to_assign, #1
  b assign_one_loop

assign_next_bits:
  sub w.bits, w.bits, #1
  b assign_bits_loop

return_ok:
  mov w.status, #0
  b return_done

bad_argument:
  mov w.status, #3

return_done:
  .restore all
  ret
.end

.function asmp_deflate_dynamic_bllen_huffman export profile=c-aapcs64 (
  in: x.freq_ptr, x.freq_len, x.len_ptr, x.len_len, x.scratch_ptr, x.scratch_len,
  out: w.status
)
entry:
  .save all

  cbz x.freq_ptr, public_bad_argument
  cbz x.len_ptr, public_bad_argument
  cbz x.scratch_ptr, public_bad_argument

  mov x.required_freq, #76
  cmp x.freq_len, x.required_freq
  b.lo public_scratch_too_small

  mov x.required_len, #19
  cmp x.len_len, x.required_len
  b.lo public_scratch_too_small

  mov x.required_scratch, #456
  cmp x.scratch_len, x.required_scratch
  b.lo public_scratch_too_small

  .call deflate_dynamic_bllen_huffman_aarch64_asm (
    x.freq_ptr=x.freq_ptr,
    x.len_ptr=x.len_ptr,
    x.scratch_ptr=x.scratch_ptr,
    w.status=w.status
  )
  cbnz w.status, public_done

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
