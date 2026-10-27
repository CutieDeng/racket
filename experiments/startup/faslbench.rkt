#lang racket/base
;; faslbench.rkt -- time Chez fasl-read of every code linklet in the default REPL's module set,
;; in-process, excluding running the code.  Usage: racket faslbench.rkt [rounds]
;; env FB_PAUSE=secs (sleep before the loop so `sample` can attach), FB_DUMP=file (per-item ms).
(require ffi/unsafe/vm racket/list racket/path racket/os '#%linklet)
(define rounds (let ([a (current-command-line-arguments)]) (if (> (vector-length a) 0) (string->number (vector-ref a 0)) 20)))
(define roots '(racket/init racket/interactive xrepl expeditor syntax-color/racket-lexer
                syntax-color/racket-indentation syntax-color/racket-navigation racket/interactive/tstring))
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
(for ([r roots]) (with-handlers ([exn:fail? (lambda (e) (eprintf "skip root ~a\n" r))])
                   (walk! (resolved-module-path-name (module-path-index-resolve (module-path-index-join r #f))))))
(define zos
  (remove-duplicates
   (for/list ([n (hash-keys seen)])
     (define p (if (pair? n) (car n) n))
     (define-values (dir file _) (split-path p))
     (build-path dir "compiled" (string-append (regexp-replace* #rx"[.]" (path->string file) "_") ".zo")))))
(define fasled (vm-eval 'linklet-fasled-code+arguments))
(define (bundle-linklets h zo)
  (for/list ([(k v) h] #:when (linklet? v))
    (define-values (fmt bv lits) (fasled v))
    (vector (if (symbol? k) k (string->symbol (format "phase~a" k))) bv lits fmt zo)))
(define items
  (append*
   (for/list ([zo zos] #:when (file-exists? zo))
     (define c (parameterize ([read-accept-compiled #t]) (call-with-input-file zo read)))
     (define bundles
       (cond [(linklet-bundle? c) (list (linklet-bundle->hash c))]
             [(linklet-directory? c)
              (let loop ([h (linklet-directory->hash c)])
                (append* (for/list ([(k v) h])
                           (cond [(linklet-bundle? v) (list (linklet-bundle->hash v))]
                                 [(linklet-directory? v) (loop (linklet-directory->hash v))]
                                 [else '()]))))]
             [else '()]))
     (append* (map (lambda (b) (bundle-linklets b zo)) bundles)))))
(define items* (filter (lambda (it) (and (bytes? (vector-ref it 1)) (memq (vector-ref it 3) '(compile interpret)))) items))
(printf "zo files ~a, code linklets ~a, total KB ~a\n" (length zos) (length items*)
        (quotient (for/sum ([it items*]) (bytes-length (vector-ref it 1))) 1024))
(define fasl-read-code (vm-eval '(lambda (bv lits) (fasl-read (open-bytevector-input-port bv) 'load lits))))
(define (run-all) (for ([it items*]) (fasl-read-code (vector-ref it 1) (vector-ref it 2))))
(collect-garbage) (collect-garbage)
(let ([p (getenv "FB_PAUSE")]) (when p (printf "pid ~a pausing ~as\n" (getpid) p) (flush-output) (sleep (string->number p))))
(run-all)
(define (ms t0) (- (current-inexact-monotonic-milliseconds) t0))
(define per-kind (make-hasheq))
(for ([it items*])
  (define k (vector-ref it 0)) (define bv (vector-ref it 1)) (define lits (vector-ref it 2))
  (define t0 (current-inexact-monotonic-milliseconds))
  (for ([i rounds]) (fasl-read-code bv lits))
  (define v (hash-ref! per-kind k (lambda () (vector 0 0 0.0))))
  (vector-set! v 0 (add1 (vector-ref v 0))) (vector-set! v 1 (+ (vector-ref v 1) (bytes-length bv)))
  (vector-set! v 2 (+ (vector-ref v 2) (/ (ms t0) rounds))))
(define dump (getenv "FB_DUMP"))
(when dump
  (with-output-to-file dump #:exists 'replace
    (lambda ()
      (for ([it items*])
        (define bv (vector-ref it 1)) (define lits (vector-ref it 2))
        (define t0 (current-inexact-monotonic-milliseconds))
        (for ([i rounds]) (fasl-read-code bv lits))
        (write (list (vector-ref it 4) (vector-ref it 0) (bytes-length bv) (/ (ms t0) rounds))) (newline)))))
(define tot (for/sum ([(k v) per-kind]) (vector-ref v 2)))
(printf "~a rounds; per-round total ~a ms, gc ~a ms total\n" rounds (real->decimal-string tot 2) (current-gc-milliseconds))
(printf "kind n KB ms us/KB us/each\n")
(for ([(k v) per-kind])
  (define kb (/ (vector-ref v 1) 1024.0))
  (printf "~a ~a ~a ~a ~a ~a\n" k (vector-ref v 0) (real->decimal-string kb 0) (real->decimal-string (vector-ref v 2) 2)
          (real->decimal-string (/ (* 1000 (vector-ref v 2)) kb) 2) (real->decimal-string (/ (* 1000 (vector-ref v 2)) (vector-ref v 0)) 1)))
