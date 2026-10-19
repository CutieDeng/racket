
;; A bundle is a 4-byte length and that many bytes of fasl-encoded
;; structure. When the high bit of the length is set, the linklets'
;; code follows as a 4-byte length and one code area, and each linklet
;; holds an offset and length into that area in place of its code.
(define CODE-AREA-FLAG #x80000000)

(define (read-linklet-bundle-hash in cross-machine-type)
  (performance-region
   'read-bundle
   (let* ([raw-len (integer-bytes->integer (read-bytes 4 in) #f #f)]
          [sliced? (not (eqv? 0 (bitwise-and raw-len CODE-AREA-FLAG)))]
          [len (bitwise-and raw-len (- CODE-AREA-FLAG 1))]
          [bstr (read-bytes len in)]
          [ls (fasl-read (open-bytevector-input-port bstr))]
          [code-area (and sliced?
                          (let ([code-len (integer-bytes->integer (read-bytes 4 in) #f #f)])
                            (if (eqv? code-len 0)
                                (make-bytevector 0)
                                (read-bytes code-len in))))])
     (adjust-linklet-bundle-laziness-and-literals ls code-area cross-machine-type))))

(define read-on-demand-source
  (make-parameter #f
                  (lambda (v)
                    (unless (or (eq? v #t) (eq? v #f) (and (path? v)
                                                           (complete-path? v)))
                      (raise-argument-error 'read-on-demand-source
                                            "(or/c #f #t (and/c path? complete-path?))"
                                            v))
                    v)
		  'read-on-demand-source))

(define (adjust-linklet-bundle-laziness-and-literals ls code-area cross-machine-type)
  (let loop ([ls ls] [ht (hasheq)])
    (cond
     [(null? ls) ht]
     [else
      (let ([key (car ls)]
            [val (cadr ls)])
        (loop (cddr ls)
              (hash-set ht
                        key
                        (cond
                          [(linklet-vector? val)
                           (vector->linklet/adjusted val code-area (lazy-code-key? key) cross-machine-type)]
                          [else val]))))])))

;; A module's syntax-literal data and its bodies above phase 0 are
;; evaluated only when one of its macros runs or when it is instantiated
;; at a higher phase, which may never happen; their code is copied out
;; of the code area so that it does not keep the whole area alive.
(define (lazy-code-key? key)
  (or (eq? key 'stx-data)
      (and (fixnum? key) (fx> key 0))))

;; Builds the linklet record once, with its code, literals, and
;; preparation adjusted for this process
(define (vector->linklet/adjusted v code-area lazy? cross-machine-type)
  (let* ([code (let ([c (vector-ref v 1)])
                 (cond
                   [(pair? c)
                    ;; an offset and length into the bundle's code area
                    (if lazy?
                        (let ([bv (make-bytevector (cdr c))])
                          (bytevector-copy! code-area (car c) bv 0 (cdr c))
                          bv)
                        (make-code-slice code-area (car c) (cdr c)))]
                   [else c]))]
         [literals (let ([l (vector-ref v 2)])
                     (if (vector? l)
                         l
                         (unfasl-literals/lazy l)))]
         [preparation (cond
                        [cross-machine-type (cons 'cross cross-machine-type)]
                        [(not (eq? root-inspector (|#%app| current-code-inspector)))
                         ;; Originally, the idea was that bytecode can be loaded in
                         ;; a non-original code inspector as long as it doesn't refer
                         ;; to unsafe operation. But increasing use of compilation to
                         ;; unsafe operations, not to mention compilation to machine
                         ;; code, means that all "bytecode" is unsafe:
                         'faslable-unsafe]
                        [(|#%app| read-on-demand-source)
                         ;; Remember that the linklet can be lazier:
                         'faslable]
                        [else
                         'faslable-strict])])
    (make-linklet code
                  literals
                  (vector-ref v 3)
                  preparation
                  (vector-ref v 5)
                  (vector-ref v 6)
                  (vector-ref v 7)
                  (vector-ref v 8)
                  (vector-ref v 9))))
