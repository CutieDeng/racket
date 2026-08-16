#lang racket

(require rackunit
         rackunit/text-ui
         racket/runtime-path
         "../library-manifest.rkt")

(define-runtime-path manifest-path "../manifest.rktd")
(define-runtime-path header-path "../include/asmp_zstd.h")

(define tests
  (test-suite
   "zstd01 library header"
   (test-case "manifest exports stable symbols"
     (define manifest (read-library-manifest manifest-path))
     (check-equal?
     (manifest-export-names manifest)
      '(asmp_zstd_compress_bound
        asmp_zstd_scratch_size
        asmp_zstd_scratch_align
        asmp_zstd_compress_default
        asmp_zstd_compress_litonly_bound
        asmp_zstd_compress_litonly_scratch_size
        asmp_zstd_compress_litonly_scratch_align
        asmp_zstd_compress_litonly
        asmp_zstd_compress_seqrle_bound
        asmp_zstd_compress_seqrle_scratch_size
        asmp_zstd_compress_seqrle_scratch_align
        asmp_zstd_compress_seqrle
        asmp_zstd_compress_seqrle_wide_bound
        asmp_zstd_compress_seqrle_wide_scratch_size
        asmp_zstd_compress_seqrle_wide_scratch_align
        asmp_zstd_compress_seqrle_wide
        asmp_zstd_compress_seqrle_full_bound
        asmp_zstd_compress_seqrle_full_scratch_size
        asmp_zstd_compress_seqrle_full_scratch_align
        asmp_zstd_compress_seqrle_full
        asmp_zstd_compress_singlematch_bound
        asmp_zstd_compress_singlematch_scratch_size
        asmp_zstd_compress_singlematch_scratch_align
        asmp_zstd_compress_singlematch
        asmp_zstd_compress_predef_singlematch_bound
        asmp_zstd_compress_predef_singlematch_scratch_size
        asmp_zstd_compress_predef_singlematch_scratch_align
        asmp_zstd_compress_predef_singlematch
        asmp_zstd_compress_multirle_bound
        asmp_zstd_compress_multirle_scratch_size
        asmp_zstd_compress_multirle_scratch_align
        asmp_zstd_compress_multirle
        asmp_zstd_compress_multitoken_bound
        asmp_zstd_compress_multitoken_scratch_size
        asmp_zstd_compress_multitoken_scratch_align
        asmp_zstd_compress_multitoken
        asmp_zstd_compress_multitoken_tail_bound
        asmp_zstd_compress_multitoken_tail_scratch_size
        asmp_zstd_compress_multitoken_tail_scratch_align
        asmp_zstd_compress_multitoken_tail
        asmp_zstd_compress_predef_seqstore_bound
        asmp_zstd_compress_predef_seqstore_scratch_size
        asmp_zstd_compress_predef_seqstore_scratch_align
        asmp_zstd_compress_predef_seqstore)))
   (test-case "header is generated from manifest"
     (define manifest (read-library-manifest manifest-path))
     (check-equal? (render-library-header manifest)
                   (call-with-input-file header-path port->string)))
   (test-case "header contains zstd status and stable API marker"
     (define header (call-with-input-file header-path port->string))
     (check-true (regexp-match? #rx"enum asmp_zstd_status" header))
     (check-true (regexp-match? #rx"/\\* Stable API\\. \\*/" header))
     (check-true (regexp-match? #rx"/\\* Experimental API\\." header))
     (check-true (regexp-match? #rx"asmp_zstd_compress_default" header))
     (check-true (regexp-match? #rx"asmp_zstd_compress_litonly" header))
     (check-true (regexp-match? #rx"asmp_zstd_compress_seqrle" header))
     (check-true (regexp-match? #rx"asmp_zstd_compress_seqrle_wide" header))
     (check-true (regexp-match? #rx"asmp_zstd_compress_seqrle_full" header))
     (check-true (regexp-match? #rx"asmp_zstd_compress_singlematch" header))
     (check-true (regexp-match? #rx"asmp_zstd_compress_predef_singlematch" header))
     (check-true (regexp-match? #rx"asmp_zstd_compress_multirle" header))
     (check-true (regexp-match? #rx"asmp_zstd_compress_multitoken" header))
     (check-true (regexp-match? #rx"asmp_zstd_compress_multitoken_tail" header))
     (check-true (regexp-match? #rx"asmp_zstd_compress_predef_seqstore" header)))))

(module+ test
  (run-tests tests))
