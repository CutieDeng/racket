
(load-relative "loadtest.rktl")

(Section 'crypto-kem)

(require racket/crypto)

;; ----------------------------------------
;; ML-KEM-768 (FIPS 203) sizes

(test 1184 values MLKEM768-PUBLIC-KEY-BYTES)
(test 2400 values MLKEM768-SECRET-KEY-BYTES)
(test 1088 values MLKEM768-CIPHERTEXT-BYTES)
(test 32   values MLKEM768-SHARED-SECRET-BYTES)

;; ----------------------------------------
;; Key generation, encapsulation, decapsulation round-trip

(for ([i (in-range 20)])
  (define-values (pk sk) (mlkem768-generate-key))
  (test 1184 bytes-length pk)
  (test 2400 bytes-length sk)
  (define-values (ct ss) (mlkem768-encaps pk))
  (test 1088 bytes-length ct)
  (test 32 bytes-length ss)
  ;; the party holding sk recovers the same shared secret
  (test ss mlkem768-decaps ct sk))

;; each key generation is independent
(let-values ([(pk1 sk1) (mlkem768-generate-key)]
             [(pk2 sk2) (mlkem768-generate-key)])
  (test #f equal? pk1 pk2)
  (test #f equal? sk1 sk2))

;; encapsulation is randomized: two encaps to the same key differ,
;; but both decapsulate correctly
(let-values ([(pk sk) (mlkem768-generate-key)])
  (define-values (ct1 ss1) (mlkem768-encaps pk))
  (define-values (ct2 ss2) (mlkem768-encaps pk))
  (test #f equal? ct1 ct2)
  (test #f equal? ss1 ss2)
  (test ss1 mlkem768-decaps ct1 sk)
  (test ss2 mlkem768-decaps ct2 sk))

;; ----------------------------------------
;; Implicit rejection: a ciphertext meant for another key, or a
;; tampered ciphertext, decapsulates to a pseudorandom secret (not an
;; error) that does not match the encapsulated secret.

(let-values ([(pk-a sk-a) (mlkem768-generate-key)]
             [(pk-b sk-b) (mlkem768-generate-key)])
  (define-values (ct ss) (mlkem768-encaps pk-a))
  ;; decapsulating A's ciphertext with B's key gives some 32-byte value
  ;; that (with overwhelming probability) differs from ss
  (define wrong (mlkem768-decaps ct sk-b))
  (test 32 bytes-length wrong)
  (test #f equal? ss wrong))

(let-values ([(pk sk) (mlkem768-generate-key)])
  (define-values (ct ss) (mlkem768-encaps pk))
  (define bad (bytes-copy ct))
  (bytes-set! bad 0 (bitwise-xor (bytes-ref bad 0) 1))
  (define got (mlkem768-decaps bad sk))
  (test 32 bytes-length got)          ; no error raised
  (test #f equal? ss got))

;; ----------------------------------------
;; Negative cases: malformed sizes raise

(err/rt-test (mlkem768-encaps (make-bytes 100)) exn:fail?)
(err/rt-test (mlkem768-decaps (make-bytes 100) (make-bytes 2400)) exn:fail?)
(err/rt-test (mlkem768-decaps (make-bytes 1088) (make-bytes 100)) exn:fail?)
(err/rt-test (mlkem768-encaps "not bytes") exn:fail:contract?)

;; ----------------------------------------
;; X25519MLKEM768 hybrid KEM (wire order verified against OpenSSL)

(test 1216 values X25519MLKEM768-PUBLIC-KEY-BYTES)
(test 2432 values X25519MLKEM768-SECRET-KEY-BYTES)
(test 1120 values X25519MLKEM768-CIPHERTEXT-BYTES)
(test 64   values X25519MLKEM768-SHARED-SECRET-BYTES)

(for ([i (in-range 20)])
  (define-values (ek dk) (x25519mlkem768-generate-key))
  (test 1216 bytes-length ek)
  (test 2432 bytes-length dk)
  (define-values (ct ss) (x25519mlkem768-encaps ek))
  (test 1120 bytes-length ct)
  (test 64 bytes-length ss)
  (test ss x25519mlkem768-decaps ct dk))

;; the hybrid secret is the ML-KEM secret concatenated with the X25519
;; secret: its first 32 bytes match the standalone ML-KEM decapsulation
(let-values ([(ek dk) (x25519mlkem768-generate-key)])
  (define-values (ct ss) (x25519mlkem768-encaps ek))
  (define mlss (mlkem768-decaps (subbytes ct 0 1088) (subbytes dk 0 2400)))
  (test mlss values (subbytes ss 0 32)))

;; randomized: two encapsulations differ, both decapsulate correctly
(let-values ([(ek dk) (x25519mlkem768-generate-key)])
  (define-values (ct1 ss1) (x25519mlkem768-encaps ek))
  (define-values (ct2 ss2) (x25519mlkem768-encaps ek))
  (test #f equal? ct1 ct2)
  (test #f equal? ss1 ss2)
  (test ss1 x25519mlkem768-decaps ct1 dk)
  (test ss2 x25519mlkem768-decaps ct2 dk))

;; wrong key: decapsulating with a different dk gives a different secret
(let-values ([(ek-a dk-a) (x25519mlkem768-generate-key)]
             [(ek-b dk-b) (x25519mlkem768-generate-key)])
  (define-values (ct ss) (x25519mlkem768-encaps ek-a))
  (test #f equal? ss (x25519mlkem768-decaps ct dk-b)))

;; malformed sizes raise
(err/rt-test (x25519mlkem768-encaps (make-bytes 100)) exn:fail?)
(err/rt-test (x25519mlkem768-decaps (make-bytes 100) (make-bytes 2432)) exn:fail?)
(err/rt-test (x25519mlkem768-decaps (make-bytes 1120) (make-bytes 100)) exn:fail?)

(report-errs)
