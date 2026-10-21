#lang racket/base

;; asm/gen/gcm-vaes-x86.rkt — emitter for the fused AES-GCM x86-64 kernel (asm/x86/gcm_vaes.asm).
;;
;; Structure of one 512-byte chunk (32 counter blocks in eight 512-bit registers s0..s7, all
;; eight AES chains advanced together so the four-cycle vaesenc latency is covered by the two
;; AES pipes): slot A counters, slot B byte swap + round-0 key, slots R1..R(nr-1) one round each,
;; slot L the last round, slot X xor-with-input + store and the capture of the ciphertext into
;; e0..e7 (byte-reversed for GHASH). The GHASH work of earlier chunks is spread over those slots
;; in program order so the single vpclmulqdq unit (one 512-bit multiply per two cycles on Zen 5)
;; is fed at the rate the AES pipes consume slots and never queues up in front of the AES ops:
;;   - the products of the previous chunk's ciphertext (e1..e7 against H^28..H^1, then e0 with
;;     the accumulator folded in against H^32..H^29) are accumulated raw into lo/hi/mid, about
;;     two multiplies per slot, the accumulator-dependent e0 block in the last slots;
;;   - the raw sums left by the chunk before that are folded (four lanes to one, mid into lo/hi)
;;     into fl/fh and reduced with the shift-then-fold sequence of the intrinsics in the first
;;     slots, giving the accumulator the e0 block of this chunk needs, so the serial reduction
;;     chain runs a whole chunk ahead of its consumer.
;; The two interleaved streams use disjoint scratch registers (products: t/t2; fold/reduce:
;; r1..r3), since a stream's write/read pair may be split across slots with the other between.
;; Each key length (10/12/14 rounds) gets its own straight-line path: chunk 0 (AES only),
;; chunk 1 (AES + products of chunk 0), then the loop chunk (AES + fold + products). The
;; epilogue folds the pending raw sums and runs the GHASH of the last chunk's ciphertext.
;;
;; Usage: racket asm/gen/gcm-vaes-x86.rkt asm/x86/gcm_vaes.asm   (then regen-x86.sh regen gcm_vaes)

(require racket/list racket/string racket/port)

(define out (open-output-string))
;; timing-experiment knobs (never set for the committed kernel): drop or neuter one stream
(define (knob name) (and (getenv name) #t))
(define no-ghash? (knob "GCM_GEN_NOGHASH"))     ; no GHASH ops at all
(define no-clmul? (knob "GCM_GEN_NOCLMUL"))     ; vpclmulqdq -> vpxorq of the same operands
(define no-shuf? (knob "GCM_GEN_NOSHUF"))       ; no counter/ciphertext vpshufb
(define no-fold? (knob "GCM_GEN_NOFOLD"))       ; no fold/reduce ops
(define no-aes? (knob "GCM_GEN_NOAES"))         ; no vaesenc/vaesenclast

(define (neuter lines)
  (for/list ([l lines])
    (cond [(and no-clmul? (regexp-match? #rx"vpclmulqdq" l))
           (regexp-replace #rx", 0x[0-9a-f][0-9a-f]" (regexp-replace #rx"vpclmulqdq" l "vpxorq    ") "")]
          [else l])))
(define (emit fmt . args) (write-string (apply format fmt args) out) (newline out))

;; ---- GHASH op lists -------------------------------------------------------------------------

;; raw products of register e<j> (four ciphertext blocks a = (a0, a1)) against table row j
;; (b = H^(32-4j).. times x^-1) with Karatsuba: lo += a0*b0, hi += a1*b1, mid += (a0^a1)*(b0^b1)
;; from the second table (b0^b1 in both halves of each lane); a vpclmulqdq is four FP micro-ops
;; on Zen 5, so three multiplies plus a lane swap and an xor beat four multiplies. The fold adds
;; lo and hi into mid once per chunk to turn it into the true middle term.
(define (prod-ops j first?)
  (define row (if (= j 0) "[q.htab]" (format "[q.htab + ~a]" (* 64 j))))
  (define krow (format "[q.htab + ~a]" (+ 512 (* 64 j))))
  (define e (format "zmm.e~a" j))
  (append
   (if (= j 0) (list (format "  vpxorq ~a, ~a, zmm.acc                 ; accumulator into block 0 (upper lanes of acc are zero)" e e)) '())
   (if first?
       (list (format "  vpclmulqdq zmm.lo, ~a, zmmword ptr ~a, 0x00" e row)
             (format "  vpclmulqdq zmm.hi, ~a, zmmword ptr ~a, 0x11" e row)
             (format "  vpshufd zmm.t2, ~a, 0x4e" e)
             (format "  vpxorq zmm.t2, zmm.t2, ~a                  ; a0 ^ a1 in both halves" e)
             (format "  vpclmulqdq zmm.mid, zmm.t2, zmmword ptr ~a, 0x00" krow))
       (list (format "  vpclmulqdq zmm.t, ~a, zmmword ptr ~a, 0x00" e row)
             "  vpxorq zmm.lo, zmm.lo, zmm.t"
             (format "  vpclmulqdq zmm.t, ~a, zmmword ptr ~a, 0x11" e row)
             "  vpxorq zmm.hi, zmm.hi, zmm.t"
             (format "  vpshufd zmm.t2, ~a, 0x4e" e)
             (format "  vpxorq zmm.t2, zmm.t2, ~a" e)
             (format "  vpclmulqdq zmm.t, zmm.t2, zmmword ptr ~a, 0x00" krow)
             "  vpxorq zmm.mid, zmm.mid, zmm.t"))))

;; products of e1..e7 (independent of the accumulator), then e0 (needs it)
(define prod-independent (append* (for/list ([j (in-range 1 8)]) (prod-ops j (= j 1)))))
(define prod-acc (prod-ops 0 #f))

;; fold the raw sums lo/hi/mid into fl/fh (one 256-bit product) and reduce into acc
(define fold-ops   ; its scratch is r1/r2, never t/t2: the product ops interleaved with it own those
  (list "  vpternlogq zmm.mid, zmm.lo, zmm.hi, 0x96      ; Karatsuba: mid = sum of the cross terms"
        "  vpslldq zmm.r1, zmm.mid, 8"
        "  vpsrldq zmm.r2, zmm.mid, 8"
        "  vpxorq zmm.fl, zmm.lo, zmm.r1                ; mid folds into lo/hi (gcm_mul_raw)"
        "  vpxorq zmm.fh, zmm.hi, zmm.r2"
        "  vextracti64x4 ymm.r1, zmm.fl, 1"
        "  vpxorq ymm.fl, ymm.fl, ymm.r1"
        "  vextracti32x4 xmm.r1, ymm.fl, 1"
        "  vpxorq xmm.fl, xmm.fl, xmm.r1"
        "  vextracti64x4 ymm.r2, zmm.fh, 1"
        "  vpxorq ymm.fh, ymm.fh, ymm.r2"
        "  vextracti32x4 xmm.r2, ymm.fh, 1"
        "  vpxorq xmm.fh, xmm.fh, xmm.r2                ; four lanes to one"))
;; The table rows the kernel multiplies by hold H^k * x^-1, so the raw product of the reflected
;; operands is already the reflected 256-bit product of the field elements and the one-bit shift
;; of the generic gcm_reduce is not needed: only the fold modulo the polynomial remains.
(define reduce-ops
  (list "  vpslld xmm.r1, xmm.fl, 31                    ; fold modulo the polynomial (table rows carry x^-1)"
        "  vpslld xmm.r2, xmm.fl, 30"
        "  vpslld xmm.r3, xmm.fl, 25"
        "  vpxorq xmm.r1, xmm.r1, xmm.r2"
        "  vpxorq xmm.r1, xmm.r1, xmm.r3"
        "  vpsrldq xmm.r2, xmm.r1, 4"
        "  vpslldq xmm.r1, xmm.r1, 12"
        "  vpxorq xmm.fl, xmm.fl, xmm.r1"
        "  vpsrld xmm.r1, xmm.fl, 1"
        "  vpsrld xmm.r3, xmm.fl, 2"
        "  vpxorq xmm.r1, xmm.r1, xmm.r3"
        "  vpsrld xmm.r3, xmm.fl, 7"
        "  vpxorq xmm.r1, xmm.r1, xmm.r3"
        "  vpxorq xmm.r1, xmm.r1, xmm.r2"
        "  vpxorq xmm.fl, xmm.fl, xmm.r1"
        "  vpxorq xmm.acc, xmm.fh, xmm.fl"))
(define fold+reduce (append fold-ops reduce-ops))

;; ---- AES slots of one chunk ------------------------------------------------------------------

(define (aes-slots nr tag)
  ;; returns a list of slots; each slot is a list of lines
  (append
   (list (for/list ([j 8]) (format "  vpaddd zmm.s~a, zmm.base, zmmword ptr [rip + gcm_vaes_inc + ~a]" j (* 64 j))))
   (list (append (list "  vbroadcasti32x4 zmm.k, xmmword ptr [q.rk]")
                 (for/list ([j 8]) (format "  vpshufb zmm.s~a, zmm.s~a, zmm.bswap" j j))
                 (for/list ([j 8]) (format "  vpxorq zmm.s~a, zmm.s~a, zmm.k" j j))))
   (for/list ([r (in-range 1 nr)])
     (cons (format "  vbroadcasti32x4 zmm.k, xmmword ptr [q.rk + ~a]" (* 16 r))
           (for/list ([j 8]) (format "  vaesenc zmm.s~a, zmm.s~a, zmm.k" j j))))
   (list (cons (format "  vbroadcasti32x4 zmm.k, xmmword ptr [q.rk + ~a]" (* 16 nr))
               (for/list ([j 8]) (format "  vaesenclast zmm.s~a, zmm.s~a, zmm.k" j j))))
   (list (append
          (list "  test d.enc, d.enc" (format "  jz decrypt~a" tag))
          (append* (for/list ([j 8]) (list (format "  vpxorq zmm.e~a, zmm.s~a, zmmword ptr [q.in + ~a]      ; encrypt: ciphertext straight into e" j j (* 64 j))
                                           (format "  vmovdqu64 zmmword ptr [q.out + ~a], zmm.e~a" (* 64 j) j))))
          (list (format "  jmp reverse~a" tag) (format "decrypt~a:" tag))
          (for/list ([j 8]) (format "  vmovdqu64 zmm.e~a, zmmword ptr [q.in + ~a]     ; decrypt: the ciphertext is the input (loaded before the store: in-place safe)" j (* 64 j)))
          (append* (for/list ([j 8]) (list (format "  vpxorq zmm.s~a, zmm.s~a, zmm.e~a" j j j)
                                           (format "  vmovdqu64 zmmword ptr [q.out + ~a], zmm.s~a" (* 64 j) j))))
          (list (format "reverse~a:" tag))
          (for/list ([j 8]) (format "  vpshufb zmm.e~a, zmm.e~a, zmm.bswap" j j))))))

;; spread ops over slots [a, b] (inclusive), as evenly as possible, in order
(define (spread ops a b)
  (define n (add1 (- b a)))
  (define total (length ops))
  (for/list ([i n])
    (define lo (quotient (* i total) n))
    (define hi (quotient (* (add1 i) total) n))
    (cons (+ a i) (take (drop ops lo) (- hi lo)))))

;; one chunk: AES slots with GHASH ops merged (GHASH ops at the head of each slot)
(define (emit-chunk nr tag fold? prod?)
  (define slots (aes-slots nr tag))
  (define S (length slots))
  (define extra (make-vector S '()))
  (define (add! placement)
    (for ([p placement]) (vector-set! extra (car p) (append (vector-ref extra (car p)) (cdr p)))))
  ;; the fold's first five ops consume lo/hi/mid; they must precede the first product op (which
  ;; starts the new sums in those registers), so they always go to the head of slot 0 and only
  ;; the rest is spread
  (when (and fold? (not no-ghash?) (not no-fold?))
    (add! (list (cons 0 (take (neuter fold+reduce) 5))))
    (add! (spread (drop (neuter fold+reduce) 5) 0 5)))
  (when (and prod? (not no-ghash?))
    (add! (spread (neuter prod-independent) 0 (- S 5)))
    (add! (spread (neuter prod-acc) (- S 4) (- S 1))))
  ;; GHASH ops go first in a slot: slot X overwrites e0..e7 with the new ciphertext, and the
  ;; accumulator-dependent e0 block ends in that slot
  (for ([slot slots] [k (in-naturals)])
    (emit "  ;; -- slot ~a" k)
    (for-each (lambda (l) (emit "~a" l)) (vector-ref extra k))
    (for-each (lambda (l) (unless (or (and no-shuf? (regexp-match? #rx"vpshufb" l))
                                      (and no-aes? (regexp-match? #rx"vaesenc" l)))
                            (emit "~a" l)))
              slot)))

(define (emit-advance)
  (emit "  vpaddd zmm.base, zmm.base, zmmword ptr [rip + gcm_vaes_thirtytwo]")
  (emit "  add q.in, 512")
  (emit "  add q.out, 512")
  (emit "  add q.ret, 512")
  (emit "  sub q.len, 512"))

(define (emit-path nr)
  (emit "p~a:" nr)
  (emit "  ;; ==== chunk 0: AES only" )
  (emit-chunk nr (format "~a_0" nr) #f #f)
  (emit-advance)
  (emit "  cmp q.len, 512")
  (emit "  jb fin_last")
  (emit "  ;; ==== chunk 1: AES + products of chunk 0")
  (emit-chunk nr (format "~a_1" nr) #f #t)
  (emit-advance)
  (emit "  cmp q.len, 512")
  (emit "  jb fin_fold")
  (emit "loop~a:" nr)
  (emit "  ;; ==== loop chunk: AES + fold of the chunk before last + products of the previous chunk")
  (emit-chunk nr (format "~a_l" nr) #t #t)
  (emit-advance)
  (emit "  cmp q.len, 512")
  (emit "  jae loop~a" nr)
  (emit "  jmp fin_fold"))

;; ---- file ------------------------------------------------------------------------------------

(emit ";; Fused AES-GCM bulk pass on VAES + VPCLMULQDQ + AVX-512 (x86-64 SysV). GENERATED by")
(emit ";; asm/gen/gcm-vaes-x86.rkt (see its header for the chunk/slot structure); edit the generator.")
(emit ";; Per 512-byte chunk, 32 CTR blocks (inc32) are encrypted in eight 512-bit registers and")
(emit ";; XORed with the input; the ciphertext of the previous chunk is multiplied into raw GHASH")
(emit ";; sums with ONE reduction per chunk, and that reduction runs one chunk later still, both")
(emit ";; interleaved with the AES rounds in program order. One kernel serves both directions: the")
(emit ";; GHASH input is the ciphertext, taken from the registers after the XOR (encrypt) or loaded")
(emit ";; before the output store (decrypt, which keeps in-place decryption correct).")
(emit ";;   intptr_t rktcrypto_gcm_crypt_vaes(const struct rktcrypto_gcm_vaes_ctx *c,")
(emit ";;                                     const unsigned char *in, unsigned char *out, intptr_t len)")
(emit ";; ctx: rk@0, htab@8 (H^32..H^1 times x^-1 in eight 64-byte rows, byte-reversed, then the")
(emit ";; eight rows of their (lo ^ hi) halves for the Karatsuba cross term), ctr@16")
(emit ";; (big-endian, updated), acc@24 (byte-reversed, updated), nr@32, enc@40. Returns the bytes processed")
(emit ";; (a multiple of 512); the C side finishes the remainder on the CTR and GHASH paths.")
(emit ";; Oracle: the two-pass path (rktcrypto_aes_ctr_aesni + rktcrypto_ghash_x86);")
(emit ";; gate: asm/tests/test_gcm_vaes.c.")
(emit ";;")
(emit ";; rktcrypto_gcm_htab_vaes(htab, H) builds the whole 1280-byte table from the hash key block:")
(emit ";; H^32..H^1 times x^-1 in eight rows, their (lo ^ hi) halves for the Karatsuba cross term, and")
(emit ";; the plain H^16..H^1 the region helper takes (see the kernel's own comment).")
(emit "")
(emit ".rodata gcm_vaes_bswap align=16")
(emit "  .byte 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0")
(emit ".end")
(emit ".rodata gcm_vaes_inc align=64                   ; lane i of vector j holds 4j+i in dword 0")
(for ([j 8]) (emit "  .long ~a" (string-join (for/list ([i 4]) (format "~a,0,0,0" (+ (* 4 j) i))) ", ")))
(emit ".end")
(emit ".rodata gcm_vaes_thirtytwo align=64")
(emit "  .long 32,0,0,0, 32,0,0,0, 32,0,0,0, 32,0,0,0")
(emit ".end")
(emit "")
(emit ".function rktcrypto_gcm_crypt_vaes export (")
(emit "  in: q.ctx, q.in, q.out, q.len")
(emit "  out: q.ret")
(emit ")")
(emit "  .simd avx512")
(emit "  xor d.ret, d.ret")
(emit "  cmp q.len, 512")
(emit "  jb done")
(emit "  mov q.rk, qword ptr [q.ctx]")
(emit "  mov q.htab, qword ptr [q.ctx + 8]")
(emit "  mov q.p, qword ptr [q.ctx + 16]                ; counter block")
(emit "  mov q.nr, qword ptr [q.ctx + 32]")
(emit "  mov q.enc, qword ptr [q.ctx + 40]")
(emit "  vbroadcasti32x4 zmm.bswap, xmmword ptr [rip + gcm_vaes_bswap]")
(emit "  vbroadcasti32x4 zmm.base, xmmword ptr [q.p]")
(emit "  vpshufb zmm.base, zmm.base, zmm.bswap          ; little-endian counters, all lanes equal")
(emit "  mov q.p, qword ptr [q.ctx + 24]                ; accumulator")
(emit "  vmovdqu64 xmm.acc, xmmword ptr [q.p]")
(emit "  cmp d.nr, 10")
(emit "  je p10")
(emit "  cmp d.nr, 12")
(emit "  je p12")
(emit-path 14)
(emit-path 12)
(emit-path 10)
(emit "fin_fold:")
(emit "  ;; ==== raw sums of the chunk before last: fold and reduce")
(for-each (lambda (l) (emit "~a" l)) fold+reduce)
(emit "fin_last:")
(emit "  ;; ==== GHASH of the last chunk's ciphertext")
(for-each (lambda (l) (emit "~a" l)) prod-independent)
(for-each (lambda (l) (emit "~a" l)) prod-acc)
(for-each (lambda (l) (emit "~a" l)) fold+reduce)
(emit "  vmovdqu64 xmmword ptr [q.p], xmm.acc")
(emit "  mov q.p, qword ptr [q.ctx + 16]")
(emit "  vpshufb xmm.t, xmm.base, xmm.bswap")
(emit "  vmovdqu64 xmmword ptr [q.p], xmm.t")
(emit "done:")
(emit "  ret")
(emit ".end")
(emit "")
;; ---- the table kernel: every power, the x^-1 scaling and the Karatsuba rows in one pass ----------
;; rktcrypto_gcm_htab_vaes(htab, hblock): hblock = H = AES_K(0) as the 16-byte block (GCM byte order).
;; The powers are formed in the x^-1-scaled representation the bulk kernel multiplies in: with
;; a' = a*x^-1 and b' = b*x^-1 the carry-less product of the reflected operands is the reflected
;; 256-bit a*b*x^-1, which the fold alone reduces to (a*b)', so every multiply here is the short
;; one and no scaling pass is needed afterwards. H is scaled once up front (shift left, carry across
;; the lane's qwords, the bit off the top folds x^-1 = 0xC2..01 in); H^2, H^3, H^4, H^8, H^16 on xmm
;; (depth 4), row 7 = [H^4 H^3 H^2 H], rows 6..0 with H^4/H^8/H^16 in every lane (depth 3 more);
;; rows 4..7 are unscaled again (shift right, the bit off the bottom folds x^128 = 0xE1..00 in)
;; for the plain H^16..H^1 the region helper takes, and the (lo ^ hi) halves of the scaled
;; entries fill htab + 512..1023 for the Karatsuba cross term.
(define (gfmul w d a b)   ; w = view prefix (xmm/zmm); d = a * b in the scaled representation (fold-only reduction)
  (for-each (lambda (l) (emit "~a" l))
   (list (format "  vpclmulqdq ~a.lo, ~a.~a, ~a.~a, 0x00" w w a w b)
         (format "  vpclmulqdq ~a.hi, ~a.~a, ~a.~a, 0x11" w w a w b)
         (format "  vpclmulqdq ~a.mid, ~a.~a, ~a.~a, 0x10" w w a w b)
         (format "  vpclmulqdq ~a.t, ~a.~a, ~a.~a, 0x01" w w a w b)
         (format "  vpxorq ~a.mid, ~a.mid, ~a.t" w w w)
         (format "  vpslldq ~a.t, ~a.mid, 8" w w)
         (format "  vpsrldq ~a.mid, ~a.mid, 8" w w)
         (format "  vpxorq ~a.lo, ~a.lo, ~a.t" w w w)
         (format "  vpxorq ~a.hi, ~a.hi, ~a.mid" w w w)
         (format "  vpslld ~a.t7, ~a.lo, 31" w w)
         (format "  vpslld ~a.t8, ~a.lo, 30" w w)
         (format "  vpslld ~a.t9, ~a.lo, 25" w w)
         (format "  vpxorq ~a.t7, ~a.t7, ~a.t8" w w w)
         (format "  vpxorq ~a.t7, ~a.t7, ~a.t9" w w w)
         (format "  vpsrldq ~a.t8, ~a.t7, 4" w w)
         (format "  vpslldq ~a.t7, ~a.t7, 12" w w)
         (format "  vpxorq ~a.lo, ~a.lo, ~a.t7" w w w)
         (format "  vpsrld ~a.t2, ~a.lo, 1" w w)
         (format "  vpsrld ~a.t4, ~a.lo, 2" w w)
         (format "  vpsrld ~a.t5, ~a.lo, 7" w w)
         (format "  vpxorq ~a.t2, ~a.t2, ~a.t4" w w w)
         (format "  vpxorq ~a.t2, ~a.t2, ~a.t5" w w w)
         (format "  vpxorq ~a.t2, ~a.t2, ~a.t8" w w w)
         (format "  vpxorq ~a.lo, ~a.lo, ~a.t2" w w w)
         (format "  vpxorq ~a.~a, ~a.hi, ~a.lo" w d w w))))
(emit ".rodata gcm_vaes_xinv align=64                  ; x^-1 in the reflected representation, per 128-bit lane")
(emit "  .quad 1, 0xc200000000000000, 1, 0xc200000000000000, 1, 0xc200000000000000, 1, 0xc200000000000000")
(emit ".end")
(emit ".rodata gcm_vaes_xpow128 align=64               ; x^128 mod P = x^7 + x^2 + x + 1, reflected, per lane")
(emit "  .quad 0, 0xe100000000000000, 0, 0xe100000000000000, 0, 0xe100000000000000, 0, 0xe100000000000000")
(emit ".end")
(emit ".function rktcrypto_gcm_htab_vaes export (")
(emit "  in: q.htab, q.hb")
(emit ")")
(emit "  .simd avx512")
(emit "  vmovdqu64 xmm.h1, xmmword ptr [q.hb]")
(emit "  vpshufb xmm.h1, xmm.h1, xmmword ptr [rip + gcm_vaes_bswap]   ; byte-reversed representation")
(emit "  vpxorq xmm.zero, xmm.zero, xmm.zero")
(emit "  ;; H * x^-1")
(emit "  vpsrlq xmm.t, xmm.h1, 63")
(emit "  vpsllq xmm.h1, xmm.h1, 1")
(emit "  vpslldq xmm.t2, xmm.t, 8")
(emit "  vporq xmm.h1, xmm.h1, xmm.t2")
(emit "  vpshufd xmm.t, xmm.t, 0xee")
(emit "  vpsubq xmm.t, xmm.zero, xmm.t")
(emit "  vpternlogq xmm.h1, xmm.t, xmmword ptr [rip + gcm_vaes_xinv], 0x78")
(gfmul "xmm" "h2" "h1" "h1")
(gfmul "xmm" "h3" "h2" "h1")
(gfmul "xmm" "h4" "h2" "h2")
(gfmul "xmm" "h8" "h4" "h4")
(gfmul "xmm" "h16" "h8" "h8")
(emit "  vinserti32x4 zmm.v7, zmm.h4, xmm.h3, 1         ; row 7 = [H^4 H^3 H^2 H]")
(emit "  vinserti32x4 zmm.v7, zmm.v7, xmm.h2, 2")
(emit "  vinserti32x4 zmm.v7, zmm.v7, xmm.h1, 3")
(emit "  vshufi32x4 zmm.c4, zmm.h4, zmm.h4, 0           ; lane 0 to every lane")
(emit "  vshufi32x4 zmm.c8, zmm.h8, zmm.h8, 0")
(emit "  vshufi32x4 zmm.c16, zmm.h16, zmm.h16, 0")
(emit "  ;; rows: 6 = 7*H^4 | 5 = 7*H^8 | 4 = 6*H^8 | 3 = 7*H^16 | 2 = 6*H^16 | 1 = 5*H^16 | 0 = 4*H^16")
(for ([step '(("v6" "v7" "c4") ("v5" "v7" "c8") ("v4" "v6" "c8") ("v3" "v7" "c16") ("v2" "v6" "c16") ("v1" "v5" "c16") ("v0" "v4" "c16"))])
  (gfmul "zmm" (car step) (cadr step) (caddr step)))
(for ([k 8]) (emit "  vmovdqu64 zmmword ptr [q.htab + ~a], zmm.v~a" (* 64 k) k))
(emit "  ;; Karatsuba rows: (lo ^ hi) of each scaled entry in both halves")
(for ([k 8])
  (emit "  vpshufd zmm.t, zmm.v~a, 0x4e" k)
  (emit "  vpxorq zmm.t, zmm.t, zmm.v~a" k)
  (emit "  vmovdqu64 zmmword ptr [q.htab + ~a], zmm.t" (+ 512 (* 64 k))))
(emit "  ;; plain H^16..H^1 for the region helper: times x (shift right, the bit off the bottom folds x^128 in)")
(emit "  vmovdqa64 zmm.xp, zmmword ptr [rip + gcm_vaes_xpow128]")
(for ([k (in-range 4 8)])
  (emit "  vpsllq zmm.t2, zmm.v~a, 63                    ; qword 0's low bit, as the sign of qword 0" k)
  (emit "  vpsraq zmm.t2, zmm.t2, 63                     ; mask in qword 0")
  (emit "  vpslldq zmm.t2, zmm.t2, 8                     ; ... moved to qword 1")
  (emit "  vpsllq zmm.t, zmm.v~a, 63                     ; qword 1's low bit heads for qword 0's top" k)
  (emit "  vpsrldq zmm.t, zmm.t, 8")
  (emit "  vpsrlq zmm.v~a, zmm.v~a, 1" k k)
  (emit "  vporq zmm.v~a, zmm.v~a, zmm.t" k k)
  (emit "  vpternlogq zmm.v~a, zmm.t2, zmm.xp, 0x78       ; ^= mask & x^128" k)
  (emit "  vmovdqu64 zmmword ptr [q.htab + ~a], zmm.v~a" (+ 1024 (* 64 (- k 4))) k))
(emit "  ret")
(emit ".end")

(define args (current-command-line-arguments))
(void
 (if (> (vector-length args) 0)
     (call-with-output-file (vector-ref args 0) #:exists 'truncate (lambda (o) (write-string (get-output-string out) o)))
     (write-string (get-output-string out) (current-output-port))))
