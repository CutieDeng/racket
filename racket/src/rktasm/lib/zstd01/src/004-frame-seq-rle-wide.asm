// ============================================================
// 004-frame-seq-rle-wide.asm - wider RLE sequence match lengths
// ============================================================
//
// This step keeps the literal-only compressed block as the complete
// fallback, then extends the single-sequence RLE encoder:
//
//   input = one repeated byte, length 4..259
//   literals = first byte
//   sequence = LL code 1, OF code 0, ML code selected from zstd ML ranges
//
// The LL/OF/ML tables are emitted in zstd RLE mode. For ML codes 32..43, the
// one-byte sequence bitstream stores ML extra bits followed by the end mark.
// Larger matches need a multi-byte bitstream and are left for the next step.

.function zstd04_bound_inner (
  in: x.src_len,
  out: x.bound
)
entry:
  ubfm x.extra, x.src_len, #12, #63
  add x.bound, x.src_len, x.extra
  add x.bound, x.bound, #64
  ret
.end

.function zstd04_write_u24 (
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

.function zstd04_write_u16 (
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

.function zstd04_copy_bytes (
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

.function zstd04_write_frame_header (
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

.function zstd04_write_empty_block (
  inout: x.out
)
entry:
  mov x.header, #1
  .inline zstd04_write_u24 (x.out=x.out, x.value=x.header)
  ret
.end

.function zstd04_lit_header_size (
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

.function zstd04_write_litonly_block (
  inout: x.out, x.in,
  in: x.block_len, x.last
)
entry:
  .inline zstd04_lit_header_size (x.block_len=x.block_len, x.header_size=x.lit_header_size)
  add x.content_size, x.block_len, x.lit_header_size
  add x.content_size, x.content_size, #1

  add x.header, x.content_size, x.content_size
  add x.header, x.header, x.header
  add x.header, x.header, x.header
  orr x.header, x.header, #4
  orr x.header, x.header, x.last
  .inline zstd04_write_u24 (x.out=x.out, x.value=x.header)

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
  .inline zstd04_copy_bytes (x.out=x.out, x.in=x.in, x.count=x.count)

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
  .inline zstd04_write_u16 (x.out=x.out, x.value=x.header)
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

.function zstd04_compress_litonly_frame (
  in: x.dst, x.src, x.src_len,
  out: x.written
)
entry:
  mov x.out, x.dst
  mov x.in, x.src
  mov x.remaining, x.src_len
  .inline zstd04_write_frame_header (x.out=x.out, x.src_len=x.src_len)

  cbnz x.remaining, block_loop
  .inline zstd04_write_empty_block (x.out=x.out)
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
  .inline zstd04_write_litonly_block (x.out=x.out, x.in=x.in, x.block_len=x.block_len, x.last=x.last)
  sub x.remaining, x.remaining, x.block_len
  cbnz x.remaining, block_loop
  b frame_done

frame_done:
  sub x.written, x.out, x.dst
  ret
.end

.function zstd04_all_equal_wide (
  in: x.src, x.src_len,
  out: w.ok
)
entry:
  mov w.ok, #0
  cmp x.src_len, #4
  b.lo done
  cmp x.src_len, #259
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

.function zstd04_match_length_code (
  in: x.match_len,
  out: x.ml_code, x.ml_extra, x.ml_extra_bits
)
entry:
  cmp x.match_len, #35
  b.hs ml32
  sub x.ml_code, x.match_len, #3
  mov x.ml_extra, #0
  mov x.ml_extra_bits, #0
  ret

ml32:
  cmp x.match_len, #37
  b.hs ml33
  mov x.ml_code, #32
  sub x.ml_extra, x.match_len, #35
  mov x.ml_extra_bits, #1
  ret

ml33:
  cmp x.match_len, #39
  b.hs ml34
  mov x.ml_code, #33
  sub x.ml_extra, x.match_len, #37
  mov x.ml_extra_bits, #1
  ret

ml34:
  cmp x.match_len, #41
  b.hs ml35
  mov x.ml_code, #34
  sub x.ml_extra, x.match_len, #39
  mov x.ml_extra_bits, #1
  ret

ml35:
  cmp x.match_len, #43
  b.hs ml36
  mov x.ml_code, #35
  sub x.ml_extra, x.match_len, #41
  mov x.ml_extra_bits, #1
  ret

ml36:
  cmp x.match_len, #47
  b.hs ml37
  mov x.ml_code, #36
  sub x.ml_extra, x.match_len, #43
  mov x.ml_extra_bits, #2
  ret

ml37:
  cmp x.match_len, #51
  b.hs ml38
  mov x.ml_code, #37
  sub x.ml_extra, x.match_len, #47
  mov x.ml_extra_bits, #2
  ret

ml38:
  cmp x.match_len, #59
  b.hs ml39
  mov x.ml_code, #38
  sub x.ml_extra, x.match_len, #51
  mov x.ml_extra_bits, #3
  ret

ml39:
  cmp x.match_len, #67
  b.hs ml40
  mov x.ml_code, #39
  sub x.ml_extra, x.match_len, #59
  mov x.ml_extra_bits, #3
  ret

ml40:
  cmp x.match_len, #83
  b.hs ml41
  mov x.ml_code, #40
  sub x.ml_extra, x.match_len, #67
  mov x.ml_extra_bits, #4
  ret

ml41:
  cmp x.match_len, #99
  b.hs ml42
  mov x.ml_code, #41
  sub x.ml_extra, x.match_len, #83
  mov x.ml_extra_bits, #4
  ret

ml42:
  cmp x.match_len, #131
  b.hs ml43
  mov x.ml_code, #42
  sub x.ml_extra, x.match_len, #99
  mov x.ml_extra_bits, #5
  ret

ml43:
  mov x.ml_code, #43
  sub x.ml_extra, x.match_len, #131
  mov x.ml_extra_bits, #7
  ret
.end

.function zstd04_write_seqrle_block (
  inout: x.out,
  in: x.src, x.src_len
)
entry:
  mov x.header, #0x45
  .inline zstd04_write_u24 (x.out=x.out, x.value=x.header)

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

  sub x.match_len, x.src_len, #1
  .inline zstd04_match_length_code (x.match_len=x.match_len, x.ml_code=x.ml_code, x.ml_extra=x.ml_extra, x.ml_extra_bits=x.ml_extra_bits)
  strb w.ml_code, [x.out]
  add x.out, x.out, #1

  mov w.byte, #1
  cbz x.ml_extra_bits, write_bitstream
  lsl x.byte, x.byte, x.ml_extra_bits
  orr x.byte, x.byte, x.ml_extra

write_bitstream:
  strb w.byte, [x.out]
  add x.out, x.out, #1
  ret
.end

.function zstd04_compress_seqrle_frame (
  in: x.dst, x.src, x.src_len,
  out: x.written
)
entry:
  .save all

  .inline zstd04_all_equal_wide (x.src=x.src, x.src_len=x.src_len, w.ok=w.ok)
  cbz w.ok, fallback_litonly

  mov x.out, x.dst
  .inline zstd04_write_frame_header (x.out=x.out, x.src_len=x.src_len)
  .inline zstd04_write_seqrle_block (x.out=x.out, x.src=x.src, x.src_len=x.src_len)
  sub x.written, x.out, x.dst
  b done

fallback_litonly:
  .call zstd04_compress_litonly_frame (
    x.dst=x.dst,
    x.src=x.src,
    x.src_len=x.src_len,
    x.written=x.written
  )

done:
  .restore all
  ret
.end

.function asmp_zstd_compress_seqrle_wide_bound export profile=c-aapcs64 (
  in: x.src_len,
  out: x.bound
)
entry:
  .inline zstd04_bound_inner (x.src_len=x.src_len, x.bound=x.bound)
  ret
.end

.function asmp_zstd_compress_seqrle_wide_scratch_size export profile=c-aapcs64 (
  out: x.size
)
entry:
  mov x.size, #0
  ret
.end

.function asmp_zstd_compress_seqrle_wide_scratch_align export profile=c-aapcs64 (
  out: x.align
)
entry:
  mov x.align, #1
  ret
.end

.function asmp_zstd_compress_seqrle_wide export profile=c-aapcs64 (
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
  .inline zstd04_bound_inner (x.src_len=x.src_len, x.bound=x.required)
  cmp x.dst_cap, x.required
  b.lo dst_too_small

  .call zstd04_compress_seqrle_frame (
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
