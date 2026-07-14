#lang racket/base

;; Unified message-digest API over the built-in rktcrypto subsystem:
;; one-shot, incremental, and port-consuming forms for SHA-2, SHA-3,
;; SHAKE, and BLAKE2b, all sharing one algorithm-symbol namespace.

(require racket/contract/base
         (only-in '#%kernel
                  crypto-digest-ctx-size
                  crypto-digest-size
                  crypto-digest-block-size
                  crypto-digest-xof?
                  crypto-digest-init!
                  crypto-digest-update!
                  crypto-digest-final!
                  crypto-digest-oneshot!))

(define algorithms
  '(sha224 sha256 sha384 sha512 sha512/256
    sha3-224 sha3-256 sha3-384 sha3-512
    shake128 shake256 blake2b))

(define (digest-algorithm? v) (and (memq v algorithms) #t))

(define (fixed-algorithm? v)
  (and (digest-algorithm? v) (not (crypto-digest-xof? v))))

;; An incremental digest. `ctx` is the rktcrypto context byte string;
;; `done?` guards against use after finalization.
(struct digest (algorithm ctx [done? #:mutable])
  #:omit-define-syntaxes)

(define (make-a-digest alg [outlen 0])
  (define ctx (make-bytes (crypto-digest-ctx-size alg)))
  (crypto-digest-init! alg ctx outlen)
  (digest alg ctx #f))

(define (digest-update!* who dg data start end)
  (when (digest-done? dg)
    (raise-arguments-error who "digest has already been finalized"))
  (crypto-digest-update! (digest-algorithm dg) (digest-ctx dg) data start end))

;; Finalize, producing `len` bytes (defaults to the algorithm's digest
;; size; required for XOFs, which have no default). The digest becomes
;; unusable afterward.
(define (digest-final!* who dg len)
  (when (digest-done? dg)
    (raise-arguments-error who "digest has already been finalized"))
  (define alg (digest-algorithm dg))
  (define out-len
    (cond
      [len len]
      [(crypto-digest-xof? alg)
       (raise-arguments-error who "output length required for an extendable-output function"
                              "algorithm" alg)]
      [else (crypto-digest-size alg)]))
  (define out (make-bytes out-len))
  (crypto-digest-final! alg (digest-ctx dg) out 0 out-len)
  (set-digest-done?! dg #t)
  out)

;; ---- one-shot ----

(define (digest-bytes alg in
                      #:start [start 0]
                      #:end [end (and (bytes? in) (bytes-length in))]
                      #:length [len #f])
  (define out-len
    (cond
      [len len]
      [(crypto-digest-xof? alg)
       (raise-arguments-error 'digest-bytes
                              "output length required for an extendable-output function"
                              "algorithm" alg)]
      [else (crypto-digest-size alg)]))
  (cond
    [(bytes? in)
     (define out (make-bytes out-len))
     (crypto-digest-oneshot! alg in start (or end (bytes-length in)) out 0 out-len)
     out]
    [else
     ;; input port: stream through an incremental digest
     (define dg (make-a-digest alg out-len))
     (feed-port! 'digest-bytes dg in start end)
     (digest-final!* 'digest-bytes dg out-len)]))

(define (digest-file alg path #:length [len #f])
  (call-with-input-file* path
    (lambda (in) (digest-bytes alg in #:length len))))

;; ---- port streaming ----

(define read-chunk 65536)

(define (feed-port! who dg in start end)
  ;; Skip `start` bytes, then feed up to `(- end start)` bytes.
  (let skip ([n start])
    (when (and n (> n 0))
      (define got (read-bytes (min n read-chunk) in))
      (unless (eof-object? got)
        (skip (- n (bytes-length got))))))
  (define buf (make-bytes read-chunk))
  (let loop ([remain (and end (- end start))])
    (unless (and remain (<= remain 0))
      (define cap (if remain (min remain read-chunk) read-chunk))
      (define got (read-bytes! buf in 0 cap))
      (unless (eof-object? got)
        (digest-update!* who dg buf 0 got)
        (loop (and remain (- remain got)))))))

;; ---- incremental object API ----

(define (make-digest alg #:length [outlen 0])
  (make-a-digest alg outlen))

(define (digest-update! dg data
                        #:start [start 0]
                        #:end [end (and (bytes? data) (bytes-length data))])
  (digest-update!* 'digest-update! dg data start (or end (bytes-length data)))
  (void))

(define (digest-final! dg #:length [len #f])
  (digest-final!* 'digest-final! dg len))

;; ---- metadata ----

(define (digest-algorithms) algorithms)
(define (digest-output-size alg) (crypto-digest-size alg))
(define (digest-block-size alg) (crypto-digest-block-size alg))
(define (digest-xof? alg) (crypto-digest-xof? alg))

(define digest-algorithm/c (flat-named-contract 'digest-algorithm/c digest-algorithm?))

(provide digest-algorithm/c
         (contract-out
          [digest? (-> any/c boolean?)]
          [digest-algorithms (-> (listof symbol?))]
          [digest-bytes (->* (digest-algorithm/c (or/c bytes? input-port?))
                             (#:start exact-nonnegative-integer?
                              #:end (or/c exact-nonnegative-integer? #f)
                              #:length (or/c exact-positive-integer? #f))
                             bytes?)]
          [digest-file (->* (digest-algorithm/c (or/c path-string? path?))
                            (#:length (or/c exact-positive-integer? #f))
                            bytes?)]
          [make-digest (->* (digest-algorithm/c)
                            (#:length exact-nonnegative-integer?)
                            digest?)]
          [digest-update! (->* (digest? bytes?)
                               (#:start exact-nonnegative-integer?
                                #:end (or/c exact-nonnegative-integer? #f))
                               void?)]
          [digest-final! (->* (digest?)
                              (#:length (or/c exact-positive-integer? #f))
                              bytes?)]
          [digest-output-size (-> fixed-algorithm? exact-positive-integer?)]
          [digest-block-size (-> digest-algorithm/c exact-positive-integer?)]
          [digest-xof? (-> digest-algorithm/c boolean?)]))
