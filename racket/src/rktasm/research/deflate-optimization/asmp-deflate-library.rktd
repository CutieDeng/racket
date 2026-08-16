#hash((format . asmp-deflate-library)
      (version . 1)
      (name . "asmp_deflate")
      (library-name . "libasmp_deflate.a")
      (header . "research/deflate-optimization/include/asmp_deflate.h")
      (sources . (("019-fixed-chain" . "example/019-deflate-fixed-chain.asm")
                  ("028-canonical" . "example/028-deflate-dynamic-canonical-codes.asm")
                  ("029-reverse" . "example/029-deflate-dynamic-reverse-codes.asm")
                  ("031-rle" . "example/031-deflate-dynamic-code-length-rle.asm")
                  ("032-blfreq" . "example/032-deflate-dynamic-blfreq.asm")
                  ("037-code-counts" . "example/037-deflate-dynamic-code-counts.asm")
                  ("039-litlen-huffman" . "example/039-deflate-dynamic-litlen-huffman.asm")
                  ("041-bllen-huffman" . "example/041-deflate-dynamic-bllen-huffman.asm")
                  ("043-lz77-freq" . "example/043-deflate-dynamic-lz77-freq.asm")
                  ("044-distlen-huffman" . "example/044-deflate-dynamic-distlen-huffman.asm")
                  ("045-lz77-huffman" . "example/045-deflate-dynamic-lz77-huffman.asm")
                  ("046-auto-dynamic-probe" . "example/046-deflate-auto-dynamic-probe.asm")
                  ("047-auto-dynamic-cost-probe" . "example/047-deflate-auto-cost-probe.asm")
                  ("048-auto-dynamic-size-probe" . "example/048-deflate-auto-size-probe.asm")
                  ("049-auto-dynamic-prepared-size-probe" . "example/049-deflate-auto-prepared-size-probe.asm")
                  ("050-auto-dynamic-cheap-prepared-size-probe" . "example/050-deflate-auto-cheap-prepared-size-probe.asm")
                  ("051-blocked-fixed" . "example/051-deflate-blocked-fixed.asm")
                  ("052-blocked-auto" . "example/052-deflate-blocked-auto.asm")
                  ("053-blocked-dynamic-auto" . "example/053-deflate-blocked-dynamic-auto.asm")))
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
