#lang racket/base
;; startup-pack-build.rkt -- S1 of the startup pack: compute the static
;; closure of the given root modules, and write their compiled files into
;; one indexed pack file.
;;
;;   racket startup-pack-build.rkt <out.pack> <root-module> ...
;;   racket startup-pack-build.rkt --verify <out.pack>
;;
;; Pack format v1 (see repl-startup-pack-dev-2026-10-26.md §2.3):
;;   #"RKTPK1\n" <u32 header-len> <header> <u32 index-len> <index> <members...>
(require racket/list racket/string racket/path racket/port file/sha1 setup/dirs)

(define MAGIC #"RKTPK1\n")

;; ---------------------------------------------------------------------
;; key normalization: exactly what the resolver hands to `find-col-file`
;; as (collection col-path file-name), joined with "/"

(define (ss->rkt s)
  (if (and (>= (string-length s) 3) (string-suffix? s ".ss"))
      (string-append (substring s 0 (- (string-length s) 3)) ".rkt")
      s))

(define (split-relative-string s)
  ;; "a/b/c" -> (values '("a" "b") "c")
  (define parts (string-split s "/" #:trim? #f))
  (values (drop-right parts 1) (last parts)))

;; symbol or (lib ...) module path -> key string or #f
(define (module-path->key mp)
  (cond
    [(symbol? mp)
     (define-values (cols file) (split-relative-string (symbol->string mp)))
     (define f-file (if (null? cols) "main.rkt" (string-append file ".rkt")))
     (define col (if (null? cols) file (car cols)))
     (define col-path (if (null? cols) null (cdr cols)))
     (string-join (append (list col) col-path (list f-file)) "/")]
    [(and (pair? mp) (eq? (car mp) 'lib))
     (define-values (cols file) (split-relative-string (cadr mp)))
     (define old-style? (if (null? (cddr mp))
                            (and (null? cols) (regexp-match? #rx"[.]" file))
                            #t))
     (define f-file (if old-style?
                        (ss->rkt file)
                        (if (null? cols)
                            "main.rkt"
                            (if (regexp-match? #rx"[.]" file) (ss->rkt file) (string-append file ".rkt")))))
     (define cols* (if old-style?
                       (append (if (null? (cddr mp))
                                   '("mzlib")
                                   (append* (map (lambda (p) (string-split p "/" #:trim? #f)) (cddr mp))))
                               cols)
                       (if (null? cols) (list file) cols)))
     (string-join (append cols* (list f-file)) "/")]
    [else #f]))

;; ---------------------------------------------------------------------
;; closure

(define (root-name rmp)
  (define n (resolved-module-path-name rmp))
  (if (pair? n) (car n) n))

(define (zo-path-of src)
  (define-values (base name dir?) (split-path src))
  (build-path base "compiled" (path-add-extension name #".zo")))

(define (compute-closure roots)
  ;; path -> (mutable set of key strings)
  (define keys (make-hash))
  (define order '())      ; declaration order (first-seen), reversed
  (define seen (make-hash))
  (define (note-key! path mp)
    (define k (module-path->key mp))
    (when k (hash-update! keys path (lambda (s) (if (member k s) s (cons k s))) null)))
  (define (visit! mp rel)
    (define mpi (module-path-index-join mp rel))
    (define rmp (module-path-index-resolve mpi #t))
    (define name (root-name rmp))
    (when (path? name)
      (note-key! name mp)
      (unless (hash-ref seen name #f)
        (hash-set! seen name #t)
        ;; a submodule reference may have declared only the submodule;
        ;; make sure the root module itself is declared before asking
        ;; for its imports
        (module-declared? name #t)
        (define root-rmp (make-resolved-module-path name))
        (for* ([phase+mpis (in-list (module->imports root-rmp))]
               ;; label-phase imports are never loaded at run time
               #:when (car phase+mpis)
               [imp (in-list (cdr phase+mpis))])
          (define-values (sub-mp base) (module-path-index-split imp))
          (when sub-mp
            (visit! sub-mp (module-path-index-join name #f))))
        (set! order (cons name order)))))
  (for ([r roots]) (visit! r #f))
  (values (reverse order) keys))

;; ---------------------------------------------------------------------
;; write / verify

(define (u32 n) (integer->integer-bytes n 4 #f #f))

(define (build out roots)
  (define-values (order keys) (compute-closure roots))
  (define members
    (for/list ([src (in-list order)]
               #:when (file-exists? (zo-path-of src)))
      (define zo (zo-path-of src))
      (define so (path-replace-extension zo #".so"))
      (when (file-exists? so) (error 'startup-pack "native extension present, refusing: ~a" so))
      (list src zo (reverse (hash-ref keys src null)))))
  (define skipped (for/list ([src (in-list order)] #:unless (file-exists? (zo-path-of src))) src))
  (define datas (for/list ([m members]) (call-with-input-file (cadr m) port->bytes)))
  ;; offsets are assigned after the header+index sizes are known: compute
  ;; index twice (sizes of offsets in decimal can change the index length),
  ;; so iterate to a fixed point
  (define (make-index base)
    (for/fold ([acc '()] [off base] #:result (list->vector (reverse acc)))
              ([m members] [d datas])
      (values (cons (vector (path->string (car m)) (path->string (cadr m)) (caddr m)
                            off (bytes-length d) (sha1 (open-input-bytes d)))
                    acc)
              (+ off (bytes-length d)))))
  (define header
    (list 'version (version)
          'vm (symbol->string (system-type 'vm))
          'library-subpath (path->string (system-library-subpath #f))
          'links (format "~s" (map (lambda (p) (and p (path->string p))) (current-library-collection-links)))
          'paths (format "~s" (map path->string (current-library-collection-paths)))
          'modes (format "~s" (map path->string (use-compiled-file-paths)))
          'build-time (current-seconds)
          'members (length members)))
  (define header-bytes (string->bytes/utf-8 (format "~s" header)))
  (define (index-bytes base) (string->bytes/utf-8 (format "~s" (make-index base))))
  (define base
    (let loop ([guess (+ (bytes-length MAGIC) 4 (bytes-length header-bytes) 4 (bytes-length (index-bytes 0)))])
      (define b (+ (bytes-length MAGIC) 4 (bytes-length header-bytes) 4 (bytes-length (index-bytes guess))))
      (if (= b guess) b (loop b))))
  (define ib (index-bytes base))
  (call-with-output-file out #:exists 'replace
    (lambda (o)
      (write-bytes MAGIC o)
      (write-bytes (u32 (bytes-length header-bytes)) o) (write-bytes header-bytes o)
      (write-bytes (u32 (bytes-length ib)) o) (write-bytes ib o)
      (for ([d datas]) (write-bytes d o))))
  (printf "pack: ~a members, ~a MB, ~a keys, index ~a KB, header+index ~a bytes; skipped (no .zo): ~a\n"
          (length members)
          (quotient (for/sum ([d datas]) (bytes-length d)) 1000000)
          (for/sum ([m members]) (length (caddr m)))
          (quotient (bytes-length ib) 1000)
          base
          (length skipped))
  (for ([s skipped]) (printf "  skipped ~a\n" s)))

(define (read-pack in)
  (unless (equal? (read-bytes (bytes-length MAGIC) in) MAGIC) (error 'startup-pack "bad magic"))
  (define hl (integer-bytes->integer (read-bytes 4 in) #f #f))
  (define header (read (open-input-bytes (read-bytes hl in))))
  (define il (integer-bytes->integer (read-bytes 4 in) #f #f))
  (define index (read (open-input-bytes (read-bytes il in))))
  (values header index))

(define (verify pack)
  (call-with-input-file pack
    (lambda (in)
      (define-values (header index) (read-pack in))
      (define bad 0)
      (for ([e (in-vector index)])
        (define zo (vector-ref e 1)) (define off (vector-ref e 3)) (define len (vector-ref e 4))
        (file-position in off)
        (define d (read-bytes len in))
        (unless (and (equal? d (call-with-input-file zo port->bytes))
                     (equal? (sha1 (open-input-bytes d)) (vector-ref e 5)))
          (set! bad (add1 bad)) (printf "MISMATCH ~a\n" zo)))
      (printf "verify: ~a members, ~a mismatches; header: ~s\n" (vector-length index) bad header))))

(module+ main
  (define args (vector->list (current-command-line-arguments)))
  (cond
    [(and (pair? args) (equal? (car args) "--verify")) (verify (cadr args))]
    [(pair? args) (build (car args) (map string->symbol (cdr args)))]
    [else (error 'startup-pack "usage: <out.pack> <root> ... | --verify <pack>")]))
