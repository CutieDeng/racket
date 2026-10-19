
(define (linklet-virtual-machine-bytes)
  (string->utf8 (symbol->string (machine-type))))

(define (linklet-cross-machine-type l)
  (let ([prep (linklet-preparation l)])
    (and (pair? prep) (cdr prep))))

;; The linklets' code is written after the fasl-encoded structure as
;; one code area, so that a reader can refer into it instead of copying
;; each linklet's code out of the fasl stream; see "read.ss"
(define (write-linklet-bundle-hash ht dest-o)
  (let-values ([(ls cross-machine codes code-len) (encode-linklet-literals ht)])
    (let ([bstr (if cross-machine
                    (let-values ([(bstr literals) (cross-fasl-to-string cross-machine ls #f 'data)])
                      (unless (equal? literals '#())
                        (#%error 'write-linklet "cross fasl produced additional literals"))
                      bstr)
                    (let-values ([(o get) (open-bytevector-output-port)])
                      (fasl-write* ls o)
                      (get)))])
      (write-bytes (integer->integer-bytes (bitwise-ior (bytes-length bstr) CODE-AREA-FLAG) 4 #f #f) dest-o)
      (write-bytes bstr dest-o)
      (write-bytes (integer->integer-bytes code-len 4 #f #f) dest-o)
      (for-each (lambda (code)
                  (if (code-slice? code)
                      (write-bytes (code-slice-bv code) dest-o (code-slice-start code) (fx+ (code-slice-start code) (code-slice-len code)))
                      (write-bytes code dest-o)))
                codes))))

;; Returns the key/value list to fasl, the cross-compilation machine,
;; the linklets' code in the order it goes into the code area, and the
;; area's length. In the list, each linklet's code is replaced by its
;; offset and length in the area.
(define (encode-linklet-literals orig-ht)
  (let loop ([i (hash-iterate-first orig-ht)] [accum '()] [cross-machine #f] [codes '()] [code-len 0])
    (cond
      [(not i) (values accum cross-machine (reverse codes) code-len)]
      [else
       (let-values ([(key v) (hash-iterate-key+value orig-ht i)])
         (when (linklet? v) (check-fasl-preparation v))
         (let* ([new-v (cond
                         [(linklet? v)
                          (adjust-cross-preparation
                           (let ([literals (linklet-literals v)])
                             (cond
                               [(and (#%vector? literals)
                                     (fx= 0 (#%vector-length literals)))
                                v]
                               [else
                                (set-linklet-literals
                                 v
                                 (fasl-literals (extract-literals literals) uninterned-symbol?))])))]
                         [else v])]
                [code (and (linklet? new-v) (linklet-code new-v))]
                [len (cond
                       [(not code) 0]
                       [(bytevector? code) (bytevector-length code)]
                       [(code-slice? code) (code-slice-len code)]
                       [else (#%error 'write-linklet "linklet code is not serializable: ~s" code)])]
                [new-v (if code
                           (set-linklet-code new-v (cons code-len len) (linklet-preparation new-v))
                           new-v)])
           (when (linklet? new-v)
             (linklet-pack-exports-info! new-v))
           (let ([accum (cons* key (to-portable new-v) accum)])
             (loop (hash-iterate-next orig-ht i)
                   accum
                   (or cross-machine
                       (and (linklet? v)
                            (let ([prep (linklet-preparation v)])
                              (and (pair? prep) (cdr prep)))))
                   (if code (cons code codes) codes)
                   (fx+ code-len len)))))])))

;; Before fasl conversion, change 'cross or 'faslable-unsafe to 'faslable
(define (adjust-cross-preparation l)
  (let ([p (linklet-preparation l)])
    (if (or (pair? p) (eq? p 'faslable-unsafe))
        (set-linklet-preparation l 'faslable)
        l)))

(define (check-fasl-preparation l)
  (case (linklet-preparation l)
    [(callable lazy)
     (raise-arguments-error 'write "linklet is not serializable")]))

(define (to-portable v)
  (cond
    [(linklet? v)
     ;; Linklet records have a different shape across platforms (at least
     ;; for 32-bit versus 64-bit]. Convert to a shape that can be unfasled
     ;; on any platform. It might also work to omit RTDs in the fasled
     ;; form and rely on matching field counts, but this approach is a
     ;; little more direct.
     (linklet->vector v)]
    [else v]))
