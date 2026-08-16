// ============================================================
// 003-frame-seq-rle.asm - first real zstd sequence section
// ============================================================
//
// This step keeps the 002 literal-only compressed block as the complete
// fallback, then adds one narrow sequence encoder:
//
//   input = one repeated byte, length 4..35
//   literals = first byte
//   sequence = LL code 1, OF code 0, ML code len-4
//
// The LL/OF/ML tables are emitted in zstd RLE mode, so the sequence bitstream
// only needs the end mark byte. This gives us a small, inspectable bridge from
// "compressed block shell" to "actual match sequence".

.function zstd03_bound_inner (
  in: x.src_len,
  out: x.bound
)
entry:
  ubfm x.extra, x.src_len, #12, #63
  add x.bound, x.src_len, x.extra
  add x.bound, x.bound, #64
  ret
.end

.function zstd03_write_u24 (
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

.function zstd03_write_u16 (
  inout: x.out,
  in: x.value
)
entry:
  strb w.value, [x.out]
  add x.out, x.out, #1
  ubfm x.tmp, x.value, #8, #63
  strb w.tmp, [x.out]
  add x.out, x.out, #1
  ret
.end

.function zstd03_copy_bytes (
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

.function zstd03_write_frame_header (
  inout: x.out,
  in: x.src_len
)
entry:
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

  mov w.byte, #0xc0
  strb w.byte, [x.out]
  add x.out, x.out, #1

  mov w.byte, #0x38
  strb w.byte, [x.out]
  add x.out, x.out, #1

  str x.src_len, [x.out]
  add x.out, x.out, #8
  ret
.end

.function zstd03_write_empty_block (
  inout: x.out
)
entry:
  mov x.header, #1
  .inline zstd03_write_u24 (x.out=x.out, x.value=x.header)
  ret
.end

.function zstd03_lit_header_size (
  in: x.block_len,
  out: x.header_size
)
entry:
  mov x.header_size, #1
  cmp x.block_len, #32
  b.lo size_done
  mov x.header_size, #2
  cmp x.block_len, #4096
  b.lo size_done
  mov x.header_size, #3

size_done:
  ret
.end

.function zstd03_write_litonly_block (
  inout: x.out, x.in,
  in: x.block_len, x.last
)
entry:
  .inline zstd03_lit_header_size (x.block_len=x.block_len, x.header_size=x.lit_header_size)
  add x.content_size, x.block_len, x.lit_header_size
  add x.content_size, x.content_size, #1

  add x.header, x.content_size, x.content_size
  add x.header, x.header, x.header
  add x.header, x.header, x.header
  orr x.header, x.header, #4
  orr x.header, x.header, x.last
  .inline zstd03_write_u24 (x.out=x.out, x.value=x.header)

  cmp x.block_len, #32
  b.hs litonly_header_two_or_three

  add x.header, x.block_len, x.block_len
  add x.header, x.header, x.header
  add x.header, x.header, x.header
  strb w.header, [x.out]
  add x.out, x.out, #1
  b litonly_header_done

litonly_header_done:
  mov x.count, x.block_len
  .inline zstd03_copy_bytes (x.out=x.out, x.in=x.in, x.count=x.count)

  mov w.seq_count, #0
  strb w.seq_count, [x.out]
  add x.out, x.out, #1
  ret

litonly_header_two_or_three:
  cmp x.block_len, #4096
  b.hs litonly_header_three

  add x.header, x.block_len, x.block_len
  add x.header, x.header, x.header
  add x.header, x.header, x.header
  add x.header, x.header, x.header
  add x.header, x.header, #4
  .inline zstd03_write_u16 (x.out=x.out, x.value=x.header)
  b litonly_header_done

litonly_header_three:
  add x.header, x.block_len, x.block_len
  add x.header, x.header, x.header
  add x.header, x.header, x.header
  add x.header, x.header, x.header
  add x.header, x.header, #12
  strb w.header, [x.out]
  add x.out, x.out, #1
  ubfm x.header_byte, x.header, #8, #63
  strb w.header_byte, [x.out]
  add x.out, x.out, #1
  ubfm x.header_byte, x.header, #16, #63
  strb w.header_byte, [x.out]
  add x.out, x.out, #1
  b litonly_header_done
.end

.function zstd03_compress_litonly_frame (
  in: x.dst, x.src, x.src_len,
  out: x.written
)
entry:
  mov x.out, x.dst
  mov x.in, x.src
  mov x.remaining, x.src_len
  .inline zstd03_write_frame_header (x.out=x.out, x.src_len=x.src_len)

  cbnz x.remaining, block_loop
  .inline zstd03_write_empty_block (x.out=x.out)
  b frame_done

block_loop:
  movz x.block_max, #0xffff
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
  .inline zstd03_write_litonly_block (x.out=x.out, x.in=x.in, x.block_len=x.block_len, x.last=x.last)
  sub x.remaining, x.remaining, x.block_len
  cbnz x.remaining, block_loop
  b frame_done

frame_done:
  sub x.written, x.out, x.dst
  ret
.end

.function zstd03_all_equal_small (
  in: x.src, x.src_len,
  out: w.ok
)
entry:
  mov w.ok, #0
  cmp x.src_len, #4
  b.lo done
  cmp x.src_len, #35
  b.hi done

  ldrb w.first, [x.src]
  add x.scan, x.src, #1
  add x.end, x.src, x.src_len

scan_loop:
  cmp x.scan, x.end
  b.hs all_equal
  ldrb w.byte, [x.scan]
  cmp w.byte, w.first
  b.ne done
  add x.scan, x.scan, #1
  b scan_loop

all_equal:
  mov w.ok, #1

done:
  ret
.end

.function zstd03_write_seqrle_block (
  inout: x.out,
  in: x.src, x.src_len
)
entry:
  mov x.header, #0x45
  .inline zstd03_write_u24 (x.out=x.out, x.value=x.header)

  mov w.byte, #0x08
  strb w.byte, [x.out]
  add x.out, x.out, #1

  ldrb w.byte, [x.src]
  strb w.byte, [x.out]
  add x.out, x.out, #1

  mov w.byte, #1
  strb w.byte, [x.out]
  add x.out, x.out, #1

  mov w.byte, #0x54
  strb w.byte, [x.out]
  add x.out, x.out, #1

  mov w.byte, #1
  strb w.byte, [x.out]
  add x.out, x.out, #1

  mov w.byte, #0
  strb w.byte, [x.out]
  add x.out, x.out, #1

  sub x.ml_code, x.src_len, #4
  strb w.ml_code, [x.out]
  add x.out, x.out, #1

  mov w.byte, #1
  strb w.byte, [x.out]
  add x.out, x.out, #1
  ret
.end

.function zstd03_compress_seqrle_frame (
  in: x.dst, x.src, x.src_len,
  out: x.written
)
entry:
  .save all

  .inline zstd03_all_equal_small (x.src=x.src, x.src_len=x.src_len, w.ok=w.ok)
  cbz w.ok, fallback_litonly

  mov x.out, x.dst
  .inline zstd03_write_frame_header (x.out=x.out, x.src_len=x.src_len)
  .inline zstd03_write_seqrle_block (x.out=x.out, x.src=x.src, x.src_len=x.src_len)
  sub x.written, x.out, x.dst
  b done

fallback_litonly:
  .call zstd03_compress_litonly_frame (
    x.dst=x.dst,
    x.src=x.src,
    x.src_len=x.src_len,
    x.written=x.written
  )

done:
  .restore all
  ret
.end

.function asmp_zstd_compress_seqrle_bound export profile=c-aapcs64 (
  in: x.src_len,
  out: x.bound
)
entry:
  .inline zstd03_bound_inner (x.src_len=x.src_len, x.bound=x.bound)
  ret
.end

.function asmp_zstd_compress_seqrle_scratch_size export profile=c-aapcs64 (
  out: x.size
)
entry:
  mov x.size, #0
  ret
.end

.function asmp_zstd_compress_seqrle_scratch_align export profile=c-aapcs64 (
  out: x.align
)
entry:
  mov x.align, #1
  ret
.end

.function asmp_zstd_compress_seqrle export profile=c-aapcs64 (
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
  .inline zstd03_bound_inner (x.src_len=x.src_len, x.bound=x.required)
  cmp x.dst_cap, x.required
  b.lo dst_too_small

  .call zstd03_compress_seqrle_frame (
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
