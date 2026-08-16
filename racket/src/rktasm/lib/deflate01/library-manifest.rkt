#lang racket

(require racket/list
         racket/runtime-path
         racket/string
         "../../parser/frontend.rkt"
         "../../semantic/control-flow.rkt"
         "../../semantic/public-abi.rkt")

(provide
 root-relative-path
 read-library-manifest
 manifest-library-name
 manifest-header-path
 manifest-sources
 manifest-export-groups
 manifest-export-names
 library-public-abi-manifest
 render-library-header
 write-library-header)

(define-runtime-path root-dir "../..")

(define deflate-status-enum
  #<<C
enum asmp_deflate_status {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_DST_TOO_SMALL = 1,
  ASMP_DEFLATE_SCRATCH_TOO_SMALL = 2,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};
C
  )

(define (root-relative-path value)
  (define path (if (path? value) value (string->path (format "~a" value))))
  (if (absolute-path? path)
      path
      (build-path root-dir path)))

(define (valid-source-entry? entry)
  (and (pair? entry)
       (string? (car entry))
       (string? (cdr entry))))

(define (valid-export-group? group)
  (and (pair? group)
       (symbol? (car group))
       (andmap symbol? (cdr group))))

(define (read-library-manifest manifest-path)
  (define manifest (call-with-input-file manifest-path read))
  (unless (and (hash? manifest)
               (eq? (hash-ref manifest 'format #f) 'asmp-deflate-library)
               (equal? (hash-ref manifest 'version #f) 1))
    (error 'read-library-manifest
           "unsupported library manifest: ~a"
           manifest-path))
  (define sources (hash-ref manifest 'sources #f))
  (unless (and (list? sources) (andmap valid-source-entry? sources))
    (error 'read-library-manifest
           "manifest has invalid sources: ~a"
           manifest-path))
  (define exports (hash-ref manifest 'exports #f))
  (unless (and (list? exports) (andmap valid-export-group? exports))
    (error 'read-library-manifest
           "manifest has invalid exports: ~a"
           manifest-path))
  manifest)

(define (manifest-library-name manifest override)
  (or override
      (hash-ref manifest 'library-name
                (lambda () "libasmp_deflate.a"))))

(define (manifest-header-path manifest)
  (root-relative-path
   (hash-ref manifest 'header
             (lambda ()
               "lib/deflate01/include/asmp_deflate.h"))))

(define (manifest-sources manifest)
  (for/list ([entry (in-list (hash-ref manifest 'sources))])
    (cons (car entry) (root-relative-path (cdr entry)))))

(define (manifest-export-groups manifest)
  (hash-ref manifest 'exports))

(define (manifest-export-names manifest)
  (append-map cdr (manifest-export-groups manifest)))

(define (ok-items results)
  (for/list ([r (in-list (parse-results-items results))]
             #:when (parse-result-ok? r))
    (parse-result-instruction r)))

(define (source-public-abi-manifest source)
  (define results (parse-file source #:syntax 'gnu #:validate? #t))
  (unless (= (parse-results-error-count results) 0)
    (error 'library-public-abi-manifest
           "failed to parse public ABI source: ~a"
           source))
  (public-abi-manifest (build-cfg (ok-items results) source)))

(define (manifest-entry-table manifest)
  (for*/fold ([table (hash)])
             ([source-entry (in-list (manifest-sources manifest))]
              [entry (in-list
                      (hash-ref
                       (source-public-abi-manifest (cdr source-entry))
                       'exports))])
    (define name (hash-ref entry 'name))
    (when (hash-has-key? table name)
      (error 'library-public-abi-manifest
             "duplicate exported symbol in library sources: ~a"
             name))
    (hash-set table name entry)))

(define (library-entry-from-table table name)
  (define entry
    (hash-ref table
              name
              (lambda ()
                (error 'library-public-abi-manifest
                       "manifest export is not defined by any source: ~a"
                       name))))
  (unless (hash-ref entry 'header? #t)
    (error 'library-public-abi-manifest
           "manifest export is marked no-header in source: ~a"
           name))
  entry)

(define (ordered-library-entry-groups manifest)
  (define table (manifest-entry-table manifest))
  (for/list ([group (in-list (manifest-export-groups manifest))])
    (cons (car group)
          (for/list ([name (in-list (cdr group))])
            (library-entry-from-table table name)))))

(define (ordered-library-entries manifest)
  (append-map cdr (ordered-library-entry-groups manifest)))

(define (library-public-abi-manifest manifest)
  (define groups (ordered-library-entry-groups manifest))
  (hash 'format 'asmp-library-public-abi
        'version 1
        'name (hash-ref manifest 'name "asmp_library")
        'exports (append-map cdr groups)
        'groups groups))

(define (header-guard manifest)
  (define raw (hash-ref manifest 'name "asmp_library"))
  (define sanitized
    (regexp-replace* #rx"[^A-Za-z0-9_]" (string-upcase raw) "_"))
  (format "~a_H" sanitized))

(define (render-library-header manifest)
  (define abi-manifest (library-public-abi-manifest manifest))
  (public-c-header abi-manifest
                   #:guard (header-guard manifest)
                   #:body-prefix deflate-status-enum
                   #:entry-groups (hash-ref abi-manifest 'groups)))

(define (write-library-header manifest path)
  (call-with-output-file path
    (lambda (out)
      (display (render-library-header manifest) out))
    #:exists 'truncate/replace))
