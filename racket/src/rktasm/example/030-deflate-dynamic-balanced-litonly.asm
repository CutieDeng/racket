// ============================================================
// 030-deflate-dynamic-balanced-litonly.asm - native dynamic pipeline MVP
// ============================================================
//
// This version wires the native dynamic-Huffman scaffolding together:
//   021: literal/length frequency histogram
//   022: balanced literal/length code lengths
//   028: canonical codes
//   029: deflate bit-order codes
//
// It still emits literal-only payloads and uses a deliberately simple dynamic
// header: the code-length tree is complete for symbols 0..15 with length 4, so
// the 286 literal/length lengths and the single distance length are emitted
// directly without repeat symbols 16..18. That keeps the stream valid and easy
// to inspect while postponing compact code-length RLE.

.extern asmp_deflate_dynamic_litfreq_count
.extern asmp_deflate_dynamic_litlen_balanced
.extern asmp_deflate_dynamic_canonical_codes
.extern asmp_deflate_dynamic_reverse_codes

// Scratch layout:
//   +0      ll_freq[286]      uint32_t  1144 bytes
//   +1144   ll_len[286]       uint8_t    286 bytes
//   +1430   ll_code[286]      uint16_t   572 bytes
//   +2002   ll_bit_code[286]  uint16_t   572 bytes
//   +2576   canon_scratch                 128 bytes, 4-byte aligned

// ------------------------------------------------------------
// bdh_flush8
// ------------------------------------------------------------
.function bdh_flush8 (inout: x.out, x.bitbuf, w.bit_count)
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
// bdh_write_raw
// ------------------------------------------------------------
.function bdh_write_raw (in: x.bits, w.nbits, inout: x.out, x.bitbuf, w.bit_count)
entry:
  lsl x.tmp, x.bits, x.bit_count
  orr x.bitbuf, x.bitbuf, x.tmp
  add w.bit_count, w.bit_count, w.nbits
  .inline bdh_flush8 (x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .return
.end

// ------------------------------------------------------------
// bdh_write_huff
// ------------------------------------------------------------
.function bdh_write_huff (inout: w.code, x.out, x.bitbuf, w.bit_count, in: w.nbits)
entry:
  rbit w.code, w.code
  mov w.tmp, #32
  sub w.tmp, w.tmp, w.nbits
  lsr w.code, w.code, w.tmp
  .inline bdh_write_raw (x.bits=x.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  .return
.end

// ------------------------------------------------------------
// deflate_dynamic_balanced_litonly_aarch64_asm
// ------------------------------------------------------------
.function deflate_dynamic_balanced_litonly_aarch64_asm (
  in: x.dst, x.src, x.src_len, x.scratch,
  out: x.written, w.status
)
entry:
  .save all
  mov x29, sp

  mov x.freq_ptr, x.scratch
  add x.len_ptr, x.scratch, #1144
  add x.code_ptr, x.scratch, #1430
  add x.bit_code_ptr, x.scratch, #2002
  add x.canon_scratch, x.scratch, #2576

  mov x0, x.src
  mov x1, x.src_len
  mov x2, x.freq_ptr
  mov x3, #1144
  bl asmp_deflate_dynamic_litfreq_count
  mov w.status, w0
  cbnz w.status, return_status

  mov x0, x.freq_ptr
  mov x1, #1144
  mov x2, x.len_ptr
  mov x3, #286
  bl asmp_deflate_dynamic_litlen_balanced
  mov w.status, w0
  cbnz w.status, return_status

  mov x0, x.len_ptr
  mov x1, #286
  mov x2, x.code_ptr
  mov x3, #572
  mov x4, x.canon_scratch
  mov x5, #128
  bl asmp_deflate_dynamic_canonical_codes
  mov w.status, w0
  cbnz w.status, return_status

  mov x0, x.len_ptr
  mov x1, #286
  mov x2, x.code_ptr
  mov x3, #572
  mov x4, x.bit_code_ptr
  mov x5, #572
  bl asmp_deflate_dynamic_reverse_codes
  mov w.status, w0
  cbnz w.status, return_status

  mov x.dst_base, x.dst
  mov x.out, x.dst
  mov x.bitbuf, #0
  mov w.bit_count, #0

  // BFINAL=1, BTYPE=10.
  mov x.bits, #5
  mov w.nbits, #3
  .inline bdh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  // HLIT=29 => 286 literal/length codes.
  mov x.bits, #29
  mov w.nbits, #5
  .inline bdh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  // HDIST=0 => one distance code.
  mov x.bits, #0
  mov w.nbits, #5
  .inline bdh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  // HCLEN=15 => all nineteen code-length code lengths follow.
  mov x.bits, #15
  mov w.nbits, #4
  .inline bdh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  // Code-length alphabet order starts with 16,17,18. Those three are unused.
  mov x.count, #3
cl_zero_loop:
  mov x.bits, #0
  mov w.nbits, #3
  .inline bdh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  subs x.count, x.count, #1
  b.ne cl_zero_loop

  // The remaining symbols in the permuted order are 0..15, each length 4.
  mov x.count, #16
cl_four_loop:
  mov x.bits, #4
  mov w.nbits, #3
  .inline bdh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  subs x.count, x.count, #1
  b.ne cl_four_loop

  // Emit all literal/length code lengths with the simple 4-bit code-length tree.
  mov x.len_cursor, x.len_ptr
  mov x.count, #286
ll_len_loop:
  ldrb w.code, [x.len_cursor]
  mov w.nbits, #4
  .inline bdh_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  add x.len_cursor, x.len_cursor, #1
  subs x.count, x.count, #1
  b.ne ll_len_loop

  // Single distance code length 0: no distance codes are used by this block.
  mov w.code, #0
  mov w.nbits, #4
  .inline bdh_write_huff (w.code=w.code, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  mov x.pos, #0
literal_loop:
  cmp x.pos, x.src_len
  b.hs literal_done
  ldrb w.lit, [x.src, x.pos]

  add x.table_offset, x.lit, x.lit
  add x.table_entry, x.bit_code_ptr, x.table_offset
  ldrh w.bits, [x.table_entry]

  add x.table_entry, x.len_ptr, x.lit
  ldrb w.nbits, [x.table_entry]

  .inline bdh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)
  add x.pos, x.pos, #1
  b literal_loop

literal_done:
  ldrh w.bits, [x.bit_code_ptr, #512]
  ldrb w.nbits, [x.len_ptr, #256]
  .inline bdh_write_raw (x.bits=x.bits, w.nbits=w.nbits, x.out=x.out, x.bitbuf=x.bitbuf, w.bit_count=w.bit_count)

  cbz w.bit_count, return_ok
  strb w.bitbuf, [x.out]
  add x.out, x.out, #1

return_ok:
  sub x.written, x.out, x.dst_base
  mov w.status, #0
  b return_done

return_status:
  mov x.written, #0

return_done:
  .restore all
  ret
.end

.function asmp_deflate_raw_dynamic_balanced_bound export profile=c-aapcs64 (
  in: x.src_len,
  out: x.bound
)
entry:
  ubfm x.extra, x.src_len, #3, #63
  add x.bound, x.src_len, x.extra
  add x.bound, x.bound, #192
  ret
.end

.function asmp_deflate_raw_dynamic_balanced_scratch_size export profile=c-aapcs64 (
  out: x.size
)
entry:
  mov x.size, #2704
  ret
.end

.function asmp_deflate_raw_dynamic_balanced_scratch_align export profile=c-aapcs64 (
  out: x.align
)
entry:
  mov x.align, #16
  ret
.end

.function asmp_deflate_raw_dynamic_balanced export profile=c-aapcs64 (
  in: x.dst, x.dst_cap, x.dst_len, x.src, x.src_len, x.scratch, x.scratch_len,
  out: w.status
)
entry:
  .save all

  cbz x.dst, public_bad_argument
  cbz x.dst_len, public_bad_argument
  cbz x.scratch, public_bad_argument
  cbz x.src_len, public_src_ok
  cbz x.src, public_bad_argument

public_src_ok:
  mov x.required_scratch, #2704
  cmp x.scratch_len, x.required_scratch
  b.lo public_scratch_too_small

  ubfm x.required, x.src_len, #3, #63
  add x.required, x.src_len, x.required
  add x.required, x.required, #192
  cmp x.dst_cap, x.required
  b.lo public_dst_too_small

  .call deflate_dynamic_balanced_litonly_aarch64_asm (
    x.dst=x.dst,
    x.src=x.src,
    x.src_len=x.src_len,
    x.scratch=x.scratch,
    x.written=x.written,
    w.status=w.status
  )
  cbnz w.status, public_zero_done

  str x.written, [x.dst_len]
  b public_done

public_dst_too_small:
  mov w.status, #1
  b public_zero_done

public_scratch_too_small:
  mov w.status, #2
  b public_zero_done

public_bad_argument:
  mov w.status, #3
  b public_done

public_zero_done:
  str xzr, [x.dst_len]
  b public_done

public_done:
  .restore all
  ret
.end
