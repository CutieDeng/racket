// ============================================================
// 008-frame-multirle.asm - multiple RLE-mode run sequences
// ============================================================
//
// This step keeps the previous predefined single-match encoder as the complete
// fallback, then adds the first multi-sequence block shape:
//
//   input = 2..31 runs, each exactly 4 copies of one byte
//   literals = the first byte of every run
//   sequences = repeat N times: LL code 1, OF code 0, ML code 0
//
// The LL/OF/ML tables are emitted in zstd RLE_Mode. Since every sequence has
// no extra bits, the sequence bitstream is just the zstd end mark byte.

.function zstd08_bound_inner (
  in: x.src_len,
  out: x.bound
)
entry:
  ubfm x.extra, x.src_len, #12, #63
  add x.bound, x.src_len, x.extra
  add x.bound, x.bound, #64
  ret
.end

.function zstd08_write_u24 (
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

.function zstd08_write_u16 (
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

.function zstd08_copy_bytes (
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

.function zstd08_write_frame_header (
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

.function zstd08_write_empty_block (
  inout: x.out
)
entry:
  mov x.header, #1
  .inline zstd08_write_u24 (x.out=x.out, x.value=x.header)
  ret
.end

.function zstd08_lit_header_size (
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

.function zstd08_write_litonly_block (
  inout: x.out, x.in,
  in: x.block_len, x.last
)
entry:
  .inline zstd08_lit_header_size (x.block_len=x.block_len, x.header_size=x.lit_header_size)
  add x.content_size, x.block_len, x.lit_header_size
  add x.content_size, x.content_size, #1

  add x.header, x.content_size, x.content_size
  add x.header, x.header, x.header
  add x.header, x.header, x.header
  orr x.header, x.header, #4
  orr x.header, x.header, x.last
  .inline zstd08_write_u24 (x.out=x.out, x.value=x.header)

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
  .inline zstd08_copy_bytes (x.out=x.out, x.in=x.in, x.count=x.count)

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
  .inline zstd08_write_u16 (x.out=x.out, x.value=x.header)
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

.function zstd08_compress_litonly_frame (
  in: x.dst, x.src, x.src_len,
  out: x.written
)
entry:
  mov x.out, x.dst
  mov x.in, x.src
  mov x.remaining, x.src_len
  .inline zstd08_write_frame_header (x.out=x.out, x.src_len=x.src_len)

  cbnz x.remaining, block_loop
  .inline zstd08_write_empty_block (x.out=x.out)
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
  .inline zstd08_write_litonly_block (x.out=x.out, x.in=x.in, x.block_len=x.block_len, x.last=x.last)
  sub x.remaining, x.remaining, x.block_len
  cbnz x.remaining, block_loop
  b frame_done

frame_done:
  sub x.written, x.out, x.dst
  ret
.end

.function zstd08_find_single_match (
  in: x.src, x.src_len,
  out: w.ok, x.prefix_len
)
entry:
  mov w.ok, #0
  mov x.prefix_len, #0
  cmp x.src_len, #4
  b.lo done
  movz x.max_len, #0x2, lsl #16
  cmp x.src_len, x.max_len
  b.hi done

  mov x.candidate, #1
  add x.end, x.src, x.src_len

candidate_loop:
  cmp x.candidate, #16
  b.hs done
  sub x.match_len, x.src_len, x.candidate
  cmp x.match_len, #3
  b.lo done

  add x.prev, x.src, x.candidate
  sub x.prev, x.prev, #1
  ldrb w.match_byte, [x.prev]
  add x.scan, x.src, x.candidate

scan_loop:
  cmp x.scan, x.end
  b.hs found
  ldrb w.byte, [x.scan]
  cmp w.byte, w.match_byte
  b.ne next_candidate
  add x.scan, x.scan, #1
  b scan_loop

next_candidate:
  add x.candidate, x.candidate, #1
  b candidate_loop

found:
  mov x.prefix_len, x.candidate
  mov w.ok, #1

done:
  ret
.end

.function zstd08_match_length_code (
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
  movz x.threshold, #0x103
  cmp x.match_len, x.threshold
  b.hs ml44
  mov x.ml_code, #43
  sub x.ml_extra, x.match_len, #131
  mov x.ml_extra_bits, #7
  ret

ml44:
  movz x.threshold, #0x203
  cmp x.match_len, x.threshold
  b.hs ml45
  mov x.ml_code, #44
  sub x.ml_extra, x.match_len, #259
  mov x.ml_extra_bits, #8
  ret

ml45:
  movz x.threshold, #0x403
  cmp x.match_len, x.threshold
  b.hs ml46
  mov x.ml_code, #45
  sub x.ml_extra, x.match_len, #515
  mov x.ml_extra_bits, #9
  ret

ml46:
  movz x.threshold, #0x803
  cmp x.match_len, x.threshold
  b.hs ml47
  mov x.ml_code, #46
  sub x.ml_extra, x.match_len, #1027
  mov x.ml_extra_bits, #10
  ret

ml47:
  movz x.threshold, #0x1003
  cmp x.match_len, x.threshold
  b.hs ml48
  mov x.ml_code, #47
  sub x.ml_extra, x.match_len, #2051
  mov x.ml_extra_bits, #11
  ret

ml48:
  movz x.threshold, #0x2003
  cmp x.match_len, x.threshold
  b.hs ml49
  mov x.ml_code, #48
  movz x.base, #0x1003
  sub x.ml_extra, x.match_len, x.base
  mov x.ml_extra_bits, #12
  ret

ml49:
  movz x.threshold, #0x4003
  cmp x.match_len, x.threshold
  b.hs ml50
  mov x.ml_code, #49
  movz x.base, #0x2003
  sub x.ml_extra, x.match_len, x.base
  mov x.ml_extra_bits, #13
  ret

ml50:
  movz x.threshold, #0x8003
  cmp x.match_len, x.threshold
  b.hs ml51
  mov x.ml_code, #50
  movz x.base, #0x4003
  sub x.ml_extra, x.match_len, x.base
  mov x.ml_extra_bits, #14
  ret

ml51:
  movz x.threshold, #0x3
  movk x.threshold, #0x1, lsl #16
  cmp x.match_len, x.threshold
  b.hs ml52
  mov x.ml_code, #51
  movz x.base, #0x8003
  sub x.ml_extra, x.match_len, x.base
  mov x.ml_extra_bits, #15
  ret

ml52:
  mov x.ml_code, #52
  sub x.ml_extra, x.match_len, x.threshold
  mov x.ml_extra_bits, #16
  ret
.end

.function zstd08_write_ml_bitstream (
  inout: x.out,
  in: x.ml_extra, x.ml_extra_bits
)
entry:
  mov x.bitstream, #1
  lsl x.bitstream, x.bitstream, x.ml_extra_bits
  orr x.bitstream, x.bitstream, x.ml_extra
  add x.bits_left, x.ml_extra_bits, #1

write_loop:
  strb w.bitstream, [x.out]
  add x.out, x.out, #1
  cmp x.bits_left, #8
  b.ls done
  ubfm x.bitstream, x.bitstream, #8, #63
  sub x.bits_left, x.bits_left, #8
  b write_loop

done:
  ret
.end

.function zstd08_find_predef_single_match (
  in: x.src, x.src_len,
  out: w.ok, x.prefix_len
)
entry:
  .inline zstd08_find_single_match (x.src=x.src, x.src_len=x.src_len, w.ok=w.ok, x.prefix_len=x.prefix_len)
  cbz w.ok, done
  sub x.match_len, x.src_len, x.prefix_len
  cmp x.match_len, #35
  b.lo done
  mov w.ok, #0
  mov x.prefix_len, #0

done:
  ret
.end

.function zstd08_ll_predef_state (
  in: x.ll_code,
  out: x.ll_state
)
entry:
  cmp x.ll_code, #1
  b.ne ll2
  mov x.ll_state, #2
  ret
ll2:
  cmp x.ll_code, #2
  b.ne ll3
  mov x.ll_state, #24
  ret
ll3:
  cmp x.ll_code, #3
  b.ne ll4
  mov x.ll_state, #3
  ret
ll4:
  cmp x.ll_code, #4
  b.ne ll5
  mov x.ll_state, #4
  ret
ll5:
  cmp x.ll_code, #5
  b.ne ll6
  mov x.ll_state, #26
  ret
ll6:
  cmp x.ll_code, #6
  b.ne ll7
  mov x.ll_state, #5
  ret
ll7:
  cmp x.ll_code, #7
  b.ne ll8
  mov x.ll_state, #6
  ret
ll8:
  cmp x.ll_code, #8
  b.ne ll9
  mov x.ll_state, #28
  ret
ll9:
  cmp x.ll_code, #9
  b.ne ll10
  mov x.ll_state, #7
  ret
ll10:
  cmp x.ll_code, #10
  b.ne ll11
  mov x.ll_state, #8
  ret
ll11:
  cmp x.ll_code, #11
  b.ne ll12
  mov x.ll_state, #30
  ret
ll12:
  cmp x.ll_code, #12
  b.ne ll13
  mov x.ll_state, #9
  ret
ll13:
  cmp x.ll_code, #13
  b.ne ll14
  mov x.ll_state, #31
  ret
ll14:
  cmp x.ll_code, #14
  b.ne ll15
  mov x.ll_state, #10
  ret
ll15:
  mov x.ll_state, #53
  ret
.end

.function zstd08_ml_predef_state (
  in: x.ml_code,
  out: x.ml_state
)
entry:
  cmp x.ml_code, #0
  b.ne ml1
  mov x.ml_state, #0
  ret
ml1:
  cmp x.ml_code, #1
  b.ne ml2
  mov x.ml_state, #1
  ret
ml2:
  cmp x.ml_code, #2
  b.ne ml3
  mov x.ml_state, #2
  ret
ml3:
  cmp x.ml_code, #3
  b.ne ml4
  mov x.ml_state, #3
  ret
ml4:
  cmp x.ml_code, #4
  b.ne ml5
  mov x.ml_state, #25
  ret
ml5:
  cmp x.ml_code, #5
  b.ne ml6
  mov x.ml_state, #4
  ret
ml6:
  cmp x.ml_code, #6
  b.ne ml7
  mov x.ml_state, #5
  ret
ml7:
  cmp x.ml_code, #7
  b.ne ml8
  mov x.ml_state, #27
  ret
ml8:
  cmp x.ml_code, #8
  b.ne ml9
  mov x.ml_state, #6
  ret
ml9:
  cmp x.ml_code, #9
  b.ne ml10
  mov x.ml_state, #28
  ret
ml10:
  cmp x.ml_code, #10
  b.ne ml11
  mov x.ml_state, #7
  ret
ml11:
  cmp x.ml_code, #11
  b.ne ml12
  mov x.ml_state, #50
  ret
ml12:
  cmp x.ml_code, #12
  b.ne ml13
  mov x.ml_state, #29
  ret
ml13:
  cmp x.ml_code, #13
  b.ne ml14
  mov x.ml_state, #8
  ret
ml14:
  cmp x.ml_code, #14
  b.ne ml15
  mov x.ml_state, #51
  ret
ml15:
  cmp x.ml_code, #15
  b.ne ml16
  mov x.ml_state, #30
  ret
ml16:
  cmp x.ml_code, #16
  b.ne ml17
  mov x.ml_state, #9
  ret
ml17:
  cmp x.ml_code, #17
  b.ne ml18
  mov x.ml_state, #52
  ret
ml18:
  cmp x.ml_code, #18
  b.ne ml19
  mov x.ml_state, #31
  ret
ml19:
  cmp x.ml_code, #19
  b.ne ml20
  mov x.ml_state, #10
  ret
ml20:
  cmp x.ml_code, #20
  b.ne ml21
  mov x.ml_state, #53
  ret
ml21:
  cmp x.ml_code, #21
  b.ne ml22
  mov x.ml_state, #32
  ret
ml22:
  cmp x.ml_code, #22
  b.ne ml23
  mov x.ml_state, #11
  ret
ml23:
  cmp x.ml_code, #23
  b.ne ml24
  mov x.ml_state, #54
  ret
ml24:
  cmp x.ml_code, #24
  b.ne ml25
  mov x.ml_state, #33
  ret
ml25:
  cmp x.ml_code, #25
  b.ne ml26
  mov x.ml_state, #12
  ret
ml26:
  cmp x.ml_code, #26
  b.ne ml27
  mov x.ml_state, #55
  ret
ml27:
  cmp x.ml_code, #27
  b.ne ml28
  mov x.ml_state, #34
  ret
ml28:
  cmp x.ml_code, #28
  b.ne ml29
  mov x.ml_state, #13
  ret
ml29:
  cmp x.ml_code, #29
  b.ne ml30
  mov x.ml_state, #56
  ret
ml30:
  cmp x.ml_code, #30
  b.ne ml31
  mov x.ml_state, #35
  ret
ml31:
  mov x.ml_state, #14
  ret
.end

.function zstd08_write_predef_bitstream (
  inout: x.out,
  in: x.ll_state, x.ml_state
)
entry:
  strb w.ml_state, [x.out]
  add x.out, x.out, #1

  add x.byte, x.ll_state, x.ll_state
  add x.byte, x.byte, x.byte
  add x.byte, x.byte, x.byte
  strb w.byte, [x.out]
  add x.out, x.out, #1

  ubfm x.byte, x.ll_state, #5, #63
  orr x.byte, x.byte, #2
  strb w.byte, [x.out]
  add x.out, x.out, #1
  ret
.end

.function zstd08_write_predef_singlematch_block (
  inout: x.out,
  in: x.src, x.src_len, x.prefix_len
)
entry:
  sub x.match_len, x.src_len, x.prefix_len
  sub x.ml_code, x.match_len, #3
  .inline zstd08_ll_predef_state (x.ll_code=x.prefix_len, x.ll_state=x.ll_state)
  .inline zstd08_ml_predef_state (x.ml_code=x.ml_code, x.ml_state=x.ml_state)

  add x.content_size, x.prefix_len, #6
  add x.header, x.content_size, x.content_size
  add x.header, x.header, x.header
  add x.header, x.header, x.header
  add x.header, x.header, #5
  .inline zstd08_write_u24 (x.out=x.out, x.value=x.header)

  add x.header, x.prefix_len, x.prefix_len
  add x.header, x.header, x.header
  add x.header, x.header, x.header
  strb w.header, [x.out]
  add x.out, x.out, #1

  mov x.in, x.src
  mov x.count, x.prefix_len
  .inline zstd08_copy_bytes (x.out=x.out, x.in=x.in, x.count=x.count)

  mov w.byte, #1
  strb w.byte, [x.out]
  add x.out, x.out, #1

  mov w.byte, #0
  strb w.byte, [x.out]
  add x.out, x.out, #1

  .inline zstd08_write_predef_bitstream (x.out=x.out, x.ll_state=x.ll_state, x.ml_state=x.ml_state)
  ret
.end

.function zstd08_find_multirle_runs (
  in: x.src, x.src_len,
  out: w.ok, x.seq_count
)
entry:
  mov w.ok, #0
  mov x.seq_count, #0
  cmp x.src_len, #8
  b.lo done
  cmp x.src_len, #124
  b.hi done

  ubfm x.remainder, x.src_len, #0, #1
  cbnz x.remainder, done

  ubfm x.seq_count, x.src_len, #2, #63
  mov x.scan, x.src
  mov x.remaining, x.seq_count

run_loop:
  cbz x.remaining, found
  ldrb w.first, [x.scan]
  add x.ptr, x.scan, #1
  ldrb w.byte, [x.ptr]
  cmp w.byte, w.first
  b.ne done
  add x.ptr, x.scan, #2
  ldrb w.byte, [x.ptr]
  cmp w.byte, w.first
  b.ne done
  add x.ptr, x.scan, #3
  ldrb w.byte, [x.ptr]
  cmp w.byte, w.first
  b.ne done
  add x.scan, x.scan, #4
  sub x.remaining, x.remaining, #1
  b run_loop

found:
  mov w.ok, #1

done:
  ret
.end

.function zstd08_copy_multirle_literals (
  inout: x.out,
  in: x.src, x.seq_count
)
entry:
  mov x.in, x.src
  mov x.remaining, x.seq_count

copy_loop:
  cbz x.remaining, done
  ldrb w.byte, [x.in]
  strb w.byte, [x.out]
  add x.out, x.out, #1
  add x.in, x.in, #4
  sub x.remaining, x.remaining, #1
  b copy_loop

done:
  ret
.end

.function zstd08_write_multirle_block (
  inout: x.out,
  in: x.src, x.seq_count
)
entry:
  add x.content_size, x.seq_count, #7
  add x.header, x.content_size, x.content_size
  add x.header, x.header, x.header
  add x.header, x.header, x.header
  add x.header, x.header, #5
  .inline zstd08_write_u24 (x.out=x.out, x.value=x.header)

  add x.header, x.seq_count, x.seq_count
  add x.header, x.header, x.header
  add x.header, x.header, x.header
  strb w.header, [x.out]
  add x.out, x.out, #1

  .inline zstd08_copy_multirle_literals (x.out=x.out, x.src=x.src, x.seq_count=x.seq_count)

  strb w.seq_count, [x.out]
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

  strb w.byte, [x.out]
  add x.out, x.out, #1

  mov w.byte, #1
  strb w.byte, [x.out]
  add x.out, x.out, #1
  ret
.end

.function zstd08_compress_multirle_frame (
  in: x.dst, x.src, x.src_len,
  out: x.written
)
entry:
  .save all

  .inline zstd08_find_multirle_runs (x.src=x.src, x.src_len=x.src_len, w.ok=w.ok, x.seq_count=x.seq_count)
  cbz w.ok, fallback_predef_singlematch

  mov x.out, x.dst
  .inline zstd08_write_frame_header (x.out=x.out, x.src_len=x.src_len)
  .inline zstd08_write_multirle_block (x.out=x.out, x.src=x.src, x.seq_count=x.seq_count)
  sub x.written, x.out, x.dst
  b done

fallback_predef_singlematch:
  .call zstd08_compress_predef_singlematch_frame (
    x.dst=x.dst,
    x.src=x.src,
    x.src_len=x.src_len,
    x.written=x.written
  )

done:
  .restore all
  ret
.end

.function zstd08_write_singlematch_block (
  inout: x.out,
  in: x.src, x.src_len, x.prefix_len
)
entry:
  sub x.match_len, x.src_len, x.prefix_len
  .inline zstd08_match_length_code (x.match_len=x.match_len, x.ml_code=x.ml_code, x.ml_extra=x.ml_extra, x.ml_extra_bits=x.ml_extra_bits)

  add x.bitstream_bytes, x.ml_extra_bits, #8
  ubfm x.bitstream_bytes, x.bitstream_bytes, #3, #63
  add x.content_size, x.prefix_len, x.bitstream_bytes
  add x.content_size, x.content_size, #6
  add x.header, x.content_size, x.content_size
  add x.header, x.header, x.header
  add x.header, x.header, x.header
  add x.header, x.header, #5
  .inline zstd08_write_u24 (x.out=x.out, x.value=x.header)

  add x.header, x.prefix_len, x.prefix_len
  add x.header, x.header, x.header
  add x.header, x.header, x.header
  strb w.header, [x.out]
  add x.out, x.out, #1

  mov x.in, x.src
  mov x.count, x.prefix_len
  .inline zstd08_copy_bytes (x.out=x.out, x.in=x.in, x.count=x.count)

  mov w.byte, #1
  strb w.byte, [x.out]
  add x.out, x.out, #1

  mov w.byte, #0x54
  strb w.byte, [x.out]
  add x.out, x.out, #1

  strb w.prefix_len, [x.out]
  add x.out, x.out, #1

  mov w.byte, #0
  strb w.byte, [x.out]
  add x.out, x.out, #1

  strb w.ml_code, [x.out]
  add x.out, x.out, #1

  .inline zstd08_write_ml_bitstream (x.out=x.out, x.ml_extra=x.ml_extra, x.ml_extra_bits=x.ml_extra_bits)
  ret
.end

.function zstd08_compress_predef_singlematch_frame (
  in: x.dst, x.src, x.src_len,
  out: x.written
)
entry:
  .save all

  .inline zstd08_find_predef_single_match (x.src=x.src, x.src_len=x.src_len, w.ok=w.ok, x.prefix_len=x.prefix_len)
  cbz w.ok, fallback_singlematch

  mov x.out, x.dst
  .inline zstd08_write_frame_header (x.out=x.out, x.src_len=x.src_len)
  .inline zstd08_write_predef_singlematch_block (x.out=x.out, x.src=x.src, x.src_len=x.src_len, x.prefix_len=x.prefix_len)
  sub x.written, x.out, x.dst
  b done

fallback_singlematch:
  .call zstd08_compress_singlematch_frame (
    x.dst=x.dst,
    x.src=x.src,
    x.src_len=x.src_len,
    x.written=x.written
  )

done:
  .restore all
  ret
.end

.function zstd08_compress_singlematch_frame (
  in: x.dst, x.src, x.src_len,
  out: x.written
)
entry:
  .save all

  .inline zstd08_find_single_match (x.src=x.src, x.src_len=x.src_len, w.ok=w.ok, x.prefix_len=x.prefix_len)
  cbz w.ok, fallback_litonly

  mov x.out, x.dst
  .inline zstd08_write_frame_header (x.out=x.out, x.src_len=x.src_len)
  .inline zstd08_write_singlematch_block (x.out=x.out, x.src=x.src, x.src_len=x.src_len, x.prefix_len=x.prefix_len)
  sub x.written, x.out, x.dst
  b done

fallback_litonly:
  .call zstd08_compress_litonly_frame (
    x.dst=x.dst,
    x.src=x.src,
    x.src_len=x.src_len,
    x.written=x.written
  )

done:
  .restore all
  ret
.end

.function asmp_zstd_compress_multirle_bound export profile=c-aapcs64 (
  in: x.src_len,
  out: x.bound
)
entry:
  .inline zstd08_bound_inner (x.src_len=x.src_len, x.bound=x.bound)
  ret
.end

.function asmp_zstd_compress_multirle_scratch_size export profile=c-aapcs64 (
  out: x.size
)
entry:
  mov x.size, #0
  ret
.end

.function asmp_zstd_compress_multirle_scratch_align export profile=c-aapcs64 (
  out: x.align
)
entry:
  mov x.align, #1
  ret
.end

.function asmp_zstd_compress_multirle export profile=c-aapcs64 (
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
  .inline zstd08_bound_inner (x.src_len=x.src_len, x.bound=x.required)
  cmp x.dst_cap, x.required
  b.lo dst_too_small

  .call zstd08_compress_multirle_frame (
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
