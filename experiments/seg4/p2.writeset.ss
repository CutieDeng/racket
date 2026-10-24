;; ===== P2 write-set machinery (pure Chez, loaded before import) =====
;; Captures the write face of racket/init(+xrepl) instantiation onto pre-existing
;; mutable objects: BFS-mark pre-heap with parent paths, shallow-snapshot every
;; mutable container, diff after instantiation, build a replay patch, fasl it.

;; --- extra captured primitives ---
(define mark-ht (make-eq-hashtable))  ; shared mark set (restored)

(define c2-htsize hashtable-size)
(define c2-htset! hashtable-set!)
(define c2-htdel! hashtable-delete!)
(define c2-strlen string-length)
(define c2-substr substring)
(define c2-str=? string=?)
(define c2-bv=? bytevector=?)
(define c2-bvcopy bytevector-copy)
(define c2-bvlen bytevector-length)
(define c2-mkeqvht make-eqv-hashtable)
(define c2-mkht make-hashtable)
(define c2-utf8->str utf8->string)
(define c2-sapp string-append)
(define (c2-hashfn h) (try (lambda () (hashtable-hash-function h)) #f))
(define (c2-equivfn h) (try (lambda () (hashtable-equivalence-function h)) #f))
(define (c2-mutvec? v) (try (lambda () (mutable-vector? v)) #t))
(define (c2-mutstr? s) (try (lambda () (mutable-string? s)) #t))
(define (c2-mutbv? b) (try (lambda () (mutable-bytevector? b)) #t))
(define (c2-mutbox? b) (try (lambda () (mutable-box? b)) #t))
(define c2-fxvlen fxvector-length)
(define c2-fxvref fxvector-ref)
(define c2-mkfxv make-fxvector)
(define c2-fxvset! fxvector-set!)
(define c2-flvlen flvector-length)
(define c2-flvref flvector-ref)
(define c2-mkflv make-flvector)
(define c2-flvset! flvector-set!)

(define MISSING (gensym "p2-missing"))

;; --- substring search (Chez has no string-contains) ---
(define (substr? s sub)
  (let ([ls (c2-strlen s)] [lb (c2-strlen sub)])
    (and (fx>= ls lb)
         (let loop ([i 0])
           (cond
             [(fx> i (fx- ls lb)) #f]
             [(let check ([j 0])
                (cond [(fx>= j lb) #t]
                      [(char=? (string-ref s (fx+ i j)) (string-ref sub j)) (check (fx+ j 1))]
                      [else #f]))
              #t]
             [else (loop (fx+ i 1))])))))

;; --- readable briefs: never raw ~s on records (cycle risk); depth-limited ---
(define (p2-brief* x depth)
  (cond
    [(symbol? x) (trunc (c-fmt "~s" x) 48)]
    [(string? x) (trunc (c-fmt "~s" x) 48)]
    [(or (number? x) (char? x) (boolean? x) (null? x)) (c-fmt "~s" x)]
    [(eq? x MISSING) "<missing>"]
    [(eq? x 'UNREADABLE) "<unreadable>"]
    [(hashtable? x) (c-fmt "<~a sz=~a>" (obj-category x) (c2-htsize x))]
    [($rec? x)
     (let ([nm (rtd-name x)])
       (cond
         [(fx<= depth 0) (c-fmt "rec:~a" nm)]
         [(eq? nm 'resolved-module-path)
          (c-fmt "rmp<~a>" (p2-brief* (try (lambda () ($rref x 0)) '?) (fx- depth 1)))]
         [(eq? nm 'path)
          (c-fmt "path<~a>" (trunc (try (lambda () (c2-utf8->str ($rref x 0))) "?") 60))]
         [(eq? nm 'module-path-index)
          (c-fmt "mpi<~a>" (p2-brief* (try (lambda () ($rref x 0)) '?) (fx- depth 1)))]
         [(eq? nm 'variable)
          (c-fmt "var<~a>" (p2-brief* (try (lambda () ($rref x 1)) '?) (fx- depth 1)))]
         [(eq? nm 'instance)
          (c-fmt "inst<~a>" (p2-brief* (try (lambda () ($rref x 0)) '?) (fx- depth 1)))]
         [else (c-fmt "rec:~a" nm)]))]
    [(pair? x)
     (if (fx<= depth 0)
         "(...)"
         (c-fmt "(~a . ~a)" (p2-brief* (car x) (fx- depth 1)) (p2-brief* (cdr x) (fx- depth 1))))]
    [(vector? x) (c-fmt "vec[~a]" (vector-length x))]
    [(procedure? x) (obj-brief x)]
    [(bytevector? x) (c-fmt "bv[~a]" (c2-bvlen x))]
    [else (obj-brief x)]))
(define (p2-brief x) (try (lambda () (p2-brief* x 3)) "<unprintable>"))

;; --- labeled kids (labels carry parent rtd names since field names are all 'field) ---
(define (p2-kids obj)
  ;; -> list of (label-string . child)
  (cond
    [(procedure? obj)
     (cond
       [($cont? obj) '()]
       [(safe-clen obj)
        => (lambda (n)
             (let loop ([i 0] [acc '()])
               (if (fx>= i n)
                   (reverse acc)
                   (loop (fx+ i 1)
                         (cons (cons (c-fmt "clos{~a}.fv~a" (trunc (c-fmt "~a" ($cname obj)) 28) i)
                                     ($cref obj i))
                               acc)))))]
       [else '()])]
    [(hashtable? obj)
     (let ([ks (c-htkeys obj)])
       (let loop ([i 0] [acc '()])
         (if (fx>= i (vector-length ks))
             acc
             (let ([k (vector-ref ks i)])
               (loop (fx+ i 1)
                     (cons (cons (c-fmt "k<~a>" (try (lambda () (p2-brief* k 1)) "?")) k)
                           (cons (cons (c-fmt "v<~a>" (try (lambda () (p2-brief* k 1)) "?"))
                                       (c-htref obj k #f))
                             acc)))))))]
    [($rec? obj)
     (let ([n (rtd-total-fields ($rtd obj))]
           [nm (rtd-name obj)])
       (let loop ([i 0] [acc '()])
         (if (fx>= i n)
             (reverse acc)
             (loop (fx+ i 1)
                   (cons (cons (c-fmt "~a.f~a" nm i)
                               (try (lambda () ($rref obj i)) 'UNREADABLE))
                         acc)))))]
    [(pair? obj) (list (cons "car" (car obj)) (cons "cdr" (cdr obj)))]
    [($stvec? obj)
     (let ([n ($stlen obj)])
       (let loop ([i 0] [acc '()])
         (if (fx>= i n)
             (reverse acc)
             (loop (fx+ i 1)
                   (cons (cons (c-fmt "st~a" i) (try (lambda () ($stref obj i)) 'UNREADABLE)) acc)))))]
    [(box? obj) (list (cons "unbox" (unbox obj)))]
    [(vector? obj)
     (let ([n (vector-length obj)])
       (let loop ([i 0] [acc '()])
         (if (fx>= i n)
             (reverse acc)
             (loop (fx+ i 1) (cons (cons (c-fmt "v~a" i) (vector-ref obj i)) acc)))))]
    [else '()]))

;; --- BFS marking with parent paths; fills mark-ht (shared with engine rules) ---
(define p2-parent (make-eq-hashtable))   ; obj -> (parent . label) | (#f . root-name)
(define p2-objs '())                     ; marked heapish objects in BFS order
(define p2-n 0)
(define p2-bufs '())                     ; (buf-obj . (kind . content-copy)) mutable leaf buffers
(define p2-bufseen (make-eq-hashtable))

(define (buf-snap x)
  (try (lambda ()
         (cond
           [(and (string? x) (c2-mutstr? x)) (cons 'str (c2-substr x 0 (c2-strlen x)))]
           [(and (bytevector? x) (c2-mutbv? x)) (cons 'bv (c2-bvcopy x))]
           [(fxvector? x)
            (let ([n (c2-fxvlen x)])
              (let ([v (c2-mkfxv n 0)])
                (let lp ([i 0]) (when (fx< i n) (c2-fxvset! v i (c2-fxvref x i)) (lp (fx+ i 1))))
                (cons 'fxv v)))]
           [(flvector? x)
            (let ([n (c2-flvlen x)])
              (let ([v (c2-mkflv n 0.0)])
                (let lp ([i 0]) (when (fx< i n) (c2-flvset! v i (c2-flvref x i)) (lp (fx+ i 1))))
                (cons 'flv v)))]
           [else #f]))
       #f))

(define (p2-scan! roots cap)
  ;; roots: list of (name . obj)
  (define qf '())
  (define qb '())
  (define (enq! x) (set! qb (cons x qb)))
  (define (deq!)
    (when (null? qf) (set! qf (reverse qb)) (set! qb '()))
    (let ([x (car qf)]) (set! qf (cdr qf)) x))
  (define (empty?) (and (null? qf) (null? qb)))
  (for-each (lambda (pr)
              (let ([x (cdr pr)])
                (when (and (heapish? x) (not (eq-hashtable-ref mark-ht x #f)))
                  (eq-hashtable-set! mark-ht x #t)
                  (eq-hashtable-set! p2-parent x (cons #f (c-fmt "~a" (car pr))))
                  (enq! x))))
            roots)
  (let loop ()
    (unless (or (empty?) (fx>= p2-n cap))
      (let ([obj (deq!)])
        (set! p2-objs (cons obj p2-objs))
        (set! p2-n (fx+ p2-n 1))
        (for-each
         (lambda (lc)
           (let ([child (cdr lc)])
             (cond
               [(eq? child 'UNREADABLE) (void)]
               [(heapish? child)
                (unless (eq-hashtable-ref mark-ht child #f)
                  (eq-hashtable-set! mark-ht child #t)
                  (eq-hashtable-set! p2-parent child (cons obj (car lc)))
                  (enq! child))]
               [(or (string? child) (bytevector? child) (fxvector? child) (flvector? child))
                (unless (eq-hashtable-ref p2-bufseen child #f)
                  (eq-hashtable-set! p2-bufseen child #t)
                  (let ([e (buf-snap child)])
                    (when e
                      (eq-hashtable-set! p2-parent child (cons obj (car lc)))
                      (set! p2-bufs (cons (cons child e) p2-bufs)))))]
               [else (void)])))
         (p2-kids obj)))
      (loop)))
  (set! p2-objs (reverse p2-objs))
  p2-n)

(define (p2-path obj)
  (let loop ([x obj] [acc '()] [g 0])
    (let ([pr (eq-hashtable-ref p2-parent x #f)])
      (cond
        [(not pr)
         (apply c2-sapp (cons "?" acc))]
        [(not (car pr))
         (apply c2-sapp (cons (cdr pr) acc))]
        [(fx> g 30)
         (apply c2-sapp (cons "..." acc))]
        [else (loop (car pr) (cons (c2-sapp "\xB7;" (cdr pr)) acc) (fx+ g 1))]))))
(define (p2-path/trunc obj n)
  (let ([s (try (lambda () (p2-path obj)) "<path-err>")])
    (if (fx> (c2-strlen s) n)
        (c2-sapp "..." (c2-substr s (fx- (c2-strlen s) n) (c2-strlen s)))
        s)))

;; --- shallow snapshot of one heapish object; #f = untracked/immutable ---
(define (p2-snap-one x)
  (cond
    [(hashtable? x)
     (and (c-htmut? x)
          (let* ([ks (c-htkeys x)]
                 [n (vector-length ks)]
                 [prs (make-vector n)])
            (let lp ([i 0])
              (when (fx< i n)
                (let ([k (vector-ref ks i)])
                  (vector-set! prs i (cons k (c-htref x k MISSING))))
                (lp (fx+ i 1))))
            (cons 'ht prs)))]
    [(procedure? x)
     (cond
       [($cont? x) #f]
       [(safe-clen x)
        => (lambda (n)
             (let ([v (make-vector n)])
               (let lp ([i 0])
                 (when (fx< i n)
                   (vector-set! v i (try (lambda () ($cref x i)) 'UNREADABLE))
                   (lp (fx+ i 1))))
               (cons 'clos v)))]
       [else #f])]
    [($stvec? x)
     (let* ([n ($stlen x)] [v (make-vector n)])
       (let lp ([i 0])
         (when (fx< i n)
           (vector-set! v i (try (lambda () ($stref x i)) 'UNREADABLE))
           (lp (fx+ i 1))))
       (cons 'stvec v))]
    [(box? x) (and (c2-mutbox? x) (cons 'box (unbox x)))]
    [(pair? x) (cons 'pair (cons (car x) (cdr x)))]
    [($rec? x)
     (let* ([n (rtd-total-fields ($rtd x))] [v (make-vector n)])
       (let lp ([i 0])
         (when (fx< i n)
           (vector-set! v i (try (lambda () ($rref x i)) 'UNREADABLE))
           (lp (fx+ i 1))))
       (cons 'rec v))]
    [(vector? x)
     (and (c2-mutvec? x)
          (let* ([n (vector-length x)] [v (make-vector n)])
            (let lp ([i 0])
              (when (fx< i n) (vector-set! v i (vector-ref x i)) (lp (fx+ i 1))))
            (cons 'vec v)))]
    [else #f]))

(define snap0 (make-eq-hashtable))     ; original pre-init snapshot (kept for patch)
(define cursnap (make-eq-hashtable))   ; working snapshot (updated after each diff)
(define bufsnap0 (make-eq-hashtable))  ; buf obj -> (kind . copy)
(define bufcur (make-eq-hashtable))

(define (p2-snapshot-all! o)
  (let ([kinds (make-hashtable equal-hash equal?)])
    (for-each (lambda (x)
                (let ([e (p2-snap-one x)])
                  (when e
                    (eq-hashtable-set! snap0 x e)
                    (eq-hashtable-set! cursnap x e)
                    (hashtable-update! kinds (car e) (lambda (v) (fx+ v 1)) 0))))
              p2-objs)
    (for-each (lambda (pr)
                (eq-hashtable-set! bufsnap0 (car pr) (cdr pr))
                (eq-hashtable-set! bufcur (car pr) (cdr pr))
                (hashtable-update! kinds (cadr pr) (lambda (v) (fx+ v 1)) 0))
              p2-bufs)
    (dump-counts o kinds "  snapshot census (mutable-candidate containers by kind):")))

;; --- destination classification of a written value ---
(define (dest-of v)
  (cond
    [($code? v) 'code]
    [(heapish? v) (if (eq-hashtable-ref mark-ht v #f) 'pre 'seg-new)]
    [else 'leaf]))

;; --- old-key membership table matching the live table's equivalence ---
(define (old-keyset x prs)
  (try (lambda ()
         (let ([t (cond
                    [(eq-hashtable? x) (make-eq-hashtable)]
                    [(symbol-hashtable? x) (make-eq-hashtable)]
                    [(c2-hashfn x) => (lambda (hf) (c2-mkht hf (c2-equivfn x)))]
                    [else (c2-mkeqvht)])])
           (let lp ([i 0])
             (when (fx< i (vector-length prs))
               (c2-htset! t (car (vector-ref prs i)) #t)
               (lp (fx+ i 1))))
           t))
       #f))

(define (p2-read-slot x kind i)
  (case kind
    [(clos) (try (lambda () ($cref x i)) 'UNREADABLE)]
    [(stvec) (try (lambda () ($stref x i)) 'UNREADABLE)]
    [(rec) (try (lambda () ($rref x i)) 'UNREADABLE)]
    [(vec) (vector-ref x i)]
    [else 'UNREADABLE]))

;; --- diff one object against snapshot entry ---
;; -> #f | ht-diff: (list 'ht n-add n-del n-mod adds dels mods dest-vec)
;;         adds: full list (k . v); dels: full list (k . oldv); mods: full list (k oldv newv)
;;    slot-diff: (list kind nch changes dest-vec)  changes: full list (i oldv newv)
(define (p2-diff-one x old)
  (let ([kind (car old)]
        [dv (vector 0 0 0 0)])  ; seg-new pre leaf code
    (define (dest! v)
      (let ([d (dest-of v)])
        (vector-set! dv (case d [(seg-new) 0] [(pre) 1] [(leaf) 2] [else 3])
                     (fx+ 1 (vector-ref dv (case d [(seg-new) 0] [(pre) 1] [(leaf) 2] [else 3]))))))
    (case kind
      [(ht)
       (let* ([prs (cdr old)]
              [n-old (vector-length prs)]
              [dels '()] [mods '()] [adds '()]
              [n-del 0] [n-mod 0] [n-add 0])
         (let lp ([i 0])
           (when (fx< i n-old)
             (let* ([pr (vector-ref prs i)] [k (car pr)] [ov (cdr pr)])
               (cond
                 [(not (try (lambda () (c-htcontains? x k)) #f))
                  (set! n-del (fx+ n-del 1))
                  (set! dels (cons pr dels))]
                 [else
                  (let ([nv (c-htref x k MISSING)])
                    (unless (eq? nv ov)
                      (set! n-mod (fx+ n-mod 1))
                      (dest! nv)
                      (set! mods (cons (list k ov nv) mods))))]))
             (lp (fx+ i 1))))
         (let ([sz (c2-htsize x)])
           (when (fx> (fx- (fx+ sz n-del) n-old) 0)
             (let ([oldset (old-keyset x prs)])
               (cond
                 [oldset
                  (let ([ks (c-htkeys x)])
                    (let lp ([i 0])
                      (when (fx< i (vector-length ks))
                        (let ([k (vector-ref ks i)])
                          (unless (try (lambda () (c-htcontains? oldset k)) #t)
                            (let ([nv (c-htref x k MISSING)])
                              (set! n-add (fx+ n-add 1))
                              (dest! nv)
                              (set! adds (cons (cons k nv) adds)))))
                        (lp (fx+ i 1)))))]
                 [else
                  (set! n-add (fx- (fx+ sz n-del) n-old))]))))
         (if (and (fx= n-add 0) (fx= n-del 0) (fx= n-mod 0))
             #f
             (list 'ht n-add n-del n-mod adds dels mods dv)))]
      [(clos stvec rec vec)
       (let* ([ov (cdr old)]
              [n (vector-length ov)]
              [ch '()] [nch 0])
         (let lp ([i 0])
           (when (fx< i n)
             (let ([nv (p2-read-slot x kind i)])
               (unless (eq? nv (vector-ref ov i))
                 (set! nch (fx+ nch 1))
                 (dest! nv)
                 (set! ch (cons (list i (vector-ref ov i) nv) ch))))
             (lp (fx+ i 1))))
         (if (fx= nch 0) #f (list kind nch (reverse ch) dv)))]
      [(box)
       (let ([nv (unbox x)])
         (if (eq? nv (cdr old))
             #f
             (begin (dest! nv) (list 'box 1 (list (list 0 (cdr old) nv)) dv))))]
      [(pair)
       (let ([oc (car (cdr old))] [od (cdr (cdr old))]
             [nc (car x)] [nd (cdr x)])
         (let ([ch '()])
           (unless (eq? nd od) (dest! nd) (set! ch (cons (list 1 od nd) ch)))
           (unless (eq? nc oc) (dest! nc) (set! ch (cons (list 0 oc nc) ch)))
           (if (null? ch) #f (list 'pair (length ch) ch dv))))]
      [else #f])))

;; --- weakness label of a container ---
(define (weak-label x)
  (cond
    [(and (hashtable? x) (eq-hashtable? x))
     (cond [(try (lambda () (c-eqeph? x)) #f) "eph"]
           [(try (lambda () (c-eqweak? x)) #f) "weak"]
           [else "strong"])]
    [(hashtable? x) "strong"]
    [(and (pair? x) (weak-pair? x)) "weak"]
    [(and (pair? x) (ephemeron-pair? x)) "eph"]
    [else "strong"]))

;; --- auto tag by path + category (analysis aid; final judgment in report) ---
(define (p2-tag x path)
  (cond
    [(and (substr? path "module-registry") (substr? path ".f0")
          (hashtable? x)) 'registry-table]
    [(substr? path "module-registry") 'registry-misc]
    [(substr? path "declaration") 'registry-table]
    [(substr? path "small-hash") 'small-hash]
    [(and (hashtable? x)
          (or (string=? (weak-label x) "weak") (string=? (weak-label x) "eph")))
     'weak-cache]
    [(substr? path "intern") 'intern]
    [(substr? path "cache") 'cache]
    [(substr? path "logger") 'logger]
    [(substr? path "plumber") 'plumber]
    [(substr? path "custodian") 'custodian]
    [(substr? path "will-") 'will]
    [(substr? path "thread") 'thread]
    [(substr? path "parameterization") 'param]
    [(substr? path "namespace.f") (if ($rec? x) 'namespace-rec 'namespace-sub)]
    [(substr? path "performance") 'perf-counter]
    [(substr? path "place") 'place]
    [(substr? path "evt") 'evt]
    [(substr? path "rktio") 'io]
    [(substr? path "port") 'io]
    [(substr? path "security") 'security]
    [(substr? path "inspector") 'inspector]
    [else 'other]))

;; --- phase diff over all snapshotted objects ---
(define phase-diffs '())   ; latest phase: list of (x diff path tag)

(define (p2-diff-phase! o label)
  (set! phase-diffs '())
  (o "")
  (o "======== " label " ========")
  (let ([n-changed 0]
        [total-entries 0]
        [tagcnt (make-hashtable equal-hash equal?)]
        [kindcnt (make-hashtable equal-hash equal?)]
        [dest-tot (vector 0 0 0 0)])
    (for-each
     (lambda (x)
       (let ([old (eq-hashtable-ref cursnap x #f)])
         (when old
           (let ([d (try (lambda () (p2-diff-one x old)) 'DIFF-ERR)])
             (cond
               [(eq? d 'DIFF-ERR)
                (o "  !! diff error on " (obj-brief x))]
               [d
                (let* ([path (p2-path/trunc x 240)]
                       [tag (p2-tag x path)]
                       [cnt (if (eq? (car d) 'ht)
                                (fx+ (cadr d) (fx+ (caddr d) (cadddr d)))
                                (cadr d))]
                       [dv (if (eq? (car d) 'ht) (list-ref d 7) (list-ref d 3))])
                  (set! n-changed (fx+ n-changed 1))
                  (set! total-entries (fx+ total-entries cnt))
                  (hashtable-update! tagcnt tag (lambda (v) (fx+ v cnt)) 0)
                  (hashtable-update! kindcnt (car d) (lambda (v) (fx+ v 1)) 0)
                  (let lp ([i 0])
                    (when (fx< i 4)
                      (vector-set! dest-tot i (fx+ (vector-ref dest-tot i) (vector-ref dv i)))
                      (lp (fx+ i 1))))
                  (set! phase-diffs (cons (list x d path tag) phase-diffs))
                  ;; refresh working snapshot for this object
                  (let ([e (p2-snap-one x)])
                    (when e (eq-hashtable-set! cursnap x e))))]
               [else (void)])))))
     p2-objs)
    ;; buffer diffs
    (let ([n-buf-changed 0])
      (for-each
       (lambda (pr)
         (let* ([x (car pr)]
                [old (eq-hashtable-ref bufcur x #f)])
           (when old
             (let ([same
                    (try (lambda ()
                           (case (car old)
                             [(str) (c2-str=? x (cdr old))]
                             [(bv) (c2-bv=? x (cdr old))]
                             [(fxv) (let ([n (c2-fxvlen x)])
                                      (let lp ([i 0])
                                        (cond [(fx>= i n) #t]
                                              [(fx= (c2-fxvref x i) (c2-fxvref (cdr old) i)) (lp (fx+ i 1))]
                                              [else #f])))]
                             [(flv) (let ([n (c2-flvlen x)])
                                      (let lp ([i 0])
                                        (cond [(fx>= i n) #t]
                                              [(= (c2-flvref x i) (c2-flvref (cdr old) i)) (lp (fx+ i 1))]
                                              [else #f])))]
                             [else #t]))
                         #t)])
               (unless same
                 (set! n-buf-changed (fx+ n-buf-changed 1))
                 (when (fx<= n-buf-changed 40)
                   (o (c-fmt "  BUF-WRITE ~a ~a  path=~a"
                             (car old) (p2-brief x) (p2-path/trunc x 200))))
                 (let ([e (buf-snap x)])
                   (when e (eq-hashtable-set! bufcur x e))))))))
       p2-bufs)
      (o "  changed containers: " n-changed "   total write entries: " total-entries
         "   changed leaf buffers: " n-buf-changed)
      (o (c-fmt "  written-value destinations: seg-new=~a pre-existing=~a leaf=~a code=~a"
                (vector-ref dest-tot 0) (vector-ref dest-tot 1)
                (vector-ref dest-tot 2) (vector-ref dest-tot 3)))
      (dump-counts o kindcnt "  changed containers by kind:")
      (dump-counts o tagcnt "  write entries by auto-tag:"))
    ;; detail dump, largest first
    (let* ([ds (c-sort (lambda (a b)
                         (let ([ca (let ([d (cadr a)]) (if (eq? (car d) 'ht)
                                                           (fx+ (cadr d) (fx+ (caddr d) (cadddr d)))
                                                           (cadr d)))]
                               [cb (let ([d (cadr b)]) (if (eq? (car d) 'ht)
                                                           (fx+ (cadr d) (fx+ (caddr d) (cadddr d)))
                                                           (cadr d)))])
                           (fx> ca cb)))
                       phase-diffs)]
           [shown 0])
      (for-each
       (lambda (entry)
         (set! shown (fx+ shown 1))
         (when (fx<= shown 300)
           (let* ([x (car entry)] [d (cadr entry)] [path (caddr entry)] [tag (cadddr entry)])
             (o "")
             (o (c-fmt "  [~a] ~a ~a (~a) tag=~a" shown (car d) (obj-category x) (weak-label x) tag))
             (o "      path=" path)
             (case (car d)
               [(ht)
                (o (c-fmt "      +~a -~a ~~~a  (size now ~a)"
                          (cadr d) (caddr d) (cadddr d) (c2-htsize x)))
                (let ([show (lambda (lst fmt1 cap)
                              (let lp ([l lst] [i 0])
                                (when (and (pair? l) (fx< i cap))
                                  (o (fmt1 (car l)))
                                  (lp (cdr l) (fx+ i 1)))))])
                  (show (list-ref d 4)
                        (lambda (pr) (c-fmt "      + ~a -> ~a [~a]"
                                            (p2-brief (car pr)) (p2-brief (cdr pr)) (dest-of (cdr pr))))
                        6)
                  (show (list-ref d 5)
                        (lambda (pr) (c-fmt "      - ~a (was ~a)" (p2-brief (car pr)) (p2-brief (cdr pr))))
                        6)
                  (show (list-ref d 6)
                        (lambda (m) (c-fmt "      ~~ ~a : ~a => ~a [~a]"
                                           (p2-brief (car m)) (p2-brief (cadr m)) (p2-brief (caddr m))
                                           (dest-of (caddr m))))
                        6))]
               [else
                (o (c-fmt "      ~a slots changed" (cadr d)))
                (let lp ([l (list-ref d 2)] [i 0])
                  (when (and (pair? l) (fx< i 6))
                    (let ([c (car l)])
                      (o (c-fmt "      slot ~a : ~a => ~a [~a]"
                                (car c) (p2-brief (cadr c)) (p2-brief (caddr c))
                                (dest-of (caddr c)))))
                    (lp (cdr l) (fx+ i 1))))]))))
       ds)
      (when (fx> shown 300)
        (o "  ... (" (fx- shown 300) " more changed containers omitted)")))))

;; --- cumulative patch construction: diff live state vs snap0 ---
;; entry formats:
;;   (vector 'ht+ container key val) (vector 'ht~ container key val) (vector 'ht- container key)
;;   (vector 'slot container kind idx val)
(define (p2-build-patch o include?)
  ;; include?: (lambda (x tag diff) -> bool) container filter
  (let ([entries '()]
        [n-entries 0]
        [n-containers 0]
        [n-excluded 0]
        [n-excluded-entries 0]
        [key-dest (vector 0 0 0 0)]
        [val-dest (vector 0 0 0 0)]
        [by-tag (make-hashtable equal-hash equal?)]
        [containers '()])
    (define (bump-dest! v x)
      (let ([i (case (dest-of x) [(seg-new) 0] [(pre) 1] [(leaf) 2] [else 3])])
        (vector-set! v i (fx+ 1 (vector-ref v i)))))
    (for-each
     (lambda (x)
       (let ([old (eq-hashtable-ref snap0 x #f)])
         (when old
           (let ([d (try (lambda () (p2-diff-one x old)) #f)])
             (when (and d (list? d))
               (let* ([path (p2-path/trunc x 240)]
                      [tag (p2-tag x path)]
                      [cnt (if (eq? (car d) 'ht)
                               (fx+ (cadr d) (fx+ (caddr d) (cadddr d)))
                               (cadr d))])
                 (cond
                   [(include? x tag d)
                    (set! n-containers (fx+ n-containers 1))
                    (set! containers (cons (list x d path tag) containers))
                    (hashtable-update! by-tag tag (lambda (v) (fx+ v cnt)) 0)
                    (case (car d)
                      [(ht)
                       (for-each (lambda (pr)
                                   (unless (eq? (cdr pr) MISSING)
                                     (bump-dest! key-dest (car pr))
                                     (bump-dest! val-dest (cdr pr))
                                     (set! n-entries (fx+ n-entries 1))
                                     (set! entries (cons (vector 'ht+ x (car pr) (cdr pr)) entries))))
                                 (list-ref d 4))
                       (for-each (lambda (pr)
                                   (bump-dest! key-dest (car pr))
                                   (set! n-entries (fx+ n-entries 1))
                                   (set! entries (cons (vector 'ht- x (car pr)) entries)))
                                 (list-ref d 5))
                       (for-each (lambda (m)
                                   (unless (eq? (caddr m) MISSING)
                                     (bump-dest! key-dest (car m))
                                     (bump-dest! val-dest (caddr m))
                                     (set! n-entries (fx+ n-entries 1))
                                     (set! entries (cons (vector 'ht~ x (car m) (caddr m)) entries))))
                                 (list-ref d 6))]
                      [(rec vec box pair stvec clos)
                       (for-each (lambda (c)
                                   (unless (eq? (caddr c) 'UNREADABLE)
                                     (bump-dest! val-dest (caddr c))
                                     (set! n-entries (fx+ n-entries 1))
                                     (set! entries (cons (vector 'slot x (car d) (car c) (caddr c))
                                                         entries))))
                                 (list-ref d 2))])]
                   [else
                    (set! n-excluded (fx+ n-excluded 1))
                    (set! n-excluded-entries (fx+ n-excluded-entries cnt))])))))))
     p2-objs)
    (o "")
    (o "==== CUMULATIVE PATCH (live vs snap0) ====")
    (o "  containers in patch: " n-containers "   entries: " n-entries)
    (o "  excluded containers (filter): " n-excluded " with " n-excluded-entries " entries")
    (o (c-fmt "  key dest: seg-new=~a pre=~a leaf=~a code=~a"
              (vector-ref key-dest 0) (vector-ref key-dest 1)
              (vector-ref key-dest 2) (vector-ref key-dest 3)))
    (o (c-fmt "  val dest: seg-new=~a pre=~a leaf=~a code=~a"
              (vector-ref val-dest 0) (vector-ref val-dest 1)
              (vector-ref val-dest 2) (vector-ref val-dest 3)))
    (dump-counts o by-tag "  patch entries by tag:")
    (values (list->vector (reverse entries)) containers)))

;; --- replay equivalence check: snap0 clone + patch ops == live table ---
(define (p2-replay-check! o containers)
  (let ([n-ok 0] [n-bad 0] [n-skipped 0])
    (for-each
     (lambda (entry)
       (let* ([x (car entry)] [d (cadr entry)])
         (cond
           [(not (eq? (car d) 'ht)) (set! n-skipped (fx+ n-skipped 1))]
           [else
            (let ([old (eq-hashtable-ref snap0 x #f)])
              (let ([clone (try (lambda ()
                                  (let ([t (cond
                                             [(eq-hashtable? x) (make-eq-hashtable)]
                                             [(symbol-hashtable? x) (make-eq-hashtable)]
                                             [(c2-hashfn x) => (lambda (hf) (c2-mkht hf (c2-equivfn x)))]
                                             [else (c2-mkeqvht)])]
                                        [prs (cdr old)])
                                    ;; state at snapshot time
                                    (let lp ([i 0])
                                      (when (fx< i (vector-length prs))
                                        (let ([pr (vector-ref prs i)])
                                          (unless (eq? (cdr pr) MISSING)
                                            (c2-htset! t (car pr) (cdr pr))))
                                        (lp (fx+ i 1))))
                                    ;; apply patch ops for this container
                                    (for-each (lambda (pr) (c2-htset! t (car pr) (cdr pr)))
                                              (list-ref d 4))            ; adds
                                    (for-each (lambda (pr) (c2-htdel! t (car pr)))
                                              (list-ref d 5))            ; dels
                                    (for-each (lambda (m) (c2-htset! t (car m) (caddr m)))
                                              (list-ref d 6))            ; mods
                                    t))
                                #f)])
                (cond
                  [(not clone) (set! n-bad (fx+ n-bad 1))
                               (o "  replay CLONE-FAIL: " (p2-path/trunc x 160))]
                  [else
                   (let ([ok (try
                              (lambda ()
                                (and (fx= (c2-htsize clone) (c2-htsize x))
                                     (let ([ks (c-htkeys clone)])
                                       (let lp ([i 0])
                                         (cond
                                           [(fx>= i (vector-length ks)) #t]
                                           [(let ([k (vector-ref ks i)])
                                              (and (c-htcontains? x k)
                                                   (eq? (c-htref x k MISSING)
                                                        (c-htref clone k MISSING))))
                                            (lp (fx+ i 1))]
                                           [else #f])))))
                              #f)])
                     (if ok
                         (set! n-ok (fx+ n-ok 1))
                         (begin (set! n-bad (fx+ n-bad 1))
                                (o "  replay MISMATCH: " (p2-path/trunc x 160)
                                   "  clone-sz=" (c2-htsize clone) " live-sz=" (c2-htsize x)))))])))]))
       )
     containers)
    (o "  replay equivalence (ht containers): OK=" n-ok " MISMATCH=" n-bad
       " non-ht(slot,by-construction)=" n-skipped)))
