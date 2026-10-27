#lang racket/base
;; The startup pack: one file carrying the compiled forms of the modules
;; a default REPL loads, with an index from collection references and
;; source paths to the members. The expander consults it at startup
;; (see racket/src/expander/boot/startup-pack.rkt); this module builds
;; it (`raco setup`) and keeps it honest (the compilation manager marks
;; it stale when it rewrites a member).
;;
;; Format v3:
;;   #"RKTPK4\n" <u32 header-len> <header s-exp> <u32 index-len> <index> <members...>
;;   header = (version "..." vm "..." library-subpath "..." modes "..."
;;            build-time N members N)
;;   index  = <u32 count> then per member:
;;            <u16 n><src path bytes> <u16 n><zo path bytes>
;;            <u8 k> k * (<u16 n><key bytes>) <u32 offset> <u32 length> <20 bytes sha1>
;;            <u8 kind> <u16 table-len> <u16 m> m * (<u16 n><bundle name> <u32 offset in member> <u32 length> <20 bytes sha1>)
;;   table-len is the byte length of what follows it in the record, so
;;   that the table can be skipped or kept as one byte string.
;;   kind is `B` for a file that is one linklet bundle or `D` for a
;;   linklet directory; the bundle table lists the bundles of the file
;;   with the names as the directory encodes them (the root module is
;;   #""), so that the load handler finds a submodule's bundle and its
;;   hash code without scanning the file.
;; The index is binary so that decoding it costs a fraction of a
;; millisecond at every startup (an s-expression index took 2-3 ms to
;; read and 7 ms to turn into tables).
(require racket/list racket/string racket/port file/sha1 setup/dirs)

(provide startup-pack-path
         startup-pack-stale-path
         startup-pack-roots
         build-startup-pack
         verify-startup-pack
         startup-pack-member?
         mark-startup-pack-stale!
         clear-startup-pack-stale!)

(define MAGIC #"RKTPK4\n")

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
(define (u16 n) (integer->integer-bytes n 2 #f #f))

(define (header-string)
  (list 'version (version)
        'vm (symbol->string (system-type 'vm))
        'library-subpath (path->string (system-library-subpath #f))
        'modes (format "~s" (map path->string (use-compiled-file-paths)))))

;; index bytes for the members, with offsets relative to `base`
(define (index-bytes members datas base)
  (define o (open-output-bytes))
  (write-bytes (u32 (length members)) o)
  (for/fold ([off base]) ([m members] [d datas])
    (define src (path->bytes (car m)))
    (define zo (path->bytes (cadr m)))
    (write-bytes (u16 (bytes-length src)) o) (write-bytes src o)
    (write-bytes (u16 (bytes-length zo)) o) (write-bytes zo o)
    (write-bytes (bytes (length (caddr m))) o)
    (for ([k (caddr m)])
      (define kb (string->bytes/utf-8 k))
      (write-bytes (u16 (bytes-length kb)) o) (write-bytes kb o))
    (write-bytes (u32 off) o)
    (write-bytes (u32 (bytes-length d)) o)
    (write-bytes (sha1-bytes (open-input-bytes d)) o)
    (define-values (kind table) (bundle-table d (cadr m)))
    (write-bytes (bytes (char->integer kind)) o)
    (define tb (let ([t (open-output-bytes)])
                 (write-bytes (u16 (length table)) t)
                 (for ([e table])
                   (write-bytes (u16 (bytes-length (car e))) t) (write-bytes (car e) t)
                   (write-bytes (u32 (cadr e)) t)
                   (write-bytes (u32 (caddr e)) t)
                   (write-bytes (cadddr e) t))
                 (get-output-bytes t)))
    (write-bytes (u16 (bytes-length tb)) o)
    (write-bytes tb o)
    (+ off (bytes-length d)))
  (get-output-bytes o))

;; Parse a compiled file's header: -> (values tag header-length sha1)
;; where sha1 is 20 bytes (all zero when the bundle has no hash code)
(define (bundle-header d at)
  (define (bad) (error 'build-startup-pack "not a compiled module file at ~a" at))
  (unless (and (<= (+ at 2) (bytes-length d))
               (= (bytes-ref d at) (char->integer #\#))
               (= (bytes-ref d (add1 at)) (char->integer #\~)))
    (bad))
  (define vers-len (bytes-ref d (+ at 2)))
  (define vm-len (bytes-ref d (+ at 3 vers-len)))
  (define tag-at (+ at 4 vers-len vm-len))
  (define tag (integer->char (bytes-ref d tag-at)))
  (values tag
          (- (add1 tag-at) at)
          (if (eqv? tag #\B)
              (subbytes d (add1 tag-at) (+ tag-at 21))
              (make-bytes 20 0))))

;; -> (values kind (listof (list name-bytes offset length sha1)))
(define (bundle-table d zo)
  (define-values (tag hlen sha1) (bundle-header d 0))
  (define (u32-at i) (integer-bytes->integer d #f #f i (+ i 4)))
  (case tag
    [(#\B) (values #\B (list (list #"" 0 (bytes-length d) sha1)))]
    [(#\D)
     (define count (u32-at hlen))
     (define-values (entries _)
       (for/fold ([acc null] [i (+ hlen 4)]) ([k count])
         (define name-len (u32-at i))
         (define name (subbytes d (+ i 4) (+ i 4 name-len)))
         (define off (u32-at (+ i 4 name-len)))
         (define len (u32-at (+ i 8 name-len)))
         ;; left and right are the directory's search tree; not needed
         (define sha1
           (if (and (positive? len)
                    (= (bytes-ref d off) (char->integer #\#)))
               (let-values ([(t h s) (bundle-header d off)]) s)
               (make-bytes 20 0)))
         (values (cons (list name off len sha1) acc) (+ i 20 name-len))))
     (values #\D (reverse entries))]
    [else (error 'build-startup-pack "unknown compiled-file tag ~s in ~a" tag zo)]))

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
  (define header
    (append (header-string)
            (list 'build-time (current-seconds) 'members (length members))))
  (define header-bytes (string->bytes/utf-8 (format "~s" header)))
  ;; the index length does not depend on the offsets (fixed-width), so
  ;; the base is known after one measurement
  (define base (+ (bytes-length MAGIC) 4 (bytes-length header-bytes) 4
                  (bytes-length (index-bytes members datas 0))))
  (define ib (index-bytes members datas base))
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

(define (read-u32 in) (integer-bytes->integer (read-bytes 4 in) #f #f))
(define (read-u16 in) (integer-bytes->integer (read-bytes 2 in) #f #f))

;; -> (values header (listof (vector src-bytes zo-bytes keys offset length sha1-bytes)))
(define (read-pack-index in)
  (unless (equal? (read-bytes (bytes-length MAGIC) in) MAGIC) (error 'startup-pack "bad magic"))
  (define hl (read-u32 in))
  (define header (read (open-input-bytes (read-bytes hl in))))
  (define il (read-u32 in))
  (define ip (open-input-bytes (read-bytes il in)))
  (define n (read-u32 ip))
  (define index
    (for/list ([i n])
      (define src (read-bytes (read-u16 ip) ip))
      (define zo (read-bytes (read-u16 ip) ip))
      (define k (read-byte ip))
      (define keys (for/list ([j k]) (read-bytes (read-u16 ip) ip)))
      (define off (read-u32 ip))
      (define len (read-u32 ip))
      (define sha (read-bytes 20 ip))
      (read-byte ip) ; kind
      (read-bytes (read-u16 ip) ip) ; bundle table
      (vector src zo keys off len sha)))
  (values header index))

;; -> number of mismatching members
(define (verify-startup-pack pack)
  (call-with-input-file pack
    (lambda (in)
      (define-values (header index) (read-pack-index in))
      (for/sum ([e (in-list index)])
        (file-position in (vector-ref e 3))
        (define d (read-bytes (vector-ref e 4) in))
        (if (and (equal? d (call-with-input-file (bytes->path (vector-ref e 1)) port->bytes))
                 (equal? (sha1-bytes (open-input-bytes d)) (vector-ref e 5)))
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
                       (for/hash ([e (in-list index)]) (values (vector-ref e 1) #t))))
                   'none))))
     (and (hash? member-table)
          (hash-ref member-table (path->bytes (path->complete-path zo-path)) #f))]))

(define (mark-startup-pack-stale!)
  (define stale (startup-pack-stale-path))
  (when stale
    (with-handlers ([exn:fail? void])
      (call-with-output-file stale #:exists 'truncate void))))

(define (clear-startup-pack-stale! [pack (startup-pack-path)])
  (define stale (startup-pack-stale-path pack))
  (when (and stale (file-exists? stale))
    (delete-file stale)))
