#lang racket/base

;; Message authentication codes over the built-in digests.
;;
;; HMAC (FIPS 198-1 / RFC 2104) is orchestrated in Racket on top of the
;; C digest cores: the performance-critical compression work stays in
;; rktcrypto, so a C HMAC would add nothing. Keys are byte strings.

(require racket/contract/base
         "digest.rkt"
         (prefix-in u: "util.rkt")
         (only-in '#%kernel
                  crypto-siphash-2-4
                  crypto-siphash-1-3))

(define (hmac-algorithm? v)
  (and (memq v (digest-algorithms))
       ;; HMAC needs a fixed-size compression, so exclude XOFs:
       (not (digest-xof? v))
       #t))

;; Prepares the key block K0: hash keys longer than the block size,
;; then zero-pad to the block size.
(define (key-block alg key)
  (define bs (digest-block-size alg))
  (define k (if (> (bytes-length key) bs)
                (digest-bytes alg key)
                key))
  (define k0 (make-bytes bs 0))
  (bytes-copy! k0 0 k)
  k0)

(define (xor-block k0 pad)
  (define n (bytes-length k0))
  (define out (make-bytes n))
  (for ([i (in-range n)])
    (bytes-set! out i (bitwise-xor (bytes-ref k0 i) pad)))
  out)

(define (hmac-bytes alg key data
                    #:start [start 0]
                    #:end [end (bytes-length data)])
  (define k0 (key-block alg key))
  (define i-key (xor-block k0 #x36))
  (define o-key (xor-block k0 #x5c))
  (define inner-input (bytes-append i-key (subbytes data start end)))
  (define inner (digest-bytes alg inner-input))
  (begin0
    (digest-bytes alg (bytes-append o-key inner))
    (u:crypto-bytes-clear! k0)
    (u:crypto-bytes-clear! i-key)
    (u:crypto-bytes-clear! o-key)))

;; Incremental HMAC: an inner digest primed with the ipad key block,
;; plus an outer digest primed with the opad key block for the final
;; wrap. Keeping the key material as primed digest midstates (rather
;; than retained key-block bytes) means `hmac-copy` forks a keyed
;; context without re-absorbing either key block, and no raw key
;; block outlives `make-hmac`.
(struct hmac (algorithm inner outer [done? #:mutable])
  #:omit-define-syntaxes)

(define (make-hmac alg key)
  (define k0 (key-block alg key))
  (define i-key (xor-block k0 #x36))
  (define o-key (xor-block k0 #x5c))
  (define inner (make-digest alg))
  (digest-update! inner i-key)
  (define outer (make-digest alg))
  (digest-update! outer o-key)
  (u:crypto-bytes-clear! k0)
  (u:crypto-bytes-clear! i-key)
  (u:crypto-bytes-clear! o-key)
  (hmac alg inner outer #f))

;; An independent fork of the HMAC state. Copying a fresh context
;; amortizes the key-block absorptions over many messages under one
;; key; copying mid-stream forks the MAC of a shared prefix.
(define (hmac-copy h)
  (hmac (hmac-algorithm h)
        (digest-copy (hmac-inner h))
        (digest-copy (hmac-outer h))
        (hmac-done? h)))

(define (hmac-update! h data
                      #:start [start 0]
                      #:end [end (bytes-length data)])
  (when (hmac-done? h)
    (raise-arguments-error 'hmac-update! "HMAC has already been finalized"))
  (digest-update! (hmac-inner h) data #:start start #:end end)
  (void))

(define (hmac-final! h)
  (when (hmac-done? h)
    (raise-arguments-error 'hmac-final! "HMAC has already been finalized"))
  (define outer (hmac-outer h))
  (digest-update! outer (digest-final! (hmac-inner h)))
  (begin0
    (digest-final! outer)
    (set-hmac-done?! h #t)))

;; SipHash keyed PRF: an 8-byte MAC keyed by a 16-byte key, for short
;; inputs and hash-flooding-resistant hashing. SipHash-2-4 is the
;; standard choice; SipHash-1-3 trades a margin of security for speed.
(define (siphash-2-4 key data #:start [start 0] #:end [end (bytes-length data)])
  (crypto-siphash-2-4 key data start end))
(define (siphash-1-3 key data #:start [start 0] #:end [end (bytes-length data)])
  (crypto-siphash-1-3 key data start end))

(define hmac-algorithm/c (flat-named-contract 'hmac-algorithm/c hmac-algorithm?))

(provide hmac-algorithm/c
         (contract-out
          [hmac? (-> any/c boolean?)]
          [hmac-bytes (->* (hmac-algorithm/c bytes? bytes?)
                           (#:start exact-nonnegative-integer?
                            #:end exact-nonnegative-integer?)
                           bytes?)]
          [make-hmac (-> hmac-algorithm/c bytes? hmac?)]
          [hmac-copy (-> hmac? hmac?)]
          [hmac-update! (->* (hmac? bytes?)
                             (#:start exact-nonnegative-integer?
                              #:end exact-nonnegative-integer?)
                             void?)]
          [hmac-final! (-> hmac? bytes?)]
          [siphash-2-4 (->* (bytes? bytes?)
                            (#:start exact-nonnegative-integer?
                             #:end exact-nonnegative-integer?)
                            bytes?)]
          [siphash-1-3 (->* (bytes? bytes?)
                            (#:start exact-nonnegative-integer?
                             #:end exact-nonnegative-integer?)
                            bytes?)]))
