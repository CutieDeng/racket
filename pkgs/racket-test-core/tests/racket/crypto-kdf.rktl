
(load-relative "loadtest.rktl")

(Section 'crypto-kdf)

(require racket/crypto
         file/sha1)

(define (hx bs) (bytes->hex-string bs))

;; ----------------------------------------
;; HKDF (RFC 5869 Test Case 1, SHA-256)

(define tc1-ikm (make-bytes 22 #x0b))
(define tc1-salt (list->bytes (for/list ([i (in-range 13)]) i)))
(define tc1-info (list->bytes (for/list ([i (in-range 10)]) (+ #xf0 i))))

(test "077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5"
      hx (hkdf-extract 'sha256 tc1-ikm #:salt tc1-salt))
(test "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865"
      hx (hkdf 'sha256 tc1-ikm #:salt tc1-salt #:info tc1-info #:length 42))

;; RFC 5869 Test Case 3 (zero-length salt and info)
(test "19ef24a32c717b167f33a91d6f648bdf96596776afdb6377ac434c1c293ccb04"
      hx (hkdf-extract 'sha256 (make-bytes 22 #x0b)))
(test "8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d9d201395faa4b61a96c8"
      (lambda (v) v)
      (bytes->hex-string (hkdf 'sha256 (make-bytes 22 #x0b) #:length 42)))

;; default (empty) salt/info still works and is deterministic
(test #t bytes? (hkdf 'sha256 #"ikm" #:length 32))
(test (hkdf 'sha256 #"ikm" #:length 32)
      values (hkdf 'sha256 #"ikm" #:length 32 #:salt #"" #:info #""))

;; ----------------------------------------
;; PBKDF2-HMAC-SHA256 (known vectors)

(test "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b"
      hx (pbkdf2 'sha256 #"password" #"salt" #:iterations 1 #:length 32))
(test "ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43"
      hx (pbkdf2 'sha256 #"password" #"salt" #:iterations 2 #:length 32))
;; longer output than one block, crossing the hash-length boundary
(test 50 bytes-length (pbkdf2 'sha256 #"password" #"salt" #:iterations 3 #:length 50))

;; ----------------------------------------
;; Argon2id (RFC 9106 test vector)

(test "0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659"
      hx (argon2id (make-bytes 32 1) (make-bytes 16 2)
                   #:secret (make-bytes 8 3) #:ad (make-bytes 12 4)
                   #:iterations 3 #:memory 32 #:parallelism 4 #:length 32))
;; default parameters produce a 32-byte tag; deterministic
(let ([h (argon2id #"password" #"saltsaltsaltsalt" #:iterations 1 #:memory 64 #:parallelism 1)])
  (test 32 bytes-length h)
  (test h argon2id #"password" #"saltsaltsaltsalt" #:iterations 1 #:memory 64 #:parallelism 1))
;; different salt -> different hash
(test #f equal?
      (argon2id #"pw" #"salt-one-16bytes" #:iterations 1 #:memory 32 #:parallelism 1)
      (argon2id #"pw" #"salt-two-16bytes" #:iterations 1 #:memory 32 #:parallelism 1))
;; custom output length
(test 64 bytes-length
      (argon2id #"pw" #"saltsaltsaltsalt" #:iterations 1 #:memory 32 #:parallelism 1 #:length 64))
;; negative: non-positive parameters
(err/rt-test (argon2id #"p" #"s" #:iterations 0) exn:fail:contract?)
(err/rt-test (argon2id #"p" #"s" #:length 0) exn:fail:contract?)
(err/rt-test (argon2id "not bytes" #"s") exn:fail:contract?)

;; ----------------------------------------
;; Negative cases

(err/rt-test (hkdf 'shake128 #"ikm" #:length 32) exn:fail:contract?)   ; XOF not allowed
(err/rt-test (hkdf 'sha256 #"ikm" #:length 0) exn:fail:contract?)      ; length must be positive
(err/rt-test (hkdf-expand 'sha256 #"prk" (* 256 32)) exn:fail?)        ; too long
(err/rt-test (pbkdf2 'sha256 #"p" #"s" #:iterations 0 #:length 16) exn:fail:contract?)
(err/rt-test (pbkdf2 'sha256 "not bytes" #"s" #:iterations 1 #:length 16) exn:fail:contract?)

(report-errs)
