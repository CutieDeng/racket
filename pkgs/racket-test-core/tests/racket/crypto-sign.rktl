
(load-relative "loadtest.rktl")

(Section 'crypto-sign)

(require racket/crypto
         file/sha1)

(define (unhex s) (hex-string->bytes s))

;; ----------------------------------------
;; Ed25519 known-answer (seed = 00 01 .. 1f; verified against OpenSSL)

(define seed (list->bytes (for/list ([i (in-range 32)]) i)))
(define expected-pk "03a107bff3ce10be1d70dd18e74bc09967e4d6309ba50d5f1ddc8664125531b8")
(define expected-sig-abc
  (string-append "cc46d62d3754f41754b27b6ea2cb2c272bafa7a5a1f6062bd060f414e50caaea"
                 "c2da66ad39cef4424a90236ea907b7d8057e3443dc5abfc9986967ee7213a407"))

(test expected-pk bytes->hex-string (ed25519-public-key seed))
(test expected-sig-abc bytes->hex-string (ed25519-sign seed #"abc"))

;; valid signature verifies; wrong message / tampered signature do not
(let ([pk (ed25519-public-key seed)]
      [sig (ed25519-sign seed #"abc")])
  (test #t ed25519-verify pk #"abc" sig)
  (test #f ed25519-verify pk #"abd" sig)
  (let ([bad (bytes-copy sig)])
    (bytes-set! bad 0 (bitwise-xor (bytes-ref bad 0) 1))
    (test #f ed25519-verify pk #"abc" bad))
  ;; wrong public key
  (test #f ed25519-verify (ed25519-public-key (make-bytes 32 5)) #"abc" sig))

;; ----------------------------------------
;; Sign/verify round-trips with fresh random keys and various messages

(for ([i (in-range 20)])
  (define sk (ed25519-generate-private-key))
  (define pk (ed25519-public-key sk))
  (define msg (make-bytes (modulo (* i 7) 100) (modulo i 256)))
  (test 32 bytes-length sk)
  (test 32 bytes-length pk)
  (define sig (ed25519-sign sk msg))
  (test 64 bytes-length sig)
  (test #t ed25519-verify pk msg sig)
  ;; a signature from one key does not verify under another
  (test #f ed25519-verify (ed25519-public-key (ed25519-generate-private-key)) msg sig))

;; empty message signs and verifies
(let* ([sk (ed25519-generate-private-key)]
       [pk (ed25519-public-key sk)]
       [sig (ed25519-sign sk #"")])
  (test #t ed25519-verify pk #"" sig))

;; ----------------------------------------
;; P-256 ECDSA (random nonce, so signatures vary; verify round-trips)

(for ([i (in-range 15)])
  (define sk (p256-generate-private-key))
  (define pk (p256-public-key sk))
  (define msg (make-bytes (modulo (* i 11) 80) (modulo (+ i 3) 256)))
  (define sig (p256-ecdsa-sign sk msg))
  (test 64 bytes-length sig)
  (test #t p256-ecdsa-verify pk msg sig)
  (test #f p256-ecdsa-verify pk (bytes-append msg #"x") sig)      ; wrong message
  ;; tampered signature
  (let ([bad (bytes-copy sig)])
    (bytes-set! bad 0 (bitwise-xor (bytes-ref bad 0) 1))
    (test #f p256-ecdsa-verify pk msg bad))
  ;; wrong key
  (test #f p256-ecdsa-verify (p256-public-key (p256-generate-private-key)) msg sig))

;; two signatures of the same message differ (random nonce)
(let ([sk (p256-generate-private-key)])
  (test #f equal? (p256-ecdsa-sign sk #"same") (p256-ecdsa-sign sk #"same")))

;; ----------------------------------------
;; Negative cases

(err/rt-test (ed25519-public-key (make-bytes 16)) exn:fail?)      ; wrong seed size
(err/rt-test (ed25519-sign (make-bytes 8) #"m") exn:fail?)        ; wrong seed size
(err/rt-test (ed25519-public-key "not bytes") exn:fail:contract?)
;; verify with malformed sizes returns #f rather than raising
(test #f ed25519-verify (make-bytes 10) #"m" (make-bytes 64))
(test #f ed25519-verify (make-bytes 32) #"m" (make-bytes 10))

(report-errs)
