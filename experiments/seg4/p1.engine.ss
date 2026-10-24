;; ===== P1 engine: staged whole-graph fasl roundtrip machinery (pure Chez, pre-import) =====

(define c-lt (lambda (a b) (< a b)))
(define c-cpu cpu-time)
(define c-bvlen bytevector-length)
(define c-htmut? hashtable-mutable?)
(define c-eqweak? eq-hashtable-weak?)
(define c-eqeph? eq-hashtable-ephemeron?)
(define c-htcontains? hashtable-contains?)
(define c-htref hashtable-ref)
(define c-htkeys hashtable-keys)
(define ($stmask x) (try (lambda () (#%$stencil-vector-mask x)) #f))

(define (trunc s n)   ; truncate a string for logs
  (let ([s (if (string? s) s (c-fmt "~a" s))])
    (if (> (string-length s) n) (string-append (substring s 0 n) "...") s)))

(define (fmt-val x n)  ; safe truncated ~s of any value
  (try (lambda () (trunc (c-fmt "~s" x) n)) "<unprintable>"))

(define (cond->string e)
  (try (lambda ()
         (let ([sp (c-oos)])
           (c-dispcond e sp)
           (c-gos sp)))
       "<condition unprintable>"))

(define (first-irritant e)
  (try (lambda ()
         (if (and (condition? e) (irritants-condition? e))
             (let ([ir (condition-irritants e)])
               (if (pair? ir) (car ir) 'NO-IRRITANT))
             'NO-IRRITANT))
       'NO-IRRITANT))

;; short description of an object for logs
(define (obj-brief x)
  (try (lambda ()
         (let ([cat (obj-category x)])
           (case cat
             [(closure opaque-procedure) (c-fmt "~a name=~a clen=~a" cat ($cname x) (safe-clen x))]
             [(code) (c-fmt "code name=~a" (code-name x))]
             [(string) (c-fmt "string ~a" (fmt-val x 40))]
             [(symbol gensym number char boolean) (c-fmt "~a ~a" cat (fmt-val x 40))]
             [else (c-fmt "~a" cat)])))
       "<unprintable>"))

;; ---------- externals machinery ----------
;; rules: list of (tag . pred); forced: eq-ht obj -> tag
(define ext-rules '())
(define forced-ht (make-eq-hashtable))
(define collected '())   ; per-attempt (obj . tag), reversed
(define n-collected 0)

(define (reset-ext!)
  (set! ext-rules '())
  (set! forced-ht (make-eq-hashtable)))

(define (add-rule! tag pred)
  (set! ext-rules (append ext-rules (list (cons tag pred)))))

(define (rule-tag v)
  (let loop ([rs ext-rules])
    (cond
      [(null? rs) #f]
      [(try (lambda () ((cdar rs) v)) #f) (caar rs)]
      [else (loop (cdr rs))])))

(define (note! tag v)
  (set! collected (cons (cons v tag) collected))
  (set! n-collected (fx+ n-collected 1)))

(define (make-ext-pred)
  (lambda (v)
    (cond
      [($code? v) (note! 'code v) #t]
      [(eq-hashtable-ref forced-ht v #f)
       => (lambda (tag) (note! tag v) #t)]
      [(rule-tag v) => (lambda (tag) (note! tag v) #t)]
      [else #f])))

;; ---------- pre-scan: category census of the graph fasl would traverse ----------
;; stops at objects the current ext machinery would claim (like bld does)
(define (prescan root cap)
  (define visited (make-eq-hashtable))
  (define cats (make-hashtable equal-hash equal?))
  (define ext-cats (make-hashtable equal-hash equal?))
  (define nodes 0)
  (define n-ext 0)
  (define truncated #f)
  (define stack (list root))
  (define (bump! t x) (hashtable-update! t x (lambda (v) (fx+ v 1)) 0))
  (eq-hashtable-set! visited root #t)
  (let loop ()
    (unless (null? stack)
      (let ([obj (car stack)])
        (set! stack (cdr stack))
        (set! nodes (fx+ nodes 1))
        (cond
          [(fx>= nodes cap) (set! truncated #t)]
          [else
           (let ([ext-tag (or (and ($code? obj) 'code)
                              (eq-hashtable-ref forced-ht obj #f)
                              (rule-tag obj))])
             (cond
               [ext-tag (bump! ext-cats ext-tag) (set! n-ext (fx+ n-ext 1))]
               [else
                (bump! cats (obj-category obj))
                (for-each (lambda (child)
                            (when (and (not (eq? child 'UNREADABLE)) (heapish? child)
                                       (not (eq-hashtable-ref visited child #f)))
                              (eq-hashtable-set! visited child #t)
                              (set! stack (cons child stack))))
                          (children obj #f))]))
           (loop)])))
    )
  (list nodes truncated cats ext-cats n-ext))

(define (dump-counts o t label)
  (o label)
  (let ([ks (vector->list (c-htkeys t))])
    (for-each (lambda (k) (o (c-fmt "    ~a : ~a" k (c-htref t k 0))))
              (c-sort (lambda (a b) (> (c-htref t a 0) (c-htref t b 0))) ks))))

;; ---------- one fasl-write attempt ----------
(define (attempt-write root)
  (set! collected '())
  (set! n-collected 0)
  (call/cc
   (lambda (k)
     (with-exception-handler
       (lambda (e) (k (list 'err e)))
       (lambda ()
         (let-values ([(op get) (c-obvop)])
           (c-faslw root op (make-ext-pred))
           (list 'ok (get) (reverse collected))))))))

;; ---------- crash-driven iteration ----------
;; returns (list 'ok bv exts hist) | (list 'fail reason hist)
(define (iterate-write root o max-iters)
  (let loop ([i 1] [hist '()])
    (cond
      [(fx> i max-iters) (list 'fail 'max-iters-exceeded (reverse hist))]
      [else
       (let* ([t0 (c-cpu)]
              [r (attempt-write root)]
              [dt (- (c-cpu) t0)])
         (cond
           [(eq? (car r) 'ok)
            (o (c-fmt "  [iter ~a] SUCCESS in ~ams; bytes=~a externals=~a"
                      i dt (c-bvlen (cadr r)) (length (caddr r))))
            (list 'ok (cadr r) (caddr r) (reverse hist))]
           [else
            (let* ([e (cadr r)]
                   [irr (first-irritant e)]
                   [cat (obj-category irr)]
                   [brief (obj-brief irr)]
                   [entry (c-fmt "  [iter ~a] CRASH after ~ams (externals so far ~a): ~a~%           irritant: ~a"
                                 i dt n-collected (cond->string e) brief)])
              (o entry)
              ;; policy: derive a new externalization rule from the irritant
              (let ([act
                     (cond
                       [(eq? irr 'NO-IRRITANT)
                        (list 'bail "no irritant to classify")]
                       [(and (procedure? irr) ($cont? irr))
                        (if (assq 'continuation ext-rules)
                            (list 'force irr 'forced:continuation)
                            (list 'rule 'continuation
                                  (lambda (v) (and (procedure? v) ($cont? v)))))]
                       [(port? irr)
                        (if (assq 'chez-port ext-rules)
                            (list 'force irr 'forced:chez-port)
                            (list 'rule 'chez-port (lambda (v) (port? v))))]
                       [(and (hashtable? irr) (not (eq-hashtable? irr)) (not (symbol-hashtable? irr)))
                        (if (assq 'generic-chez-hashtable ext-rules)
                            (list 'force irr 'forced:generic-hashtable)
                            (list 'rule 'generic-chez-hashtable
                                  (lambda (v) (and (hashtable? v) (not (eq-hashtable? v))
                                                   (not (symbol-hashtable? v))))))]
                       [(memq cat '(other continuation opaque-procedure))
                        ;; 'other = non-heap / foreign pointers (rktio handles etc.), tlc, ...
                        (if (assq 'foreign/other ext-rules)
                            (list 'force irr 'forced:foreign/other)
                            (list 'rule 'foreign/other
                                  (lambda (v) (memq (obj-category v)
                                                    '(other continuation opaque-procedure)))))]
                       [(and ($rec? irr) (not (hashtable? irr)))
                        (let* ([rtd ($rtd irr)]
                               [tag (string->symbol
                                     (string-append "rec:" (symbol->string (rtd-name irr))))])
                          (if (assq tag ext-rules)
                              (list 'force irr (string->symbol (c-fmt "forced:~a" tag)))
                              (list 'rule tag
                                    (lambda (v) (and ($rec? v) (not (hashtable? v))
                                                     (eq? (#%$record-type-descriptor v) rtd))))))]
                       [else
                        (if (eq-hashtable-ref forced-ht irr #f)
                            (list 'bail (c-fmt "already-forced object still crashing: ~a" brief))
                            (list 'force irr (string->symbol (c-fmt "forced:~a" cat))))])])
                (case (car act)
                  [(rule)
                   (o (c-fmt "           -> add class rule: ~a" (cadr act)))
                   (add-rule! (cadr act) (caddr act))
                   (loop (fx+ i 1) (cons (list i cat brief 'rule (cadr act)) hist))]
                  [(force)
                   (o (c-fmt "           -> force individual object external: ~a" (caddr act)))
                   (eq-hashtable-set! forced-ht (cadr act) (caddr act))
                   (loop (fx+ i 1) (cons (list i cat brief 'force (caddr act)) hist))]
                  [(bail)
                   (o (c-fmt "           -> BAIL: ~a" (cadr act)))
                   (list 'fail (cadr act) (reverse (cons (list i cat brief 'bail #f) hist)))])))]))])))

;; ---------- read back ----------
(define (read-back bv exts)
  (call/cc
   (lambda (k)
     (with-exception-handler
       (lambda (e) (k (list 'err (cond->string e))))
       (lambda ()
         (let ([ip (c-obvip bv)])
           (list 'ok (c-faslr ip 'load (list->vector (map car exts))))))))))

;; ---------- lockstep structural comparison ----------
(define (compare-graphs a0 b0 ext-objs o)
  (define amap (make-eq-hashtable))     ; a -> b as first mapped
  (define mism '())
  (define n-mism 0)
  (define n-pairs 0)
  (define n-ext-hit 0)
  (define n-eq-leaf 0)
  (define copy-cats (make-hashtable equal-hash equal?))
  (define skipped-ht-keys 0)
  (define (bump! t x) (hashtable-update! t x (lambda (v) (fx+ v 1)) 0))
  (define (mm! kind a b)
    (set! n-mism (fx+ n-mism 1))
    (when (< (length mism) 40)
      (set! mism (cons (c-fmt "~a : a=~a b=~a" kind (obj-brief a) (obj-brief b)) mism))))
  (define stack (list (cons a0 b0)))
  (define (push! a b) (set! stack (cons (cons a b) stack)))
  (let loop ()
    (unless (null? stack)
      (let* ([pr (car stack)] [a (car pr)] [b (cdr pr)])
        (set! stack (cdr stack))
        (set! n-pairs (fx+ n-pairs 1))
        (cond
          ;; externalized object: identity must be preserved
          [(eq-hashtable-ref ext-objs a #f)
           (if (eq? a b) (set! n-ext-hit (fx+ n-ext-hit 1)) (mm! 'external-not-eq a b))]
          ;; same object (interned symbol, fixnum, shared rtd, empty containers...)
          [(eq? a b) (set! n-eq-leaf (fx+ n-eq-leaf 1))]
          [else
           (let ([ca (obj-category a)] [cb (obj-category b)])
             (cond
               [(not (eq? ca cb)) (mm! 'category a b)]
               [(and (heapish? a) (eq-hashtable-ref amap a #f))
                => (lambda (b*) (void))]  ; placeholder, replaced below
               [else (void)])
             ;; real dispatch
             (cond
               [(not (eq? ca cb)) (void)] ; already mismatched
               [(heapish? a)
                (let ([prev (eq-hashtable-ref amap a #f)])
                  (cond
                    [prev
                     (unless (eq? prev b) (mm! 'sharing-broken a b))]
                    [else
                     (eq-hashtable-set! amap a b)
                     (bump! copy-cats ca)
                     (case ca
                       [(closure)
                        (let ([na (safe-clen a)] [nb (safe-clen b)])
                          (cond
                            [(not (eqv? na nb)) (mm! 'closure-len a b)]
                            [(not (eq? ($ccode a) (try (lambda () ($ccode b)) #f)))
                             (mm! 'closure-code-not-eq a b)]
                            [else
                             (let lp ([i 0])
                               (when (fx< i na)
                                 (push! ($cref a i) (try (lambda () ($cref b i)) 'UNREADABLE))
                                 (lp (fx+ i 1))))]))]
                       [(eq-hashtable)
                        (cond
                          [(not (eqv? (hashtable-size a) (hashtable-size b))) (mm! 'ht-size a b)]
                          [(not (eq? (c-htmut? a) (c-htmut? b))) (mm! 'ht-mutability a b)]
                          [(not (eq? (c-eqweak? a) (c-eqweak? b))) (mm! 'ht-weakness a b)]
                          [(not (eq? (c-eqeph? a) (c-eqeph? b))) (mm! 'ht-ephemeron a b)]
                          [else
                           (let ([ks (c-htkeys a)])
                             (let lp ([i 0])
                               (when (fx< i (vector-length ks))
                                 (let ([k (vector-ref ks i)])
                                   (if (or (symbol? k) (fixnum? k) (boolean? k) (char? k) (null? k))
                                       (if (c-htcontains? b k)
                                           (push! (c-htref a k #f) (c-htref b k #f))
                                           (mm! 'ht-key-missing k b))
                                       (set! skipped-ht-keys (fx+ skipped-ht-keys 1))))
                                 (lp (fx+ i 1)))))])]
                       [(symbol-hashtable)
                        (if (eqv? (hashtable-size a) (hashtable-size b))
                            (let ([ks (c-htkeys a)])
                              (let lp ([i 0])
                                (when (fx< i (vector-length ks))
                                  (let ([k (vector-ref ks i)])
                                    (if (c-htcontains? b k)
                                        (push! (c-htref a k #f) (c-htref b k #f))
                                        (mm! 'ht-key-missing k b)))
                                  (lp (fx+ i 1)))))
                            (mm! 'ht-size a b))]
                       [(weak-pair ephemeron-pair pair)
                        ;; weakness must be preserved
                        (let ([wb (cond [(weak-pair? b) 'weak-pair]
                                        [(ephemeron-pair? b) 'ephemeron-pair]
                                        [else 'pair])])
                          (if (eq? ca wb)
                              (begin (push! (car a) (car b)) (push! (cdr a) (cdr b)))
                              (mm! 'pair-weakness a b)))]
                       [(vector)
                        (if (eqv? (vector-length a) (vector-length b))
                            (let lp ([i 0])
                              (when (fx< i (vector-length a))
                                (push! (vector-ref a i) (vector-ref b i))
                                (lp (fx+ i 1))))
                            (mm! 'vector-len a b))]
                       [(stencil-vector)
                        (if (and (eqv? ($stlen a) (try (lambda () ($stlen b)) #f))
                                 (eqv? ($stmask a) ($stmask b)))
                            (let lp ([i 0])
                              (when (fx< i ($stlen a))
                                (push! (try (lambda () ($stref a i)) 'UNREADABLE)
                                       (try (lambda () ($stref b i)) 'UNREADABLE))
                                (lp (fx+ i 1))))
                            (mm! 'stencil-shape a b))]
                       [(box)
                        (push! (unbox a) (unbox b))]
                       [else
                        (cond
                          [($rec? a)
                           (cond
                             [(not (and ($rec? b) (eq? ($rtd a) (try (lambda () ($rtd b)) #f))))
                              (mm! 'record-rtd a b)]
                             [else
                              (let ([n (rtd-total-fields ($rtd a))])
                                (let lp ([i 0])
                                  (when (fx< i n)
                                    (push! (try (lambda () ($rref a i)) 'UNREADABLE)
                                           (try (lambda () ($rref b i)) 'UNREADABLE))
                                    (lp (fx+ i 1)))))])]
                          [else (mm! 'unknown-heapish a b)])])]))]
               ;; non-heapish leaves
               [else
                (case ca
                  [(string bytevector fxvector flvector)
                   (unless (try (lambda () (equal? a b)) #f) (mm! 'leaf-not-equal a b))]
                  [(number)
                   (unless (eqv? a b) (mm! 'number-not-eqv a b))]
                  [(symbol gensym char boolean null void eof)
                   (unless (eqv? a b) (mm! 'atom-not-eqv a b))]
                  [else
                   (unless (eqv? a b) (mm! 'other-leaf a b))])]))]))
      (loop)))
  (o (c-fmt "  compared object pairs: ~a" n-pairs))
  (o (c-fmt "  eq? leaves (interned/shared/immediate): ~a" n-eq-leaf))
  (o (c-fmt "  external identity hits: ~a" n-ext-hit))
  (o (c-fmt "  hashtable keys skipped (non-atomic): ~a" skipped-ht-keys))
  (o (c-fmt "  MISMATCHES: ~a" n-mism))
  (for-each (lambda (m) (o (c-fmt "    ! ~a" m))) (reverse mism))
  (dump-counts o copy-cats "  copied-object categories (a-side, structurally compared):")
  n-mism)

;; ---------- externals census ----------
(define (dump-externals o exts)
  (let ([tags (make-hashtable equal-hash equal?)])
    (for-each (lambda (pr)
                (hashtable-update! tags (cdr pr) (lambda (v) (fx+ v 1)) 0))
              exts)
    (dump-counts o tags (c-fmt "  externals by tag (total ~a):" (length exts))))
  (let ([shown 0])
    (for-each (lambda (pr)
                (when (and (eq? (cdr pr) 'code) (fx< shown 25))
                  (set! shown (fx+ shown 1))
                  (o (c-fmt "    code[~a]: ~a" shown (code-name (car pr))))))
              exts)))

;; ---------- behavior probes ----------
;; spec: (list name make-args), applied to orig and copy values of that variable
;; safe-apply: (lambda (f args) -> (cons 'val v) | (cons 'err msg)), catches Racket raises too
(define (probe-behavior o inst-a inst-b specs safe-apply)
  (define hta (inst-eq-ht inst-a))
  (define htb (inst-eq-ht inst-b))
  (define (val-of ht name)
    (let ([var (and ht (c-htref ht name #f))])
      (and var (var-val var))))
  (for-each
   (lambda (spec)
     (let* ([name (car spec)]
            [mk (cadr spec)]
            [fa (val-of hta name)]
            [fb (val-of htb name)])
       (cond
         [(not (and (procedure? fa) (procedure? fb)))
          (o (c-fmt "  probe ~a: values not both procedures (a=~a b=~a)"
                    name (obj-brief fa) (obj-brief fb)))]
         [else
          (let* ([args-a (mk)] [args-b (mk)]
                 [ra (safe-apply fa args-a)]
                 [rb (safe-apply fb args-b)]
                 [same-arity (eqv? (try (lambda () (c-arity fa)) #f)
                                   (try (lambda () (c-arity fb)) #f))]
                 [verdict
                  (cond
                    [(and (eq? (car ra) 'val) (eq? (car rb) 'val)
                          (try (lambda () (equal? (cdr ra) (cdr rb))) #f)
                          ;; mutation probes: argument vectors must agree too
                          (try (lambda () (equal? args-a args-b)) #f))
                     'OK]
                    [(and (eq? (car ra) 'err) (eq? (car rb) 'err)
                          (equal? (cdr ra) (cdr rb)))
                     'OK-both-raise-same-error]
                    [else 'DIFFER])])
            (o (c-fmt "  probe ~a: ~a  arity-same=~a" name verdict same-arity))
            (o (c-fmt "     orig=~a" (fmt-val (cdr ra) 100)))
            (o (c-fmt "     copy=~a" (fmt-val (cdr rb) 100)))
            (o (c-fmt "     args-after: orig=~a copy=~a"
                      (fmt-val args-a 60) (fmt-val args-b 60))))])))
   specs))

;; ---------- full stage runner ----------
(define (run-stage root o stage-label prescan-cap max-iters bv-read-cap probe-inst-b?)
  ;; returns (list result-tag bv exts copy) with copy possibly #f
  (o "")
  (o (c-fmt "======== STAGE ~a ========" stage-label))
  (let* ([t0 (c-cpu)]
         [ps (prescan root prescan-cap)]
         [dt (- (c-cpu) t0)])
    (o (c-fmt "  prescan: ~a nodes traversed in ~ams~a; ~a external hits"
              (car ps) dt (if (cadr ps) " (TRUNCATED at cap)" "") (list-ref ps 4)))
    (dump-counts o (caddr ps) "  graph category census (to-serialize side):")
    (dump-counts o (cadddr ps) "  boundary hits by tag (prescan):"))
  (let ([r (iterate-write root o max-iters)])
    (cond
      [(eq? (car r) 'ok)
       (let ([bv (cadr r)] [exts (caddr r)])
         (o (c-fmt "  WRITE OK: ~a bytes, ~a externals, ~a crash iterations before success"
                   (c-bvlen bv) (length exts) (length (cadddr r))))
         (dump-externals o exts)
         (cond
           [(> (c-bvlen bv) bv-read-cap)
            (o (c-fmt "  read-back SKIPPED (bytevector ~a > cap ~a)" (c-bvlen bv) bv-read-cap))
            (list 'ok-noread bv exts #f)]
           [else
            (let* ([t1 (c-cpu)]
                   [rb (read-back bv exts)]
                   [dt1 (- (c-cpu) t1)])
              (cond
                [(eq? (car rb) 'ok)
                 (o (c-fmt "  READ OK in ~ams" dt1))
                 (let ([copy (cadr rb)]
                       [ext-objs (make-eq-hashtable)])
                   (for-each (lambda (pr) (eq-hashtable-set! ext-objs (car pr) (cdr pr))) exts)
                   (o "  ---- structural lockstep comparison ----")
                   (let ([nm (compare-graphs root copy ext-objs o)])
                     (o (c-fmt "  comparison mismatches: ~a" nm)))
                   (list 'ok bv exts copy))]
                [else
                 (o (c-fmt "  READ FAILED: ~a" (cadr rb)))
                 (list 'read-failed bv exts #f)]))]))]
      [else
       (o (c-fmt "  WRITE DID NOT CONVERGE: ~a" (cadr r)))
       (list 'write-failed #f #f #f)])))
