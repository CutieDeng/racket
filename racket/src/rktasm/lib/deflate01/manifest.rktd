#hash((format . asmp-deflate-library)
      (version . 1)
      (name . "asmp_deflate")
      (library-name . "libasmp_deflate.a")
      (header . "lib/deflate01/include/asmp_deflate.h")
      (sources . (("019-fixed-chain" . "lib/deflate01/src/019-deflate-fixed-chain.asm")
                  ("028-canonical" . "lib/deflate01/src/028-deflate-dynamic-canonical-codes.asm")
                  ("029-reverse" . "lib/deflate01/src/029-deflate-dynamic-reverse-codes.asm")
                  ("031-rle" . "lib/deflate01/src/031-deflate-dynamic-code-length-rle.asm")
                  ("032-blfreq" . "lib/deflate01/src/032-deflate-dynamic-blfreq.asm")
                  ("037-code-counts" . "lib/deflate01/src/037-deflate-dynamic-code-counts.asm")
                  ("039-litlen-huffman" . "lib/deflate01/src/039-deflate-dynamic-litlen-huffman.asm")
                  ("041-bllen-huffman" . "lib/deflate01/src/041-deflate-dynamic-bllen-huffman.asm")
                  ("043-lz77-freq" . "lib/deflate01/src/043-deflate-dynamic-lz77-freq.asm")
                  ("044-distlen-huffman" . "lib/deflate01/src/044-deflate-dynamic-distlen-huffman.asm")
                  ("045-lz77-huffman" . "lib/deflate01/src/045-deflate-dynamic-lz77-huffman.asm")
                  ("046-auto-dynamic-probe" . "lib/deflate01/src/046-deflate-auto-dynamic-probe.asm")
                  ("047-auto-dynamic-cost-probe" . "lib/deflate01/src/047-deflate-auto-cost-probe.asm")
                  ("048-auto-dynamic-size-probe" . "lib/deflate01/src/048-deflate-auto-size-probe.asm")
                  ("049-auto-dynamic-prepared-size-probe" . "lib/deflate01/src/049-deflate-auto-prepared-size-probe.asm")
                  ("050-auto-dynamic-cheap-prepared-size-probe" . "lib/deflate01/src/050-deflate-auto-cheap-prepared-size-probe.asm")
                  ("051-blocked-fixed" . "lib/deflate01/src/051-deflate-blocked-fixed.asm")
                  ("052-blocked-auto" . "lib/deflate01/src/052-deflate-blocked-auto.asm")
                  ("053-blocked-dynamic-auto" . "lib/deflate01/src/053-deflate-blocked-dynamic-auto.asm")))
      (exports . ((stable
                   asmp_deflate_raw_bound
                   asmp_deflate_raw_scratch_size
                   asmp_deflate_raw_scratch_align
                   asmp_deflate_raw_fixed
                   asmp_deflate_raw_stored
                   asmp_deflate_raw_auto)
                  (experimental
                   asmp_deflate_raw_dynamic_lz77_huffman_bound
                   asmp_deflate_raw_dynamic_lz77_huffman_scratch_size
                   asmp_deflate_raw_dynamic_lz77_huffman_scratch_align
                   asmp_deflate_raw_dynamic_lz77_huffman
                   asmp_deflate_raw_auto_dynamic_probe_bound
                   asmp_deflate_raw_auto_dynamic_probe_scratch_size
                   asmp_deflate_raw_auto_dynamic_probe_scratch_align
                   asmp_deflate_raw_auto_dynamic_probe
                   asmp_deflate_raw_auto_dynamic_cost_probe_bound
                   asmp_deflate_raw_auto_dynamic_cost_probe_scratch_size
                   asmp_deflate_raw_auto_dynamic_cost_probe_scratch_align
                   asmp_deflate_raw_auto_dynamic_cost_probe
                   asmp_deflate_raw_auto_dynamic_size_probe_bound
                   asmp_deflate_raw_auto_dynamic_size_probe_scratch_size
                   asmp_deflate_raw_auto_dynamic_size_probe_scratch_align
                   asmp_deflate_raw_auto_dynamic_size_probe
                   asmp_deflate_raw_auto_dynamic_prepared_size_probe_bound
                   asmp_deflate_raw_auto_dynamic_prepared_size_probe_scratch_size
                   asmp_deflate_raw_auto_dynamic_prepared_size_probe_scratch_align
                   asmp_deflate_raw_auto_dynamic_prepared_size_probe
                   asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_bound
                   asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_scratch_size
                   asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_scratch_align
                   asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe
                   asmp_deflate_raw_blocked_fixed_bound
                   asmp_deflate_raw_blocked_fixed_scratch_size
                   asmp_deflate_raw_blocked_fixed_scratch_align
                   asmp_deflate_raw_blocked_fixed
                   asmp_deflate_raw_blocked_auto_bound
                   asmp_deflate_raw_blocked_auto_scratch_size
                   asmp_deflate_raw_blocked_auto_scratch_align
                   asmp_deflate_raw_blocked_auto
                   asmp_deflate_raw_blocked_dynamic_auto_bound
                   asmp_deflate_raw_blocked_dynamic_auto_scratch_size
                   asmp_deflate_raw_blocked_dynamic_auto_scratch_align
                   asmp_deflate_raw_blocked_dynamic_auto))))
