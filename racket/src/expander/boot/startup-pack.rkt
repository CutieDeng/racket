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
         pack-member-bytes)

(define MAGIC #"RKTPK1\n")

(define-place-local pack-on? #f)
(define-place-local pack-port #f)
(define-place-local pack-sema #f)
(define-place-local pack-guard #f)
(define-place-local pack-by-key #f)  ; "col/sub/file" -> source path
(define-place-local pack-by-src #f)  ; source path bytes -> compiled path
(define-place-local pack-by-zo #f)   ; compiled path bytes -> (cons offset length)

(define (startup-pack-place-init!)
  (set! pack-on? #f)
  (set! pack-port #f)
  (set! pack-sema #f)
  (set! pack-guard #f)
  (set! pack-by-key #f)
  (set! pack-by-src #f)
  (set! pack-by-zo #f))

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

(define (startup-pack-init! share-dir candidate-dirs-for)
  (startup-pack-place-init!)
  (let* ([env (getenv-bytes #"PLT_STARTUP_PACK")]
         [pack-path (cond
                      [(not env) (default-pack-path share-dir)]
                      [(equal? env #"off") #f]
                      [else (bytes->path env)])])
    (pack-debug "startup-pack: path ~s roots ~s modes ~s check ~s"
           pack-path (current-compiled-file-roots) (use-compiled-file-paths) (use-compiled-file-check))
    (when (and pack-path
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
               [index (and (pair? header) (read-sexp in (read-u32 in)))])
          (pack-debug "startup-pack: magic ~s header ~s index ~s" (equal? magic MAGIC) (and (pair? header) #t) (and (vector? index) (vector-length index)))
          (when (pair? header)
            (pack-debug "startup-pack: version ~s vm ~s subpath ~s modes ~s"
                   (equal? (header-ref header 'version) (version))
                   (equal? (header-ref header 'vm) (symbol->string (system-type 'vm)))
                   (equal? (header-ref header 'library-subpath) (path->string (system-library-subpath #f)))
                   (equal? (header-ref header 'modes) (modes-string))))
          (cond
            [(and (vector? index)
                  (equal? (header-ref header 'version) (version))
                  (equal? (header-ref header 'vm) (symbol->string (system-type 'vm)))
                  (equal? (header-ref header 'library-subpath) (path->string (system-library-subpath #f)))
                  (equal? (header-ref header 'modes) (modes-string)))
             (let ([by-key (make-hash)]
                   [by-src (make-hash)]
                   [by-zo (make-hash)])
               (let loop ([i 0])
                 (when (< i (vector-length index))
                   (let* ([e (vector-ref index i)]
                          [src (string->path (vector-ref e 0))]
                          [zo (string->path (vector-ref e 1))])
                     (for-each (lambda (k) (hash-set! by-key k src)) (vector-ref e 2))
                     (hash-set! by-src (path->bytes src) zo)
                     (hash-set! by-zo (path->bytes zo) (cons (vector-ref e 3) (vector-ref e 4))))
                   (loop (add1 i))))
               ;; Check every key against the live collection search order,
               ;; exactly as `find-col-file` would resolve it: the first
               ;; candidate directory that has the file wins. A key whose
               ;; winner is not the member's source is dropped, so that
               ;; module resolves and loads as it does without a pack.
               ;; Directory existence is cached per (candidate, collection),
               ;; so this costs about one `directory-exists?` per candidate
               ;; and collection plus a `file-exists?` per key.
               (let* ([split (lambda (k)
                               (let loop ([i 0] [start 0] [acc '()])
                                 (cond
                                   [(= i (string-length k)) (reverse (cons (substring k start i) acc))]
                                   [(char=? (string-ref k i) #\/) (loop (add1 i) (add1 i) (cons (substring k start i) acc))]
                                   [else (loop (add1 i) start acc)])))]
                      [dir-cache (make-hash)]
                      [col-dir (lambda (cand col)
                                 ;; the collection's directory for a candidate, or #f
                                 (let ([key (cons (if (box? cand) (unbox cand) cand) col)])
                                   (let ([v (hash-ref dir-cache key 'none)])
                                     (if (eq? v 'none)
                                         (let* ([d (if (box? cand) (unbox cand) (build-path cand col))]
                                                [r (and (directory-exists? d) d)])
                                           (hash-set! dir-cache key r)
                                           r)
                                         v))))])
                 (for-each
                  (lambda (k)
                    (let* ([parts (split k)]
                           [col (car parts)]
                           [rest (cdr parts)]
                           [member-src (hash-ref by-key k)]
                           [winner (let loop ([cands (candidate-dirs-for col)])
                                     (cond
                                       [(null? cands) #f]
                                       [else
                                        (let ([d (col-dir (car cands) col)])
                                          (if (and d (file-exists? (apply build-path d rest)))
                                              (apply build-path d rest)
                                              (loop (cdr cands))))]))])
                      (unless (and winner
                                   (equal? (path->bytes (simplify-path winner #f))
                                           (path->bytes (simplify-path member-src #f))))
                        (pack-debug "startup-pack: key ~s resolves to ~s, not the member; dropped" k winner)
                        (hash-remove! by-key k))))
                  (hash-keys by-key)))
               (set! pack-by-key by-key)
               (set! pack-by-src by-src)
               (set! pack-by-zo by-zo)
               (set! pack-port in)
               (set! pack-sema (make-semaphore 1))
               (set! pack-guard (current-security-guard))
               (set! pack-on? #t)
               (pack-debug "startup-pack: enabled, ~a members, ~a keys" (vector-length index) (hash-count by-key)))]
            [else
             (close-input-port in)]))))))

;; ----------------------------------------

(define (->string p)
  (cond
    [(path? p) (path->string p)]
    [(string? p) p]
    [else #f]))

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
                (hash-ref pack-by-key key #f))))))

(define (->bytes p)
  (cond
    [(path? p) (path->bytes p)]
    [(string? p) (path->bytes (string->path p))]
    [else #f]))

;; source path -> compiled path, when the pack carries it
(define (pack-zo-for-source path)
  (let ([b (->bytes path)])
    (and b (hash-ref pack-by-src b #f))))

;; compiled path -> its bytes from the pack, or #f
(define (pack-member-bytes path)
  (let* ([b (->bytes path)]
         [e (and b (hash-ref pack-by-zo b #f))])
    (and e
         (performance-region
          ['eval 'pack]
          (semaphore-wait pack-sema)
          (dynamic-wind
           void
           (lambda ()
             (file-position pack-port (car e))
             (let ([bstr (read-bytes (cdr e) pack-port)])
               (and (bytes? bstr)
                    (= (bytes-length bstr) (cdr e))
                    bstr)))
           (lambda () (semaphore-post pack-sema)))))))
