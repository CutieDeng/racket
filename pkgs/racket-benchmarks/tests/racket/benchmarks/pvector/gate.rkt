#lang racket/base

(require racket/cmdline
         racket/file
         racket/list
         racket/match
         racket/path
         racket/system
         (prefix-in chunked: racket/private/pvector-chunked))

(define N 10000)
(define quiet? #f)
(define compile-rumble? #f)

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
                       (set! compile-rumble? #t)])

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
     (href h 'vector-leaves)))

(define (ratio numerator denominator)
  (/ numerator (max 1 denominator)))

(define (format-ratio r)
  (real->decimal-string r 4))

(define (objects-per-elem h)
  (ratio (total-objects h) (href h 'length)))

(define (retained-per-visible h)
  (ratio (href h 'retained-elems) (href h 'visible-elems)))

(define (build-compact n)
  (chunked:list->pvector (build-list n values)))

(define (build-cons-right n)
  (for/fold ([pv (chunked:pvector-empty)]) ([i (in-range n)])
    (chunked:pvector-cons-right pv i)))

(define (build-cons-left n)
  (for/fold ([pv (chunked:pvector-empty)]) ([i (in-range n)])
    (chunked:pvector-cons-left pv i)))

(define (pop-left-half pv n)
  (for/fold ([pv pv]) ([i (in-range (quotient n 2))])
    (define-values (_ rest) (chunked:pvector-pop-left pv))
    rest))

(define (pop-right-half pv n)
  (for/fold ([pv pv]) ([i (in-range (quotient n 2))])
    (define-values (_ rest) (chunked:pvector-pop-right pv))
    rest))

(define (split-left pv n)
  (define-values (left right) (chunked:pvector-split-at pv (quotient n 2)))
  left)

(define (split-right pv n)
  (define-values (left right) (chunked:pvector-split-at pv (quotient n 2)))
  right)

(define (subvector-middle pv n)
  (chunked:pvector-copy pv (quotient n 4) (- n (quotient n 4))))

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
  (regexp-symbols #px"\\(define-record-type\\s+([^\\s()\\[\\]]+)" s))

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
                (fail! "~a is missing primitive entry ~a" kernel-rel name)))))
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
   '(pvector leaf-chunk leaf-vector digit1 digit2 digit3 digit4
     node2 node3 empty-tree single-tree deep-tree))
  (check-members
   "helper group"
   (and runtime-helper-groups (map car runtime-helper-groups))
   '(chunk tree pvector iteration debug-only))
  (check-members
   "primitive candidate"
   (and primitive-candidates
        (for/list ([candidate (in-list primitive-candidates)])
          (alist-ref 'name candidate)))
   '(pvector? pvector-empty pvector-empty? pvector-length
     list->pvector vector->pvector sequence->pvector pvector->list
     pvector->vector pvector-ref pvector-set pvector-cons-left
     pvector-cons-right pvector-pop-left pvector-pop-right pvector-append
     pvector-split-at pvector-split-at-right pvector-take pvector-drop
     pvector-copy))
  (for ([name '(compact cons-right cons-left pop-left-half pop-right-half
                split-left split-right subvector-middle)])
    (unless (alist-ref name shape-gates)
      (fail! "runtime boundary manifest is missing shape gate ~a" name))))

(define (check-shape! name pv)
  (define spec (alist-ref name shape-gates))
  (define h (chunked:pvector-shape-stats pv))
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

(check-boundary!)

(unless quiet?
  (printf "pvector runtime boundary: ~a\n" (alist-ref 'status boundary))
  (printf "shape gate n=~a\n" N))

(for ([name+pv (in-list (scenario-values N))])
  (check-shape! (car name+pv) (cdr name+pv)))

(check-rumble-compile!)

(cond
  [(null? failures)
   (unless quiet?
     (printf "pvector gate: ok\n"))]
  [else
   (for ([msg (in-list (reverse failures))])
     (eprintf "pvector gate: ~a\n" msg))
   (exit 1)])
