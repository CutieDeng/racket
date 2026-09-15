;; ===== p1.engine-suppl.ss: additions lost to /tmp cleanup, rebuilt from
;; session transcript fragments (2026-09-14). Load immediately AFTER
;; p1.engine.ss. Contains: trunc, fmt-val, children/labeled,
;; find-leak-paths (tail re-written, semantics preserved).
;; NOTE: the rescued p1.engine.ss lacks the ftype-carrier crash-derive
;; branch; the standing rule is installed explicitly by the A driver, so
;; only the helper predicate form is needed at rule-install time.

(define (trunc s n)
  (if (and (string? s) (fx> (string-length s) n))
      (substring s 0 n)
      s))

(define (fmt-val v n)
  (trunc (try (lambda () (c-fmt "~s" v)) "<unprintable>") n))

(define (children/labeled obj)
  (cond
    [(procedure? obj)
     (cond
       [($cont? obj) '()]
       [(safe-clen obj)
        => (lambda (n)
             (let loop ([i 0] [acc '()])
               (if (fx>= i n) (reverse acc)
                   (loop (fx+ i 1)
                         (cons (cons (string->symbol (c-fmt "fv~a" i)) ($cref obj i)) acc)))))]
       [else '()])]
    [(hashtable? obj)
     (let ([ks (c-htkeys obj)])
       (let loop ([i 0] [acc '()])
         (if (fx>= i (vector-length ks)) acc
             (let ([k (vector-ref ks i)])
               (loop (fx+ i 1)
                     (cons (cons (string->symbol (c-fmt "hkey<~a>" (trunc (c-fmt "~s" k) 24))) k)
                           (cons (cons (string->symbol (c-fmt "hval<~a>" (trunc (c-fmt "~s" k) 24)))
                                       (c-htref obj k #f))
                             acc)))))))]
    [($rec? obj)
     (let ([n (rtd-total-fields ($rtd obj))])
       (let loop ([i 0] [acc '()])
         (if (fx>= i n) (reverse acc)
             (loop (fx+ i 1)
                   (cons (cons (string->symbol (c-fmt "f~a" i))
                               (try (lambda () ($rref obj i)) 'UNREADABLE))
                         acc)))))]
    [(pair? obj) (list (cons 'car (car obj)) (cons 'cdr (cdr obj)))]
    [($stvec? obj)
     (let ([n ($stlen obj)])
       (let loop ([i 0] [acc '()])
         (if (fx>= i n) (reverse acc)
             (loop (fx+ i 1) (cons (cons (string->symbol (c-fmt "st~a" i))
                                         (try (lambda () ($stref obj i)) 'UNREADABLE))
                                   acc)))))]
    [(box? obj) (list (cons 'unbox (unbox obj)))]
    [(vector? obj)
     (let ([n (vector-length obj)])
       (let loop ([i 0] [acc '()])
         (if (fx>= i n) (reverse acc)
             (loop (fx+ i 1) (cons (cons (string->symbol (c-fmt "v~a" i)) (vector-ref obj i)) acc)))))]
    [else '()]))


(define (find-leak-paths root wanted-cats o cap)
  (define visited (make-eq-hashtable))
  (define parent (make-eq-hashtable))   ; obj -> (parent . edge)
  (define remaining wanted-cats)
  (define qf (list root)) (define qb '())
  (define nodes 0)
  (define (deq!) (when (null? qf) (set! qf (reverse qb)) (set! qb '()))
    (let ([x (car qf)]) (set! qf (cdr qf)) x))
  (define (path-of obj)
    (let loop ([o* obj] [acc '()] [g 0])
      (let ([p (eq-hashtable-ref parent o* #f)])
        (if (or (not p) (> g 100)) acc
            (loop (car p) (cons (c-fmt "~a[.~a]" (obj-category (car p)) (cdr p)) acc) (fx+ g 1))))))
  (eq-hashtable-set! visited root #t)
  (let bfs ()
    (unless (or (and (null? qf) (null? qb)) (null? remaining) (fx>= nodes cap))
      (let ([obj (deq!)])
        (set! nodes (fx+ nodes 1))
        (let ([cat (obj-category obj)])
          (when (memq cat remaining)
            (set! remaining (remq cat remaining))
            (o (c-fmt "  LEAK ~a reached via:" cat))
            (for-each (lambda (s) (o "      " s)) (path-of obj))
            (o (c-fmt "      => ~a" (obj-brief obj)))))
        (unless (or ($code? obj) (eq-hashtable-ref forced-ht obj #f) (rule-tag obj))
          (for-each (lambda (ec)
                      (let ([child (cdr ec)])
                        (when (and (not (eq? child 'UNREADABLE)) (heapish? child)
                                   (not (eq-hashtable-ref visited child #f)))
                          (eq-hashtable-set! visited child #t)
                          (eq-hashtable-set! parent child (cons obj (car ec)))
                          (set! qb (cons child qb)))))
                    (children/labeled obj))))
      (bfs)))
  (o (c-fmt "  (leak scan visited ~a nodes; unfound: ~a)" nodes remaining)))

;; ---------- stage C: pre-instantiation heap marking (segment-diff simulation) ----------
(define mark-ht (make-eq-hashtable))
(define (mark-scan! root cap)
  ;; mark every heapish object reachable from root (unpruned), honoring no ext rules
  (define stack (list root))
  (define nodes 0)
  (eq-hashtable-set! mark-ht root #t)
  (let loop ()
    (unless (or (null? stack) (fx>= nodes cap))
      (let ([obj (car stack)])
        (set! stack (cdr stack))
        (set! nodes (fx+ nodes 1))
        (for-each (lambda (child)
                    (when (and (not (eq? child 'UNREADABLE)) (heapish? child)
                               (not (eq-hashtable-ref mark-ht child #f)))
                      (eq-hashtable-set! mark-ht child #t)
                      (set! stack (cons child stack))))
                  (children obj #f)))
      (loop)))
  nodes)

