#lang racket/base

(require racket/file
         racket/list
         racket/path
         setup/dirs
         setup/link)

(provide compiled-cache-root
         compiled-cache-source-dirs
         delete-compiled-cache!
         write-compiled-cache-debug-event!)

(define (read-config)
  (define dir (find-config-dir))
  (define file (and dir (build-path dir "config.rktd")))
  (or (and file
           (file-exists? file)
           (with-handlers ([exn:fail? (lambda (exn) #hash())])
             (call-with-input-file*
              file
              (lambda (in)
                (call-with-default-reading-parameterization
                 (lambda ()
                   (define v (read in))
                   (if (hash? v) v #hash())))))))
      #hash()))

(define (coerce-complete-path p)
  (cond
    [(string? p) (simplify-path (path->complete-path (string->path p)))]
    [(bytes? p) (simplify-path (path->complete-path (bytes->path p)))]
    [(path? p) (simplify-path (path->complete-path p))]
    [else #f]))

(define (default-system-cache-root)
  (case (system-type)
    [(windows) (build-path (find-system-path 'cache-dir) "compiled-system")]
    [else (build-path "/" "var" "cache" "racket" "compiled")]))

(define (compiled-cache-root kind [config (read-config)])
  (case kind
    [(user) (build-path (find-system-path 'cache-dir) "compiled")]
    [(system)
     (or (coerce-complete-path
          (hash-ref config 'compiled-file-system-cache-root #f))
         (default-system-cache-root))]
    [else
     (raise-argument-error 'compiled-cache-root "(or/c 'user 'system)" kind)]))

(define (existing-dir-or-path p)
  (and p (simplify-path (path->complete-path p))))

(define (link-file-source-dirs link-file)
  (with-handlers ([exn:fail? (lambda (exn) null)])
    (append
     (for/list ([p (in-list (links #:file link-file #:root? #t))])
       (existing-dir-or-path p))
     (for/list ([name+path (in-list (links #:file link-file #:with-path? #t))])
       (existing-dir-or-path (cdr name+path))))))

(define (linked-source-dirs)
  (append*
   (for/list ([p (in-list (current-library-collection-links))]
              #:when (path? p))
     (link-file-source-dirs p))))

(define (compiled-cache-source-dirs)
  (remove-duplicates
   (filter values
           (append
            (for/list ([p (in-list (current-library-collection-paths))])
              (existing-dir-or-path p))
            (for/list ([p (in-list (get-pkgs-search-dirs))])
              (existing-dir-or-path p))
            (list (existing-dir-or-path (find-pkgs-dir)))
            (linked-source-dirs)))
   equal?))

(define (path->cache-relative-path path)
  ;; This mirrors the current compiled-root behavior for complete paths:
  ;; a source under /usr/share/racket maps under <root>/usr/share/racket.
  (define s (path->string (simplify-path (path->complete-path path))))
  (string->path (regexp-replace #rx"^[/\\\\]+" s "")))

(define (cache-path-for-source root source)
  (build-path root (path->cache-relative-path source)))

(define (debug-log-path root)
  (define parent (or (path-only root) (current-directory)))
  (build-path parent "racket-compiled-cache.log"))

(define (path->debug-string p)
  (cond
    [(path? p) (path->string p)]
    [(eq? p 'same) "same"]
    [else (format "~s" p)]))

(define (write-compiled-cache-debug-event! root event data)
  (define log-file (debug-log-path root))
  (with-handlers ([exn:fail?
                   (lambda (exn)
                     (eprintf "warning: could not write compiled-cache debug log ~a: ~a\n"
                              log-file
                              (exn-message exn)))])
    (make-directory* (or (path-only log-file) (current-directory)))
    (call-with-output-file*
     log-file
     #:exists 'append
     (lambda (out)
       (write
        (hash 'time (current-seconds)
              'event event
              'root (path->debug-string root)
              'data data)
        out)
       (newline out)))))

(define (unsafe-root? root)
  (define p (simplify-path (path->complete-path root)))
  (define s (path->string p))
  (or (equal? p (find-system-path 'home-dir))
      (regexp-match? #rx"^/*$" s)
      (regexp-match? #rx"^/var/?$" s)
      (regexp-match? #rx"^/var/cache/?$" s)
      (regexp-match? #rx"^[A-Za-z]:[/\\\\]?$" s)))

(define (delete-path! p)
  (cond
    [(directory-exists? p) (delete-directory/files p #:must-exist? #f)]
    [(file-exists? p) (delete-file p)]
    [else (void)]))

(define (delete-compiled-cache! #:system? [system? #f]
                                #:unsafe-delete-all? [unsafe-delete-all? #f]
                                #:delete-only? [delete-only? #f]
                                #:who [who 'raco-setup])
  (define root (compiled-cache-root (if system? 'system 'user)))
  (define sources (compiled-cache-source-dirs))
  (define targets
    (if unsafe-delete-all?
        (list root)
        (for/list ([source (in-list sources)])
          (cache-path-for-source root source))))
  (write-compiled-cache-debug-event!
   root
   'delete-start
   (hash 'who (format "~a" who)
         'system? system?
         'unsafe-delete-all? unsafe-delete-all?
         'delete-only? delete-only?
         'sources (map path->debug-string sources)
         'targets (map path->debug-string targets)))
  (when (and unsafe-delete-all? (unsafe-root? root))
    (write-compiled-cache-debug-event!
     root
     'delete-refused
     (hash 'reason "refusing to delete a dangerous cache root"
           'root (path->debug-string root)))
    (raise-user-error who
                      (format "refusing to delete dangerous compiled-cache root: ~a" root)))
  (define deleted '())
  (define skipped '())
  (define errors '())
  (for ([target (in-list targets)])
    (cond
      [(or (file-exists? target) (directory-exists? target))
       (with-handlers ([exn:fail?
                        (lambda (exn)
                          (set! errors
                                (cons (cons (path->debug-string target)
                                            (exn-message exn))
                                      errors)))])
         (delete-path! target)
         (set! deleted (cons (path->debug-string target) deleted)))]
      [else
       (set! skipped (cons (path->debug-string target) skipped))]))
  (write-compiled-cache-debug-event!
   root
   'delete-finish
   (hash 'deleted (reverse deleted)
         'skipped (reverse skipped)
         'errors (reverse errors)))
  (unless (null? errors)
    (raise-user-error who
                      (format "compiled-cache deletion failed; see debug log: ~a"
                              (debug-log-path root))))
  (values root (reverse deleted) (reverse skipped)))
