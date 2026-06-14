((name . pvector-runtime-boundary)
 (format-version . 2)
 (status . runtime-paper-finger-tree-baseline)
 (design . "pvector-runtime-native-design.md")
 (public-module . racket/pvector)
 (runtime-adapter-module . racket/private/pvector-runtime-adapter)
 (current-racket-backend-module . racket/private/pvector)
 (runtime-candidate-file . "racket/src/cs/rumble/pvector.ss")

 (current-default
  . ((adapter-backend . (finger core))
     (chunked-runtime-status . removed-from-current-boundary)
     (core-available?-meaning . "true only after a no-chunk runtime core with large measured nodes is available")))

 (measure
  . ((mode . fixed-length)
     (unit . 0)
     (leaf . element-count)
     (node . subtree-length)
     (combine . +)
     (note . "The pvector/list-replacement measure is element count only; no generic monoid measure is exposed.")))

 (target-representations
  . ((empty
      . ((allocation . singleton)
         (tree . none)
         (chunk-cache . none)))
     (single
      . ((sizes . "1")
         (allocation . "one runtime object")
         (tree . none)
         (chunk-cache . none)))
     (deep-finger
      . ((sizes . "2..")
         (shape . "paper-style size-measured finger tree")
         (digits . "1..4 direct elements or child nodes")
         (nodes . "node2/node3 with cached element count")
         (chunked-leaves . none)
         (chunk-index-vector . none)
         (ref-cache . none)
         (vector-payload . none)))))

 (compatibility-views
  . ((pvector->chunk-vector
      . ((status . compatibility-only)
         (internal-representation . #f)
         (cache . none)
         (runtime-primitive . absent)
         (note . "The adapter may materialize immutable vector pieces for old low-level callers; callers must not rely on shape.")))
     (pvector->chunk-vector/shared
      . ((status . compatibility-only)
         (internal-representation . #f)
         (runtime-primitive . absent)
         (cache . none)))))

 (runtime-adapter
  . ((file . "racket/collects/racket/private/pvector-runtime-adapter.rkt")
     (fallback-module . "racket/collects/racket/private/pvector.rkt")
     (disabled-core-reason . "compiled core is disabled unless it reports the no-chunk shape")
     (probe-functions . (pvector-runtime-adapter-backend
                         pvector-runtime-adapter-core-available?))
     (expected-default-backend . (finger core))))

 (acceptance
  . ((correctness
      . ("./racket/bin/racket -y pkgs/racket-test/tests/racket/pvector-runtime-adapter.rkt"
         "./racket/bin/racket -y pkgs/racket-test/tests/racket/pvector.rkt"
         "./racket/bin/racket -y pkgs/racket-test/tests/generic/stream.rkt"))
     (no-chunk-baseline
      . ((adapter-backend . (finger core))
         (shape-stats-backend . (finger core))
         (chunk-index-vectors . 0)
         (chunk-constructor-primitives . absent)
         (chunk-view-primitives . absent)
         (hot-sequence-path . vector-snapshot-no-chunk-view)
         (sequence-cursor-primitives . absent)
         (core-linear-traversal . map-for-each-list)
         (ref-cache? . #f)
         (core-large-finger
          . ((payload-vectors . 0)
             (digit-vectors . 2)
             (finger-nodes . positive)))))
     (performance
      . ((release-gate . "./racket/bin/racket -y pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/gate.rkt --performance")
         (smoke-gate . "./racket/bin/racket -y pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/gate.rkt --performance-smoke")
         (workload-script . "pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/list-workload.rkt")
         (spectrum-script . "pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/list-spectrum.rkt")
         (score-script . "pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/list-score.rkt")
         (score-script-output . "detail rows include iterations, real-ms, real-ns/op, live-bytes, academic-result-cost units, and scores; power-score rows aggregate each power-of-two size; total-score rows aggregate power scores")
         (score-profile
          . ((name . academic-clean)
             (baseline . list)
             (speed-weight . 0.7)
             (cost-weight . 0.3)
             (score-direction . higher-is-better)
             (cost-model . academic-result-cost)
             (size-weighting . equal-per-power-size)))
         (latest-smoke
          . ((date . "2026-06-14")
             (status . stale-after-small-flat-removal)
             (known-blockers
              . ("performance must be remeasured with list-score before adding representation optimizations"
                 "paper-style deep-finger baseline is correctness-first and not expected to pass the old flat-tuned smoke thresholds"))))
         (latest-score-smoke
         . ((date . "2026-06-14")
             (command . "./racket/bin/racket -y pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/list-score.rkt --target-ms 3 --m 100 --max-m 100000 --sizes 1,2,4,8,16,64,256 --ops build,sum,append-self,map-add1 --impls list,vector,treelist,pvector,adapter-pvector")
             (status . paper-baseline-measured)
             (note . "This score smoke is a broad optimization signal, not an acceptance threshold.")
             (total-score/list
              . ((list . 1.0)
                 (vector . 1.2505)
                 (treelist . 0.8804)
                 (pvector . 0.5659)
                 (adapter-pvector . 0.5624)))
             (speed-score/list
              . ((list . 1.0)
                 (vector . 1.0260)
                 (treelist . 0.6215)
                 (pvector . 0.3665)
                 (adapter-pvector . 0.3797)))
             (cost-score/list
              . ((list . 1.0)
                 (vector . 1.9841)
                 (treelist . 1.9841)
                 (pvector . 1.5587)
                 (adapter-pvector . 1.4062)))))))
     (next-runtime-gate
      . ("remeasure paper-style empty/single/deep-finger paths with list-score"
         "only add specialized representations after list-score shows broad benefit, not from a single size/op")))))
