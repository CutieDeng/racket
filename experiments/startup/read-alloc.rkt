#lang racket/base
;; read-alloc.rkt: per-.zo allocation of `read` (compiled code) vs file size, code bytes, lazily
;; copied code bytes (stx-data / phase>=1), metadata symbols; prints rows and a least-squares fit.
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
  (filter file-exists?
   (remove-duplicates
    (for/list ([n (hash-keys seen)])
      (define p (if (pair? n) (car n) n))
      (define-values (dir file _) (split-path p))
      (build-path dir "compiled" (string-append (regexp-replace* #rx"[.]" (path->string file) "_") ".zo"))))))
(define fasled (vm-eval 'linklet-fasled-code+arguments))
(define importss-of (vm-eval '(lambda (lk) ((record-accessor (record-rtd lk) 7) lk))))
(define exports-of (vm-eval '(lambda (lk) ((record-accessor (record-rtd lk) 8) lk))))
(define rows '())
(for ([zo zos])
  (define b (call-with-input-file zo (lambda (p) (read-bytes (file-size zo) p))))
  ;; warm + measure
  (parameterize ([read-accept-compiled #t]) (read (open-input-bytes b)))
  (define m0 (current-memory-use 'cumulative))
  (define c (parameterize ([read-accept-compiled #t]) (read (open-input-bytes b))))
  (define alloc (- (current-memory-use 'cumulative) m0))
  ;; structure stats (after the measured read, on c)
  (define code 0) (define lazy 0) (define nsym 0) (define nl 0) (define nb 0)
  (define (walk h)
    (set! nb (add1 nb))
    (for ([(k v) h] #:when (linklet? v))
      (set! nl (add1 nl))
      (define-values (fmt bv lits) (fasled v))
      (when (bytes? bv)
        (set! code (+ code (bytes-length bv)))
        (when (or (eq? k 'stx-data) (and (exact-integer? k) (> k 0))) (set! lazy (+ lazy (bytes-length bv)))))
      (set! nsym (+ nsym (length (exports-of v)) (for/sum ([l (importss-of v)]) (length l))))))
  (let loop ([c c])
    (cond [(linklet-bundle? c) (walk (linklet-bundle->hash c))]
          [(linklet-directory? c) (for ([(k v) (linklet-directory->hash c)])
                                    (cond [(linklet-bundle? v) (walk (linklet-bundle->hash v))]
                                          [(linklet-directory? v) (loop v)]))]))
  (set! rows (cons (list (bytes-length b) alloc code lazy nsym nl nb (path->string zo)) rows)))
(define tot (lambda (i) (for/sum ([r rows]) (list-ref r i))))
(printf "files ~a: bytes ~a KB, alloc ~a KB (~a x), code ~a KB, lazy-copied code ~a KB, symbols ~a, linklets ~a, bundles ~a\n"
        (length rows) (quotient (tot 0) 1024) (quotient (tot 1) 1024) (real->decimal-string (/ (tot 1) (tot 0)) 2)
        (quotient (tot 2) 1024) (quotient (tot 3) 1024) (tot 4) (tot 5) (tot 6))
(printf "## top 8 by alloc/bytes ratio (bytes alloc code lazy nsym nl nb file)\n")
(for ([r (take (sort rows > #:key (lambda (r) (/ (cadr r) (max 1 (car r))))) 8)])
  (printf "~a ~a ~a ~a ~a ~a ~a ~a\n" (car r) (cadr r) (caddr r) (cadddr r) (list-ref r 4) (list-ref r 5) (list-ref r 6)
          (regexp-replace #rx".*/racket/" (list-ref r 7) "")))
(with-output-to-file "/tmp/read-alloc.rktd" #:exists 'replace (lambda () (write rows)))
