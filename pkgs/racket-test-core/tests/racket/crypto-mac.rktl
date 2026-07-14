
(load-relative "loadtest.rktl")

(Section 'crypto-mac)

(require racket/crypto
         file/sha1)

;; ----------------------------------------
;; SipHash-2-4 (reference vectors: 16-byte key = 0..15, input byte i = i)

(define sip-key (list->bytes (for/list ([i (in-range 16)]) i)))
(define (sip-in len) (list->bytes (for/list ([i (in-range len)]) i)))
(define (sip24 len) (bytes->hex-string (siphash-2-4 sip-key (sip-in len))))

(test "310e0edd47db6f72" sip24 0)
(test "fd67dc93c539f874" sip24 1)
(test "5a4fa9d909806c0d" sip24 2)
(test "2d7efbd796666785" sip24 3)
(test "b7877127e09427cf" sip24 4)
(test "8da699cd64557618" sip24 5)
(test "cee3fe586e46c9cb" sip24 6)
(test "37d1018bf50002ab" sip24 7)

;; output is 8 bytes
(test 8 bytes-length (siphash-2-4 sip-key #"anything"))
;; region selection matches a copy
(test (siphash-2-4 sip-key (subbytes (bytes-append #"XX" (sip-in 3)) 2))
      values (siphash-2-4 sip-key (bytes-append #"XX" (sip-in 3)) #:start 2))

;; SipHash-1-3 differs from SipHash-2-4 and is deterministic
(test #f equal? (siphash-1-3 sip-key #"data") (siphash-2-4 sip-key #"data"))
(test (siphash-1-3 sip-key #"data") values (siphash-1-3 sip-key #"data"))
(test 8 bytes-length (siphash-1-3 sip-key #"data"))

;; different keys give different results
(test #f equal? (siphash-2-4 sip-key #"x") (siphash-2-4 (make-bytes 16 0) #"x"))

;; ----------------------------------------
;; Negative cases

;; key must be exactly 16 bytes
(err/rt-test (siphash-2-4 (make-bytes 8) #"x") exn:fail?)
(err/rt-test (siphash-2-4 (make-bytes 32) #"x") exn:fail?)
(err/rt-test (siphash-2-4 "not bytes" #"x") exn:fail:contract?)
(err/rt-test (siphash-2-4 sip-key "not bytes") exn:fail:contract?)

(report-errs)
