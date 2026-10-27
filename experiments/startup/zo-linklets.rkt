#lang racket/base
;; zo-linklets.rkt <zo> ...: per-linklet code bytes and racket/fasl literal payload of a .zo
(require ffi/unsafe/vm '#%linklet racket/list racket/fasl)
(define fasled (vm-eval 'linklet-fasled-code+arguments))
(define lits-of (vm-eval '(lambda (lk) ((record-accessor (record-rtd lk) 1) lk))))
(define (lit-bytes l)
  (define v (if (box? l) (unbox l) l))
  (cond [(vector? v) (if (= 0 (vector-length v)) 0
                         (with-handlers ([void (lambda (e) -1)])
                           (bytes-length (s-exp->fasl v #:skip-prefix? #t))))]
        [else -2]))
(for ([zo (current-command-line-arguments)])
  (printf "== ~a\n" zo)
  (define c (parameterize ([read-accept-compiled #t]) (call-with-input-file zo read)))
  (define (walk h prefix)
    (for ([(k v) h])
      (cond [(linklet-bundle? v) (walk (linklet-bundle->hash v) (format "~a~a/" prefix k))]
            [(linklet-directory? v) (walk (linklet-directory->hash v) (format "~a~a/" prefix k))]
            [(linklet? v)
             (define-values (fmt bv lits) (fasled v))
             (printf "  ~a~a code ~a B, literals ~a (fasl ~a B)\n" prefix k (if (bytes? bv) (bytes-length bv) '?)
                     (if (vector? lits) (vector-length lits) '?) (lit-bytes (lits-of v)))])))
  (cond [(linklet-bundle? c) (walk (linklet-bundle->hash c) "")]
        [(linklet-directory? c) (walk (linklet-directory->hash c) "")]))
