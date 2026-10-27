#lang racket/base
;; loadtrace.rkt -- per-module ledger for a module chain:
;;   A. declare (read+declare .zo, all phases, DFS over module->imports), self time via load handler
;;   B. instantiate phase-0 bodies, dependency post-order (incremental = own body)
;;   C. visit decomposition: (a) phase-0 bodies run at phase 1 (dynamic-require-for-syntax),
;;      (b) phase-1 bodies of the phase-0 set (dynamic-require ... (void)), both post-order
;; Usage (mirrors the REPL state at expeditor-configure: racket/init namespace, phase-1 visited):
;;   racket -I racket/init -e '(require (file "experiments/startup/loadtrace.rkt"))' -- <modpath> ...
;; Env: LT_OUT=<file.rktd> dump raw records; PLTDISABLEGC=1 for GC-free attribution.
(require racket/list racket/string racket/format)

(define targets (map (lambda (s) (read (open-input-string s)))
                     (vector->list (current-command-line-arguments))))
(when (null? targets) (error 'loadtrace "no targets"))

(define (now) (current-inexact-monotonic-milliseconds))
(define (mem) (current-memory-use 'cumulative))
(define (gcms) (current-gc-milliseconds))

;; mpis from module->imports end in a base-less "self" index: rebase onto the module's own name
(define (resolve-import mpi self)
  (define-values (p b) (module-path-index-split mpi))
  (cond [(not p) self]
        [else (resolved-module-path-name
               (module-path-index-resolve
                (module-path-index-join p (make-resolved-module-path
                                           (if b (resolve-import b self) self)))))]))
(define edges (make-hash)) ; name -> list of (phase . name)
(define (imports-of name)
  (hash-ref! edges name
             (lambda ()
               (if (symbol? name) '()
                   (for*/list ([ph+mpis (module->imports (make-resolved-module-path name))]
                               #:when (car ph+mpis)
                               [mpi (cdr ph+mpis)])
                     (cons (car ph+mpis) (resolve-import mpi name)))))))

;; ---- phase A: declare whole graph, trace loads ----
(struct rec (name path t-total t-self alloc-total alloc-self gc order) #:mutable)
(define recs '())
(define stack '())            ; frames: (vector start mem gc child-ms child-alloc)
(define order 0)
(define old-load (current-load/use-compiled))
(define (traced-load path expected)
  (define frame (vector (now) (mem) (gcms) 0.0 0))
  (set! stack (cons frame stack))
  (define name (current-module-declare-name))
  (begin0 (old-load path expected)
    (set! stack (cdr stack))
    (let ([dt (- (now) (vector-ref frame 0))]
          [da (- (mem) (vector-ref frame 1))]
          [dg (- (gcms) (vector-ref frame 2))])
      (set! order (add1 order))
      (set! recs (cons (rec (and name (resolved-module-path-name name)) path
                            dt (- dt (vector-ref frame 3))
                            da (- da (vector-ref frame 4)) dg order)
                       recs))
      (unless (null? stack)
        (let ([p (car stack)])
          (vector-set! p 3 (+ (vector-ref p 3) dt))
          (vector-set! p 4 (+ (vector-ref p 4) da)))))))

(define declared (make-hash))
(define (declare! name)
  (unless (hash-ref declared name #f)
    (hash-set! declared name #t)
    ;; module-declared? loads only for a module path (not a resolved one)
    (module-declared? (cond [(path? name) name]
                            [(pair? name) `(submod ,(car name) ,@(cdr name))]
                            [else `(quote ,name)])
                      #t)
    (for ([e (imports-of name)]) (declare! (cdr e)))))
(define target-names
  (for/list ([t targets])
    (resolved-module-path-name (module-path-index-resolve (module-path-index-join t #f)))))
(define a0 (now)) (define m0 (mem)) (define g0 (gcms))
(parameterize ([current-load/use-compiled traced-load])
  (for-each declare! target-names))
(define a-ms (- (now) a0)) (define a-alloc (- (mem) m0)) (define a-gc (- (gcms) g0))
(set! recs (reverse recs))
(define traced (for/hash ([r recs] #:when (rec-name r)) (values (rec-name r) #t)))

;; ---- phase-0 reachable set + post-order ----
(define reach (make-hash))
(define post-order '())
(define (walk! name)
  (unless (hash-ref reach name #f)
    (hash-set! reach name #t)
    (for ([e (imports-of name)] #:when (= (car e) 0)) (walk! (cdr e)))
    (set! post-order (cons name post-order))))
(for-each walk! target-names)

;; ---- phase B: instantiate phase 0 in post-order ----
(define (measure! table n thunk)
  (define t0 (now)) (define mm (mem)) (define gg (gcms))
  (thunk)
  (hash-set! table n (vector (- (now) t0) (- (mem) mm) (- (gcms) gg))))
(define inst (make-hash))
(define b0 (now)) (define bm (mem)) (define bg (gcms))
(for ([n (reverse post-order)] #:when (hash-ref traced n #f))
  (measure! inst n (lambda () (dynamic-require n #f))))
(define b-ms (- (now) b0)) (define b-alloc (- (mem) bm)) (define b-gc (- (gcms) bg))

;; ---- phase C: visit decomposition (skipped when LT_SKIP_C is set) ----
(define skip-c? (getenv "LT_SKIP_C"))
;; F: modules whose phase-0 body runs at phase 1 during a visit of the targets
(define F (make-hash))
(define F-post '())
(define (walkF! name)
  (unless (hash-ref F name #f)
    (hash-set! F name #t)
    (for ([e (imports-of name)] #:when (= (car e) 0)) (walkF! (cdr e)))
    (set! F-post (cons name F-post))))
(for ([n (hash-keys reach)])
  (for ([e (imports-of n)] #:when (= (car e) 1)) (walkF! (cdr e))))
(define instC1 (make-hash))
(define c0 (now)) (define cm (mem)) (define cg (gcms))
(for ([n (reverse F-post)] #:when (and (not skip-c?) (hash-ref traced n #f)))
  (measure! instC1 n (lambda () (dynamic-require-for-syntax n #f))))
(define c1-ms (- (now) c0)) (define c1-alloc (- (mem) cm)) (define c1-gc (- (gcms) cg))
(define instC2 (make-hash))
(define d0 (now)) (define dm (mem)) (define dg (gcms))
(for ([n (reverse post-order)] #:when (and (not skip-c?) (hash-ref traced n #f)))
  (measure! instC2 n (lambda () (dynamic-require n (void)))))
(define c2-ms (- (now) d0)) (define c2-alloc (- (mem) dm)) (define c2-gc (- (gcms) dg))

;; ---- report ----
(define (short n)
  (define s (cond [(path? n) (path->string n)]
                  [(pair? n) (format "~a ~a" (short (car n)) (cdr n))]
                  [else (format "~a" n)]))
  (define i (or (for/first ([k '("/share/pkgs/" "/collects/")]
                            #:when (string-contains? s k))
                  (+ (string-length k) (caar (regexp-match-positions (regexp-quote k) s))))
                0))
  (substring s i))
(define (f ms) (~r ms #:precision '(= 2) #:min-width 7))
(define (kb b) (~r (/ b 1024.0) #:precision '(= 0) #:min-width 6))
(define (cell v i) (if v (if (= i 0) (f (vector-ref v 0)) (kb (vector-ref v 1))) (if (= i 0) "      -" "     -")))
(printf "A declare: ~a modules, ~a ms, ~a KB, gc ~a ms\n" (length recs) (f a-ms) (kb a-alloc) a-gc)
(printf "B instantiate phase 0 (~a of ~a): ~a ms, ~a KB, gc ~a ms\n"
        (hash-count inst) (length recs) (f b-ms) (kb b-alloc) b-gc)
(printf "C(a) phase-0 bodies at phase 1 (~a traced of ~a): ~a ms, ~a KB, gc ~a ms\n"
        (hash-count instC1) (hash-count F) (f c1-ms) (kb c1-alloc) c1-gc)
(printf "C(b) phase-1 bodies of phase-0 set (~a): ~a ms, ~a KB, gc ~a ms\n"
        (hash-count instC2) (f c2-ms) (kb c2-alloc) c2-gc)
(printf "~a ~a ~a | ~a ~a | ~a ~a | ~a ~a | ~a\n"
        "   #" " dcl-ms" "dcl-KB" "  p0-ms" " p0-KB" " p0@1ms" "p0@1KB" "  p1-ms" " p1-KB" "module")
(for ([r recs] [i (in-naturals 1)])
  (define n (rec-name r))
  (define iv (and n (hash-ref inst n #f)))
  (define c1 (and n (hash-ref instC1 n #f)))
  (define c2 (and n (hash-ref instC2 n #f)))
  (printf "~a ~a ~a | ~a ~a | ~a ~a | ~a ~a | ~a\n"
          (~r i #:min-width 4) (f (rec-t-self r)) (kb (rec-alloc-self r))
          (cell iv 0) (cell iv 1) (cell c1 0) (cell c1 1) (cell c2 0) (cell c2 1)
          (short (or n (rec-path r)))))
(define out (getenv "LT_OUT"))
(when out
  (with-output-to-file out #:exists 'replace
    (lambda ()
      (write (for/list ([r recs])
               (define n (rec-name r))
               (list (short (or n (rec-path r))) (rec-t-self r) (rec-alloc-self r) (rec-gc r)
                     (and n (hash-ref inst n #f)) (and n (hash-ref instC1 n #f)) (and n (hash-ref instC2 n #f))))))))
