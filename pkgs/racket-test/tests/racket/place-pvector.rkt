#lang racket/base
(require racket/place
         racket/pvector)

(module+ test
  ;; real places with pvector messages need the CS thread layer
  (when (and (place-enabled?)
             (eq? 'chez-scheme (system-type 'vm)))
    (go)))

(define (go)
  (define p (place ch
              (define pv (place-channel-get ch))
              (place-channel-put ch (list (pvector? pv)
                                          (pvector-length pv)
                                          (pvector-ref pv 2)))
              ;; send the same value back, so the parent can check
              ;; that identity survives a round trip
              (place-channel-put ch pv)
              ;; a pvector built in the child crosses to the parent
              (place-channel-put ch (list->pvector '(x y z)))))
  (define pv (list->pvector '(a b c d e)))
  (place-channel-put p pv)
  (unless (equal? (place-channel-get p) '(#t 5 c))
    (error "child-side checks failed"))
  (unless (eq? pv (place-channel-get p))
    (error "identity not preserved through round trip"))
  (define from-child (place-channel-get p))
  (unless (and (pvector? from-child)
               (equal? (pvector->list from-child) '(x y z)))
    (error "child-built pvector did not arrive intact"))
  (place-wait p))
