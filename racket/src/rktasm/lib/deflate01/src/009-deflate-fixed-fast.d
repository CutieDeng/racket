;; ============================================================
;; 009-deflate-fixed-fast.d - AArch64 fixed-Huffman deflate core
;; ============================================================
;;
;; Prototype:
;;   uint64_t deflate_fixed_fast_aarch64(uint8_t *dst,
;;                                       const uint8_t *src,
;;                                       uint64_t len,
;;                                       uint32_t *head);
;;
;; Contract:
;;   x0 = output buffer, large enough for a fixed-Huffman deflate stream
;;   x1 = input bytes
;;   x2 = input length, expected to fit in 32 bits for the hash table
;;   x3 = scratch head table, 32768 uint32_t entries
;;   return x0 = bytes written
;;
;; The stream is one raw deflate block with BFINAL=1 and BTYPE=fixed.
;; This is a fast level-1 style compressor:
;;   - 15-bit hash on the next 4 bytes
;;   - one previous candidate per hash bucket
;;   - no lazy parsing
;;   - skipped bytes inside a match are not reinserted
;;
;; The helpers below are intentionally written as inline-able assembly
;; snippets. They expose a current limitation of the assembler DSL: without
;; macro parameters or data directives, high-performance bit writers and
;; code tables have to be expressed as calling-convention-like snippets.

;; ------------------------------------------------------------
;; df_flush8
;; State:
;;   x5 = output cursor
;;   x6 = bit buffer, least-significant bits are pending
;;   w7 = pending bit count
;; Clobbers:
;;   flags
;; ------------------------------------------------------------
(: function df_flush8 (abi leaf) (inline-only))
(: label entry)
(: label flush_loop)
  (cmp w7 8)
  (b.lt flush_done)
  (strb w6 (x5))
  (add x5 x5 1)
  (ubfm x6 x6 8 63)
  (sub w7 w7 8)
  (b flush_loop)
(: label flush_done)
  (ret)
(: end-function)

;; ------------------------------------------------------------
;; df_write_raw
;; Inputs:
;;   x12 = low-order bits to append
;;   w13 = bit count
;; State:
;;   x5/x6/w7 as above
;; Clobbers:
;;   x14, flags
;; ------------------------------------------------------------
(: function df_write_raw (abi leaf) (inline-only))
(: label entry)
  (lsl x14 x12 x7)
  (orr x6 x6 x14)
  (add w7 w7 w13)
  (: inline df_flush8)
  (ret)
(: end-function)

;; ------------------------------------------------------------
;; df_write_huff
;; Inputs:
;;   w12 = canonical Huffman code
;;   w13 = code length
;; State:
;;   x5/x6/w7 as above
;; Clobbers:
;;   x12, x14, flags
;; ------------------------------------------------------------
(: function df_write_huff (abi leaf) (inline-only))
(: label entry)
  (rbit w12 w12)
  (mov w14 32)
  (sub w14 w14 w13)
  (lsr w12 w12 w14)
  (: inline df_write_raw)
  (ret)
(: end-function)

;; ------------------------------------------------------------
;; df_write_fixed_lit
;; Input:
;;   w12 = literal byte
;; State:
;;   x5/x6/w7 as above
;; Clobbers:
;;   x12, x13, x14, flags
;; ------------------------------------------------------------
(: function df_write_fixed_lit (abi leaf) (inline-only))
(: label entry)
  (cmp w12 144)
  (b.hs lit_high)

  ;; Literals 0..143: canonical code = 0x30 + literal, length = 8.
  (add w12 w12 48)
  (mov w13 8)
  (: inline df_write_huff)
  (ret)

(: label lit_high)
  ;; Literals 144..255: canonical code = 0x190 + literal - 144,
  ;; equivalently literal + 256, length = 9.
  (add w12 w12 256)
  (mov w13 9)
  (: inline df_write_huff)
  (ret)
(: end-function)

;; ------------------------------------------------------------
;; df_write_eob
;; Emits fixed-Huffman end-of-block code 256.
;; State:
;;   x5/x6/w7 as above
;; Clobbers:
;;   x12, x13, x14, flags
;; ------------------------------------------------------------
(: function df_write_eob (abi leaf) (inline-only))
(: label entry)
  (mov w12 0)
  (mov w13 7)
  (: inline df_write_huff)
  (ret)
(: end-function)

;; ------------------------------------------------------------
;; df_write_len
;; Input:
;;   w15 = match length, 3..258
;; State:
;;   x5/x6/w7 as above
;; Clobbers:
;;   x8-x14, flags
;; ------------------------------------------------------------
(: function df_write_len (abi leaf) (inline-only))
(: label entry)
  (cmp w15 258)
  (b.eq len_258)

  (cmp w15 10)
  (b.hi len_extra)

  ;; Lengths 3..10 map to codes 257..264, no extra bits.
  (add w12 w15 254)
  (mov w13 7)
  (: inline df_write_huff)
  (ret)

(: label len_258)
  ;; Length 258 uses code 285, no extra bits, 8-bit fixed code.
  (mov w12 197)        ; 0xc0 + (285 - 280)
  (mov w13 8)
  (: inline df_write_huff)
  (ret)

(: label len_extra)
  ;; n = length - 11
  (sub w8 w15 11)

  (cmp w8 8)
  (b.lo len_e1)
  (cmp w8 24)
  (b.lo len_e2)
  (cmp w8 56)
  (b.lo len_e3)
  (cmp w8 120)
  (b.lo len_e4)
  (b len_e5)

(: label len_e1)
  (mov w9 1)           ; extra bits
  (mov w10 265)        ; first code
  (mov w11 0)          ; n threshold
  (b len_build)

(: label len_e2)
  (mov w9 2)
  (mov w10 269)
  (mov w11 8)
  (b len_build)

(: label len_e3)
  (mov w9 3)
  (mov w10 273)
  (mov w11 24)
  (b len_build)

(: label len_e4)
  (mov w9 4)
  (mov w10 277)
  (mov w11 56)
  (b len_build)

(: label len_e5)
  (mov w9 5)
  (mov w10 281)
  (mov w11 120)

(: label len_build)
  ;; local = n - threshold
  (sub w8 w8 w11)
  ;; slot = local >> extra
  (lsr w11 w8 w9)
  ;; code = first-code + slot
  (add w10 w10 w11)
  ;; extra_value = local - (slot << extra)
  (lsl w11 w11 w9)
  (sub w8 w8 w11)

  ;; Save extra metadata across the Huffman writer.
  (mov w11 w8)
  (mov w8 w9)

  ;; Fixed literal/length code: 257..279 are 7 bits; 280..287 are 8 bits.
  (cmp w10 280)
  (b.hs len_code_8)
  (sub w12 w10 256)
  (mov w13 7)
  (: inline df_write_huff)
  (b len_extra_bits)

(: label len_code_8)
  (sub w12 w10 280)
  (add w12 w12 192)
  (mov w13 8)
  (: inline df_write_huff)

(: label len_extra_bits)
  (cbz w8 len_done)
  (mov w12 w11)
  (mov w13 w8)
  (: inline df_write_raw)
(: label len_done)
  (ret)
(: end-function)

;; ------------------------------------------------------------
;; df_write_dist
;; Input:
;;   w16 = match distance, 1..32768
;; State:
;;   x5/x6/w7 as above
;; Clobbers:
;;   x8-x14, flags
;; ------------------------------------------------------------
(: function df_write_dist (abi leaf) (inline-only))
(: label entry)
  ;; n = distance - 1
  (sub w8 w16 1)
  (cmp w8 4)
  (b.hs dist_long)

  ;; Distances 1..4 map directly to codes 0..3, no extra bits.
  (mov w12 w8)
  (mov w13 5)
  (: inline df_write_huff)
  (ret)

(: label dist_long)
  ;; extra = floor(log2(n)) - 1
  (clz w9 w8)
  (mov w10 31)
  (sub w9 w10 w9)
  (sub w9 w9 1)

  ;; bit = (n >> extra) & 1
  (lsr w10 w8 w9)
  (and w10 w10 1)

  ;; code = 2 * extra + 2 + bit
  (add w12 w9 w9)
  (add w12 w12 2)
  (add w12 w12 w10)

  ;; base_n = (2 + bit) << extra
  (add w11 w10 2)
  (lsl w11 w11 w9)
  ;; extra_value = n - base_n
  (sub w11 w8 w11)

  ;; Preserve extra and extra_value across the Huffman writer.
  (mov w8 w9)
  (mov w9 w11)

  (mov w13 5)
  (: inline df_write_huff)

  (cbz w8 dist_done)
  (mov w12 w9)
  (mov w13 w8)
  (: inline df_write_raw)

(: label dist_done)
  (ret)
(: end-function)

;; ------------------------------------------------------------
;; deflate_fixed_fast_aarch64
;; ------------------------------------------------------------
(: function deflate_fixed_fast_aarch64 (export) (abi aapcs64))
(: label entry)
  ;; x5 = output cursor
  ;; x6/w7 = bit writer state
  ;; x4 = input position
  (mov x5 x0)
  (mov x6 0)
  (mov w7 0)
  (mov x4 0)

  ;; Clear 32768 uint32_t hash buckets. Zero means "empty"; stored values are
  ;; positions plus one.
  (mov x8 x3)
  (mov x9 8192)
(: label clear_head_loop)
  (stp xzr xzr (x8))
  (add x8 x8 16)
  (subs x9 x9 1)
  (b.ne clear_head_loop)

  ;; Deflate block header: BFINAL=1, BTYPE=01. Bits are raw LSB-first: 0b011.
  (mov x12 3)
  (mov w13 3)
  (: inline df_write_raw)

  ;; Need four readable input bytes for the hash load.
  (cmp x2 4)
  (b.lo tail_literals)
  (sub x17 x2 4)

(: label main_loop)
  (cmp x4 x17)
  (b.hi tail_literals)

  ;; Hash the next 4 bytes. Unaligned word loads are legal on AArch64.
  (ldr w8 (x1 x4))
  (eor w9 w8 w8 lsr 16)
  (ubfm w9 w9 0 14)

  ;; candidate = head[hash] - 1; then head[hash] = pos + 1.
  (ldr w10 (x3 w9 uxtw 2))
  (add w11 w4 1)
  (str w11 (x3 w9 uxtw 2))
  (cbz w10 emit_literal)
  (sub w10 w10 1)

  ;; distance = pos - candidate; reject candidates outside the 32 KiB window.
  (sub w16 w4 w10)
  (cbz w16 emit_literal)
  (cmp w16 32768)
  (b.hi emit_literal)

  ;; Check the first three bytes before entering the byte-by-byte extender.
  (ldr w11 (x1 w10 uxtw))
  (eor w11 w11 w8)
  (ubfm w11 w11 0 23)
  (cbnz w11 emit_literal)

  ;; Compute max_len = min(258, len - pos).
  (sub x11 x2 x4)
  (mov x12 258)
  (cmp x11 x12)
  (b.ls max_len_ready)
  (mov x11 258)
(: label max_len_ready)

  ;; We already know the first three bytes match.
  (mov w15 3)
  (add x8 x4 3)
  (add x9 x10 3)

(: label extend_match_loop)
  (cmp x15 x11)
  (b.hs emit_match)
  (ldrb w12 (x1 x8))
  (ldrb w13 (x1 x9))
  (cmp w12 w13)
  (b.ne emit_match)
  (add x8 x8 1)
  (add x9 x9 1)
  (add w15 w15 1)
  (b extend_match_loop)

(: label emit_match)
  (: inline df_write_len)
  (: inline df_write_dist)
  (add x4 x4 x15)
  (b main_loop)

(: label emit_literal)
  (ldrb w12 (x1 x4))
  (: inline df_write_fixed_lit)
  (add x4 x4 1)
  (b main_loop)

(: label tail_literals)
  (cmp x4 x2)
  (b.hs finish_block)
  (ldrb w12 (x1 x4))
  (: inline df_write_fixed_lit)
  (add x4 x4 1)
  (b tail_literals)

(: label finish_block)
  (: inline df_write_eob)
  (cbz w7 return_size)
  (strb w6 (x5))
  (add x5 x5 1)

(: label return_size)
  (sub x0 x5 x0)
  (ret)
(: end-function)
