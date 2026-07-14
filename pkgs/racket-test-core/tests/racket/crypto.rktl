
(load-relative "loadtest.rktl")

(Section 'crypto)

(require racket/crypto
         racket/random)

;; ----------------------------------------
;; crypto-random-bytes

(test 32 bytes-length (crypto-random-bytes 32))
(test 0 bytes-length (crypto-random-bytes 0))
(test #f immutable? (crypto-random-bytes 8))

;; Two independent 32-byte draws colliding means a broken source, not
;; bad luck (probability 2^-256):
(test #f equal? (crypto-random-bytes 32) (crypto-random-bytes 32))

;; A 64-byte draw of all zeros likewise:
(test #f equal? (make-bytes 64 0) (crypto-random-bytes 64))

;; Exercise the >256-byte path (getentropy loops in 256-byte chunks):
(test 5000 bytes-length (crypto-random-bytes 5000))

;; Distribution smoke test: 65536 draws must hit most byte values;
;; this catches "constant output" or "stuck bits" wiring errors only,
;; not statistical quality:
(test #t
      (lambda (bs)
        (define seen (make-vector 256 #f))
        (for ([b (in-bytes bs)]) (vector-set! seen b #t))
        (>= (for/sum ([v (in-vector seen)]) (if v 1 0)) 200))
      (crypto-random-bytes 65536))

;; crypto-random-bytes! fills exactly the requested range:
(let ([bs (make-bytes 40 170)])
  (test (void) crypto-random-bytes! bs 4 36)
  (test 170 bytes-ref bs 0)
  (test 170 bytes-ref bs 3)
  (test 170 bytes-ref bs 36)
  (test 170 bytes-ref bs 39)
  ;; middle 32 bytes are extremely unlikely to still be all #xAA:
  (test #f equal? (make-bytes 32 170) (subbytes bs 4 36)))

;; Defaults fill the whole byte string:
(let ([bs (make-bytes 64 0)])
  (test (void) crypto-random-bytes! bs)
  (test #f equal? (make-bytes 64 0) bs))

;; Empty range is a no-op:
(let ([bs (make-bytes 4 7)])
  (test (void) crypto-random-bytes! bs 2 2)
  (test (make-bytes 4 7) values bs))

;; Negative: bad arguments
(err/rt-test (crypto-random-bytes -1) exn:fail:contract?)
(err/rt-test (crypto-random-bytes 'x) exn:fail:contract?)
(err/rt-test (crypto-random-bytes! (bytes->immutable-bytes (make-bytes 4)))
             exn:fail:contract?)
(err/rt-test (crypto-random-bytes! "not bytes") exn:fail:contract?)
(err/rt-test (crypto-random-bytes! (make-bytes 4) 3 2) exn:fail:contract?)
(err/rt-test (crypto-random-bytes! (make-bytes 4) 0 5) exn:fail:contract?)
(err/rt-test (crypto-random-bytes! (make-bytes 4) -1 2) exn:fail:contract?)

;; ----------------------------------------
;; crypto-bytes=?

(test #t crypto-bytes=? #"" #"")
(test #t crypto-bytes=? #"abc" #"abc")
(test #f crypto-bytes=? #"abc" #"abd")
(test #f crypto-bytes=? #"abc" #"Abc")
(test #f crypto-bytes=? #"ab" #"abc")
(test #f crypto-bytes=? #"abc" #"ab")
(test #t crypto-bytes=? (make-bytes 1000 42) (make-bytes 1000 42))
(let ([b (make-bytes 1000 42)])
  (bytes-set! b 999 43)
  (test #f crypto-bytes=? (make-bytes 1000 42) b))
;; mutable vs immutable does not matter:
(test #t crypto-bytes=? (bytes 1 2 3) #"\1\2\3")

;; Negative: non-bytes arguments
(err/rt-test (crypto-bytes=? "abc" #"abc") exn:fail:contract?)
(err/rt-test (crypto-bytes=? #"abc" 3) exn:fail:contract?)

;; ----------------------------------------
;; crypto-bytes-clear!

(let ([bs (bytes 1 2 3 4 5 6 7 8)])
  (test (void) crypto-bytes-clear! bs 2 6)
  (test (bytes 1 2 0 0 0 0 7 8) values bs)
  (test (void) crypto-bytes-clear! bs)
  (test (make-bytes 8 0) values bs))

(let ([bs (bytes 9 9)])
  (test (void) crypto-bytes-clear! bs 1 1)
  (test (bytes 9 9) values bs))

;; Negative: immutable or bad range
(err/rt-test (crypto-bytes-clear! #"abcd") exn:fail:contract?)
(err/rt-test (crypto-bytes-clear! (make-bytes 4) 0 5) exn:fail:contract?)
(err/rt-test (crypto-bytes-clear! (make-bytes 4) 3 1) exn:fail:contract?)

;; ----------------------------------------
;; call-with-secret-bytes

(test 16 call-with-secret-bytes 16 bytes-length)
(test (make-bytes 8 0) call-with-secret-bytes 8 bytes-copy)

;; cleared after normal return:
(let ([saved #f])
  (call-with-secret-bytes 4 (lambda (bs)
                              (bytes-fill! bs 255)
                              (set! saved bs)))
  (test (make-bytes 4 0) values saved))

;; cleared after an escape:
(let ([saved #f])
  (with-handlers ([symbol? void])
    (call-with-secret-bytes 4 (lambda (bs)
                                (bytes-fill! bs 255)
                                (set! saved bs)
                                (raise 'escape))))
  (test (make-bytes 4 0) values saved))

(err/rt-test (call-with-secret-bytes -1 void) exn:fail:contract?)
(err/rt-test (call-with-secret-bytes 4 'not-a-proc) exn:fail:contract?)

;; ----------------------------------------
;; subsystem self-test

;; On CS hosts the rktcrypto subsystem must be present and pass; on
;; other hosts the function reports #f without failing:
(test (eq? 'chez-scheme (system-type 'vm)) crypto-subsystem-self-test?)

(report-errs)
