// ============================================================
// 020-deflate-dynamic-litonly.asm - literal-only dynamic Huffman deflate
// ============================================================
//
// This is the first assembly milestone for dynamic-Huffman blocks. It mirrors
// lib/deflate01/dynamic-huffman-reference.rkt:
//   - raw deflate stream only, no zlib/gzip wrapper and no checksum
//   - one final BTYPE=10 dynamic block
//   - literal-only payload, no LZ77 matches and no distance symbols
//   - complete literal/length tree:
//       symbols 0..225   length 8
//       symbols 226..285 length 9
//   - code-length tree:
//       symbols 0..15 length 4
//       symbols 16..18 unused
//
// It is intentionally not a compression-quality implementation. Its purpose is
// to make dynamic block header emission, canonical codes, and deflate bit order
// inspectable in the new .asm syntax before adding frequency-driven tree build.

// ------------------------------------------------------------
// dh_flush8
// ------------------------------------------------------------
.function dh_flush8 (inout: x.out, x.bitbuf, w.bit_count)
entry:
flush_loop:
  cmp w.bit_count, #8
  b.lt flush_done
  strb w.bitbuf, [x.out]
  add x.out, x.out, #1
  ubfm x.bitbuf, x.bitbuf, #8, #63
  sub w.bit_count, w.bit_count, #8
  b flush_loop
flush_done:
  .return
.end

// ------------------------------------------------------------
// dh_write_raw
// ------------------------------------------------------------
.function dh_write_raw (in: x.bits, w.nbits, inout: x.out, x.bitbuf, w.bit_count)
entry:
  lsl x.tmp, x.bits, x.bit_count
  orr x.bitbuf, x.bitbuf, x.tmp
  add w.bit_count, w.bit_count, w.nbits
  .inline dh_flush8 (x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .return
.end

// ------------------------------------------------------------
// dh_write_huff
// Input w.code is the canonical code in ordinary MSB-first form. Deflate
// transmits Huffman codes least-significant bit first, so reverse before
// writing raw bits.
// ------------------------------------------------------------
.function dh_write_huff (inout: w.code, x.out, x.bitbuf, w.bit_count, in: w.nbits)
entry:
  rbit w.code, w.code
  mov w.tmp, #32
  sub w.tmp, w.tmp, w.nbits
  lsr w.code, w.code, w.tmp
  .inline dh_write_raw (x.bits=x.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .return
.end

// ------------------------------------------------------------
// deflate_dynamic_litonly_aarch64_asm
// ------------------------------------------------------------
.function deflate_dynamic_litonly_aarch64_asm export profile=c-aapcs64 visibility=hidden no-header (
  in: x.dst, x.src, x.src_len,
  out: x.written
)
entry:
  .save all

  mov x.dst_base, x.dst
  mov x.out, x.dst
  mov x.bitbuf, #0
  mov w.bit_count, #0

  // BFINAL=1, BTYPE=10.
  mov x.bits, #5
  mov w.nbits, #3
  .inline dh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  // HLIT=29 => 286 literal/length codes.
  mov x.bits, #29
  mov w.nbits, #5
  .inline dh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  // HDIST=0 => one distance code.
  mov x.bits, #0
  mov w.nbits, #5
  .inline dh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  // HCLEN=15 => all nineteen code-length code lengths follow.
  mov x.bits, #15
  mov w.nbits, #4
  .inline dh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  // Code-length alphabet order starts with 16,17,18. Those three are unused.
  mov x.count, #3
cl_zero_loop:
  mov x.bits, #0
  mov w.nbits, #3
  .inline dh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  subs x.count, x.count, #1
  b.ne cl_zero_loop

  // The remaining symbols in the permuted order are 0..15, each length 4.
  mov x.count, #16
cl_four_loop:
  mov x.bits, #4
  mov w.nbits, #3
  .inline dh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  subs x.count, x.count, #1
  b.ne cl_four_loop

  // Literal/length code lengths: symbols 0..225 have length 8.
  // The code-length tree is canonical with symbols 0..15 all length 4, so
  // emitting length value 8 means writing code symbol 8 with four bits.
  mov x.count, #226
ll_len8_loop:
  mov w.code, #8
  mov w.nbits, #4
  .inline dh_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  subs x.count, x.count, #1
  b.ne ll_len8_loop

  // Literal/length code lengths: symbols 226..285 have length 9.
  mov x.count, #60
ll_len9_loop:
  mov w.code, #9
  mov w.nbits, #4
  .inline dh_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  subs x.count, x.count, #1
  b.ne ll_len9_loop

  // Single distance code length 0: no distance codes are used by this block.
  mov w.code, #0
  mov w.nbits, #4
  .inline dh_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  mov x.pos, #0
literal_loop:
  cmp x.pos, x.src_len
  b.hs literal_done
  ldrb w.lit, [x.src, x.pos]
  cmp w.lit, #226
  b.hs literal_code9

  // Canonical code for symbols 0..225 is the symbol value, length 8.
  mov w.code, w.lit
  mov w.nbits, #8
  .inline dh_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  add x.pos, x.pos, #1
  b literal_loop

literal_code9:
  // Canonical code for symbols 226..285 is symbol + 226, length 9.
  add w.code, w.lit, #226
  mov w.nbits, #9
  .inline dh_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  add x.pos, x.pos, #1
  b literal_loop

literal_done:
  // End-of-block symbol 256 has canonical code 482, length 9.
  mov w.code, #482
  mov w.nbits, #9
  .inline dh_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  cbz w.bit_count, return_size
  strb w.bitbuf, [x.out]
  add x.out, x.out, #1

return_size:
  sub x.written, x.out, x.dst_base
  .restore all
  ret
.end

.function asmp_deflate_raw_dynamic_litonly_bound export profile=c-aapcs64 (
  in: x.src_len,
  out: x.bound
)
entry:
  ubfm x.extra, x.src_len, #3, #63
  add x.bound, x.src_len, x.extra
  add x.bound, x.bound, #192
  ret
.end

.function asmp_deflate_raw_dynamic_litonly export profile=c-aapcs64 (
  in: x.dst, x.dst_cap, x.dst_len, x.src, x.src_len,
  out: w.status
)
entry:
  .save all

  cbz x.dst, public_bad_argument
  cbz x.dst_len, public_bad_argument
  cbz x.src_len, public_src_ok
  cbz x.src, public_bad_argument

public_src_ok:
  ubfm x.required, x.src_len, #3, #63
  add x.required, x.src_len, x.required
  add x.required, x.required, #192
  cmp x.dst_cap, x.required
  b.lo public_dst_too_small

  .call deflate_dynamic_litonly_aarch64_asm (
    x.dst=x.dst,
    x.src=x.src,
    x.src_len=x.src_len,
    x.written=x.written
  )

  str x.written, [x.dst_len]
  mov w.status, #0
  b public_done

public_dst_too_small:
  str xzr, [x.dst_len]
  mov w.status, #1
  b public_done

public_bad_argument:
  mov w.status, #3
  b public_done

public_done:
  .restore all
  ret
.end
