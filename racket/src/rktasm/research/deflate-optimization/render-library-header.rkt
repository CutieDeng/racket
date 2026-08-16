#!/usr/bin/env racket
#lang racket

(require racket/cmdline
         racket/file
         racket/runtime-path
         "library-manifest.rkt")

(define-runtime-path default-manifest "asmp-deflate-library.rktd")

(module+ main
  (define manifest-path default-manifest)
  (define output-path #f)
  (define check? #f)
  (command-line
   #:program "render-library-header.rkt"
   #:once-each
   [("--manifest") path "Library manifest to read"
                   (set! manifest-path path)]
   [("-o" "--output") path "Header output path; defaults to manifest header"
                    (set! output-path path)]
   [("--check") "Fail if the generated header differs from the output path"
                (set! check? #t)]
   #:args ()
   (define manifest (read-library-manifest manifest-path))
   (define header-path (or output-path (manifest-header-path manifest)))
   (define rendered (render-library-header manifest))
   (if check?
       (unless (and (file-exists? header-path)
                    (equal? rendered (file->string header-path)))
         (error 'render-library-header
                "generated header differs from ~a"
                header-path))
       (call-with-output-file header-path
         (lambda (out) (display rendered out))
         #:exists 'truncate/replace))))
