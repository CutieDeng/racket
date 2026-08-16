#!/usr/bin/env racket
#lang racket

(require racket/cmdline
         racket/runtime-path
         "library-manifest.rkt")

(define-runtime-path default-manifest "manifest.rktd")

(module+ main
  (define manifest-path default-manifest)
  (define output-path #f)
  (define check? #f)
  (command-line
   #:program "render-header.rkt"
   #:once-each
   [("--manifest") path "Library manifest"
                   (set! manifest-path path)]
   [("--output") path "Header output path"
                 (set! output-path path)]
   [("--check") "Fail if the generated header differs from the manifest header"
                (set! check? #t)]
   #:args ()
   (define manifest (read-library-manifest manifest-path))
   (define rendered (render-library-header manifest))
   (cond
     [check?
      (define header-path (manifest-header-path manifest))
      (define current
        (and (file-exists? header-path)
             (call-with-input-file header-path port->string)))
      (unless (equal? rendered current)
        (error 'render-header.rkt
               "header is out of date: ~a"
               header-path))]
     [output-path
      (call-with-output-file output-path
        (lambda (out) (display rendered out))
        #:exists 'truncate/replace)]
     [else
      (display rendered)])))
