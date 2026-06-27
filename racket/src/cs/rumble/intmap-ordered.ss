;; Persistent ordered map for exact-integer keys.
;;
;; This file intentionally does not use the name "intmap.ss", which is already
;; used by the runtime HAMT/hash implementation.

(define core-intmap-delta 5
) ; end define
(define core-intmap-ratio 2
) ; end define

(define-record-type core-intmap-empty-record
  [fields
  ] ; end fields
  [nongenerative #{core-intmap-empty-record cutie-intmap-ordered-runtime-1}
  ] ; end nongenerative
  [sealed #t
  ] ; end sealed
) ; end define-record-type

(define-record-type core-intmap-node
  [fields (immutable size
          ) ; end immutable
          (immutable key
          ) ; end immutable
          (immutable value
          ) ; end immutable
          (immutable left
          ) ; end immutable
          (immutable right
          ) ; end immutable
  ] ; end fields
  [nongenerative #{core-intmap-node cutie-intmap-ordered-runtime-2}
  ] ; end nongenerative
  [sealed #t
  ] ; end sealed
) ; end define-record-type

(define-record-type core-intmap-cursor
  [fields (immutable stack
          ) ; end immutable
          (immutable reverse?
          ) ; end immutable
          (immutable bound
          ) ; end immutable
          (immutable inclusive-bound?
          ) ; end immutable
  ] ; end fields
  [nongenerative #{core-intmap-cursor cutie-intmap-ordered-runtime-3}
  ] ; end nongenerative
  [sealed #t
  ] ; end sealed
) ; end define-record-type

(define empty-core-intmap (make-core-intmap-empty-record
                          ) ; end make-core-intmap-empty-record
) ; end define

(define (core-intmap? v
        ) ; end core-intmap?
  (or (core-intmap-empty-record? v
      ) ; end core-intmap-empty-record?
      (core-intmap-node? v
      ) ; end core-intmap-node?
  ) ; end or
) ; end define

(define (core-intmap-empty
        ) ; end core-intmap-empty
  empty-core-intmap
) ; end define

(define (core-intmap-empty? im
        ) ; end core-intmap-empty?
  (eq? im empty-core-intmap
  ) ; end eq?
) ; end define

(define (core-check-intmap who im
        ) ; end core-check-intmap
  (unless (core-intmap? im
          ) ; end core-intmap?
    (raise-argument-error who "intmap?" im
    ) ; end raise-argument-error
  ) ; end unless
  im
) ; end define

(define (core-check-intmap-key who k
        ) ; end core-check-intmap-key
  (unless (exact-integer? k
          ) ; end exact-integer?
    (raise-argument-error who "exact-integer?" k
    ) ; end raise-argument-error
  ) ; end unless
  k
) ; end define

(define (core-intmap-key=? a b
        ) ; end core-intmap-key=?
  (if (and (fixnum? a) (fixnum? b
                       ) ; end fixnum?
      ) ; end and
      (fx= a b
      ) ; end fx=
      (= a b
      ) ; end =
  ) ; end if
) ; end define

(define (core-intmap-key<? a b
        ) ; end core-intmap-key<?
  (if (and (fixnum? a) (fixnum? b
                       ) ; end fixnum?
      ) ; end and
      (fx< a b
      ) ; end fx<
      (< a b
      ) ; end <
  ) ; end if
) ; end define

(define (core-intmap-key>? a b
        ) ; end core-intmap-key>?
  (core-intmap-key<? b a
  ) ; end core-intmap-key<?
) ; end define

(define (core-intmap-key<=? a b
        ) ; end core-intmap-key<=?
  (not (core-intmap-key>? a b
       ) ; end core-intmap-key>?
  ) ; end not
) ; end define

(define (core-intmap-key>=? a b
        ) ; end core-intmap-key>=?
  (not (core-intmap-key<? a b
       ) ; end core-intmap-key<?
  ) ; end not
) ; end define

(define (core-intmap-fixnum-key<? a b
        ) ; end core-intmap-fixnum-key<?
  (if (fixnum? b
      ) ; end fixnum?
      (fx< a b
      ) ; end fx<
      (< a b
      ) ; end <
  ) ; end if
) ; end define

(define (core-intmap-fixnum-key>? a b
        ) ; end core-intmap-fixnum-key>?
  (if (fixnum? b
      ) ; end fixnum?
      (fx> a b
      ) ; end fx>
      (> a b
      ) ; end >
  ) ; end if
) ; end define

(define (core-intmap-fixnum-key<=? a b
        ) ; end core-intmap-fixnum-key<=?
  (not (core-intmap-fixnum-key>? a b
       ) ; end core-intmap-fixnum-key>?
  ) ; end not
) ; end define

(define (core-intmap-fixnum-key>=? a b
        ) ; end core-intmap-fixnum-key>=?
  (not (core-intmap-fixnum-key<? a b
       ) ; end core-intmap-fixnum-key<?
  ) ; end not
) ; end define

(define (core-intmap-key<fixnum? a b
        ) ; end core-intmap-key<fixnum?
  (if (fixnum? a
      ) ; end fixnum?
      (fx< a b
      ) ; end fx<
      (< a b
      ) ; end <
  ) ; end if
) ; end define

(define (core-intmap-key>fixnum? a b
        ) ; end core-intmap-key>fixnum?
  (if (fixnum? a
      ) ; end fixnum?
      (fx> a b
      ) ; end fx>
      (> a b
      ) ; end >
  ) ; end if
) ; end define

(define (core-intmap-key<=fixnum? a b
        ) ; end core-intmap-key<=fixnum?
  (not (core-intmap-key>fixnum? a b
       ) ; end core-intmap-key>fixnum?
  ) ; end not
) ; end define

(define (core-intmap-key>=fixnum? a b
        ) ; end core-intmap-key>=fixnum?
  (not (core-intmap-key<fixnum? a b
       ) ; end core-intmap-key<fixnum?
  ) ; end not
) ; end define

(define (core-intmap-size im
        ) ; end core-intmap-size
  (if (core-intmap-node? im
      ) ; end core-intmap-node?
      (core-intmap-node-size im
      ) ; end core-intmap-node-size
      0
  ) ; end if
) ; end define

(define (core-intmap-make-node key value left right
        ) ; end core-intmap-make-node
  (make-core-intmap-node (+ 1
                            (core-intmap-size left
                            ) ; end core-intmap-size
                            (core-intmap-size right
                            ) ; end core-intmap-size
                         ) ; end +
                         key
                         value
                         left
                         right
  ) ; end make-core-intmap-node
) ; end define

(define (core-intmap-single-left key value left right
        ) ; end core-intmap-single-left
  (core-intmap-make-node
   (core-intmap-node-key right
   ) ; end core-intmap-node-key
   (core-intmap-node-value right
   ) ; end core-intmap-node-value
   (core-intmap-make-node key value left (core-intmap-node-left right
                                         ) ; end core-intmap-node-left
   ) ; end core-intmap-make-node
   (core-intmap-node-right right
   ) ; end core-intmap-node-right
  ) ; end core-intmap-make-node
) ; end define

(define (core-intmap-double-left key value left right
        ) ; end core-intmap-double-left
  (let ([right-left (core-intmap-node-left right
                    ) ; end core-intmap-node-left
        ] ; end right-left
       ) ; end form
    (core-intmap-make-node
     (core-intmap-node-key right-left
     ) ; end core-intmap-node-key
     (core-intmap-node-value right-left
     ) ; end core-intmap-node-value
     (core-intmap-make-node key value left (core-intmap-node-left right-left
                                           ) ; end core-intmap-node-left
     ) ; end core-intmap-make-node
     (core-intmap-make-node (core-intmap-node-key right
                            ) ; end core-intmap-node-key
                            (core-intmap-node-value right
                            ) ; end core-intmap-node-value
                            (core-intmap-node-right right-left
                            ) ; end core-intmap-node-right
                            (core-intmap-node-right right
                            ) ; end core-intmap-node-right
     ) ; end core-intmap-make-node
    ) ; end core-intmap-make-node
  ) ; end let
) ; end define

(define (core-intmap-single-right key value left right
        ) ; end core-intmap-single-right
  (core-intmap-make-node
   (core-intmap-node-key left
   ) ; end core-intmap-node-key
   (core-intmap-node-value left
   ) ; end core-intmap-node-value
   (core-intmap-node-left left
   ) ; end core-intmap-node-left
   (core-intmap-make-node key value (core-intmap-node-right left) right
   ) ; end core-intmap-make-node
  ) ; end core-intmap-make-node
) ; end define

(define (core-intmap-double-right key value left right
        ) ; end core-intmap-double-right
  (let ([left-right (core-intmap-node-right left
                    ) ; end core-intmap-node-right
        ] ; end left-right
       ) ; end form
    (core-intmap-make-node
     (core-intmap-node-key left-right
     ) ; end core-intmap-node-key
     (core-intmap-node-value left-right
     ) ; end core-intmap-node-value
     (core-intmap-make-node (core-intmap-node-key left
                            ) ; end core-intmap-node-key
                            (core-intmap-node-value left
                            ) ; end core-intmap-node-value
                            (core-intmap-node-left left
                            ) ; end core-intmap-node-left
                            (core-intmap-node-left left-right
                            ) ; end core-intmap-node-left
     ) ; end core-intmap-make-node
     (core-intmap-make-node key value (core-intmap-node-right left-right) right
     ) ; end core-intmap-make-node
    ) ; end core-intmap-make-node
  ) ; end let
) ; end define

(define (core-intmap-balance key value left right
        ) ; end core-intmap-balance
  (let ([left-size (core-intmap-size left
                   ) ; end core-intmap-size
        ] ; end left-size
        [right-size (core-intmap-size right
                    ) ; end core-intmap-size
        ] ; end right-size
       ) ; end form
    (cond
     [(<= (+ left-size right-size) 1
      ) ; end <=
      (core-intmap-make-node key value left right
      ) ; end core-intmap-make-node
     ] ; end clause
     [(>= right-size (* core-intmap-delta left-size
                     ) ; end *
      ) ; end >=
      (cond
       [(not (core-intmap-node? right
             ) ; end core-intmap-node?
        ) ; end not
        (core-intmap-make-node key value left right
        ) ; end core-intmap-make-node
       ] ; end clause
       [(or (not (core-intmap-node? (core-intmap-node-left right
                                    ) ; end core-intmap-node-left
                 ) ; end core-intmap-node?
            ) ; end not
            (< (core-intmap-size (core-intmap-node-left right
                                 ) ; end core-intmap-node-left
               ) ; end core-intmap-size
               (* core-intmap-ratio
                  (core-intmap-size (core-intmap-node-right right
                                    ) ; end core-intmap-node-right
                  ) ; end core-intmap-size
               ) ; end *
            ) ; end <
        ) ; end or
        (core-intmap-single-left key value left right
        ) ; end core-intmap-single-left
       ] ; end clause
       [else
        (core-intmap-double-left key value left right
        ) ; end core-intmap-double-left
       ] ; end else
      ) ; end cond
     ] ; end clause
     [(>= left-size (* core-intmap-delta right-size
                    ) ; end *
      ) ; end >=
      (cond
       [(not (core-intmap-node? left
             ) ; end core-intmap-node?
        ) ; end not
        (core-intmap-make-node key value left right
        ) ; end core-intmap-make-node
       ] ; end clause
       [(or (not (core-intmap-node? (core-intmap-node-right left
                                    ) ; end core-intmap-node-right
                 ) ; end core-intmap-node?
            ) ; end not
            (< (core-intmap-size (core-intmap-node-right left
                                 ) ; end core-intmap-node-right
               ) ; end core-intmap-size
               (* core-intmap-ratio
                  (core-intmap-size (core-intmap-node-left left
                                    ) ; end core-intmap-node-left
                  ) ; end core-intmap-size
               ) ; end *
            ) ; end <
        ) ; end or
        (core-intmap-single-right key value left right
        ) ; end core-intmap-single-right
       ] ; end clause
       [else
        (core-intmap-double-right key value left right
        ) ; end core-intmap-double-right
       ] ; end else
      ) ; end cond
     ] ; end clause
     [else
      (core-intmap-make-node key value left right
      ) ; end core-intmap-make-node
     ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (core-intmap-count im
        ) ; end core-intmap-count
  (core-intmap-size (core-check-intmap 'core-intmap-count im
                    ) ; end core-check-intmap
  ) ; end core-intmap-size
) ; end define

(define (core-intmap-ref im key default
        ) ; end core-intmap-ref
  (let ([im (core-check-intmap 'core-intmap-ref im
            ) ; end core-check-intmap
        ] ; end im
        [key (core-check-intmap-key 'core-intmap-ref key
             ) ; end core-check-intmap-key
        ] ; end key
       ) ; end form
    (if (fixnum? key
        ) ; end fixnum?
        (let loop ([t im
                   ] ; end t
                  ) ; end form
          (cond
           [(core-intmap-empty-record? t) default
           ] ; end default
           [else
            (let ([tk (core-intmap-node-key t
                      ) ; end core-intmap-node-key
                  ] ; end tk
                 ) ; end form
              (cond
               [(core-intmap-fixnum-key<? key tk) (loop (core-intmap-node-left t
                                                        ) ; end core-intmap-node-left
                                                  ) ; end loop
               ] ; end clause
               [(core-intmap-fixnum-key>? key tk) (loop (core-intmap-node-right t
                                                        ) ; end core-intmap-node-right
                                                  ) ; end loop
               ] ; end clause
               [else (core-intmap-node-value t
                     ) ; end core-intmap-node-value
               ] ; end else
              ) ; end cond
            ) ; end let
           ] ; end else
          ) ; end cond
        ) ; end let
        (let loop ([t im
                   ] ; end t
                  ) ; end form
          (cond
           [(core-intmap-empty-record? t) default
           ] ; end default
           [else
            (let ([tk (core-intmap-node-key t
                      ) ; end core-intmap-node-key
                  ] ; end tk
                 ) ; end form
              (cond
               [(core-intmap-key<? key tk) (loop (core-intmap-node-left t
                                                 ) ; end core-intmap-node-left
                                           ) ; end loop
               ] ; end clause
               [(core-intmap-key>? key tk) (loop (core-intmap-node-right t
                                                 ) ; end core-intmap-node-right
                                           ) ; end loop
               ] ; end clause
               [else (core-intmap-node-value t
                     ) ; end core-intmap-node-value
               ] ; end else
              ) ; end cond
            ) ; end let
           ] ; end else
          ) ; end cond
        ) ; end let
    ) ; end if
  ) ; end let
) ; end define

(define (core-intmap-has-key? im key
        ) ; end core-intmap-has-key?
  (let ([im (core-check-intmap 'core-intmap-has-key? im
            ) ; end core-check-intmap
        ] ; end im
        [key (core-check-intmap-key 'core-intmap-has-key? key
             ) ; end core-check-intmap-key
        ] ; end key
       ) ; end form
    (if (fixnum? key
        ) ; end fixnum?
        (let loop ([t im
                   ] ; end t
                  ) ; end form
          (cond
           [(core-intmap-empty-record? t) #f
           ] ; end f
           [else
            (let ([tk (core-intmap-node-key t
                      ) ; end core-intmap-node-key
                  ] ; end tk
                 ) ; end form
              (cond
               [(core-intmap-fixnum-key<? key tk) (loop (core-intmap-node-left t
                                                        ) ; end core-intmap-node-left
                                                  ) ; end loop
               ] ; end clause
               [(core-intmap-fixnum-key>? key tk) (loop (core-intmap-node-right t
                                                        ) ; end core-intmap-node-right
                                                  ) ; end loop
               ] ; end clause
               [else #t
               ] ; end else
              ) ; end cond
            ) ; end let
           ] ; end else
          ) ; end cond
        ) ; end let
        (let loop ([t im
                   ] ; end t
                  ) ; end form
          (cond
           [(core-intmap-empty-record? t) #f
           ] ; end f
           [else
            (let ([tk (core-intmap-node-key t
                      ) ; end core-intmap-node-key
                  ] ; end tk
                 ) ; end form
              (cond
               [(core-intmap-key<? key tk) (loop (core-intmap-node-left t
                                                 ) ; end core-intmap-node-left
                                           ) ; end loop
               ] ; end clause
               [(core-intmap-key>? key tk) (loop (core-intmap-node-right t
                                                 ) ; end core-intmap-node-right
                                           ) ; end loop
               ] ; end clause
               [else #t
               ] ; end else
              ) ; end cond
            ) ; end let
           ] ; end else
          ) ; end cond
        ) ; end let
    ) ; end if
  ) ; end let
) ; end define

(define (core-intmap-set im key value
        ) ; end core-intmap-set
  (let ([im (core-check-intmap 'core-intmap-set im
            ) ; end core-check-intmap
        ] ; end im
        [key (core-check-intmap-key 'core-intmap-set key
             ) ; end core-check-intmap-key
        ] ; end key
       ) ; end form
    (if (fixnum? key
        ) ; end fixnum?
        (let loop ([t im
                   ] ; end t
                  ) ; end form
          (cond
           [(core-intmap-empty-record? t
            ) ; end core-intmap-empty-record?
            (core-intmap-make-node key value empty-core-intmap empty-core-intmap
            ) ; end core-intmap-make-node
           ] ; end clause
           [else
            (let ([tk (core-intmap-node-key t
                      ) ; end core-intmap-node-key
                  ] ; end tk
                 ) ; end form
              (cond
               [(core-intmap-fixnum-key<? key tk
                ) ; end core-intmap-fixnum-key<?
                (core-intmap-balance tk
                                     (core-intmap-node-value t
                                     ) ; end core-intmap-node-value
                                     (loop (core-intmap-node-left t
                                           ) ; end core-intmap-node-left
                                     ) ; end loop
                                     (core-intmap-node-right t
                                     ) ; end core-intmap-node-right
                ) ; end core-intmap-balance
               ] ; end clause
               [(core-intmap-fixnum-key>? key tk
                ) ; end core-intmap-fixnum-key>?
                (core-intmap-balance tk
                                     (core-intmap-node-value t
                                     ) ; end core-intmap-node-value
                                     (core-intmap-node-left t
                                     ) ; end core-intmap-node-left
                                     (loop (core-intmap-node-right t
                                           ) ; end core-intmap-node-right
                                     ) ; end loop
                ) ; end core-intmap-balance
               ] ; end clause
               [else
                (make-core-intmap-node (core-intmap-node-size t
                                       ) ; end core-intmap-node-size
                                       key
                                       value
                                       (core-intmap-node-left t
                                       ) ; end core-intmap-node-left
                                       (core-intmap-node-right t
                                       ) ; end core-intmap-node-right
                ) ; end make-core-intmap-node
               ] ; end else
              ) ; end cond
            ) ; end let
           ] ; end else
          ) ; end cond
        ) ; end let
        (let loop ([t im
                   ] ; end t
                  ) ; end form
          (cond
           [(core-intmap-empty-record? t
            ) ; end core-intmap-empty-record?
            (core-intmap-make-node key value empty-core-intmap empty-core-intmap
            ) ; end core-intmap-make-node
           ] ; end clause
           [else
            (let ([tk (core-intmap-node-key t
                      ) ; end core-intmap-node-key
                  ] ; end tk
                 ) ; end form
              (cond
               [(core-intmap-key<? key tk
                ) ; end core-intmap-key<?
                (core-intmap-balance tk
                                     (core-intmap-node-value t
                                     ) ; end core-intmap-node-value
                                     (loop (core-intmap-node-left t
                                           ) ; end core-intmap-node-left
                                     ) ; end loop
                                     (core-intmap-node-right t
                                     ) ; end core-intmap-node-right
                ) ; end core-intmap-balance
               ] ; end clause
               [(core-intmap-key>? key tk
                ) ; end core-intmap-key>?
                (core-intmap-balance tk
                                     (core-intmap-node-value t
                                     ) ; end core-intmap-node-value
                                     (core-intmap-node-left t
                                     ) ; end core-intmap-node-left
                                     (loop (core-intmap-node-right t
                                           ) ; end core-intmap-node-right
                                     ) ; end loop
                ) ; end core-intmap-balance
               ] ; end clause
               [else
                (make-core-intmap-node (core-intmap-node-size t
                                       ) ; end core-intmap-node-size
                                       key
                                       value
                                       (core-intmap-node-left t
                                       ) ; end core-intmap-node-left
                                       (core-intmap-node-right t
                                       ) ; end core-intmap-node-right
                ) ; end make-core-intmap-node
               ] ; end else
              ) ; end cond
            ) ; end let
           ] ; end else
          ) ; end cond
        ) ; end let
    ) ; end if
  ) ; end let
) ; end define

(define (core-intmap-produced-value producer old-value present?
        ) ; end core-intmap-produced-value
  (if (procedure? producer)
      (if present?
          (producer old-value
          ) ; end producer
          (producer
          ) ; end producer
      ) ; end if
      producer
  ) ; end if
) ; end define

(define (core-intmap-update im key absent present
        ) ; end core-intmap-update
  (let ([im (core-check-intmap 'core-intmap-update im
            ) ; end core-check-intmap
        ] ; end im
        [key (core-check-intmap-key 'core-intmap-update key
             ) ; end core-check-intmap-key
        ] ; end key
       ) ; end form
    (if (fixnum? key
        ) ; end fixnum?
        (let loop ([t im
                   ] ; end t
                  ) ; end form
          (cond
           [(core-intmap-empty-record? t
            ) ; end core-intmap-empty-record?
            (core-intmap-make-node
             key
             (core-intmap-produced-value absent #f #f
             ) ; end core-intmap-produced-value
             empty-core-intmap
             empty-core-intmap
            ) ; end core-intmap-make-node
           ] ; end clause
           [else
            (let ([tk (core-intmap-node-key t
                      ) ; end core-intmap-node-key
                  ] ; end tk
                 ) ; end form
              (cond
               [(core-intmap-fixnum-key<? key tk
                ) ; end core-intmap-fixnum-key<?
                (core-intmap-balance tk
                                     (core-intmap-node-value t
                                     ) ; end core-intmap-node-value
                                     (loop (core-intmap-node-left t
                                           ) ; end core-intmap-node-left
                                     ) ; end loop
                                     (core-intmap-node-right t
                                     ) ; end core-intmap-node-right
                ) ; end core-intmap-balance
               ] ; end clause
               [(core-intmap-fixnum-key>? key tk
                ) ; end core-intmap-fixnum-key>?
                (core-intmap-balance tk
                                     (core-intmap-node-value t
                                     ) ; end core-intmap-node-value
                                     (core-intmap-node-left t
                                     ) ; end core-intmap-node-left
                                     (loop (core-intmap-node-right t
                                           ) ; end core-intmap-node-right
                                     ) ; end loop
                ) ; end core-intmap-balance
               ] ; end clause
               [else
                (make-core-intmap-node
                 (core-intmap-node-size t
                 ) ; end core-intmap-node-size
                 key
                 (core-intmap-produced-value
                  present
                  (core-intmap-node-value t
                  ) ; end core-intmap-node-value
                  #t
                 ) ; end core-intmap-produced-value
                 (core-intmap-node-left t
                 ) ; end core-intmap-node-left
                 (core-intmap-node-right t
                 ) ; end core-intmap-node-right
                ) ; end make-core-intmap-node
               ] ; end else
              ) ; end cond
            ) ; end let
           ] ; end else
          ) ; end cond
        ) ; end let
        (let loop ([t im
                   ] ; end t
                  ) ; end form
          (cond
           [(core-intmap-empty-record? t
            ) ; end core-intmap-empty-record?
            (core-intmap-make-node
             key
             (core-intmap-produced-value absent #f #f
             ) ; end core-intmap-produced-value
             empty-core-intmap
             empty-core-intmap
            ) ; end core-intmap-make-node
           ] ; end clause
           [else
            (let ([tk (core-intmap-node-key t
                      ) ; end core-intmap-node-key
                  ] ; end tk
                 ) ; end form
              (cond
               [(core-intmap-key<? key tk
                ) ; end core-intmap-key<?
                (core-intmap-balance tk
                                     (core-intmap-node-value t
                                     ) ; end core-intmap-node-value
                                     (loop (core-intmap-node-left t
                                           ) ; end core-intmap-node-left
                                     ) ; end loop
                                     (core-intmap-node-right t
                                     ) ; end core-intmap-node-right
                ) ; end core-intmap-balance
               ] ; end clause
               [(core-intmap-key>? key tk
                ) ; end core-intmap-key>?
                (core-intmap-balance tk
                                     (core-intmap-node-value t
                                     ) ; end core-intmap-node-value
                                     (core-intmap-node-left t
                                     ) ; end core-intmap-node-left
                                     (loop (core-intmap-node-right t
                                           ) ; end core-intmap-node-right
                                     ) ; end loop
                ) ; end core-intmap-balance
               ] ; end clause
               [else
                (make-core-intmap-node
                 (core-intmap-node-size t
                 ) ; end core-intmap-node-size
                 key
                 (core-intmap-produced-value
                  present
                  (core-intmap-node-value t
                  ) ; end core-intmap-node-value
                  #t
                 ) ; end core-intmap-produced-value
                 (core-intmap-node-left t
                 ) ; end core-intmap-node-left
                 (core-intmap-node-right t
                 ) ; end core-intmap-node-right
                ) ; end make-core-intmap-node
               ] ; end else
              ) ; end cond
            ) ; end let
           ] ; end else
          ) ; end cond
        ) ; end let
    ) ; end if
  ) ; end let
) ; end define

(define (core-intmap-set/absent im key value
        ) ; end core-intmap-set/absent
  (let ([im (core-check-intmap 'core-intmap-set/absent im
            ) ; end core-check-intmap
        ] ; end im
        [key (core-check-intmap-key 'core-intmap-set/absent key
             ) ; end core-check-intmap-key
        ] ; end key
       ) ; end form
    (if (fixnum? key
        ) ; end fixnum?
        (let loop ([t im
                   ] ; end t
                  ) ; end form
          (cond
           [(core-intmap-empty-record? t
            ) ; end core-intmap-empty-record?
            (values (core-intmap-make-node key value empty-core-intmap empty-core-intmap
                    ) ; end core-intmap-make-node
                    #t
            ) ; end values
           ] ; end clause
           [else
            (let ([tk (core-intmap-node-key t
                      ) ; end core-intmap-node-key
                  ] ; end tk
                 ) ; end form
              (cond
               [(core-intmap-fixnum-key<? key tk
                ) ; end core-intmap-fixnum-key<?
                (let-values ([(left inserted?
                               ) ; end left
                              (loop (core-intmap-node-left t
                                    ) ; end core-intmap-node-left
                              ) ; end loop
                             ] ; end clause
                            ) ; end form
                  (if inserted?
                      (values (core-intmap-balance tk
                                                   (core-intmap-node-value t
                                                   ) ; end core-intmap-node-value
                                                   left
                                                   (core-intmap-node-right t
                                                   ) ; end core-intmap-node-right
                              ) ; end core-intmap-balance
                              #t
                      ) ; end values
                      (values t #f
                      ) ; end values
                  ) ; end if
                ) ; end let-values
               ] ; end clause
               [(core-intmap-fixnum-key>? key tk
                ) ; end core-intmap-fixnum-key>?
                (let-values ([(right inserted?
                               ) ; end right
                              (loop (core-intmap-node-right t
                                    ) ; end core-intmap-node-right
                              ) ; end loop
                             ] ; end clause
                            ) ; end form
                  (if inserted?
                      (values (core-intmap-balance tk
                                                   (core-intmap-node-value t
                                                   ) ; end core-intmap-node-value
                                                   (core-intmap-node-left t
                                                   ) ; end core-intmap-node-left
                                                   right
                              ) ; end core-intmap-balance
                              #t
                      ) ; end values
                      (values t #f
                      ) ; end values
                  ) ; end if
                ) ; end let-values
               ] ; end clause
               [else (values t #f
                     ) ; end values
               ] ; end else
              ) ; end cond
            ) ; end let
           ] ; end else
          ) ; end cond
        ) ; end let
        (let loop ([t im
                   ] ; end t
                  ) ; end form
          (cond
           [(core-intmap-empty-record? t
            ) ; end core-intmap-empty-record?
            (values (core-intmap-make-node key value empty-core-intmap empty-core-intmap
                    ) ; end core-intmap-make-node
                    #t
            ) ; end values
           ] ; end clause
           [else
            (let ([tk (core-intmap-node-key t
                      ) ; end core-intmap-node-key
                  ] ; end tk
                 ) ; end form
              (cond
               [(core-intmap-key<? key tk
                ) ; end core-intmap-key<?
                (let-values ([(left inserted?
                               ) ; end left
                              (loop (core-intmap-node-left t
                                    ) ; end core-intmap-node-left
                              ) ; end loop
                             ] ; end clause
                            ) ; end form
                  (if inserted?
                      (values (core-intmap-balance tk
                                                   (core-intmap-node-value t
                                                   ) ; end core-intmap-node-value
                                                   left
                                                   (core-intmap-node-right t
                                                   ) ; end core-intmap-node-right
                              ) ; end core-intmap-balance
                              #t
                      ) ; end values
                      (values t #f
                      ) ; end values
                  ) ; end if
                ) ; end let-values
               ] ; end clause
               [(core-intmap-key>? key tk
                ) ; end core-intmap-key>?
                (let-values ([(right inserted?
                               ) ; end right
                              (loop (core-intmap-node-right t
                                    ) ; end core-intmap-node-right
                              ) ; end loop
                             ] ; end clause
                            ) ; end form
                  (if inserted?
                      (values (core-intmap-balance tk
                                                   (core-intmap-node-value t
                                                   ) ; end core-intmap-node-value
                                                   (core-intmap-node-left t
                                                   ) ; end core-intmap-node-left
                                                   right
                              ) ; end core-intmap-balance
                              #t
                      ) ; end values
                      (values t #f
                      ) ; end values
                  ) ; end if
                ) ; end let-values
               ] ; end clause
               [else (values t #f
                     ) ; end values
               ] ; end else
              ) ; end cond
            ) ; end let
           ] ; end else
          ) ; end cond
        ) ; end let
    ) ; end if
  ) ; end let
) ; end define

(define (core-intmap-always-same? expected actual
        ) ; end core-intmap-always-same?
  #t
) ; end define

(define (core-intmap-replace/check who same? im key expected value
        ) ; end core-intmap-replace/check
  (let ([im (core-check-intmap who im
            ) ; end core-check-intmap
        ] ; end im
        [key (core-check-intmap-key who key
             ) ; end core-check-intmap-key
        ] ; end key
       ) ; end form
    (if (fixnum? key
        ) ; end fixnum?
        (let loop ([t im
                   ] ; end t
                  ) ; end form
          (cond
           [(core-intmap-empty-record? t) (values t #f
                                      ) ; end values
           ] ; end t
           [else
            (let ([tk (core-intmap-node-key t
                      ) ; end core-intmap-node-key
                  ] ; end tk
                 ) ; end form
              (cond
               [(core-intmap-fixnum-key<? key tk
                ) ; end core-intmap-fixnum-key<?
                (let-values ([(left changed?
                               ) ; end left
                              (loop (core-intmap-node-left t
                                    ) ; end core-intmap-node-left
                              ) ; end loop
                             ] ; end clause
                            ) ; end form
                  (if changed?
                      (values (core-intmap-balance tk
                                                   (core-intmap-node-value t
                                                   ) ; end core-intmap-node-value
                                                   left
                                                   (core-intmap-node-right t
                                                   ) ; end core-intmap-node-right
                              ) ; end core-intmap-balance
                              #t
                      ) ; end values
                      (values t #f
                      ) ; end values
                  ) ; end if
                ) ; end let-values
               ] ; end clause
               [(core-intmap-fixnum-key>? key tk
                ) ; end core-intmap-fixnum-key>?
                (let-values ([(right changed?
                               ) ; end right
                              (loop (core-intmap-node-right t
                                    ) ; end core-intmap-node-right
                              ) ; end loop
                             ] ; end clause
                            ) ; end form
                  (if changed?
                      (values (core-intmap-balance tk
                                                   (core-intmap-node-value t
                                                   ) ; end core-intmap-node-value
                                                   (core-intmap-node-left t
                                                   ) ; end core-intmap-node-left
                                                   right
                              ) ; end core-intmap-balance
                              #t
                      ) ; end values
                      (values t #f
                      ) ; end values
                  ) ; end if
                ) ; end let-values
               ] ; end clause
               [(same? expected (core-intmap-node-value t
                                ) ; end core-intmap-node-value
                ) ; end same?
                (values (make-core-intmap-node
                         (core-intmap-node-size t
                         ) ; end core-intmap-node-size
                         key
                         value
                         (core-intmap-node-left t
                         ) ; end core-intmap-node-left
                         (core-intmap-node-right t
                         ) ; end core-intmap-node-right
                        ) ; end make-core-intmap-node
                        #t
                ) ; end values
               ] ; end clause
               [else (values t #f
                     ) ; end values
               ] ; end else
              ) ; end cond
            ) ; end let
           ] ; end else
          ) ; end cond
        ) ; end let
        (let loop ([t im
                   ] ; end t
                  ) ; end form
          (cond
           [(core-intmap-empty-record? t) (values t #f
                                      ) ; end values
           ] ; end t
           [else
            (let ([tk (core-intmap-node-key t
                      ) ; end core-intmap-node-key
                  ] ; end tk
                 ) ; end form
              (cond
               [(core-intmap-key<? key tk
                ) ; end core-intmap-key<?
                (let-values ([(left changed?
                               ) ; end left
                              (loop (core-intmap-node-left t
                                    ) ; end core-intmap-node-left
                              ) ; end loop
                             ] ; end clause
                            ) ; end form
                  (if changed?
                      (values (core-intmap-balance tk
                                                   (core-intmap-node-value t
                                                   ) ; end core-intmap-node-value
                                                   left
                                                   (core-intmap-node-right t
                                                   ) ; end core-intmap-node-right
                              ) ; end core-intmap-balance
                              #t
                      ) ; end values
                      (values t #f
                      ) ; end values
                  ) ; end if
                ) ; end let-values
               ] ; end clause
               [(core-intmap-key>? key tk
                ) ; end core-intmap-key>?
                (let-values ([(right changed?
                               ) ; end right
                              (loop (core-intmap-node-right t
                                    ) ; end core-intmap-node-right
                              ) ; end loop
                             ] ; end clause
                            ) ; end form
                  (if changed?
                      (values (core-intmap-balance tk
                                                   (core-intmap-node-value t
                                                   ) ; end core-intmap-node-value
                                                   (core-intmap-node-left t
                                                   ) ; end core-intmap-node-left
                                                   right
                              ) ; end core-intmap-balance
                              #t
                      ) ; end values
                      (values t #f
                      ) ; end values
                  ) ; end if
                ) ; end let-values
               ] ; end clause
               [(same? expected (core-intmap-node-value t
                                ) ; end core-intmap-node-value
                ) ; end same?
                (values (make-core-intmap-node
                         (core-intmap-node-size t
                         ) ; end core-intmap-node-size
                         key
                         value
                         (core-intmap-node-left t
                         ) ; end core-intmap-node-left
                         (core-intmap-node-right t
                         ) ; end core-intmap-node-right
                        ) ; end make-core-intmap-node
                        #t
                ) ; end values
               ] ; end clause
               [else (values t #f
                     ) ; end values
               ] ; end else
              ) ; end cond
            ) ; end let
           ] ; end else
          ) ; end cond
        ) ; end let
    ) ; end if
  ) ; end let
) ; end define

(define (core-intmap-replace im key value
        ) ; end core-intmap-replace
  (core-intmap-replace/check
   'core-intmap-replace
   core-intmap-always-same?
   im
   key
   #f
   value
  ) ; end core-intmap-replace/check
) ; end define

(define (core-intmap-replace/eq im key expected value
        ) ; end core-intmap-replace/eq
  (core-intmap-replace/check
   'core-intmap-replace/eq
   eq?
   im
   key
   expected
   value
  ) ; end core-intmap-replace/check
) ; end define

(define (core-intmap-replace/equal im key expected value
        ) ; end core-intmap-replace/equal
  (core-intmap-replace/check
   'core-intmap-replace/equal
   equal?
   im
   key
   expected
   value
  ) ; end core-intmap-replace/check
) ; end define

(define (core-intmap-delete-find-min t
        ) ; end core-intmap-delete-find-min
  (cond
   [(core-intmap-empty-record? (core-intmap-node-left t
                               ) ; end core-intmap-node-left
    ) ; end core-intmap-empty-record?
    (values (core-intmap-node-key t
            ) ; end core-intmap-node-key
            (core-intmap-node-value t
            ) ; end core-intmap-node-value
            (core-intmap-node-right t
            ) ; end core-intmap-node-right
    ) ; end values
   ] ; end clause
   [else
    (let-values ([(key value left*
                  ) ; end key
                  (core-intmap-delete-find-min (core-intmap-node-left t
                                               ) ; end core-intmap-node-left
                  ) ; end core-intmap-delete-find-min
                 ] ; end clause
                ) ; end form
      (values key
              value
              (core-intmap-balance (core-intmap-node-key t
                                   ) ; end core-intmap-node-key
                                   (core-intmap-node-value t
                                   ) ; end core-intmap-node-value
                                   left*
                                   (core-intmap-node-right t
                                   ) ; end core-intmap-node-right
              ) ; end core-intmap-balance
      ) ; end values
    ) ; end let-values
   ] ; end else
  ) ; end cond
) ; end define

(define (core-intmap-delete-find-max t
        ) ; end core-intmap-delete-find-max
  (cond
   [(core-intmap-empty-record? (core-intmap-node-right t
                               ) ; end core-intmap-node-right
    ) ; end core-intmap-empty-record?
    (values (core-intmap-node-key t
            ) ; end core-intmap-node-key
            (core-intmap-node-value t
            ) ; end core-intmap-node-value
            (core-intmap-node-left t
            ) ; end core-intmap-node-left
    ) ; end values
   ] ; end clause
   [else
    (let-values ([(key value right*
                  ) ; end key
                  (core-intmap-delete-find-max (core-intmap-node-right t
                                               ) ; end core-intmap-node-right
                  ) ; end core-intmap-delete-find-max
                 ] ; end clause
                ) ; end form
      (values key
              value
              (core-intmap-balance (core-intmap-node-key t
                                   ) ; end core-intmap-node-key
                                   (core-intmap-node-value t
                                   ) ; end core-intmap-node-value
                                   (core-intmap-node-left t
                                   ) ; end core-intmap-node-left
                                   right*
              ) ; end core-intmap-balance
      ) ; end values
    ) ; end let-values
   ] ; end else
  ) ; end cond
) ; end define

(define (core-intmap-glue left right
        ) ; end core-intmap-glue
  (cond
   [(core-intmap-empty-record? left) right
   ] ; end right
   [(core-intmap-empty-record? right) left
   ] ; end left
   [(> (core-intmap-size left) (core-intmap-size right
                               ) ; end core-intmap-size
    ) ; end >
    (let-values ([(key value left*) (core-intmap-delete-find-max left
                                    ) ; end core-intmap-delete-find-max
                 ] ; end clause
                ) ; end form
      (core-intmap-balance key value left* right
      ) ; end core-intmap-balance
    ) ; end let-values
   ] ; end clause
   [else
    (let-values ([(key value right*) (core-intmap-delete-find-min right
                                     ) ; end core-intmap-delete-find-min
                 ] ; end clause
                ) ; end form
      (core-intmap-balance key value left right*
      ) ; end core-intmap-balance
    ) ; end let-values
   ] ; end else
  ) ; end cond
) ; end define

(define (core-intmap-remove im key
        ) ; end core-intmap-remove
  (let ([im (core-check-intmap 'core-intmap-remove im
            ) ; end core-check-intmap
        ] ; end im
        [key (core-check-intmap-key 'core-intmap-remove key
             ) ; end core-check-intmap-key
        ] ; end key
       ) ; end form
    (if (fixnum? key
        ) ; end fixnum?
        (let loop ([t im
                   ] ; end t
                  ) ; end form
          (cond
           [(core-intmap-empty-record? t) t
           ] ; end t
           [else
            (let ([tk (core-intmap-node-key t
                      ) ; end core-intmap-node-key
                  ] ; end tk
                 ) ; end form
              (cond
               [(core-intmap-fixnum-key<? key tk
                ) ; end core-intmap-fixnum-key<?
                (core-intmap-balance tk
                                     (core-intmap-node-value t
                                     ) ; end core-intmap-node-value
                                     (loop (core-intmap-node-left t
                                           ) ; end core-intmap-node-left
                                     ) ; end loop
                                     (core-intmap-node-right t
                                     ) ; end core-intmap-node-right
                ) ; end core-intmap-balance
               ] ; end clause
               [(core-intmap-fixnum-key>? key tk
                ) ; end core-intmap-fixnum-key>?
                (core-intmap-balance tk
                                     (core-intmap-node-value t
                                     ) ; end core-intmap-node-value
                                     (core-intmap-node-left t
                                     ) ; end core-intmap-node-left
                                     (loop (core-intmap-node-right t
                                           ) ; end core-intmap-node-right
                                     ) ; end loop
                ) ; end core-intmap-balance
               ] ; end clause
               [else
                (core-intmap-glue (core-intmap-node-left t
                                  ) ; end core-intmap-node-left
                                  (core-intmap-node-right t
                                  ) ; end core-intmap-node-right
                ) ; end core-intmap-glue
               ] ; end else
              ) ; end cond
            ) ; end let
           ] ; end else
          ) ; end cond
        ) ; end let
        (let loop ([t im
                   ] ; end t
                  ) ; end form
          (cond
           [(core-intmap-empty-record? t) t
           ] ; end t
           [else
            (let ([tk (core-intmap-node-key t
                      ) ; end core-intmap-node-key
                  ] ; end tk
                 ) ; end form
              (cond
               [(core-intmap-key<? key tk
                ) ; end core-intmap-key<?
                (core-intmap-balance tk
                                     (core-intmap-node-value t
                                     ) ; end core-intmap-node-value
                                     (loop (core-intmap-node-left t
                                           ) ; end core-intmap-node-left
                                     ) ; end loop
                                     (core-intmap-node-right t
                                     ) ; end core-intmap-node-right
                ) ; end core-intmap-balance
               ] ; end clause
               [(core-intmap-key>? key tk
                ) ; end core-intmap-key>?
                (core-intmap-balance tk
                                     (core-intmap-node-value t
                                     ) ; end core-intmap-node-value
                                     (core-intmap-node-left t
                                     ) ; end core-intmap-node-left
                                     (loop (core-intmap-node-right t
                                           ) ; end core-intmap-node-right
                                     ) ; end loop
                ) ; end core-intmap-balance
               ] ; end clause
               [else
                (core-intmap-glue (core-intmap-node-left t
                                  ) ; end core-intmap-node-left
                                  (core-intmap-node-right t
                                  ) ; end core-intmap-node-right
                ) ; end core-intmap-glue
               ] ; end else
              ) ; end cond
            ) ; end let
           ] ; end else
          ) ; end cond
        ) ; end let
    ) ; end if
  ) ; end let
) ; end define

(define (core-intmap-remove/check who same? im key expected
        ) ; end core-intmap-remove/check
  (let ([im (core-check-intmap who im
            ) ; end core-check-intmap
        ] ; end im
        [key (core-check-intmap-key who key
             ) ; end core-check-intmap-key
        ] ; end key
       ) ; end form
    (if (fixnum? key
        ) ; end fixnum?
        (let loop ([t im
                   ] ; end t
                  ) ; end form
          (cond
           [(core-intmap-empty-record? t) (values t #f
                                      ) ; end values
           ] ; end t
           [else
            (let ([tk (core-intmap-node-key t
                      ) ; end core-intmap-node-key
                  ] ; end tk
                 ) ; end form
              (cond
               [(core-intmap-fixnum-key<? key tk
                ) ; end core-intmap-fixnum-key<?
                (let-values ([(left removed?
                               ) ; end left
                              (loop (core-intmap-node-left t
                                    ) ; end core-intmap-node-left
                              ) ; end loop
                             ] ; end clause
                            ) ; end form
                  (if removed?
                      (values (core-intmap-balance tk
                                                   (core-intmap-node-value t
                                                   ) ; end core-intmap-node-value
                                                   left
                                                   (core-intmap-node-right t
                                                   ) ; end core-intmap-node-right
                              ) ; end core-intmap-balance
                              #t
                      ) ; end values
                      (values t #f
                      ) ; end values
                  ) ; end if
                ) ; end let-values
               ] ; end clause
               [(core-intmap-fixnum-key>? key tk
                ) ; end core-intmap-fixnum-key>?
                (let-values ([(right removed?
                               ) ; end right
                              (loop (core-intmap-node-right t
                                    ) ; end core-intmap-node-right
                              ) ; end loop
                             ] ; end clause
                            ) ; end form
                  (if removed?
                      (values (core-intmap-balance tk
                                                   (core-intmap-node-value t
                                                   ) ; end core-intmap-node-value
                                                   (core-intmap-node-left t
                                                   ) ; end core-intmap-node-left
                                                   right
                              ) ; end core-intmap-balance
                              #t
                      ) ; end values
                      (values t #f
                      ) ; end values
                  ) ; end if
                ) ; end let-values
               ] ; end clause
               [(same? expected (core-intmap-node-value t
                                ) ; end core-intmap-node-value
                ) ; end same?
                (values (core-intmap-glue (core-intmap-node-left t
                                           ) ; end core-intmap-node-left
                                           (core-intmap-node-right t
                                           ) ; end core-intmap-node-right
                        ) ; end core-intmap-glue
                        #t
                ) ; end values
               ] ; end clause
               [else (values t #f
                     ) ; end values
               ] ; end else
              ) ; end cond
            ) ; end let
           ] ; end else
          ) ; end cond
        ) ; end let
        (let loop ([t im
                   ] ; end t
                  ) ; end form
          (cond
           [(core-intmap-empty-record? t) (values t #f
                                      ) ; end values
           ] ; end t
           [else
            (let ([tk (core-intmap-node-key t
                      ) ; end core-intmap-node-key
                  ] ; end tk
                 ) ; end form
              (cond
               [(core-intmap-key<? key tk
                ) ; end core-intmap-key<?
                (let-values ([(left removed?
                               ) ; end left
                              (loop (core-intmap-node-left t
                                    ) ; end core-intmap-node-left
                              ) ; end loop
                             ] ; end clause
                            ) ; end form
                  (if removed?
                      (values (core-intmap-balance tk
                                                   (core-intmap-node-value t
                                                   ) ; end core-intmap-node-value
                                                   left
                                                   (core-intmap-node-right t
                                                   ) ; end core-intmap-node-right
                              ) ; end core-intmap-balance
                              #t
                      ) ; end values
                      (values t #f
                      ) ; end values
                  ) ; end if
                ) ; end let-values
               ] ; end clause
               [(core-intmap-key>? key tk
                ) ; end core-intmap-key>?
                (let-values ([(right removed?
                               ) ; end right
                              (loop (core-intmap-node-right t
                                    ) ; end core-intmap-node-right
                              ) ; end loop
                             ] ; end clause
                            ) ; end form
                  (if removed?
                      (values (core-intmap-balance tk
                                                   (core-intmap-node-value t
                                                   ) ; end core-intmap-node-value
                                                   (core-intmap-node-left t
                                                   ) ; end core-intmap-node-left
                                                   right
                              ) ; end core-intmap-balance
                              #t
                      ) ; end values
                      (values t #f
                      ) ; end values
                  ) ; end if
                ) ; end let-values
               ] ; end clause
               [(same? expected (core-intmap-node-value t
                                ) ; end core-intmap-node-value
                ) ; end same?
                (values (core-intmap-glue (core-intmap-node-left t
                                           ) ; end core-intmap-node-left
                                           (core-intmap-node-right t
                                           ) ; end core-intmap-node-right
                        ) ; end core-intmap-glue
                        #t
                ) ; end values
               ] ; end clause
               [else (values t #f
                     ) ; end values
               ] ; end else
              ) ; end cond
            ) ; end let
           ] ; end else
          ) ; end cond
        ) ; end let
    ) ; end if
  ) ; end let
) ; end define

(define (core-intmap-remove/eq im key expected
        ) ; end core-intmap-remove/eq
  (core-intmap-remove/check
   'core-intmap-remove/eq
   eq?
   im
   key
   expected
  ) ; end core-intmap-remove/check
) ; end define

(define (core-intmap-remove/equal im key expected
        ) ; end core-intmap-remove/equal
  (core-intmap-remove/check
   'core-intmap-remove/equal
   equal?
   im
   key
   expected
  ) ; end core-intmap-remove/check
) ; end define

(define (core-intmap-node->entry t
        ) ; end core-intmap-node->entry
  (and t
       (cons (core-intmap-node-key t
             ) ; end core-intmap-node-key
             (core-intmap-node-value t
             ) ; end core-intmap-node-value
       ) ; end cons
  ) ; end and
) ; end define

(define (core-intmap-search-lower im key ok?
        ) ; end core-intmap-search-lower
  (let loop ([t im] [best #f
                    ] ; end best
            ) ; end form
    (cond
     [(core-intmap-empty-record? t) best
     ] ; end best
     [else
      (let ([tk (core-intmap-node-key t
                ) ; end core-intmap-node-key
            ] ; end tk
           ) ; end form
        (if (ok? tk key
            ) ; end ok?
            (loop (core-intmap-node-right t) t
            ) ; end loop
            (loop (core-intmap-node-left t) best
            ) ; end loop
        ) ; end if
      ) ; end let
     ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (core-intmap-search-lower/fixnum im key ok?
        ) ; end core-intmap-search-lower/fixnum
  (let loop ([t im] [best #f
                    ] ; end best
            ) ; end form
    (cond
     [(core-intmap-empty-record? t) best
     ] ; end best
     [else
      (let ([tk (core-intmap-node-key t
                ) ; end core-intmap-node-key
            ] ; end tk
           ) ; end form
        (if (ok? tk key
            ) ; end ok?
            (loop (core-intmap-node-right t) t
            ) ; end loop
            (loop (core-intmap-node-left t) best
            ) ; end loop
        ) ; end if
      ) ; end let
     ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (core-intmap-search-upper im key ok?
        ) ; end core-intmap-search-upper
  (let loop ([t im] [best #f
                    ] ; end best
            ) ; end form
    (cond
     [(core-intmap-empty-record? t) best
     ] ; end best
     [else
      (let ([tk (core-intmap-node-key t
                ) ; end core-intmap-node-key
            ] ; end tk
           ) ; end form
        (if (ok? tk key
            ) ; end ok?
            (loop (core-intmap-node-left t) t
            ) ; end loop
            (loop (core-intmap-node-right t) best
            ) ; end loop
        ) ; end if
      ) ; end let
     ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (core-intmap-search-upper/fixnum im key ok?
        ) ; end core-intmap-search-upper/fixnum
  (let loop ([t im] [best #f
                    ] ; end best
            ) ; end form
    (cond
     [(core-intmap-empty-record? t) best
     ] ; end best
     [else
      (let ([tk (core-intmap-node-key t
                ) ; end core-intmap-node-key
            ] ; end tk
           ) ; end form
        (if (ok? tk key
            ) ; end ok?
            (loop (core-intmap-node-left t) t
            ) ; end loop
            (loop (core-intmap-node-right t) best
            ) ; end loop
        ) ; end if
      ) ; end let
     ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (core-intmap-entry< im key default
        ) ; end core-intmap-entry<
  (let ([im (core-check-intmap 'core-intmap-entry< im
            ) ; end core-check-intmap
        ] ; end im
        [key (core-check-intmap-key 'core-intmap-entry< key
             ) ; end core-check-intmap-key
        ] ; end key
       ) ; end form
    (or (core-intmap-node->entry
         (if (fixnum? key
             ) ; end fixnum?
             (core-intmap-search-lower/fixnum im key core-intmap-key<fixnum?
             ) ; end core-intmap-search-lower/fixnum
             (core-intmap-search-lower im key core-intmap-key<?
             ) ; end core-intmap-search-lower
         ) ; end if
        ) ; end core-intmap-node->entry
        default
    ) ; end or
  ) ; end let
) ; end define

(define (core-intmap-entry<= im key default
        ) ; end core-intmap-entry<=
  (let ([im (core-check-intmap 'core-intmap-entry<= im
            ) ; end core-check-intmap
        ] ; end im
        [key (core-check-intmap-key 'core-intmap-entry<= key
             ) ; end core-check-intmap-key
        ] ; end key
       ) ; end form
    (or (core-intmap-node->entry
         (if (fixnum? key
             ) ; end fixnum?
             (core-intmap-search-lower/fixnum im key core-intmap-key<=fixnum?
             ) ; end core-intmap-search-lower/fixnum
             (core-intmap-search-lower im key core-intmap-key<=?
             ) ; end core-intmap-search-lower
         ) ; end if
        ) ; end core-intmap-node->entry
        default
    ) ; end or
  ) ; end let
) ; end define

(define (core-intmap-entry> im key default
        ) ; end core-intmap-entry>
  (let ([im (core-check-intmap 'core-intmap-entry> im
            ) ; end core-check-intmap
        ] ; end im
        [key (core-check-intmap-key 'core-intmap-entry> key
             ) ; end core-check-intmap-key
        ] ; end key
       ) ; end form
    (or (core-intmap-node->entry
         (if (fixnum? key
             ) ; end fixnum?
             (core-intmap-search-upper/fixnum im key core-intmap-key>fixnum?
             ) ; end core-intmap-search-upper/fixnum
             (core-intmap-search-upper im key core-intmap-key>?
             ) ; end core-intmap-search-upper
         ) ; end if
        ) ; end core-intmap-node->entry
        default
    ) ; end or
  ) ; end let
) ; end define

(define (core-intmap-entry>= im key default
        ) ; end core-intmap-entry>=
  (let ([im (core-check-intmap 'core-intmap-entry>= im
            ) ; end core-check-intmap
        ] ; end im
        [key (core-check-intmap-key 'core-intmap-entry>= key
             ) ; end core-check-intmap-key
        ] ; end key
       ) ; end form
    (or (core-intmap-node->entry
         (if (fixnum? key
             ) ; end fixnum?
             (core-intmap-search-upper/fixnum im key core-intmap-key>=fixnum?
             ) ; end core-intmap-search-upper/fixnum
             (core-intmap-search-upper im key core-intmap-key>=?
             ) ; end core-intmap-search-upper
         ) ; end if
        ) ; end core-intmap-node->entry
        default
    ) ; end or
  ) ; end let
) ; end define

(define (core-intmap-min-entry im default
        ) ; end core-intmap-min-entry
  (let ([im (core-check-intmap 'core-intmap-min-entry im
            ) ; end core-check-intmap
        ] ; end im
       ) ; end form
    (let loop ([t im
               ] ; end t
              ) ; end form
      (cond
       [(core-intmap-empty-record? t) default
       ] ; end default
       [(core-intmap-empty-record? (core-intmap-node-left t
                                   ) ; end core-intmap-node-left
        ) ; end core-intmap-empty-record?
        (cons (core-intmap-node-key t) (core-intmap-node-value t
                                       ) ; end core-intmap-node-value
        ) ; end cons
       ] ; end clause
       [else (loop (core-intmap-node-left t
                   ) ; end core-intmap-node-left
             ) ; end loop
       ] ; end else
      ) ; end cond
    ) ; end let
  ) ; end let
) ; end define

(define (core-intmap-max-entry im default
        ) ; end core-intmap-max-entry
  (let ([im (core-check-intmap 'core-intmap-max-entry im
            ) ; end core-check-intmap
        ] ; end im
       ) ; end form
    (let loop ([t im
               ] ; end t
              ) ; end form
      (cond
       [(core-intmap-empty-record? t) default
       ] ; end default
       [(core-intmap-empty-record? (core-intmap-node-right t
                                   ) ; end core-intmap-node-right
        ) ; end core-intmap-empty-record?
        (cons (core-intmap-node-key t) (core-intmap-node-value t
                                       ) ; end core-intmap-node-value
        ) ; end cons
       ] ; end clause
       [else (loop (core-intmap-node-right t
                   ) ; end core-intmap-node-right
             ) ; end loop
       ] ; end else
      ) ; end cond
    ) ; end let
  ) ; end let
) ; end define

(define (core-intmap-range->list im lo hi inclusive-lo? inclusive-hi?
        ) ; end core-intmap-range->list
  (let ([im (core-check-intmap 'core-intmap-range->list im
            ) ; end core-check-intmap
        ] ; end im
       ) ; end form
    (when lo (core-check-intmap-key 'core-intmap-range->list lo
             ) ; end core-check-intmap-key
    ) ; end when
    (when hi (core-check-intmap-key 'core-intmap-range->list hi
             ) ; end core-check-intmap-key
    ) ; end when
    (letrec ([above-lo?
              (lambda (key
                      ) ; end key
                (or (not lo
                    ) ; end not
                    (if inclusive-lo?
                        (core-intmap-key>=? key lo
                        ) ; end core-intmap-key>=?
                        (core-intmap-key>? key lo
                        ) ; end core-intmap-key>?
                    ) ; end if
                ) ; end or
              ) ; end lambda
             ] ; end above-lo?
             [below-hi?
              (lambda (key
                      ) ; end key
                (or (not hi
                    ) ; end not
                    (if inclusive-hi?
                        (core-intmap-key<=? key hi
                        ) ; end core-intmap-key<=?
                        (core-intmap-key<? key hi
                        ) ; end core-intmap-key<?
                    ) ; end if
                ) ; end or
              ) ; end lambda
             ] ; end below-hi?
             [maybe-left?
              (lambda (key
                      ) ; end key
                (or (not lo) (core-intmap-key>? key lo
                             ) ; end core-intmap-key>?
                ) ; end or
              ) ; end lambda
             ] ; end maybe-left?
             [maybe-right?
              (lambda (key
                      ) ; end key
                (or (not hi) (core-intmap-key<? key hi
                             ) ; end core-intmap-key<?
                ) ; end or
              ) ; end lambda
             ] ; end maybe-right?
            ) ; end form
      (let loop ([t im] [acc '(
                              ) ; end form
                        ] ; end acc
                ) ; end form
        (cond
         [(core-intmap-empty-record? t) acc
         ] ; end acc
         [else
          (let* ([key (core-intmap-node-key t
                      ) ; end core-intmap-node-key
                 ] ; end key
                 [acc* (if (maybe-right? key
                           ) ; end maybe-right?
                           (loop (core-intmap-node-right t) acc
                           ) ; end loop
                           acc
                       ) ; end if
                 ] ; end acc*
                 [acc** (if (and (above-lo? key) (below-hi? key
                                                 ) ; end below-hi?
                            ) ; end and
                            (cons (cons key (core-intmap-node-value t)) acc*
                            ) ; end cons
                            acc*
                        ) ; end if
                 ] ; end acc**
                ) ; end form
            (if (maybe-left? key
                ) ; end maybe-left?
                (loop (core-intmap-node-left t) acc**
                ) ; end loop
                acc**
            ) ; end if
          ) ; end let*
         ] ; end else
        ) ; end cond
      ) ; end let
    ) ; end letrec
  ) ; end let
) ; end define

(define (core-intmap-entry-key who entry
        ) ; end core-intmap-entry-key
  (cond
   [(pair? entry) (car entry
                  ) ; end car
   ] ; end clause
   [else (raise-argument-error who "pair?" entry
         ) ; end raise-argument-error
   ] ; end else
  ) ; end cond
) ; end define

(define (core-intmap-entry-value who entry
        ) ; end core-intmap-entry-value
  (cond
   [(pair? entry) (cdr entry
                  ) ; end cdr
   ] ; end clause
   [else (raise-argument-error who "pair?" entry
         ) ; end raise-argument-error
   ] ; end else
  ) ; end cond
) ; end define

(define (core-sorted-vector->intmap vec
        ) ; end core-sorted-vector->intmap
  (unless (vector? vec
          ) ; end vector?
    (raise-argument-error 'sorted-vector->intmap "vector?" vec
    ) ; end raise-argument-error
  ) ; end unless
  (let ([len (#%vector-length vec
             ) ; end %vector-length
        ] ; end len
       ) ; end form
    (let check-loop ([i 0] [previous #f
                           ] ; end previous
                    ) ; end form
      (when (fx< i len
            ) ; end fx<
        (let* ([entry (#3%vector-ref vec i
                      ) ; end 3%vector-ref
               ] ; end entry
               [key (core-intmap-entry-key 'sorted-vector->intmap entry
                    ) ; end core-intmap-entry-key
               ] ; end key
              ) ; end form
          (core-check-intmap-key 'sorted-vector->intmap key
          ) ; end core-check-intmap-key
          (when (and previous (not (core-intmap-key<? previous key
                                   ) ; end core-intmap-key<?
                              ) ; end not
                ) ; end and
            (raise-arguments-error 'sorted-vector->intmap
                                   "expected strictly increasing integer keys"
                                   "previous key" previous
                                   "key" key
            ) ; end raise-arguments-error
          ) ; end when
          (check-loop (fx+ i 1) key
          ) ; end check-loop
        ) ; end let*
      ) ; end when
    ) ; end let
    (let build ([start 0] [end len
                          ] ; end end
               ) ; end form
      (if (fx>= start end
          ) ; end fx>=
          empty-core-intmap
          (let* ([mid (fxquotient (fx+ start end) 2
                      ) ; end fxquotient
                 ] ; end mid
                 [entry (#3%vector-ref vec mid
                        ) ; end 3%vector-ref
                 ] ; end entry
                ) ; end form
            (core-intmap-make-node
             (core-intmap-entry-key 'sorted-vector->intmap entry
             ) ; end core-intmap-entry-key
             (core-intmap-entry-value 'sorted-vector->intmap entry
             ) ; end core-intmap-entry-value
             (build start mid
             ) ; end build
             (build (fx+ mid 1) end
             ) ; end build
            ) ; end core-intmap-make-node
          ) ; end let*
      ) ; end if
    ) ; end let
  ) ; end let
) ; end define

(define (core-intmap-literal-error msg . args
        ) ; end core-intmap-literal-error
  (error 'core-intmap-literal->intmap (apply format msg args
                                      ) ; end apply
  ) ; end error
) ; end define

(define (core-intmap-literal-proper-list? v
        ) ; end core-intmap-literal-proper-list?
  (let loop ([v v
             ] ; end v
            ) ; end let args
    (cond
     [(null? v) #t
     ] ; end t
     [(pair? v)
      (loop (cdr v
            ) ; end cdr
      ) ; end loop
     ] ; end clause
     [else #f
     ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (core-intmap-literal-check-proper-list who v
        ) ; end core-intmap-literal-check-proper-list
  (unless (core-intmap-literal-proper-list? v
          ) ; end core-intmap-literal-proper-list?
    (core-intmap-literal-error "~a is not a proper list: ~s" who v
    ) ; end core-intmap-literal-error
  ) ; end unless
  v
) ; end define

(define (core-intmap-literal-order-error previous key
        ) ; end core-intmap-literal-order-error
  (raise-arguments-error 'core-intmap-literal->intmap
                         "expected strictly increasing integer keys"
                         "previous key" previous
                         "key" key
  ) ; end raise-arguments-error
) ; end define

(define (core-intmap-literal-duplicate-error key
        ) ; end core-intmap-literal-duplicate-error
  (raise-arguments-error 'core-intmap-literal->intmap
                         "duplicate key"
                         "key" key
  ) ; end raise-arguments-error
) ; end define

(define (core-intmap-literal-sort-vector vec len
        ) ; end core-intmap-literal-sort-vector
  (let ([wrapped (#%make-vector len
                 ) ; end #%make-vector
        ] ; end wrapped
       ) ; end let args
    (let loop ([i 0
               ] ; end i
              ) ; end let args
      (when (fx< i len
            ) ; end fx<
        (let* ([entry (#3%vector-ref vec i
                      ) ; end 3%vector-ref
               ] ; end entry
               [key (core-intmap-entry-key 'core-intmap-literal->intmap entry
                    ) ; end core-intmap-entry-key
               ] ; end key
              ) ; end let* args
          (#%vector-set! wrapped i (cons key (cons i entry
                                             ) ; end cons
                                  ) ; end cons
          ) ; end #%vector-set!
          (loop (fx+ i 1
                ) ; end fx+
          ) ; end loop
        ) ; end let*
      ) ; end when
    ) ; end let
    (chez:vector-sort
     (lambda (a b
             ) ; end lambda
       (let ([ak (car a
                 ) ; end car
             ] ; end ak
             [bk (car b
                 ) ; end car
             ] ; end bk
            ) ; end let args
         (cond
          [(core-intmap-key<? ak bk) #t
          ] ; end clause
          [(core-intmap-key<? bk ak) #f
          ] ; end clause
          [else (fx< (car (cdr a
                          ) ; end cdr
                     ) ; end car
                     (car (cdr b
                          ) ; end cdr
                     ) ; end car
                ) ; end fx<
          ] ; end else
         ) ; end cond
       ) ; end let
     ) ; end lambda
     wrapped
    ) ; end chez:vector-sort
  ) ; end let
) ; end define

(define (core-intmap-literal-sorted-entry item wrapped?
        ) ; end core-intmap-literal-sorted-entry
  (if wrapped?
      (cdr (cdr item
           ) ; end cdr
      ) ; end cdr
      item
  ) ; end if
) ; end define

(define (core-intmap-literal-sorted-key item wrapped?
        ) ; end core-intmap-literal-sorted-key
  (if wrapped?
      (car item
      ) ; end car
      (core-intmap-entry-key 'core-intmap-literal->intmap item
      ) ; end core-intmap-entry-key
  ) ; end if
) ; end define

(define (core-intmap-literal-build-compact-vector out len
        ) ; end core-intmap-literal-build-compact-vector
  (let ([compact (#%make-vector len
                 ) ; end #%make-vector
        ] ; end compact
       ) ; end let args
    (let loop ([i 0
               ] ; end i
              ) ; end let args
      (when (fx< i len
            ) ; end fx<
        (#%vector-set! compact i (#3%vector-ref out i
                               ) ; end 3%vector-ref
        ) ; end #%vector-set!
        (loop (fx+ i 1
              ) ; end fx+
        ) ; end loop
      ) ; end when
    ) ; end let
    compact
  ) ; end let
) ; end define

(define (core-intmap-literal-compact-sorted-vector sorted len wrapped? accept-duplicate-keys?
        ) ; end core-intmap-literal-compact-sorted-vector
  (if (fx= len 0
      ) ; end fx=
      empty-core-intmap
      (let* ([first-item (#3%vector-ref sorted 0
                         ) ; end 3%vector-ref
             ] ; end first-item
             [first-key (core-intmap-literal-sorted-key first-item wrapped?
                        ) ; end core-intmap-literal-sorted-key
             ] ; end first-key
             [first-entry (core-intmap-literal-sorted-entry first-item wrapped?
                          ) ; end core-intmap-literal-sorted-entry
             ] ; end first-entry
             [out (#%make-vector len
                  ) ; end #%make-vector
             ] ; end out
            ) ; end let* args
        (let loop ([i 1] [out-i 0
                         ] ; end out-i
                    [key first-key
                         ] ; end key
                    [entry first-entry
                         ] ; end entry
                  ) ; end let args
          (if (fx>= i len
              ) ; end fx>=
              (let ([out-len (fx+ out-i 1
                              ) ; end fx+
                    ] ; end out-len
                   ) ; end let args
                (#%vector-set! out out-i entry
                ) ; end #%vector-set!
                (core-sorted-vector->intmap
                 (if (fx= out-len len
                     ) ; end fx=
                     out
                     (core-intmap-literal-build-compact-vector out out-len
                     ) ; end core-intmap-literal-build-compact-vector
                 ) ; end if
                ) ; end core-sorted-vector->intmap
              ) ; end let
              (let* ([item (#3%vector-ref sorted i
                           ) ; end 3%vector-ref
                     ] ; end item
                     [next-key (core-intmap-literal-sorted-key item wrapped?
                               ) ; end core-intmap-literal-sorted-key
                     ] ; end next-key
                     [next-entry (core-intmap-literal-sorted-entry item wrapped?
                                 ) ; end core-intmap-literal-sorted-entry
                     ] ; end next-entry
                    ) ; end let* args
                (if (core-intmap-key=? key next-key
                    ) ; end core-intmap-key=?
                    (begin
                      (unless accept-duplicate-keys?
                        (core-intmap-literal-duplicate-error next-key
                        ) ; end core-intmap-literal-duplicate-error
                      ) ; end unless
                      (loop (fx+ i 1
                            ) ; end fx+
                            out-i
                            key
                            next-entry
                      ) ; end loop
                    ) ; end begin
                    (begin
                      (#%vector-set! out out-i entry
                      ) ; end #%vector-set!
                      (loop (fx+ i 1
                            ) ; end fx+
                            (fx+ out-i 1
                            ) ; end fx+
                            next-key
                            next-entry
                      ) ; end loop
                    ) ; end begin
                ) ; end if
              ) ; end let*
          ) ; end if
        ) ; end let
      ) ; end let*
  ) ; end if
) ; end define

(define (core-intmap-literal-adaptive->intmap vec accept-unordered? accept-duplicate-keys?
        ) ; end core-intmap-literal-adaptive->intmap
  (let ([len (#%vector-length vec
              ) ; end %vector-length
        ] ; end len
       ) ; end let args
    (let loop ([i 0] [previous #f
                     ] ; end previous
                  [needs-sort? #f
                     ] ; end needs-sort?
                  [needs-compact? #f
                     ] ; end needs-compact?
              ) ; end let args
      (if (fx>= i len
          ) ; end fx>=
          (cond
           [needs-sort?
            (core-intmap-literal-compact-sorted-vector
             (core-intmap-literal-sort-vector vec len
             ) ; end core-intmap-literal-sort-vector
             len
             #t
             accept-duplicate-keys?
            ) ; end core-intmap-literal-compact-sorted-vector
           ] ; end clause
           [needs-compact?
            (core-intmap-literal-compact-sorted-vector
             vec
             len
             #f
             accept-duplicate-keys?
            ) ; end core-intmap-literal-compact-sorted-vector
           ] ; end clause
           [else
            (core-sorted-vector->intmap vec
            ) ; end core-sorted-vector->intmap
           ] ; end else
          ) ; end cond
          (let* ([entry (#3%vector-ref vec i
                        ) ; end 3%vector-ref
                 ] ; end entry
                 [key (core-intmap-entry-key 'core-intmap-literal->intmap entry
                      ) ; end core-intmap-entry-key
                 ] ; end key
                ) ; end let* args
            (core-check-intmap-key 'core-intmap-literal->intmap key
            ) ; end core-check-intmap-key
            (cond
             [(not previous)
              (loop (fx+ i 1
                    ) ; end fx+
                    key
                    needs-sort?
                    needs-compact?
              ) ; end loop
             ] ; end clause
             [(core-intmap-key<? previous key
              ) ; end core-intmap-key<?
              (loop (fx+ i 1
                    ) ; end fx+
                    key
                    needs-sort?
                    needs-compact?
              ) ; end loop
             ] ; end clause
             [(core-intmap-key=? previous key
              ) ; end core-intmap-key=?
              (if accept-duplicate-keys?
                  (loop (fx+ i 1
                        ) ; end fx+
                        key
                        needs-sort?
                        #t
                  ) ; end loop
                  (core-intmap-literal-duplicate-error key
                  ) ; end core-intmap-literal-duplicate-error
              ) ; end if
             ] ; end clause
             [accept-unordered?
              (loop (fx+ i 1
                    ) ; end fx+
                    key
                    #t
                    needs-compact?
              ) ; end loop
             ] ; end clause
             [else
              (core-intmap-literal-order-error previous key
              ) ; end core-intmap-literal-order-error
             ] ; end else
            ) ; end cond
          ) ; end let*
      ) ; end if
    ) ; end let
  ) ; end let
) ; end define

(define (core-intmap-literal->intmap datum accept-unordered? accept-duplicate-keys?
        ) ; end core-intmap-literal->intmap
  (core-intmap-literal-check-proper-list 'entry-list datum
  ) ; end core-intmap-literal-check-proper-list
  (let ([vec (list->vector datum
             ) ; end list->vector
        ] ; end vec
       ) ; end let args
    (if (or accept-unordered? accept-duplicate-keys?
        ) ; end or
        (core-intmap-literal-adaptive->intmap vec
                                             accept-unordered?
                                             accept-duplicate-keys?
        ) ; end core-intmap-literal-adaptive->intmap
        (core-sorted-vector->intmap vec
        ) ; end core-sorted-vector->intmap
    ) ; end if
  ) ; end let
) ; end define

(define (core-intmap-push-left t stack
        ) ; end core-intmap-push-left
  (let loop ([t t] [stack stack
                   ] ; end stack
            ) ; end form
    (if (core-intmap-empty-record? t
        ) ; end core-intmap-empty-record?
        stack
        (loop (core-intmap-node-left t) (cons t stack
                                        ) ; end cons
        ) ; end loop
    ) ; end if
  ) ; end let
) ; end define

(define (core-intmap-push-right t stack
        ) ; end core-intmap-push-right
  (let loop ([t t] [stack stack
                   ] ; end stack
            ) ; end form
    (if (core-intmap-empty-record? t
        ) ; end core-intmap-empty-record?
        stack
        (loop (core-intmap-node-right t) (cons t stack
                                         ) ; end cons
        ) ; end loop
    ) ; end if
  ) ; end let
) ; end define

(define (core-intmap-push-left/from t stack lo inclusive-lo?
        ) ; end core-intmap-push-left/from
  (let loop ([t t] [stack stack
                   ] ; end stack
            ) ; end form
    (cond
     [(core-intmap-empty-record? t) stack
     ] ; end stack
     [else
      (let ([key (core-intmap-node-key t
                 ) ; end core-intmap-node-key
            ] ; end key
           ) ; end form
        (if (and lo
                 (or (core-intmap-key<? key lo
                     ) ; end core-intmap-key<?
                     (and (not inclusive-lo?
                          ) ; end not
                          (core-intmap-key=? key lo
                          ) ; end core-intmap-key=?
                     ) ; end and
                 ) ; end or
            ) ; end and
            (loop (core-intmap-node-right t) stack
            ) ; end loop
            (loop (core-intmap-node-left t) (cons t stack
                                            ) ; end cons
            ) ; end loop
        ) ; end if
      ) ; end let
     ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (core-intmap-push-right/from t stack hi inclusive-hi?
        ) ; end core-intmap-push-right/from
  (let loop ([t t] [stack stack
                   ] ; end stack
            ) ; end form
    (cond
     [(core-intmap-empty-record? t) stack
     ] ; end stack
     [else
      (let ([key (core-intmap-node-key t
                 ) ; end core-intmap-node-key
            ] ; end key
           ) ; end form
        (if (and hi
                 (or (core-intmap-key>? key hi
                     ) ; end core-intmap-key>?
                     (and (not inclusive-hi?
                          ) ; end not
                          (core-intmap-key=? key hi
                          ) ; end core-intmap-key=?
                     ) ; end and
                 ) ; end or
            ) ; end and
            (loop (core-intmap-node-left t) stack
            ) ; end loop
            (loop (core-intmap-node-right t) (cons t stack
                                             ) ; end cons
            ) ; end loop
        ) ; end if
      ) ; end let
     ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (core-intmap-cursor-stack-in-bound? reverse? bound inclusive-bound? stack
        ) ; end core-intmap-cursor-stack-in-bound?
  (or (null? stack
      ) ; end null?
      (let ([key (core-intmap-node-key (car stack
                                       ) ; end car
                 ) ; end core-intmap-node-key
            ] ; end key
           ) ; end form
        (if reverse?
            (or (not bound
                ) ; end not
                (if inclusive-bound?
                    (core-intmap-key>=? key bound
                    ) ; end core-intmap-key>=?
                    (core-intmap-key>? key bound
                    ) ; end core-intmap-key>?
                ) ; end if
            ) ; end or
            (or (not bound
                ) ; end not
                (if inclusive-bound?
                    (core-intmap-key<=? key bound
                    ) ; end core-intmap-key<=?
                    (core-intmap-key<? key bound
                    ) ; end core-intmap-key<?
                ) ; end if
            ) ; end or
        ) ; end if
      ) ; end let
  ) ; end or
) ; end define

(define (core-intmap-make-cursor-or-false stack reverse? bound inclusive-bound?
        ) ; end core-intmap-make-cursor-or-false
  (if (and (not (null? stack
                ) ; end null?
           ) ; end not
           (core-intmap-cursor-stack-in-bound? reverse? bound inclusive-bound? stack
           ) ; end core-intmap-cursor-stack-in-bound?
      ) ; end and
      (make-core-intmap-cursor stack reverse? bound inclusive-bound?
      ) ; end make-core-intmap-cursor
      #f
  ) ; end if
) ; end define

(define (core-intmap-cursor-start im reverse? lo hi inclusive-lo? inclusive-hi?
        ) ; end core-intmap-cursor-start
  (let ([im (core-check-intmap 'core-intmap-cursor-start im
            ) ; end core-check-intmap
        ] ; end im
       ) ; end form
    (when lo (core-check-intmap-key 'core-intmap-cursor-start lo
             ) ; end core-check-intmap-key
    ) ; end when
    (when hi (core-check-intmap-key 'core-intmap-cursor-start hi
             ) ; end core-check-intmap-key
    ) ; end when
    (if reverse?
        (core-intmap-make-cursor-or-false
         (core-intmap-push-right/from im '() hi inclusive-hi?
         ) ; end core-intmap-push-right/from
         #t
         lo
         inclusive-lo?
        ) ; end core-intmap-make-cursor-or-false
        (core-intmap-make-cursor-or-false
         (core-intmap-push-left/from im '() lo inclusive-lo?
         ) ; end core-intmap-push-left/from
         #f
         hi
         inclusive-hi?
        ) ; end core-intmap-make-cursor-or-false
    ) ; end if
  ) ; end let
) ; end define

(define (core-check-intmap-cursor who cursor
        ) ; end core-check-intmap-cursor
  (unless (core-intmap-cursor? cursor
          ) ; end core-intmap-cursor?
    (raise-argument-error who "core-intmap-cursor?" cursor
    ) ; end raise-argument-error
  ) ; end unless
  cursor
) ; end define

(define (core-intmap-cursor-key cursor
        ) ; end core-intmap-cursor-key
  (let* ([cursor (core-check-intmap-cursor 'core-intmap-cursor-key cursor
                 ) ; end core-check-intmap-cursor
         ] ; end cursor
         [stack (core-intmap-cursor-stack cursor
                ) ; end core-intmap-cursor-stack
         ] ; end stack
        ) ; end form
    (if (null? stack
        ) ; end null?
        (raise-arguments-error 'core-intmap-cursor-key "empty cursor"
        ) ; end raise-arguments-error
        (core-intmap-node-key (car stack
                              ) ; end car
        ) ; end core-intmap-node-key
    ) ; end if
  ) ; end let*
) ; end define

(define (core-intmap-cursor-value cursor
        ) ; end core-intmap-cursor-value
  (let* ([cursor (core-check-intmap-cursor 'core-intmap-cursor-value cursor
                 ) ; end core-check-intmap-cursor
         ] ; end cursor
         [stack (core-intmap-cursor-stack cursor
                ) ; end core-intmap-cursor-stack
         ] ; end stack
        ) ; end form
    (if (null? stack
        ) ; end null?
        (raise-arguments-error 'core-intmap-cursor-value "empty cursor"
        ) ; end raise-arguments-error
        (core-intmap-node-value (car stack
                                ) ; end car
        ) ; end core-intmap-node-value
    ) ; end if
  ) ; end let*
) ; end define

(define (core-intmap-cursor-next cursor
        ) ; end core-intmap-cursor-next
  (let* ([cursor (core-check-intmap-cursor 'core-intmap-cursor-next cursor
                 ) ; end core-check-intmap-cursor
         ] ; end cursor
         [stack (core-intmap-cursor-stack cursor
                ) ; end core-intmap-cursor-stack
         ] ; end stack
        ) ; end form
    (if (null? stack
        ) ; end null?
        #f
        (let* ([node (car stack
                     ) ; end car
               ] ; end node
               [rest (cdr stack
                     ) ; end cdr
               ] ; end rest
               [next-stack (if (core-intmap-cursor-reverse? cursor
                               ) ; end core-intmap-cursor-reverse?
                               (core-intmap-push-right (core-intmap-node-left node) rest
                               ) ; end core-intmap-push-right
                               (core-intmap-push-left (core-intmap-node-right node) rest
                               ) ; end core-intmap-push-left
                           ) ; end if
               ] ; end next-stack
              ) ; end form
          (core-intmap-make-cursor-or-false
           next-stack
           (core-intmap-cursor-reverse? cursor
           ) ; end core-intmap-cursor-reverse?
           (core-intmap-cursor-bound cursor
           ) ; end core-intmap-cursor-bound
           (core-intmap-cursor-inclusive-bound? cursor
           ) ; end core-intmap-cursor-inclusive-bound?
          ) ; end core-intmap-make-cursor-or-false
        ) ; end let*
    ) ; end if
  ) ; end let*
) ; end define

(define (core-intmap-cursor-key+value+next cursor
        ) ; end core-intmap-cursor-key+value+next
  (values (core-intmap-cursor-key cursor
          ) ; end core-intmap-cursor-key
          (core-intmap-cursor-value cursor
          ) ; end core-intmap-cursor-value
          (core-intmap-cursor-next cursor
          ) ; end core-intmap-cursor-next
  ) ; end values
) ; end define

(define (core-intmap-height im
        ) ; end core-intmap-height
  (if (core-intmap-empty-record? im
      ) ; end core-intmap-empty-record?
      0
      (+ 1
         (max (core-intmap-height (core-intmap-node-left im
                                  ) ; end core-intmap-node-left
              ) ; end core-intmap-height
              (core-intmap-height (core-intmap-node-right im
                                  ) ; end core-intmap-node-right
              ) ; end core-intmap-height
         ) ; end max
      ) ; end +
  ) ; end if
) ; end define

(define (core-intmap-max-imbalance im
        ) ; end core-intmap-max-imbalance
  (if (core-intmap-empty-record? im
      ) ; end core-intmap-empty-record?
      0
      (max (abs (- (core-intmap-size (core-intmap-node-left im
                                     ) ; end core-intmap-node-left
                   ) ; end core-intmap-size
                   (core-intmap-size (core-intmap-node-right im
                                     ) ; end core-intmap-node-right
                   ) ; end core-intmap-size
                ) ; end -
           ) ; end abs
           (core-intmap-max-imbalance (core-intmap-node-left im
                                      ) ; end core-intmap-node-left
           ) ; end core-intmap-max-imbalance
           (core-intmap-max-imbalance (core-intmap-node-right im
                                      ) ; end core-intmap-node-right
           ) ; end core-intmap-max-imbalance
      ) ; end max
  ) ; end if
) ; end define

(define (core-intmap-record-equal? im other recur
        ) ; end core-intmap-record-equal?
  (and (core-intmap? other
       ) ; end core-intmap?
       (= (core-intmap-size im) (core-intmap-size other
                                ) ; end core-intmap-size
       ) ; end =
       (recur (core-intmap-range->list im #f #f #t #f
              ) ; end core-intmap-range->list
              (core-intmap-range->list other #f #f #t #f
              ) ; end core-intmap-range->list
       ) ; end recur
  ) ; end and
) ; end define

(define (core-intmap-record-hash-code im recur
        ) ; end core-intmap-record-hash-code
  (recur (core-intmap-range->list im #f #f #t #f
         ) ; end core-intmap-range->list
  ) ; end recur
) ; end define

(define (core-intmap-record-secondary-hash-code im recur
        ) ; end core-intmap-record-secondary-hash-code
  (recur (core-intmap-range->list im #f #f #t #f
         ) ; end core-intmap-range->list
  ) ; end recur
) ; end define

(define core-intmap-record-equal+hash
  (list core-intmap-record-equal?
        core-intmap-record-hash-code
        core-intmap-record-secondary-hash-code
  ) ; end list
) ; end define

(define (set-core-intmap-record-properties!
        ) ; end set-core-intmap-record-properties!
  (define (install! rtd
          ) ; end install!
    (struct-property-set! prop:equal+hash rtd core-intmap-record-equal+hash
    ) ; end struct-property-set!
  ) ; end define
  (install! (record-type-descriptor core-intmap-empty-record
            ) ; end record-type-descriptor
  ) ; end install!
  (install! (record-type-descriptor core-intmap-node
            ) ; end record-type-descriptor
  ) ; end install!
) ; end define

(define (core-intmap-install-struct-property! prop value
        ) ; end core-intmap-install-struct-property!
  (define (install! rtd
          ) ; end install!
    (unless (struct-property-ref prop rtd #f
            ) ; end struct-property-ref
      (struct-property-set! prop rtd value
      ) ; end struct-property-set!
    ) ; end unless
  ) ; end define
  (install! (record-type-descriptor core-intmap-empty-record
            ) ; end record-type-descriptor
  ) ; end install!
  (install! (record-type-descriptor core-intmap-node
            ) ; end record-type-descriptor
  ) ; end install!
  (void
  ) ; end void
) ; end define

(define (core-intmap-shape-stats im
        ) ; end core-intmap-shape-stats
  (let* ([im (core-check-intmap 'core-intmap-shape-stats im
             ) ; end core-check-intmap
         ] ; end im
         [h (make-hasheq
            ) ; end make-hasheq
         ] ; end h
        ) ; end form
    (hash-set! h 'backend 'core
    ) ; end hash-set!
    (hash-set! h 'count (core-intmap-size im
                        ) ; end core-intmap-size
    ) ; end hash-set!
    (hash-set! h 'height (core-intmap-height im
                         ) ; end core-intmap-height
    ) ; end hash-set!
    (hash-set! h 'max-imbalance (core-intmap-max-imbalance im
                                ) ; end core-intmap-max-imbalance
    ) ; end hash-set!
    h
  ) ; end let*
) ; end define
