#lang racket/base

(require (prefix-in raw: "private/pvector-runtime-adapter.rkt")
         "private/serialize-structs.rkt"
         (only-in "private/for.rkt" prop:stream)
         racket/hash-code)

(provide pvector?
         pvector-empty
         pvector-empty?
         pvector
         make-pvector
         list->pvector
         pvector->list
         vector->pvector
         pvector->vector
         sequence->pvector
         pvector-length
         pvector-ref
         pvector-set
         pvector-first
         pvector-last
         pvector-cons-left
         pvector-cons-right
         pvector-pop-left
         pvector-pop-right
         pvector-append
         pvector-insert
         pvector-delete
         pvector-take
         pvector-drop
         pvector-take-right
         pvector-drop-right
         pvector-subvector
         pvector-split
         pvector-split-at
         in-pvector
         in-pvector-reverse
         for/pvector
         for*/pvector)

(struct pvector-wrapper (tree)
  #:sealed
  #:property prop:custom-write
  (lambda (pv port mode) (pvector-print pv port mode))
  #:property prop:equal+hash
  (list (lambda (pv other recur) (pvector-equal? pv other recur))
        (lambda (pv recur) (pvector-hash-code pv recur))
        (lambda (pv recur) (pvector-secondary-hash-code pv recur)))
  #:property prop:sequence
  (lambda (pv) (in-pvector pv))
  #:property prop:stream
  (vector
   (lambda (pv) (pvector-empty? pv))
   (lambda (pv) (pvector-first pv))
   (lambda (pv)
     (define-values (_ rest) (pvector-pop-left pv))
     rest))
  #:property prop:serializable
  (make-serialize-info
   (lambda (pv) (vector (pvector->vector pv)))
   (cons 'deserialize-pvector
         (module-path-index-join '(submod "." deserialize)
                                 (variable-reference->module-path-index
                                  (#%variable-reference))))
   #f
   (or (current-load-relative-directory)
       (current-directory))))

(module+ deserialize
  (provide deserialize-pvector)
  (define deserialize-pvector
    (make-deserialize-info
     (lambda (vec)
       (if (vector? vec)
           (vector->pvector vec)
           (error 'pvector "invalid deserialization")))
     (lambda () (error "should not get here; cycles not supported"))))
  (module declare-preserve-for-embedding racket/kernel))

(define empty-pvector
  (pvector-wrapper (raw:pvector-empty)))

(define pvector? pvector-wrapper?)

(define (wrap tree)
  (if (raw:pvector-empty? tree)
      empty-pvector
      (pvector-wrapper tree)))

(define (check-pvector who v)
  (unless (pvector-wrapper? v)
    (raise-argument-error who "pvector?" v))
  v)

(define (unwrap who v)
  (pvector-wrapper-tree (check-pvector who v)))

(define (check-nonnegative-integer who n)
  (unless (exact-nonnegative-integer? n)
    (raise-argument-error who "exact-nonnegative-integer?" n))
  n)

(define (checked-length who pv)
  (raw:pvector-length (unwrap who pv)))

(define (check-index who pv index)
  (check-nonnegative-integer who index)
  (define len (checked-length who pv))
  (when (>= index len)
    (raise-range-error who "pvector" "" index pv 0 (sub1 len)))
  index)

(define (check-end-index who pv index)
  (check-nonnegative-integer who index)
  (define len (checked-length who pv))
  (when (> index len)
    (raise-range-error who "pvector" "" index pv 0 len))
  index)

(define (check-subrange who pv start end)
  (check-end-index who pv start)
  (check-end-index who pv end)
  (when (> start end)
    (raise-arguments-error who
                           "starting index is greater than ending index"
                           "starting index" start
                           "ending index" end
                           "pvector" pv))
  (values start end))

(define (check-nonempty who pv)
  (define tree (unwrap who pv))
  (when (raw:pvector-empty? tree)
    (raise-arguments-error who "pvector is empty" "pvector" pv))
  tree)

(define (pvector-empty)
  empty-pvector)

(define (pvector-empty? v)
  (and (pvector-wrapper? v)
       (raw:pvector-empty? (pvector-wrapper-tree v))))

(define (pvector . elems)
  (list->pvector elems))

(define (make-pvector n [v #f])
  (check-nonnegative-integer 'make-pvector n)
  (wrap (raw:vector->pvector (make-vector n v))))

(define (list->pvector lst)
  (unless (list? lst)
    (raise-argument-error 'list->pvector "list?" lst))
  (wrap (raw:list->pvector lst)))

(define (pvector->list pv)
  (raw:pvector->list (unwrap 'pvector->list pv)))

(define (vector->pvector vec)
  (unless (vector? vec)
    (raise-argument-error 'vector->pvector "vector?" vec))
  (wrap (raw:vector->pvector vec)))

(define (pvector->vector pv)
  (raw:pvector->vector (unwrap 'pvector->vector pv)))

(define (sequence->pvector seq)
  (cond
    [(pvector-wrapper? seq) seq]
    [(list? seq) (list->pvector seq)]
    [(vector? seq) (vector->pvector seq)]
    [(sequence? seq)
     (for/fold ([pv empty-pvector])
               ([elem seq])
       (pvector-cons-right pv elem))]
    [else
     (raise-argument-error 'sequence->pvector "sequence?" seq)]))

(define (pvector-length pv)
  (checked-length 'pvector-length pv))

(define (pvector-ref pv index)
  (check-index 'pvector-ref pv index)
  (raw:pvector-ref (unwrap 'pvector-ref pv) index))

(define (pvector-set pv index value)
  (check-index 'pvector-set pv index)
  (wrap (raw:pvector-set (unwrap 'pvector-set pv) index value)))

(define (pvector-first pv)
  (raw:pvector-view-left (check-nonempty 'pvector-first pv)))

(define (pvector-last pv)
  (raw:pvector-view-right (check-nonempty 'pvector-last pv)))

(define (pvector-cons-left pv value)
  (wrap (raw:pvector-cons-left (unwrap 'pvector-cons-left pv) value)))

(define (pvector-cons-right pv value)
  (wrap (raw:pvector-cons-right (unwrap 'pvector-cons-right pv) value)))

(define (pvector-pop-left pv)
  (define-values (value rest)
    (raw:pvector-pop-left (check-nonempty 'pvector-pop-left pv)))
  (values value (wrap rest)))

(define (pvector-pop-right pv)
  (define-values (value rest)
    (raw:pvector-pop-right (check-nonempty 'pvector-pop-right pv)))
  (values value (wrap rest)))

(define (pvector-append pv0 pv1)
  (wrap (raw:pvector-append (unwrap 'pvector-append pv0)
                            (unwrap 'pvector-append pv1))))

(define (pvector-insert pv index value)
  (check-end-index 'pvector-insert pv index)
  (wrap (raw:pvector-insert (unwrap 'pvector-insert pv) index value)))

(define (pvector-delete pv index)
  (check-index 'pvector-delete pv index)
  (define-values (rest value)
    (raw:pvector-delete (unwrap 'pvector-delete pv) index))
  (values (wrap rest) value))

(define (pvector-take pv pos)
  (check-end-index 'pvector-take pv pos)
  (wrap (raw:pvector-take (unwrap 'pvector-take pv) pos)))

(define (pvector-drop pv pos)
  (check-end-index 'pvector-drop pv pos)
  (wrap (raw:pvector-drop (unwrap 'pvector-drop pv) pos)))

(define (pvector-take-right pv pos)
  (check-end-index 'pvector-take-right pv pos)
  (wrap (raw:pvector-take-right (unwrap 'pvector-take-right pv) pos)))

(define (pvector-drop-right pv pos)
  (check-end-index 'pvector-drop-right pv pos)
  (wrap (raw:pvector-drop-right (unwrap 'pvector-drop-right pv) pos)))

(define (pvector-subvector pv start [end (pvector-length pv)])
  (define-values (start* end*) (check-subrange 'pvector-subvector pv start end))
  (wrap (raw:pvector-copy (unwrap 'pvector-subvector pv) start* end*)))

(define (pvector-split pv index)
  (check-index 'pvector-split pv index)
  (define-values (left value right)
    (raw:pvector-split (unwrap 'pvector-split pv) index))
  (values (wrap left) value (wrap right)))

(define (pvector-split-at pv pos)
  (check-end-index 'pvector-split-at pv pos)
  (define-values (left right)
    (raw:pvector-split-at (unwrap 'pvector-split-at pv) pos))
  (values (wrap left) (wrap right)))

(define (in-pvector pv)
  (raw:in-pvector (unwrap 'in-pvector pv)))

(define (in-pvector-reverse pv)
  (raw:in-pvector-reverse (unwrap 'in-pvector-reverse pv)))

(module+ unsafe
  (provide unsafe-pvector-length
           unsafe-pvector-ref
           unsafe-pvector-set
           unsafe-pvector-first
           unsafe-pvector-last
           unsafe-pvector-cons-left
           unsafe-pvector-cons-right
           unsafe-pvector-pop-left
           unsafe-pvector-pop-right
           unsafe-pvector-append
           unsafe-pvector-insert
           unsafe-pvector-delete
           unsafe-pvector-take
           unsafe-pvector-drop
           unsafe-pvector-take-right
           unsafe-pvector-drop-right
           unsafe-pvector-subvector
           unsafe-pvector-split
           unsafe-pvector-split-at
           unsafe-in-pvector
           unsafe-in-pvector-reverse)

  (define (unsafe-tree pv)
    (pvector-wrapper-tree pv))

  (define (unsafe-pvector-length pv)
    (raw:pvector-length (unsafe-tree pv)))

  (define (unsafe-pvector-ref pv index)
    (raw:pvector-ref (unsafe-tree pv) index))

  (define (unsafe-pvector-set pv index value)
    (wrap (raw:pvector-set (unsafe-tree pv) index value)))

  (define (unsafe-pvector-first pv)
    (raw:pvector-view-left (unsafe-tree pv)))

  (define (unsafe-pvector-last pv)
    (raw:pvector-view-right (unsafe-tree pv)))

  (define (unsafe-pvector-cons-left pv value)
    (wrap (raw:pvector-cons-left (unsafe-tree pv) value)))

  (define (unsafe-pvector-cons-right pv value)
    (wrap (raw:pvector-cons-right (unsafe-tree pv) value)))

  (define (unsafe-pvector-pop-left pv)
    (define-values (value rest)
      (raw:pvector-pop-left (unsafe-tree pv)))
    (values value (wrap rest)))

  (define (unsafe-pvector-pop-right pv)
    (define-values (value rest)
      (raw:pvector-pop-right (unsafe-tree pv)))
    (values value (wrap rest)))

  (define (unsafe-pvector-append pv0 pv1)
    (wrap (raw:pvector-append (unsafe-tree pv0)
                              (unsafe-tree pv1))))

  (define (unsafe-pvector-insert pv index value)
    (wrap (raw:pvector-insert (unsafe-tree pv) index value)))

  (define (unsafe-pvector-delete pv index)
    (define-values (rest value)
      (raw:pvector-delete (unsafe-tree pv) index))
    (values (wrap rest) value))

  (define (unsafe-pvector-take pv pos)
    (wrap (raw:pvector-take (unsafe-tree pv) pos)))

  (define (unsafe-pvector-drop pv pos)
    (wrap (raw:pvector-drop (unsafe-tree pv) pos)))

  (define (unsafe-pvector-take-right pv pos)
    (wrap (raw:pvector-take-right (unsafe-tree pv) pos)))

  (define (unsafe-pvector-drop-right pv pos)
    (wrap (raw:pvector-drop-right (unsafe-tree pv) pos)))

  (define (unsafe-pvector-subvector pv start end)
    (wrap (raw:pvector-copy (unsafe-tree pv) start end)))

  (define (unsafe-pvector-split pv index)
    (define-values (left value right)
      (raw:pvector-split (unsafe-tree pv) index))
    (values (wrap left) value (wrap right)))

  (define (unsafe-pvector-split-at pv pos)
    (define-values (left right)
      (raw:pvector-split-at (unsafe-tree pv) pos))
    (values (wrap left) (wrap right)))

  (define (unsafe-in-pvector pv)
    (raw:in-pvector (unsafe-tree pv)))

  (define (unsafe-in-pvector-reverse pv)
    (raw:in-pvector-reverse (unsafe-tree pv))))

(define-syntax-rule (for/pvector (clause ...) body ...)
  (for/fold ([pv (pvector-empty)])
            (clause ...)
    (pvector-cons-right pv (let () body ...))))

(define-syntax-rule (for*/pvector (clause ...) body ...)
  (for*/fold ([pv (pvector-empty)])
             (clause ...)
    (pvector-cons-right pv (let () body ...))))

(define (pvector-print pv port mode)
  (display "(pvector" port)
  (for ([elem (in-pvector pv)])
    (display " " port)
    (case mode
      [(#t) (write elem port)]
      [(#f) (display elem port)]
      [else (print elem port)]))
  (display ")" port))

(define (pvector-equal? pv other recur)
  (and (pvector-wrapper? other)
       (= (pvector-length pv) (pvector-length other))
       (for/and ([a (in-pvector pv)]
                 [b (in-pvector other)])
         (recur a b))))

(define (pvector-hash-code pv recur)
  (for/fold ([hc (hash-code-combine 16381 (pvector-length pv))])
            ([elem (in-pvector pv)])
    (hash-code-combine hc (recur elem))))

(define (pvector-secondary-hash-code pv recur)
  (for/fold ([hc (hash-code-combine 32749 (pvector-length pv))])
            ([elem (in-pvector pv)])
    (hash-code-combine hc (recur elem))))
