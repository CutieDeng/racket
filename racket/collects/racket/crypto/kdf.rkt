#lang racket/base

;; Key-derivation functions over the built-in HMAC.
;;
;; HKDF (RFC 5869) and PBKDF2 (RFC 8018) are orchestrated in Racket on
;; top of the C HMAC; the hash compression stays in rktcrypto. PBKDF2
;; with a large iteration count is CPU-bound in this Racket loop; a C
;; inner loop is a planned optimization.

(require racket/contract/base
         "digest.rkt"
         "mac.rkt"
         (prefix-in u: "util.rkt"))

(define (kdf-hash? v)
  (and (memq v (digest-algorithms)) (not (digest-xof? v)) #t))
(define kdf-hash/c (flat-named-contract 'kdf-hash/c kdf-hash?))

;; HKDF-Extract: PRK = HMAC(salt, ikm). An empty salt defaults to a
;; string of hash-length zero bytes, per RFC 5869.
(define (hkdf-extract alg ikm #:salt [salt #""])
  (define s (if (= (bytes-length salt) 0)
                (make-bytes (digest-output-size alg) 0)
                salt))
  (hmac-bytes alg s ikm))

;; HKDF-Expand: OKM = T(1) || T(2) || ... truncated to `length`.
(define (hkdf-expand alg prk length #:info [info #""])
  (define hlen (digest-output-size alg))
  (define n (quotient (+ length hlen -1) hlen))
  (unless (<= n 255)
    (raise-arguments-error 'hkdf-expand "requested length too large"
                           "length" length "maximum" (* 255 hlen)))
  (define out (make-bytes (* n hlen)))
  (let loop ([i 1] [prev #""])
    (when (<= i n)
      (define h (make-hmac alg prk))
      (hmac-update! h prev)
      (hmac-update! h info)
      (hmac-update! h (bytes i))
      (define t (hmac-final! h))
      (bytes-copy! out (* (sub1 i) hlen) t)
      (loop (add1 i) t)))
  (subbytes out 0 length))

;; One-shot HKDF (extract then expand).
(define (hkdf alg ikm #:length length #:salt [salt #""] #:info [info #""])
  (hkdf-expand alg (hkdf-extract alg ikm #:salt salt) length #:info info))

;; PBKDF2-HMAC (RFC 8018).
(define (pbkdf2 alg password salt #:iterations iterations #:length length)
  (define hlen (digest-output-size alg))
  (define blocks (quotient (+ length hlen -1) hlen))
  (define out (make-bytes (* blocks hlen)))
  (for ([blk (in-range 1 (add1 blocks))])
    (define int-be (bytes (arithmetic-shift blk -24)
                          (bitwise-and (arithmetic-shift blk -16) #xff)
                          (bitwise-and (arithmetic-shift blk -8) #xff)
                          (bitwise-and blk #xff)))
    (define u1 (let ([h (make-hmac alg password)])
                 (hmac-update! h salt)
                 (hmac-update! h int-be)
                 (hmac-final! h)))
    (define acc (bytes-copy u1))
    (let loop ([i 2] [prev u1])
      (when (<= i iterations)
        (define u (hmac-bytes alg password prev))
        (for ([j (in-range hlen)])
          (bytes-set! acc j (bitwise-xor (bytes-ref acc j) (bytes-ref u j))))
        (loop (add1 i) u)))
    (bytes-copy! out (* (sub1 blk) hlen) acc))
  (subbytes out 0 length))

(provide kdf-hash/c
         (contract-out
          [hkdf (->* (kdf-hash/c bytes? #:length exact-positive-integer?)
                     (#:salt bytes? #:info bytes?)
                     bytes?)]
          [hkdf-extract (->* (kdf-hash/c bytes?) (#:salt bytes?) bytes?)]
          [hkdf-expand (->* (kdf-hash/c bytes? exact-positive-integer?)
                            (#:info bytes?) bytes?)]
          [pbkdf2 (-> kdf-hash/c bytes? bytes?
                      #:iterations exact-positive-integer?
                      #:length exact-positive-integer?
                      bytes?)]))
