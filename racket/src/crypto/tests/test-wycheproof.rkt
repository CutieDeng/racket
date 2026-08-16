#lang racket
;; Project Wycheproof conformance gate for librktcrypto's signature verifiers.
;;
;; Runs Google/C2SP Wycheproof test vectors (vendored under wycheproof-vectors/)
;; through the same verify.rkt path the TLS/X.509 stack uses. Each vector is a
;; (msg, sig, expected-result) triple; "valid" must be accepted, "invalid" must
;; be rejected, "acceptable" may go either way.
;;
;; This gate has already caught three real defects, all now fixed:
;;   * ECDSA DER parser too lenient -> signature malleability (non-canonical DER).
;;   * ECDSA DER parser rejected minimal long-form SEQUENCE length -> ALL P-521
;;     verification failed (P-521 sigs are ~139 bytes, so length is long-form).
;;   * Ed25519 FFI call passed (pk, sig) in the (sig, pk) slots -> every Ed25519
;;     verification failed; plus no length / no S<L (RFC 8032 §5.1.7) checks.
;;
;;   racket/bin/racket racket/src/crypto/tests/test-wycheproof.rkt
(require json racket/runtime-path
         (only-in "../../../collects/openssl/private/rktcrypto-verify.rkt" verify-signature-over)
         (only-in "../../../collects/openssl/private/rktcrypto-x509.rkt" pubkey))

(define (hx s) (list->bytes (for/list ([i (in-range 0 (string-length s) 2)])
                              (string->number (substring s i (+ i 2)) 16))))
(define (strip0 b) (let loop ([i 0]) (if (and (< i (sub1 (bytes-length b))) (zero? (bytes-ref b i)))
                                          (loop (add1 i)) (subbytes b i))))

(define (run-file path)
  (define d (call-with-input-file path read-json))
  (define alg (hash-ref d 'algorithm))
  (define va 0) (define vr 0) (define ir 0) (define ia 0) (define ae 0)
  (for ([g (in-list (hash-ref d 'testGroups))])
    (define-values (mk-pub scheme)
      (cond
        [(string=? alg "ECDSA")
         (define pk (hash-ref g 'publicKey))
         (define curve (hash-ref pk 'curve))
         (define pt (hx (hash-ref pk 'uncompressed)))
         (values (lambda () (pubkey 'ec #f #f
                                    (case curve [("secp256r1") 'p256] [("secp384r1") 'p384] [("secp521r1") 'p521])
                                    pt))
                 (case curve [("secp256r1") #x0403] [("secp384r1") #x0503] [("secp521r1") #x0603]))]
        [(string=? alg "EDDSA")
         (define pk (hx (hash-ref (hash-ref g 'publicKey) 'pk)))
         (values (lambda () (pubkey 'ed25519 #f #f #f pk)) #x0807)]
        [(regexp-match? #rx"^RSASSA" alg)
         (define pk (hash-ref g 'publicKey))
         (define n (strip0 (hx (hash-ref pk 'modulus))))
         (define e (strip0 (hx (hash-ref pk 'publicExponent))))
         (values (lambda () (pubkey 'rsa n e #f #f))
                 (case (hash-ref g 'sha) [("SHA-256") #x0401] [("SHA-384") #x0501] [("SHA-512") #x0601]))]
        [else (error 'wycheproof "unsupported algorithm ~a" alg)]))
    (define pub (mk-pub))
    (for ([t (in-list (hash-ref g 'tests))])
      (define msg (hx (hash-ref t 'msg)))
      (define sig (hx (hash-ref t 'sig)))
      (define res (hash-ref t 'result))
      (define ok (and (> (bytes-length sig) 0)
                      (with-handlers ([exn:fail? (lambda (_) #f)])
                        (and (verify-signature-over scheme pub msg sig) #t))))
      (cond
        [(string=? res "valid")   (if ok (set! va (add1 va))
                                         (begin (set! vr (add1 vr))
                                                (printf "  MISMATCH ~a tcId ~a: valid but REJECTED (~a)\n"
                                                        alg (hash-ref t 'tcId) (hash-ref t 'comment))))]
        [(string=? res "invalid") (if ok (begin (set! ia (add1 ia))
                                                (printf "  MISMATCH ~a tcId ~a: invalid but ACCEPTED (~a)\n"
                                                        alg (hash-ref t 'tcId) (hash-ref t 'comment)))
                                         (set! ir (add1 ir)))]
        [else (set! ae (add1 ae))])))
  (printf "  ~a [~a]: valid ~a/~a rej, invalid ~a rej/~a acc, either ~a\n"
          (let-values ([(_ f __) (split-path path)]) (path->string f)) alg va vr ir ia ae)
  (+ vr ia))

;; run over every vendored vector file next to this script
(define-runtime-path vec-dir "wycheproof-vectors")
(printf "Wycheproof conformance (librktcrypto verify.rkt path):\n")
(define bad
  (for/sum ([p (in-list (sort (map path->string (directory-list vec-dir)) string<?))]
            #:when (regexp-match? #rx"\\.json$" p))
    (run-file (build-path vec-dir p))))
(printf "Wycheproof: ~a\n" (if (zero? bad) "0 mismatches — ALL PASS" (format "~a mismatches" bad)))
(exit (if (zero? bad) 0 1))
