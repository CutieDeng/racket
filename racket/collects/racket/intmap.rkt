#lang racket/base

(require "private/intmap-runtime-adapter.rkt"
         "private/serialize-structs.rkt"
         (only-in "private/for.rkt" prop:sequence prop:stream
         ) ; end only-in
) ; end require

(define (intmap-rest-stream m
        ) ; end intmap-rest-stream
  (intmap-remove m (car (intmap-min-entry m
                        ) ; end intmap-min-entry
                   ) ; end car
  ) ; end intmap-remove
) ; end define

(define (intmap-custom-write m out mode
        ) ; end intmap-custom-write
  (cond
    [mode
     (if (intmap-empty? m
         ) ; end intmap-empty?
         (write-string "(intmap)" out
         ) ; end write-string
         (fprintf out "(sorted-list->intmap '~s)"
                  (intmap-range->list m #f #f
                  ) ; end intmap-range->list
         ) ; end fprintf
     ) ; end if
    ] ; end mode
    [else
     (fprintf out "#<intmap:~a>" (intmap-count m
                                 ) ; end intmap-count
     ) ; end fprintf
    ] ; end else
  ) ; end cond
) ; end define

(define intmap-equal+hash
  (list (lambda (a b equal?-recur
                ) ; end a
          (and (intmap? b
               ) ; end intmap?
               (= (intmap-count a) (intmap-count b
                                   ) ; end intmap-count
               ) ; end =
               (equal?-recur (intmap-range->list a #f #f
                             ) ; end intmap-range->list
                             (intmap-range->list b #f #f
                             ) ; end intmap-range->list
               ) ; end equal?-recur
          ) ; end and
        ) ; end lambda
        (lambda (a hash-recur
                ) ; end a
          (hash-recur (intmap-range->list a #f #f
                      ) ; end intmap-range->list
          ) ; end hash-recur
        ) ; end lambda
        (lambda (a hash2-recur
                ) ; end a
          (hash2-recur (intmap-range->list a #f #f
                       ) ; end intmap-range->list
          ) ; end hash2-recur
        ) ; end lambda
  ) ; end list
) ; end define

(when (intmap-runtime-adapter-public-properties-available?
      ) ; end intmap-runtime-adapter-public-propert...
  (intmap-install-struct-property! prop:custom-write intmap-custom-write
  ) ; end intmap-install-struct-property!
  (intmap-install-struct-property! prop:equal+hash intmap-equal+hash
  ) ; end intmap-install-struct-property!
  (intmap-install-struct-property! prop:sequence (lambda (m) (in-intmap m
                                                             ) ; end in-intmap
                                                 ) ; end lambda
  ) ; end intmap-install-struct-property!
  (intmap-install-struct-property!
   prop:stream
   (vector intmap-empty?
           intmap-min-entry
           intmap-rest-stream
   ) ; end vector
  ) ; end intmap-install-struct-property!
  (intmap-install-struct-property!
   prop:serializable
   (make-serialize-info
    (lambda (m) (vector (intmap-range->list m #f #f
                        ) ; end intmap-range->list
                ) ; end vector
    ) ; end lambda
    (cons 'deserialize-intmap
          (module-path-index-join '(submod "." deserialize
                                   ) ; end submod
                                  (variable-reference->module-path-index
                                   (#%variable-reference
                                   ) ; end %variable-reference
                                  ) ; end variable-reference->module-path-index
          ) ; end module-path-index-join
    ) ; end cons
    #f
    (or (current-load-relative-directory
        ) ; end current-load-relative-directory
        (current-directory
        ) ; end current-directory
    ) ; end or
   ) ; end make-serialize-info
  ) ; end intmap-install-struct-property!
) ; end when

(module+ deserialize
  (provide deserialize-intmap
  ) ; end provide
  (define deserialize-intmap
    (make-deserialize-info
     (lambda (entries
             ) ; end entries
       (if (list? entries
           ) ; end list?
           (sorted-list->intmap entries
           ) ; end sorted-list->intmap
           (error 'intmap "invalid deserialization"
           ) ; end error
       ) ; end if
     ) ; end lambda
     (lambda () (error "should not get here; cycles not supported"
                ) ; end error
     ) ; end lambda
    ) ; end make-deserialize-info
  ) ; end define
  (module declare-preserve-for-embedding racket/kernel
  ) ; end module
) ; end module+

(provide
 intmap?
 intmap
 intmap-empty
 intmap-empty?
 intmap-count
 intmap-ref
 intmap-has-key?
 intmap-set
 intmap-update
 intmap-replace
 intmap-set/absent
 intmap-remove
 intmap-remove/eq
 intmap-remove/equal
 intmap-replace/eq
 intmap-replace/equal
 intmap-entry<
 intmap-entry<=
 intmap-entry>
 intmap-entry>=
 intmap-min-entry
 intmap-max-entry
 intmap-range->list
 in-intmap
 in-intmap-keys
 in-intmap-values
 in-intmap-pairs
 in-intmap-range
 in-intmap-range-keys
 in-intmap-range-values
 in-intmap-range-pairs
 sorted-list->intmap
 sorted-vector->intmap
) ; end provide
