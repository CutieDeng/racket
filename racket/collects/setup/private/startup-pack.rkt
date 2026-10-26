#lang racket/base
;; The startup pack: one file carrying the compiled forms of the modules
;; a default REPL loads, with an index from collection references and
;; source paths to the members. The expander consults it at startup
;; (see racket/src/expander/boot/startup-pack.rkt); this module builds
;; it (`raco setup`) and keeps it honest (the compilation manager marks
;; it stale when it rewrites a member).
;;
;; Format v1:
;;   #"RKTPK1\n" <u32 header-len> <header> <u32 index-len> <index> <members...>
;;   header = (version "..." vm "..." library-subpath "..." links "..." paths "..."
;;            modes "..." build-time N members N)
;;   index  = #( #(src-path zo-path (key ...) offset len zo-sha1) ... )
;; The header strings are produced exactly as the expander reproduces
;; them at startup; a mismatch disables the pack.
(require racket/list racket/string racket/port file/sha1 setup/dirs)

(provide startup-pack-path
         startup-pack-stale-path
         startup-pack-roots
         build-startup-pack
         verify-startup-pack
         startup-pack-member?
         mark-startup-pack-stale!
         clear-startup-pack-stale!)

(define MAGIC #"RKTPK1\n")

(define (startup-pack-path)
  (define share (find-share-dir))
  (and share (build-path share "startup.pack")))

(define (startup-pack-stale-path [pack (startup-pack-path)])
  (and pack (path-add-extension pack #".stale")))

;; Roots: the default REPL's entry points; ones that are not installed
;; are skipped by the builder.
(define (startup-pack-roots)
  '(racket/init racket/interactive xrepl expeditor syntax-color/racket-lexer))

;; ---------------------------------------------------------------------
;; collection keys: exactly what the resolver hands to `find-col-file`
;; as (collection col-path file-name), joined with "/"

(define (ss->rkt s)
  (if (and (>= (string-length s) 3) (string-suffix? s ".ss"))
      (string-append (substring s 0 (- (string-length s) 3)) ".rkt")
      s))

(define (split-relative-string s)
  (define parts (string-split s "/" #:trim? #f))
  (values (drop-right parts 1) (last parts)))

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
  (define keys (make-hash))   ; path -> keys
  (define order '())
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
        ;; a submodule reference may have declared only the submodule
        (module-declared? name #t)
        (for* ([phase+mpis (in-list (module->imports (make-resolved-module-path name)))]
               ;; label-phase imports are never loaded at run time
               #:when (car phase+mpis)
               [imp (in-list (cdr phase+mpis))])
          (define-values (sub-mp base) (module-path-index-split imp))
          (when sub-mp
            (visit! sub-mp (module-path-index-join name #f))))
        (set! order (cons name order)))))
  (define skipped-roots
    (for/list ([r roots]
               #:unless (with-handlers ([exn:fail? (lambda (e) #f)])
                          (visit! r #f)
                          #t))
      r))
  (values (reverse order) keys skipped-roots))

;; ---------------------------------------------------------------------
;; write / verify

(define (u32 n) (integer->integer-bytes n 4 #f #f))

(define (header-string)
  (list 'version (version)
        'vm (symbol->string (system-type 'vm))
        'library-subpath (path->string (system-library-subpath #f))
        'links (format "~s" (map (lambda (p) (and p (path->string p))) (current-library-collection-links)))
        'paths (format "~s" (map path->string (current-library-collection-paths)))
        'modes (format "~s" (map path->string (use-compiled-file-paths)))))

;; -> (values member-count skipped-roots)
(define (build-startup-pack out roots)
  (define-values (order keys skipped-roots)
    (parameterize ([current-namespace (make-base-empty-namespace)])
      (compute-closure roots)))
  (define members
    (for/list ([src (in-list order)]
               #:when (file-exists? (zo-path-of src)))
      (define zo (zo-path-of src))
      (define so (path-replace-extension zo #".so"))
      (when (file-exists? so)
        (error 'build-startup-pack "native extension present: ~a" so))
      (list src zo (reverse (hash-ref keys src null)))))
  (define datas (for/list ([m members]) (call-with-input-file (cadr m) port->bytes)))
  (define (make-index base)
    (for/fold ([acc '()] [off base] #:result (list->vector (reverse acc)))
              ([m members] [d datas])
      (values (cons (vector (path->string (car m)) (path->string (cadr m)) (caddr m)
                            off (bytes-length d) (sha1 (open-input-bytes d)))
                    acc)
              (+ off (bytes-length d)))))
  (define header
    (append (header-string)
            (list 'build-time (current-seconds) 'members (length members))))
  (define header-bytes (string->bytes/utf-8 (format "~s" header)))
  (define (index-bytes base) (string->bytes/utf-8 (format "~s" (make-index base))))
  (define base
    (let loop ([guess (+ (bytes-length MAGIC) 4 (bytes-length header-bytes) 4 (bytes-length (index-bytes 0)))])
      (define b (+ (bytes-length MAGIC) 4 (bytes-length header-bytes) 4 (bytes-length (index-bytes guess))))
      (if (= b guess) b (loop b))))
  (define ib (index-bytes base))
  (define-values (dir name dir?) (split-path out))
  (define tmp (build-path dir (path-add-extension name #".tmp")))
  (call-with-output-file tmp #:exists 'truncate/replace
    (lambda (o)
      (write-bytes MAGIC o)
      (write-bytes (u32 (bytes-length header-bytes)) o) (write-bytes header-bytes o)
      (write-bytes (u32 (bytes-length ib)) o) (write-bytes ib o)
      (for ([d datas]) (write-bytes d o))))
  (rename-file-or-directory tmp out #t)
  (values (length members) skipped-roots))

(define (read-pack-index in)
  (unless (equal? (read-bytes (bytes-length MAGIC) in) MAGIC) (error 'startup-pack "bad magic"))
  (define hl (integer-bytes->integer (read-bytes 4 in) #f #f))
  (define header (read (open-input-bytes (read-bytes hl in))))
  (define il (integer-bytes->integer (read-bytes 4 in) #f #f))
  (define index (read (open-input-bytes (read-bytes il in))))
  (values header index))

;; -> number of mismatching members
(define (verify-startup-pack pack)
  (call-with-input-file pack
    (lambda (in)
      (define-values (header index) (read-pack-index in))
      (for/sum ([e (in-vector index)])
        (file-position in (vector-ref e 3))
        (define d (read-bytes (vector-ref e 4) in))
        (if (and (equal? d (call-with-input-file (vector-ref e 1) port->bytes))
                 (equal? (sha1 (open-input-bytes d)) (vector-ref e 5)))
            0
            1)))))

;; ---------------------------------------------------------------------
;; staleness, for the compilation manager

(define member-table #f) ; #f = not loaded; hash of zo-path string -> #t; 'none = no pack

(define (startup-pack-member? zo-path)
  (define pack (startup-pack-path))
  (cond
    [(not pack) #f]
    [else
     (unless member-table
       (set! member-table
             (with-handlers ([exn:fail? (lambda (e) 'none)])
               (if (file-exists? pack)
                   (call-with-input-file pack
                     (lambda (in)
                       (define-values (header index) (read-pack-index in))
                       (for/hash ([e (in-vector index)]) (values (vector-ref e 1) #t))))
                   'none))))
     (and (hash? member-table)
          (hash-ref member-table (path->string (path->complete-path zo-path)) #f))]))

(define (mark-startup-pack-stale!)
  (define stale (startup-pack-stale-path))
  (when stale
    (with-handlers ([exn:fail? void])
      (call-with-output-file stale #:exists 'truncate void))))

(define (clear-startup-pack-stale! [pack (startup-pack-path)])
  (define stale (startup-pack-stale-path pack))
  (when (and stale (file-exists? stale))
    (delete-file stale)))
