#hash((format . asmp-zstd-library)
      (version . 1)
      (name . "asmp_zstd")
      (library-name . "libasmp_zstd.a")
      (header . "lib/zstd01/include/asmp_zstd.h")
      (sources . (("001-frame-raw-rle" . "lib/zstd01/src/001-frame-raw-rle.asm")
                  ("002-frame-litonly" . "lib/zstd01/src/002-frame-litonly.asm")
                  ("003-frame-seq-rle" . "lib/zstd01/src/003-frame-seq-rle.asm")
                  ("004-frame-seq-rle-wide" . "lib/zstd01/src/004-frame-seq-rle-wide.asm")
                  ("005-frame-seq-rle-full" . "lib/zstd01/src/005-frame-seq-rle-full.asm")
                  ("006-frame-single-match" . "lib/zstd01/src/006-frame-single-match.asm")
                  ("007-frame-predef-single-match" . "lib/zstd01/src/007-frame-predef-single-match.asm")
                  ("008-frame-multirle" . "lib/zstd01/src/008-frame-multirle.asm")
                  ("009-frame-multitoken" . "lib/zstd01/src/009-frame-multitoken.asm")
                  ("010-frame-multitoken-tail" . "lib/zstd01/src/010-frame-multitoken-tail.asm")
                  ("011-frame-predef-seqstore" . "lib/zstd01/src/011-frame-predef-seqstore.asm")))
      (exports . ((stable
                   asmp_zstd_compress_bound
                   asmp_zstd_scratch_size
                   asmp_zstd_scratch_align
                   asmp_zstd_compress_default)
                  (experimental
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
                   asmp_zstd_compress_predef_seqstore))))
