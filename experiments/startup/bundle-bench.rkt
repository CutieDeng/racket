#lang racket/base
;; bundle-bench.rkt: R4 estimate. For a module set, time `read` of each compiled file (bundle
;; structure; code stays as unmaterialized slices) and count linklet metadata symbols by kind.
(require ffi/unsafe/vm racket/list racket/path '#%linklet)
(define roots '(racket/init racket/interactive))
(define (resolve-import mpi self)
  (define-values (p b) (module-path-index-split mpi))
  (cond [(not p) self]
        [else (resolved-module-path-name
               (module-path-index-resolve
                (module-path-index-join p (make-resolved-module-path (if b (resolve-import b self) self)))))]))
(define seen (make-hash))
(define (walk! name)
  (unless (or (symbol? name) (hash-ref seen name #f))
    (hash-set! seen name #t)
    (module-declared? (cond [(path? name) name] [(pair? name) `(submod ,(car name) ,@(cdr name))]) #t)
    (for* ([ph+mpis (module->imports (make-resolved-module-path name))] #:when (car ph+mpis)
           [mpi (cdr ph+mpis)])
      (walk! (resolve-import mpi name)))))
(for ([r roots]) (walk! (resolved-module-path-name (module-path-index-resolve (module-path-index-join r #f)))))
(define zos
  (remove-duplicates
   (for/list ([n (hash-keys seen)])
     (define p (if (pair? n) (car n) n))
     (define-values (dir file _) (split-path p))
     (build-path dir "compiled" (string-append (regexp-replace* #rx"[.]" (path->string file) "_") ".zo")))))
(define zos* (filter file-exists? zos))
(define bstrs (for/list ([zo zos*]) (call-with-input-file zo (lambda (p) (read-bytes (file-size zo) p)))))
(printf "zo files ~a, bytes ~a KB\n" (length zos*) (quotient (for/sum ([b bstrs]) (bytes-length b)) 1024))
(define (read-all)
  (for ([b bstrs]) (parameterize ([read-accept-compiled #t]) (read (open-input-bytes b)))))
(collect-garbage)
(read-all)
(define rounds 10)
(define t0 (current-inexact-monotonic-milliseconds)) (define m0 (current-memory-use 'cumulative))
(for ([i rounds]) (read-all))
(printf "read bundle structure (warm): ~a ms/round, ~a MB/round\n"
        (real->decimal-string (/ (- (current-inexact-monotonic-milliseconds) t0) rounds) 2)
        (real->decimal-string (/ (- (current-memory-use 'cumulative) m0) rounds 1048576.0) 1))
(define importss-of (vm-eval '(lambda (lk) ((record-accessor (record-rtd lk) 7) lk))))
(define exports-of (vm-eval '(lambda (lk) ((record-accessor (record-rtd lk) 8) lk))))
(define per-kind (make-hasheq))
(define (note! kind lk)
  (define v (hash-ref! per-kind kind (lambda () (vector 0 0 0))))
  (vector-set! v 0 (add1 (vector-ref v 0)))
  (vector-set! v 1 (+ (vector-ref v 1) (for/sum ([l (importss-of lk)]) (length l))))
  (vector-set! v 2 (+ (vector-ref v 2) (length (exports-of lk)))))
(for ([b bstrs])
  (define c (parameterize ([read-accept-compiled #t]) (read (open-input-bytes b))))
  (define (walk h)
    (for ([(k v) h])
      (cond [(linklet-bundle? v) (walk (linklet-bundle->hash v))]
            [(linklet-directory? v) (walk (linklet-directory->hash v))]
            [(linklet? v) (note! (if (symbol? k) k (string->symbol (format "phase~a" k))) v)])))
  (cond [(linklet-bundle? c) (walk (linklet-bundle->hash c))]
        [(linklet-directory? c) (walk (linklet-directory->hash c))]))
(printf "kind linklets import-syms export-syms\n")
(define-values (ti te) (for/fold ([ti 0] [te 0]) ([(k v) per-kind])
                         (printf "~a ~a ~a ~a\n" k (vector-ref v 0) (vector-ref v 1) (vector-ref v 2))
                         (values (+ ti (vector-ref v 1)) (+ te (vector-ref v 2)))))
(printf "total import symbols ~a, export symbols ~a\n" ti te)
