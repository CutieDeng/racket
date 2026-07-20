#lang racket/base

;; Minimal DER/ASN.1 reader for X.509 certificate parsing. A parsed value
;; is (der tag content-bytes start end): the identifier octet, the raw
;; certificate bytes, and the [start,end) window of this value's *content*
;; (inside the certificate byte string). Working in offsets over the
;; original bytes lets us hand the exact TBSCertificate span to the C
;; signature verifier with no copy.

(provide (struct-out der)
         der-read
         der-read-at
         der-children
         der-explicit
         der-uint
         der-oid=?
         bytes->oid-string
         der-tag-context?
         der-tag-number)

(struct der (tag bytes start end) #:transparent)

;; Reads the TLV at offset `pos` in `bs` (bounded by `limit`). Returns
;; (values der next-pos) or raises 'der-error.
(define (der-read-at bs pos limit)
  (when (> (+ pos 2) limit) (error 'der "truncated header"))
  (define tag (bytes-ref bs pos))
  (define b1 (bytes-ref bs (add1 pos)))
  (define-values (len hdr)
    (if (< b1 #x80)
        (values b1 2)
        (let ([nb (bitwise-and b1 #x7f)])
          (when (or (< nb 1) (> nb 4) (> (+ pos 2 nb) limit))
            (error 'der "bad length"))
          (let loop ([i 0] [acc 0])
            (if (= i nb)
                (values acc (+ 2 nb))
                (loop (add1 i) (+ (* acc 256) (bytes-ref bs (+ pos 2 i)))))))))
  (define cstart (+ pos hdr))
  (define cend (+ cstart len))
  (when (> cend limit) (error 'der "content overruns"))
  (values (der tag bs cstart cend) cend))

;; Reads a single top-level TLV from a byte string.
(define (der-read bs)
  (define-values (v _) (der-read-at bs 0 (bytes-length bs)))
  v)

;; Returns the list of child TLVs inside a constructed value.
(define (der-children d)
  (let loop ([pos (der-start d)] [acc '()])
    (if (>= pos (der-end d))
        (reverse acc)
        (let-values ([(child next) (der-read-at (der-bytes d) pos (der-end d))])
          (loop next (cons child acc))))))

;; The single TLV wrapped inside an EXPLICIT [n] context tag.
(define (der-explicit d)
  (define-values (v _) (der-read-at (der-bytes d) (der-start d) (der-end d)))
  v)

;; INTEGER content as a nonnegative integer (drops a leading sign byte).
(define (der-uint d)
  (let loop ([pos (der-start d)] [acc 0])
    (if (>= pos (der-end d))
        acc
        (loop (add1 pos) (+ (* acc 256) (bytes-ref (der-bytes d) pos))))))

;; The content bytes of a value, copied out.
(define (der-content d) (subbytes (der-bytes d) (der-start d) (der-end d)))

(define (der-oid=? d oid-bytes)
  (and (= (der-tag d) #x06)
       (= (- (der-end d) (der-start d)) (bytes-length oid-bytes))
       (let loop ([i 0])
         (or (= i (bytes-length oid-bytes))
             (and (= (bytes-ref (der-bytes d) (+ (der-start d) i))
                     (bytes-ref oid-bytes i))
                  (loop (add1 i)))))))

;; Decodes an OID's content bytes to dotted-decimal (for diagnostics).
(define (bytes->oid-string d)
  (define bs (der-content d))
  (if (zero? (bytes-length bs))
      ""
      (let ([first (bytes-ref bs 0)])
        (define parts
          (let loop ([i 1] [acc (list (remainder first 40) (quotient first 40))] [val 0])
            (if (= i (bytes-length bs))
                (reverse acc)
                (let ([b (bytes-ref bs i)])
                  (if (>= b #x80)
                      (loop (add1 i) acc (* (+ val (bitwise-and b #x7f)) 128))
                      (loop (add1 i) (cons (+ val b) acc) 0))))))
        (apply string-append
               (car (map number->string parts))
               (map (lambda (p) (string-append "." (number->string p)))
                    (cdr parts))))))

(define (der-tag-context? d) (= #x80 (bitwise-and (der-tag d) #xc0)))
(define (der-tag-number d) (bitwise-and (der-tag d) #x1f))

(provide der-content)
