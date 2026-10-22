#lang racket/base

;; asm/gen/gcm-aesni-x86.rkt — emitter for the AES-NI + PCLMULQDQ fused AES-GCM kernel
;; (asm/x86/gcm_aesni.asm), the tier for x86-64 CPUs with AVX2 but without VAES/AVX-512.
;;
;; Sixteen xmm registers: eight AES chains (s0..s7, one block each, 128-byte chunks), the raw
;; GHASH sums lo/hi/mid, two scratch, the counter base; the round keys, the byte-swap mask, the
;; counter increments and the table rows are memory operands. The GHASH of a chunk is computed
;; from memory, interleaved slot by slot with the AES rounds of a chunk as in the VAES kernel:
;; when encrypting, the previous chunk's output (intact in memory) during the current chunk,
;; the last chunk's after the loop; when decrypting, the current chunk's input, whose loads all
;; sit before the slot that overwrites it (in-place safe). The products use Karatsuba against
;; the x^-1-scaled entries H^8..H^1 of the shared 1280-byte table (rows 6 and 7) and their
;; (lo ^ hi) rows, so the fold at the end of a chunk is the short reduction; the fold runs at the
;; chunk's end (the register budget allows no second set of sums), the accumulator-dependent
;; block 0 last among the products.
;;
;; Usage: racket asm/gen/gcm-aesni-x86.rkt asm/x86/gcm_aesni.asm   (then regen-x86.sh regen gcm_aesni)

(require racket/list racket/string)

(define out (open-output-string))
(define (emit fmt . args) (write-string (apply format fmt args) out) (newline out))

;; ---- GHASH ops: products of block j (of 8) taken from memory at [q.g + 16 j] ---------------------
;; table: scaled H^(8-j) at htab + 384 + 16 j, its Karatsuba row at htab + 896 + 16 j
(define (prod-ops j first?)
  (define row (format "[q.htab + ~a]" (+ 384 (* 16 j))))
  (define krow (format "[q.htab + ~a]" (+ 896 (* 16 j))))
  (append
   (list (format "  vmovdqu xmm.t, xmmword ptr [q.g + ~a]" (* 16 j))
         "  vpshufb xmm.t, xmm.t, xmmword ptr [rip + gcm_aesni_bswap]")
   (if (= j 0) (list "  vpxor xmm.t, xmm.t, xmm.acc                 ; accumulator into block 0") '())
   (if first?
       (list (format "  vpclmulqdq xmm.lo, xmm.t, xmmword ptr ~a, 0x00" row)
             (format "  vpclmulqdq xmm.hi, xmm.t, xmmword ptr ~a, 0x11" row)
             "  vpshufd xmm.t2, xmm.t, 0x4e"
             "  vpxor xmm.t2, xmm.t2, xmm.t                   ; a0 ^ a1 in both halves"
             (format "  vpclmulqdq xmm.mid, xmm.t2, xmmword ptr ~a, 0x00" krow))
       (list (format "  vpclmulqdq xmm.t2, xmm.t, xmmword ptr ~a, 0x00" row)
             "  vpxor xmm.lo, xmm.lo, xmm.t2"
             (format "  vpclmulqdq xmm.t2, xmm.t, xmmword ptr ~a, 0x11" row)
             "  vpxor xmm.hi, xmm.hi, xmm.t2"
             "  vpshufd xmm.t2, xmm.t, 0x4e"
             "  vpxor xmm.t2, xmm.t2, xmm.t"
             (format "  vpclmulqdq xmm.t2, xmm.t2, xmmword ptr ~a, 0x00" krow)
             "  vpxor xmm.mid, xmm.mid, xmm.t2"))))
(define prod-independent (append* (for/list ([j (in-range 1 8)]) (prod-ops j (= j 1)))))
(define prod-acc (prod-ops 0 #f))
;; fold mid into lo/hi, reduce (table rows carry x^-1: fold modulo the polynomial only), acc = result
(define fold+reduce
  (list "  vpxor xmm.mid, xmm.mid, xmm.lo                ; Karatsuba: mid = sum of the cross terms"
        "  vpxor xmm.mid, xmm.mid, xmm.hi"
        "  vpslldq xmm.t, xmm.mid, 8"
        "  vpsrldq xmm.t2, xmm.mid, 8"
        "  vpxor xmm.lo, xmm.lo, xmm.t"
        "  vpxor xmm.hi, xmm.hi, xmm.t2"
        "  vpslld xmm.t, xmm.lo, 31"
        "  vpslld xmm.t2, xmm.lo, 30"
        "  vpslld xmm.mid, xmm.lo, 25"
        "  vpxor xmm.t, xmm.t, xmm.t2"
        "  vpxor xmm.t, xmm.t, xmm.mid"
        "  vpsrldq xmm.t2, xmm.t, 4"
        "  vpslldq xmm.t, xmm.t, 12"
        "  vpxor xmm.lo, xmm.lo, xmm.t"
        "  vpsrld xmm.t, xmm.lo, 1"
        "  vpsrld xmm.mid, xmm.lo, 2"
        "  vpxor xmm.t, xmm.t, xmm.mid"
        "  vpsrld xmm.mid, xmm.lo, 7"
        "  vpxor xmm.t, xmm.t, xmm.mid"
        "  vpxor xmm.t, xmm.t, xmm.t2"
        "  vpxor xmm.lo, xmm.lo, xmm.t"
        "  vpxor xmm.acc, xmm.hi, xmm.lo"))

;; ---- AES slots of one 128-byte chunk --------------------------------------------------------------
(define (aes-slots nr tag enc?)
  (append
   (list (for/list ([j 8]) (format "  vpaddd xmm.s~a, xmm.base, xmmword ptr [rip + gcm_aesni_inc + ~a]" j (* 16 j))))
   (list (append (for/list ([j 8]) (format "  vpshufb xmm.s~a, xmm.s~a, xmmword ptr [rip + gcm_aesni_bswap]" j j))
                 (for/list ([j 8]) (format "  vpxor xmm.s~a, xmm.s~a, xmmword ptr [q.rk]" j j))))
   (for/list ([r (in-range 1 nr)])
     (for/list ([j 8]) (format "  vaesenc xmm.s~a, xmm.s~a, xmmword ptr [q.rk + ~a]" j j (* 16 r))))
   (list (for/list ([j 8]) (format "  vaesenclast xmm.s~a, xmm.s~a, xmmword ptr [q.rk + ~a]" j j (* 16 nr))))
   (list (append* (for/list ([j 8]) (list (format "  vpxor xmm.s~a, xmm.s~a, xmmword ptr [q.in + ~a]" j j (* 16 j))
                                          (format "  vmovdqu xmmword ptr [q.out + ~a], xmm.s~a" (* 16 j) j)))))))

(define (spread ops a b)
  (define n (add1 (- b a)))
  (define total (length ops))
  (for/list ([i n])
    (define lo (quotient (* i total) n))
    (define hi (quotient (* (add1 i) total) n))
    (cons (+ a i) (take (drop ops lo) (- hi lo)))))

;; one chunk; ghash?: the products of the chunk at [q.g ..] and the fold at the end
(define (emit-chunk nr tag enc? ghash?)
  (define slots (aes-slots nr tag enc?))
  (define S (length slots))
  (define extra (make-vector S '()))
  (define (add! placement)
    (for ([p placement]) (vector-set! extra (car p) (append (vector-ref extra (car p)) (cdr p)))))
  (when ghash?
    ;; products over the slots before X (the loads must precede the overwrite when decrypting in
    ;; place), the accumulator-dependent block 0 last, then the fold in the last slot after X's AES ops
    (add! (spread prod-independent 0 (- S 5)))
    (add! (spread prod-acc (- S 4) (- S 2))))
  (for ([slot slots] [k (in-naturals)])
    (emit "  ;; -- slot ~a" k)
    (for-each (lambda (l) (emit "~a" l)) (vector-ref extra k))
    (for-each (lambda (l) (emit "~a" l)) slot))
  (when ghash? (for-each (lambda (l) (emit "~a" l)) fold+reduce)))

(define (emit-advance)
  (emit "  vpaddd xmm.base, xmm.base, xmmword ptr [rip + gcm_aesni_eight]")
  (emit "  add q.in, 128")
  (emit "  add q.out, 128")
  (emit "  add q.ret, 128")
  (emit "  sub q.len, 128"))

(define (emit-path nr)
  ;; encrypt: chunk 0 without GHASH, then chunks whose GHASH source is the previous output
  (emit "e~a:" nr)
  (emit-chunk nr (format "e~a_0" nr) #t #f)
  (emit-advance)
  (emit "  cmp q.len, 128")
  (emit "  jb fin_last")
  (emit "eloop~a:" nr)
  (emit "  lea q.g, [q.out -128]")
  (emit-chunk nr (format "e~a_l" nr) #t #t)
  (emit-advance)
  (emit "  cmp q.len, 128")
  (emit "  jae eloop~a" nr)
  (emit "  jmp fin_last")
  ;; decrypt: every chunk GHASHes its own input
  (emit "d~a:" nr)
  (emit "  mov q.g, q.in")
  (emit-chunk nr (format "d~a_l" nr) #f #t)
  (emit-advance)
  (emit "  cmp q.len, 128")
  (emit "  jae d~a" nr)
  (emit "  jmp fin"))

(emit ";; Fused AES-GCM bulk pass on AES-NI + PCLMULQDQ + AVX2 (x86-64 SysV), the tier below VAES.")
(emit ";; GENERATED by asm/gen/gcm-aesni-x86.rkt (see its header); edit the generator.")
(emit ";;   intptr_t rktcrypto_gcm_crypt_aesni(const struct rktcrypto_gcm_vaes_ctx *c,")
(emit ";;                                      const unsigned char *in, unsigned char *out, intptr_t len)")
(emit ";; The same context and table as rktcrypto_gcm_crypt_vaes; processes 128-byte chunks and returns")
(emit ";; the bytes done (a multiple of 128); the C side finishes the remainder. Oracle: the two-pass")
(emit ";; path with AVX2 cleared; gate: asm/tests/test_gcm_vaes.c.")
(emit "")
(emit ".rodata gcm_aesni_bswap align=16")
(emit "  .byte 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0")
(emit ".end")
(emit ".rodata gcm_aesni_inc align=16                  ; block j of a chunk: counter + j in dword 0")
(for ([j 8]) (emit "  .long ~a, 0, 0, 0" j))
(emit ".end")
(emit ".rodata gcm_aesni_eight align=16")
(emit "  .long 8, 0, 0, 0")
(emit ".end")
(emit "")
(emit ".function rktcrypto_gcm_crypt_aesni export (")
(emit "  in: q.ctx, q.in, q.out, q.len")
(emit "  out: q.ret")
(emit ")")
(emit "  .simd avx2")
(emit "  xor d.ret, d.ret")
(emit "  cmp q.len, 128")
(emit "  jb done")
(emit "  mov q.rk, qword ptr [q.ctx]")
(emit "  mov q.htab, qword ptr [q.ctx + 8]")
(emit "  mov q.p, qword ptr [q.ctx + 16]                ; counter block")
(emit "  mov q.nr, qword ptr [q.ctx + 32]")
(emit "  mov q.enc, qword ptr [q.ctx + 40]")
(emit "  vmovdqu xmm.base, xmmword ptr [q.p]")
(emit "  vpshufb xmm.base, xmm.base, xmmword ptr [rip + gcm_aesni_bswap]   ; little-endian counter")
(emit "  mov q.p, qword ptr [q.ctx + 24]                ; accumulator")
(emit "  vmovdqu xmm.acc, xmmword ptr [q.p]")
(emit "  test d.enc, d.enc")
(emit "  jz dec")
(emit "  cmp d.nr, 10")
(emit "  je e10")
(emit "  cmp d.nr, 12")
(emit "  je e12")
(emit "  jmp e14")
(emit "dec:")
(emit "  cmp d.nr, 10")
(emit "  je d10")
(emit "  cmp d.nr, 12")
(emit "  je d12")
(emit "  jmp d14")
(emit-path 14)
(emit-path 12)
(emit-path 10)
(emit "fin_last:")
(emit "  ;; the last encrypted chunk's GHASH")
(emit "  lea q.g, [q.out -128]")
(for-each (lambda (l) (emit "~a" l)) prod-independent)
(for-each (lambda (l) (emit "~a" l)) prod-acc)
(for-each (lambda (l) (emit "~a" l)) fold+reduce)
(emit "fin:")
(emit "  vmovdqu xmmword ptr [q.p], xmm.acc")
(emit "  mov q.p, qword ptr [q.ctx + 16]")
(emit "  vpshufb xmm.base, xmm.base, xmmword ptr [rip + gcm_aesni_bswap]")
(emit "  vmovdqu xmmword ptr [q.p], xmm.base")
(emit "done:")
(emit "  ret")
(emit ".end")

(define args (current-command-line-arguments))
(void
 (if (> (vector-length args) 0)
     (call-with-output-file (vector-ref args 0) #:exists 'truncate (lambda (o) (write-string (get-output-string out) o)))
     (write-string (get-output-string out) (current-output-port))))
