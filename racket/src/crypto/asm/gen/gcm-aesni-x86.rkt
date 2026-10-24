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
;; Usage: racket asm/gen/gcm-aesni-x86.rkt asm/x86/gcm_aesni.asm       (VEX, AVX2 tier)
;;        racket asm/gen/gcm-aesni-x86.rkt --sse asm/x86/gcm_aesni_sse.asm   (SSE, the tier below)

(require racket/list racket/string)

(define args (vector->list (current-command-line-arguments)))
;; SSE mode (legacy encodings, two-operand forms, aligned memory operands only for the table and
;; key schedule, which the C side copies to aligned buffers) with --sse; the output is the last argument
(define sse? (and (member "--sse" args) #t))
(define out-path (let ([rest (remove "--sse" args)]) (and (pair? rest) (last rest))))
(define fname (if sse? "rktcrypto_gcm_crypt_aesni_sse" "rktcrypto_gcm_crypt_aesni"))
(define pfx (if sse? "gcm_aesnisse" "gcm_aesni"))

(define out (open-output-string))
(define (emit fmt . args) (write-string (apply format fmt args) out) (newline out))

;; ---- instruction spelling in the two modes -----------------------------------------------------
;; (op3 mn d a src [imm]): VEX "v<mn> d, a, src" ; SSE "movdqa d, a" (when d != a) then "<mn> d, src"
(define (op3 mn d a src [imm #f])
  (define immstr (if imm (format ", ~a" imm) ""))
  (if sse?
      (append (if (equal? d a) '() (list (format "  movdqa ~a, ~a" d a)))
              (list (format "  ~a ~a, ~a~a" mn d src immstr)))
      (list (format "  v~a ~a, ~a, ~a~a" mn d a src immstr))))
(define (shift mn d a n)   ; immediate shifts: VEX "v<mn> d, a, n" ; SSE "movdqa d, a; <mn> d, n"
  (if sse?
      (append (if (equal? d a) '() (list (format "  movdqa ~a, ~a" d a))) (list (format "  ~a ~a, ~a" mn d n)))
      (list (format "  v~a ~a, ~a, ~a" mn d a n))))
(define (ld d mem) (list (format "  ~amovdqu ~a, ~a" (if sse? "" "v") d mem)))
(define (st mem s) (list (format "  ~amovdqu ~a, ~a" (if sse? "" "v") mem s)))
(define (pshufd d a imm) (list (format "  ~apshufd ~a, ~a, ~a" (if sse? "" "v") d a imm)))

;; ---- GHASH ops: products of block j (of 8) taken from memory at [q.g + 16 j] ---------------------
;; table: scaled H^(8-j) at htab + 384 + 16 j, its Karatsuba row at htab + 896 + 16 j
(define (prod-ops j first?)
  (define row (format "xmmword ptr [q.htab + ~a]" (+ 384 (* 16 j))))
  (define krow (format "xmmword ptr [q.htab + ~a]" (+ 896 (* 16 j))))
  (append
   (ld "xmm.t" (format "xmmword ptr [q.g + ~a]" (* 16 j)))
   (op3 "pshufb" "xmm.t" "xmm.t" (format "xmmword ptr [rip + ~a_bswap]" pfx))
   (if (= j 0) (op3 "pxor" "xmm.t" "xmm.t" "xmm.acc") '())
   (if first?
       (append (op3 "pclmulqdq" "xmm.lo" "xmm.t" row "0x00")
               (op3 "pclmulqdq" "xmm.hi" "xmm.t" row "0x11")
               (pshufd "xmm.t2" "xmm.t" "0x4e")
               (op3 "pxor" "xmm.t2" "xmm.t2" "xmm.t")
               (op3 "pclmulqdq" "xmm.mid" "xmm.t2" krow "0x00"))
       (append (op3 "pclmulqdq" "xmm.t2" "xmm.t" row "0x00")
               (op3 "pxor" "xmm.lo" "xmm.lo" "xmm.t2")
               (op3 "pclmulqdq" "xmm.t2" "xmm.t" row "0x11")
               (op3 "pxor" "xmm.hi" "xmm.hi" "xmm.t2")
               (pshufd "xmm.t2" "xmm.t" "0x4e")
               (op3 "pxor" "xmm.t2" "xmm.t2" "xmm.t")
               (op3 "pclmulqdq" "xmm.t2" "xmm.t2" krow "0x00")
               (op3 "pxor" "xmm.mid" "xmm.mid" "xmm.t2")))))
(define prod-independent (append* (for/list ([j (in-range 1 8)]) (prod-ops j (= j 1)))))
(define prod-acc (prod-ops 0 #f))
;; fold mid into lo/hi, reduce (table rows carry x^-1: fold modulo the polynomial only), acc = result
(define fold+reduce
  (append
   (op3 "pxor" "xmm.mid" "xmm.mid" "xmm.lo")
   (op3 "pxor" "xmm.mid" "xmm.mid" "xmm.hi")
   (shift "pslldq" "xmm.t" "xmm.mid" 8)
   (shift "psrldq" "xmm.t2" "xmm.mid" 8)
   (op3 "pxor" "xmm.lo" "xmm.lo" "xmm.t")
   (op3 "pxor" "xmm.hi" "xmm.hi" "xmm.t2")
   (shift "pslld" "xmm.t" "xmm.lo" 31)
   (shift "pslld" "xmm.t2" "xmm.lo" 30)
   (shift "pslld" "xmm.mid" "xmm.lo" 25)
   (op3 "pxor" "xmm.t" "xmm.t" "xmm.t2")
   (op3 "pxor" "xmm.t" "xmm.t" "xmm.mid")
   (shift "psrldq" "xmm.t2" "xmm.t" 4)
   (shift "pslldq" "xmm.t" "xmm.t" 12)
   (op3 "pxor" "xmm.lo" "xmm.lo" "xmm.t")
   (shift "psrld" "xmm.t" "xmm.lo" 1)
   (shift "psrld" "xmm.mid" "xmm.lo" 2)
   (op3 "pxor" "xmm.t" "xmm.t" "xmm.mid")
   (shift "psrld" "xmm.mid" "xmm.lo" 7)
   (op3 "pxor" "xmm.t" "xmm.t" "xmm.mid")
   (op3 "pxor" "xmm.t" "xmm.t" "xmm.t2")
   (op3 "pxor" "xmm.lo" "xmm.lo" "xmm.t")
   (op3 "pxor" "xmm.acc" "xmm.hi" "xmm.lo")))

;; ---- AES slots of one 128-byte chunk --------------------------------------------------------------
(define (aes-slots nr tag enc?)
  (append
   (list (append* (for/list ([j 8]) (op3 "paddd" (format "xmm.s~a" j) "xmm.base" (format "xmmword ptr [rip + ~a_inc + ~a]" pfx (* 16 j))))))
   (list (append (append* (for/list ([j 8]) (op3 "pshufb" (format "xmm.s~a" j) (format "xmm.s~a" j) (format "xmmword ptr [rip + ~a_bswap]" pfx))))
                 (append* (for/list ([j 8]) (op3 "pxor" (format "xmm.s~a" j) (format "xmm.s~a" j) "xmmword ptr [q.rk]")))))
   (for/list ([r (in-range 1 nr)])
     (append* (for/list ([j 8]) (op3 "aesenc" (format "xmm.s~a" j) (format "xmm.s~a" j) (format "xmmword ptr [q.rk + ~a]" (* 16 r))))))
   (list (append* (for/list ([j 8]) (op3 "aesenclast" (format "xmm.s~a" j) (format "xmm.s~a" j) (format "xmmword ptr [q.rk + ~a]" (* 16 nr))))))
   ;; input XOR: a VEX memory operand may be unaligned; the SSE tier loads through scratch t (free here)
   (list (append* (for/list ([j 8]) (append (if sse?
                                                (append (ld "xmm.t" (format "xmmword ptr [q.in + ~a]" (* 16 j)))
                                                        (op3 "pxor" (format "xmm.s~a" j) (format "xmm.s~a" j) "xmm.t"))
                                                (op3 "pxor" (format "xmm.s~a" j) (format "xmm.s~a" j) (format "xmmword ptr [q.in + ~a]" (* 16 j))))
                                            (st (format "xmmword ptr [q.out + ~a]" (* 16 j)) (format "xmm.s~a" j))))))))

(define (spread ops a b)
  (define n (add1 (- b a)))
  (define total (length ops))
  (for/list ([i n])
    (define lo (quotient (* i total) n))
    (define hi (quotient (* (add1 i) total) n))
    (cons (+ a i) (take (drop ops lo) (- hi lo)))))

(define (emit-chunk nr tag enc? ghash?)
  (define slots (aes-slots nr tag enc?))
  (define S (length slots))
  (define extra (make-vector S '()))
  (define (add! placement)
    (for ([p placement]) (vector-set! extra (car p) (append (vector-ref extra (car p)) (cdr p)))))
  (when ghash?
    (add! (spread prod-independent 0 (- S 5)))
    (add! (spread prod-acc (- S 4) (- S 2))))
  (for ([slot slots] [k (in-naturals)])
    (emit "  ;; -- slot ~a" k)
    (for-each (lambda (l) (emit "~a" l)) (vector-ref extra k))
    (for-each (lambda (l) (emit "~a" l)) slot))
  (when ghash? (for-each (lambda (l) (emit "~a" l)) fold+reduce)))

(define (emit-advance)
  (for-each (lambda (l) (emit "~a" l)) (op3 "paddd" "xmm.base" "xmm.base" (format "xmmword ptr [rip + ~a_eight]" pfx)))
  (emit "  add q.in, 128")
  (emit "  add q.out, 128")
  (emit "  add q.ret, 128")
  (emit "  sub q.len, 128"))

(define (emit-path nr)
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
  (emit "d~a:" nr)
  (emit "  mov q.g, q.in")
  (emit-chunk nr (format "d~a_l" nr) #f #t)
  (emit-advance)
  (emit "  cmp q.len, 128")
  (emit "  jae d~a" nr)
  (emit "  jmp fin"))

(emit ";; Fused AES-GCM bulk pass on AES-NI + PCLMULQDQ~a (x86-64 SysV), ~a." (if sse? "" " + AVX2") (if sse? "the SSE tier below AVX2 (legacy encodings; the key schedule and table must be 16-byte aligned, the C side copies them)" "the tier below VAES"))
(emit ";; GENERATED by asm/gen/gcm-aesni-x86.rkt (see its header); edit the generator.")
(emit ";;   intptr_t ~a(const struct rktcrypto_gcm_vaes_ctx *c," fname)
(emit ";;                                      const unsigned char *in, unsigned char *out, intptr_t len)")
(emit ";; The same context and table as rktcrypto_gcm_crypt_vaes; processes 128-byte chunks and returns")
(emit ";; the bytes done (a multiple of 128); the C side finishes the remainder. Oracle: the two-pass")
(emit ";; path (the tiers above cleared); gate: asm/tests/test_gcm_vaes.c.")
(emit "")
(emit ".rodata ~a_bswap align=16" pfx)
(emit "  .byte 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0")
(emit ".end")
(emit ".rodata ~a_inc align=16                  ; block j of a chunk: counter + j in dword 0" pfx)
(for ([j 8]) (emit "  .long ~a, 0, 0, 0" j))
(emit ".end")
(emit ".rodata ~a_eight align=16" pfx)
(emit "  .long 8, 0, 0, 0")
(emit ".end")
(emit "")
(emit ".function ~a export (" fname)
(emit "  in: q.ctx, q.in, q.out, q.len")
(emit "  out: q.ret")
(emit ")")
(unless sse? (emit "  .simd avx2"))
(emit "  xor d.ret, d.ret")
(emit "  cmp q.len, 128")
(emit "  jb done")
(emit "  mov q.rk, qword ptr [q.ctx]")
(emit "  mov q.htab, qword ptr [q.ctx + 8]")
(emit "  mov q.p, qword ptr [q.ctx + 16]                ; counter block")
(emit "  mov q.nr, qword ptr [q.ctx + 32]")
(emit "  mov q.enc, qword ptr [q.ctx + 40]")
(for-each (lambda (l) (emit "~a" l)) (ld "xmm.base" "xmmword ptr [q.p]"))
(for-each (lambda (l) (emit "~a" l)) (op3 "pshufb" "xmm.base" "xmm.base" (format "xmmword ptr [rip + ~a_bswap]" pfx)))
(emit "  mov q.p, qword ptr [q.ctx + 24]                ; accumulator")
(for-each (lambda (l) (emit "~a" l)) (ld "xmm.acc" "xmmword ptr [q.p]"))
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
(emit "  lea q.g, [q.out -128]")
(for-each (lambda (l) (emit "~a" l)) prod-independent)
(for-each (lambda (l) (emit "~a" l)) prod-acc)
(for-each (lambda (l) (emit "~a" l)) fold+reduce)
(emit "fin:")
(for-each (lambda (l) (emit "~a" l)) (st "xmmword ptr [q.p]" "xmm.acc"))
(emit "  mov q.p, qword ptr [q.ctx + 16]")
(for-each (lambda (l) (emit "~a" l)) (op3 "pshufb" "xmm.base" "xmm.base" (format "xmmword ptr [rip + ~a_bswap]" pfx)))
(for-each (lambda (l) (emit "~a" l)) (st "xmmword ptr [q.p]" "xmm.base"))
(emit "done:")
(emit "  ret")
(emit ".end")

(void
 (if out-path
     (call-with-output-file out-path #:exists 'truncate (lambda (o) (write-string (get-output-string out) o)))
     (write-string (get-output-string out) (current-output-port))))
