#lang racket/base
(require "../common/check.rkt"
         "../host/rktcrypto.rkt")

(provide crypto-random-bytes!
         crypto-bytes=?
         crypto-bytes-clear!
         crypto-subsystem-self-test?
         crypto-digest-ctx-size
         crypto-digest-size
         crypto-digest-block-size
         crypto-digest-xof?
         crypto-digest-init!
         crypto-digest-update!
         crypto-digest-final!
         crypto-digest-oneshot!)

(define mutable-bytes-contract "(and/c bytes? (not/c immutable?))")

(define (check-mutable-bytes who bstr)
  (check who (lambda (v) (and (bytes? v) (not (immutable? v))))
         #:contract mutable-bytes-contract
         bstr))

(define (check-start/end who bstr start end)
  (check who exact-nonnegative-integer? start)
  (check who exact-nonnegative-integer? end)
  (check-range who start end (bytes-length bstr) bstr))

;; Fills `bstr[start..end)` with cryptographically secure random
;; bytes from the operating system. Raises `exn:fail` if the system
;; entropy source is unavailable.
(define/who (crypto-random-bytes! bstr [start 0] [end (and (bytes? bstr) (bytes-length bstr))])
  (check-mutable-bytes who bstr)
  (check-start/end who bstr start end)
  (unless (eqv? 1 (rktcrypto_system_random bstr start end))
    (raise (exn:fail
            (string-append (symbol->string who)
                           ": system entropy source is unavailable")
            (current-continuation-marks))))
  (void))

;; Constant-time comparison with respect to buffer contents. Byte
;; strings of different lengths compare `#f` immediately; lengths are
;; not treated as secrets.
(define/who (crypto-bytes=? a b)
  (check who bytes? a)
  (check who bytes? b)
  (and (eqv? (bytes-length a) (bytes-length b))
       (eqv? 1 (rktcrypto_ct_bytes_equal a 0 b 0 (bytes-length a)))))

;; Zeroes `bstr[start..end)` such that the clearing cannot be elided
;; by compiler optimization. Best-effort at the process level: copies
;; made by the garbage collector or the operating system are outside
;; its reach.
(define/who (crypto-bytes-clear! bstr [start 0] [end (and (bytes? bstr) (bytes-length bstr))])
  (check-mutable-bytes who bstr)
  (check-start/end who bstr start end)
  (rktcrypto_secure_clear bstr start end))

;; Runs the rktcrypto known-answer self-tests; `#t` means all passed.
(define/who (crypto-subsystem-self-test?)
  (eqv? 1 (rktcrypto_selftest_core)))

;; ----------------------------------------
;; Message digests
;;
;; These low-level primitives take an algorithm symbol and expose the
;; rktcrypto digest dispatch. The digest context is a caller-provided
;; mutable byte string of at least `crypto-digest-ctx-size` bytes; the
;; collects-level `racket/crypto/digest` wraps this as a digest object
;; with a finalized flag, contracts, and port support.

(define (alg->id who alg)
  (case alg
    [(sha224)     RKTCRYPTO_SHA224]
    [(sha256)     RKTCRYPTO_SHA256]
    [(sha384)     RKTCRYPTO_SHA384]
    [(sha512)     RKTCRYPTO_SHA512]
    [(sha512/256) RKTCRYPTO_SHA512_256]
    [(sha3-224)   RKTCRYPTO_SHA3_224]
    [(sha3-256)   RKTCRYPTO_SHA3_256]
    [(sha3-384)   RKTCRYPTO_SHA3_384]
    [(sha3-512)   RKTCRYPTO_SHA3_512]
    [(shake128)   RKTCRYPTO_SHAKE128]
    [(shake256)   RKTCRYPTO_SHAKE256]
    [(blake2b)    RKTCRYPTO_BLAKE2B]
    [else (raise-argument-error who "crypto-digest-algorithm/c" alg)]))

(define/who (crypto-digest-ctx-size alg)
  (rktcrypto_digest_ctx_size (alg->id who alg)))

(define/who (crypto-digest-size alg)
  (rktcrypto_digest_size (alg->id who alg)))

(define/who (crypto-digest-block-size alg)
  (rktcrypto_digest_block_size (alg->id who alg)))

(define/who (crypto-digest-xof? alg)
  (eqv? 1 (rktcrypto_digest_is_xof (alg->id who alg))))

(define (check-ctx who ctx alg-id)
  (check-mutable-bytes who ctx)
  (define need (rktcrypto_digest_ctx_size alg-id))
  (unless (>= (bytes-length ctx) need)
    (raise-arguments-error who "digest context byte string is too small"
                           "given" (bytes-length ctx)
                           "required" need)))

(define (fail-digest who)
  (raise (exn:fail (string-append (symbol->string who) ": digest operation failed")
                   (current-continuation-marks))))

(define/who (crypto-digest-init! alg ctx [outlen 0])
  (define id (alg->id who alg))
  (check-ctx who ctx id)
  (check who exact-nonnegative-integer? outlen)
  (unless (eqv? 1 (rktcrypto_digest_init id ctx (bytes-length ctx) outlen))
    (fail-digest who))
  (void))

(define/who (crypto-digest-update! alg ctx data [start 0] [end (and (bytes? data) (bytes-length data))])
  (define id (alg->id who alg))
  (check-ctx who ctx id)
  (check who bytes? data)
  (check-start/end who data start end)
  (unless (eqv? 1 (rktcrypto_digest_update id ctx (bytes-length ctx) data start end))
    (fail-digest who))
  (void))

(define/who (crypto-digest-final! alg ctx out [out-start 0] [out-len (and (bytes? out) (- (bytes-length out) out-start))])
  (define id (alg->id who alg))
  (check-ctx who ctx id)
  (check-mutable-bytes who out)
  (check who exact-nonnegative-integer? out-start)
  (check who exact-nonnegative-integer? out-len)
  (check-range who out-start (+ out-start out-len) (bytes-length out) out)
  (unless (eqv? 1 (rktcrypto_digest_final id ctx (bytes-length ctx) out out-start out-len))
    (fail-digest who))
  (void))

(define/who (crypto-digest-oneshot! alg data data-start data-end out out-start out-len)
  (define id (alg->id who alg))
  (check who bytes? data)
  (check-start/end who data data-start data-end)
  (check-mutable-bytes who out)
  (check who exact-nonnegative-integer? out-start)
  (check who exact-nonnegative-integer? out-len)
  (check-range who out-start (+ out-start out-len) (bytes-length out) out)
  (unless (eqv? 1 (rktcrypto_digest_oneshot id data data-start data-end out out-start out-len))
    (fail-digest who))
  (void))
