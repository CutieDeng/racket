((name . pvector-runtime-boundary)
 (format-version . 1)
 (status . racket-backend-before-runtime-downshift)
 (public-module . racket/pvector)
 (racket-backend-module . racket/private/pvector-chunked)
 (core-structure-module . racket/private/pvector-core)
 (default-chunk-size . 64)
 (endpoint-pack-limit . 4)
 (measure
  . ((mode . fixed-length)
     (unit . 0)
     (leaf . chunk-length)
     (node . subtree-length)
     (combine . +)
     (note . "The pvector/list-replacement measure is element count only.")))
 (public-boundary
  . ((wrapper-stays-in-racket . #t)
     (contracts-stay-in-racket . #t)
     (unsafe-submodule-stays-in-racket . #t)
     (runtime-objects-are-not-public . #t)
     (debug-shape-stats-private-only . #t)))
 (rumble-candidate
  . ((file . "racket/src/cs/rumble/pvector.ss")
     (included-from . "racket/src/cs/rumble.sls")
     (build-dependency-from . "racket/src/cs/main.zuo")
     (exported-from-rumble . core-pvector-primitives)
     (exported-names
      . (core-pvector?
         core-pvector-empty
         core-pvector-empty?
         core-pvector-length
         core-vector->pvector
         core-list->pvector
         core-make-pvector
         core-pvector->vector
         core-pvector->list
         core-pvector-ref
         core-pvector-set
         core-pvector-cons-left
         core-pvector-cons-right
         core-pvector-pop-left
         core-pvector-pop-right
         core-pvector-append
         core-pvector-split-at
         core-pvector-split-at-right
         core-pvector-take
         core-pvector-drop
         core-pvector-copy))
     (kernel-primitives
      . ((file . "racket/src/cs/primitive/kernel.ss")
         (names
          . (core-pvector?
             core-pvector-empty
             core-pvector-empty?
             core-pvector-length
             core-vector->pvector
             core-list->pvector
             core-make-pvector
             core-pvector->vector
             core-pvector->list
             core-pvector-ref
             core-pvector-set
             core-pvector-cons-left
             core-pvector-cons-right
             core-pvector-pop-left
             core-pvector-pop-right
             core-pvector-append
             core-pvector-split-at
             core-pvector-split-at-right
             core-pvector-take
             core-pvector-drop
             core-pvector-copy))))
     (record-types
      . (core-pvector
         pvector-leaf-chunk
         pvector-digit1
         pvector-digit2
         pvector-digit3
         pvector-digit4
         pvector-node2
         pvector-node3
         pvector-empty-tree
         pvector-single-tree
         pvector-deep-tree))
     (helpers
      . (default-core-pvector-chunk-size
         core-pvector-endpoint-pack-limit
         empty-core-pvector-tree
         empty-core-pvector
         core-pvector-empty
         core-pvector-empty?
         pvector-leaf-vector?
         pvector-chunk?
         pvector-digit?
         pvector-node?
         pvector-tree?
         pvector-chunk-length
         pvector-chunk-ref
         pvector-chunk-slice
         pvector-copy-chunk-range
         pvector-chunk-set
         pvector-chunk-prepend
         pvector-chunk-append
         pvector-subtree-measure
         pvector-make-node2
         pvector-make-node3
         pvector-digit-measure
         pvector-tree-measure
         pvector-make-deep-tree
         pvector-vector-measure
         pvector-small-vector->tree
         pvector-vector->node3-vector
         pvector-nodes-vector->tree
         pvector-vector->chunks
         pvector-tree-build
         pvector-tree-cons-left
         pvector-tree-cons-right
         pvector-digit-first-node
         pvector-digit-last-node
         pvector-digit-replace-first
         pvector-digit-replace-last
         pvector-tree-first-node
         pvector-tree-last-node
         pvector-tree-replace-first
         pvector-tree-replace-last
         pvector-node->list
         pvector-digit->list
         pvector-list->digit
         pvector-node->digit
         pvector-list-measure
         pvector-digit-list->tree
         pvector-digit-list2->tree
         pvector-tree-pop-left
         pvector-tree-pop-right
         pvector-digit-list+tree->digit
         pvector-left-digit+tree->tree
         pvector-right-digit+tree->tree
         pvector-node-list->nodes
         pvector-tree-concat
         pvector-split-digit
         pvector-split-node
         pvector-tree-add-right-list
         pvector-tree-add-left-list
         pvector-split-tree
         core-pvector-ref-node
         core-pvector-ref-digit
         core-pvector-ref-tree
         core-pvector-ref
         core-pvector-set-node
         core-pvector-set-digit
         core-pvector-set-tree
         core-pvector-set
         core-pvector-singleton-chunk
         core-pvector-cons-left
         core-pvector-cons-right
         core-pvector-pop-left
         core-pvector-pop-right
         core-pvector-append
         core-pvector-split-at
         core-pvector-split-at-right
         core-pvector-take
         core-pvector-drop
         core-pvector-copy
         core-vector->pvector
         core-list->pvector
         core-make-pvector
         core-pvector-fill-chunk!
         core-pvector-fill-node!
         core-pvector-fill-digit!
         core-pvector-fill-tree!
         core-pvector->vector
         core-pvector->list))))
 (runtime-adapter
  . ((file . "racket/collects/racket/private/pvector-runtime-adapter.rkt")
     (public-module . "racket/collects/racket/pvector.rkt")
     (fallback-module . "racket/collects/racket/private/pvector-chunked.rkt")
     (required-by-public-module . #t)
     (backend-probes
      . (pvector-runtime-adapter-backend
         pvector-runtime-adapter-core-available?))))
 (runtime-objects
  . ((pvector
      . ((fields . (tree length chunk-size))
         (current-racket-type . chunked-pvector)
         (rumble-type . core-pvector)
         (runtime-note . "Candidate immutable runtime object with direct length field.")))
     (leaf-chunk
      . ((fields . (vector start end))
         (current-racket-type . leaf-chunk)
         (rumble-type . pvector-leaf-chunk)
         (runtime-note . "Slice view over immutable vector leaf; supports cheap split/pop/copy views.")))
     (leaf-vector
      . ((fields . (immutable-vector))
         (rumble-predicate . pvector-leaf-vector?)
         (runtime-note . "Compact full leaf, normally chunk-size elements except endpoint packing.")))
     (digit1
      . ((fields . (a))
         (source . racket/private/pvector-core)))
     (digit2
      . ((fields . (a b))
         (source . racket/private/pvector-core)))
     (digit3
      . ((fields . (a b c))
         (source . racket/private/pvector-core)))
     (digit4
      . ((fields . (a b c d))
         (source . racket/private/pvector-core)))
     (node2
      . ((fields . (measure a b))
         (source . racket/private/pvector-core)))
     (node3
      . ((fields . (measure a b c))
         (source . racket/private/pvector-core)))
     (empty-tree
      . ((fields . ())
         (source . racket/private/pvector-core)))
     (single-tree
      . ((fields . (a))
         (source . racket/private/pvector-core)))
     (deep-tree
      . ((fields . (measure left inner right))
         (source . racket/private/pvector-core)))))
 (runtime-helper-groups
  . ((chunk
      . (chunk-length chunk-ref chunk-slice chunk-set chunk-for-each
         chunk-prepend chunk-append))
     (tree
      . (tree-measure node-measure digit-measure tree-cons-left
         tree-cons-right tree-pop-left tree-pop-right tree-concat
         tree-split-at tree-replace-first tree-replace-last))
     (pvector
      . (list->pvector vector->pvector sequence->pvector pvector->vector
         pvector-ref pvector-set pvector-cons-left pvector-cons-right
         pvector-pop-left pvector-pop-right pvector-append pvector-split-at
         pvector-take pvector-drop pvector-copy))
     (iteration
      . (pvector-for-each in-pvector in-pvector-reverse))
     (debug-only
      . (pvector-shape-stats))))
 (primitive-candidates
  . (((name . pvector?)
      (arity . 1)
      (kind . predicate))
     ((name . pvector-empty)
      (arity . 0)
      (kind . constructor))
     ((name . pvector-empty?)
      (arity . 1)
      (kind . predicate))
     ((name . pvector-length)
      (arity . 1)
      (kind . accessor))
     ((name . list->pvector)
      (arity . 1)
      (kind . conversion))
     ((name . vector->pvector)
      (arity . 1)
      (kind . conversion))
     ((name . sequence->pvector)
      (arity . 1)
      (kind . conversion))
     ((name . pvector->list)
      (arity . 1)
      (kind . conversion))
     ((name . pvector->vector)
      (arity . 1)
      (kind . conversion))
     ((name . pvector-ref)
      (arity . 2)
      (kind . access))
     ((name . pvector-set)
      (arity . 3)
      (kind . update))
     ((name . pvector-cons-left)
      (arity . 2)
      (kind . endpoint-update))
     ((name . pvector-cons-right)
      (arity . 2)
      (kind . endpoint-update))
     ((name . pvector-pop-left)
      (arity . 1)
      (kind . endpoint-view))
     ((name . pvector-pop-right)
      (arity . 1)
      (kind . endpoint-view))
     ((name . pvector-append)
      (arity . any)
      (kind . concatenate))
     ((name . pvector-split-at)
      (arity . 2)
      (kind . split))
     ((name . pvector-split-at-right)
      (arity . 2)
      (kind . split))
     ((name . pvector-take)
      (arity . 2)
      (kind . slice))
     ((name . pvector-drop)
      (arity . 2)
      (kind . slice))
     ((name . pvector-copy)
      (arity . (1 3))
      (kind . slice))))
 (migration-order
  . ((1 . "Keep racket/pvector as the public API and contract boundary.")
     (2 . "Move the chunk, digit, node, and tree representations to racket/src/cs/rumble/pvector.ss.")
     (3 . "Include the rumble implementation from racket/src/cs/rumble.sls.")
     (4 . "Add primitive bindings only after the Racket backend and gate remain green.")
     (5 . "Add known primitive information after primitive names and arities stabilize.")
     (6 . "Retain pvector-shape-stats as a private debug/gate helper, not as public API.")))
 (shape-gates
  . ((compact
      . ((source . build-compact)
         (min-n . 10000)
         (max-objects-per-elem . 3/100)
         (max-retained-per-visible . 1)))
     (cons-right
      . ((source . build-cons-right)
         (min-n . 10000)
         (max-objects-per-elem . 2/5)
         (max-retained-per-visible . 1)))
     (cons-left
      . ((source . build-cons-left)
         (min-n . 10000)
         (max-objects-per-elem . 2/5)
         (max-retained-per-visible . 1)))
     (pop-left-half
      . ((source . pop-left-half)
         (min-n . 10000)
         (max-objects-per-elem . 3/100)
         (max-retained-per-visible . 103/100)))
     (pop-right-half
      . ((source . pop-right-half)
         (min-n . 10000)
         (max-objects-per-elem . 3/100)
         (max-retained-per-visible . 103/100)))
     (split-left
      . ((source . split-left)
         (min-n . 10000)
         (max-objects-per-elem . 3/100)
         (max-retained-per-visible . 103/100)))
     (split-right
      . ((source . split-right)
         (min-n . 10000)
         (max-objects-per-elem . 3/100)
         (max-retained-per-visible . 103/100)))
     (subvector-middle
      . ((source . subvector-middle)
         (min-n . 10000)
         (max-objects-per-elem . 3/100)
         (max-retained-per-visible . 103/100)))))
 (test-gates
  . ("./racket/bin/racket -y racket/collects/racket/private/pvector.rkt"
     "./racket/bin/racket -y racket/collects/racket/private/pvector-chunked.rkt"
     "./racket/bin/racket -y racket/collects/racket/pvector.rkt"
     "./racket/bin/racket -y pkgs/racket-test/tests/racket/pvector.rkt"
     "./racket/bin/racket -y pkgs/racket-test/tests/racket/pvector-chunked.rkt"
     "./racket/bin/racket -y pkgs/racket-test/tests/racket/pvector-runtime-adapter.rkt"
     "./racket/bin/racket -y -t pkgs/racket-doc/scribblings/reference/pvectors.scrbl"
     "./racket/bin/racket -y -t pkgs/racket-doc/scribblings/reference/data.scrbl"
     "./racket/bin/racket -y pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/gate.rkt"))
 (compile-gates
  . ("./racket/bin/racket -y pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/gate.rkt --compile-rumble"))
 (benchmark-gates
  . ((ref-sequential
      . ((baseline . cutie-pvector)
         (candidate . pvector)
         (max-candidate/baseline . 1/3)
         (observed-ms . ((cutie-pvector . 221) (pvector . 45)))))
     (set-sequential
      . ((baseline . cutie-pvector)
         (candidate . pvector)
         (max-candidate/baseline . 1/2)
         (observed-ms . ((cutie-pvector . 338) (pvector . 93)))))
     (append-halves
      . ((baseline . cutie-pvector)
         (candidate . pvector)
         (max-candidate/baseline . 1/3)
         (observed-ms . ((cutie-pvector . 68) (pvector . 14)))))
     (split-middle
      . ((baseline . cutie-pvector)
         (candidate . pvector)
         (max-candidate/baseline . 1/3)
         (observed-ms . ((cutie-pvector . 180) (pvector . 43)))))
     (pop-left-chain
      . ((baseline . cutie-pvector)
         (candidate . pvector)
         (max-candidate/baseline . 3/5)
         (observed-ms . ((cutie-pvector . 50) (pvector . 22)))))
     (pop-right-chain
      . ((baseline . cutie-pvector)
         (candidate . pvector)
         (max-candidate/baseline . 3/5)
         (observed-ms . ((cutie-pvector . 60) (pvector . 25)))))
     (cons-left-chain
      . ((baseline . cutie-pvector)
         (candidate . pvector)
         (max-candidate/baseline . 6/5)
         (observed-ms . ((cutie-pvector . 27) (pvector . 27)))))
     (cons-right-chain
      . ((baseline . cutie-pvector)
         (candidate . pvector)
         (max-candidate/baseline . 6/5)
         (observed-ms . ((cutie-pvector . 26) (pvector . 27))))))))
