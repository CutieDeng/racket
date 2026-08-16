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
(define performance-smoke? #f)
(define score-smoke? #f)
(define performance-count 200000)
(define performance-m 100000)
(define benchmark-racket-bin #f)

(define (bc-vm?)
  (eq? (system-type 'vm) 'racket))

(define (strict-performance-thresholds?)
  (and (not performance-smoke?)
       (bc-vm?)))

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
                          (set! performance-smoke? #t)
                          (set! performance-count 20000)
                          (set! performance-m 10000)]
 [("--score-smoke") "Run the list-score academic-clean output smoke"
                    (set! score-smoke? #t)]
 [("--perf-count") n "list-workload live container count for --performance"
                    (set! performance-count (parse-count '--perf-count n))]
 [("--perf-m") n "list-spectrum repeat count for --performance"
                (set! performance-m (parse-count '--perf-m n))]
 [("--racket-bin") path "Racket executable for benchmark subprocesses; defaults to this executable"
                   (set! benchmark-racket-bin (string->path path))])

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

(define (benchmark-racket-path)
  (path->complete-path
   (or benchmark-racket-bin
       (find-system-path 'exec-file))))

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

(define obsolete-small-flat-symbols
  '("small-flat"
    "small_flat"
    "SCHEME_PVECTOR_SMALL"
    "PV_SMALL"
    "flat-pvector"))

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

(define (check-source-no-small-flat-representation!)
  (define sources
    '((bc-runtime . "racket/src/bc/src/pvector.c")
      (bc-header . "racket/src/bc/include/scheme.h")
      (public-module . "racket/collects/racket/pvector.rkt")
      (runtime-adapter . "racket/collects/racket/private/pvector-runtime-adapter.rkt")
      (cs-runtime-candidate . "racket/src/cs/rumble/pvector.ss")))
  (for ([source (in-list sources)])
    (define label (car source))
    (define text (file->string (repo-path (cdr source))))
    (for ([symbol-name (in-list obsolete-small-flat-symbols)])
      (when (regexp-match? (regexp (regexp-quote symbol-name)) text)
        (fail! "~a still mentions obsolete small-flat representation marker ~a"
               label
               symbol-name)))))

(define (check-source-core-pvector-generic-sequence-cursor!)
  (define text (file->string (repo-path "racket/collects/racket/private/for.rkt")))
  (for ([symbol-name (in-list '("core-pvector-cursor-start"
                                "core-pvector-cursor-next"
                                "core-pvector-cursor-min-length"))])
    (unless (regexp-match? (regexp (regexp-quote symbol-name)) text)
      (fail! "racket/private/for.rkt does not mention ~a for core pvector sequence traversal"
             symbol-name))))

(define (check-source-pvector-default-sequence-ref!)
  (define public-source
    (file->string (repo-path "racket/collects/racket/pvector.rkt")))
  (define adapter-source
    (file->string (repo-path "racket/collects/racket/private/pvector-runtime-adapter.rkt")))
  (define sections
    `((public-in
       . ,(source-section-between
           public-source
           "(define-sequence-syntax in-pvector"
           "(define-sequence-syntax in-pvector-reverse"))
      (public-in-reverse
       . ,(source-section-between
           public-source
           "(define-sequence-syntax in-pvector-reverse"
           "(define exported-pvector?"))
      (public-unsafe-in
       . ,(source-section-between
           public-source
           "(define-sequence-syntax unsafe-in-pvector"
           "(define-sequence-syntax unsafe-in-pvector-reverse"))
      (public-unsafe-in-reverse
       . ,(source-section-between
           public-source
           "(define-sequence-syntax unsafe-in-pvector-reverse"
           "(define (pvector-match-tail->list"))
      (adapter-in
       . ,(source-section-between
           adapter-source
           "(define-sequence-syntax in-pvector"
           "(define-sequence-syntax in-pvector-reverse"))
      (adapter-in-reverse
       . ,(source-section-between
           adapter-source
           "(define-sequence-syntax in-pvector-reverse"
           "(define (in-pvector/index/proc"))
      (adapter-in-index
       . ,(source-section-between
           adapter-source
           "(define-sequence-syntax in-pvector/index"
           "(define-syntax in-pvector-indexed"))))
  (for ([entry (in-list sections)])
    (define label (car entry))
    (define section (cdr entry))
    (unless section
      (fail! "missing default sequence section ~a" label))
    (when section
      (define required-ref
        (if (regexp-match? #rx"^adapter" (symbol->string label))
            "pvector-ref/fast"
            "raw:pvector-ref/fast"))
      (unless (regexp-match? (regexp (regexp-quote required-ref)) section)
        (fail! "~a does not use ~a as the default element path"
               label
               required-ref))
      (for ([bad (in-list '("pvector-cursor-start"
                            "pvector-cursor-next"
                            "pvector->vector"))])
        (when (regexp-match? (regexp (regexp-quote bad)) section)
          (fail! "~a uses default sequence fallback ~a"
                 label
                 bad))))))

(define (source-define-function-section source name)
  (define start
    (regexp-match-positions
     (pregexp (format "\\(define\\s+\\(~a(?=\\s|\\))"
                      (regexp-quote (symbol->string name))))
     source))
  (and start
       (let* ([from (caar start)]
              [next (regexp-match-positions #px"\n\\s*\\(define\\s+\\("
                                            source
                                            (+ from 1))]
             [to (if next (caar next) (string-length source))])
         (substring source from to))))

(define (source-define-binding-section source name)
  (define name-str (regexp-quote (symbol->string name)))
  (define start
    (or (regexp-match-positions
         (pregexp (format "\\(define\\s+\\(~a(?=\\s|\\))" name-str))
         source)
        (regexp-match-positions
         (pregexp (format "\\(define\\s+~a(?=\\s|\\))" name-str))
         source)))
  (and start
       (let* ([from (caar start)]
              [next (regexp-match-positions #px"\n\\s*\\(define\\s+"
                                            source
                                            (+ from 1))]
              [to (if next (caar next) (string-length source))])
         (substring source from to))))

(define (source-section-between source start end)
  (define start-pos
    (regexp-match-positions (regexp (regexp-quote start)) source))
  (and start-pos
       (let* ([from (caar start-pos)]
              [end-pos (regexp-match-positions (regexp (regexp-quote end))
                                               source
                                               (+ from 1))])
         (and end-pos
              (substring source from (caar end-pos))))))

(define (source-c-function-section source name next-name)
  (define start-pos
    (regexp-match-positions
     (pregexp (format "(?m:^~a\\s*\\()" (regexp-quote name)))
     source))
  (and start-pos
       (let* ([from (caar start-pos)]
              [end-pos
               (regexp-match-positions
                (pregexp (format "(?m:^~a\\s*\\()" (regexp-quote next-name)))
                source
                (+ from 1))])
         (and end-pos
              (substring source from (caar end-pos))))))

(define (check-source-pvector-stream-direct-traversal!)
  (define text (file->string (repo-path "racket/collects/racket/stream.rkt")))
  (for ([name (in-list '(pvector-stream-andmap
                         pvector-stream-ormap
                         pvector-stream-andmap-values
                         pvector-stream-ormap-values
                         pvector-stream-fold
                         pvector-stream-count
                         pvector-stream-count-values
                         pvector-stream-for-each))])
    (define section (source-define-function-section text name))
    (unless section
      (fail! "racket/stream.rkt is missing ~a" name))
    (when section
      (unless (regexp-match? #px"\\(vector-ref\\s+procs\\s+10\\)" section)
        (fail! "racket/stream.rkt ~a does not use pvector-for-each direct traversal"
               name)))))

(define (check-apply-final-argument-boundary!)
  (unless (with-handlers ([exn:fail? (lambda (_) #t)])
            (apply + (runtime:list->pvector '(1 2 3)))
            #f)
    (fail! "apply accepted pvector as a final list argument")))

(define (check-public-place-message-boundary!)
  (define public-pvector (dynamic-require 'racket/pvector 'pvector))
  (define place-message-allowed?
    (dynamic-require 'racket/place 'place-message-allowed?))
  (define place-channel (dynamic-require 'racket/place 'place-channel))
  (define place-channel-put (dynamic-require 'racket/place 'place-channel-put))
  (define pv (public-pvector 'a "b" 3))
  (when (place-message-allowed? pv)
    (fail! "place-message-allowed? accepted a public pvector"))
  (define-values (in out) (place-channel))
  (void out)
  (unless (with-handlers ([exn:fail? (lambda (_) #t)])
            (place-channel-put in pv)
            #f)
    (fail! "place-channel-put accepted a public pvector")))

(define (check-public-serialization-boundary!)
  (define public-pvector (dynamic-require 'racket/pvector 'pvector))
  (define serialize (dynamic-require 'racket/serialize 'serialize))
  (define pv (public-pvector 'a "b" 3))
  (when (and (bc-vm?)
             (eq? (runtime:pvector-runtime-adapter-backend) 'core))
    (unless (with-handlers ([exn:fail?
                             (lambda (exn)
                               (regexp-match? #rx"serializable"
                                              (exn-message exn)))])
              (serialize pv)
              #f)
      (fail! "serialize accepted a BC-native public pvector"))))

(define (source-contains-in-order? source parts)
  (let loop ([pos 0] [parts parts])
    (cond
      [(null? parts) #t]
      [else
       (define m
         (regexp-match-positions (regexp (regexp-quote (car parts)))
                                 source
                                 pos))
       (and m
            (loop (cdar m) (cdr parts)))])))

(define (check-source-mentions! label source strings)
  (for ([s (in-list strings)])
    (unless (regexp-match? (regexp (regexp-quote s)) source)
      (fail! "~a does not mention ~a" label s))))

(define (check-source-pvector-runtime-type-and-gc!)
  (define stypes-source
    (file->string (repo-path "racket/src/bc/src/stypes.h")))
  (define scheme-source
    (file->string (repo-path "racket/src/bc/include/scheme.h")))
  (define type-source
    (file->string (repo-path "racket/src/bc/src/type.c")))
  (define mzmark-source
    (file->string (repo-path "racket/src/bc/src/mzmarksrc.c")))
  (define mzmark-inc-source
    (file->string (repo-path "racket/src/bc/src/mzmark_type.inc")))
  (unless (source-contains-in-order?
           stypes-source
           '("scheme_pvector_type"
             "scheme_pvector_node_type"))
    (fail! "stypes.h does not keep pvector runtime type tags in order"))
  (check-source-mentions!
   "scheme.h"
   scheme-source
   '("SCHEME_PVECTOR_EMPTY"
     "SCHEME_PVECTOR_SINGLE"
     "SCHEME_PVECTOR_DEEP"
     "SCHEME_PVECTOR_NODE_DIGIT"
     "SCHEME_PVECTOR_NODE_TREE"
     "SCHEME_PVECTOR_NODE_CURSOR"
     "typedef struct Scheme_PVector"
     "typedef struct Scheme_PVector_Digit"
     "typedef struct Scheme_PVector_Node"
     "typedef struct Scheme_PVector_Cursor"
     "Scheme_Object *pv;"
     "Scheme_Object *leaf;"
     "Scheme_Object *stack;"
     "Scheme_Object *stack_indexes;"))
  (for ([spec (in-list '(("set_name(scheme_pvector_type, \"<pvector>\");"
                          "set_name(scheme_pvector_node_type, \"<pvector-node>\");")
                         ("GC_REG_TRAV(scheme_pvector_type, pvector_obj);"
                          "GC_REG_TRAV(scheme_pvector_node_type, pvector_node_obj);")))])
    (unless (source-contains-in-order? type-source spec)
      (fail! "type.c does not register pvector type names and GC traversers in order")))
  (check-source-mentions!
   "mzmarksrc.c"
   mzmark-source
   '("pvector_obj {"
     "pvector_node_obj {"
     "SCHEME_PVECTOR_SINGLE"
     "SCHEME_PVECTOR_DEEP"
     "SCHEME_PVECTOR_NODE_DIGIT"
     "SCHEME_PVECTOR_NODE_TREE"
     "Scheme_PVector_Cursor"
     "gcMARK2(cursor->pv"
     "gcMARK2(cursor->leaf"
     "gcMARK2(cursor->stack"
     "gcMARK2(cursor->stack_indexes"))
  (check-source-mentions!
   "mzmark_type.inc"
   mzmark-inc-source
   '("pvector_obj_MARK"
     "pvector_obj_FIXUP"
     "pvector_node_obj_MARK"
     "pvector_node_obj_FIXUP"
     "gcMARK2(cursor->pv"
     "gcMARK2(cursor->leaf"
     "gcMARK2(cursor->stack"
     "gcMARK2(cursor->stack_indexes"
     "gcFIXUP2(cursor->pv"
     "gcFIXUP2(cursor->leaf"
     "gcFIXUP2(cursor->stack"
     "gcFIXUP2(cursor->stack_indexes")))

(define (check-source-pvector-direct-equal/hash!)
  (define pvector-source
    (file->string (repo-path "racket/src/bc/src/pvector.c")))
  (unless (source-contains-in-order?
           pvector-source
           '("scheme_set_type_equality(scheme_pvector_type,"
             "pvector_equal,"
             "pvector_hash1,"
             "pvector_hash2);"))
    (fail! "pvector.c does not register direct pvector equal/hash procedures"))
  (check-source-mentions!
   "pvector.c direct equal/hash"
   pvector-source
   '("pvector_equal_element_unsafe"
     "pvector_equal_digit_unsafe"
     "pvector_equal_node_unsafe"
     "pvector_hash1_digit_unsafe"
     "pvector_hash1_node_unsafe"
     "pvector_hash2_digit_unsafe"
     "pvector_hash2_node_unsafe"
     "scheme_recur_equal"
     "scheme_recur_equal_hash_key"
     "scheme_recur_equal_hash_key2"))
  (define equal/hash-section
    (source-section-between pvector-source
                            "pvector_equal_element_unsafe"
                            "pvector_print"))
  (unless equal/hash-section
    (fail! "pvector.c direct equal/hash section was not found"))
  (when equal/hash-section
    (for ([bad (in-list '("core_pvector_to_vector"
                          "core_pvector_to_list"
                          "pvector_fill_vector"
                          "pvector_fill_list"))])
      (when (regexp-match? (regexp (regexp-quote bad)) equal/hash-section)
        (fail! "pvector.c equal/hash section uses materialization helper ~a"
               bad)))))

(define (check-source-pvector-printer!)
  (define pvector-source
    (file->string (repo-path "racket/src/bc/src/pvector.c")))
  (check-source-mentions!
   "pvector.c printer"
   pvector-source
   '("scheme_set_type_printer(scheme_pvector_type, pvector_print);"
     "pvector_print"
     "\"#<pvector:%ld>\""
     "SCHEME_PVECTOR_LENGTH")))

(define (check-source-pvector-fresh-vector-paths!)
  (define adapter-source
    (file->string (repo-path "racket/collects/racket/private/pvector-runtime-adapter.rkt")))
  (define pvector-source
    (file->string (repo-path "racket/src/bc/src/pvector.c")))
  (define c-fresh-section
    (source-section-between pvector-source
                            "core_fresh_vector_to_pvector(int argc, Scheme_Object *argv[])\n{"
                            "\nstatic Scheme_Object *\ncore_list_to_pvector"))
  (unless c-fresh-section
    (fail! "pvector.c core_fresh_vector_to_pvector section was not found"))
  (when c-fresh-section
    (unless (source-contains-in-order?
             c-fresh-section
             '("checked_vector_arg(\"core-fresh-vector->pvector\""
               "return pvector_from_vector(vec);"))
      (fail! "core-fresh-vector->pvector does not directly construct from the supplied vector"))
    (for ([bad (in-list '("vector->immutable"
                          "scheme_make_immutable"
                          "scheme_make_vector"
                          "scheme_vector_to_immutable"))])
      (when (regexp-match? (regexp (regexp-quote bad)) c-fresh-section)
        (fail! "core-fresh-vector->pvector contains extra vector/freeze step ~a"
               bad))))
  (define builder-section
    (source-section-between adapter-source
                            "(define-syntax-rule (with-core-pvector-builder"
                            "(define (small-immutable-vector->pvector"))
  (unless builder-section
    (fail! "runtime adapter with-core-pvector-builder section was not found"))
  (when builder-section
    (check-source-mentions!
     "runtime adapter builder"
     builder-section
     '("fresh-vector->core-pvector"
       "(if (unsafe-fx= len capacity)"
       "(vector-copy vec 0 len)"))
    (for ([bad (in-list '("vector->immutable-vector"
                          "small-immutable-vector->pvector"
                          "vector->pvector/backend"))])
      (when (regexp-match? (regexp (regexp-quote bad)) builder-section)
        (fail! "runtime adapter builder routes through non-fresh vector path ~a"
               bad))))
  (for ([name (in-list '(integer-range->pvector
                         arithmetic-range->pvector))])
    (define section (source-define-function-section adapter-source name))
    (unless section
      (fail! "runtime adapter is missing ~a" name))
    (when section
      (check-source-mentions!
       (format "runtime adapter ~a" name)
       section
       '("make-vector"
         "fresh-vector->core-pvector"))
      (for ([bad (in-list '("vector->immutable-vector"
                            "small-immutable-vector->pvector"
                            "vector->pvector/backend"))])
        (when (regexp-match? (regexp (regexp-quote bad)) section)
          (fail! "runtime adapter ~a routes fresh range vector through ~a"
                 name
                 bad))))))

(define (check-source-pvector-core-tree-ops-no-materialization!)
  (define pvector-source
    (file->string (repo-path "racket/src/bc/src/pvector.c")))
  (define bad-helpers
    '("core_pvector_to_vector"
      "core_pvector_to_list"
      "pvector_fill_vector_unsafe"
      "pvector_to_list_unsafe"
      "pvector_from_vector"
      "pvector_from_list"
      "scheme_make_vector"))
  (for ([spec (in-list '(("pvector_cons_left_unsafe" . "pvector_cons_right_unsafe")
                         ("pvector_cons_right_unsafe" . "pvector_from_small_fields")
                         ("pvector_copy_range_unsafe" . "pvector_tree_child_to_pvector_unsafe")
                         ("node_tree_copy_range_unsafe" . "pvector_copy_range_unsafe")
                         ("pvector_split_at_unsafe" . "pvector_split_middle_unsafe")
                         ("pvector_split_middle_unsafe" . "pvector_delete_middle_unsafe")
                         ("pvector_delete_middle_unsafe" . "pvector_insert_middle_unsafe")
                         ("pvector_insert_middle_unsafe" . "pvector_append_unsafe")
                         ("pvector_append_unsafe" . "pvector_insert_between_unsafe")
                         ("pvector_insert_between_unsafe" . "pvector_append_deep_parts_unsafe")
                         ("pvector_append_deep_parts_unsafe" . "pvector_append_after_pop_left_unsafe")
                         ("pvector_append_after_pop_left_unsafe" . "pvector_map_digit_unsafe")))])
    (define name (car spec))
    (define next-name (cdr spec))
    (define section (source-c-function-section pvector-source name next-name))
    (unless section
      (fail! "pvector.c ~a section was not found" name))
    (when section
      (for ([bad (in-list bad-helpers)])
        (when (regexp-match? (regexp (regexp-quote bad)) section)
          (fail! "pvector.c ~a uses materialization helper ~a"
                 name
                 bad))))))

(define (check-source-pvector-range/edit-paths!)
  (define pvector-source
    (file->string (repo-path "racket/src/bc/src/pvector.c")))
  (define bad-helpers
    '("core_pvector_to_vector"
      "core_pvector_to_list"
      "pvector_fill_vector_unsafe"
      "pvector_to_list_unsafe"
      "pvector_from_vector"
      "pvector_from_list"
      "scheme_make_vector"))
  (define (check-no-materialization! name section)
    (for ([bad (in-list bad-helpers)])
      (when (regexp-match? (regexp (regexp-quote bad)) section)
        (fail! "pvector.c ~a uses materialization helper ~a"
               name
               bad))))
  (define (check-section! name next-name required)
    (define section (source-c-function-section pvector-source name next-name))
    (unless section
      (fail! "pvector.c ~a section was not found" name))
    (when section
      (check-source-mentions! (format "pvector.c ~a" name) section required)
      (check-no-materialization! name section))
    section)

  (define node-copy-section
    (check-section!
     "node_tree_copy_range_unsafe"
     "pvector_copy_range_unsafe"
     '("len = end - start"
       "return core_pvector_empty;"
       "return pvector_from_node_tree_unsafe(node_obj);"
       "pvector_leaf_node_range_unsafe"
       "node_tree_take_unsafe"
       "node_tree_drop_unsafe"
       "pvector_append_tree_child_unsafe"
       "node_tree_copy_range_unsafe"
       "pvector_append_pvector_part_unsafe")))
  (when node-copy-section
    (unless (source-contains-in-order?
             node-copy-section
             '("len = end - start"
               "range"
               "result = core_pvector_empty;"
               "pvector_append_tree_child_unsafe"
               "node_tree_copy_range_unsafe"))
      (fail! "node_tree_copy_range_unsafe does not keep direct child/range copy before returning")))

  (define copy-section
    (check-section!
     "pvector_copy_range_unsafe"
     "pvector_tree_child_to_pvector_unsafe"
     '("range_len = end - start"
       "return core_pvector_empty;"
       "return pv_obj;"
       "return pvector_take_unsafe"
       "return pvector_drop_unsafe"
       "pvector_digit_range_unsafe"
       "make_digit_slice_unsafe"
       "node_tree_copy_range_unsafe"
       "pvector_prepend_digit_unsafe"
       "pvector_append_digit_unsafe")))
  (when copy-section
    (unless (source-contains-in-order?
             copy-section
             '("range_len = end - start"
               "range_len == 0"
               "return core_pvector_empty;"
               "(start == 0) && (end == len)"
               "return pv_obj;"
               "start == 0"
               "return pvector_take_unsafe"
               "end == len"
               "return pvector_drop_unsafe"))
      (fail! "pvector_copy_range_unsafe does not keep empty/self/edge range direct cases first"))
    (unless (source-contains-in-order?
             copy-section
             '("start == 0"
               "return pvector_take_unsafe"
               "end == len"
               "return pvector_drop_unsafe"
               "end <= prefix_len"
               "return pvector_digit_range_unsafe"
               "start >= suffix_start"
               "return pvector_digit_range_unsafe"))
      (fail! "pvector_copy_range_unsafe does not keep edge range direct cases before middle copy"))
    (when (regexp-match? #rx"pvector_ref_unsafe" copy-section)
      (fail! "pvector_copy_range_unsafe uses generic indexed ref for short copy")))

  (define split-section
    (check-section!
     "pvector_split_at_unsafe"
     "pvector_split_middle_unsafe"
     '("pos <= 0"
       "pos >= len"
       "pvector_digit_range_unsafe"
       "make_deep_pvector"
       "pvector_from_middle_suffix_digit_unsafe"
       "pvector_from_prefix_middle_digit_unsafe"
       "node_tree_split_at_unsafe"
       "pvector_prepend_digit_unsafe"
       "pvector_append_digit_unsafe")))
  (when split-section
    (unless (source-contains-in-order?
             split-section
             '("pos <= 0"
               "*out_left = core_pvector_empty;"
               "*out_right = pv_obj;"
               "pos >= len"
               "*out_left = pv_obj;"
               "*out_right = core_pvector_empty;"))
      (fail! "pvector_split_at_unsafe does not keep endpoint split as empty/self direct cases"))
    (unless (source-contains-in-order?
             split-section
             '("pos <= prefix_len"
               "pvector_digit_range_unsafe"
               "pvector_from_middle_suffix_digit_unsafe"
               "pos >= suffix_start"
               "pvector_from_prefix_middle_digit_unsafe"
               "node_tree_split_at_unsafe"))
      (fail! "pvector_split_at_unsafe does not keep prefix/suffix direct cases before middle descent")))

  (check-section!
   "pvector_split_middle_unsafe"
   "pvector_delete_middle_unsafe"
   '("node_tree_split_value_unsafe"
     "pvector_prepend_digit_unsafe"
     "pvector_append_digit_unsafe"))
  (check-section!
   "pvector_delete_middle_unsafe"
   "pvector_insert_middle_unsafe"
   '("node_tree_split_value_unsafe"
     "pvector_prepend_digit_unsafe"
     "pvector_append_pvector_part_unsafe"
     "pvector_append_digit_unsafe"))
  (check-section!
   "pvector_insert_middle_unsafe"
   "pvector_append_unsafe"
   '("node_tree_split_at_unsafe"
     "pvector_insert_between_unsafe"
     "pvector_prepend_digit_unsafe"
     "pvector_append_digit_unsafe"))
  (check-section!
   "core_pvector_split_at_prim"
   "core_pvector_split_at_right_prim"
   '("checked_pvector_index_contract"
     "checked_pvector"
     "checked_pvector_position_after_contract"
     "pvector_split_at_unsafe"
     "scheme_values"))
  (check-section!
   "core_pvector_copy_prim"
   "pvector_view_left_checked"
   '("checked_pvector_index_contract"
     "checked_pvector"
     "len = SCHEME_PVECTOR_LENGTH"
     "scheme_out_of_range"
     "return pvector_copy_range_unsafe"))

  (define insert-section
    (check-section!
     "core_pvector_insert_prim"
     "core_pvector_delete_prim"
     '("checked_pvector_index_contract"
       "checked_pvector"
       "checked_pvector_position_after_contract"
       "len = SCHEME_PVECTOR_LENGTH"
       "return pvector_cons_left_unsafe"
       "return pvector_cons_right_unsafe"
       "make_digit_with_insert_unsafe"
       "pvector_insert_middle_unsafe"
       "pvector_split_at_unsafe"
       "pvector_insert_between_unsafe")))
  (when insert-section
    (unless (source-contains-in-order?
             insert-section
             '("index == 0"
               "return pvector_cons_left_unsafe"
               "index == len"
               "return pvector_cons_right_unsafe"
               "index <= prefix_len"
               "make_digit_with_insert_unsafe"
               "index >= suffix_start"
               "make_digit_with_insert_unsafe"
               "pvector_insert_middle_unsafe"
               "pvector_split_at_unsafe"
               "return pvector_insert_between_unsafe"))
      (fail! "core_pvector_insert_prim does not keep edge/digit/middle paths before split fallback")))
  (when insert-section
    (unless (source-contains-in-order?
             insert-section
             '("if ((index <= prefix_len) && (prefix_len < 4))"
               "return make_deep_pvector"
               "suffix_start = len - suffix_len"))
      (fail! "core_pvector_insert_prim computes suffix_start before the prefix insert fast path")))

  (define delete-section
    (check-section!
     "core_pvector_delete_prim"
     "core_pvector_take_prim"
     '("checked_pvector_index_contract"
       "checked_pvector"
       "checked_pvector_index_after_contract"
       "len = SCHEME_PVECTOR_LENGTH"
       "pvector_pop_left_unsafe"
       "pvector_pop_right_unsafe"
       "SCHEME_PVECTOR_DIGIT_ELS"
       "make_digit_without_index_unsafe"
       "pvector_delete_middle_unsafe"
       "pvector_split_at_unsafe"
       "pvector_append_after_pop_left_unsafe")))
  (when delete-section
    (unless (source-contains-in-order?
             delete-section
             '("index == 0"
               "pvector_pop_left_unsafe"
               "index == (len - 1)"
               "pvector_pop_right_unsafe"
               "index < prefix_len"
               "make_digit_without_index_unsafe"
               "index >= suffix_start"
               "make_digit_without_index_unsafe"
               "pvector_delete_middle_unsafe"
               "pvector_split_at_unsafe"
               "pvector_append_after_pop_left_unsafe"))
      (fail! "core_pvector_delete_prim does not keep edge/digit/middle paths before split fallback")))
  (when delete-section
    (unless (source-contains-in-order?
             delete-section
             '("if (index < prefix_len)"
               "return scheme_values(2, vals);"
               "suffix_start = len - suffix_len"))
      (fail! "core_pvector_delete_prim computes suffix_start before the prefix delete fast path"))))

(define (check-source-pvector-digit/bridge-paths!)
  (define pvector-source
    (file->string (repo-path "racket/src/bc/src/pvector.c")))
  (define bad-helpers
    '("core_pvector_to_vector"
      "core_pvector_to_list"
      "pvector_fill_vector_unsafe"
      "pvector_to_list_unsafe"
      "pvector_from_vector"
      "pvector_from_list"
      "scheme_make_vector"
      "scheme_make_pair"))
  (define (check-no-materialization! name section)
    (for ([bad (in-list bad-helpers)])
      (when (regexp-match? (regexp (regexp-quote bad)) section)
        (fail! "pvector.c ~a uses materialization helper ~a"
               name
               bad))))
  (define (check-section! name next-name required)
    (define section (source-c-function-section pvector-source name next-name))
    (unless section
      (fail! "pvector.c ~a section was not found" name))
    (when section
      (check-source-mentions! (format "pvector.c ~a" name) section required)
      (check-no-materialization! name section))
    section)

  (check-section!
   "make_digit_from_fields"
   "make_digit_constant"
   '("scheme_malloc_tagged(sizeof(Scheme_PVector_Digit))"
     "scheme_pvector_node_type"
     "SCHEME_PVECTOR_NODE_DIGIT"
     "digit->count = count;"
     "digit->level = 0;"
     "digit->els[0]"
     "digit->els[1]"
     "digit->els[2]"
     "digit->els[3]"))
  (check-section!
   "make_digit_with_replaced"
   "make_digit_with_prepended"
   '("Scheme_PVector_Digit"
     "scheme_malloc_tagged(sizeof(Scheme_PVector_Digit))"
     "old_digit->els"
     "digit->els"))
  (for ([spec (in-list '(("make_digit_with_prepended" . "make_digit_with_appended")
                         ("make_digit_with_appended" . "make_digit_without_first")
                         ("make_digit_without_first" . "make_digit_without_last")
                         ("make_digit_without_last" . "make_digit_from_leaf_node")))])
    (check-section!
     (car spec)
     (cdr spec)
     '("Scheme_PVector_Digit"
       "old_digit->els"
       "make_digit_from_fields")))
  (for ([spec (in-list '(("make_digit_without_index_unsafe" . "make_digit_with_insert_unsafe")
                         ("make_digit_with_insert_unsafe" . "pvector_leaf_node_range_unsafe")))])
    (check-section!
     (car spec)
     (cdr spec)
     '("SCHEME_PVECTOR_DIGIT_ELS"
       "make_digit_from_fields")))

  (define node2-section
    (check-section!
     "make_node2"
     "make_node3"
     '("scheme_malloc_tagged(sizeof(Scheme_PVector_Node))"
       "scheme_pvector_node_type"
       "SCHEME_PVECTOR_NODE_TREE"
       "node->arity = 2;"
       "node->level = level;"
       "pvector_child_measure(a) + pvector_child_measure(b)"
       "node->a = a;"
       "node->b = b;"
       "node->c = NULL;")))
  (when node2-section
    (unless (source-contains-in-order?
             node2-section
             '("node->arity = 2;"
               "node->level = level;"
               "node->measure = pvector_child_measure(a) + pvector_child_measure(b);"
               "node->a = a;"
               "node->b = b;"
               "node->c = NULL;"))
      (fail! "make_node2 does not initialize arity/level/measure/fields directly")))

  (define node3-section
    (check-section!
     "make_node3"
     "node_cons_left"
     '("scheme_malloc_tagged(sizeof(Scheme_PVector_Node))"
       "scheme_pvector_node_type"
       "SCHEME_PVECTOR_NODE_TREE"
       "node->arity = 3;"
       "node->level = level;"
       "pvector_child_measure(a)"
       "pvector_child_measure(b)"
       "pvector_child_measure(c)"
       "node->a = a;"
       "node->b = b;"
       "node->c = c;")))
  (when node3-section
    (unless (source-contains-in-order?
             node3-section
             '("node->arity = 3;"
               "node->level = level;"
               "node->measure = (pvector_child_measure(a)"
               "+ pvector_child_measure(b)"
               "+ pvector_child_measure(c));"
               "node->a = a;"
               "node->b = b;"
               "node->c = c;"))
      (fail! "make_node3 does not initialize arity/level/measure/fields directly")))

  (define bridge-fields-section
    (check-section!
     "node_tree_from_fields"
     "node_tree_from_digit_pair"
     '("count == 2"
       "return make_node2(0, a, b);"
       "count == 3"
       "return make_node3(0, a, b, c);"
       "count == 4"
       "return make_node2(1, n1, n2);"
       "count == 9"
       "return make_node3(1, n1, n2, n3);")))
  (when bridge-fields-section
    (unless (source-contains-in-order?
             bridge-fields-section
             '("count == 2"
               "make_node2"
               "count == 3"
               "make_node3"
               "count == 4"
               "make_node2"
               "count == 9"
               "make_node3"))
      (fail! "node_tree_from_fields does not keep fixed node2/node3 bridge cases in order")))

  (check-section!
   "node_tree_from_digit_pair"
   "node_tree_from_digit_value_digit"
   '("left_digit->count + right_digit->count"
     "left_digit->els[i]"
     "right_digit->els[i]"
     "return node_tree_from_fields(total"))
  (check-section!
   "node_tree_from_digit_value_digit"
   "node_append_subtree"
   '("left_digit->count + 1 + right_digit->count"
     "left_digit->els[i]"
     "v0 = value"
     "v8 = value"
     "right_digit->els[i]"
     "return node_tree_from_fields(total"))
  (check-section!
   "next_group_size"
   "node_group_count"
   '("remaining <= 3"
     "remaining == 4"
     "(remaining % 3) == 1"
     "return 3;"))

  (define small-section
    (check-section!
     "pvector_from_small_fields"
     "pvector_digit_range_unsafe"
     '("count == 0"
       "return core_pvector_empty;"
       "count == 1"
       "return make_single_pvector"
       "count == 2"
       "return make_deep_pvector"
       "count == 3"
       "return make_deep_pvector"
       "count == 4"
       "return make_deep_pvector")))
  (when small-section
    (unless (source-contains-in-order?
             small-section
             '("count == 0"
               "return core_pvector_empty;"
               "count == 1"
               "return make_single_pvector"
               "count == 2"
               "make_digit_from_fields(1, a"
               "make_digit_from_fields(1, b"
               "count == 3"
               "make_digit_from_fields(1, a"
               "make_digit_from_fields(2, b, c"
               "count == 4"
               "make_digit_from_fields(2, a, b"
               "make_digit_from_fields(2, c, d"))
      (fail! "pvector_from_small_fields does not keep direct empty/single/deep2..4 construction")))

  (check-section!
   "pvector_digit_range_unsafe"
   "make_digit_slice_unsafe"
   '("SCHEME_PVECTOR_DIGIT_ELS"
     "return pvector_from_small_fields"))
  (check-section!
   "make_digit_slice_unsafe"
   "make_digit_without_index_unsafe"
   '("SCHEME_PVECTOR_DIGIT_ELS"
     "return make_digit_from_fields"))
  (check-section!
   "pvector_leaf_node_range_unsafe"
   "pvector_from_node_tree_unsafe"
   '("SCHEME_PVECTOR_NODE_A"
     "SCHEME_PVECTOR_NODE_B"
     "SCHEME_PVECTOR_NODE_C"
     "return pvector_from_small_fields")))

(define (check-source-pvector-cons/append-paths!)
  (define pvector-source
    (file->string (repo-path "racket/src/bc/src/pvector.c")))
  (define bad-helpers
    '("core_pvector_to_vector"
      "core_pvector_to_list"
      "pvector_fill_vector_unsafe"
      "pvector_to_list_unsafe"
      "pvector_from_vector"
      "pvector_from_list"
      "scheme_make_vector"
      "scheme_make_pair"))
  (define (check-no-materialization! name section)
    (for ([bad (in-list bad-helpers)])
      (when (regexp-match? (regexp (regexp-quote bad)) section)
        (fail! "pvector.c ~a uses materialization helper ~a"
               name
               bad))))
  (define (check-section! name next-name required)
    (define section (source-c-function-section pvector-source name next-name))
    (unless section
      (fail! "pvector.c ~a section was not found" name))
    (when section
      (check-source-mentions! (format "pvector.c ~a" name) section required)
      (check-no-materialization! name section))
    section)

  (define cons-left-section
    (check-section!
     "pvector_cons_left_unsafe"
     "pvector_cons_right_unsafe"
     '("SCHEME_PVECTOR_EMPTY"
       "return make_single_pvector(value);"
       "SCHEME_PVECTOR_SINGLE"
       "make_digit_from_fields(1, value"
       "SCHEME_PVECTOR_LENGTH"
       "SCHEME_PVECTOR_DIGIT_COUNT"
       "SCHEME_PVECTOR_DIGIT_ELS"
       "old_prefix_count < 4"
       "make_digit_with_prepended"
       "node_tree_prepend3"
       "return make_deep_pvector")))
  (when cons-left-section
    (unless (source-contains-in-order?
             cons-left-section
             '("SCHEME_PVECTOR_EMPTY"
               "return make_single_pvector(value);"
               "SCHEME_PVECTOR_SINGLE"
               "return make_deep_pvector(2"
               "old_prefix_count < 4"
               "make_digit_with_prepended"
               "node_tree_prepend3"))
      (fail! "pvector_cons_left_unsafe does not keep empty/single/digit/full-digit paths in order")))

  (define cons-right-section
    (check-section!
     "pvector_cons_right_unsafe"
     "pvector_from_small_fields"
     '("SCHEME_PVECTOR_EMPTY"
       "return make_single_pvector(value);"
       "SCHEME_PVECTOR_SINGLE"
       "make_digit_from_fields(1, value"
       "SCHEME_PVECTOR_LENGTH"
       "SCHEME_PVECTOR_DIGIT_COUNT"
       "SCHEME_PVECTOR_DIGIT_ELS"
       "old_suffix_count < 4"
       "make_digit_with_appended"
       "node_tree_append3"
       "return make_deep_pvector")))
  (when cons-right-section
    (unless (source-contains-in-order?
             cons-right-section
             '("SCHEME_PVECTOR_EMPTY"
               "return make_single_pvector(value);"
               "SCHEME_PVECTOR_SINGLE"
               "return make_deep_pvector(2"
               "old_suffix_count < 4"
               "make_digit_with_appended"
               "node_tree_append3"))
      (fail! "pvector_cons_right_unsafe does not keep empty/single/digit/full-digit paths in order")))

  (check-section!
   "node_tree_prepend3"
   "node_tree_append3"
   '("SCHEME_FALSEP(middle)"
     "return make_node3(0, a, b, c);"
     "node_tree_cons_left"
     "return node_tree_cons_left"))
  (check-section!
   "node_tree_append3"
   "node_tree_pop_left_leaf"
   '("SCHEME_FALSEP(middle)"
     "return make_node3(0, a, b, c);"
     "node_tree_cons_right"
     "return node_tree_cons_right"))

  (define append-section
    (check-section!
     "pvector_append_unsafe"
     "pvector_insert_between_unsafe"
     '("left_shape == SCHEME_PVECTOR_EMPTY"
       "return right_obj;"
       "right_shape == SCHEME_PVECTOR_EMPTY"
       "return left_obj;"
       "left_shape == SCHEME_PVECTOR_SINGLE"
       "return pvector_cons_left_unsafe"
       "right_shape == SCHEME_PVECTOR_SINGLE"
       "return pvector_cons_right_unsafe"
       "node_tree_from_digit_pair"
       "node_tree_join"
       "return make_deep_pvector")))
  (when append-section
    (unless (source-contains-in-order?
             append-section
             '("left_shape == SCHEME_PVECTOR_EMPTY"
               "return right_obj;"
               "right_shape == SCHEME_PVECTOR_EMPTY"
               "return left_obj;"
               "left_shape == SCHEME_PVECTOR_SINGLE"
               "return pvector_cons_left_unsafe"
               "right_shape == SCHEME_PVECTOR_SINGLE"
               "return pvector_cons_right_unsafe"
               "middle = node_tree_from_digit_pair"
               "middle = node_tree_join"
               "return make_deep_pvector"))
      (fail! "pvector_append_unsafe does not keep identity/singleton/direct bridge paths in order")))

  (define insert-between-section
    (check-section!
     "pvector_insert_between_unsafe"
     "pvector_append_deep_parts_unsafe"
     '("left_shape == SCHEME_PVECTOR_EMPTY"
       "return pvector_cons_left_unsafe"
       "right_shape == SCHEME_PVECTOR_EMPTY"
       "return pvector_cons_right_unsafe"
       "left_shape != SCHEME_PVECTOR_DEEP"
       "pvector_append_unsafe"
       "node_tree_from_digit_value_digit"
       "node_tree_join"
       "return make_deep_pvector")))
  (when insert-between-section
    (unless (source-contains-in-order?
             insert-between-section
             '("left_shape == SCHEME_PVECTOR_EMPTY"
               "return pvector_cons_left_unsafe"
               "right_shape == SCHEME_PVECTOR_EMPTY"
               "return pvector_cons_right_unsafe"
               "left_shape != SCHEME_PVECTOR_DEEP"
               "return pvector_append_unsafe"
               "middle = node_tree_from_digit_value_digit"
               "middle = node_tree_join"
               "return make_deep_pvector"))
      (fail! "pvector_insert_between_unsafe does not keep identity/small/direct bridge paths in order"))))

(define (check-source-pvector-small-construction-paths!)
  (define pvector-source
    (file->string (repo-path "racket/src/bc/src/pvector.c")))
  (define adapter-source
    (file->string (repo-path "racket/collects/racket/private/pvector-runtime-adapter.rkt")))
  (define public-source
    (file->string (repo-path "racket/collects/racket/pvector.rkt")))
  (for ([spec (in-list '(("pvector_from_args" . "pvector_from_vector")
                         ("pvector_from_vector" . "pvector_from_list")
                         ("pvector_from_list" . "checked_pvector")))])
    (define name (car spec))
    (define next-name (cdr spec))
    (define section (source-c-function-section pvector-source name next-name))
    (unless section
      (fail! "pvector.c ~a section was not found" name))
    (when section
      (for ([required (in-list '("<= 4"
                                 "return pvector_from_small_fields"
                                 "deep_edge_lengths"
                                 "return make_deep_pvector"))])
        (unless (regexp-match? (regexp (regexp-quote required)) section)
          (fail! "pvector.c ~a does not mention ~a for direct small construction"
                 name
                 required)))
      (unless (source-contains-in-order?
               section
               '("<= 4"
                 "return pvector_from_small_fields"
                 "deep_edge_lengths"
                 "return make_deep_pvector"))
        (fail! "pvector.c ~a does not keep length <= 4 ahead of the general deep constructor"
               name))
      (for ([bad (in-list '("scheme_make_vector"
                            "pvector_fill_vector"
                            "pvector_to_list_unsafe"
                            "core_pvector_to_vector"
                            "core_pvector_to_list"))])
        (when (regexp-match? (regexp (regexp-quote bad)) section)
          (fail! "pvector.c ~a uses materialization helper ~a"
                 name
                 bad)))))
  (define adapter-small-section
    (source-define-function-section adapter-source 'small-immutable-vector->pvector))
  (unless adapter-small-section
    (fail! "runtime adapter is missing small-immutable-vector->pvector"))
  (when adapter-small-section
    (check-source-mentions!
     "runtime adapter small-immutable-vector->pvector"
     adapter-small-section
     '("core-make-single-pvector"
       "core-make-deep2-pvector"
       "core-make-deep3-pvector"
       "core-make-deep4-pvector"
       "core-immutable-vector->pvector"))
    (unless (source-contains-in-order?
             adapter-small-section
             '("[(= len 1)"
               "core-make-single-pvector"
               "[(= len 2)"
               "core-make-deep2-pvector"
               "[(= len 3)"
               "core-make-deep3-pvector"
               "[(= len 4)"
               "core-make-deep4-pvector"
               "[else"
               "core-immutable-vector->pvector"))
      (fail! "runtime adapter small-immutable-vector->pvector does not keep length 1..4 ahead of vector fallback")))
  (for ([name (in-list '(single-value->pvector
                         two-values->pvector
                         three-values->pvector
                         four-values->pvector))])
    (define section (source-define-function-section adapter-source name))
    (unless section
      (fail! "runtime adapter is missing ~a" name))
    (when section
      (unless (regexp-match? #rx"core-make-(single|deep[234])-pvector" section)
        (fail! "runtime adapter ~a does not use a direct core constructor"
               name))
      (for ([bad (in-list '("vector-immutable"
                            "vector->pvector"
                            "list->pvector"))])
        (when (regexp-match? (regexp (regexp-quote bad)) section)
          (fail! "runtime adapter ~a routes through ~a"
                 name
                 bad)))))
  (define public-small-values-section
    (source-define-function-section public-source 'direct-small-values->pvector))
  (unless public-small-values-section
    (fail! "racket/pvector.rkt is missing direct-small-values->pvector"))
  (when public-small-values-section
    (unless (source-contains-in-order?
             public-small-values-section
             '("[(0) #'empty-pvector]"
               "[(1)"
               "single-value->pvector"
               "[(2)"
               "two-values->pvector"
               "[(3)"
               "three-values->pvector"
               "[(4)"
               "four-values->pvector"))
      (fail! "public direct-small-values->pvector does not expand length 0..4 to direct constructors"))
    (for ([bad (in-list '("vector-immutable"
                          "raw:vector->pvector"
                          "raw:list->pvector"))])
      (when (regexp-match? (regexp (regexp-quote bad)) public-small-values-section)
        (fail! "public direct-small-values->pvector uses materialization helper ~a"
               bad))))
  (define public-literal-range-section
    (source-define-function-section public-source 'small-literal-arithmetic-range->pvector))
  (unless public-literal-range-section
    (fail! "racket/pvector.rkt is missing small-literal-arithmetic-range->pvector"))
  (when public-literal-range-section
    (unless (source-contains-in-order?
             public-literal-range-section
             '("zero? len"
               "#'empty-pvector"
               "<= len 64"
               "direct-small-values->pvector"
               "small-immutable-vector->pvector"
               "[else #f]"))
      (fail! "public literal range construction does not keep length 0..4 direct constructor path")))
  (define public-make-section
    (source-define-function-section public-source 'make-pvector/known-length))
  (unless public-make-section
    (fail! "racket/pvector.rkt is missing make-pvector/known-length"))
  (when public-make-section
    (unless (source-contains-in-order?
             public-make-section
             '("case n"
               "[(0) empty-pvector]"
               "[(1) (single-value->pvector v)]"
               "[(2) (two-values->pvector v v)]"
               "small-clause ..."
               "wrap/len (raw:make-pvector n v) n"))
      (fail! "public make-pvector/known-length does not route length 5+ directly to raw:make-pvector"))
    (for ([bad (in-list '("make-vector"
                          "vector->immutable-vector"
                          "raw:vector->pvector"))])
      (when (regexp-match? (regexp (regexp-quote bad)) public-make-section)
        (fail! "public make-pvector/known-length routes through ~a"
               bad))))
  (define adapter-make-section
    (source-define-function-section adapter-source 'make-pvector))
  (unless adapter-make-section
    (fail! "runtime adapter is missing make-pvector"))
  (when adapter-make-section
    (unless (source-contains-in-order?
             adapter-make-section
             '("small-make-pvector-dispatch"
               "core-available?"
               "core-make-pvector"
               "fallback:make-pvector"))
      (fail! "runtime adapter make-pvector does not keep direct core make path for length 5+"))
    (for ([bad (in-list '("make-vector"
                          "fresh-vector->pvector"
                          "vector->pvector"))])
      (when (regexp-match? (regexp (regexp-quote bad)) adapter-make-section)
        (fail! "runtime adapter make-pvector routes through ~a"
               bad)))))

(define (check-source-pvector-linear-traversal-paths!)
  (define pvector-source
    (file->string (repo-path "racket/src/bc/src/pvector.c")))
  (define adapter-source
    (file->string (repo-path "racket/collects/racket/private/pvector-runtime-adapter.rkt")))
  (define public-source
    (file->string (repo-path "racket/collects/racket/pvector.rkt")))
  (for ([spec (in-list '(("pvector_fill_vector_digit_unsafe"
                          . "pvector_fill_vector_node_unsafe")
                         ("pvector_fill_vector_node_unsafe"
                          . "pvector_fill_vector_unsafe")
                         ("pvector_fill_vector_unsafe"
                          . "pvector_to_vector_unsafe")
                         ("pvector_to_vector_unsafe"
                          . "pvector_digit_to_list_reverse_unsafe")))])
    (define name (car spec))
    (define next-name (cdr spec))
    (define section (source-c-function-section pvector-source name next-name))
    (unless section
      (fail! "pvector.c ~a section was not found" name))
    (when section
      (check-source-mentions!
       (format "pvector.c ~a" name)
       section
       '("SCHEME_VEC_ELS"))
      (for ([bad (in-list '("pvector_ref_unsafe"
                            "pvector_to_list_unsafe"
                            "scheme_make_pair"))])
        (when (regexp-match? (regexp (regexp-quote bad)) section)
          (fail! "pvector.c ~a uses non-direct vector fill helper ~a"
                 name
                 bad)))))
  (define c-short-vector-section
    (source-c-function-section pvector-source
                               "pvector_to_vector_unsafe"
                               "pvector_digit_to_list_reverse_unsafe"))
  (unless c-short-vector-section
    (fail! "pvector.c pvector_to_vector_unsafe section was not found"))
  (when c-short-vector-section
    (unless (source-contains-in-order?
             c-short-vector-section
             '("scheme_make_vector"
               "len == 0"
               "len == 1"
               "SCHEME_VEC_ELS(vec)[0] = SCHEME_PVECTOR_A"
               "len <= 4"
               "SCHEME_PVECTOR_DIGIT_ELS"
               "pvector_fill_vector_unsafe"))
      (fail! "pvector_to_vector_unsafe does not keep direct length 0..4 ahead of generic fill"))
    (for ([bad (in-list '("pvector_ref_unsafe"
                          "pvector_to_list_unsafe"
                          "scheme_make_pair"))])
      (when (regexp-match? (regexp (regexp-quote bad)) c-short-vector-section)
        (fail! "pvector_to_vector_unsafe routes short vector materialization through ~a"
               bad))))
  (for ([spec (in-list '(("pvector_digit_to_list_reverse_unsafe"
                          . "pvector_node_to_list_reverse_unsafe")
                         ("pvector_node_to_list_reverse_unsafe"
                          . "pvector_to_list_unsafe")
                         ("pvector_to_list_unsafe"
                          . "checked_vector_arg")))])
    (define name (car spec))
    (define next-name (cdr spec))
    (define section (source-c-function-section pvector-source name next-name))
    (unless section
      (fail! "pvector.c ~a section was not found" name))
    (when section
      (check-source-mentions!
       (format "pvector.c ~a" name)
       section
       '("scheme_make_pair"))
      (for ([bad (in-list '("pvector_fill_vector_unsafe"
                            "core_pvector_to_vector"
                            "scheme_make_vector"
                            "pvector_ref_unsafe"))])
        (when (regexp-match? (regexp (regexp-quote bad)) section)
          (fail! "pvector.c ~a uses vector snapshot/ref helper ~a"
                 name
                 bad)))))
  (define c-short-list-section
    (source-c-function-section pvector-source
                               "pvector_to_list_unsafe"
                               "checked_vector_arg"))
  (unless c-short-list-section
    (fail! "pvector.c pvector_to_list_unsafe section was not found"))
  (when c-short-list-section
    (unless (source-contains-in-order?
             c-short-list-section
             '("len = SCHEME_PVECTOR_LENGTH"
               "len == 0"
               "return scheme_null;"
               "len == 1"
               "scheme_make_pair(SCHEME_PVECTOR_A"
               "len <= 4"
               "SCHEME_PVECTOR_DIGIT_ELS"
               "pvector_digit_to_list_reverse_unsafe"))
      (fail! "pvector_to_list_unsafe does not keep direct length 0..4 ahead of generic list traversal"))
    (for ([bad (in-list '("pvector_ref_unsafe"
                          "pvector_fill_vector_unsafe"
                          "scheme_make_vector"))])
      (when (regexp-match? (regexp (regexp-quote bad)) c-short-list-section)
        (fail! "pvector_to_list_unsafe routes short list materialization through ~a"
               bad))))
  (define core-to-vector-section
    (source-c-function-section pvector-source
                               "core_pvector_to_vector"
                               "core_pvector_to_list"))
  (unless core-to-vector-section
    (fail! "pvector.c core_pvector_to_vector section was not found"))
  (when core-to-vector-section
    (unless (source-contains-in-order?
             core-to-vector-section
             '("checked_pvector"
               "return pvector_to_vector_unsafe"))
      (fail! "core_pvector_to_vector does not delegate to direct vector materializer")))

  (for ([name (in-list '(pvector->list pvector->vector))])
    (define section (source-define-function-section public-source name))
    (unless section
      (fail! "racket/pvector.rkt is missing ~a" name))
    (when section
      (unless (source-contains-in-order?
               section
               '("case (pvector-length/unsafe pv)"
                 "[(1)"
                 "raw:pvector-view-left/fast"
                 "[(2)"
                 "raw:pvector-view-right/fast"
                 "[(3)"
                 "raw:pvector-ref/fast tree 1"
                 "[(4)"
                 "raw:pvector-ref/fast tree 2"
                 "[else"))
        (fail! "public ~a does not keep length 1..4 materialization ahead of raw fallback"
               name))))
  (for ([spec (in-list '(("pvector_map_digit_unsafe"
                          . "pvector_constant_digit_like")
                         ("pvector_map_node_unsafe"
                          . "pvector_constant_node_like")
                         ("pvector_map_unsafe"
                          . "pvector_constant_map_unsafe")
                         ("pvector_for_each_digit_unsafe"
                          . "pvector_for_each_node_unsafe")
                         ("pvector_for_each_node_unsafe"
                          . "pvector_for_each_unsafe")
                         ("pvector_for_each_unsafe"
                          . "pvector_cursor_int")))])
    (define name (car spec))
    (define next-name (cdr spec))
    (define section (source-c-function-section pvector-source name next-name))
    (unless section
      (fail! "pvector.c ~a section was not found" name))
    (when section
      (for ([bad (in-list '("pvector_fill_vector_unsafe"
                            "pvector_to_list_unsafe"
                            "pvector_ref_unsafe"
                            "scheme_make_vector"))])
        (when (regexp-match? (regexp (regexp-quote bad)) section)
          (fail! "pvector.c ~a materializes or indexes instead of traversing directly via ~a"
                 name
                 bad)))))
  (define core-map-section
    (source-c-function-section pvector-source
                               "core_pvector_map_prim"
                               "core_pvector_for_each_prim"))
  (define core-for-each-section
    (source-c-function-section pvector-source
                               "core_pvector_for_each_prim"
                               "core_pvector_split_at_prim"))
  (unless core-map-section
    (fail! "pvector.c core_pvector_map_prim section was not found"))
  (when core-map-section
    (unless (source-contains-in-order?
             core-map-section
             '("SAME_OBJ(proc, scheme_values_proc)"
               "return pv_obj;"
               "SAME_OBJ(proc, scheme_void_proc)"
               "pvector_constant_map_unsafe"
               "scheme_check_proc_arity"
               "return pvector_map_unsafe"))
      (fail! "core-pvector-map does not keep direct values/void/map traversal order")))
  (unless core-for-each-section
    (fail! "pvector.c core_pvector_for_each_prim section was not found"))
  (when core-for-each-section
    (unless (source-contains-in-order?
             core-for-each-section
             '("SAME_OBJ(proc, scheme_values_proc)"
               "SAME_OBJ(proc, scheme_void_proc)"
               "return scheme_void;"
               "scheme_check_proc_arity"
               "pvector_for_each_unsafe"
               "return scheme_void;"))
      (fail! "core-pvector-for-each does not keep direct values/void/for-each traversal order")))
  (define adapter-map-section
    (source-define-binding-section adapter-source 'pvector-map))
  (define adapter-for-each-section
    (source-define-binding-section adapter-source 'pvector-for-each))
  (unless adapter-map-section
    (fail! "runtime adapter is missing pvector-map binding"))
  (when adapter-map-section
    (unless (source-contains-in-order?
             adapter-map-section
             '("if core-available?"
               "core-pvector-map"
               "fallback:for/pvector"))
      (fail! "runtime adapter pvector-map does not bind directly to core-pvector-map when available")))
  (unless adapter-for-each-section
    (fail! "runtime adapter is missing pvector-for-each binding"))
  (when adapter-for-each-section
    (unless (source-contains-in-order?
             adapter-for-each-section
             '("if core-available?"
               "core-pvector-for-each"
               "fallback:pvector-for-each"))
      (fail! "runtime adapter pvector-for-each does not bind directly to core-pvector-for-each when available")))
  (for ([name (in-list '(exported-pvector-map
                         exported-pvector-for-each
                         exported-pvector->list
                         exported-pvector->vector))])
    (define section (source-define-binding-section public-source name))
    (unless section
      (fail! "racket/pvector.rkt is missing ~a" name))
    (when section
      (unless (source-contains-in-order?
               section
               '("if bc-native-public?"
                 "raw:"))
        (fail! "public ~a does not export the raw BC-native binding when available"
               name)))))

(define (check-source-pvector-public-hot-exports!)
  (define public-source
    (file->string (repo-path "racket/collects/racket/pvector.rkt")))
  (for ([name (in-list '(exported-pvector?
                         exported-pvector-empty
                         exported-pvector-empty?
                         exported-pvector->list
                         exported-pvector->vector
                         exported-pvector-length
                         exported-pvector-ref
                         exported-pvector-set
                         exported-pvector-first
                         exported-pvector-last
                         exported-pvector-cons-left
                         exported-pvector-cons-right
                         exported-pvector-pop-left
                         exported-pvector-pop-right
                         exported-pvector-append
                         exported-pvector-map
                         exported-pvector-for-each
                         exported-pvector-insert
                         exported-pvector-delete
                         exported-pvector-take
                         exported-pvector-drop
                         exported-pvector-take-right
                         exported-pvector-drop-right
                         exported-pvector-split
                         exported-pvector-split-at))])
    (define section (source-define-binding-section public-source name))
    (unless section
      (fail! "racket/pvector.rkt is missing ~a" name))
    (when section
      (unless (source-contains-in-order?
               section
               '("if bc-native-public?"
                 "raw:"))
        (fail! "public ~a does not bind directly to raw BC-native operation when available"
               name)))))

(define (check-source-pvector-endpoint-pop-paths!)
  (define pvector-source
    (file->string (repo-path "racket/src/bc/src/pvector.c")))
  (for ([spec (in-list '(("pvector_view_left_unsafe"
                          . "pvector_view_right_unsafe")
                         ("pvector_view_right_unsafe"
                          . "scheme_unsafe_pvector_ref")))])
    (define name (car spec))
    (define next-name (cdr spec))
    (define section (source-c-function-section pvector-source name next-name))
    (unless section
      (fail! "pvector.c ~a section was not found" name))
    (when section
      (check-source-mentions!
       (format "pvector.c ~a" name)
       section
       '("SCHEME_PVECTOR_SINGLE"
         "SCHEME_PVECTOR_DEEP"))
      (for ([bad (in-list '("pvector_ref_unsafe"
                            "pvector_copy_range_unsafe"
                            "pvector_pop_left_unsafe"
                            "pvector_pop_right_unsafe"
                            "scheme_make_vector"
                            "scheme_make_pair"))])
        (when (regexp-match? (regexp (regexp-quote bad)) section)
          (fail! "pvector.c ~a routes endpoint access through ~a"
                 name
                 bad)))))
  (for ([spec (in-list '(("pvector_pop_left_unsafe"
                          . "core_pvector_pop_left_prim")
                         ("pvector_pop_right_unsafe"
                          . "core_pvector_append_prim")))])
    (define name (car spec))
    (define next-name (cdr spec))
    (define section (source-c-function-section pvector-source name next-name))
    (unless section
      (fail! "pvector.c ~a section was not found" name))
    (when section
      (check-source-mentions!
       (format "pvector.c ~a" name)
       section
       '("SCHEME_PVECTOR_EMPTY"
         "SCHEME_PVECTOR_SINGLE"
         "node_tree_pop"
         "make_digit_without"
         "make_deep_pvector"))
      (for ([bad (in-list '("pvector_ref_unsafe"
                            "pvector_copy_range_unsafe"
                            "pvector_split_at_unsafe"
                            "pvector_append_unsafe"
                            "scheme_make_vector"
                            "scheme_make_pair"))])
        (when (regexp-match? (regexp (regexp-quote bad)) section)
          (fail! "pvector.c ~a materializes or uses general access helper ~a"
                 name
                 bad)))))
  (for ([spec (in-list '(("core_pvector_pop_left_prim"
                          . "core_pvector_pop_right_prim")
                         ("core_pvector_pop_right_prim"
                          . "pvector_pop_right_unsafe")))])
    (define name (car spec))
    (define next-name (cdr spec))
    (define section (source-c-function-section pvector-source name next-name))
    (unless section
      (fail! "pvector.c ~a section was not found" name))
    (when section
      (unless (source-contains-in-order?
               section
               '("checked_pvector"
                 "pvector_pop_"
                 "scheme_values"))
        (fail! "pvector.c ~a does not check once and delegate to unchecked pop helper"
               name)))))

(define (check-source-pvector-ref/set-paths!)
  (define pvector-source
    (file->string (repo-path "racket/src/bc/src/pvector.c")))
  (define ref-section
    (source-c-function-section pvector-source
                               "pvector_ref_unsafe"
                               "pvector_view_left_unsafe"))
  (unless ref-section
    (fail! "pvector.c pvector_ref_unsafe section was not found"))
  (when ref-section
    (unless (source-contains-in-order?
             ref-section
             '("prefix = (Scheme_PVector_Digit *)pv->a;"
               "if (index < prefix->count)"
               "return prefix->els[index];"
               "suffix = (Scheme_PVector_Digit *)pv->c;"
               "suffix_start = pv->length - suffix->count;"
               "if (index >= suffix_start)"
               "node_ref(pv->b, index - prefix->count)"))
      (fail! "pvector_ref_unsafe does not keep prefix hit before suffix read and middle descent"))
    (for ([bad (in-list '("pvector_view_left_unsafe"
                          "pvector_view_right_unsafe"
                          "pvector_fill_vector_unsafe"
                          "pvector_to_list_unsafe"
                          "scheme_make_vector"
                          "scheme_make_pair"))])
      (when (regexp-match? (regexp (regexp-quote bad)) ref-section)
        (fail! "pvector_ref_unsafe routes indexed ref through ~a"
               bad))))
  (define node-ref-section
    (source-c-function-section pvector-source
                               "node_ref"
                               "node_set"))
  (unless node-ref-section
    (fail! "pvector.c node_ref section was not found"))
  (when node-ref-section
    (check-source-mentions!
     "pvector.c node_ref"
     node-ref-section
     '("node->level == 0"
       "return node->a"
       "return node->b"
       "return node->c"
       "pvector_child_measure"
       "return node_ref"))
    (for ([bad (in-list '("pvector_ref_unsafe"
                          "pvector_view_left_unsafe"
                          "pvector_fill_vector_unsafe"
                          "scheme_make_vector"))])
      (when (regexp-match? (regexp (regexp-quote bad)) node-ref-section)
        (fail! "node_ref routes through ~a instead of direct recursive fields"
               bad))))
  (define node-set-section
    (source-c-function-section pvector-source
                               "node_set"
                               "pvector_ref_unsafe"))
  (unless node-set-section
    (fail! "pvector.c node_set section was not found"))
  (when node-set-section
    (check-source-mentions!
     "pvector.c node_set"
     node-set-section
     '("SAME_OBJ(node->a, value)"
       "SAME_OBJ(node->b, value)"
       "SAME_OBJ(node->c, value)"
       "new_child = node_set"
       "SAME_OBJ(new_child, node->a)"
       "SAME_OBJ(new_child, node->b)"
       "SAME_OBJ(new_child, node->c)"
       "return node_obj"))
    (for ([bad (in-list '("node_ref"
                          "pvector_ref_unsafe"
                          "pvector_fill_vector_unsafe"
                          "pvector_to_list_unsafe"
                          "scheme_make_vector"))])
      (when (regexp-match? (regexp (regexp-quote bad)) node-set-section)
        (fail! "node_set uses pre-ref/materialization helper ~a"
               bad))))
  (define set-section
    (source-c-function-section pvector-source
                               "core_pvector_set_prim"
                               "pvector_cons_left_unsafe"))
  (unless set-section
    (fail! "pvector.c core_pvector_set_prim section was not found"))
  (when set-section
    (unless (source-contains-in-order?
             set-section
             '("checked_pvector_index_contract"
               "checked_pvector"
               "checked_pvector_index_after_contract"
               "if (pv->shape == SCHEME_PVECTOR_SINGLE)"
               "SAME_OBJ(pv->a, value)"
               "if (index < pv->prefix_len)"
               "SAME_OBJ(SCHEME_PVECTOR_DIGIT_ELS(pv->a)[index], value)"
               "else if (index >= suffix_start)"
               "SAME_OBJ(SCHEME_PVECTOR_DIGIT_ELS(pv->c)[index - suffix_start], value)"
               "middle = node_set"
               "SAME_OBJ(middle, pv->b)"))
      (fail! "core_pvector_set_prim does not compare directly in each selected path"))
    (for ([bad (in-list '("pvector_ref_unsafe"
                          "node_ref"
                          "pvector_copy_range_unsafe"
                          "pvector_split_at_unsafe"
                          "pvector_fill_vector_unsafe"
                          "pvector_to_list_unsafe"
                          "scheme_make_vector"))])
      (when (regexp-match? (regexp (regexp-quote bad)) set-section)
        (fail! "core_pvector_set_prim uses pre-ref/materialization helper ~a"
               bad)))))

(define (check-source-pvector-match-tail-list!)
  (define pvector-source
    (file->string (repo-path "racket/collects/racket/pvector.rkt")))
  (define tail-section
    (source-section-between pvector-source
                            "(define (pvector-match-tail->list"
                            "(define-syntax (for/pvector"))
  (unless tail-section
    (fail! "racket/pvector.rkt pvector-match-tail->list section was not found"))
  (when tail-section
    (check-source-mentions!
     "pvector-match-tail->list"
     tail-section
     '("raw:pvector-ref/fast"))
    (for ([bad (in-list '("pvector->list"
                          "raw:pvector->vector"
                          "pvector->chunk-vector"
                          "pvector->chunk-vector/shared"))])
      (when (regexp-match? (regexp (regexp-quote bad)) tail-section)
        (fail! "pvector-match-tail->list uses materialization helper ~a"
               bad))))
  (define pvector-pattern-section
    (source-section-between pvector-source
                            "(define (pvector-pattern-transform"
                            "(define-match-expander pvector"))
  (unless pvector-pattern-section
    (fail! "racket/pvector.rkt pvector pattern transform section was not found"))
  (when pvector-pattern-section
    (unless (source-contains-in-order?
             pvector-pattern-section
             '("simple-final-repetition"
               "pvector-match-tail->list"
               "repeat-pat"))
      (fail! "pvector match final repetition does not route tail through pvector-match-tail->list")))
  (define pvector*-section
    (source-section-between pvector-source
                            "(define (generate-pvector*-match"
                            "(define-match-expander pvector*"))
  (unless pvector*-section
    (fail! "racket/pvector.rkt pvector* match section was not found"))
  (when pvector*-section
    (check-source-mentions!
     "pvector* match"
     pvector*-section
     '("raw:pvector-ref/fast"
       "raw:pvector-copy"))
    (for ([bad (in-list '("pvector->chunk-vector"
                          "pvector->chunk-vector/shared"))])
      (when (regexp-match? (regexp (regexp-quote bad)) pvector*-section)
        (fail! "pvector* match uses chunk materialization helper ~a"
               bad)))))

(define (check-source-pvector-jit-inline!)
  (define pvector-source
    (file->string (repo-path "racket/src/bc/src/pvector.c")))
  (define jit-source
    (file->string (repo-path "racket/src/bc/src/jitinline.c")))
  (for ([spec (in-list '(("core-pvector?" "SCHEME_PRIM_IS_UNARY_INLINED")
                         ("core-pvector-empty" "SCHEME_PRIM_IS_NARY_INLINED")
                         ("core-pvector-empty?" "SCHEME_PRIM_IS_UNARY_INLINED")
                         ("core-pvector-length" "SCHEME_PRIM_IS_UNARY_INLINED")
                         ("core-pvector-ref" "SCHEME_PRIM_IS_BINARY_INLINED")
                         ("core-unsafe-pvector-length" "SCHEME_PRIM_IS_UNARY_INLINED")
                         ("core-unsafe-pvector-ref" "SCHEME_PRIM_IS_BINARY_INLINED")
                         ("core-unsafe-pvector-first" "SCHEME_PRIM_IS_UNARY_INLINED")
                         ("core-unsafe-pvector-last" "SCHEME_PRIM_IS_UNARY_INLINED")
                         ("core-make-single-pvector" "SCHEME_PRIM_IS_UNARY_INLINED")
                         ("core-make-deep2-pvector" "SCHEME_PRIM_IS_BINARY_INLINED")
                         ("core-make-deep3-pvector" "SCHEME_PRIM_IS_NARY_INLINED")
                         ("core-make-deep4-pvector" "SCHEME_PRIM_IS_NARY_INLINED")))])
    (unless (source-contains-in-order? pvector-source spec)
      (fail! "pvector.c does not register ~a with ~a"
             (car spec)
             (cadr spec))))
  (for ([symbol-name (in-list '("core-pvector?"
                                "core-pvector-empty?"
                                "core-pvector-length"
                                "core-unsafe-pvector-length"
                                "core-pvector-ref"
                                "core-unsafe-pvector-ref"
                                "core-unsafe-pvector-first"
                                "core-unsafe-pvector-last"
                                "core-pvector-empty"
                                "core-make-single-pvector"
                                "core-make-deep2-pvector"
                                "core-make-deep3-pvector"
                                "core-make-deep4-pvector"
                                "generate_checked_pvector_ref"
                                "generate_unsafe_pvector_ref"
                                "generate_pvector_single_alloc"
                                "generate_pvector_deep2_alloc"
                                "generate_pvector_deep_n_alloc"))])
    (unless (regexp-match? (regexp (regexp-quote symbol-name)) jit-source)
      (fail! "jitinline.c does not mention ~a for pvector inline support"
             symbol-name))))

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
  (unless (eq? (alist-ref 'small-flat-representation no-chunk-baseline)
               'absent)
    (fail! "no-chunk-baseline does not require absent small-flat representation"))
  (check-source-no-small-flat-representation!)
  (unless (eq? (alist-ref 'hot-sequence-path no-chunk-baseline)
               'unsafe-ref-checked-once)
    (fail! "no-chunk-baseline does not require checked-once unsafe-ref sequence path"))
  (unless (eq? (alist-ref 'sequence-cursor-primitives no-chunk-baseline)
               'present-bc-native)
    (fail! "no-chunk-baseline does not require BC-native cursor primitives"))
  (unless (eq? (alist-ref 'sequence-cursor-representation no-chunk-baseline)
               'internal-runtime-object)
    (fail! "no-chunk-baseline does not record the internal cursor representation"))
  (unless (equal? (alist-ref 'sequence-cursor-min-length no-chunk-baseline)
                  32768)
    (fail! "no-chunk-baseline does not record the cursor minimum length"))
  (unless (eq? (alist-ref 'generic-sequence-cursor-path no-chunk-baseline)
               'large-native-cursor-when-core-available)
    (fail! "no-chunk-baseline does not record the generic sequence cursor path"))
  (check-source-core-pvector-generic-sequence-cursor!)
  (check-source-pvector-default-sequence-ref!)
  (unless (eq? (alist-ref 'runtime-type-and-gc no-chunk-baseline)
               'bc-type-tags-type-names-and-traversers)
    (fail! "no-chunk-baseline does not record BC runtime type and GC traversal coverage"))
  (check-source-pvector-runtime-type-and-gc!)
  (unless (eq? (alist-ref 'public-unsafe-bc-native-hot-exports
                          no-chunk-baseline)
               'direct-core-binding)
    (fail! "no-chunk-baseline does not require direct BC-native unsafe exports"))
  (unless (eq? (alist-ref 'core-unsafe-first/last-primitives no-chunk-baseline)
               'present-bc-native)
    (fail! "no-chunk-baseline does not record BC-native unsafe first/last primitives"))
  (unless (eq? (alist-ref 'fresh-vector-construction no-chunk-baseline)
               'no-freeze-copy)
    (fail! "no-chunk-baseline does not require fresh vector construction without freeze copy"))
  (unless (eq? (alist-ref 'fresh-result-materialization no-chunk-baseline)
               'no-freeze-copy)
    (fail! "no-chunk-baseline does not require fresh result materialization without freeze copy"))
  (check-source-pvector-fresh-vector-paths!)
  (check-source-pvector-core-tree-ops-no-materialization!)
  (for ([spec (in-list '((core-range-operations
                          . checked-once-unchecked-range-helper)
                         (deep-digit-lengths
                          . "1..4")
                         (core-copy-range-check
                          . single-length-read)
                         (core-node-leaf-construction
                          . fixed-measure-direct-record-constructor)
                         (core-digit-constructors
                          . inline-vector-immutable-no-freeze-copy)
                         (core-digit-slice-length-0..4
                         . direct-immutable-vector-no-copy-freeze)
                         (core-pvector-range-immutable-length-0..4
                          . direct-immutable-vector-no-temp-fill)
                         (core-large-single-append
                          . fixed-size-digit-insert-or-single-digit-bridge)
                         (core-large-single-append-known-length
                          . no-length-reprobe)
                         (core-large-edge-cons
                          . fixed-size-digit-insert-or-full-digit-bridge)
                         (core-large-edge-cons-known-length
                          . no-length-reprobe)
                         (core-full-digit-bridge
                          . direct-node2-tree-no-temp-vector)
                         (core-full-digit-pair-bridge
                          . direct-node3-tree-no-branch-ref)
                         (core-shape-specialized-cons/append
                          . no-obsolete-representation-fallback)
                         (core-large-copy-edge-digits
                          . direct-digit-slice-share)
                         (core-large-copy-edge-helper
                          . top-level-helper-no-local-closure)
                         (core-large-copy-known-length
                          . no-length-reprobe)
                         (core-pvector-range-immutable-known-length
                          . no-length-reprobe)
                         (core-bridge-nodes
                          . direct-node-construction-no-temp-vector)
                         (core-bridge-root-measure
                          . fixed-bridge-measure-no-child-measure-read)
                         (core-bridge-digit-combos
                          . fixed-length-combos-no-per-slot-branch)
                         (core-middle-node-links
                          . direct-node2/node3-no-list-vector)
                         (core-next-node-level
                          . exact-output-vector-no-copy)
                         (core-aligned-slice-short-pieces
                          . direct-node2/node3-no-list-vector)
                         (core-aligned-slice-leaf
                          . fixed-case-no-piece-list-or-entry-measure)
                         (core-aligned-slice-piece-helper
                          . top-level-helper-no-local-closure-set)
                         (core-aligned-slice-nonleaf-entry
                          . direct-child-node-measure-no-level-branch)
                         (core-digit-set
                          . direct-fixed-size-immutable-vector)
                         (core-digit-insert/delete
                          . direct-fixed-size-immutable-vector)
                         (core-insert/delete-top-level-fallback
                         . shape-specialized-direct-dispatch-no-vector-materialization)
                         (core-large-insert/delete-known-length
                          . no-length-reprobe)
                         (core-large-insert-lazy-fields
                          . prefix-insert-before-suffix-start-computation)
                         (core-large-delete-lazy-fields
                          . prefix-delete-before-suffix-start-computation)
                         (core-middle-insert/delete-composition
                          . unchecked-copy-after-single-check)
                         (core-middle-insert-singleton
                          . cons-right-no-singleton-append)
                         (core-middle-insert/delete-known-length-append
                          . no-length-reprobe)
                         (core-delete-endpoints
                          . direct-copy-no-empty-append)
                         (core-delete-edge-digits
                          . direct-large-finger-digit-shrink-no-range-copy)
                         (core-delete-edge-view-rest
                         . shared-edge-read-no-pre-ref)
                         (core-delete-middle-fallback
                          . no-edge-reprobe-after-fused-edge-view)
                         (core-short-copy
                          . direct-single-deep4-no-temp-vector)
                         (core-large-short-copy
                          . direct-digit-or-known-pieces-no-generic-ref)
                         (core-short-copy-endpoints
                          . direct-digit-no-indexed-descent)
                         (core-short-range-endpoints
                          . first-last-edge-check-only)
                         (core-large-short-immutable-range
                          . direct-digit-or-known-pieces-no-generic-ref)
                         (core-copy-edge-one
                          . direct-large-finger-digit-shrink-no-range-copy)
                         (core-copy-edge-trim
                          . direct-large-finger-multi-edge-shrink-no-range-copy)
                         (core-copy-edge-one-known-length
                          . no-length-reprobe)
                         (core-copy-fallback-fill-known-length
                          . no-length-reprobe)
                         (core-range-endpoints
                          . direct-empty-self-no-copy-helper)
                         (core-split-endpoints
                          . direct-empty-self-no-copy-helper)
                         (core-split-at-edge-one
                          . shared-edge-view-rest-no-double-copy)
                         (core-split-at-edge-interior
                          . shared-edge-digits-no-double-copy)
                         (core-split-edge-lazy-fields
                          . prefix-branch-before-suffix-start-computation)
                         (core-split-at-edge-lazy-fields
                          . prefix-branch-before-suffix-start-computation)
                         (core-split-edge-view
                          . shared-edge-read-no-pre-ref-or-side-copy)
                         (core-split/delete-selected-endpoints
                          . direct-endpoint-no-indexed-descent)))])
    (unless (equal? (alist-ref (car spec) no-chunk-baseline) (cdr spec))
      (fail! "no-chunk-baseline does not record ~a as ~a"
             (car spec)
             (cdr spec))))
  (check-source-pvector-range/edit-paths!)
  (check-source-pvector-digit/bridge-paths!)
  (check-source-pvector-cons/append-paths!)
  (for ([spec (in-list '((core-vector-length-1..4-construction
                          . direct-single-deep4)
                         (core-vector-copy-range-length-1..4
                          . direct-mutable-vector-no-loop-set)
                         (core-list-length-1..4-construction
                          . direct-single-deep4-no-temp-vector)
                         (core-make-length-2..4
                          . direct-deep2-deep4-no-temp-vector)
                         (core-short-construction-3/4
                          . direct-deep3/deep4-no-temp-vector)
                         (core-small-construction
                          . direct-empty-single-deep4)
                         (public-arity-1..4-construction
                          . direct-single-deep4-no-temp-vector)
                         (public-list/vector-length-1..4-construction
                          . direct-single-deep4-no-input-vector-copy)
                         (public-literal-range-length-1..4
                          . direct-single-deep4-no-temp-vector)
                         (public/adapter-make-length-5+
                          . runtime-core-make-no-vector-immutable)
                         (adapter-range-length-1..4
                          . direct-single-deep4-no-temp-vector)))])
    (unless (eq? (alist-ref (car spec) no-chunk-baseline) (cdr spec))
      (fail! "no-chunk-baseline does not record ~a as ~a"
             (car spec)
             (cdr spec))))
  (check-source-pvector-small-construction-paths!)
  (for ([spec (in-list '((core-linear-traversal
                          . map-for-each-list)
                         (core-node-traversal-entry
                          . top-level-helper-no-local-closure)
                         (core-node-nonleaf-traversal-entry
                          . direct-recursive-no-level-branch)
                         (core-node-leaf-traversal
                          . direct-field-range-no-entry-measure)
                         (core-node-full-traversal
                          . direct-recursive-no-range-intersection)
                         (core-list-conversion
                          . direct-no-vector-snapshot)
                         (core-map-length-1..4
                          . direct-single-deep4-no-temp-vector)
                         (core-map/for-each-short-deep
                          . direct-digit-or-node2-leaf-no-known-pieces)
                         (core-map-large-fill
                         . direct-range-map-no-for-each-closure)
                         (core-large-traversal-known-length
                          . no-length-reprobe)
                         (core-short-list/vector-materialization
                          . direct-length-0..4-no-known-pieces)
                         (core-short-deep-materialization
                          . known-pieces-known-suffix-start-no-field-reprobe-or-ref-helper)
                         (core-pvector->vector-length-1..4
                          . direct-mutable-vector-no-make/set)
                         (core-vector-segment-traversal
                          . shared-top-level-helpers-no-local-closure-set)
                         (core-large-full-range
                          . direct-prefix-middle-suffix-no-segment-crop)
                         (core-large-partial-edge-ranges
                          . direct-prefix/suffix-no-opposite-field-read)
                         (core-large-partial-middle-ranges
                          . direct-node-range-no-edge-segment-crop)
                         (core-for-each-length-1..4
                          . direct-endpoint-no-range-traversal)
                         (public-list/vector-materialization-length-1..4
                          . direct-endpoint-no-runtime-length-check)
                         (public-map-length-1
                          . direct-core-map-no-temporary-vector)))])
    (unless (eq? (alist-ref (car spec) no-chunk-baseline) (cdr spec))
      (fail! "no-chunk-baseline does not record ~a as ~a"
             (car spec)
             (cdr spec))))
  (check-source-pvector-linear-traversal-paths!)
  (for ([spec (in-list '((core-endpoint-access
                          . direct-no-general-ref)
                         (core-node-ref/set-entry
                          . direct-recursive-no-entry-helper)
                         (core-node-nonleaf-measure
                          . direct-child-node-measure-no-level-branch)
                         (core-node-leaf-ref/set
                          . direct-field-access-no-entry-helper)
                         (core-checked-ref-endpoints
                          . direct-endpoint-no-indexed-descent)
                         (core-indexed-ref-known-length
                          . no-length-reprobe)
                         (core-large-ref-prefix-hit
                          . lazy-suffix-read)
                         (core-set-endpoint-compare
                          . direct-endpoint-no-indexed-descent)
                         (core-short-set
                          . direct-single-deep2-no-digit-copy)
                         (core-large-set-known-length
                          . no-length-reprobe)
                         (core-large-set-compare
                          . fused-no-pre-ref)
                         (core-large-set-lazy-fields
                          . same-value-return-before-opposite-edge-read)
                         (core-pop-operations
                          . checked-once-unchecked-range-helper)
                         (core-pop-endpoints
                          . direct-view-no-general-ref)
                         (core-pop-edge-digits
                          . direct-large-finger-digit-shrink-no-range-copy)
                         (core-pop-edge-known-length
                          . no-length-reprobe)
                         (core-pop-edge-view-rest
                          . shared-edge-read-no-duplicate-prefix/suffix-ref)
                         (core-short-pop/delete
                          . direct-empty-single-no-copy-vector)))])
    (unless (eq? (alist-ref (car spec) no-chunk-baseline) (cdr spec))
      (fail! "no-chunk-baseline does not record ~a as ~a"
             (car spec)
             (cdr spec))))
  (check-source-pvector-ref/set-paths!)
  (check-source-pvector-endpoint-pop-paths!)
  (unless (eq? (alist-ref 'jit-inline-source no-chunk-baseline)
               'first-stage-pvector-hot-paths)
    (fail! "no-chunk-baseline does not record pvector JIT inline source coverage"))
  (check-source-pvector-jit-inline!)
  (unless (eq? (alist-ref 'public-jit-on/off-hot-paths no-chunk-baseline)
               'same-result-score)
    (fail! "no-chunk-baseline does not record public JIT hot-path coverage"))
  (unless (eq? (alist-ref 'performance-strict-policy no-chunk-baseline)
               'bounded-regression-plus-score-and-advantage-dimensions)
    (fail! "no-chunk-baseline does not record the strict performance gate policy"))
  (unless (eq? (alist-ref 'performance-strict-vm no-chunk-baseline)
               'bc-only)
    (fail! "no-chunk-baseline does not record the strict performance VM boundary"))
  (unless (eq? (alist-ref 'linear-traversal-optimization no-chunk-baseline)
               'default-sequence-unsafe-ref)
    (fail! "no-chunk-baseline does not record default unsafe-ref sequence path"))
  (unless (eq? (alist-ref 'linear-traversal-cursor-representation no-chunk-baseline)
               'internal-runtime-object)
    (fail! "no-chunk-baseline does not record the native cursor representation"))
  (unless (equal? (alist-ref 'linear-traversal-cursor-min-length no-chunk-baseline)
                  32768)
    (fail! "no-chunk-baseline does not record the native cursor minimum length"))
  (unless (eq? (alist-ref 'stream-linear-traversal no-chunk-baseline)
               'pvector-for-each-direct)
    (fail! "no-chunk-baseline does not record direct pvector stream traversal"))
  (check-source-pvector-stream-direct-traversal!)
  (unless (eq? (alist-ref 'apply-final-argument no-chunk-baseline)
               'rejects-pvector-as-non-list)
    (fail! "no-chunk-baseline does not record the apply final argument boundary"))
  (check-apply-final-argument-boundary!)
  (unless (eq? (alist-ref 'public-equal/hash no-chunk-baseline)
               'direct-no-chunk-vector-view)
    (fail! "no-chunk-baseline does not record direct public equal/hash"))
  (check-source-pvector-direct-equal/hash!)
  (unless (eq? (alist-ref 'public-printer no-chunk-baseline)
               'opaque-length-native-printer)
    (fail! "no-chunk-baseline does not record the public native printer"))
  (check-source-pvector-printer!)
  (unless (eq? (alist-ref 'public-serialization no-chunk-baseline)
               'bc-native-rejects-serialize)
    (fail! "no-chunk-baseline does not record the public serialization boundary"))
  (check-public-serialization-boundary!)
  (unless (eq? (alist-ref 'public-match-tail-list no-chunk-baseline)
               'direct-no-chunk-lookup)
    (fail! "no-chunk-baseline does not record direct public match tail lookup"))
  (check-source-pvector-match-tail-list!)
  (unless (eq? (alist-ref 'public-bc-native-hot-exports no-chunk-baseline)
               'direct-core-binding-including-index-sensitive-ops)
    (fail! "no-chunk-baseline does not record direct public BC-native hot exports"))
  (check-source-pvector-public-hot-exports!)
  (unless (eq? (alist-ref 'gc-stress no-chunk-baseline)
               'large-box-elements-and-native-cursor-survive-collection)
    (fail! "no-chunk-baseline does not record the GC stress acceptance test"))
  (unless (eq? (alist-ref 'place-message-boundary no-chunk-baseline)
               'rejects-pvector-as-not-allowed)
    (fail! "no-chunk-baseline does not record the place-message boundary"))
  (check-public-place-message-boundary!)
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
  (unless (alist-ref 'core-large-finger no-chunk-baseline)
    (fail! "no-chunk-baseline does not record core-large-finger shape constraints"))
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
  (define racket-bin (benchmark-racket-path))
  (define script (repo-path rel))
  (define command
    (append (list (path-string racket-bin)
                  "-c"
                  "-y"
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

(define (check-benchmark-coverage! label index sizes ops impls)
  (for* ([size (in-list sizes)]
         [op (in-list ops)]
         [impl (in-list impls)])
    (benchmark-row label index size op impl)))

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
(define benchmark-impls '(list vector treelist pvector adapter-pvector))

(define (check-list-workload-performance!)
  (define sizes '(1 2 4 8 16 64))
  (define ops '(build-live sum-live ref-live cons-left-live cons-right-live
                           drop-left-live append-self-live))
  (define rows
    (run-benchmark-tsv
     "list-workload"
     "pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/list-workload.rkt"
     (list "--count" (number->string performance-count)
           "--sizes" (string-join (map number->string sizes) ",")
           "--ops" "build-live,sum-live,ref-live,cons-left-live,cons-right-live,drop-left-live,append-self-live"
           "--impls" "list,vector,treelist,pvector,adapter-pvector")))
  (define index (index-benchmark-rows rows))
  (check-benchmark-coverage! "list-workload" index sizes ops benchmark-impls)
  (when (strict-performance-thresholds?)
    (for ([impl (in-list performance-impls)])
      (for ([size (in-list '(1 2 4))])
        ;; The paper-style BC representation intentionally uses a top-level
        ;; deep object plus two digit objects for size 2+, so tiny construction
        ;; has a fixed object-count tax. Keep it bounded here; use the score
        ;; suite and future cursor/layout work to drive tighter targets.
        (check-real-ratio! "list-workload" index size 'build-live impl 'list 2.5)
        (check-real-ratio! "list-workload" index size 'cons-left-live impl 'list 2.0)
        (check-real-ratio! "list-workload" index size 'ref-live impl 'treelist 1.0))
      (check-live-bytes-ratio! "list-workload" index 1 'build-live impl 'list 2.0)
      (for ([size (in-list '(2 4))])
        (check-live-bytes-ratio! "list-workload" index size 'build-live impl 'list 3.0)
        (check-live-bytes-ratio! "list-workload" index size 'build-live impl 'vector 4.0))
      (check-live-bytes-ratio! "list-workload" index 64 'build-live impl 'list 1.0)
      (check-live-bytes-ratio! "list-workload" index 64 'append-self-live impl 'list 1.0)
      (check-real-ratio! "list-workload" index 64 'append-self-live impl 'list 1.0)
      (check-real-ratio! "list-workload" index 64 'append-self-live impl 'vector 1.0))))

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
  (check-benchmark-coverage! "list-spectrum" index sizes ops benchmark-impls)
  (when (strict-performance-thresholds?)
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
        (check-real-ratio! "list-spectrum" index size 'append-self impl 'vector 1.5)
        (check-real-ratio! "list-spectrum" index size 'build impl 'list 1.0)
        (check-real-ratio! "list-spectrum" index size 'build impl 'treelist 1.0)
        (check-real-ratio! "list-spectrum" index size 'map-add1 impl 'vector 1.0)
        (check-real-ratio! "list-spectrum" index size 'map-add1 impl 'treelist 1.0)
        ;; Cursor traversal is enabled for medium/large pvectors. Keep linear
        ;; sum bounded while short pvectors avoid cursor allocation.
        (check-real-ratio! "list-spectrum" index size 'sum impl 'list 2.5)))))

(define list-score-required-columns
  '(kind size power band op impl iterations cpu-ms real-ms real-ns/op gc-ms
         live-bytes cost-model generated-result-cost-units
         result-cost-units/op result baseline speed-score/list
         speed-score/vector cost-score/list cost-score/vector speed-score
         cost-score total-score sample-count weight score-profile
         size-weight-model operation-weight-model interface-model score-method
         speed-metric cost-metric racket-version vm machine os jit-enabled))

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
    (printf "pvector performance gate checked mode=~a count=~a m=~a\n"
            (cond
              [performance-smoke? 'smoke-contract]
              [(strict-performance-thresholds?) 'strict-threshold]
              [else 'coverage-contract-non-bc])
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
