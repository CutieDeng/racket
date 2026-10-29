#lang racket/base
(require racket/private/place-local
         "../common/performance.rkt"
         "../eval/parameter.rkt")

;; Startup pack: one file that carries the compiled forms of the
;; modules that a default REPL loads, with an index from collection
;; references and source paths to those compiled forms. When the pack
;; applies, the resolver, `load/use-compiled`, and the load handler
;; take their answers from the index and the pack's bytes instead of
;; probing and opening the individual files; everything after the
;; bytes are in hand (submodule lookup, module cache, declaration) is
;; unchanged. See "repl-startup-pack-dev-2026-10-26.md".
;;
;; The pack applies only in the configuration it was built for:
;; default compiled-file roots and modes, the same collection links and
;; paths, the default load handler, the security guard that was
;; current at startup, and no "<pack>.stale" sentinel (written by the
;; compilation manager when it rewrites a member). Otherwise every
;; lookup says "not here" and the original paths run.

(provide startup-pack-init!
         startup-pack-place-init!
         pack-enabled?
         pack-collection-path
         pack-zo-for-source
         call-with-pack-member)

(define MAGIC #"RKTPK5\n")

(define-place-local pack-on? #f)
(define-place-local pack-port #f)
(define-place-local pack-sema #f)
(define-place-local pack-guard #f)
(define-place-local pack-by-key #f)  ; key bytes "col/sub/file" -> (mcons source-path-bytes checked?)
(define-place-local pack-by-src #f)  ; source path bytes -> compiled path bytes
(define-place-local pack-by-zo #f)   ; compiled path bytes -> (vector offset length table-bytes parsed-table)
(define-place-local pack-candidates #f) ; collection -> candidate directories, for key checks

(define (startup-pack-place-init!)
  (set! pack-on? #f)
  (set! pack-port #f)
  (set! pack-sema #f)
  (set! pack-guard #f)
  (set! pack-by-key #f)
  (set! pack-by-src #f)
  (set! pack-by-zo #f)
  (set! pack-candidates #f))

(define (pack-enabled?)
  (and pack-on?
       (eq? pack-guard (current-security-guard))))

;; ----------------------------------------

(define (getenv-bytes name)
  (environment-variables-ref (current-environment-variables) name))

(define (default-pack-path share-dir)
  ;; the installation's share directory is supplied by the caller
  ;; (see `find-share-dir` in "../eval/collection.rkt")
  (and (path? share-dir)
       (complete-path? share-dir)
       (build-path share-dir "startup.pack")))

(define (modes-string)
  (format "~s" (map path->string (use-compiled-file-paths))))

(define (read-u32 in)
  (let ([bstr (read-bytes 4 in)])
    (and (bytes? bstr)
         (= 4 (bytes-length bstr))
         (integer-bytes->integer bstr #f #f))))

(define (read-u16 in)
  (let ([bstr (read-bytes 2 in)])
    (and (bytes? bstr)
         (= 2 (bytes-length bstr))
         (integer-bytes->integer bstr #f #f))))

(define (read-sexp in len)
  (let ([bstr (and len (read-bytes len in))])
    (and (bytes? bstr)
         (= len (bytes-length bstr))
         (read (open-input-bytes bstr)))))

(define (header-ref header key)
  (let loop ([l header])
    (cond
      [(or (null? l) (null? (cdr l))) #f]
      [(eq? (car l) key) (cadr l)]
      [else (loop (cddr l))])))

(define pack-debug? (and (getenv-bytes #"PLT_STARTUP_PACK_DEBUG") #t))
(define (pack-debug fmt . args)
  (when pack-debug?
    (let ([e (current-error-port)])
      (write-string (apply format fmt args) e)
      (newline e))))

;; `roots` is a vector of the installation directories that member
;; paths are stored relative to (format v5): index 0 the main collection
;; directory, index 1 the installation's package directory, each as the
;; resolver sees it; a member's root tag 255 means an absolute path (the
;; builder's fallback for files outside both, as in an in-place build).
;; Relative storage keeps a build-time prefix out of the pack, which
;; rpm's check-buildroot rejected, and lets a relocated installation
;; still use it.
(define (startup-pack-init! share-dir roots candidate-dirs-for)
  (startup-pack-place-init!)
  (let* ([env (getenv-bytes #"PLT_STARTUP_PACK")]
         [pack-path (cond
                      [(not env) (default-pack-path share-dir)]
                      [(equal? env #"off") #f]
                      [else (bytes->path env)])])
    (pack-debug "startup-pack: path ~s roots ~s modes ~s check ~s"
           pack-path (current-compiled-file-roots) (use-compiled-file-paths) (use-compiled-file-check))
    (when (and pack-path
               (vector? roots)
               (equal? (current-compiled-file-roots) '(same))
               (let ([modes (use-compiled-file-paths)])
                 (and (pair? modes)
                      (null? (cdr modes))
                      (equal? (car modes) (string->path "compiled"))))
               (memq (use-compiled-file-check) '(modify-seconds exists))
               (file-exists? pack-path)
               (not (file-exists? (path-add-extension pack-path #".stale"))))
      (let ([in (open-input-file pack-path)])
        (let* ([magic (read-bytes (bytes-length MAGIC) in)]
               [header (and (equal? magic MAGIC) (read-sexp in (read-u32 in)))]
               [index-port (and (pair? header)
                                (let* ([len (read-u32 in)]
                                       [bstr (and len (read-bytes len in))])
                                  (and (bytes? bstr) (= len (bytes-length bstr))
                                       (open-input-bytes bstr))))])
          (pack-debug "startup-pack: magic ~s header ~s index ~s" (equal? magic MAGIC) (and (pair? header) #t) (and index-port #t))
          (when (pair? header)
            (pack-debug "startup-pack: version ~s vm ~s subpath ~s modes ~s"
                   (equal? (header-ref header 'version) (version))
                   (equal? (header-ref header 'vm) (symbol->string (system-type 'vm)))
                   (equal? (header-ref header 'library-subpath) (path->string (system-library-subpath #f)))
                   (equal? (header-ref header 'modes) (modes-string))))
          (cond
            [(and index-port
                  (equal? (header-ref header 'version) (version))
                  (equal? (header-ref header 'vm) (symbol->string (system-type 'vm)))
                  (equal? (header-ref header 'library-subpath) (path->string (system-library-subpath #f)))
                  (equal? (header-ref header 'modes) (modes-string)))
             (let ([by-key (make-hash)]
                   [by-src (make-hash)]
                   [by-zo (make-hash)]
                   [n (read-u32 index-port)]
                   ;; directory form, so that root + relative bytes is
                   ;; exactly the path the resolver builds for the member
                   [root-bytes (let ([v (make-vector (vector-length roots) #f)])
                                 (let rloop ([j 0])
                                   (when (< j (vector-length roots))
                                     (let ([r (vector-ref roots j)])
                                       (when (and (path? r) (complete-path? r))
                                         (vector-set! v j (path->bytes (path->directory-path (simplify-path r #f))))))
                                     (rloop (add1 j))))
                                 v)])
               (let loop ([i 0])
                 (when (< i n)
                   (let* ([tag (read-byte index-port)]
                          [root (cond
                                  [(= tag 255) #""]
                                  [(< tag (vector-length root-bytes)) (vector-ref root-bytes tag)]
                                  [else #f])]
                          [src (let ([b (read-bytes (read-u16 index-port) index-port)]) (and root (bytes-append root b)))]
                          [zo (let ([b (read-bytes (read-u16 index-port) index-port)]) (and root (bytes-append root b)))]
                          [k (read-byte index-port)])
                     (let kloop ([j 0])
                       (when (< j k)
                         (let ([kb (read-bytes (read-u16 index-port) index-port)])
                           (when src (hash-set! by-key kb (mcons src #f))))
                         (kloop (add1 j))))
                     (let* ([off (read-u32 index-port)]
                            [len (read-u32 index-port)])
                       (read-bytes 20 index-port) ; sha1, for `--verify`
                       ;; the bundle table is kept as bytes and parsed
                       ;; when the member is first loaded
                       (let* ([kind (read-byte index-port)]
                              [tbytes (read-bytes (read-u16 index-port) index-port)])
                         ;; a member under an unknown root is skipped
                         (when src
                           (hash-set! by-src src zo)
                           (hash-set! by-zo zo (vector off len kind tbytes #f))))))
                   (loop (add1 i))))
               (set! pack-by-key by-key)
               (set! pack-by-src by-src)
               (set! pack-by-zo by-zo)
               (set! pack-candidates (cons candidate-dirs-for (make-hash)))
               (set! pack-port in)
               (set! pack-sema (make-semaphore 1))
               (set! pack-guard (current-security-guard))
               (set! pack-on? #t)
               (pack-debug "startup-pack: enabled, ~a members, ~a keys" n (hash-count by-key)))]
            [else
             (close-input-port in)]))))))

;; ----------------------------------------

(define (->string p)
  (cond
    [(path? p) (path->string p)]
    [(string? p) p]
    [else #f]))

;; Validate a key against the live collection search order, exactly as
;; `find-col-file` resolves it: the first candidate directory that has
;; the file wins; the key stands only if the winner is the member's
;; source. Directory existence is cached per (candidate, collection).
;; Done on first use of a key, so a process pays only for the keys it
;; resolves.
(define (split-key k)
  (let loop ([i 0] [start 0] [acc '()])
    (cond
      [(= i (bytes-length k)) (reverse (cons (bytes->path (subbytes k start i)) acc))]
      [(= (bytes-ref k i) 47) (loop (add1 i) (add1 i) (cons (bytes->path (subbytes k start i)) acc))]
      [else (loop (add1 i) start acc)])))

(define (key-valid? k src)
  (let* ([parts (split-key k)]
         [col (car parts)]
         [rest (cdr parts)]
         [candidate-dirs-for (car pack-candidates)]
         [dir-cache (cdr pack-candidates)]
         [col-dir (lambda (cand)
                    (let ([key (cons (if (box? cand) (unbox cand) cand) col)])
                      (let ([v (hash-ref dir-cache key 'none)])
                        (if (eq? v 'none)
                            (let* ([d (if (box? cand) (unbox cand) (build-path cand col))]
                                   [r (and (directory-exists? d) d)])
                              (hash-set! dir-cache key r)
                              r)
                            v))))]
         [winner (let loop ([cands (candidate-dirs-for col)])
                   (cond
                     [(null? cands) #f]
                     [else
                      (let ([d (col-dir (car cands))])
                        (if (and d (file-exists? (apply build-path d rest)))
                            (apply build-path d rest)
                            (loop (cdr cands))))]))])
    (and winner
         (equal? (path->bytes (simplify-path winner #f)) src))))

;; collection reference as `find-col-file` receives it -> source path or #f
(define (pack-collection-path collection collection-path file-name)
  (let ([col (->string collection)]
        [file (->string file-name)])
    (and col file
         (let ([key (let loop ([l collection-path] [acc col])
                      (cond
                        [(null? l) (string-append acc "/" file)]
                        [else (let ([s (->string (car l))])
                                (and s (loop (cdr l) (string-append acc "/" s))))]))])
           (and key
                (let* ([kb (string->bytes/utf-8 key)]
                       [e (hash-ref pack-by-key kb #f)])
                  (and e
                       (cond
                         [(mcdr e) (bytes->path (mcar e))]
                         [(key-valid? kb (mcar e))
                          (set-mcdr! e #t)
                          (bytes->path (mcar e))]
                         [else
                          (pack-debug "startup-pack: key ~s does not resolve to the member; dropped" key)
                          (hash-remove! pack-by-key kb)
                          #f]))))))))

(define (->bytes p)
  (cond
    [(path? p) (path->bytes p)]
    [(string? p) (path->bytes (string->path p))]
    [else #f]))

;; source path -> compiled path, when the pack carries it
(define (pack-zo-for-source path)
  (let* ([b (->bytes path)]
         [zo (and b (hash-ref pack-by-src b #f))])
    (and zo (bytes->path zo))))

;; A member's bundle table: list of (vector name-bytes offset length hash-code),
;; `offset` relative to the member, `hash-code` 20 bytes or #f. Parsed
;; from the index bytes on first use and cached in the member's entry.
(define (member-table e)
  (or (vector-ref e 4)
      (let* ([in (open-input-bytes (vector-ref e 3))]
             [n (read-u16 in)]
             [table (let loop ([i 0])
                      (if (= i n)
                          '()
                          (let* ([name (read-bytes (read-u16 in) in)]
                                 [off (read-u32 in)]
                                 [len (read-u32 in)]
                                 [sha (read-bytes 20 in)])
                            (cons (vector name off len (and (nonzero-bytes? sha) sha))
                                  (loop (add1 i))))))])
        (vector-set! e 4 table)
        table)))

(define (nonzero-bytes? bstr)
  (let loop ([i 0])
    (cond
      [(= i (bytes-length bstr)) #f]
      [(eq? 0 (bytes-ref bstr i)) (loop (add1 i))]
      [else #t])))

;; Load a member in place: `proc` receives the pack's port, the member's
;; offset in the pack, whether the member is a linklet directory, and
;; its bundle table; it seeks within the member and reads the compiled
;; code straight from the file (one copy, into the bundle's byte string,
;; exactly as from a .zo file). The port is shared by the place, so the
;; semaphore is held for the whole span; the span is reading only, the
;; module's evaluation happens after it returns. -> (box result) or #f
(define (call-with-pack-member path proc)
  (let* ([b (->bytes path)]
         [e (and b (hash-ref pack-by-zo b #f))])
    (and e
         (performance-region
          ['eval 'pack]
          (semaphore-wait pack-sema)
          (dynamic-wind
           void
           (lambda ()
             (box (proc pack-port (vector-ref e 0) (eqv? (vector-ref e 2) 68) (member-table e))))
           (lambda () (semaphore-post pack-sema)))))))