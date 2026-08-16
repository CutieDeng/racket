#lang racket/base
(require racket/file
         "setup-cmdline.rkt"
         "option.rkt"
         "compiled-cache.rkt"
         "setup-core.rkt"
         compiler/cm)

(provide go)

(module test racket/base)

(define-values (short-name x-flags
                           x-specific-collections x-specific-packages  x-specific-planet-packages
                           x-archives)
  (parse-cmdline (current-command-line-arguments)))

(define (get-x-flag s default)
  (define a (assq s x-flags))
  (if a
      (cadr a)
      default))

(define (has-x-flag? s)
  (get-x-flag s #f))

(define (go orig-compile-file-paths)
  (define use-system-cache? (has-x-flag? 'system-cache))
  (define reset-cache? (has-x-flag? 'reset-cache))
  (define delete-cache? (has-x-flag? 'delete-cache))
  (define unsafe-delete-all? (has-x-flag? 'unsafe-delete-all))
  (when (and unsafe-delete-all? (not (or reset-cache? delete-cache?)))
    (raise-user-error short-name
                      "--unsafe-delete-all must be combined with --reset-cache or --delete-cache"))
  (define system-cache-root
    (and use-system-cache? (compiled-cache-root 'system)))
  (define (prepare-system-cache!)
    (make-directory* system-cache-root)
    (write-compiled-cache-debug-event!
     system-cache-root
     'system-setup-start
     (hash 'program short-name
           'arguments (vector->list (current-command-line-arguments)))))
  (when (or reset-cache? delete-cache?)
    (define-values (root deleted skipped)
      (delete-compiled-cache! #:system? use-system-cache?
                              #:unsafe-delete-all? unsafe-delete-all?
                              #:delete-only? delete-cache?
                              #:who short-name))
    (printf "compiled cache root: ~a\n" root)
    (printf "compiled cache deleted: ~a\n" (length deleted))
    (printf "compiled cache skipped: ~a\n" (length skipped))
    (when delete-cache?
      (void)))
  ;; Convert parse-cmdline results into parameter settings:
  (unless delete-cache?
    (when use-system-cache?
      (prepare-system-cache!))
    (parameterize ([current-compiled-file-roots
                    (if use-system-cache?
                        (list system-cache-root)
                        (current-compiled-file-roots))]
                   [current-target-plt-directory-getter
                    (if (has-x-flag? 'all-users)
                        (lambda (preferred main-collects-parent-dir choices) 
                          main-collects-parent-dir)
                        (current-target-plt-directory-getter))]
                   [trust-existing-zos (or (has-x-flag? 'trust-existing-zos)
                                           (trust-existing-zos))]
                   [managed-recompile-only (or (has-x-flag? 'recompile-only)
                                               (managed-recompile-only))]
                   [managed-recompile-cache-dir (let ([d (get-x-flag 'recompile-cache #f)])
                                                  (and d
                                                       (path->complete-path d)))]
                   [specific-collections x-specific-collections]
                   [specific-packages x-specific-packages]
                   [archives x-archives]
                   [specific-planet-dirs x-specific-planet-packages]
                   
                   [setup-program-name short-name]
                   [setup-compiled-file-paths orig-compile-file-paths])
      (call-with-flag-params
       x-flags
       setup-core))))
