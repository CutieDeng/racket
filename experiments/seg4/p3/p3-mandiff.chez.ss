;; ===== manifest comparator (Chez side) =====
;; Reads two seg4z-externals.manifest files and characterizes the difference:
;;  - same multiset, different order  => traversal-order nondeterminism
;;  - different multisets             => content nondeterminism (GC/weak/etc.)

(define (mandiff-fmt-entry e n)
  (try (lambda () (trunc (c-fmt "~s" e) n)) "<unprintable>"))

(define (mandiff-run! path1 path2)
  (define (o . xs) (for-each display xs) (newline))
  (let* ([m1 (p3-fasl-from-file path1)]
         [m2 (p3-fasl-from-file path2)])
    (o "top-level slots: " (vector-length m1) " / " (vector-length m2))
    (let lp ([i 0])
      (when (fx< i (fxmin (vector-length m1) 3))
        (o "  slot " i ": "
           (mandiff-fmt-entry (vector-ref m1 i) 80) "  |  "
           (mandiff-fmt-entry (vector-ref m2 i) 80))
        (lp (fx+ i 1))))
    (let* ([v1 (vector-ref m1 3)]
           [v2 (vector-ref m2 3)]
           [n1 (vector-length v1)]
           [n2 (vector-length v2)])
      (o "entries: " n1 " / " n2 "  (delta " (- n2 n1) ")")
      ;; per-tag counts
      (let ([t1 (make-hashtable equal-hash equal?)]
            [t2 (make-hashtable equal-hash equal?)])
        (let cnt ([i 0])
          (when (fx< i n1)
            (hashtable-update! t1 (vector-ref (vector-ref v1 i) 0)
                               (lambda (v) (fx+ v 1)) 0)
            (cnt (fx+ i 1))))
        (let cnt ([i 0])
          (when (fx< i n2)
            (hashtable-update! t2 (vector-ref (vector-ref v2 i) 0)
                               (lambda (v) (fx+ v 1)) 0)
            (cnt (fx+ i 1))))
        (o "per-tag counts (tag n1 n2 delta):")
        (let ([keys (vector->list (hashtable-keys t1))])
          (for-each
           (lambda (k)
             (let ([a (hashtable-ref t1 k 0)] [b (hashtable-ref t2 k 0)])
               (o "  " k " " a " " b (if (fx= a b) "" "   <== DIFF"))))
           (sort (lambda (a b) (string<? (c-fmt "~a" a) (c-fmt "~a" b))) keys))
          ;; tags only in t2
          (for-each
           (lambda (k)
             (unless (memq k keys)
               (o "  " k " 0 " (hashtable-ref t2 k 0) "   <== ONLY-IN-2")))
           (vector->list (hashtable-keys t2)))))
      ;; first differing index (printed form as identity proxy)
      (let ([firstdiff
             (let fd ([i 0])
               (cond
                 [(fx>= i (fxmin n1 n2)) (and (not (fx= n1 n2)) (fxmin n1 n2))]
                 [(string=? (mandiff-fmt-entry (vector-ref v1 i) 100000)
                            (mandiff-fmt-entry (vector-ref v2 i) 100000))
                  (fd (fx+ i 1))]
                 [else i]))])
        (if (not firstdiff)
            (o "prefix identical over full common length")
            (begin
              (o "first differing index: " firstdiff)
              (let ctx ([j (fxmax 0 (fx- firstdiff 1))])
                (when (fx<= j (fxmin (fx+ firstdiff 2) (fx- (fxmin n1 n2) 1)))
                  (o "  [" j "] 1: " (mandiff-fmt-entry (vector-ref v1 j) 140))
                  (o "  [" j "] 2: " (mandiff-fmt-entry (vector-ref v2 j) 140))
                  (ctx (fx+ j 1)))))))
      ;; multiset difference via printed-form counting
      (let ([bag (make-hashtable string-hash string=?)])
        (let add ([i 0])
          (when (fx< i n1)
            (hashtable-update! bag (mandiff-fmt-entry (vector-ref v1 i) 100000)
                               (lambda (v) (fx+ v 1)) 0)
            (add (fx+ i 1))))
        (let sub ([i 0])
          (when (fx< i n2)
            (hashtable-update! bag (mandiff-fmt-entry (vector-ref v2 i) 100000)
                               (lambda (v) (fx- v 1)) 0)
            (sub (fx+ i 1))))
        (let-values ([(ks vs) (hashtable-entries bag)])
          (let ([only1 '()] [only2 '()])
            (let scan ([i (fx- (vector-length ks) 1)])
              (when (fx>= i 0)
                (let ([d (vector-ref vs i)])
                  (cond
                    [(fx> d 0) (set! only1 (cons (cons (vector-ref ks i) d) only1))]
                    [(fx< d 0) (set! only2 (cons (cons (vector-ref ks i) (fx- 0 d)) only2))]))
                (scan (fx- i 1))))
            (o "multiset: only-in-1 distinct=" (length only1)
               "  only-in-2 distinct=" (length only2))
            (let ([show (lambda (label l)
                          (let sh ([l l] [n 0])
                            (when (and (pair? l) (fx< n 12))
                              (o "  " label " x" (cdar l) ": "
                                 (trunc (caar l) 160))
                              (sh (cdr l) (fx+ n 1)))))])
              (show "ONLY-1" only1)
              (show "ONLY-2" only2))
            (when (and (null? only1) (null? only2))
              (o "VERDICT: identical multisets => pure ORDERING nondeterminism"))
            (when (or (pair? only1) (pair? only2))
              (o "VERDICT: content differs => real CONTENT nondeterminism"))))))))
