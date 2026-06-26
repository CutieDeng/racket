#lang racket/base

(require racket/fixnum
) ; end require

(provide
 intbits?
 intbits-finite?
 intbits-empty
 intbits-empty?
 intbits-ref
 intbits-set
 intbits-clear
 intbits-toggle
 intbits-complement
 intbits-union
 intbits-intersect
 intbits-subtract
 intbits-xor
 intbits-intersects?
 intbits-disjoint?
 intbits-subset?
 intbits-count
 intbits-count-range
 intbits-width
 intbits-first
 intbits-last
 intbits-next
 intbits-prev
 intbits-rank
 intbits-select
 intbits-range-mask
 intbits-field
 intbits-set-range
 intbits-clear-range
 intbits-toggle-range
 intbits-replace-field
 intbits-for-each
 intbits-for-each/range
 intbits-fold
 intbits-fold/range
 intbits->list
 intbits->list/range
 list->intbits
 intbits->string
 intbits->string/range
 string->intbits
 in-intbits
 in-intbits-range
) ; end provide

(define intbits-empty 0
) ; end define

(define chunk-bits (integer-length (most-positive-fixnum
                                    ) ; end most-positive-fixnum
                   ) ; end integer-length
) ; end define
(define chunk-mask (sub1 (arithmetic-shift 1 chunk-bits
                          ) ; end arithmetic-shift
                   ) ; end sub1
) ; end define

(define (intbits? v
        ) ; end intbits?
  (exact-integer? v
  ) ; end exact-integer?
) ; end define

(define (intbits-finite? v
        ) ; end intbits-finite?
  (exact-nonnegative-integer? v
  ) ; end exact-nonnegative-integer?
) ; end define

(define (intbits-empty? v
        ) ; end intbits-empty?
  (and (exact-integer? v
       ) ; end exact-integer?
       (zero? v
       ) ; end zero?
  ) ; end and
) ; end define

(define (check-intbits who bits
        ) ; end check-intbits
  (unless (exact-integer? bits
          ) ; end exact-integer?
    (raise-argument-error who "exact-integer?" bits
    ) ; end raise-argument-error
  ) ; end unless
  bits
) ; end define

(define (check-finite-intbits who bits
        ) ; end check-finite-intbits
  (unless (exact-nonnegative-integer? bits
          ) ; end exact-nonnegative-integer?
    (raise-argument-error who "exact-nonnegative-integer?" bits
    ) ; end raise-argument-error
  ) ; end unless
  bits
) ; end define

(define (check-index who pos
        ) ; end check-index
  (unless (exact-nonnegative-integer? pos
          ) ; end exact-nonnegative-integer?
    (raise-argument-error who "exact-nonnegative-integer?" pos
    ) ; end raise-argument-error
  ) ; end unless
  pos
) ; end define

(define (check-range who lo hi
        ) ; end check-range
  (check-index who lo
  ) ; end check-index
  (check-index who hi
  ) ; end check-index
  (when (< hi lo
        ) ; end <
    (raise-arguments-error who
                           "ending index is smaller than starting index"
                           "starting index" lo
                           "ending index" hi
    ) ; end raise-arguments-error
  ) ; end when
  (values lo hi
  ) ; end values
) ; end define

(define (check-procedure-arity who proc arity
        ) ; end check-procedure-arity
  (unless (and (procedure? proc
               ) ; end procedure?
               (procedure-arity-includes? proc arity
               ) ; end procedure-arity-includes?
          ) ; end and
    (raise-argument-error who
                          (format "(procedure-arity-includes/c ~a)" arity
                          ) ; end format
                          proc
    ) ; end raise-argument-error
  ) ; end unless
  proc
) ; end define

(define (bit-at pos
        ) ; end bit-at
  (arithmetic-shift 1 pos
  ) ; end arithmetic-shift
) ; end define

(define (finite-bit-count bits
        ) ; end finite-bit-count
  (let loop ([bits bits] [count 0
                         ] ; end count
            ) ; end form
    (if (zero? bits
        ) ; end zero?
        count
        (loop (arithmetic-shift bits (- chunk-bits
                                      ) ; end -
              ) ; end arithmetic-shift
              (+ count
                 (fxpopcount (bitwise-and bits chunk-mask
                             ) ; end bitwise-and
                 ) ; end fxpopcount
              ) ; end +
        ) ; end loop
    ) ; end if
  ) ; end let
) ; end define

(define (intbits-ref bits pos
        ) ; end intbits-ref
  (check-intbits 'intbits-ref bits
  ) ; end check-intbits
  (check-index 'intbits-ref pos
  ) ; end check-index
  (bitwise-bit-set? bits pos
  ) ; end bitwise-bit-set?
) ; end define

(define (intbits-set bits pos [value #t]
        ) ; end intbits-set
  (check-intbits 'intbits-set bits
  ) ; end check-intbits
  (check-index 'intbits-set pos
  ) ; end check-index
  (unless (boolean? value
          ) ; end boolean?
    (raise-argument-error 'intbits-set "boolean?" value
    ) ; end raise-argument-error
  ) ; end unless
  (if value
      (bitwise-ior bits (bit-at pos
                       ) ; end bit-at
      ) ; end bitwise-ior
      (intbits-clear bits pos
      ) ; end intbits-clear
  ) ; end if
) ; end define

(define (intbits-clear bits pos
        ) ; end intbits-clear
  (check-intbits 'intbits-clear bits
  ) ; end check-intbits
  (check-index 'intbits-clear pos
  ) ; end check-index
  (bitwise-and bits (bitwise-not (bit-at pos
                              ) ; end bit-at
                    ) ; end bitwise-not
  ) ; end bitwise-and
) ; end define

(define (intbits-toggle bits pos
        ) ; end intbits-toggle
  (check-intbits 'intbits-toggle bits
  ) ; end check-intbits
  (check-index 'intbits-toggle pos
  ) ; end check-index
  (bitwise-xor bits (bit-at pos
                    ) ; end bit-at
  ) ; end bitwise-xor
) ; end define

(define (intbits-complement bits
        ) ; end intbits-complement
  (check-intbits 'intbits-complement bits
  ) ; end check-intbits
  (bitwise-not bits
  ) ; end bitwise-not
) ; end define

(define (intbits-union . bitss
        ) ; end intbits-union
  (for/fold ([acc 0
              ] ; end acc
             ) ; end form
            ([bits (in-list bitss
                    ) ; end in-list
             ] ; end bits
            ) ; end form
    (bitwise-ior acc (check-intbits 'intbits-union bits
                     ) ; end check-intbits
    ) ; end bitwise-ior
  ) ; end for/fold
) ; end define

(define (intbits-intersect . bitss
        ) ; end intbits-intersect
  (for/fold ([acc -1
              ] ; end acc
             ) ; end form
            ([bits (in-list bitss
                    ) ; end in-list
             ] ; end bits
            ) ; end form
    (bitwise-and acc (check-intbits 'intbits-intersect bits
                     ) ; end check-intbits
    ) ; end bitwise-and
  ) ; end for/fold
) ; end define

(define (intbits-subtract bits . remove-bitss
        ) ; end intbits-subtract
  (check-intbits 'intbits-subtract bits
  ) ; end check-intbits
  (for/fold ([acc bits
              ] ; end acc
             ) ; end form
            ([remove-bits (in-list remove-bitss
                           ) ; end in-list
             ] ; end remove-bits
            ) ; end form
    (bitwise-and acc
                 (bitwise-not (check-intbits 'intbits-subtract remove-bits
                              ) ; end check-intbits
                 ) ; end bitwise-not
    ) ; end bitwise-and
  ) ; end for/fold
) ; end define

(define (intbits-xor . bitss
        ) ; end intbits-xor
  (for/fold ([acc 0
              ] ; end acc
             ) ; end form
            ([bits (in-list bitss
                    ) ; end in-list
             ] ; end bits
            ) ; end form
    (bitwise-xor acc (check-intbits 'intbits-xor bits
                     ) ; end check-intbits
    ) ; end bitwise-xor
  ) ; end for/fold
) ; end define

(define (intbits-intersects? a b
        ) ; end intbits-intersects?
  (not (intbits-disjoint? a b
       ) ; end intbits-disjoint?
  ) ; end not
) ; end define

(define (intbits-disjoint? a b
        ) ; end intbits-disjoint?
  (check-intbits 'intbits-disjoint? a
  ) ; end check-intbits
  (check-intbits 'intbits-disjoint? b
  ) ; end check-intbits
  (zero? (bitwise-and a b
         ) ; end bitwise-and
  ) ; end zero?
) ; end define

(define (intbits-subset? a b
        ) ; end intbits-subset?
  (check-intbits 'intbits-subset? a
  ) ; end check-intbits
  (check-intbits 'intbits-subset? b
  ) ; end check-intbits
  (zero? (bitwise-and a (bitwise-not b
                         ) ; end bitwise-not
         ) ; end bitwise-and
  ) ; end zero?
) ; end define

(define (intbits-count bits
        ) ; end intbits-count
  (finite-bit-count (check-finite-intbits 'intbits-count bits
                    ) ; end check-finite-intbits
  ) ; end finite-bit-count
) ; end define

(define (intbits-count-range bits lo hi
        ) ; end intbits-count-range
  (check-intbits 'intbits-count-range bits
  ) ; end check-intbits
  (check-range 'intbits-count-range lo hi
  ) ; end check-range
  (finite-bit-count (bitwise-bit-field bits lo hi
                    ) ; end bitwise-bit-field
  ) ; end finite-bit-count
) ; end define

(define (intbits-width bits
        ) ; end intbits-width
  (integer-length (check-finite-intbits 'intbits-width bits
                  ) ; end check-finite-intbits
  ) ; end integer-length
) ; end define

(define (intbits-first bits
        ) ; end intbits-first
  (check-intbits 'intbits-first bits
  ) ; end check-intbits
  (let ([pos (bitwise-first-bit-set bits
              ) ; end bitwise-first-bit-set
        ] ; end pos
       ) ; end form
    (and (not (= pos -1
              ) ; end =
         ) ; end not
         pos
    ) ; end and
  ) ; end let
) ; end define

(define (intbits-last bits
        ) ; end intbits-last
  (check-finite-intbits 'intbits-last bits
  ) ; end check-finite-intbits
  (and (not (zero? bits
            ) ; end zero?
       ) ; end not
       (sub1 (integer-length bits
             ) ; end integer-length
       ) ; end sub1
  ) ; end and
) ; end define

(define (intbits-next bits pos
        ) ; end intbits-next
  (check-intbits 'intbits-next bits
  ) ; end check-intbits
  (check-index 'intbits-next pos
  ) ; end check-index
  (let ([next (bitwise-first-bit-set (arithmetic-shift bits (- pos
                                                            ) ; end -
                                     ) ; end arithmetic-shift
              ) ; end bitwise-first-bit-set
        ] ; end next
       ) ; end form
    (and (not (= next -1
              ) ; end =
         ) ; end not
         (+ pos next
         ) ; end +
    ) ; end and
  ) ; end let
) ; end define

(define (intbits-prev bits pos
        ) ; end intbits-prev
  (check-intbits 'intbits-prev bits
  ) ; end check-intbits
  (check-index 'intbits-prev pos
  ) ; end check-index
  (let ([prefix (bitwise-bit-field bits 0 (add1 pos
                                           ) ; end add1
                ) ; end bitwise-bit-field
        ] ; end prefix
       ) ; end form
    (and (not (zero? prefix
              ) ; end zero?
         ) ; end not
         (sub1 (integer-length prefix
               ) ; end integer-length
         ) ; end sub1
    ) ; end and
  ) ; end let
) ; end define

(define (intbits-rank bits pos
        ) ; end intbits-rank
  (intbits-count-range bits 0 pos
  ) ; end intbits-count-range
) ; end define

(define (intbits-select bits index
        ) ; end intbits-select
  (check-intbits 'intbits-select bits
  ) ; end check-intbits
  (check-index 'intbits-select index
  ) ; end check-index
  (let loop ([pos (intbits-first bits
                   ) ; end intbits-first
             ] ; end pos
             [index index
                    ] ; end index
            ) ; end form
    (cond
      [(not pos) #f
      ] ; end clause
      [(zero? index) pos
      ] ; end clause
      [else
       (loop (intbits-next bits (add1 pos
                                ) ; end add1
             ) ; end intbits-next
             (sub1 index
             ) ; end sub1
       ) ; end loop
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (intbits-range-mask lo hi
        ) ; end intbits-range-mask
  (check-range 'intbits-range-mask lo hi
  ) ; end check-range
  (if (= lo hi
      ) ; end =
      0
      (arithmetic-shift (sub1 (arithmetic-shift 1 (- hi lo
                                                  ) ; end -
                                  ) ; end arithmetic-shift
                        ) ; end sub1
                        lo
      ) ; end arithmetic-shift
  ) ; end if
) ; end define

(define (intbits-field bits lo hi
        ) ; end intbits-field
  (check-intbits 'intbits-field bits
  ) ; end check-intbits
  (check-range 'intbits-field lo hi
  ) ; end check-range
  (bitwise-bit-field bits lo hi
  ) ; end bitwise-bit-field
) ; end define

(define (intbits-set-range bits lo hi
        ) ; end intbits-set-range
  (check-intbits 'intbits-set-range bits
  ) ; end check-intbits
  (bitwise-ior bits (intbits-range-mask lo hi
                    ) ; end intbits-range-mask
  ) ; end bitwise-ior
) ; end define

(define (intbits-clear-range bits lo hi
        ) ; end intbits-clear-range
  (check-intbits 'intbits-clear-range bits
  ) ; end check-intbits
  (bitwise-and bits (bitwise-not (intbits-range-mask lo hi
                              ) ; end intbits-range-mask
                    ) ; end bitwise-not
  ) ; end bitwise-and
) ; end define

(define (intbits-toggle-range bits lo hi
        ) ; end intbits-toggle-range
  (check-intbits 'intbits-toggle-range bits
  ) ; end check-intbits
  (bitwise-xor bits (intbits-range-mask lo hi
                    ) ; end intbits-range-mask
  ) ; end bitwise-xor
) ; end define

(define (intbits-replace-field bits lo hi field
        ) ; end intbits-replace-field
  (check-intbits 'intbits-replace-field bits
  ) ; end check-intbits
  (check-intbits 'intbits-replace-field field
  ) ; end check-intbits
  (check-range 'intbits-replace-field lo hi
  ) ; end check-range
  (let* ([width (- hi lo
                 ) ; end -
          ] ; end width
         [field* (bitwise-bit-field field 0 width
                 ) ; end bitwise-bit-field
          ] ; end field*
        ) ; end form
    (bitwise-ior (intbits-clear-range bits lo hi
                 ) ; end intbits-clear-range
                 (arithmetic-shift field* lo
                 ) ; end arithmetic-shift
    ) ; end bitwise-ior
  ) ; end let*
) ; end define

(define (intbits-for-each bits proc
        ) ; end intbits-for-each
  (check-finite-intbits 'intbits-for-each bits
  ) ; end check-finite-intbits
  (intbits-for-each/range bits 0 (intbits-width bits
                                ) ; end intbits-width
                          proc
  ) ; end intbits-for-each/range
) ; end define

(define (intbits-for-each/range bits lo hi proc
        ) ; end intbits-for-each/range
  (check-intbits 'intbits-for-each/range bits
  ) ; end check-intbits
  (check-range 'intbits-for-each/range lo hi
  ) ; end check-range
  (check-procedure-arity 'intbits-for-each/range proc 1
  ) ; end check-procedure-arity
  (let loop ([pos (range-first bits lo hi
                   ) ; end range-first
             ] ; end pos
            ) ; end form
    (when pos
      (proc pos
      ) ; end proc
      (loop (range-next bits hi pos
            ) ; end range-next
      ) ; end loop
    ) ; end when
  ) ; end let
  (void
  ) ; end void
) ; end define

(define (intbits-fold bits init proc
        ) ; end intbits-fold
  (check-finite-intbits 'intbits-fold bits
  ) ; end check-finite-intbits
  (intbits-fold/range bits 0 (intbits-width bits
                            ) ; end intbits-width
                      init
                      proc
  ) ; end intbits-fold/range
) ; end define

(define (intbits-fold/range bits lo hi init proc
        ) ; end intbits-fold/range
  (check-intbits 'intbits-fold/range bits
  ) ; end check-intbits
  (check-range 'intbits-fold/range lo hi
  ) ; end check-range
  (check-procedure-arity 'intbits-fold/range proc 2
  ) ; end check-procedure-arity
  (let loop ([acc init
              ] ; end acc
             [pos (range-first bits lo hi
                   ) ; end range-first
              ] ; end pos
            ) ; end form
    (if pos
        (loop (proc acc pos
              ) ; end proc
              (range-next bits hi pos
              ) ; end range-next
        ) ; end loop
        acc
    ) ; end if
  ) ; end let
) ; end define

(define (intbits->list bits
        ) ; end intbits->list
  (check-finite-intbits 'intbits->list bits
  ) ; end check-finite-intbits
  (for/list ([pos (in-intbits bits
                  ) ; end in-intbits
             ] ; end pos
            ) ; end form
    pos
  ) ; end for/list
) ; end define

(define (intbits->list/range bits lo hi
        ) ; end intbits->list/range
  (check-intbits 'intbits->list/range bits
  ) ; end check-intbits
  (for/list ([pos (in-intbits-range bits lo hi
                  ) ; end in-intbits-range
             ] ; end pos
            ) ; end form
    pos
  ) ; end for/list
) ; end define

(define (list->intbits positions
        ) ; end list->intbits
  (unless (list? positions
          ) ; end list?
    (raise-argument-error 'list->intbits "list?" positions
    ) ; end raise-argument-error
  ) ; end unless
  (for/fold ([bits 0
              ] ; end bits
             ) ; end form
            ([pos (in-list positions
                   ) ; end in-list
             ] ; end pos
            ) ; end form
    (check-index 'list->intbits pos
    ) ; end check-index
    (intbits-set bits pos
    ) ; end intbits-set
  ) ; end for/fold
) ; end define

(define (intbits->string bits
        ) ; end intbits->string
  (check-finite-intbits 'intbits->string bits
  ) ; end check-finite-intbits
  (intbits->string/range bits 0 (intbits-width bits
                              ) ; end intbits-width
  ) ; end intbits->string/range
) ; end define

(define (intbits->string/range bits lo hi
        ) ; end intbits->string/range
  (check-intbits 'intbits->string/range bits
  ) ; end check-intbits
  (check-range 'intbits->string/range lo hi
  ) ; end check-range
  (let* ([len (- hi lo
               ) ; end -
          ] ; end len
         [str (make-string len #\0
              ) ; end make-string
          ] ; end str
        ) ; end form
    (for ([i (in-range len
              ) ; end in-range
           ] ; end i
          ) ; end form
      (when (intbits-ref bits (+ lo i
                              ) ; end +
            ) ; end intbits-ref
        (string-set! str i #\1
        ) ; end string-set!
      ) ; end when
    ) ; end for
    str
  ) ; end let*
) ; end define

(define (string->intbits str
        ) ; end string->intbits
  (unless (string? str
          ) ; end string?
    (raise-argument-error 'string->intbits "string?" str
    ) ; end raise-argument-error
  ) ; end unless
  (for/fold ([bits 0
              ] ; end bits
             ) ; end form
            ([ch (in-string str
                 ) ; end in-string
             ] ; end ch
             [i (in-naturals
                ) ; end in-naturals
             ] ; end i
            ) ; end form
    (case ch
      [(#\0) bits
      ] ; end clause
      [(#\1) (intbits-set bits i
              ) ; end intbits-set
      ] ; end clause
      [else
       (raise-arguments-error 'string->intbits
                              "expected a string containing only 0 or 1"
                              "string" str
                              "index" i
                              "character" ch
       ) ; end raise-arguments-error
      ] ; end else
    ) ; end case
  ) ; end for/fold
) ; end define

(define (range-first bits lo hi
        ) ; end range-first
  (let ([pos (intbits-next bits lo
             ) ; end intbits-next
        ] ; end pos
       ) ; end form
    (and pos
         (< pos hi
         ) ; end <
         pos
    ) ; end and
  ) ; end let
) ; end define

(define (range-next bits hi pos
        ) ; end range-next
  (range-first bits (add1 pos
                    ) ; end add1
               hi
  ) ; end range-first
) ; end define

(define (in-intbits bits
        ) ; end in-intbits
  (check-finite-intbits 'in-intbits bits
  ) ; end check-finite-intbits
  (in-intbits-range bits 0 (intbits-width bits
                        ) ; end intbits-width
  ) ; end in-intbits-range
) ; end define

(define (in-intbits-range bits lo hi
        ) ; end in-intbits-range
  (check-intbits 'in-intbits-range bits
  ) ; end check-intbits
  (check-range 'in-intbits-range lo hi
  ) ; end check-range
  (make-do-sequence
   (lambda (
           ) ; end form
     (values
      values
      (lambda (pos
               ) ; end pos
        (range-next bits hi pos
        ) ; end range-next
      ) ; end lambda
      (range-first bits lo hi
      ) ; end range-first
      exact-nonnegative-integer?
      #f
      #f
     ) ; end values
   ) ; end lambda
  ) ; end make-do-sequence
) ; end define
