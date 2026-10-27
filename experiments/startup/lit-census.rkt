#lang racket/base
;; lit-census.rkt: for the default REPL's module set, count the racket/fasl literals of every
;; linklet by type and kind, and time their decoding (fasl->s-exp with datum-intern) in-process.
(require ffi/unsafe/vm racket/list racket/path racket/fasl '#%linklet)
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
(for ([r roots]) (walk! (resolved-module-path-name (module-path-index-resolve (module-path-index-join r #f)))))
(define zos
  (remove-duplicates
   (for/list ([n (hash-keys seen)])
     (define p (if (pair? n) (car n) n))
     (define-values (dir file _) (split-path p))
     (build-path dir "compiled" (string-append (regexp-replace* #rx"[.]" (path->string file) "_") ".zo")))))
(define raw-lits (vm-eval '(lambda (lk) ((record-accessor (record-rtd lk) 1) lk))))
(define to-unfasl-bstr (vm-eval '(lambda (r) ((record-accessor (record-rtd r) 0) r))))
(define to-unfasl-ext (vm-eval '(lambda (r) ((record-accessor (record-rtd r) 1) r))))
;; collect (kind bstr externals)
(define items
  (append*
   (for/list ([zo zos] #:when (file-exists? zo))
     (define c (parameterize ([read-accept-compiled #t]) (call-with-input-file zo read)))
     (define (bundle-items h)
       (for/list ([(k v) h] #:when (linklet? v))
         (define kind (if (symbol? k) k (string->symbol (format "phase~a" k))))
         (define l (raw-lits v))
         (define u (if (box? l) (unbox l) l))
         (cond [(and (vector? u) (= 0 (vector-length u))) (list kind #f #f)]
               [(vector? u) (list kind 'forced u)]
               [else (list kind (to-unfasl-bstr u) (to-unfasl-ext u))])))
     (cond [(linklet-bundle? c) (bundle-items (linklet-bundle->hash c))]
           [(linklet-directory? c)
            (let loop ([h (linklet-directory->hash c)])
              (append* (for/list ([(k v) h])
                         (cond [(linklet-bundle? v) (bundle-items (linklet-bundle->hash v))]
                               [(linklet-directory? v) (loop (linklet-directory->hash v))]
                               [else '()]))))]
           [else '()]))))
(define (classify v)
  (cond [(srcloc? v) 'srcloc] [(string? v) 'string] [(keyword? v) 'keyword] [(path? v) 'path]
        [(symbol? v) 'symbol] [(hash? v) 'hash] [(prefab-struct-key v) 'prefab] [(bytes? v) 'bytes]
        [(regexp? v) 'regexp] [(byte-regexp? v) 'byte-regexp] [else 'other]))
(define per-kind (make-hasheq)) ; kind -> hash type -> count ; plus bytes & ms
(define total-bstr 0) (define n-with 0)
(define t-total 0.0)
(for ([it items] #:when (bytes? (cadr it)))
  (define kind (car it)) (define bstr (cadr it)) (define ext (caddr it))
  (set! total-bstr (+ total-bstr (bytes-length bstr))) (set! n-with (add1 n-with))
  (define t0 (current-inexact-monotonic-milliseconds))
  (define v (fasl->s-exp bstr #:datum-intern? #t #:skip-prefix? #t #:external-lifts ext))
  (set! t-total (+ t-total (- (current-inexact-monotonic-milliseconds) t0)))
  (define h (hash-ref! per-kind kind (lambda () (make-hasheq))))
  (hash-update! h 'bytes (lambda (x) (+ x (bytes-length bstr))) 0)
  (hash-update! h 'linklets add1 0)
  (for ([e (in-vector v)]) (hash-update! h (classify e) add1 0)))
(define rxs (for*/list ([it items] #:when (bytes? (cadr it))
                        [e (in-vector (fasl->s-exp (cadr it) #:datum-intern? #t #:skip-prefix? #t #:external-lifts (caddr it)))]
                        #:when (or (regexp? e) (byte-regexp? e))) e))
(define t-rx (let ([t0 (current-inexact-monotonic-milliseconds)])
               (for ([rx rxs]) (if (byte-regexp? rx) ((if (byte-pregexp? rx) byte-pregexp byte-regexp) (object-name rx)) ((if (pregexp? rx) pregexp regexp) (object-name rx))))
               (- (current-inexact-monotonic-milliseconds) t0)))
(printf "regexp literals ~a, recompile all ~a ms\n" (length rxs) (real->decimal-string t-rx 2))
(printf "linklets with literals ~a, fasl bytes ~a KB, decode time ~a ms (warm, single pass)\n"
        n-with (quotient total-bstr 1024) (real->decimal-string t-total 2))
(for ([(k h) per-kind])
  (printf "~a: linklets ~a, KB ~a |" k (hash-ref h 'linklets 0) (quotient (hash-ref h 'bytes 0) 1024))
  (for ([t '(srcloc string keyword path symbol hash prefab bytes regexp byte-regexp other)])
    (when (hash-ref h t #f) (printf " ~a ~a" t (hash-ref h t))))
  (newline))
