#lang racket

(require rackunit
         rackunit/text-ui
         racket/runtime-path
         "../library-manifest.rkt")

(define-runtime-path library-manifest-path
  "../manifest.rktd")
(define-runtime-path checked-in-header-path
  "../include/asmp_deflate.h")

(define (contains? text needle)
  (regexp-match? (regexp (regexp-quote needle)) text))

(define deflate-library-header-tests
  (test-suite
   "deflate library generated header"

   (test-case "checked-in header matches manifest-driven renderer"
     (define manifest (read-library-manifest library-manifest-path))
     (check-equal? (render-library-header manifest)
                   (file->string checked-in-header-path)))

   (test-case "header exposes curated stable and experimental APIs"
     (define manifest (read-library-manifest library-manifest-path))
     (define header (render-library-header manifest))
     (for ([name (in-list (manifest-export-names manifest))])
       (check-true (contains? header (symbol->string name))))
     (check-true (contains? header "enum asmp_deflate_status"))
     (check-true (contains? header "ASMP_DEFLATE_OK = 0"))
     (check-true (contains? header "/* Stable API. */"))
     (check-true (contains? header "/* Experimental API."))
     (check-true (contains? header "asmp_deflate_raw_auto_dynamic_probe")))

   (test-case "header does not expose internal dynamic-Huffman helpers"
     (define manifest (read-library-manifest library-manifest-path))
     (define header (render-library-header manifest))
     (for ([name (in-list '("asmp_deflate_dynamic_canonical_codes"
                            "asmp_deflate_dynamic_reverse_codes"
                            "asmp_deflate_dynamic_code_length_rle"
                            "asmp_deflate_dynamic_blfreq_count"
                            "asmp_deflate_dynamic_litlen_huffman"
                            "asmp_deflate_dynamic_distlen_huffman"))])
       (check-false (contains? header name))))))

(module+ test
  (void (run-tests deflate-library-header-tests)))

(module+ main
  (void (run-tests deflate-library-header-tests)))
