;; ===== P3 naming engine: cross-process external naming (pure Chez, pre-import) =====
;; Loaded after p1.head.ss / p1.engine.ss / p2.writeset.ss, before (import ...).
;; Provides:
;;   n3-scan!        structured-parent scan of the pre-boot heap (mark point)
;;   n3-encode       object -> locator (edge chain from one of the 8 roots)
;;   n3-resolve      locator -> object (process B, walks edges from its own roots)
;;   dw-walk!        deterministic post-init walk assigning cross-process code names
;;   manifest helpers for kw / rmp / eqvht externals

;; --- extra captured primitives (pre-import, clean Chez) ---
(define c3-ofop open-file-output-port)
(define c3-ofip open-file-input-port)
(define c3-putbv put-bytevector)
(define c3-getbvall get-bytevector-all)
(define c3-closep close-port)
(define c3-fo (file-options no-fail))
(define c3-symstr symbol->string)
(define c3-equalhash equal-hash)
(define c3-equalpred equal?)
(define c3-htweak? (lambda (h) (try (lambda () (hashtable-weak? h)) #f)))
(define c3-mkweqv make-weak-eqv-hashtable)
(define c3-rtd? record-type-descriptor?)
(define c3-gensym2 gensym)                 ; (gensym pretty unique) re-interns by unique name
(define c3-rtypeuid record-type-uid)
(define c3-guniq gensym->unique-string)

(define (p3-rtd-spec x)   ; -> (pretty . unique) for nongenerative-registered rtds
  (try (lambda ()
         (let ([uid (c3-rtypeuid x)])
           (and (gensym? uid)
                (cons (symbol->string uid) (c3-guniq uid)))))
       #f))

(define ($rtd-by-uid pretty unique)  ; B side: uid gensym -> registered rtd
  (try (lambda ()
         (let ([g (c3-gensym2 pretty unique)])
           (#%$sgetprop g '*rtd* #f)))
       #f))
(define ($rset! r i v) (#%$record-set! r i v))
(define ($stset! s i v) (#%$stencil-vector-set! s i v))
(define ($codearity c) (try (lambda () (#%$code-arity-mask c)) 'noar))

(define (p3-write-bv-file! path bv)
  (let ([p (c3-ofop path c3-fo)])
    (c3-putbv p bv)
    (c3-closep p)))
(define (p3-read-bv-file path)
  (let* ([p (c3-ofip path)]
         [bv (c3-getbvall p)])
    (c3-closep p)
    bv))
(define (p3-fasl-to-file! path obj)
  (let ([p (c3-ofop path c3-fo)])
    (c-faslw obj p)
    (c3-closep p)))
(define (p3-fasl-from-file path)
  (let* ([bv (p3-read-bv-file path)]
         [ip (c-obvip bv)])
    (c-faslr ip)))

;; --- record classifiers ---
(define (p3-plainrec? v) (and ($rec? v) (not (hashtable? v))))
(define (p3-kw? v) (and (p3-plainrec? v) (eq? (rtd-name v) 'keyword)))
(define (p3-rmp? v) (and (p3-plainrec? v) (eq? (rtd-name v) 'resolved-module-path)))
(define (p3-path? v) (and (p3-plainrec? v) (eq? (rtd-name v) 'path)))

(define (p3-kw-str x)      ; keyword record field 0 = interned symbol
  (let ([f (try (lambda () ($rref x 0)) #f)])
    (cond
      [(symbol? f) (c3-symstr f)]
      [(string? f) f]
      [else #f])))

;; rmp name spec: symbol | path | (cons base (listof symbol))
(define (p3-rmp-name-spec x)   ; -> encoded spec or #f
  (define (enc-name n)
    (cond
      [(symbol? n) (vector 'sym n)]
      [(p3-path? n)
       (let ([b (try (lambda () ($rref n 0)) #f)])
         (and (bytevector? b) (vector 'pth b)))]
      [(pair? n)
       (let ([base (enc-name (car n))])
         (and base (andmap-sym? (cdr n)) (vector 'lst base (cdr n))))]
      [else #f]))
  (define (andmap-sym? l)
    (or (null? l) (and (pair? l) (symbol? (car l)) (andmap-sym? (cdr l)))))
  (let ([f (try (lambda () ($rref x 0)) #f)])
    (and f (enc-name f))))

;; ---------- structured-parent scan (mark point; pass 1 = no ht-key enqueue) ----------
(define n3-parent (make-eq-hashtable))  ; obj -> (cons parent edge) | (cons #f root-index)
(define n3-seen (make-eq-hashtable))
(define n3-count 0)

(define (n3-leafish? x) (or (symbol? x) (string? x) (bytevector? x)))

(define (n3-kids obj)  ; -> list of (edge . child); ht KEYS are not enqueued
  (cond
    [(procedure? obj)
     (cond
       [($cont? obj) '()]
       [(safe-clen obj)
        => (lambda (n)
             (let ([cd (try (lambda () ($ccode obj)) #f)])
               (let loop ([i 0] [acc (if cd (list (cons '(cc) cd)) '())])
                 (if (fx>= i n)
                     (reverse acc)
                     (loop (fx+ i 1) (cons (cons (cons 'c i) ($cref obj i)) acc))))))]
       [else '()])]
    [(hashtable? obj)
     ;; hv edges MUST be enumerated in a deterministic order: c-htkeys order
     ;; is address-dependent, and n3-scan!'s first-wins parent assignment
     ;; turns enumeration order into locator-path content (measured: 83 loc
     ;; entries flipping between r:y:#%boot and r:p:<path> routes per run).
     ;; Sort by the key's stable string; keys without one sort last by their
     ;; printed form (deterministic for interned data, best-effort otherwise).
     (let ([ks (c-htkeys obj)])
       (let loop ([i 0] [acc '()])
         (if (fx>= i (vector-length ks))
             ;; sort by key string for determinism. Tied groups (e.g. several
             ;; thread keys all printing "#<thread>") KEEP their address order:
             ;; dropping them was tried and BROKE semantics -- 4 loc names for
             ;; thread-cell-table residents were lost, those pre-existing cells
             ;; got copied into the segment, and B's evaluation lost its
             ;; parameterization (#%app unbound, 0/8). The residual ~23-entry
             ;; route flip between runs is semantically harmless: both routes
             ;; resolve on B (loc 1237/1237, acceptance unaffected).
             (map cdr
                  (c-sort (lambda (a b) (string<? (car a) (car b)))
                          (map (lambda (ec)
                                 (let ([k (cdr (car ec))])
                                   (cons (or (try (lambda () (dw-stable-str k 3)) #f)
                                             (string-append
                                              "~zz:" (try (lambda () (trunc (c-fmt "~s" k) 200))
                                                          "?")))
                                         ec)))
                               acc)))
             (let ([k (vector-ref ks i)])
               (loop (fx+ i 1)
                     (cons (cons (cons 'hv k) (c-htref obj k #f)) acc))))))]
    [($rec? obj)
     (let ([n (rtd-total-fields ($rtd obj))])
       (let loop ([i 0] [acc '()])
         (if (fx>= i n)
             (reverse acc)
             (loop (fx+ i 1)
                   (cons (cons (cons 'r i) (try (lambda () ($rref obj i)) 'UNREADABLE)) acc)))))]
    [(pair? obj) (list (cons 'a (car obj)) (cons 'd (cdr obj)))]
    [($stvec? obj)
     (let ([n ($stlen obj)])
       (let loop ([i 0] [acc '()])
         (if (fx>= i n)
             (reverse acc)
             (loop (fx+ i 1)
                   (cons (cons (cons 's i) (try (lambda () ($stref obj i)) 'UNREADABLE)) acc)))))]
    [(box? obj) (list (cons 'u (unbox obj)))]
    [(vector? obj)
     (let ([n (vector-length obj)])
       (let loop ([i 0] [acc '()])
         (if (fx>= i n)
             (reverse acc)
             (loop (fx+ i 1) (cons (cons (cons 'v i) (vector-ref obj i)) acc)))))]
    [else '()]))

(define n3-parent2 (make-eq-hashtable)) ; first alternate parent edge
(define n3-tables '())                  ; visited chez hashtables (for key pass 2)

(define (n3-reset!)  ; fresh scan state (e.g. re-scan post-init heap)
  (set! n3-parent (make-eq-hashtable))
  (set! n3-parent2 (make-eq-hashtable))
  (set! n3-seen (make-eq-hashtable))
  (set! n3-tables '())
  (set! n3-count 0)
  (set! n3-enc-cache (make-eq-hashtable))
  (set! n3-inprog (make-eq-hashtable)))

(define (n3-scan! rootvec cap)
  (define qf '()) (define qb '())
  (define (enq! x) (set! qb (cons x qb)))
  (define (deq!)
    (when (null? qf) (set! qf (reverse qb)) (set! qb '()))
    (let ([x (car qf)]) (set! qf (cdr qf)) x))
  (define (empty?) (and (null? qf) (null? qb)))
  (let lp ([i 0])
    (when (fx< i (vector-length rootvec))
      (let ([x (vector-ref rootvec i)])
        (when (and (heapish? x) (not (eq-hashtable-ref n3-seen x #f)))
          (eq-hashtable-set! n3-seen x #t)
          (eq-hashtable-set! n3-parent x (cons #f i))
          (enq! x)))
      (lp (fx+ i 1))))
  (let loop ()
    (unless (or (empty?) (fx>= n3-count cap))
      (let ([obj (deq!)])
        (set! n3-count (fx+ n3-count 1))
        (when (hashtable? obj) (set! n3-tables (cons obj n3-tables)))
        (for-each
         (lambda (ec)
           (let ([edge (car ec)] [child (cdr ec)])
             (cond
               [(eq? child 'UNREADABLE) (void)]
               [(heapish? child)
                (cond
                  [(not (eq-hashtable-ref n3-seen child #f))
                   (eq-hashtable-set! n3-seen child #t)
                   (eq-hashtable-set! n3-parent child (cons obj edge))
                   (enq! child)]
                  [(not (eq-hashtable-ref n3-parent2 child #f))
                   (eq-hashtable-set! n3-parent2 child (cons obj edge))])]
               [(or (n3-leafish? child) ($code? child))
                (cond
                  [(not (eq-hashtable-ref n3-parent child #f))
                   (eq-hashtable-set! n3-parent child (cons obj edge))]
                  [(not (eq-hashtable-ref n3-parent2 child #f))
                   (eq-hashtable-set! n3-parent2 child (cons obj edge))])]
               [else (void)])))
         (try (lambda () (n3-kids obj)) '())))
      (loop)))
  ;; ---- pass 2: give hashtable KEYS a locator parent (hk = find-key-by-spec) ----
  (for-each
   (lambda (t)
     (for-each
      (lambda (k)
        (when (and (or (heapish? k) (n3-leafish? k))
                   (not (eq-hashtable-ref n3-parent k #f)))
          (let ([s (try (lambda () (dw-stable-str k 3)) #f)])
            (when s
              (eq-hashtable-set! n3-parent k (cons t (cons 'hk (cons 'sm s))))))))
      (vector->list (try (lambda () (c-htkeys t)) (vector)))))
   n3-tables)
  n3-count)

;; ---------- locator encoding (A side) ----------
(define n3-enc-cache (make-eq-hashtable))  ; obj -> edges | 'FAIL
(define n3-inprog (make-eq-hashtable))

(define (n3-eqsafe-atom? k)
  (or (fixnum? k) (char? k) (boolean? k) (null? k)
      (and (symbol? k) (not (gensym? k)))))

(define (n3-key-spec k depth)
  (cond
    [(n3-eqsafe-atom? k) (cons 'sa k)]
    [(try (lambda () (dw-stable-str k 3)) #f)
     => (lambda (s) (cons 'sm s))]
    [(fx<= depth 0) #f]
    [else (let ([e (n3-encode k (fx- depth 1))])
            (and e (cons 'sl e)))]))

(define (n3-edge-enc edge depth)
  (cond
    [(and (pair? edge) (eq? (car edge) 'hv))
     (let ([ks (n3-key-spec (cdr edge) depth)])
       (and ks (cons 'hv ks)))]
    [else edge]))   ; (r . i) (v . i) (c . i) (s . i) (hk . spec) a d u

(define (n3-encode obj depth)
  (let ([hit (eq-hashtable-ref n3-enc-cache obj 'none)])
    (cond
      [(not (eq? hit 'none)) (if (eq? hit 'FAIL) #f hit)]
      [(eq-hashtable-ref n3-inprog obj #f) #f]
      [else
       (eq-hashtable-set! n3-inprog obj #t)
       (let* ([try-pr
               (lambda (pr)
                 (and pr
                      (if (not (car pr))
                          (list (cons 'root (cdr pr)))
                          (let ([pc (n3-encode (car pr) depth)])
                            (and pc
                                 (let ([ee (n3-edge-enc (cdr pr) depth)])
                                   (and ee (append pc (list ee)))))))))]
              [r (or (try-pr (eq-hashtable-ref n3-parent obj #f))
                     (try-pr (eq-hashtable-ref n3-parent2 obj #f)))])
         (eq-hashtable-delete! n3-inprog obj)
         (eq-hashtable-set! n3-enc-cache obj (if r r 'FAIL))
         r)])))

;; ---------- locator resolution (B side; needs only its own root vector) ----------
(define N3FAIL (gensym "n3fail"))
(define N3MISS (gensym "n3miss"))

(define (n3-find-key T spec)
  ;; unique key of T matching spec -> key object | #f
  (let ([ks (try (lambda () (c-htkeys T)) #f)])
    (and ks
         (let lp ([i 0] [found 'none])
           (if (fx>= i (vector-length ks))
               (if (eq? found 'none) #f found)
               (let* ([k (vector-ref ks i)]
                      [m (case (car spec)
                           [(sa) (let ([v (cdr spec)])
                                   (or (eqv? k v)
                                       (and (string? k) (string? v) (c2-str=? k v))))]
                           [(sm) (let ([s (try (lambda () (dw-stable-str k 3)) #f)])
                                   (and s (c2-str=? s (cdr spec))))]
                           [else #f])])
                 (cond
                   [(not m) (lp (fx+ i 1) found)]
                   [(eq? found 'none) (lp (fx+ i 1) k)]
                   [else #f])))))))

(define (n3-resolve edges rootvec)
  ;; -> (cons 'ok obj) | (cons 'fail (why . edge-index))
  (call/cc
   (lambda (k)
     (define idx 0)
     (define (bad why) (k (cons 'fail (cons why idx))))
     (let loop ([es edges] [cur #f])
       (cond
         [(null? es) (cons 'ok cur)]
         [else
          (set! idx (fx- (length edges) (length es)))
          (let* ([e (car es)]
                 [nxt
                  (cond
                    [(and (pair? e) (eq? (car e) 'root))
                     (if (fx< (cdr e) (vector-length rootvec))
                         (vector-ref rootvec (cdr e))
                         (bad 'root-idx))]
                    [(eq? e 'a) (if (pair? cur) (car cur) (bad 'car))]
                    [(eq? e 'd) (if (pair? cur) (cdr cur) (bad 'cdr))]
                    [(eq? e 'u) (if (box? cur) (unbox cur) (bad 'unbox))]
                    [(pair? e)
                     (case (car e)
                       [(r) (let ([v (try (lambda () ($rref cur (cdr e))) N3FAIL)])
                              (if (eq? v N3FAIL) (bad 'rref) v))]
                       [(v) (if (and (vector? cur) (fx< (cdr e) (vector-length cur)))
                                (vector-ref cur (cdr e))
                                (bad 'vref))]
                       [(c) (let ([v (try (lambda () ($cref cur (cdr e))) N3FAIL)])
                              (if (eq? v N3FAIL) (bad 'cref) v))]
                       [(s) (let ([v (try (lambda () ($stref cur (cdr e))) N3FAIL)])
                              (if (eq? v N3FAIL) (bad 'sref) v))]
                       [(hv)
                        (if (not (hashtable? cur))
                            (bad 'not-ht)
                            (let* ([ks (cdr e)]
                                   [kv (case (car ks)
                                         [(sa) (cdr ks)]
                                         [(sm) (let ([k (n3-find-key cur ks)])
                                                 (or k (bad 'key-sm)))]
                                         [(sl) (let ([r (n3-resolve (cdr ks) rootvec)])
                                                 (if (eq? (car r) 'ok) (cdr r) (bad 'key)))]
                                         [else (bad 'keyspec)])])
                              (let ([v (try (lambda () (c-htref cur kv N3MISS)) N3MISS)])
                                (if (eq? v N3MISS) (bad 'htmiss) v))))]
                       [(hk)
                        (if (hashtable? cur)
                            (let ([k (n3-find-key cur (cdr e))])
                              (or k (bad 'hk)))
                            (bad 'not-ht))]
                       [(cc)
                        (let ([v (try (lambda () ($ccode cur)) N3FAIL)])
                          (if (or (eq? v N3FAIL) (not ($code? v))) (bad 'ccode) v))]
                       [else (bad 'edge)])]
                    [else (bad 'edge)])])
            (loop (cdr es) nxt))])))))

;; ---------- deterministic post-init walk: cross-process code identity ----------
(define dw-codetab (make-eq-hashtable))            ; code -> (key . occ)     [A side use]
(define dw-classes (make-hashtable equal-hash equal?)) ; key -> reversed code list [B side use]
(define dw-nodes 0)
(define dw-ncodes 0)

(define (dw-code-key c)
  (let ([nm (let ([n (code-name c)]) (if (string? n) n (c-fmt "~a" n)))]
        [ar ($codearity c)])
    (c2-sapp nm "|" (c-fmt "~a" ar))))

(define (dw-stable-str x depth)
  (cond
    [(and (symbol? x) (not (gensym? x))) (c2-sapp "y:" (c3-symstr x))]
    [(symbol? x) #f]  ; gensym: unique name differs across processes
    [(fixnum? x) (c-fmt "i:~a" x)]
    [(number? x) (c-fmt "n:~s" x)]
    [(char? x) (c-fmt "c:~s" x)]
    [(boolean? x) (if x "b:t" "b:f")]
    [(null? x) "nil"]
    [(string? x) (c2-sapp "s:" x)]
    [(bytevector? x) (c-fmt "B:~s" x)]
    [(p3-kw? x) (let ([s (p3-kw-str x)]) (and s (c2-sapp "k:" s)))]
    [(p3-path? x)
     (let ([b (try (lambda () ($rref x 0)) #f)])
       (and (bytevector? b) (c-fmt "p:~s" b)))]
    [(p3-rmp? x)
     (and (fx> depth 0)
          (let ([f (try (lambda () ($rref x 0)) #f)])
            (and f (let ([s (dw-stable-str f (fx- depth 1))]) (and s (c2-sapp "r:" s))))))]
    [(pair? x)
     (and (fx> depth 0) (not (weak-pair? x)) (not (ephemeron-pair? x))
          (let ([a (dw-stable-str (car x) (fx- depth 1))])
            (and a (let ([d (dw-stable-str (cdr x) (fx- depth 1))])
                     (and d (c2-sapp "(" a " . " d ")"))))))]
    [(and (vector? x) (fx<= (vector-length x) 8))
     (and (fx> depth 0)
          (let lp ([i 0] [acc "#("])
            (if (fx>= i (vector-length x))
                (c2-sapp acc ")")
                (let ([s (dw-stable-str (vector-ref x i) (fx- depth 1))])
                  (and s (lp (fx+ i 1) (c2-sapp acc s " ")))))))]
    [else #f]))

(define dw-leaf-recs '(thread custodian will-executor weak-box ephemeron))

(define (dw-node? x) (or (heapish? x) ($code? x)))

;; reloc traversal is only safe at the mark point: with retained static
;; relocation the GC does NOT update static reloc tables, so after any
;; collection their entries that point into movable generations dangle
;; (measured: post-attach scope-census crash, d72-d85)
(define dw-reloc-ok #t)
(define (dw-kids obj)
  (cond
    [($code? obj)
     (if dw-reloc-ok
         (let ([r (try (lambda () (dw-get-reloc obj #f)) '())])
           (if (list? r) r '()))
         '())]
    [(procedure? obj)
     (cond
       [($cont? obj) '()]
       [(safe-clen obj)
        => (lambda (n)
             (let ([cd (try (lambda () ($ccode obj)) #f)])
               (let loop ([i (fx- n 1)] [acc (if cd (list cd) '())])
                 (if (fx< i 0)
                     acc
                     (loop (fx- i 1) (cons ($cref obj i) acc))))))]
       [else '()])]
    [(hashtable? obj)
     (if (or (c3-htweak? obj)
             (and (eq-hashtable? obj)
                  (or (try (lambda () (c-eqweak? obj)) #f)
                      (try (lambda () (c-eqeph? obj)) #f))))
         '()
         (let* ([ks (c-htkeys obj)] [n (vector-length ks)])
           (let loop ([i 0] [acc '()])
             (if (fx>= i n)
                 (let* ([sorted (c-sort (lambda (a b) (string<? (car a) (car b))) acc)]
                        ;; drop groups of tied stable-keys entirely (both sides deterministic)
                        [pruned
                         (let lp ([l sorted] [out '()])
                           (cond
                             [(null? l) (reverse out)]
                             [(and (pair? (cdr l)) (string=? (car (car l)) (car (cadr l))))
                              (let ([s (car (car l))])
                                (let skip ([l l])
                                  (if (and (pair? l) (string=? (car (car l)) s))
                                      (skip (cdr l))
                                      (lp l out))))]
                             [else (lp (cdr l) (cons (car l) out))]))])
                   (apply append
                          (map (lambda (e) (list (cadr e) (cddr e))) pruned)))
                 (let* ([k (vector-ref ks i)]
                        [s (try (lambda () (dw-stable-str k 3)) #f)])
                   (loop (fx+ i 1)
                         (if s
                             (cons (cons s (cons k (c-htref obj k #f))) acc)
                             acc)))))))]
    [($rec? obj)
     (cond
       [(memq (rtd-name obj) dw-leaf-recs) '()]
       [(memq (rtd-name obj) '(eq-mutable-hash mutable-hash weak-mutable-hash))
        ;; racket mutable hashes carry an internal bucket vector + pair
        ;; chains ordered by INSERTION (process-local!). Only descend into
        ;; the Chez hashtable field, which dw-kids enumerates sorted.
        ;; (measured: walk fingerprints diverging at a bucket pair, d97-d100)
        (let ([n (rtd-total-fields ($rtd obj))])
          (let loop ([i (fx- n 1)] [acc '()])
            (if (fx< i 0)
                acc
                (loop (fx- i 1)
                      (let ([v (try (lambda () ($rref obj i)) 'UNREADABLE)])
                        (if (hashtable? v) (cons v acc) acc))))))]
       [else
        (let ([n (rtd-total-fields ($rtd obj))])
          (let loop ([i (fx- n 1)] [acc '()])
            (if (fx< i 0)
                acc
                (loop (fx- i 1) (cons (try (lambda () ($rref obj i)) 'UNREADABLE) acc)))))])]
    [(and (pair? obj) (or (weak-pair? obj) (ephemeron-pair? obj))) '()]
    [(pair? obj) (list (car obj) (cdr obj))]
    [($stvec? obj)
     (let ([n ($stlen obj)])
       (let loop ([i (fx- n 1)] [acc '()])
         (if (fx< i 0)
             acc
             (loop (fx- i 1) (cons (try (lambda () ($stref obj i)) 'UNREADABLE) acc)))))]
    [(box? obj) (list (unbox obj))]
    [(vector? obj)
     (let ([n (vector-length obj)])
       (let loop ([i (fx- n 1)] [acc '()])
         (if (fx< i 0)
             acc
             (loop (fx- i 1) (cons (vector-ref obj i) acc)))))]
    [else '()]))

(define scope-name-histo (make-hashtable equal-hash equal?))
;; scope-proper identity registry: (name . id-key) -> this heap's object.
;; scope ids are allocated by a deterministic boot-time counter; A and B
;; run byte-identical paths up to the mark point, so same-role singletons
;; carry the same id in both heaps. shifted-multi-scope has no id of its
;; own: it is interned on (phase . multi-scope), so its key uses the
;; owning multi-scope's id.
(define native-scope-tab (make-eq-hashtable))  ; every scope-proper object in THIS heap at mark
(define iscope-tab (make-hashtable equal-hash equal?))
(define (iscope-lookup k) (c-htref iscope-tab k #f))
(define (scope-proper-key x)
  ;; -> (cons name key) for the five scope-proper rtds, else #f
  (let ([nm (try (lambda () (rtd-name x)) #f)])
    (case nm
      [(scope interned-scope representative-scope multi-scope)
       (cons nm (try (lambda () (#%$record-ref x 0)) #f))]
      [(shifted-multi-scope)
       (let* ([ph (try (lambda () (#%$record-ref x 0)) #f)]
              [ms (try (lambda () (#%$record-ref x 1)) #f)]
              [msid (and ms ($rec? ms)
                         (try (lambda () (#%$record-ref ms 0)) #f))])
         (cons nm (cons ph msid)))]
      [else #f])))

;; standalone scope census: walk from roots with a fresh seen-table and
;; collect (id kind extra) triples for every scope-proper record found.
;; run before/after an eval burst to detect freshly deserialized scopes.
(define (scope-census rootvec)
  (define seen (make-eq-hashtable))
  (define out '())
  (define stack '())
  (let lp ([i (fx- (vector-length rootvec) 1)])
    (when (fx>= i 0)
      (set! stack (cons (vector-ref rootvec i) stack))
      (lp (fx- i 1))))
  (let loop ()
    (unless (null? stack)
      (let ([x (car stack)])
        (set! stack (cdr stack))
        (when (and (dw-node? x) (not (eq-hashtable-ref seen x #f)))
          (eq-hashtable-set! seen x #t)
          (when ($rec? x)
            (let ([nm (try (lambda () (rtd-name x)) #f)])
              (when (memq nm '(scope interned-scope representative-scope
                               multi-scope shifted-multi-scope))
                (set! out (cons (cons x
                                      (list nm
                                            (try (lambda () (#%$record-ref x 0)) '?)
                                            (try (lambda () (#%$record-ref x 1)) '?)))
                                out)))))
          (let ([kids (try (lambda () (dw-kids x)) '())])
            (let push ([ks kids])
              (unless (null? ks)
                (when (dw-node? (car ks))
                  (set! stack (cons (car ks) stack)))
                (push (cdr ks)))))))
      (loop)))
  out)

(define (neg-scope-count rootvec)
  ;; count of negative-id scope-proper objects reachable from roots
  (let ([n 0])
    (for-each (lambda (pr)
                (let ([id (cadr (cdr pr))])
                  (when (and (number? id) (negative? id))
                    (set! n (fx+ n 1)))))
              (scope-census rootvec))
    n))

;; ---- rumble eq-hash-code `codes` table access (h7 sync) ----
;; The table maps obj -> per-process registration number; racket hasheq
;; HAMTs are organized by these numbers, so a fasl-migrated HAMT is only
;; navigable on B if B's codes table agrees for every key that A had
;; registered when building the HAMT. Locate the (library-internal) table
;; through the collect-request-handler closure, which captures rumble's
;; update-eq-hash-code-table-size!.
(define (find-eq-code-table)
  (let ([seen (make-eq-hashtable)]
        [hit #f])
    (let bfs ([q (list (collect-request-handler))] [n 0])
      (unless (or hit (null? q) (fx> n 60000))
        (let ([x (car q)])
          (cond
            [(eq-hashtable-ref seen x #f) (bfs (cdr q) (fx+ n 1))]
            [else
             (eq-hashtable-set! seen x #t)
             (if (and (hashtable? x) (eq-hashtable? x)
                      (try (lambda () (hashtable-weak? x)) #f)
                      (fx> (hashtable-size x) 0)
                      (let-values ([(ks vs) (hashtable-entries x)])
                        (let lp ([i 0] [ok #t])
                          (if (or (not ok) (fx>= i (fxmin (vector-length vs) 30)))
                              ok
                              (lp (fx+ i 1) (fixnum? (vector-ref vs i)))))))
                 (set! hit x)
                 (let ([kids
                        (cond
                          [(and (procedure? x) (not ($cont? x)) (safe-clen x))
                           => (lambda (len)
                                (let lp ([i 0] [acc '()])
                                  (if (fx>= i len) acc
                                      (lp (fx+ i 1) (cons ($cref x i) acc)))))]
                          [(pair? x) (list (car x) (cdr x))]
                          [(vector? x) (vector->list x)]
                          [(box? x) (list (unbox x))]
                          [else '()])])
                   (bfs (append kids (cdr q)) (fx+ n 1))))]))))
    hit))

;; reloc-table access: a code object's constant-pool heap references.
;; This lets the deterministic walk penetrate library statics (expander/
;; rumble internal codes reachable only through other codes' constants).
(define dw-get-reloc
  (foreign-procedure "(cs)s_get_reloc" (scheme-object boolean) scheme-object))

;; ---- static-generation address identity ('staddr) ----
;; A/B boot from identical files; the static generation's layout is
;; process-invariant up to a single base shift (measured: anchor-relative
;; fxaddress offsets identical across runs, including across boot files).
;; Identity = (delta . tag): delta = fxaddress difference from the anchor
;; (car's code), tag = low ptr bits recovered by A-side roundtrip
;; self-check; ptr = ((anchor+delta) << 3) | tag.
(define staddr-fxaddr ($primitive $fxaddress))
(define staddr-a2o ($primitive $address->object))
(define staddr-gen ($primitive $generation))
(define staddr-anchor (staddr-fxaddr ($ccode car)))
(define (staddr-static? x)
  (and (heapish? x) (try (lambda () (eqv? (staddr-gen x) 7)) #f)))
(define (staddr-spec x)
  ;; -> (delta . tag) with roundtrip proof, else #f
  (let ([fa (staddr-fxaddr x)])
    (let tagloop ([tag 0])
      (cond
        [(fx> tag 7) #f]
        [(try (lambda ()
                (eq? (staddr-a2o (fxlogor (fxsll fa 3) tag) 0) x))
              #f)
         (cons (fx- fa staddr-anchor) tag)]
        [else (tagloop (fx+ tag 1))]))))
(define (staddr-resolve delta tag)
  (try (lambda ()
         (staddr-a2o (fxlogor (fxsll (fx+ staddr-anchor delta) 3) tag) 0))
       #f))

(define dw-parent-obj (make-eq-hashtable))  ; child obj -> first parent obj
(define dw-obj-seq (make-eq-hashtable))   ; obj -> walk seq (cross-process library-domain identity)
(define dw-seq-obj (make-hashtable equal-hash equal?)) ; seq -> obj

(define dw-extra-roots (vector))  ; extra dw-walk roots (kernel primitive closures)

;; ---- module-instance hunter (phase table route) ----
(define (p33-substr? hay needle)
  (let ([hl (string-length hay)] [nl (string-length needle)])
    (let srch ([i 0])
      (and (fx<= (fx+ i nl) hl)
           (or (string=? (substring hay i (fx+ i nl)) needle)
               (srch (fx+ i 1)))))))
(define (p33-rmp-path-matches? k path-substr)
  (and ($rec? k)
       (let ([nm (try (lambda () (#%$record-ref k 0)) #f)])
         (and ($rec? nm)
              (let ([bv (try (lambda () (#%$record-ref nm 0)) #f)])
                (and (bytevector? bv)
                     (p33-substr? (try (lambda () (utf8->string bv)) "")
                                  path-substr)))))))
(define (p33-find-minsts ns path-substr)
  ;; -> list of (phase-key . module-instance) from ns.f16
  (let* ([mi (try (lambda () (#%$record-ref ns 16)) #f)]
         [mih (and mi ($rec? mi) (try (lambda () (#%$record-ref mi 3)) #f))]
         [out '()])
    (when (hashtable? mih)
      (let ([ks (c-htkeys mih)])
        (let f ([i 0])
          (when (fx< i (vector-length ks))
            (let* ([pk (vector-ref ks i)]
                   [pv (c-htref mih pk #f)])
              (cond
                [(p33-rmp-path-matches? pk path-substr)
                 (set! out (cons (cons 'union pv) out))]
                [(and ($rec? pv)
                      (eq? (try (lambda () (rtd-name pv)) #f) 'eq-mutable-hash))
                 (let ([inner (try (lambda () (#%$record-ref pv 3)) #f)])
                   (when (hashtable? inner)
                     (let ([iks (c-htkeys inner)])
                       (let g ([j 0])
                         (when (fx< j (vector-length iks))
                           (when (p33-rmp-path-matches? (vector-ref iks j) path-substr)
                             (set! out (cons (cons pk (c-htref inner (vector-ref iks j) #f))
                                             out)))
                           (g (fx+ j 1)))))))]
                [else (void)]))
            (f (fx+ i 1))))))
    out))
(define (p33-hunt-vars o root needle tag maxd)
  ;; walk root (record fields + closure fvs + pairs/vectors, depth maxd),
  ;; dump matching variables in any instance's variable table
  (let ([seen (make-eq-hashtable)])
    (define (dump-inst inst label)
      (let* ([ih (try (lambda () (#%$record-ref inst 2)) #f)]
             [iht (and ih ($rec? ih) (try (lambda () (#%$record-ref ih 3)) #f))])
        (when (hashtable? iht)
          (let ([ks (c-htkeys iht)])
            (let f ([i 0])
              (when (fx< i (vector-length ks))
                (let* ([k (vector-ref ks i)]
                       [kstr (try (lambda () (symbol->string k)) "")])
                  (when (p33-substr? kstr needle)
                    (let* ([var (c-htref iht k #f)]
                           [val (try (lambda () (#%$record-ref var 0)) '?)])
                      (o "  [" tag "] " label " " k " = " (obj-brief val)
                         (if (and (procedure? val) (not ($cont? val)))
                             (let ([cd (try (lambda () ($ccode val)) #f)])
                               (c-fmt "  code=~a clen=~a gen=~a"
                                      (try (lambda () (code-name cd)) '?)
                                      (safe-clen val)
                                      (try (lambda () (staddr-gen cd)) '?)))
                             "")))))
                (f (fx+ i 1))))))))
    (let walk ([x root] [label "r"] [d 0])
      (when (and (fx< d maxd) (heapish? x) (not (eq-hashtable-ref seen x #f)))
        (eq-hashtable-set! seen x #t)
        (when (and ($rec? x) (eq? (try (lambda () (rtd-name x)) #f) 'instance))
          (dump-inst x label))
        (cond
          [($rec? x)
           (let ([n (try (lambda () (rtd-total-fields ($rtd x))) 0)])
             (let f ([i 0])
               (when (fx< i n)
                 (walk (try (lambda () (#%$record-ref x i)) #f)
                       (c-fmt "~a.f~a" label i) (fx+ d 1))
                 (f (fx+ i 1)))))]
          [(and (procedure? x) (not ($cont? x)) (safe-clen x))
           => (lambda (cn)
                (let f ([j 0])
                  (when (fx< j cn)
                    (walk (try (lambda () ($cref x j)) #f)
                          (c-fmt "~a.v~a" label j) (fx+ d 1))
                    (f (fx+ j 1)))))]
          [(pair? x) (walk (car x) label (fx+ d 1)) (walk (cdr x) label (fx+ d 1))]
          [(vector? x)
           (let ([n (vector-length x)])
             (let f ([i 0])
               (when (fx< i (fxmin n 128))
                 (walk (vector-ref x i) (c-fmt "~a.e~a" label i) (fx+ d 1))
                 (f (fx+ i 1)))))]
          [else (void)])))))

(define dw-mark-seen #f)   ; the mark-walk's seen table (all objects @ mark)

(define (dw-walk! rootvec)
  (define seen (make-eq-hashtable))
  (define stack '())
  (set! dw-mark-seen seen)
  (let ([prs (c-sort (lambda (a b) (string<? (car a) (car b)))
                     (vector->list dw-extra-roots))])
    (when (equal? (#%getenv "P33_DWFP") "1")
      (let ([op (c-oof (string-append "/tmp/kp-" (or (#%getenv "P33_ROLE") "?") ".txt")
                       'replace)])
        (for-each (lambda (pr) (c-disp (car pr) op) (c-nl op)) prs)
        (c3-closep op)))
    (for-each (lambda (pr) (set! stack (cons (cdr pr) stack)))
              (reverse prs)))
  (let lp ([i (fx- (vector-length rootvec) 1)])
    (when (fx>= i 0)
      (set! stack (cons (vector-ref rootvec i) stack))
      (lp (fx- i 1))))
  (let loop ()
    (unless (null? stack)
      (let ([x (car stack)])
        (set! stack (cdr stack))
        (when (and (dw-node? x) (not (eq-hashtable-ref seen x #f)))
          (eq-hashtable-set! seen x #t)
          (set! dw-nodes (fx+ dw-nodes 1))
          (eq-hashtable-set! dw-obj-seq x dw-nodes)
          (c2-htset! dw-seq-obj dw-nodes x)
          ;; interned-scope registry: key -> this heap's interned scope
          ;; (expander interns these by symbolic key across unmarshalling;
          ;;  cross-process identity must resolve BY KEY, like rtd uids)
          ;; iscope registry only -- keep this hook allocation-light: the
          ;; walk runs at the mark point and extra allocation here shifts
          ;; GC timing for everything after it (measured segment drift)
          (when ($rec? x)
            (let ([k (scope-proper-key x)])
              (when (and k (cdr k))
                (eq-hashtable-set! native-scope-tab x #t)
                (when (not (c-htref iscope-tab k #f))
                  (c2-htset! iscope-tab k x)))))
          (when ($code? x)
            (set! dw-ncodes (fx+ dw-ncodes 1))
            (let* ([key (dw-code-key x)]
                   [n (c-htref dw-classes key '())])
              (eq-hashtable-set! dw-codetab x (cons key (length n)))
              (c2-htset! dw-classes key (cons x n))))
          (let ([kids (try (lambda () (dw-kids x)) '())])
            (let push ([ks (reverse kids)])
              (unless (null? ks)
                (when (dw-node? (car ks))
                  (unless (eq-hashtable-ref dw-parent-obj (car ks) #f)
                    (eq-hashtable-set! dw-parent-obj (car ks) x))
                  (set! stack (cons (car ks) stack)))
                (push (cdr ks)))))))
      (loop)))
  dw-nodes)

;; After dw-walk!: walk the property-list VALUES of every rtd seen in the
;; mark domain, extending the same seen/codetab/classes state. Boot-static
;; codes referenced only by struct-type-property values (prop:stream,
;; prop:set!-transformer, provide/contract transformers...) become
;; bdw-named this way; both roles run it identically at the mark point.
(define (dw-walk-rtd-plists!)
  (let ([seen dw-mark-seen]
        [rtds '()])
    ;; collect rtds present in the mark domain (as values or as $rtd of recs)
    (let-values ([(ks vs) (hashtable-entries seen)])
      (let lp ([i (fx- (vector-length ks) 1)] [acc '()] [rseen (make-eq-hashtable)])
        (if (fx< i 0)
            (set! rtds acc)
            (let* ([x (vector-ref ks i)]
                   [r (cond
                        [(c3-rtd? x) x]
                        [($rec? x) (try (lambda () ($rtd x)) #f)]
                        [else #f])])
              (if (and r (not (eq-hashtable-ref rseen r #f)))
                  (begin
                    (eq-hashtable-set! rseen r #t)
                    (lp (fx- i 1) (cons r acc) rseen))
                  (lp (fx- i 1) acc rseen))))))
    ;; sort rtds by (uid unique-string) for deterministic walk order
    (let* ([keyed (map (lambda (r)
                         (cons (or (try (lambda ()
                                          (let ([u (c3-rtypeuid r)])
                                            (if (gensym? u) (c3-guniq u)
                                                (symbol->string u))))
                                        #f)
                                   "~")
                               r))
                       rtds)]
           [sorted (map cdr (c-sort (lambda (a b) (string<? (car a) (car b))) keyed))]
           [stack '()]
           [n0 dw-nodes])
      (for-each
       (lambda (r)
         (let ([pl (try (lambda () (#%property-list (c3-rtypeuid r))) '())])
           (let lp ([l pl])
             (when (and (pair? l) (pair? (cdr l)))
               (set! stack (cons (cadr l) stack))
               (lp (cddr l))))))
       (reverse sorted))
      (let loop ()
        (unless (null? stack)
          (let ([x (car stack)])
            (set! stack (cdr stack))
            (when (and (dw-node? x) (not (eq-hashtable-ref seen x #f)))
              (eq-hashtable-set! seen x #t)
              (set! dw-nodes (fx+ dw-nodes 1))
              (eq-hashtable-set! dw-obj-seq x dw-nodes)
              (c2-htset! dw-seq-obj dw-nodes x)
              (when ($code? x)
                (set! dw-ncodes (fx+ dw-ncodes 1))
                (let* ([key (dw-code-key x)]
                       [n (c-htref dw-classes key '())])
                  (eq-hashtable-set! dw-codetab x (cons key (length n)))
                  (c2-htset! dw-classes key (cons x n))))
              ;; also register codes OF closures (dw-kids includes $ccode)
              (let ([kids (try (lambda () (dw-kids x)) '())])
                (let push ([ks (reverse kids)])
                  (unless (null? ks)
                    (when (dw-node? (car ks))
                      (set! stack (cons (car ks) stack)))
                    (push (cdr ks)))))))
          (loop)))
      (fx- dw-nodes n0))))

;; walk-order fingerprint: one line per seq -> type/name digest, for A/B diff
(define (dw-dump-fingerprint! path)
  (let ([op (c-oof path 'replace)])
    (let ([n dw-nodes])
      (let f ([i 1])
        (when (fx<= i n)
          (let ([x (c-htref dw-seq-obj i #f)])
            (c-disp i op) (c-disp " " op)
            (c-disp "p" op)
            (c-disp (let ([po (eq-hashtable-ref dw-parent-obj x #f)])
                      (if po (or (eq-hashtable-ref dw-obj-seq po #f) '?) 'root))
                    op)
            (c-disp " " op)
            (c-disp
             (try (lambda ()
                    (cond
                      [($code? x) (c-fmt "code:~a" (code-name x))]
                      [(procedure? x) (c-fmt "clos:~a/~a" ($cname x) (safe-clen x))]
                      [($rec? x) (c-fmt "rec:~a" (rtd-name x))]
                      [(pair? x) "pair"]
                      [(vector? x) (c-fmt "vec~a" (vector-length x))]
                      [(box? x) "box"]
                      [(hashtable? x) (c-fmt "ht~a" (hashtable-size x))]
                      [($stvec? x) (c-fmt "st~a" ($stlen x))]
                      [(symbol? x) (c-fmt "sym:~a" x)]
                      [(string? x) (c-fmt "str~a" (string-length x))]
                      [(bytevector? x) (c-fmt "bv~a" (bytevector-length x))]
                      [else "other"]))
                  "ERR")
             op)
            (c-nl op))
          (f (fx+ i 1)))))
    (c3-closep op)))

(define (dw-class-stats)
  ;; -> (list n-classes n-multi max-size)
  (let ([ks (vector->list (c-htkeys dw-classes))])
    (let loop ([l ks] [n 0] [multi 0] [mx 0])
      (if (null? l)
          (list n multi mx)
          (let ([sz (length (c-htref dw-classes (car l) '()))])
            (loop (cdr l) (fx+ n 1)
                  (if (fx> sz 1) (fx+ multi 1) multi)
                  (fxmax mx sz)))))))

;; B side: key -> vector of codes in first-encounter order
(define dw-classvecs (make-hashtable equal-hash equal?))
(define (dw-freeze-classes!)
  (let ([ks (vector->list (c-htkeys dw-classes))])
    (for-each
     (lambda (k)
       (c2-htset! dw-classvecs k (list->vector (reverse (c-htref dw-classes k '())))))
     ks)))
(define (dw-lookup-code key occ)
  (let ([v (c-htref dw-classvecs key #f)])
    (and v (fx< occ (vector-length v)) (vector-ref v occ))))

;; ---------- stxparam mark-key identity dissection (7.1 probe) ----------
;; The syntax-parameter continuation-mark KEY is the
;; `current-parameter-environment` (cpe) closure of one stxparamkey module
;; instance.  get side freezes its instance's `apply-syntax-parameter` (asp)
;; into struct:syntax-parameter's prop:set!-transformer at type-creation;
;; set side resolves `let-local-keys` (llk, private/stxparam.rkt) in the
;; expander's phase-1 world.  If asp and llk resolve to DIFFERENT cpe
;; closures for the world the micro-test runs in, the mark is written under
;; one key and read under another -> 'default.
;; NOTE: p33-find-minsts returns EXPANDER module-instance records; the
;; linklet-level `instance` records (name data hash) sit deeper inside, so
;; collect them by bounded walk first.
(define (p33-collect-insts root maxd maxn)
  ;; -> list of rumble linklet `instance` records reachable from root
  (let ([seen (make-eq-hashtable)] [out '()] [n 0])
    (let walk ([x root] [d 0])
      (when (and (fx< d maxd) (fx< n maxn) (heapish? x)
                 (not (eq-hashtable-ref seen x #f)))
        (eq-hashtable-set! seen x #t)
        (when (and ($rec? x) (eq? (try (lambda () (rtd-name x)) #f) 'instance))
          (set! out (cons x out))
          (set! n (fx+ n 1)))
        (cond
          [($rec? x)
           (let ([nf (try (lambda () (rtd-total-fields ($rtd x))) 0)])
             (let f ([i 0])
               (when (fx< i nf)
                 (walk (try (lambda () (#%$record-ref x i)) #f) (fx+ d 1))
                 (f (fx+ i 1)))))]
          [(pair? x) (walk (car x) (fx+ d 1)) (walk (cdr x) (fx+ d 1))]
          [(vector? x)
           (let ([nf (vector-length x)])
             (let f ([i 0])
               (when (fx< i nf)
                 (walk (vector-ref x i) (fx+ d 1))
                 (f (fx+ i 1)))))]
          [(box? x) (walk (unbox x) (fx+ d 1))]
          [else (void)])))
    (reverse out)))

(define (p33-inst-vartab inst)
  ;; linklet instance -> Chez eq-hashtable of (symbol -> variable), or #f
  (let ([ih (try (lambda () (#%$record-ref inst 2)) #f)])
    (cond
      [(hashtable? ih) ih]
      [(and ih ($rec? ih))
       (let ([f3 (try (lambda () (#%$record-ref ih 3)) #f)])
         (and (hashtable? f3) f3))]
      [else #f])))

(define (p33-inst-vars* inst needle)
  ;; -> list of (sym . value) for instance variables whose name contains needle
  (let ([iht (p33-inst-vartab inst)] [out '()])
    (when iht
      (let ([ks (c-htkeys iht)])
        (let f ([i 0])
          (when (fx< i (vector-length ks))
            (let* ([k (vector-ref ks i)]
                   [kstr (try (lambda () (symbol->string k)) "")])
              (when (p33-substr? kstr needle)
                (let* ([var (c-htref iht k #f)]
                       [val (try (lambda () (#%$record-ref var 0)) #f)])
                  (set! out (cons (cons k val) out)))))
            (f (fx+ i 1))))))
    out))

(define (p33-fv-hunt-cpe root maxd)
  ;; walk root's fv chain (closures, variable cells, pairs, vectors);
  ;; -> list of distinct closures whose code-name contains "parameter-environment"
  (let ([seen (make-eq-hashtable)] [hits '()])
    (let walk ([x root] [d 0])
      (when (and (fx< d maxd) (heapish? x) (not (eq-hashtable-ref seen x #f)))
        (eq-hashtable-set! seen x #t)
        (when (and (procedure? x) (not ($cont? x)))
          (let ([cd (try (lambda () ($ccode x)) #f)])
            (when (and cd
                       (p33-substr? (c-fmt "~a" (try (lambda () (code-name cd)) ""))
                                    "parameter-environment")
                       (not (memq x hits)))
              (set! hits (cons x hits)))))
        ;; NOT exclusive: a wrapper record can be procedure? AND $rec? --
        ;; walk closure fvs and record fields both (cond short-circuit here
        ;; previously made asp fv chase come up empty)
        (when (and (procedure? x) (not ($cont? x)))
          (let ([cn (safe-clen x)])
            (when cn
              (let f ([j 0])
                (when (fx< j cn)
                  (walk (try (lambda () ($cref x j)) #f) (fx+ d 1))
                  (f (fx+ j 1)))))))
        (cond
          [($rec? x)
           (unless (hashtable? x)
             (let ([n (try (lambda () (rtd-total-fields ($rtd x))) 0)])
               (let f ([i 0])
                 (when (fx< i n)
                   (walk (try (lambda () (#%$record-ref x i)) #f) (fx+ d 1))
                   (f (fx+ i 1))))))]
          [(pair? x) (walk (car x) (fx+ d 1)) (walk (cdr x) (fx+ d 1))]
          [(vector? x)
           (let ([n (vector-length x)])
             (let f ([i 0])
               (when (fx< i n)
                 (walk (vector-ref x i) (fx+ d 1))
                 (f (fx+ i 1)))))]
          [(box? x) (walk (unbox x) (fx+ d 1))]
          [else (void)])))
    hits))

(define (p33-stxkey-dissect o ns tag)
  ;; enumerate linklet instances via the head-layer pruned BFS (find-instances
  ;; proven to reach 2000+ instances from ns) UNION per-minst walks (f16
  ;; module-instance routes can reach instances the ns-wide pruned walk
  ;; misses), then census cpe/asp/llk.
  (let ([insts (let ([seen (make-eq-hashtable)] [acc '()])
                 (define (add! l)
                   (for-each (lambda (i)
                               (unless (eq-hashtable-ref seen i #f)
                                 (eq-hashtable-set! seen i #t)
                                 (set! acc (cons i acc))))
                             l))
                 (add! (find-instances ns))
                 (for-each
                  (lambda (pr)
                    (add! (try (lambda () (find-instances (cdr pr))) '())))
                  (append (p33-find-minsts ns "stxparamkey")
                          (p33-find-minsts ns "private/stxparam")))
                 (reverse acc))]
        [cpe-tab '()])   ; list of (closure . idx), master census
    (define (cpe-idx c)
      (cond
        [(assq c cpe-tab) => cdr]
        [else (let ([i (length cpe-tab)])
                (set! cpe-tab (cons (cons c i) cpe-tab))
                i)]))
    (define (idxs-of cs) (map (lambda (c) (cpe-idx c)) cs))
    (define (vars-matching i needle)
      ;; -> list of (sym . value) from instance var table
      (let loop ([vs (inst-vars i)] [acc '()])
        (cond
          [(null? vs) (reverse acc)]
          [(p33-substr? (c-fmt "~a" (car (car vs))) needle)
           (loop (cdr vs)
                 (cons (cons (car (car vs)) (var-val (cdr (car vs)))) acc))]
          [else (loop (cdr vs) acc)])))
    (define (each-named name-substr proc)
      (for-each
       (lambda (i)
         (when (substr? (inst-name-str i) name-substr)
           (proc i)))
       insts))
    (define (name-tail i n)
      (let* ([s (inst-name-str i)] [l (string-length s)])
        (if (fx> l n) (substring s (fx- l n) l) s)))
    (o "  [" tag "] stxkey dissect: linklet insts total=" (length insts))
    ;; census + get side, per stxparamkey linklet instance
    (each-named "stxparamkey"
      (lambda (i)
        (let ([cpes (vars-matching i "current-parameter-environment")]
              [asps (vars-matching i "apply-syntax-parameter")])
          (o "    KINST ..." (name-tail i 46)
             " nvars=" (length (inst-vars i))
             " cpe#" (idxs-of (filter procedure? (map cdr cpes))))
          (for-each
           (lambda (nv)
             (when (procedure? (cdr nv))
               (o "      GET asp->cpe#" (idxs-of (p33-fv-hunt-cpe (cdr nv) 7)))))
           asps))))
    ;; set side, per private/stxparam.rkt linklet instance
    (each-named "private/stxparam.rkt"
      (lambda (i)
        (for-each
         (lambda (nv)
           (when (procedure? (cdr nv))
             (o "    SET ..." (name-tail i 46)
                " llk->cpe#" (idxs-of (p33-fv-hunt-cpe (cdr nv) 7)))))
         (vars-matching i "let-local-keys"))))
    (o "    distinct cpe closures seen: " (length cpe-tab))))

(define (p33-hunt-ptags root maxd)
  ;; -> list of distinct records whose rtd-name mentions continuation-prompt-tag,
  ;; found via root's fv/record chain
  (let ([seen (make-eq-hashtable)] [hits '()])
    (let walk ([x root] [d 0])
      (when (and (fx< d maxd) (heapish? x) (not (eq-hashtable-ref seen x #f)))
        (eq-hashtable-set! seen x #t)
        (when (and ($rec? x) (not (hashtable? x))
                   (p33-substr? (c-fmt "~a" (try (lambda () (rtd-name x)) ""))
                                "continuation-prompt-tag")
                   (not (memq x hits)))
          (set! hits (cons x hits)))
        (when (and (procedure? x) (not ($cont? x)))
          (let ([cn (safe-clen x)])
            (when cn
              (let f ([j 0])
                (when (fx< j cn)
                  (walk (try (lambda () ($cref x j)) #f) (fx+ d 1))
                  (f (fx+ j 1)))))))
        (cond
          [($rec? x)
           (unless (hashtable? x)
             (let ([n (try (lambda () (rtd-total-fields ($rtd x))) 0)])
               (let f ([i 0])
                 (when (fx< i n)
                   (walk (try (lambda () (#%$record-ref x i)) #f) (fx+ d 1))
                   (f (fx+ i 1))))))]
          [(pair? x) (walk (car x) (fx+ d 1)) (walk (cdr x) (fx+ d 1))]
          [(vector? x)
           (let ([n (vector-length x)])
             (let f ([i 0])
               (when (fx< i n)
                 (walk (vector-ref x i) (fx+ d 1))
                 (f (fx+ i 1)))))]
          [(box? x) (walk (unbox x) (fx+ d 1))]
          [else (void)])))
    hits))

(define (p33-find-cpe-closure ns)
  ;; -> the (shared) current-parameter-environment closure of the traveled
  ;; stxparamkey instances, or #f
  (let ([found #f])
    (for-each
     (lambda (i)
       (when (and (not found) (substr? (inst-name-str i) "stxparamkey"))
         (let loop ([vs (inst-vars i)])
           (when (pair? vs)
             (if (and (p33-substr? (c-fmt "~a" (car (car vs)))
                                   "current-parameter-environment")
                      (procedure? (var-val (cdr (car vs)))))
                 (set! found (var-val (cdr (car vs))))
                 (loop (cdr vs)))))))
     (find-instances ns))
    found))

;; ---------- zoclo: canonical 0-fv closure literal of a zo-named code ----------
;; A 0-fv closure created at zo load time exists in TWO places: the module
;; instance cell AND the code's reloc self-literal (same object on the load
;; process).  Segment travel splits them: B replays the zo (fresh literal)
;; while the segment brings A's cell closure -- two eq-distinct closures for
;; one code.  Anything keying on the closure object (stxparam continuation
;; marks) breaks.  Channel: A externalizes the cell closure as its code's
;; (evt . seq); B resolves to the replayed code's reloc self-literal.
(define (p33-zoclo-literal cd)
  ;; -> the 0-fv self-closure literal in cd's reloc, or #f
  ;; (dynamic-generation code reloc is GC-maintained: safe to read anytime)
  (let ([rl (try (lambda () (dw-get-reloc cd #f)) '())])
    (let loop ([l rl])
      (cond
        [(not (pair? l)) #f]
        [(and (procedure? (car l)) (not ($cont? (car l)))
              (eqv? (safe-clen (car l)) 0)
              (eq? (try (lambda () ($ccode (car l))) #f) cd))
         (car l)]
        [else (loop (cdr l))]))))

;; ---------- 7.2.1 targeted preheat: lazy syntax-literals force plan ----------
;; The workload preheat exists to force declared modules' deserialized-
;; syntax-vector boxes (the scope-minting layer) before the segment is
;; written; running user-level code for that drags the workload's own
;; modules and eval by-products into the segment.  This enumerates the
;; registry declarations instead and hands back each module's
;; force-bulk-binding closure (expander eval/module.rkt wires it to
;; force-syntax-deserialize) so the runner can invoke them racket-side
;; (exception-wrapped there -- racket raise from a bare Chez frame kills
;; the process) with the namespace's bulk-binding-registry.

(define (p33-rtd-field-index rtd want)
  ;; absolute field index (as $rref counts, inherited fields first) of
  ;; the field named `want`, searching rtd then its ancestors; #f if absent
  (let loop ([r rtd])
    (and r
         (let* ([names (record-type-field-names r)]
                [base (let ([p (record-type-parent r)])
                       (if p (rtd-total-fields p) 0))]
                [n (vector-length names)])
           (let scan ([i 0])
             (cond
               [(fx= i n) (loop (record-type-parent r))]
               [(eq? (vector-ref names i) want) (fx+ base i)]
               [else (scan (fx+ i 1))]))))))

(define (p33-rec-field-by-name x want)
  (let ([i (and ($rec? x) (p33-rtd-field-index ($rtd x) want))])
    (and i (try (lambda () ($rref x i)) #f))))

(define (p33-fsp-name-str k)
  ;; deterministic sort key for a resolved-module-path (single field: name)
  (let ([nm (if (p3-rmp? k) (try (lambda () ($rref k 0)) k) k)])
    (cond
      [(symbol? nm) (symbol->string nm)]
      [(and ($rec? nm) (p3-path? nm))
       (c-fmt "~a" (try (lambda () ($rref nm 0)) nm))]
      [else (c-fmt "~s" nm)])))

(define (p33-syntax-force-plan ns)
  ;; -> (vector breg (vector (name-str . force-closure) ...)) name-sorted,
  ;;    or (vector 'ERR diag) when a field lookup fails.
  ;; Field access by INDEX (rumble rtds do not carry the racket source
  ;; field names): ns f7=module-registry f9=bulk-binding-registry
  ;; (handoff constants, project-validated); module-registry f0=
  ;; declarations (registry.rkt:7); module f12=force-bulk-binding
  ;; (namespace/module.rkt:74, #:authentic, no parent).  Each index is
  ;; validated against the record's rtd-name / a procedure? check.
  (let* ([reg (let ([r (try (lambda () ($rref ns 7)) #f)])
                (and ($rec? r) (eq? (rtd-name r) 'module-registry) r))]
         [breg (let ([r (try (lambda () ($rref ns 9)) #f)])
                 (and ($rec? r) r))]
         [decls (and reg (try (lambda () ($rref reg 0)) #f))]
         [ht (and decls ($rec? decls)
                  ;; racket mutable hash: descend only into the Chez
                  ;; hashtable field (dw-kids precedent, d97-d100)
                  (let ([n (rtd-total-fields ($rtd decls))])
                    (let scan ([i 0])
                      (and (fx< i n)
                           (let ([v (try (lambda () ($rref decls i)) #f)])
                             (if (hashtable? v) v (scan (fx+ i 1))))))))])
    (if (not (and breg ht))
        (vector 'ERR (list 'reg (and reg #t) 'breg (and breg #t)
                           'decls (and decls #t) 'ht (and ht #t)
                           'f7-name (let ([r (try (lambda () ($rref ns 7)) #f)])
                                      (and ($rec? r) (rtd-name r)))))
        (let* ([ks (hashtable-keys ht)]
               [prs (let lp ([i (fx- (vector-length ks) 1)] [acc '()])
                      (if (fx< i 0)
                          acc
                          (lp (fx- i 1)
                              (let* ([k (vector-ref ks i)]
                                     [m (hashtable-ref ht k #f)]
                                     [fbb (and m ($rec? m)
                                               (eq? (rtd-name m) 'module)
                                               (try (lambda () ($rref m 12)) #f))])
                                (if (procedure? fbb)
                                    (cons (cons (p33-fsp-name-str k) fbb) acc)
                                    acc)))))])
          (vector breg
                  (list->vector
                   (sort (lambda (a b) (string<? (car a) (car b))) prs)))))))

(define (p33-stack-necropsy o)
  ;; forward-analysis instrument: called from a base-exception-handler
  ;; at the crash point (Chez handlers run ON the crashing continuation,
  ;; before unwind) -- walk the frames via the inspector and print the
  ;; Scheme-level code-name chain, identifying WHO dereferenced the
  ;; poison.
  (try
   (lambda ()
     (call/cc
      (lambda (k)
        (let lp ([f (inspect/object k)] [n 0])
          (when (and f (fx< n 40))
            (let ([nm (try (lambda ()
                             (let ([c ((f 'code) 'value)])
                               (code-name c)))
                           '?)]
                  [src (try (lambda ()
                              (let ([s ((f 'code) 'source-path)])
                                (call-with-values (lambda () s)
                                  (case-lambda
                                    [(path line char) (c-fmt "~a:~a" path line)]
                                    [(path) (c-fmt "~a" path)]
                                    [args '?]))))
                            '?)])
              (o "  [necropsy " n "] " nm "  " (trunc (c-fmt "~a" src) 120)))
            (lp (try (lambda () (f 'link)) #f) (fx+ n 1)))))))
   'necropsy-failed))

(define (p33-zoclo-target? v)
  ;; the 'zoclo rule's object-side essence (sans mark-ht guard): would this
  ;; closure canonicalize through the zoclo channel?  Used by A's manifest
  ;; build to assert the ordered staddr/dwseq rules never capture one (they
  ;; resolve by address/walk-seq, NOT to the reloc self-literal, so a silent
  ;; steal would reintroduce the 0-fv identity split -- design doc 6.2)
  (and (procedure? v)
       (not ($cont? v))
       (eqv? (safe-clen v) 0)
       (let ([cd (try (lambda () ($ccode v)) #f)])
         (and cd
              (zo-a-lookup cd)
              (eq? (p33-zoclo-literal cd) v)))
       #t))
