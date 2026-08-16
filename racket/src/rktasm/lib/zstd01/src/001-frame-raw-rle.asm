// ============================================================
// 001-frame-raw-rle.asm - minimal zstd frame writer
// ============================================================
//
// Phase 0/1 zstd encoder:
//   - standard zstd magic number
//   - single-segment frame with 8-byte content size
//   - raw blocks and RLE blocks
//   - no dictionary, no checksum, no compressed sequence section yet
//
// Public contract:
//   int asmp_zstd_compress_default(uint8_t *dst, uint64_t dst_cap,
//                                  uint64_t *dst_len,
//                                  const uint8_t *src, uint64_t src_len,
//                                  void *scratch, uint64_t scratch_len);

.function zstd01_bound_inner (
  in: x.src_len,
  out: x.bound
)
entry:
  movz x.block_mask, #0xffff
  movk x.block_mask, #0x1, lsl #16
  add x.blocks, x.src_len, x.block_mask
  ubfm x.blocks, x.blocks, #17, #63
  cbnz x.blocks, have_blocks
  mov x.blocks, #1

have_blocks:
  add x.block_headers, x.blocks, x.blocks
  add x.block_headers, x.block_headers, x.blocks
  add x.bound, x.src_len, x.block_headers
  add x.bound, x.bound, #13
  ret
.end

.function zstd01_write_u24 (
  inout: x.out,
  in: x.value
)
entry:
  strb w.value, [x.out]
  add x.out, x.out, #1
  ubfm x.tmp, x.value, #8, #63
  strb w.tmp, [x.out]
  add x.out, x.out, #1
  ubfm x.tmp, x.value, #16, #63
  strb w.tmp, [x.out]
  add x.out, x.out, #1
  ret
.end

.function zstd01_copy_bytes (
  inout: x.out, x.in, x.count
)
entry:
copy_loop:
  cbz x.count, copy_done
  ldrb w.byte, [x.in]
  strb w.byte, [x.out]
  add x.in, x.in, #1
  add x.out, x.out, #1
  sub x.count, x.count, #1
  b copy_loop

copy_done:
  ret
.end

.function zstd01_write_frame_header (
  inout: x.out,
  in: x.src_len
)
entry:
  // Magic number 0xFD2FB528, little-endian.
  mov w.byte, #0x28
  strb w.byte, [x.out]
  add x.out, x.out, #1
  mov w.byte, #0xb5
  strb w.byte, [x.out]
  add x.out, x.out, #1
  mov w.byte, #0x2f
  strb w.byte, [x.out]
  add x.out, x.out, #1
  mov w.byte, #0xfd
  strb w.byte, [x.out]
  add x.out, x.out, #1

  // Frame header descriptor:
  //   Frame_Content_Size_Flag = 3 (8 bytes)
  //   Single_Segment_Flag = 1
  //   no dictionary id, no checksum
  mov w.byte, #0xe0
  strb w.byte, [x.out]
  add x.out, x.out, #1

  // 8-byte frame content size, little-endian. macOS/AArch64 allows unaligned
  // integer stores, and this path is native-arm64 only.
  str x.src_len, [x.out]
  add x.out, x.out, #8
  ret
.end

.function zstd01_write_empty_block (
  inout: x.out
)
entry:
  mov x.header, #1
  .inline zstd01_write_u24 (x.out=x.out, x.value=x.header)
  ret
.end

.function zstd01_write_rle_block (
  inout: x.out,
  in: x.block_len, x.last, w.rle_byte
)
entry:
  add x.header, x.block_len, x.block_len
  add x.header, x.header, x.header
  add x.header, x.header, x.header
  orr x.header, x.header, #2
  orr x.header, x.header, x.last
  .inline zstd01_write_u24 (x.out=x.out, x.value=x.header)
  strb w.rle_byte, [x.out]
  add x.out, x.out, #1
  ret
.end

.function zstd01_write_raw_block (
  inout: x.out, x.in,
  in: x.block_len, x.last
)
entry:
  add x.header, x.block_len, x.block_len
  add x.header, x.header, x.header
  add x.header, x.header, x.header
  orr x.header, x.header, x.last
  .inline zstd01_write_u24 (x.out=x.out, x.value=x.header)
  mov x.count, x.block_len
  .inline zstd01_copy_bytes (x.out=x.out, x.in=x.in, x.count=x.count)
  ret
.end

.function zstd01_compress_raw_rle_frame (
  in: x.dst, x.src, x.src_len,
  out: x.written
)
entry:
  mov x.out, x.dst
  mov x.in, x.src
  mov x.remaining, x.src_len
  .inline zstd01_write_frame_header (x.out=x.out, x.src_len=x.src_len)

  cbnz x.remaining, block_loop
  .inline zstd01_write_empty_block (x.out=x.out)
  b frame_done

block_loop:
  movz x.block_max, #0
  movk x.block_max, #0x2, lsl #16
  cmp x.remaining, x.block_max
  b.ls use_remaining
  mov x.block_len, x.block_max
  b have_block_len

use_remaining:
  mov x.block_len, x.remaining
  b have_block_len

have_block_len:
  cmp x.remaining, x.block_len
  cset x.last, eq

  ldrb w.rle_byte, [x.in]
  add x.scan, x.in, #1
  add x.end, x.in, x.block_len

rle_scan_loop:
  cmp x.scan, x.end
  b.hs emit_rle
  ldrb w.byte, [x.scan]
  cmp w.byte, w.rle_byte
  b.ne emit_raw
  add x.scan, x.scan, #1
  b rle_scan_loop

emit_rle:
  .inline zstd01_write_rle_block (x.out=x.out, x.block_len=x.block_len, x.last=x.last, w.rle_byte=w.rle_byte)
  add x.in, x.in, x.block_len
  sub x.remaining, x.remaining, x.block_len
  cbnz x.remaining, block_loop
  b frame_done

emit_raw:
  .inline zstd01_write_raw_block (x.out=x.out, x.in=x.in, x.block_len=x.block_len, x.last=x.last)
  sub x.remaining, x.remaining, x.block_len
  cbnz x.remaining, block_loop
  b frame_done

frame_done:
  sub x.written, x.out, x.dst
  ret
.end

.function asmp_zstd_compress_bound export profile=c-aapcs64 (
  in: x.src_len,
  out: x.bound
)
entry:
  .inline zstd01_bound_inner (x.src_len=x.src_len, x.bound=x.bound)
  ret
.end

.function asmp_zstd_scratch_size export profile=c-aapcs64 (
  out: x.size
)
entry:
  mov x.size, #0
  ret
.end

.function asmp_zstd_scratch_align export profile=c-aapcs64 (
  out: x.align
)
entry:
  mov x.align, #1
  ret
.end

.function asmp_zstd_compress_default export profile=c-aapcs64 (
  in: x.dst, x.dst_cap, x.dst_len, x.src, x.src_len, x.scratch, x.scratch_len,
  out: w.status
)
entry:
  .save all

  cbz x.dst, bad_argument
  cbz x.dst_len, bad_argument
  cbz x.src_len, src_ok
  cbz x.src, bad_argument

src_ok:
  .inline zstd01_bound_inner (x.src_len=x.src_len, x.bound=x.required)
  cmp x.dst_cap, x.required
  b.lo dst_too_small

  .call zstd01_compress_raw_rle_frame (
    x.dst=x.dst,
    x.src=x.src,
    x.src_len=x.src_len,
    x.written=x.written
  )
  str x.written, [x.dst_len]
  mov w.status, #0
  b done

dst_too_small:
  str xzr, [x.dst_len]
  mov w.status, #1
  b done

bad_argument:
  mov w.status, #3
  b done

done:
  .restore all
  ret
.end
