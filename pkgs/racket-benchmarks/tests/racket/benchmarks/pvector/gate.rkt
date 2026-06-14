#lang racket/base

(require racket/cmdline
         racket/file
         racket/list
         racket/match
         racket/path
         racket/port
         racket/string
         racket/system
         (prefix-in runtime: racket/private/pvector-runtime-adapter))

(define N 10000)
(define quiet? #f)
(define compile-rumble? #f)
(define performance? #f)
(define score-smoke? #f)
(define performance-count 200000)
(define performance-m 100000)

(define (parse-count who s)
  (define n (string->number s))
  (unless (exact-positive-integer? n)
    (raise-user-error who "expected a positive exact integer, got ~e" s))
  n)

(command-line
 #:program "pvector-gate"
 #:once-each
 [("--n") n "Shape gate sequence length"
          (set! N (parse-count '--n n))]
 [("--quiet") "Only print failures"
              (set! quiet? #t)]
 [("--compile-rumble") "Compile racket/src/cs/rumble.sls with the local Chez build"
                       (set! compile-rumble? #t)]
 [("--performance") "Run pvector benchmark performance and memory gates"
                    (set! performance? #t)]
 [("--performance-smoke") "Run performance gates with smaller benchmark counts"
                          (set! performance? #t)
                          (set! performance-count 20000)
                          (set! performance-m 10000)]
 [("--score-smoke") "Run the list-score academic-clean output smoke"
                    (set! score-smoke? #t)]
 [("--perf-count") n "list-workload live container count for --performance"
                    (set! performance-count (parse-count '--perf-count n))]
 [("--perf-m") n "list-spectrum repeat count for --performance"
                (set! performance-m (parse-count '--perf-m n))])

(define (alist-ref key alst [default #f])
  (cond
    [(assq key alst) => cdr]
    [else default]))

(define boundary-path
  (collection-file-path "pvector-runtime-boundary.rktd"
                        "racket/private"))

(define repo-root
  (simplify-path (build-path (path-only boundary-path)
                             'up 'up 'up 'up)))

(define (repo-path relative-path)
  (apply build-path repo-root (explode-path relative-path)))

(define (read-one path)
  (call-with-input-file path read))

(define (read-all path)
  (call-with-input-file
   path
   (lambda (in)
     (let loop ([forms null])
       (define v (read in))
       (if (eof-object? v)
           (reverse forms)
           (loop (cons v forms)))))))

(define boundary (read-one boundary-path))
(define boundary-format-version (alist-ref 'format-version boundary 1))
(define shape-gates (alist-ref 'shape-gates boundary))
(define rumble-candidate (alist-ref 'rumble-candidate boundary))
(define runtime-adapter (alist-ref 'runtime-adapter boundary))
(define runtime-objects (alist-ref 'runtime-objects boundary))
(define runtime-helper-groups (alist-ref 'runtime-helper-groups boundary))
(define primitive-candidates (alist-ref 'primitive-candidates boundary))

(define (path-string p)
  (path->string (simplify-path p)))

(define (href h k)
  (hash-ref h k 0))

(define (struct-objects h)
  (+ (href h 'ft-empty)
     (href h 'ft-single)
     (href h 'ft-deep)
     (href h 'digit1)
     (href h 'digit2)
     (href h 'digit3)
     (href h 'digit4)
     (href h 'node2)
     (href h 'node3)
     (href h 'slice-leaves)))

(define (total-objects h)
  (+ (struct-objects h)
     (href h 'vector-leaves)
     (href h 'chunk-index-vectors)))

(define (ratio numerator denominator)
  (/ numerator (max 1 denominator)))

(define (format-ratio r)
  (real->decimal-string r 4))

(define (objects-per-elem h)
  (ratio (total-objects h) (href h 'length)))

(define (retained-per-visible h)
  (ratio (href h 'retained-elems) (href h 'visible-elems)))

(define (build-compact n)
  (runtime:list->pvector (build-list n values)))

(define (build-cons-right n)
  (for/fold ([pv (runtime:pvector-empty)]) ([i (in-range n)])
    (runtime:pvector-cons-right pv i)))

(define (build-cons-left n)
  (for/fold ([pv (runtime:pvector-empty)]) ([i (in-range n)])
    (runtime:pvector-cons-left pv i)))

(define (pop-left-half pv n)
  (for/fold ([pv pv]) ([i (in-range (quotient n 2))])
    (define-values (_ rest) (runtime:pvector-pop-left pv))
    rest))

(define (pop-right-half pv n)
  (for/fold ([pv pv]) ([i (in-range (quotient n 2))])
    (define-values (_ rest) (runtime:pvector-pop-right pv))
    rest))

(define (split-left pv n)
  (define-values (left right) (runtime:pvector-split-at pv (quotient n 2)))
  left)

(define (split-right pv n)
  (define-values (left right) (runtime:pvector-split-at pv (quotient n 2)))
  right)

(define (subvector-middle pv n)
  (runtime:pvector-copy pv (quotient n 4) (- n (quotient n 4))))

(define (scenario-values n)
  (define compact (build-compact n))
  (list
   (cons 'compact compact)
   (cons 'cons-right (build-cons-right n))
   (cons 'cons-left (build-cons-left n))
   (cons 'pop-left-half (pop-left-half compact n))
   (cons 'pop-right-half (pop-right-half compact n))
   (cons 'split-left (split-left compact n))
   (cons 'split-right (split-right compact n))
   (cons 'subvector-middle (subvector-middle compact n))))

(define failures null)

(define (fail! fmt . args)
  (set! failures (cons (apply format fmt args) failures)))

(define (contains-include? v include-path)
  (cond
    [(pair? v)
     (match v
       [`(include ,s)
        (equal? s include-path)]
       [_
        (or (contains-include? (car v) include-path)
            (contains-include? (cdr v) include-path))])]
    [else #f]))

(define (form-define-name v)
  (match v
    [`(define (,name . ,_) . ,_) name]
    [`(define ,name . ,_) #:when (symbol? name) name]
    [_ #f]))

(define (form-record-type-name v)
  (match v
    [`(define-record-type ,name . ,_) name]
    [_ #f]))

(define (regexp-symbols rx s)
  (for/list ([m (in-list (regexp-match* rx s #:match-select cdr))])
    (string->symbol (car m))))

(define (source-record-type-names s)
  (append
   (regexp-symbols #px"\\(define-record-type\\s+([^\\s()\\[\\]]+)" s)
   (regexp-symbols #px"\\(define-record-type\\s+\\(([^\\s()\\[\\]]+)" s)))

(define (source-define-names s)
  (append
   (regexp-symbols #px"\\(define\\s+\\(([^\\s()\\[\\]]+)" s)
   (regexp-symbols #px"\\(define\\s+([^\\s()\\[\\]]+)" s)))

(define (normalize-chez-reader-prefixes s)
  (regexp-replace* #px"#\\d+%" s "#%"))

(define (check-readable-after-normalization! path source)
  (define normalized (normalize-chez-reader-prefixes source))
  (define in (open-input-string normalized))
  (let loop ()
    (define v (read in))
    (unless (eof-object? v)
      (loop))))

(define (export-spec->names spec)
  (match spec
    [(? symbol? name) (list name)]
    [`(rename [,locals ,externals] ...)
     externals]
    [_ null]))

(define (rumble-exported-names forms)
  (match forms
    [`((library ,_ (export ,exports ...) . ,_) . ,_)
     (apply append (map export-spec->names exports))]
    [_ null]))

(define (source-primitive-names s)
  (regexp-symbols #px"\\[([^\\s\\[\\]]+)\\s" s))

(define (kernel-procedure-provided? name)
  (with-handlers ([exn:fail? (lambda (_) #f)])
    (procedure? (dynamic-require ''#%kernel name))))

(define (source-provide-names s)
  (regexp-symbols #px"\\b([^\\s()\\[\\]]+)\\b" s))

(define (check-runtime-adapter!)
  (unless runtime-adapter
    (fail! "runtime boundary manifest is missing runtime-adapter"))
  (when runtime-adapter
    (define adapter-rel (alist-ref 'file runtime-adapter))
    (define public-rel (alist-ref 'public-module runtime-adapter))
    (define fallback-rel (alist-ref 'fallback-module runtime-adapter))
    (define backend-probes (alist-ref 'backend-probes runtime-adapter))
    (for ([rel (in-list (list adapter-rel public-rel fallback-rel))]
          [label (in-list '(adapter public fallback))])
      (unless rel
        (fail! "runtime-adapter is missing ~a module path" label))
      (when rel
        (unless (file-exists? (repo-path rel))
          (fail! "runtime-adapter ~a file does not exist: ~a" label rel))))
    (when (and adapter-rel (file-exists? (repo-path adapter-rel)))
      (define adapter-source (file->string (repo-path adapter-rel)))
      (for ([name (in-list (or backend-probes null))])
        (unless (regexp-match? (regexp (regexp-quote (symbol->string name)))
                               adapter-source)
          (fail! "runtime adapter is missing backend probe ~a" name))))
    (when (and adapter-rel public-rel
               (file-exists? (repo-path adapter-rel))
               (file-exists? (repo-path public-rel)))
      (define public-source (file->string (repo-path public-rel)))
      (define adapter-basename (path->string (file-name-from-path (repo-path adapter-rel))))
      (unless (regexp-match? (regexp (regexp-quote adapter-basename)) public-source)
        (fail! "~a does not require runtime adapter ~a" public-rel adapter-basename)))))

(define (check-rumble-candidate!)
  (unless rumble-candidate
    (fail! "runtime boundary manifest is missing rumble-candidate"))
  (when rumble-candidate
    (define candidate-rel (alist-ref 'file rumble-candidate))
    (define include-rel (alist-ref 'included-from rumble-candidate))
    (define build-dependency-rel (alist-ref 'build-dependency-from rumble-candidate))
    (define exported-names (alist-ref 'exported-names rumble-candidate))
    (define kernel-primitives (alist-ref 'kernel-primitives rumble-candidate))
    (define record-types (alist-ref 'record-types rumble-candidate))
    (define helpers (alist-ref 'helpers rumble-candidate))
    (unless candidate-rel
      (fail! "rumble-candidate is missing file"))
    (unless include-rel
      (fail! "rumble-candidate is missing included-from"))
    (unless build-dependency-rel
      (fail! "rumble-candidate is missing build-dependency-from"))
    (unless record-types
      (fail! "rumble-candidate is missing record-types"))
    (unless helpers
      (fail! "rumble-candidate is missing helpers"))
    (when (and candidate-rel include-rel)
      (define candidate-path (repo-path candidate-rel))
      (define include-path (repo-path include-rel))
      (unless (file-exists? candidate-path)
        (fail! "rumble candidate file does not exist: ~a" candidate-rel))
      (unless (file-exists? include-path)
        (fail! "rumble include file does not exist: ~a" include-rel))
      (when build-dependency-rel
        (define build-dependency-path (repo-path build-dependency-rel))
        (unless (file-exists? build-dependency-path)
          (fail! "rumble build dependency file does not exist: ~a" build-dependency-rel))
        (when (file-exists? build-dependency-path)
          (define build-dependency-source (file->string build-dependency-path))
          (define candidate-basename
            (path->string (file-name-from-path candidate-path)))
          (unless (regexp-match? (regexp (regexp-quote candidate-basename))
                                 build-dependency-source)
            (fail! "~a does not track rumble candidate dependency ~s"
                   build-dependency-rel
                   candidate-basename))))
      (when (and (file-exists? candidate-path) (file-exists? include-path))
        (define include-target (find-relative-path (path-only include-path)
                                                   candidate-path))
        (define include-target-string (path->string include-target))
        (define include-forms (read-all include-path))
        (unless (ormap (lambda (form)
                         (contains-include? form include-target-string))
                       include-forms)
          (fail! "~a does not include ~s" include-rel include-target-string))
        (when exported-names
          (define exports (rumble-exported-names include-forms))
          (for ([name (in-list exported-names)])
            (unless (memq name exports)
              (fail! "~a does not export ~a" include-rel name))))
        (when kernel-primitives
          (define kernel-rel (alist-ref 'file kernel-primitives))
          (define kernel-path (repo-path kernel-rel))
          (unless (file-exists? kernel-path)
            (fail! "kernel primitive file does not exist: ~a" kernel-rel))
          (when (file-exists? kernel-path)
            (define kernel-source (file->string kernel-path))
            (define primitive-names (source-primitive-names kernel-source))
            (for ([name (in-list (alist-ref 'names kernel-primitives null))])
              (unless (memq name primitive-names)
                (fail! "~a is missing primitive entry ~a" kernel-rel name))
              (unless (kernel-procedure-provided? name)
                (fail! "current #%kernel does not provide primitive ~a" name)))))
        (define candidate-source (file->string candidate-path))
        (with-handlers ([exn:fail?
                         (lambda (exn)
                           (fail! "rumble candidate is not readable after Chez-prefix normalization: ~a"
                                  (exn-message exn)))])
          (check-readable-after-normalization! candidate-path candidate-source))
        (define found-records (source-record-type-names candidate-source))
        (define found-defines (source-define-names candidate-source))
        (for ([name (in-list (or record-types null))])
          (unless (memq name found-records)
            (fail! "rumble candidate is missing record type ~a" name)))
        (for ([name (in-list (or helpers null))])
          (unless (memq name found-defines)
            (fail! "rumble candidate is missing helper ~a" name)))))))

(define (find-local-scheme)
  (for/or ([rel (in-list
                 '("racket/src/build/cs/c/ChezScheme/tarm64osx/bin/tarm64osx/scheme"
                   "racket/src/build/cs/c/ChezScheme/pb/bin/pb/scheme"))])
    (define path (repo-path rel))
    (and (file-exists? path) path)))

(define (check-rumble-compile!)
  (when compile-rumble?
    (define scheme (find-local-scheme))
    (define compile-file (repo-path "racket/src/cs/compile-file.ss"))
    (define src-dir (repo-path "racket/src/cs"))
    (define source-build-dir (repo-path "racket/src/build/cs/c"))
    (define temp-build-dir (make-temporary-file "pvector-rumble-gate-~a" 'directory))
    (define rumble-src (repo-path "racket/src/cs/rumble.sls"))
    (define expander-src (repo-path "racket/src/cs/expander.sls"))
    (define chezpart (repo-path "racket/src/build/cs/c/chezpart.so"))
    (define rumble-out (build-path temp-build-dir "rumble.so"))
    (define expander-out (build-path temp-build-dir "expander.so"))
    (unless scheme
      (fail! "cannot find a local Chez scheme executable for rumble compile gate"))
    (unless (file-exists? chezpart)
      (fail! "cannot find chezpart dependency for rumble compile gate: ~a"
             (path-string chezpart)))
    (when (and scheme (file-exists? chezpart))
      (unless quiet?
        (printf "compiling rumble candidate with ~a\n" (path-string scheme))
        (flush-output))
      (define rumble-ok?
        (system* (path-string scheme)
                 "--script" (path-string compile-file)
                 "--src" (path-string src-dir)
                 "--dest" (path-string temp-build-dir)
                 (path-string rumble-src)
                 (path-string rumble-out)
                 (path-string chezpart)))
      (unless rumble-ok?
        (fail! "rumble compile gate failed"))
      (when rumble-ok?
        (unless quiet?
          (printf "compiling expander primitive table against pvector rumble candidate\n")
          (flush-output))
        (define expander-ok?
          (apply system*
                 (path-string scheme)
                 "--script" (path-string compile-file)
                 "--src" (path-string src-dir)
                 "--dest" (path-string temp-build-dir)
                 (path-string expander-src)
                 (path-string expander-out)
                 (map path-string
                      (list chezpart
                            rumble-out
                            (build-path source-build-dir "thread.so")
                            (build-path source-build-dir "io.so")
                            (build-path source-build-dir "regexp.so")
                            (build-path source-build-dir "schemify.so")
                            (build-path source-build-dir "linklet.so")))))
        (unless expander-ok?
          (fail! "expander primitive-table compile gate failed"))))
    (when (directory-exists? temp-build-dir)
      (delete-directory/files temp-build-dir))))

(define (check-boundary!)
  (unless (eq? (alist-ref 'name boundary) 'pvector-runtime-boundary)
    (fail! "runtime boundary manifest has unexpected name: ~e"
           (alist-ref 'name boundary)))
  (check-rumble-candidate!)
  (check-runtime-adapter!)
  (unless runtime-objects
    (fail! "runtime boundary manifest is missing runtime-objects"))
  (unless runtime-helper-groups
    (fail! "runtime boundary manifest is missing runtime-helper-groups"))
  (unless primitive-candidates
    (fail! "runtime boundary manifest is missing primitive-candidates"))
  (unless shape-gates
    (fail! "runtime boundary manifest is missing shape-gates"))
  (define (check-members label have need)
    (for ([name (in-list need)])
      (unless (and have (memq name have))
        (fail! "runtime boundary manifest is missing ~a ~a" label name))))
  (check-members
   "object"
   (and runtime-objects (map car runtime-objects))
   '(pvector leaf-vector digit1 digit2 digit3 digit4
     node2 node3 empty-tree single-tree deep-tree))
  (check-members
   "helper group"
   (and runtime-helper-groups (map car runtime-helper-groups))
   '(tree pvector iteration debug-only))
  (check-members
   "primitive candidate"
   (and primitive-candidates
        (for/list ([candidate (in-list primitive-candidates)])
          (alist-ref 'name candidate)))
   '(pvector? pvector-empty pvector-empty? pvector-length
     list->pvector vector->pvector sequence->pvector pvector->list
     pvector->vector pvector-ref pvector-set pvector-cons-left
     pvector-cons-right pvector-pop-left pvector-pop-right pvector-append
     pvector-map pvector-split-at pvector-split-at-right pvector-take pvector-drop
     pvector-take-right pvector-drop-right pvector-copy))
  (for ([name '(compact cons-right cons-left pop-left-half pop-right-half
                split-left split-right subvector-middle)])
    (unless (alist-ref name shape-gates)
      (fail! "runtime boundary manifest is missing shape gate ~a" name))))

(define (check-path-field! owner label rel)
  (unless rel
    (fail! "~a is missing ~a path" owner label))
  (when rel
    (unless (file-exists? (repo-path rel))
      (fail! "~a ~a file does not exist: ~a" owner label rel))))

(define (allowed-backend? backend allowed)
  (cond
    [(list? allowed) (and (memq backend allowed) #t)]
    [else (eq? backend allowed)]))

(define obsolete-chunk-constructor-symbols
  '("core-fixed-chunks->pvector"
    "core-chunks->pvector"))

(define obsolete-core-chunk-view-symbols
  '("core-pvector->chunk-vector"
    "core-pvector->chunk-vector/shared"
    "core-pvector-lookup-chunk"))

(define (check-source-no-obsolete-chunk-constructors!)
  (define sources
    (list (cons 'runtime-candidate
                (alist-ref 'runtime-candidate-file boundary))
          (cons 'runtime-adapter
                (and runtime-adapter (alist-ref 'file runtime-adapter)))
          (cons 'rumble-exports
                "racket/src/cs/rumble.sls")
          (cons 'kernel-primitives
                "racket/src/cs/primitive/kernel.ss")))
  (for ([source (in-list sources)])
    (define label (car source))
    (define rel (cdr source))
    (when rel
      (define text (file->string (repo-path rel)))
      (for ([symbol-name (in-list obsolete-chunk-constructor-symbols)])
        (when (regexp-match? (regexp (regexp-quote symbol-name)) text)
          (fail! "~a still mentions obsolete chunk constructor primitive ~a"
                 label
                 symbol-name))))))

(define (check-source-no-core-chunk-view-primitives!)
  (define sources
    (list (cons 'runtime-candidate
                (alist-ref 'runtime-candidate-file boundary))
          (cons 'rumble-exports
                "racket/src/cs/rumble.sls")
          (cons 'kernel-primitives
                "racket/src/cs/primitive/kernel.ss")))
  (for ([source (in-list sources)])
    (define label (car source))
    (define rel (cdr source))
    (when rel
      (define text (file->string (repo-path rel)))
      (for ([symbol-name (in-list obsolete-core-chunk-view-symbols)])
        (when (regexp-match? (regexp (regexp-quote symbol-name)) text)
          (fail! "~a still mentions obsolete core chunk-view primitive ~a"
                 label
                 symbol-name))))))

(define (check-boundary-v2!)
  (unless (eq? (alist-ref 'name boundary) 'pvector-runtime-boundary)
    (fail! "runtime boundary manifest has unexpected name: ~e"
           (alist-ref 'name boundary)))
  (unless (eqv? boundary-format-version 2)
    (fail! "runtime boundary manifest is not format-version 2: ~e"
           boundary-format-version))
  (define current-default (alist-ref 'current-default boundary))
  (define compatibility-views (alist-ref 'compatibility-views boundary))
  (define no-chunk-baseline
    (alist-ref 'no-chunk-baseline (alist-ref 'acceptance boundary null)))
  (check-path-field! 'boundary 'runtime-candidate
                     (alist-ref 'runtime-candidate-file boundary))
  (unless runtime-adapter
    (fail! "runtime boundary manifest is missing runtime-adapter"))
  (when runtime-adapter
    (check-path-field! 'runtime-adapter 'file
                       (alist-ref 'file runtime-adapter))
    (check-path-field! 'runtime-adapter 'fallback-module
                       (alist-ref 'fallback-module runtime-adapter))
    (unless (allowed-backend? 'finger
                              (alist-ref 'expected-default-backend runtime-adapter))
      (fail! "runtime-adapter expected-default-backend does not allow finger: ~e"
             (alist-ref 'expected-default-backend runtime-adapter))))
  (check-source-no-obsolete-chunk-constructors!)
  (check-source-no-core-chunk-view-primitives!)
  (unless (allowed-backend? 'finger
                            (alist-ref 'adapter-backend current-default))
    (fail! "current-default adapter-backend does not allow finger: ~e"
           (alist-ref 'adapter-backend current-default)))
  (unless (eq? (alist-ref 'chunked-runtime-status current-default)
               'removed-from-current-boundary)
    (fail! "current-default does not mark chunked runtime as removed: ~e"
           (alist-ref 'chunked-runtime-status current-default)))
  (define backend (runtime:pvector-runtime-adapter-backend))
  (unless (allowed-backend? backend (alist-ref 'adapter-backend current-default))
    (fail! "runtime adapter backend is not allowed by manifest: ~e" backend))
  (unless compatibility-views
    (fail! "runtime boundary manifest is missing compatibility-views"))
  (unless no-chunk-baseline
    (fail! "runtime boundary manifest is missing no-chunk-baseline acceptance"))
  (unless (eq? (alist-ref 'chunk-constructor-primitives no-chunk-baseline)
               'absent)
    (fail! "no-chunk-baseline does not require absent chunk constructor primitives"))
  (unless (eq? (alist-ref 'chunk-view-primitives no-chunk-baseline)
               'absent)
    (fail! "no-chunk-baseline does not require absent chunk-view primitives"))
  (define stats
    (runtime:pvector-shape-stats
     (runtime:list->pvector (build-list (max 1 N) values))))
  (unless (allowed-backend? (hash-ref stats 'backend #f)
                            (alist-ref 'shape-stats-backend no-chunk-baseline))
    (fail! "shape-stats backend is not allowed by manifest: ~e"
           (hash-ref stats 'backend #f)))
  (unless (eq? (hash-ref stats 'chunked-tree? #t) #f)
    (fail! "shape-stats does not report chunked-tree? #f"))
  (unless (zero? (hash-ref stats 'chunk-index-vectors 1))
    (fail! "shape-stats reports chunk-index-vectors: ~e"
           (hash-ref stats 'chunk-index-vectors #f)))
  (unless (eq? (hash-ref stats 'ref-cache? #t) #f)
    (fail! "shape-stats does not report ref-cache? #f"))
  (when (eq? backend 'core)
    (define large-stats
      (runtime:pvector-shape-stats
       (runtime:list->pvector (build-list (max 513 N) values))))
    (unless (eq? (hash-ref large-stats 'representation #f) 'large-finger)
      (fail! "core large value is not represented as large-finger: ~e"
             (hash-ref large-stats 'representation #f)))
    (unless (zero? (hash-ref large-stats 'payload-vectors 1))
      (fail! "core large-finger still reports vector payloads: ~e"
             (hash-ref large-stats 'payload-vectors #f)))
    (unless (= (hash-ref large-stats 'digit-vectors 0) 2)
      (fail! "core large-finger does not report prefix/suffix digits: ~e"
             (hash-ref large-stats 'digit-vectors #f)))
    (unless (positive? (hash-ref large-stats 'finger-nodes 0))
      (fail! "core large-finger does not report measured nodes: ~e"
             (hash-ref large-stats 'finger-nodes #f))))
  (check-rumble-compile!))

(define (check-shape! name pv)
  (define spec (alist-ref name shape-gates))
  (define h (runtime:pvector-shape-stats pv))
  (define obj (objects-per-elem h))
  (define retained (retained-per-visible h))
  (define obj-limit (alist-ref 'max-objects-per-elem spec))
  (define retained-limit (alist-ref 'max-retained-per-visible spec))
  (unless obj-limit
    (fail! "shape gate ~a is missing max-objects-per-elem" name))
  (unless retained-limit
    (fail! "shape gate ~a is missing max-retained-per-visible" name))
  (define ok?
    (and obj-limit
         retained-limit
         (<= obj obj-limit)
         (<= retained retained-limit)))
  (unless quiet?
    (printf "~a\tlen=~a\tobjects/elem=~a <= ~a\tretained/visible=~a <= ~a\t~a\n"
            name
            (href h 'length)
            (format-ratio obj)
            (format-ratio obj-limit)
            (format-ratio retained)
            (format-ratio retained-limit)
            (if ok? "ok" "FAIL")))
  (unless (or (not obj-limit) (<= obj obj-limit))
    (fail! "~a objects/elem is ~a, over limit ~a"
           name (format-ratio obj) (format-ratio obj-limit)))
  (unless (or (not retained-limit) (<= retained retained-limit))
    (fail! "~a retained/visible is ~a, over limit ~a"
           name (format-ratio retained) (format-ratio retained-limit))))

(define (parse-tsv-number s)
  (or (string->number s) 0))

(define (parse-tsv-field key s)
  (case key
    [(size count iterations cpu-ms real-ms real-ns/op gc-ms live-bytes
           generated-result-cost-units result-cost-units/op
           speed-score/list speed-score/vector cost-score/list
           cost-score/vector speed-score cost-score total-score
           sample-count weight)
     (parse-tsv-number s)]
    [(kind op impl baseline cost-model score-profile size-weight-model
           operation-weight-model interface-model speed-metric cost-metric)
     (string->symbol s)]
    [else s]))

(define (parse-benchmark-tsv label output)
  (define lines
    (filter (lambda (s) (not (string=? s "")))
            (string-split output "\n")))
  (cond
    [(null? lines)
     (fail! "~a benchmark produced no output" label)
     null]
    [else
     (define headers
       (map string->symbol (string-split (car lines) "\t" #:trim? #f)))
     (for/list ([line (in-list (cdr lines))]
                #:when (not (regexp-match? #rx"^#" line)))
       (define cells (string-split line "\t" #:trim? #f))
       (define row (make-hasheq))
       (for ([key (in-list headers)]
             [cell (in-list cells)])
         (hash-set! row key (parse-tsv-field key cell)))
       row)]))

(define (run-benchmark-tsv label rel args)
  (define racket-bin (repo-path "racket/bin/racket"))
  (define script (repo-path rel))
  (define command
    (append (list (path-string racket-bin)
                  "-t"
                  (path-string script)
                  "--")
            args))
  (unless quiet?
    (printf "~a benchmark command: ~a\n" label (string-join command " "))
    (flush-output))
  (define ok? #t)
  (define output
    (with-output-to-string
      (lambda ()
        (set! ok? (apply system* command)))))
  (unless ok?
    (fail! "~a benchmark command failed" label))
  (parse-benchmark-tsv label output))

(define (index-benchmark-rows rows)
  (for/hash ([row (in-list rows)])
    (values (list (hash-ref row 'size #f)
                  (hash-ref row 'op #f)
                  (hash-ref row 'impl #f))
            row)))

(define (benchmark-row label index size op impl)
  (define row (hash-ref index (list size op impl) #f))
  (unless row
    (fail! "~a is missing row size=~a op=~a impl=~a"
           label size op impl))
  row)

(define (row-real-ms row)
  (if row (max 1 (hash-ref row 'real-ms 0)) 1))

(define (row-live-bytes row)
  (if row (max 0 (hash-ref row 'live-bytes 0)) 0))

(define (check-real-ratio! label index size op impl baseline-impl max-ratio)
  (define target (benchmark-row label index size op impl))
  (define baseline (benchmark-row label index size op baseline-impl))
  (when (and target baseline)
    (define target-ms (row-real-ms target))
    (define baseline-ms (row-real-ms baseline))
    (define actual (ratio target-ms baseline-ms))
    (unless (<= actual max-ratio)
      (fail! "~a size=~a op=~a: ~a real-ms ~a is ~ax ~a real-ms ~a, over limit ~ax"
             label
             size
             op
             impl
             target-ms
             (format-ratio actual)
             baseline-impl
             baseline-ms
             (format-ratio max-ratio)))))

(define (check-live-bytes-ratio! label index size op impl baseline-impl max-ratio)
  (define target (benchmark-row label index size op impl))
  (define baseline (benchmark-row label index size op baseline-impl))
  (when (and target baseline)
    (define target-bytes (row-live-bytes target))
    (define baseline-bytes (max 1 (row-live-bytes baseline)))
    (define actual (ratio target-bytes baseline-bytes))
    (unless (<= actual max-ratio)
      (fail! "~a size=~a op=~a: ~a live-bytes ~a is ~ax ~a live-bytes ~a, over limit ~ax"
             label
             size
             op
             impl
             target-bytes
             (format-ratio actual)
             baseline-impl
             baseline-bytes
             (format-ratio max-ratio)))))

(define (geomean xs)
  (cond
    [(null? xs) #f]
    [else (exp (/ (for/sum ([x (in-list xs)]) (log x))
                  (length xs)))]))

(define performance-impls '(pvector adapter-pvector))

(define (check-list-workload-performance!)
  (define rows
    (run-benchmark-tsv
     "list-workload"
     "pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/list-workload.rkt"
     (list "--count" (number->string performance-count)
           "--sizes" "1,2,4,8,16,64"
           "--ops" "build-live,sum-live,ref-live,cons-left-live,cons-right-live,drop-left-live,append-self-live"
           "--impls" "list,vector,treelist,pvector,adapter-pvector")))
  (define index (index-benchmark-rows rows))
  (for ([impl (in-list performance-impls)])
    (for ([size (in-list '(1 2 4))])
      (check-real-ratio! "list-workload" index size 'build-live impl 'list 2.0)
      (check-real-ratio! "list-workload" index size 'cons-left-live impl 'list 2.0)
      (check-real-ratio! "list-workload" index size 'ref-live impl 'treelist 1.0))
    (check-live-bytes-ratio! "list-workload" index 1 'build-live impl 'list 2.0)
    (for ([size (in-list '(2 4))])
      (check-live-bytes-ratio! "list-workload" index size 'build-live impl 'list 1.5)
      (check-live-bytes-ratio! "list-workload" index size 'build-live impl 'vector 2.0))
    (check-live-bytes-ratio! "list-workload" index 64 'build-live impl 'list 1.0)
    (check-live-bytes-ratio! "list-workload" index 64 'append-self-live impl 'list 1.0)
    (check-real-ratio! "list-workload" index 64 'append-self-live impl 'list 1.0)
    (check-real-ratio! "list-workload" index 64 'append-self-live impl 'vector 1.0)))

(define (check-list-spectrum-performance!)
  (define sizes '(1 2 4 8 16 64 256))
  (define ops '(build sum ref-middle append-self map-add1))
  (define rows
    (run-benchmark-tsv
     "list-spectrum"
     "pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/list-spectrum.rkt"
     (list "--m" (number->string performance-m)
           "--sizes" "1,2,4,8,16,64,256"
           "--ops" "build,sum,ref-middle,append-self,map-add1"
           "--impls" "list,vector,treelist,pvector,adapter-pvector")))
  (define index (index-benchmark-rows rows))
  (for ([impl (in-list performance-impls)])
    (define ratios
      (for*/list ([size (in-list sizes)]
                  [op (in-list ops)]
                  [target (in-value (benchmark-row "list-spectrum" index size op impl))]
                  [baseline (in-value (benchmark-row "list-spectrum" index size op 'list))]
                  #:when (and target baseline))
        (ratio (row-real-ms target) (row-real-ms baseline))))
    (define gm (geomean ratios))
    (when (and gm (> gm 1.0))
      (fail! "list-spectrum: ~a geometric mean real time is ~ax list, over limit 1.0000x"
             impl
             (format-ratio gm)))
    (for* ([size (in-list sizes)]
           [op (in-list ops)])
      (unless (and (memq size '(64 256))
                   (memq op '(build sum append-self map-add1)))
        (check-real-ratio! "list-spectrum" index size op impl 'list 2.0)))
    (for ([size (in-list '(64 256))])
      (check-real-ratio! "list-spectrum" index size 'append-self impl 'list 1.0)
      (check-real-ratio! "list-spectrum" index size 'append-self impl 'vector 1.0)
      (check-real-ratio! "list-spectrum" index size 'build impl 'list 1.0)
      (check-real-ratio! "list-spectrum" index size 'build impl 'treelist 1.0)
      (check-real-ratio! "list-spectrum" index size 'map-add1 impl 'vector 1.0)
      (check-real-ratio! "list-spectrum" index size 'map-add1 impl 'treelist 1.0)
      (check-real-ratio! "list-spectrum" index size 'sum impl 'list 1.0))))

(define list-score-required-columns
  '(kind size power band op impl iterations cpu-ms real-ms real-ns/op gc-ms
         live-bytes cost-model generated-result-cost-units
         result-cost-units/op result baseline speed-score/list
         speed-score/vector cost-score/list cost-score/vector speed-score
         cost-score total-score sample-count weight score-profile
         size-weight-model operation-weight-model interface-model score-method
         speed-metric cost-metric))

(define (count-score-rows rows kind)
  (for/sum ([row (in-list rows)]
            #:when (eq? (hash-ref row 'kind #f) kind))
    1))

(define (find-score-row rows kind op impl)
  (for/first ([row (in-list rows)]
              #:when (and (eq? (hash-ref row 'kind #f) kind)
                          (eq? (hash-ref row 'op #f) op)
                          (eq? (hash-ref row 'impl #f) impl)))
    row))

(define (find-score-detail-row rows size op impl)
  (for/first ([row (in-list rows)]
              #:when (and (eq? (hash-ref row 'kind #f) 'detail)
                          (= (hash-ref row 'size #f) size)
                          (eq? (hash-ref row 'op #f) op)
                          (eq? (hash-ref row 'impl #f) impl)))
    row))

(define (check-score-positive! label row field)
  (define value (hash-ref row field #f))
  (unless (and (number? value) (positive? value))
    (fail! "~a has ~a ~a, expected positive score"
           label
           field
           value)))

(define (check-list-score-row-contract! rows)
  (for ([row (in-list rows)])
    (case (hash-ref row 'kind #f)
      [(detail)
       (define iterations (hash-ref row 'iterations #f))
       (define cost/op (hash-ref row 'result-cost-units/op #f))
       (define generated (hash-ref row 'generated-result-cost-units #f))
       (unless (and (number? iterations)
                    (number? cost/op)
                    (number? generated)
                    (equal? generated (* iterations cost/op)))
         (fail! "list-score detail row cost contract failed for size=~a op=~a impl=~a: generated=~a iterations=~a cost/op=~a"
                (hash-ref row 'size #f)
                (hash-ref row 'op #f)
                (hash-ref row 'impl #f)
                generated
                iterations
                cost/op))]
      [(power-score total-score)
       (define label
         (format "list-score ~a row size=~a impl=~a"
                 (hash-ref row 'kind #f)
                 (hash-ref row 'size #f)
                 (hash-ref row 'impl #f)))
       (check-score-positive! label row 'speed-score)
       (check-score-positive! label row 'cost-score)
       (check-score-positive! label row 'total-score)]
      [else (void)])))

(define (check-list-score-smoke!)
  (define rows
    (run-benchmark-tsv
     "list-score"
     "pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/list-score.rkt"
     (list "--target-ms" "0"
           "--m" "5"
           "--sizes" "0,1,2,4"
           "--ops" "build,sum,append-self,map-add1"
           "--impls" "list,vector,pvector,adapter-pvector")))
  (when (null? rows)
    (fail! "list-score smoke produced no data rows"))
  (define first-row (and (pair? rows) (car rows)))
  (when first-row
    (for ([column (in-list list-score-required-columns)])
      (unless (hash-has-key? first-row column)
        (fail! "list-score smoke is missing column ~a" column))))
  (unless (= (count-score-rows rows 'detail) 64)
    (fail! "list-score smoke detail row count is ~a, expected 64"
           (count-score-rows rows 'detail)))
  (unless (= (count-score-rows rows 'power-score) 16)
    (fail! "list-score smoke power-score row count is ~a, expected 16"
           (count-score-rows rows 'power-score)))
  (unless (= (count-score-rows rows 'total-score) 4)
    (fail! "list-score smoke total-score row count is ~a, expected 4"
           (count-score-rows rows 'total-score)))
  (for ([row (in-list rows)])
    (unless (eq? (hash-ref row 'score-profile #f) 'academic-clean)
      (fail! "list-score row has score-profile ~a"
             (hash-ref row 'score-profile #f)))
    (unless (eq? (hash-ref row 'size-weight-model #f) 'equal-per-power-size)
      (fail! "list-score row has size-weight-model ~a"
             (hash-ref row 'size-weight-model #f)))
    (unless (eq? (hash-ref row 'operation-weight-model #f)
                 'equal-per-operation-within-size)
      (fail! "list-score row has operation-weight-model ~a"
             (hash-ref row 'operation-weight-model #f)))
    (unless (eq? (hash-ref row 'interface-model #f) 'direct-concrete-interface)
      (fail! "list-score row has interface-model ~a"
             (hash-ref row 'interface-model #f)))
    (unless (regexp-match? #rx"cost-ratio=zero-aware-add1-baseline/target"
                           (hash-ref row 'score-method ""))
      (fail! "list-score row has score-method ~a"
             (hash-ref row 'score-method ""))))
  (check-list-score-row-contract! rows)
  (define vector-empty-build
    (find-score-detail-row rows 0 'build 'vector))
  (unless vector-empty-build
    (fail! "list-score smoke missing vector empty build detail row"))
  (when vector-empty-build
    (define vector-empty-cost
      (hash-ref vector-empty-build 'result-cost-units/op #f))
    (define vector-empty-cost-score
      (hash-ref vector-empty-build 'cost-score/list #f))
    (unless (equal? vector-empty-cost 1)
      (fail! "list-score vector empty build result-cost-units/op is ~a"
             vector-empty-cost))
    (unless (and (number? vector-empty-cost-score)
                 (< vector-empty-cost-score 1.0))
      (fail! "list-score vector empty build cost-score/list is ~a, expected below 1.0"
             vector-empty-cost-score)))
  (for ([impl (in-list '(list vector pvector adapter-pvector))])
    (define total-row (find-score-row rows 'total-score 'all impl))
    (unless total-row
      (fail! "list-score smoke missing total-score row for ~a" impl))
    (when total-row
      (unless (positive? (hash-ref total-row 'total-score 0))
        (fail! "list-score total-score for ~a is ~a"
               impl
               (hash-ref total-row 'total-score #f))))))

(define (check-performance!)
  (check-list-workload-performance!)
  (check-list-spectrum-performance!)
  (check-list-score-smoke!)
  (unless quiet?
    (printf "pvector performance gate checked count=~a m=~a\n"
            performance-count
            performance-m)))

(if (eqv? boundary-format-version 2)
    (begin
      (check-boundary-v2!)
      (unless quiet?
        (printf "pvector runtime boundary: ~a\n" (alist-ref 'status boundary))
        (printf "no-chunk baseline backend: ~a\n"
                (runtime:pvector-runtime-adapter-backend))))
    (begin
      (check-boundary!)
      (unless quiet?
        (printf "pvector runtime boundary: ~a\n" (alist-ref 'status boundary))
        (printf "shape gate n=~a\n" N))
      (for ([name+pv (in-list (scenario-values N))])
        (check-shape! (car name+pv) (cdr name+pv)))
      (check-rumble-compile!)))

(when performance?
  (check-performance!))

(when (and score-smoke? (not performance?))
  (check-list-score-smoke!))

(cond
  [(null? failures)
   (unless quiet?
     (printf "pvector gate: ok\n"))]
  [else
   (for ([msg (in-list (reverse failures))])
     (eprintf "pvector gate: ~a\n" msg))
   (exit 1)])
