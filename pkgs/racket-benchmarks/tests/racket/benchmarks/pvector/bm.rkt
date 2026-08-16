#lang racket/base

(require racket/cmdline
         racket/list
         racket/match
         racket/pvector
         (prefix-in adapter: racket/private/pvector-runtime-adapter)
         (prefix-in raw: racket/private/pvector)
         (prefix-in unsafe: (submod racket/pvector unsafe))
         racket/string
         racket/stream
         racket/treelist
         racket/vector)

(define M 20)
(define N 1000)
(define list-limit 2000)
(define impls '(list vector treelist raw-pvector adapter-pvector pvector unsafe-pvector))
(define ops #f)
(define cutie-module
  (let ([p (getenv "PLT_PVECTOR_CUTIE_MODULE")])
    (and p (string->path p))))

(define (unloaded-cutie name)
  (lambda args
    (raise-user-error
     'pvector-bm
     "cutie-pvector operation ~a was used before cutie support was loaded"
     name)))

(define cutie:pvector? (lambda (_) #f))
(define cutie:pvector (unloaded-cutie 'pvector))
(define cutie:pvector-empty (unloaded-cutie 'pvector-empty))
(define cutie:pvector-length (unloaded-cutie 'pvector-length))
(define cutie:pvector-ref (unloaded-cutie 'pvector-ref))
(define cutie:pvector-set (unloaded-cutie 'pvector-set))
(define cutie:pvector-cons-left (unloaded-cutie 'pvector-cons-left))
(define cutie:pvector-cons-right (unloaded-cutie 'pvector-cons-right))
(define cutie:pvector-pop-left (unloaded-cutie 'pvector-pop-left))
(define cutie:pvector-pop-right (unloaded-cutie 'pvector-pop-right))
(define cutie:pvector-append (unloaded-cutie 'pvector-append))
(define cutie:pvector-take (unloaded-cutie 'pvector-take))
(define cutie:pvector-drop (unloaded-cutie 'pvector-drop))
(define cutie:pvector-copy (unloaded-cutie 'pvector-copy))
(define cutie:pvector-insert (unloaded-cutie 'pvector-insert))
(define cutie:pvector-delete (unloaded-cutie 'pvector-delete))
(define cutie:pvector-split-at (unloaded-cutie 'pvector-split-at))
(define cutie:pvector-view-left (unloaded-cutie 'pvector-view-left))
(define cutie:pvector-view-right (unloaded-cutie 'pvector-view-right))
(define cutie:pvector->list (unloaded-cutie 'pvector->list))
(define cutie:pvector->vector (unloaded-cutie 'pvector->vector))
(define cutie:list->pvector (unloaded-cutie 'list->pvector))
(define cutie:vector->pvector (unloaded-cutie 'vector->pvector))
(define cutie:in-pvector (unloaded-cutie 'in-pvector))
(define cutie:in-pvector-reverse (unloaded-cutie 'in-pvector-reverse))

(define cutie-loaded? #f)

(define (load-cutie name)
  (unless cutie-module
    (raise-user-error
     'pvector-bm
     "cutie-pvector was requested, but no cutie module was supplied; use --cutie-module or PLT_PVECTOR_CUTIE_MODULE"))
  (dynamic-require cutie-module name))

(define (load-cutie-support!)
  (unless cutie-loaded?
    (set! cutie:pvector? (load-cutie 'pvector?))
    (set! cutie:pvector (load-cutie 'pvector))
    (set! cutie:pvector-empty (load-cutie 'pvector-empty))
    (set! cutie:pvector-length (load-cutie 'pvector-length))
    (set! cutie:pvector-ref (load-cutie 'pvector-ref))
    (set! cutie:pvector-set (load-cutie 'pvector-set))
    (set! cutie:pvector-cons-left (load-cutie 'pvector-cons-left))
    (set! cutie:pvector-cons-right (load-cutie 'pvector-cons-right))
    (set! cutie:pvector-pop-left (load-cutie 'pvector-pop-left))
    (set! cutie:pvector-pop-right (load-cutie 'pvector-pop-right))
    (set! cutie:pvector-append (load-cutie 'pvector-append))
    (set! cutie:pvector-take (load-cutie 'pvector-take))
    (set! cutie:pvector-drop (load-cutie 'pvector-drop))
    (set! cutie:pvector-copy (load-cutie 'pvector-copy))
    (set! cutie:pvector-insert (load-cutie 'pvector-insert))
    (set! cutie:pvector-delete (load-cutie 'pvector-delete))
    (set! cutie:pvector-split-at (load-cutie 'pvector-split-at))
    (set! cutie:pvector-view-left (load-cutie 'pvector-view-left))
    (set! cutie:pvector-view-right (load-cutie 'pvector-view-right))
    (set! cutie:pvector->list (load-cutie 'pvector->list))
    (set! cutie:pvector->vector (load-cutie 'pvector->vector))
    (set! cutie:list->pvector (load-cutie 'list->pvector))
    (set! cutie:vector->pvector (load-cutie 'vector->pvector))
    (set! cutie:in-pvector (load-cutie 'in-pvector))
    (set! cutie:in-pvector-reverse (load-cutie 'in-pvector-reverse))
    (set! cutie-loaded? #t)))

(define (parse-count who s)
  (define n (string->number s))
  (unless (exact-positive-integer? n)
    (raise-user-error who "expected a positive exact integer, got ~e" s))
  n)

(define (parse-symbol-list s)
  (for/list ([part (in-list (string-split s ","))]
             #:unless (string=? part ""))
    (string->symbol part)))

(command-line
 #:program "pvector-bm"
 #:once-each
 [("--m") m "Outer repeat count"
          (set! M (parse-count '--m m))]
 [("--n") n "Sequence length"
          (set! N (parse-count '--n n))]
 [("--list-limit") n "Maximum N for O(N^2) list baselines"
                   (set! list-limit (parse-count '--list-limit n))]
 [("--impls") s "Comma-separated implementations: list,vector,treelist,cutie-pvector,raw-pvector,adapter-pvector,pvector,unsafe-pvector"
              (set! impls (parse-symbol-list s))]
 [("--cutie-module") p "Optional path to the original cutie-ftree pvector.rkt"
                     (set! cutie-module (string->path p))]
 [("--ops") s "Comma-separated benchmark names"
           (set! ops (parse-symbol-list s))])

(define (enabled? xs x)
  (or (not xs) (memq x xs)))

(define (build-list-data n)
  (for/list ([i (in-range n)]) i))

(define (build-vector-data n)
  (for/vector #:length n ([i (in-range n)]) i))

(define (vector-set/persistent vec i value)
  (define vec* (vector-copy vec))
  (vector-set! vec* i value)
  vec*)

(define (vector-take vec n)
  (vector-copy vec 0 n))

(define (vector-drop vec n)
  (vector-copy vec n))

(define (summarize-value v)
  (cond
    [(list? v) (format "list:~a" (length v))]
    [(vector? v) (format "vector:~a" (vector-length v))]
    [(treelist? v) (format "treelist:~a" (treelist-length v))]
    [(cutie:pvector? v) (format "cutie-pvector:~a" (cutie:pvector-length v))]
    [(raw:pvector? v) (format "raw-pvector:~a" (raw:pvector-length v))]
    [(adapter:pvector? v) (format "adapter-pvector:~a" (adapter:pvector-length v))]
    [(pvector? v) (format "pvector:~a" (pvector-length v))]
    [else (format "~s" v)]))

(define (bench op impl thunk #:when [ok? #t])
  (when (and ok? (enabled? ops op) (memq impl impls))
    (collect-garbage)
    (collect-garbage)
    (define-values (vals cpu real gc) (time-apply thunk null))
    (define result (if (pair? vals) (car vals) (void)))
    (printf "~a\t~a\t~a\t~a\t~a\t~a\n"
            op impl cpu real gc (summarize-value result))
    (flush-output)))

(define (measure m n)
  (printf "M=~a N=~a\n" m n)
  (printf "op\timpl\tcpu-ms\treal-ms\tgc-ms\tresult\n")
  (define cutie-enabled? (memq 'cutie-pvector impls))
  (when cutie-enabled?
    (load-cutie-support!))

	  (define base-list (build-list-data n))
	  (define base-uniform-list
	    (let ([value (box 'uniform-list)])
	      (make-list n value)))
  (define builder-constant-value (box 'builder-constant))
	  (define base-filter-list
	    (for/list ([i (in-range n)])
	      (and (even? i) i)))
  (define base-vector (list->vector base-list))
  (define base-uniform-vector (make-vector n builder-constant-value))
  (define base-treelist (list->treelist base-list))
  (define base-filter-treelist (list->treelist base-filter-list))
  (define base-cutie-pvector
    (and cutie-enabled? (cutie:list->pvector base-list)))
  (define base-raw-pvector (raw:list->pvector base-list))
  (define base-adapter-pvector (adapter:list->pvector base-list))
  (define base-pvector (list->pvector base-list))
  (define base-filter-pvector (list->pvector base-filter-list))
  (define base-false-pvector (make-pvector n #f))
  (define base-odd-pvector (make-pvector n 1))
  (void (stream->list (pvector-empty)))
  (define match-fixed-pvector (pvector 0 1 2 3))
  (define match-rest-pvector (list->pvector (range 16)))
  (define small-8-list '(0 1 2 3 4 5 6 7))
  (define small-16-list '(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15))
  (define small-17-list '(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16))
  (define small-18-list '(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17))
  (define small-32-list
    '(0 1 2 3 4 5 6 7
      8 9 10 11 12 13 14 15
      16 17 18 19 20 21 22 23
      24 25 26 27 28 29 30 31))
  (define small-64-list
    '(0 1 2 3 4 5 6 7
      8 9 10 11 12 13 14 15
      16 17 18 19 20 21 22 23
      24 25 26 27 28 29 30 31
      32 33 34 35 36 37 38 39
      40 41 42 43 44 45 46 47
      48 49 50 51 52 53 54 55
      56 57 58 59 60 61 62 63))
  (define small-65-list (append small-64-list '(64)))
  (define small-96-list (append small-64-list (range 64 96)))
  (define small-112-list (append small-64-list (range 64 112)))
  (define small-128-list (append small-64-list (range 64 128)))
  (define singleton-list '(0))
  (define singleton-vector #(0))
  (define singleton-pvector (pvector 0))
  (define pair-pvector (pvector 0 1))
  (define triple-pvector (pvector 0 1 2))
  (define quad-pvector (pvector 0 1 2 3))
  (define small-8-vector (list->vector small-8-list))
  (define small-16-vector (list->vector small-16-list))
  (define small-17-vector (list->vector small-17-list))
  (define small-18-vector (list->vector small-18-list))
  (define small-32-vector (list->vector small-32-list))
  (define small-64-vector (list->vector small-64-list))
  (define base-list-reverse (reverse base-list))
  (define base-vector-reverse (list->vector base-list-reverse))
  (define base-treelist-reverse (treelist-reverse base-treelist))
  (define half (quotient n 2))
  (define quarter (quotient n 4))
  (define three-quarter (- n quarter))
  (define shift-amount (min 3 n))
  (define eighth (quotient n 8))
  (define left-subvector-start eighth)
  (define left-subvector-end (min n (+ left-subvector-start half)))
  (define right-subvector-end (- n eighth))
  (define right-subvector-start (max 0 (- right-subvector-end half)))
  (define wide-subvector-start eighth)
  (define wide-subvector-end (max wide-subvector-start (- n eighth)))
  (define narrow-subvector-len (max 1 (quotient n 10)))
  (define narrow-subvector-start (quotient (- n narrow-subvector-len) 2))
  (define narrow-subvector-end (+ narrow-subvector-start narrow-subvector-len))
  (define small-subvector-start
    (if (>= n 256) (+ half 17) 0))
  (define small-2chunk-subvector-len (min (- n small-subvector-start) 96))
  (define small-2chunk-subvector-end
    (+ small-subvector-start small-2chunk-subvector-len))
  (define small-3chunk-subvector-len (min (- n small-subvector-start) 128))
  (define small-3chunk-subvector-end
    (+ small-subvector-start small-3chunk-subvector-len))
  (define large-aligned-copy-start
    (* 64 (quotient quarter 64)))
  (define large-copy-len
    (min 8192 (max 0 (- n large-aligned-copy-start))))
  (define large-aligned-copy-end
    (+ large-aligned-copy-start large-copy-len))
  (define large-unaligned-copy-start
    (min n (+ large-aligned-copy-start 4)))
  (define large-unaligned-copy-len
    (min 8192 (max 0 (- n large-unaligned-copy-start))))
  (define large-unaligned-copy-end
    (+ large-unaligned-copy-start large-unaligned-copy-len))
  (define left-list (take base-list half))
  (define right-list (drop base-list half))
  (define left-vector (vector-copy base-vector 0 half))
  (define right-vector (vector-copy base-vector half n))
  (define left-treelist (treelist-take base-treelist half))
  (define right-treelist (treelist-drop base-treelist half))
  (define left-cutie-pvector
    (and cutie-enabled? (cutie:pvector-take base-cutie-pvector half)))
  (define right-cutie-pvector
    (and cutie-enabled? (cutie:pvector-drop base-cutie-pvector half)))
  (define left-raw-pvector (raw:pvector-take base-raw-pvector half))
  (define right-raw-pvector (raw:pvector-drop base-raw-pvector half))
  (define left-pvector (pvector-take base-pvector half))
  (define right-pvector (pvector-drop base-pvector half))
  (define take-right-half-pvector (pvector-take-right base-pvector half))
  (define drop-right-half-pvector (pvector-drop-right base-pvector half))
  (define-values (split-left-pvector split-right-pvector)
    (pvector-split-at base-pvector half))
  (define split-value-index
    (max 0 (sub1 half)))
  (define-values (split-value-left-pvector split-value split-value-right-pvector)
    (pvector-split base-pvector split-value-index))
  (define consed-right-pvector
    (and (or (enabled? ops 'for-each-sum-consed)
             (enabled? ops 'for-each-void-consed)
             (enabled? ops 'iterate-consed)
             (enabled? ops 'iterate-proc-consed)
             (enabled? ops 'iterate-sequence-consed)
             (enabled? ops 'iterate-reverse-consed)
             (enabled? ops 'iterate-reverse-proc-consed)
             (enabled? ops 'hash-consed-repeated)
             (enabled? ops 'equal-consed-separate-build)
             (enabled? ops 'equal-consed-same-shape)
             (enabled? ops 'stream-for-each-sum-consed)
             (enabled? ops 'stream-for-each-void-consed)
             (enabled? ops 'stream-add-between-consed)
             (enabled? ops 'stream-add-between-list-consed)
             (enabled? ops 'stream-filter-values-all-consed-list)
             (enabled? ops 'stream-filter-values-all-consed)
	             (enabled? ops 'stream-map-values-list-consed)
	             (enabled? ops 'stream-map-void-list-consed)
	             (enabled? ops 'stream-map-add1-list-consed)
	             (enabled? ops 'stream-map-add1-length-consed)
	             (enabled? ops 'stream-map-add1-ref-consed)
	             (enabled? ops 'stream-map-add1-tail-list-consed)
	             (enabled? ops 'stream-map-add1-take-list-consed)
	             (enabled? ops 'stream-map-add1-count-even-consed)
	             (enabled? ops 'stream-map-add1-fold-sum-consed)
	             (enabled? ops 'stream-map-add1-for-each-sum-consed)
	             (enabled? ops 'stream-map-add1-andmap-positive-consed)
	             (enabled? ops 'stream-map-add1-ormap-last-consed)
	             (enabled? ops 'stream-filter-even-list-consed)
	             (enabled? ops 'stream-filter-even-length-consed)
	             (enabled? ops 'stream-filter-even-ref-consed)
	             (enabled? ops 'stream-filter-even-tail-list-consed)
	             (enabled? ops 'stream-filter-even-take-list-consed)
	             (enabled? ops 'stream-filter-even-count-values-consed)
	             (enabled? ops 'stream-filter-even-take-count-values-consed)
	             (enabled? ops 'stream-filter-even-fold-sum-consed)
	             (enabled? ops 'stream-filter-even-take-fold-sum-consed)
	             (enabled? ops 'stream-filter-even-for-each-sum-consed)
	             (enabled? ops 'stream-filter-even-take-for-each-sum-consed)
	             (enabled? ops 'stream-filter-even-andmap-even-consed)
	             (enabled? ops 'stream-filter-even-ormap-last-consed)
	             (enabled? ops 'stream-filter-even-take-andmap-even-consed)
	             (enabled? ops 'stream-append-list-consed-list)
	             (enabled? ops 'stream-append-length-consed-list)
	             (enabled? ops 'stream-append-ref-consed-list)
	             (enabled? ops 'stream-append-tail-list-consed-list)
	             (enabled? ops 'stream-append-take-list-consed-list)
	             (enabled? ops 'stream-append-count-even-consed-list)
	             (enabled? ops 'stream-append-fold-sum-consed-list)
	             (enabled? ops 'stream-append-for-each-sum-consed-list)
	             (enabled? ops 'stream-append-andmap-integer-consed-list)
	             (enabled? ops 'stream-append-ormap-last-consed-list))
	         (for/fold ([pv (pvector-empty)]) ([i (in-range n)])
	           (pvector-cons-right pv i))))
  (define consed-right-pvector*
    (and (enabled? ops 'equal-consed-same-shape)
         (for/fold ([pv (pvector-empty)]) ([i (in-range n)])
           (pvector-cons-right pv i))))
  (define consed-filter-pvector
    (and (or (enabled? ops 'stream-filter-values-alt-consed-list)
             (enabled? ops 'stream-filter-values-alt-consed))
         (for/fold ([pv (pvector-empty)]) ([v (in-list base-filter-list)])
           (pvector-cons-right pv v))))
  (define large-aligned-copy-pvector
    (pvector-subvector base-pvector
                       large-aligned-copy-start
                       large-aligned-copy-end))
  (define large-unaligned-copy-pvector
    (pvector-subvector base-pvector
                       large-unaligned-copy-start
                       large-unaligned-copy-end))
  (define prefix-subvector-pvector
    (pvector-subvector base-pvector 0 half))
  (define suffix-subvector-pvector
    (pvector-subvector base-pvector half n))
  (define unsafe-prefix-subvector-pvector
    (unsafe:unsafe-pvector-subvector base-pvector 0 half))
  (define unsafe-suffix-subvector-pvector
    (unsafe:unsafe-pvector-subvector base-pvector half n))
  (define appended-halves-pvector (pvector-append left-pvector right-pvector))
  (define left-cached-pvector (list->pvector left-list))
  (define right-cached-pvector (list->pvector right-list))
  (define appended-cached-halves-pvector
    (pvector-append left-cached-pvector right-cached-pvector))
	  (define shifted-pvector (pvector-drop base-pvector shift-amount))
	  (define same-list-pvector (list->pvector base-list))
	  (define set-same-pvector (pvector-set base-pvector half half))
	  (define set-different-pvector (pvector-set base-pvector half 'different))
	  (define set-middle-ref-pvector (pvector-set base-pvector half -1))
	  (define unsafe-set-middle-ref-pvector
	    (unsafe:unsafe-pvector-set base-pvector half -1))
	  (define cons-left-ref-pvector (pvector-cons-left base-pvector -1))
	  (define unsafe-cons-left-ref-pvector
	    (unsafe:unsafe-pvector-cons-left base-pvector -1))
	  (define-values (pop-left-ref-value pop-left-ref-pvector)
	    (pvector-pop-left base-pvector))
	  (define-values (unsafe-pop-left-ref-value unsafe-pop-left-ref-pvector)
	    (unsafe:unsafe-pvector-pop-left base-pvector))
	  (define insert-right-ref-pvector (pvector-insert base-pvector n -1))
	  (define unsafe-insert-right-ref-pvector
	    (unsafe:unsafe-pvector-insert base-pvector n -1))
  (define-values (delete-right-ref-pvector delete-right-ref-value)
    (pvector-delete base-pvector (sub1 n)))
  (define-values (unsafe-delete-right-ref-pvector unsafe-delete-right-ref-value)
    (unsafe:unsafe-pvector-delete base-pvector (sub1 n)))
  (define inserted-middle-pvector (pvector-insert base-pvector half 'inserted))
  (define (boundary-inserted-pvector base)
    (for/fold ([pv base] [shift 0] #:result pv)
              ([pos (in-range 64 n 64)])
      (values (pvector-insert pv (+ pos shift) 'inserted)
              (add1 shift))))
  (define base-boundary-inserted-pvector
    (and (>= n 128)
         (boundary-inserted-pvector base-pvector)))

  (bench 'build-native 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (build-list-data n))))
  (bench 'build-native 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (build-vector-data n))))
  (bench 'build-native 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (for/treelist ([i (in-range n)]) i))))
  (bench 'build-native 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv (cutie:pvector-empty)]) ([i (in-range n)])
               (cutie:pvector-cons-right pv i)))))
  (bench 'build-native 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector ([i (in-range n)]) i))))
  (bench 'for-range-constant 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector ([i (in-range n)]) builder-constant-value))))
  (bench 'for-range-constant 'adapter-pvector
         (lambda ()
           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
             (adapter:for/pvector ([i (in-range n)])
               builder-constant-value))))
  (bench 'for-range-constant->vector 'pvector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (pvector->vector
              (for/pvector ([i (in-range n)])
                builder-constant-value)))))
  (bench 'for-range-constant->vector 'adapter-pvector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (adapter:pvector->vector
              (adapter:for/pvector ([i (in-range n)])
                builder-constant-value)))))
  (bench 'for-range-constant->list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (pvector->list
              (for/pvector ([i (in-range n)])
                builder-constant-value)))))
  (bench 'for-range-constant->list 'adapter-pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (adapter:pvector->list
              (adapter:for/pvector ([i (in-range n)])
                builder-constant-value)))))
  (bench 'for-range-square 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector ([i (in-range n)]) (* i i)))))
  (bench 'for*-range-constant 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector ([i (in-range n)]) builder-constant-value))))
  (bench 'for*-range-constant 'adapter-pvector
         (lambda ()
           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
             (adapter:for*/pvector ([i (in-range n)])
               builder-constant-value))))
  (bench 'for-range-length-constant 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector #:length n ([i (in-range n)])
               builder-constant-value))))
  (bench 'for-range-length-constant 'adapter-pvector
         (lambda ()
           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
             (adapter:for/pvector #:length n ([i (in-range n)])
               builder-constant-value))))
  (bench 'for-range-length-constant->vector 'pvector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (pvector->vector
              (for/pvector #:length n ([i (in-range n)])
                builder-constant-value)))))
  (bench 'for-range-length-constant->vector 'adapter-pvector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (adapter:pvector->vector
              (adapter:for/pvector #:length n ([i (in-range n)])
                builder-constant-value)))))
  (bench 'for-range-length-square 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector #:length n ([i (in-range n)]) (* i i)))))
  (bench 'for-in-list-identity 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector ([i (in-list base-list)]) i))))
  (bench 'for-in-vector-identity 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector ([i (in-vector base-vector)]) i))))
  (bench 'for-in-pvector-identity 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector ([i (in-pvector base-pvector)]) i))))
  (bench 'for-bare-pvector-identity 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector ([i base-pvector]) i))))
  (bench 'for-in-pvector-reverse->seq 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector ([i (in-pvector-reverse base-pvector)]) i))))
  (bench 'for-length-in-pvector-identity 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector #:length n ([i (in-pvector base-pvector)]) i))))
  (bench 'for-length-bare-pvector-identity 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector #:length n ([i base-pvector]) i))))
  (bench 'for-length-in-vector-identity 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector #:length n ([i (in-vector base-vector)]) i))))
  (bench 'for-length-bare-vector-identity 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector #:length n ([i base-vector]) i))))
  (bench 'for*-in-list-identity 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector ([i (in-list base-list)]) i))))
  (bench 'for*-in-vector-identity 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector ([i (in-vector base-vector)]) i))))
  (bench 'for*-in-pvector-identity 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector ([i (in-pvector base-pvector)]) i))))
  (bench 'for*-bare-pvector-identity 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector ([i base-pvector]) i))))
  (bench 'for*-in-pvector-reverse->seq 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector ([i (in-pvector-reverse base-pvector)]) i))))
  (bench 'for*-length-in-pvector-identity 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector #:length n ([i (in-pvector base-pvector)]) i))))
  (bench 'for*-length-bare-pvector-identity 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector #:length n ([i base-pvector]) i))))
  (bench 'for*-length-in-vector-identity 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector #:length n ([i (in-vector base-vector)]) i))))
  (bench 'for*-length-bare-vector-identity 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector #:length n ([i base-vector]) i))))
  (bench 'build-native 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv (pvector-empty)]) ([i (in-range n)])
               (unsafe:unsafe-pvector-cons-right pv i)))))

  (bench 'build-native-length 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector #:length n ([i (in-range n)]) i))))
  (bench 'for-range-length-literal-8 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector #:length 8 ([i (in-range 8)]) i))))
  (bench 'for-range-length-literal-17 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector #:length 17 ([i (in-range 17)]) i))))
  (bench 'for-range-length-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector #:length 64 ([i (in-range 64)]) i))))
  (bench 'for-range-length-start1-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector #:length 64 ([i (in-range 1 65)]) i))))
  (bench 'for-range-length-step2-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector #:length 64 ([i (in-range 0 128 2)]) i))))
  (bench 'for-range-length-neg-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector #:length 64 ([i (in-range 64 0 -1)]) i))))
  (bench 'for-range-length-id-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (let ([len 64])
               (for/pvector #:length len ([i (in-range len)]) i)))))
  (bench 'for-range-length-start0-id 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector #:length n ([i (in-range 0 n)]) i))))
  (bench 'for-range-length-start0-step1-id 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector #:length n ([i (in-range 0 n 1)]) i))))
  (bench 'for*-range-length-start0-id 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector #:length n ([i (in-range 0 n)]) i))))
  (bench 'for*-range-length-start0-step1-id 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector #:length n ([i (in-range 0 n 1)]) i))))
  (bench 'for-range-length-square-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector #:length 64 ([i (in-range 64)]) (* i i)))))
  (bench 'for-range-length-fill-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector #:length 64 #:fill 'missing
                          ([i (in-range 32)])
                          i))))
  (bench 'for*-range-length-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector #:length 64 ([i (in-range 64)]) i))))
  (bench 'for*-range-length-start1-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector #:length 64 ([i (in-range 1 65)]) i))))
  (bench 'for*-range-length-step2-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector #:length 64 ([i (in-range 0 128 2)]) i))))
  (bench 'for*-range-length-neg-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector #:length 64 ([i (in-range 64 0 -1)]) i))))
  (bench 'for*-range-length-id-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (let ([len 64])
               (for*/pvector #:length len ([i (in-range len)]) i)))))
  (bench 'for*-range-length-square-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector #:length 64 ([i (in-range 64)]) (* i i)))))
  (bench 'for*-range-length-fill-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector #:length 64 #:fill 'missing
                           ([i (in-range 32)])
                           i))))
  (bench 'for-range-literal-8 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector ([i (in-range 8)]) i))))
  (bench 'for-range-literal-17 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector ([i (in-range 17)]) i))))
  (bench 'for-range-literal-18 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector ([i (in-range 18)]) i))))
  (bench 'for-range-literal-32 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector ([i (in-range 32)]) i))))
  (bench 'for-range-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector ([i (in-range 64)]) i))))
  (bench 'for-range-square-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector ([i (in-range 64)]) (* i i)))))
  (bench 'for-range-start1-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector ([i (in-range 1 65)]) i))))
  (bench 'for-range-step2-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector ([i (in-range 0 128 2)]) i))))
  (bench 'for-range-neg-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector ([i (in-range 64 0 -1)]) i))))
  (bench 'for*-range-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector ([i (in-range 64)]) i))))
  (bench 'for*-range-square-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector ([i (in-range 64)]) (* i i)))))
  (bench 'for*-range-start1-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector ([i (in-range 1 65)]) i))))
  (bench 'for*-range-step2-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector ([i (in-range 0 128 2)]) i))))
  (bench 'for*-range-neg-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for*/pvector ([i (in-range 64 0 -1)]) i))))
  (bench 'sequence-integer-literal-18 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector 18))))
  (bench 'sequence-integer-literal-32 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector 32))))
  (bench 'sequence-integer-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector 64))))
  (bench 'sequence-range-literal-18 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector (in-range 18)))))
  (bench 'sequence-range-literal-32 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector (in-range 32)))))
  (bench 'sequence-range-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector (in-range 64)))))
  (bench 'sequence-range-start1-literal-18 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector (in-range 1 19)))))
  (bench 'sequence-range-start1-literal-32 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector (in-range 1 33)))))
  (bench 'sequence-range-start1-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector (in-range 1 65)))))
  (bench 'sequence-range-step2-literal-18 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector (in-range 0 36 2)))))
  (bench 'sequence-range-step2-literal-32 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector (in-range 0 64 2)))))
  (bench 'sequence-range-step2-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector (in-range 0 128 2)))))
  (bench 'sequence-range-neg-literal-18 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector (in-range 18 0 -1)))))
  (bench 'sequence-range-neg-literal-32 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector (in-range 32 0 -1)))))
  (bench 'sequence-range-neg-literal-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector (in-range 64 0 -1)))))

  (bench 'construct-17 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (list 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16))))
  (bench 'construct-17 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (vector 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16))))
  (bench 'construct-17 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (list->treelist small-17-list))))
  (bench 'construct-17 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (cutie:pvector 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16))))
  (bench 'construct-17 'raw-pvector
         (lambda ()
           (for/fold ([r (raw:pvector-empty)]) ([j (in-range m)])
             (raw:pvector 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16))))
  (bench 'construct-17 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16))))
  (bench 'construct-18 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17))))
  (bench 'construct-32 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector 0 1 2 3 4 5 6 7
                      8 9 10 11 12 13 14 15
                      16 17 18 19 20 21 22 23
                      24 25 26 27 28 29 30 31))))
  (bench 'construct-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector 0 1 2 3 4 5 6 7
                      8 9 10 11 12 13 14 15
                      16 17 18 19 20 21 22 23
                      24 25 26 27 28 29 30 31
                      32 33 34 35 36 37 38 39
                      40 41 42 43 44 45 46 47
                      48 49 50 51 52 53 54 55
                      56 57 58 59 60 61 62 63))))
  (bench 'construct-65 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector 0 1 2 3 4 5 6 7
                      8 9 10 11 12 13 14 15
                      16 17 18 19 20 21 22 23
                      24 25 26 27 28 29 30 31
                      32 33 34 35 36 37 38 39
                      40 41 42 43 44 45 46 47
                      48 49 50 51 52 53 54 55
                      56 57 58 59 60 61 62 63
                      64))))
  (bench 'apply-18 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (apply pvector small-18-list))))
  (bench 'apply-32 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (apply pvector small-32-list))))
  (bench 'apply-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (apply pvector small-64-list))))
  (bench 'apply-65 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (apply pvector small-65-list))))
  (bench 'apply-96 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (apply pvector small-96-list))))
  (bench 'apply-112 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (apply pvector small-112-list))))
  (bench 'apply-128 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (apply pvector small-128-list))))
  (bench 'make-singleton 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (make-pvector 1 j))))
  (bench 'make-singleton 'adapter-pvector
         (lambda ()
           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
             (adapter:make-pvector 1 j))))
  (bench 'make-small-8 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (make-pvector 8 j))))
  (bench 'make-small-8 'adapter-pvector
         (lambda ()
           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
             (adapter:make-pvector 8 j))))
  (bench 'make-small-16 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (make-pvector 16 j))))
  (bench 'make-small-16 'adapter-pvector
         (lambda ()
           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
             (adapter:make-pvector 16 j))))
  (bench 'make-small-17 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (make-pvector 17 j))))
  (bench 'make-small-17 'adapter-pvector
         (lambda ()
           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
             (adapter:make-pvector 17 j))))
  (bench 'make-small-18 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (make-pvector 18 j))))
  (bench 'make-small-18 'adapter-pvector
         (lambda ()
           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
             (adapter:make-pvector 18 j))))
  (bench 'make-small-32 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (make-pvector 32 j))))
  (bench 'make-small-32 'adapter-pvector
         (lambda ()
           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
             (adapter:make-pvector 32 j))))
  (bench 'make-small-64 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (make-pvector 64 j))))
  (bench 'make-small-64 'adapter-pvector
         (lambda ()
           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
             (adapter:make-pvector 64 j))))
  (bench 'make-small-65 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (make-pvector 65 j))))
  (bench 'make-small-65 'adapter-pvector
         (lambda ()
           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
             (adapter:make-pvector 65 j))))
  (bench 'make-large 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (make-pvector n j))))
  (bench 'make-large 'adapter-pvector
         (lambda ()
           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
             (adapter:make-pvector n j))))
  (bench 'make-large->vector 'pvector
         (lambda ()
           (define pv (make-pvector n (void)))
           (for/fold ([r #()]) ([j (in-range m)])
             (pvector->vector pv))))
  (bench 'make-large->vector 'adapter-pvector
         (lambda ()
           (define pv (adapter:make-pvector n (void)))
           (for/fold ([r #()]) ([j (in-range m)])
             (adapter:pvector->vector pv))))
  (bench 'make-large->list 'pvector
         (lambda ()
           (define pv (make-pvector n (void)))
           (for/fold ([r null]) ([j (in-range m)])
             (pvector->list pv))))
  (bench 'make-large->list 'adapter-pvector
         (lambda ()
           (define pv (adapter:make-pvector n (void)))
           (for/fold ([r null]) ([j (in-range m)])
             (adapter:pvector->list pv))))
  (bench 'shared-subvector->vector 'pvector
         (lambda ()
           (define pv (make-pvector n (void)))
           (for/fold ([r #()]) ([j (in-range m)])
             (pvector->vector (pvector-subvector pv quarter three-quarter)))))
  (bench 'shared-subvector->vector 'adapter-pvector
         (lambda ()
           (define pv (adapter:make-pvector n (void)))
           (for/fold ([r #()]) ([j (in-range m)])
             (adapter:pvector->vector
              (adapter:pvector-copy pv quarter three-quarter)))))
  (bench 'shared-subvector->list 'pvector
         (lambda ()
           (define pv (make-pvector n (void)))
           (for/fold ([r null]) ([j (in-range m)])
             (pvector->list (pvector-subvector pv quarter three-quarter)))))
  (bench 'shared-subvector->list 'adapter-pvector
         (lambda ()
           (define pv (adapter:make-pvector n (void)))
           (for/fold ([r null]) ([j (in-range m)])
             (adapter:pvector->list
              (adapter:pvector-copy pv quarter three-quarter)))))
  (bench 'shared-prefix->vector 'pvector
         (lambda ()
           (define pv (make-pvector n (void)))
           (for/fold ([r #()]) ([j (in-range m)])
             (pvector->vector (pvector-subvector pv 0 half)))))
  (bench 'shared-prefix->vector 'adapter-pvector
         (lambda ()
           (define pv (adapter:make-pvector n (void)))
           (for/fold ([r #()]) ([j (in-range m)])
             (adapter:pvector->vector (adapter:pvector-take pv half)))))
  (bench 'shared-suffix->vector 'pvector
         (lambda ()
           (define pv (make-pvector n (void)))
           (for/fold ([r #()]) ([j (in-range m)])
             (pvector->vector (pvector-subvector pv half n)))))
  (bench 'shared-suffix->vector 'adapter-pvector
         (lambda ()
           (define pv (adapter:make-pvector n (void)))
           (for/fold ([r #()]) ([j (in-range m)])
             (adapter:pvector->vector (adapter:pvector-drop pv half)))))
  (bench 'shared-prefix->list 'pvector
         (lambda ()
           (define pv (make-pvector n (void)))
           (for/fold ([r null]) ([j (in-range m)])
             (pvector->list (pvector-subvector pv 0 half)))))
  (bench 'shared-prefix->list 'adapter-pvector
         (lambda ()
           (define pv (adapter:make-pvector n (void)))
           (for/fold ([r null]) ([j (in-range m)])
             (adapter:pvector->list (adapter:pvector-take pv half)))))
  (bench 'shared-suffix->list 'pvector
         (lambda ()
           (define pv (make-pvector n (void)))
           (for/fold ([r null]) ([j (in-range m)])
             (pvector->list (pvector-subvector pv half n)))))
  (bench 'shared-suffix->list 'adapter-pvector
         (lambda ()
           (define pv (adapter:make-pvector n (void)))
           (for/fold ([r null]) ([j (in-range m)])
             (adapter:pvector->list (adapter:pvector-drop pv half)))))
  (bench 'shared-append->vector 'pvector
         (lambda ()
           (define value (box 'shared))
           (define left (make-pvector half value))
           (define right (make-pvector (- n half) value))
           (for/fold ([r #()]) ([j (in-range m)])
             (pvector->vector (pvector-append left right)))))
  (bench 'shared-append->vector 'adapter-pvector
         (lambda ()
           (define value (box 'shared))
           (define left (adapter:make-pvector half value))
           (define right (adapter:make-pvector (- n half) value))
           (for/fold ([r #()]) ([j (in-range m)])
             (adapter:pvector->vector (adapter:pvector-append left right)))))
  (bench 'shared-append->list 'pvector
         (lambda ()
           (define value (box 'shared))
           (define left (make-pvector half value))
           (define right (make-pvector (- n half) value))
           (for/fold ([r null]) ([j (in-range m)])
             (pvector->list (pvector-append left right)))))
  (bench 'shared-append->list 'adapter-pvector
         (lambda ()
           (define value (box 'shared))
           (define left (adapter:make-pvector half value))
           (define right (adapter:make-pvector (- n half) value))
           (for/fold ([r null]) ([j (in-range m)])
             (adapter:pvector->list (adapter:pvector-append left right)))))
  (bench 'shared-cons-left->vector 'pvector
         (lambda ()
           (define value (box 'shared))
           (define pv (make-pvector n value))
           (for/fold ([r #()]) ([j (in-range m)])
             (pvector->vector (pvector-cons-left pv value)))))
  (bench 'shared-cons-left->vector 'adapter-pvector
         (lambda ()
           (define value (box 'shared))
           (define pv (adapter:make-pvector n value))
           (for/fold ([r #()]) ([j (in-range m)])
             (adapter:pvector->vector (adapter:pvector-cons-left pv value)))))
  (bench 'shared-cons-right->vector 'pvector
         (lambda ()
           (define value (box 'shared))
           (define pv (make-pvector n value))
           (for/fold ([r #()]) ([j (in-range m)])
             (pvector->vector (pvector-cons-right pv value)))))
  (bench 'shared-cons-right->vector 'adapter-pvector
         (lambda ()
           (define value (box 'shared))
           (define pv (adapter:make-pvector n value))
           (for/fold ([r #()]) ([j (in-range m)])
             (adapter:pvector->vector (adapter:pvector-cons-right pv value)))))
  (bench 'shared-pop-left->vector 'pvector
         (lambda ()
           (define pv (make-pvector n (void)))
           (for/fold ([r #()]) ([j (in-range m)])
             (let-values ([(value rest) (pvector-pop-left pv)])
               (pvector->vector rest)))))
  (bench 'shared-pop-left->vector 'adapter-pvector
         (lambda ()
           (define pv (adapter:make-pvector n (void)))
           (for/fold ([r #()]) ([j (in-range m)])
             (let-values ([(value rest) (adapter:pvector-pop-left pv)])
               (adapter:pvector->vector rest)))))
  (bench 'shared-pop-right->vector 'pvector
         (lambda ()
           (define pv (make-pvector n (void)))
           (for/fold ([r #()]) ([j (in-range m)])
             (let-values ([(value rest) (pvector-pop-right pv)])
               (pvector->vector rest)))))
  (bench 'shared-pop-right->vector 'adapter-pvector
         (lambda ()
           (define pv (adapter:make-pvector n (void)))
           (for/fold ([r #()]) ([j (in-range m)])
             (let-values ([(value rest) (adapter:pvector-pop-right pv)])
               (adapter:pvector->vector rest)))))
  (bench 'shared-cons-left->list 'pvector
         (lambda ()
           (define value (box 'shared))
           (define pv (make-pvector n value))
           (for/fold ([r null]) ([j (in-range m)])
             (pvector->list (pvector-cons-left pv value)))))
  (bench 'shared-cons-left->list 'adapter-pvector
         (lambda ()
           (define value (box 'shared))
           (define pv (adapter:make-pvector n value))
           (for/fold ([r null]) ([j (in-range m)])
             (adapter:pvector->list (adapter:pvector-cons-left pv value)))))
  (bench 'shared-pop-left->list 'pvector
         (lambda ()
           (define pv (make-pvector n (void)))
           (for/fold ([r null]) ([j (in-range m)])
             (let-values ([(value rest) (pvector-pop-left pv)])
               (pvector->list rest)))))
  (bench 'shared-pop-left->list 'adapter-pvector
         (lambda ()
           (define pv (adapter:make-pvector n (void)))
           (for/fold ([r null]) ([j (in-range m)])
             (let-values ([(value rest) (adapter:pvector-pop-left pv)])
               (adapter:pvector->list rest)))))
  (bench 'shared-map-identity-lambda->vector 'pvector
         (lambda ()
           (define value (box 'shared))
           (define pv (make-pvector n value))
           (for/fold ([r #()]) ([j (in-range m)])
             (pvector->vector (pvector-map pv (lambda (elem) elem))))))
  (bench 'shared-map-identity-lambda->vector 'adapter-pvector
         (lambda ()
           (define value (box 'shared))
           (define pv (adapter:make-pvector n value))
           (for/fold ([r #()]) ([j (in-range m)])
             (adapter:pvector->vector
              (adapter:pvector-map pv (lambda (elem) elem))))))
  (bench 'shared-map-identity-lambda->list 'pvector
         (lambda ()
           (define value (box 'shared))
           (define pv (make-pvector n value))
           (for/fold ([r null]) ([j (in-range m)])
             (pvector->list (pvector-map pv (lambda (elem) elem))))))
  (bench 'shared-map-identity-lambda->list 'adapter-pvector
         (lambda ()
           (define value (box 'shared))
           (define pv (adapter:make-pvector n value))
           (for/fold ([r null]) ([j (in-range m)])
             (adapter:pvector->list
              (adapter:pvector-map pv (lambda (elem) elem))))))
  (bench 'shared-map-constant->vector 'pvector
         (lambda ()
           (define value (box 'shared))
           (define const-value (box 'const))
           (define pv (make-pvector n value))
           (for/fold ([r #()]) ([j (in-range m)])
             (pvector->vector
              (pvector-map pv (lambda (elem) const-value))))))
  (bench 'shared-map-constant->vector 'adapter-pvector
         (lambda ()
           (define value (box 'shared))
           (define const-value (box 'const))
           (define pv (adapter:make-pvector n value))
           (for/fold ([r #()]) ([j (in-range m)])
             (adapter:pvector->vector
              (adapter:pvector-map pv (lambda (elem) const-value))))))
  (bench 'shared-map-nonuniform->vector 'pvector
         (lambda ()
           (define value (box 'shared))
           (define pv (make-pvector n value))
           (for/fold ([r #()]) ([j (in-range m)])
             (let ([count 0])
               (pvector->vector
                (pvector-map pv
                             (lambda (elem)
                               (set! count (add1 count))
                               (if (= count half) 'other elem))))))))
  (bench 'shared-map-nonuniform->vector 'adapter-pvector
         (lambda ()
           (define value (box 'shared))
           (define pv (adapter:make-pvector n value))
           (for/fold ([r #()]) ([j (in-range m)])
             (let ([count 0])
               (adapter:pvector->vector
                (adapter:pvector-map pv
                                     (lambda (elem)
                                       (set! count (add1 count))
                                       (if (= count half) 'other elem))))))))
  (bench 'shared-insert-middle-same->vector 'pvector
         (lambda ()
           (define value (box 'shared))
           (define pv (make-pvector n value))
           (for/fold ([r #()]) ([j (in-range m)])
             (pvector->vector (pvector-insert pv half value)))))
  (bench 'shared-insert-middle-same->vector 'adapter-pvector
         (lambda ()
           (define value (box 'shared))
           (define pv (adapter:make-pvector n value))
           (for/fold ([r #()]) ([j (in-range m)])
             (adapter:pvector->vector (adapter:pvector-insert pv half value)))))
  (bench 'shared-insert-middle-same->list 'pvector
         (lambda ()
           (define value (box 'shared))
           (define pv (make-pvector n value))
           (for/fold ([r null]) ([j (in-range m)])
             (pvector->list (pvector-insert pv half value)))))
  (bench 'shared-insert-middle-same->list 'adapter-pvector
         (lambda ()
           (define value (box 'shared))
           (define pv (adapter:make-pvector n value))
           (for/fold ([r null]) ([j (in-range m)])
             (adapter:pvector->list (adapter:pvector-insert pv half value)))))
  (bench 'shared-delete-middle->vector 'pvector
         (lambda ()
           (define pv (make-pvector n (void)))
           (for/fold ([r #()]) ([j (in-range m)])
             (let-values ([(rest value) (pvector-delete pv half)])
               (pvector->vector rest)))))
  (bench 'shared-delete-middle->vector 'adapter-pvector
         (lambda ()
           (define pv (adapter:make-pvector n (void)))
           (for/fold ([r #()]) ([j (in-range m)])
             (let-values ([(rest value) (adapter:pvector-delete pv half)])
               (adapter:pvector->vector rest)))))
  (bench 'shared-delete-middle->list 'pvector
         (lambda ()
           (define pv (make-pvector n (void)))
           (for/fold ([r null]) ([j (in-range m)])
             (let-values ([(rest value) (pvector-delete pv half)])
               (pvector->list rest)))))
  (bench 'shared-delete-middle->list 'adapter-pvector
         (lambda ()
           (define pv (adapter:make-pvector n (void)))
           (for/fold ([r null]) ([j (in-range m)])
             (let-values ([(rest value) (adapter:pvector-delete pv half)])
               (adapter:pvector->list rest)))))
  (bench 'shared-split-left->vector 'pvector
         (lambda ()
           (define pv (make-pvector n (void)))
           (for/fold ([r #()]) ([j (in-range m)])
             (let-values ([(left right) (pvector-split-at pv half)])
               (pvector->vector left)))))
  (bench 'shared-split-left->vector 'adapter-pvector
         (lambda ()
           (define pv (adapter:make-pvector n (void)))
           (for/fold ([r #()]) ([j (in-range m)])
             (let-values ([(left right) (adapter:pvector-split-at pv half)])
               (adapter:pvector->vector left)))))
  (bench 'shared-split-right->vector 'pvector
         (lambda ()
           (define pv (make-pvector n (void)))
           (for/fold ([r #()]) ([j (in-range m)])
             (let-values ([(left right) (pvector-split-at pv half)])
               (pvector->vector right)))))
  (bench 'shared-split-right->vector 'adapter-pvector
         (lambda ()
           (define pv (adapter:make-pvector n (void)))
           (for/fold ([r #()]) ([j (in-range m)])
             (let-values ([(left right) (adapter:pvector-split-at pv half)])
               (adapter:pvector->vector right)))))
  (bench 'shared-split-left->list 'pvector
         (lambda ()
           (define pv (make-pvector n (void)))
           (for/fold ([r null]) ([j (in-range m)])
             (let-values ([(left right) (pvector-split-at pv half)])
               (pvector->list left)))))
  (bench 'shared-split-left->list 'adapter-pvector
         (lambda ()
           (define pv (adapter:make-pvector n (void)))
           (for/fold ([r null]) ([j (in-range m)])
             (let-values ([(left right) (adapter:pvector-split-at pv half)])
               (adapter:pvector->list left)))))
  (bench 'list-empty->pvector 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (list->pvector null))))
  (bench 'list-singleton->pvector 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (list->pvector singleton-list))))
  (bench 'list-small-8->pvector 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (list->pvector small-8-list))))
  (bench 'list-small-16->pvector 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (list->pvector small-16-list))))
  (bench 'list-small-17->pvector 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (list->pvector small-17-list))))
  (bench 'list-small-18->pvector 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (list->pvector small-18-list))))
	  (bench 'list-small-32->pvector 'pvector
	         (lambda ()
	           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
	             (list->pvector small-32-list))))
	  (bench 'uniform-list->pvector 'pvector
	         (lambda ()
	           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
	             (list->pvector base-uniform-list))))
	  (bench 'uniform-list->pvector 'adapter-pvector
	         (lambda ()
	           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
	             (adapter:list->pvector base-uniform-list))))
	  (bench 'uniform-list->pvector->vector 'pvector
	         (lambda ()
	           (for/fold ([r #()]) ([j (in-range m)])
	             (pvector->vector (list->pvector base-uniform-list)))))
	  (bench 'uniform-list->pvector->vector 'adapter-pvector
	         (lambda ()
	           (for/fold ([r #()]) ([j (in-range m)])
	             (adapter:pvector->vector
	              (adapter:list->pvector base-uniform-list)))))
	  (bench 'uniform-list->pvector->list 'pvector
	         (lambda ()
	           (for/fold ([r null]) ([j (in-range m)])
	             (pvector->list (list->pvector base-uniform-list)))))
	  (bench 'uniform-list->pvector->list 'adapter-pvector
	         (lambda ()
	           (for/fold ([r null]) ([j (in-range m)])
	             (adapter:pvector->list
	              (adapter:list->pvector base-uniform-list)))))
	  (bench 'varied-list->pvector 'pvector
	         (lambda ()
	           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
	             (list->pvector base-list))))
	  (bench 'varied-list->pvector 'adapter-pvector
	         (lambda ()
	           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
	             (adapter:list->pvector base-list))))
  (bench 'uniform-vector->pvector 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (vector->pvector base-uniform-vector))))
  (bench 'uniform-vector->pvector 'adapter-pvector
         (lambda ()
           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
             (adapter:vector->pvector base-uniform-vector))))
  (bench 'uniform-vector->pvector->vector 'pvector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (pvector->vector (vector->pvector base-uniform-vector)))))
  (bench 'uniform-vector->pvector->vector 'adapter-pvector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (adapter:pvector->vector
              (adapter:vector->pvector base-uniform-vector)))))
  (bench 'varied-vector->pvector 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (vector->pvector base-vector))))
  (bench 'varied-vector->pvector 'adapter-pvector
         (lambda ()
           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
             (adapter:vector->pvector base-vector))))
	  (bench 'vector-empty->pvector 'pvector
	         (lambda ()
	           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (vector->pvector #()))))
  (bench 'vector-singleton->pvector 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (vector->pvector singleton-vector))))
  (bench 'vector-small-8->pvector 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (vector->pvector small-8-vector))))
  (bench 'vector-small-16->pvector 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (vector->pvector small-16-vector))))
  (bench 'vector-small-17->pvector 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (vector->pvector small-17-vector))))
  (bench 'vector-small-18->pvector 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (vector->pvector small-18-vector))))
  (bench 'vector-small-32->pvector 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (vector->pvector small-32-vector))))
  (bench 'vector-small-64->pvector 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (vector->pvector small-64-vector))))
  (bench 'empty-pvector->list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (pvector->list (pvector-empty)))))
  (bench 'empty-pvector->list 'unsafe-pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (unsafe:unsafe-pvector->list (pvector-empty)))))
  (bench 'singleton-pvector->list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (pvector->list singleton-pvector))))
  (bench 'singleton-pvector->list 'unsafe-pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (unsafe:unsafe-pvector->list singleton-pvector))))
  (bench 'empty-pvector->vector 'pvector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (pvector->vector (pvector-empty)))))
  (bench 'singleton-pvector->vector 'pvector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (pvector->vector singleton-pvector))))
  (bench 'singleton-pvector->vector 'unsafe-pvector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (unsafe:unsafe-pvector->vector singleton-pvector))))
  (bench 'empty-pvector-map 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-map (pvector-empty) add1))))
  (bench 'singleton-pvector-map-add1 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-map singleton-pvector add1))))
  (bench 'singleton-pvector-map-void 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-map singleton-pvector void))))
  (bench 'empty-pvector-for-each 'pvector
         (lambda ()
           (for/fold ([r (void)]) ([j (in-range m)])
             (pvector-for-each (pvector-empty) add1))))
  (bench 'singleton-pvector-for-each-add1 'pvector
         (lambda ()
           (for/fold ([r (void)]) ([j (in-range m)])
             (pvector-for-each singleton-pvector add1))))
  (bench 'singleton-pvector-for-each-void 'pvector
         (lambda ()
           (for/fold ([r (void)]) ([j (in-range m)])
             (pvector-for-each singleton-pvector void))))

  (bench 'match-fixed-4 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (if (match match-fixed-pvector
                   [(pvector 0 1 2 3) #t]
                   [_ #f])
                 (add1 sum)
                 sum))))
	  (bench 'match-list-repeat 'pvector
	         (lambda ()
	           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
	             (match match-rest-pvector
	               [(pvector 0 xs ..2)
	                (+ sum (length xs))]
	               [_ sum]))))
	  (bench 'match-leading-repeat 'pvector
	         (lambda ()
	           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
	             (match match-rest-pvector
	               [(pvector xs ..2 14 15)
	                (+ sum (length xs))]
	               [_ sum]))))
	  (bench 'match-middle-repeat 'pvector
	         (lambda ()
	           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
	             (match match-rest-pvector
	               [(pvector 0 xs ..2 15)
	                (+ sum (length xs))]
	               [_ sum]))))
	  (bench 'match-rest-span 'pvector
	         (lambda ()
	           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (match match-rest-pvector
               [(pvector* 0 1 #:rest mid 15)
                (+ sum (pvector-length mid))]
               [_ sum]))))

  (bench 'cons-left-chain 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (for/fold ([xs null]) ([i (in-range n)])
               (cons i xs)))))
  (bench 'cons-left-chain 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (for/fold ([vec #()]) ([i (in-range n)])
               (vector-append (vector i) vec))))
         #:when (n . <= . list-limit))
  (bench 'cons-left-chain 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (for/fold ([tl empty-treelist]) ([i (in-range n)])
               (treelist-cons tl i)))))
  (bench 'cons-left-chain 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv (cutie:pvector-empty)]) ([i (in-range n)])
               (cutie:pvector-cons-left pv i)))))
  (bench 'cons-left-chain 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv (pvector-empty)]) ([i (in-range n)])
               (pvector-cons-left pv i)))))
  (bench 'cons-left-chain 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv (pvector-empty)]) ([i (in-range n)])
               (unsafe:unsafe-pvector-cons-left pv i)))))

  (bench 'cons-right-chain 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (for/fold ([xs null]) ([i (in-range n)])
               (append xs (list i)))))
         #:when (n . <= . list-limit))
  (bench 'cons-right-chain 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (for/fold ([vec #()]) ([i (in-range n)])
               (vector-append vec (vector i)))))
         #:when (n . <= . list-limit))
  (bench 'cons-right-chain 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (for/fold ([tl empty-treelist]) ([i (in-range n)])
               (treelist-add tl i)))))
  (bench 'cons-right-chain 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv (cutie:pvector-empty)]) ([i (in-range n)])
               (cutie:pvector-cons-right pv i)))))
  (bench 'cons-right-chain 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv (pvector-empty)]) ([i (in-range n)])
               (pvector-cons-right pv i)))))
  (bench 'cons-right-chain 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv (pvector-empty)]) ([i (in-range n)])
               (unsafe:unsafe-pvector-cons-right pv i)))))

  (bench 'pop-left-chain 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (for/fold ([xs base-list]) ([i (in-range n)])
               (cdr xs)))))
  (bench 'pop-left-chain 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (for/fold ([vec base-vector]) ([i (in-range n)])
               (vector-drop vec 1))))
         #:when (n . <= . list-limit))
  (bench 'pop-left-chain 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (for/fold ([tl base-treelist]) ([i (in-range n)])
               (treelist-rest tl)))))
  (bench 'pop-left-chain 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-cutie-pvector]) ([i (in-range n)])
               (define-values (_ rest) (cutie:pvector-pop-left pv))
               rest))))
  (bench 'pop-left-chain 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-pvector]) ([i (in-range n)])
               (define-values (_ rest) (pvector-pop-left pv))
               rest))))
  (bench 'pop-left-chain 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-pvector]) ([i (in-range n)])
               (define-values (_ rest) (unsafe:unsafe-pvector-pop-left pv))
               rest))))
  (bench 'pop-left-singleton 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (_ rest) (pvector-pop-left singleton-pvector))
             rest)))
  (bench 'pop-left-singleton 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (_ rest) (unsafe:unsafe-pvector-pop-left singleton-pvector))
             rest)))

  (bench 'pop-right-chain 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (for/fold ([xs base-list] [len n] #:result xs) ([i (in-range n)])
               (values (take xs (sub1 len)) (sub1 len)))))
         #:when (n . <= . list-limit))
  (bench 'pop-right-chain 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (for/fold ([vec base-vector] [len n] #:result vec) ([i (in-range n)])
               (values (vector-take vec (sub1 len)) (sub1 len)))))
         #:when (n . <= . list-limit))
  (bench 'pop-right-chain 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (for/fold ([tl base-treelist]) ([i (in-range n)])
               (treelist-drop-right tl 1)))))
  (bench 'pop-right-chain 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-cutie-pvector]) ([i (in-range n)])
               (define-values (_ rest) (cutie:pvector-pop-right pv))
               rest))))
  (bench 'pop-right-chain 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-pvector]) ([i (in-range n)])
               (define-values (_ rest) (pvector-pop-right pv))
               rest))))
  (bench 'pop-right-chain 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-pvector]) ([i (in-range n)])
               (define-values (_ rest) (unsafe:unsafe-pvector-pop-right pv))
               rest))))
  (bench 'pop-right-singleton 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (_ rest) (pvector-pop-right singleton-pvector))
             rest)))
  (bench 'pop-right-singleton 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (_ rest) (unsafe:unsafe-pvector-pop-right singleton-pvector))
             rest)))

  (bench 'append-halves 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (append left-list right-list))))
  (bench 'append-halves 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (vector-append left-vector right-vector))))
  (bench 'append-halves 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (treelist-append left-treelist right-treelist))))
  (bench 'append-halves 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (cutie:pvector-append left-cutie-pvector right-cutie-pvector))))
  (bench 'append-halves 'raw-pvector
         (lambda ()
           (for/fold ([r (raw:pvector-empty)]) ([j (in-range m)])
             (raw:pvector-append left-raw-pvector right-raw-pvector))))
  (bench 'append-halves 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-append left-pvector right-pvector))))
  (bench 'append-left-empty 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-append (pvector-empty) base-pvector))))
  (bench 'append-right-empty 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-append base-pvector (pvector-empty)))))
  (bench 'append-halves 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-append left-pvector right-pvector))))
  (bench 'append-halves->vector 'pvector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (pvector->vector (pvector-append left-pvector right-pvector)))))
  (bench 'append-halves->list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (pvector->list (pvector-append left-pvector right-pvector)))))
  (bench 'append-cached-halves 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-append left-cached-pvector right-cached-pvector))))
  (bench 'append-cached-halves->vector 'pvector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (pvector->vector
              (pvector-append left-cached-pvector right-cached-pvector)))))
  (bench 'append-cached-halves->list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (pvector->list
              (pvector-append left-cached-pvector right-cached-pvector)))))
  (bench 'append-left-empty 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-append (pvector-empty) base-pvector))))
  (bench 'append-right-empty 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-append base-pvector (pvector-empty)))))
  (bench 'append-left-singleton 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-append singleton-pvector base-pvector))))
  (bench 'append-left-singleton 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-append singleton-pvector base-pvector))))
  (bench 'append-left-2 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-append pair-pvector base-pvector))))
  (bench 'append-left-2 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-append pair-pvector base-pvector))))
  (bench 'append-left-3 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-append triple-pvector base-pvector))))
  (bench 'append-left-3 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-append triple-pvector base-pvector))))
  (bench 'append-left-4 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-append quad-pvector base-pvector))))
  (bench 'append-left-4 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-append quad-pvector base-pvector))))
  (bench 'append-right-singleton 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-append base-pvector singleton-pvector))))
  (bench 'append-right-singleton 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-append base-pvector singleton-pvector))))
  (bench 'append-right-2 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-append base-pvector pair-pvector))))
  (bench 'append-right-2 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-append base-pvector pair-pvector))))
  (bench 'append-right-3 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-append base-pvector triple-pvector))))
  (bench 'append-right-3 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-append base-pvector triple-pvector))))
  (bench 'append-right-4 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-append base-pvector quad-pvector))))
  (bench 'append-right-4 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-append base-pvector quad-pvector))))

  (bench 'map-add1 'list
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (list->pvector (map add1 base-list)))))
  (bench 'map-add1 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (treelist-map base-treelist add1))))
  (bench 'map-add1 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-map base-pvector add1))))
  (bench 'map-values 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-map base-pvector values))))
  (bench 'map-void 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-map base-pvector void))))

  (bench 'for-each-sum 'list
         (lambda ()
           (for/fold ([total 0]) ([j (in-range m)])
             (define sum 0)
             (for-each (lambda (v) (set! sum (+ sum v))) base-list)
             (+ total sum))))
  (bench 'for-each-sum 'treelist
         (lambda ()
           (for/fold ([total 0]) ([j (in-range m)])
             (define sum 0)
             (treelist-for-each base-treelist
                                (lambda (v) (set! sum (+ sum v))))
             (+ total sum))))
  (bench 'for-each-sum 'pvector
         (lambda ()
           (for/fold ([total 0]) ([j (in-range m)])
             (define sum 0)
             (pvector-for-each base-pvector
                               (lambda (v) (set! sum (+ sum v))))
             (+ total sum))))
  (bench 'for-each-sum-consed 'pvector
         (lambda ()
           (for/fold ([total 0]) ([j (in-range m)])
             (define sum 0)
             (pvector-for-each consed-right-pvector
                               (lambda (v) (set! sum (+ sum v))))
             (+ total sum)))
         #:when consed-right-pvector)
  (bench 'for-each-void 'pvector
         (lambda ()
           (for/fold ([r (void)]) ([j (in-range m)])
             (pvector-for-each base-pvector void))))
  (bench 'for-each-void-consed 'pvector
         (lambda ()
           (for/fold ([r (void)]) ([j (in-range m)])
             (pvector-for-each consed-right-pvector void)))
         #:when consed-right-pvector)
  (bench 'for-each-values 'pvector
         (lambda ()
           (for/fold ([r (void)]) ([j (in-range m)])
             (pvector-for-each base-pvector values))))

  (bench 'append-roundtrip 'list
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (list->pvector (append left-list right-list)))))
  (bench 'append-roundtrip 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-append left-pvector right-pvector))))

  (bench 'first-repeated 'list
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (car base-list)))))
  (bench 'first-repeated 'vector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (vector-ref base-vector 0)))))
  (bench 'first-repeated 'treelist
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (treelist-first base-treelist)))))
  (bench 'first-repeated 'cutie-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (cutie:pvector-view-left base-cutie-pvector)))))
  (bench 'first-repeated 'raw-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (raw:pvector-view-left base-raw-pvector)))))
  (bench 'first-repeated 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (pvector-first base-pvector)))))
  (bench 'first-repeated 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (unsafe:unsafe-pvector-first base-pvector)))))
  (bench 'ref-first-repeated 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (pvector-ref base-pvector 0)))))
  (bench 'ref-first-repeated 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (unsafe:unsafe-pvector-ref base-pvector 0)))))

  (bench 'last-repeated 'list
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (last base-list))))
         #:when (n . <= . list-limit))
  (bench 'last-repeated 'vector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (vector-ref base-vector (sub1 n))))))
  (bench 'last-repeated 'treelist
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (treelist-last base-treelist)))))
  (bench 'last-repeated 'cutie-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (cutie:pvector-view-right base-cutie-pvector)))))
  (bench 'last-repeated 'raw-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (raw:pvector-view-right base-raw-pvector)))))
  (bench 'last-repeated 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (pvector-last base-pvector)))))
  (bench 'last-repeated 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (unsafe:unsafe-pvector-last base-pvector)))))
  (bench 'ref-last-repeated 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (pvector-ref base-pvector (sub1 n))))))
  (bench 'ref-last-repeated 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (unsafe:unsafe-pvector-ref base-pvector (sub1 n))))))

  (bench 'length-repeated 'list
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (length base-list))))
         #:when (n . <= . list-limit))
  (bench 'length-repeated 'vector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (vector-length base-vector)))))
  (bench 'length-repeated 'treelist
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (treelist-length base-treelist)))))
  (bench 'length-repeated 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (pvector-length base-pvector)))))
  (bench 'length-repeated 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (unsafe:unsafe-pvector-length base-pvector)))))

  (bench 'empty?-empty 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (if (pvector-empty? (pvector-empty)) (add1 sum) sum))))
  (bench 'empty?-nonempty 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (if (pvector-empty? base-pvector) (add1 sum) sum))))
  (bench 'empty?-other 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (if (pvector-empty? null) (add1 sum) sum))))

  (bench 'hash-repeated 'list
         (lambda ()
           (for/fold ([h 0]) ([j (in-range m)])
             (bitwise-xor h (equal-hash-code base-list)))))
  (bench 'hash-repeated 'vector
         (lambda ()
           (for/fold ([h 0]) ([j (in-range m)])
             (bitwise-xor h (equal-hash-code base-vector)))))
  (bench 'hash-repeated 'treelist
         (lambda ()
           (for/fold ([h 0]) ([j (in-range m)])
             (bitwise-xor h (equal-hash-code base-treelist)))))
  (bench 'hash-repeated 'pvector
         (lambda ()
           (for/fold ([h 0]) ([j (in-range m)])
             (bitwise-xor h (equal-hash-code base-pvector)))))
  (bench 'hash-consed-repeated 'pvector
         (lambda ()
           (for/fold ([h 0]) ([j (in-range m)])
             (bitwise-xor h (equal-hash-code consed-right-pvector))))
         #:when consed-right-pvector)

  (bench 'equal-separate-build 'pvector
         (lambda ()
           (for/fold ([r #f]) ([j (in-range m)])
             (equal? base-pvector same-list-pvector))))
  (bench 'equal-consed-separate-build 'pvector
         (lambda ()
           (for/fold ([r #f]) ([j (in-range m)])
             (equal? base-pvector consed-right-pvector)))
         #:when consed-right-pvector)
  (bench 'equal-consed-same-shape 'pvector
         (lambda ()
           (for/fold ([r #f]) ([j (in-range m)])
             (equal? consed-right-pvector consed-right-pvector*)))
         #:when (and consed-right-pvector consed-right-pvector*))
  (bench 'equal-shared-set-same 'pvector
         (lambda ()
           (for/fold ([r #f]) ([j (in-range m)])
             (equal? base-pvector set-same-pvector))))
  (bench 'equal-shared-set-different 'pvector
         (lambda ()
           (for/fold ([r #f]) ([j (in-range m)])
             (equal? base-pvector set-different-pvector))))

  (bench 'split-middle 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (list (take base-list half) (drop base-list half)))))
  (bench 'split-middle 'vector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (list (vector-copy base-vector 0 half)
                   (vector-copy base-vector half n)))))
  (bench 'split-middle 'treelist
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (list (treelist-take base-treelist half)
                   (treelist-drop base-treelist half)))))
  (bench 'split-middle 'cutie-pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (define-values (left right) (cutie:pvector-split-at base-cutie-pvector half))
             (list left right))))
  (bench 'split-middle 'raw-pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (define-values (left right) (raw:pvector-split-at base-raw-pvector half))
             (list left right))))
  (bench 'split-middle 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (define-values (left right) (pvector-split-at base-pvector half))
             (list left right))))
  (bench 'split-middle 'unsafe-pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (define-values (left right) (unsafe:unsafe-pvector-split-at base-pvector half))
             (list left right))))
  (bench 'split-singleton 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (left value right) (pvector-split singleton-pvector 0))
             right)))
  (bench 'split-singleton 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (left value right) (unsafe:unsafe-pvector-split singleton-pvector 0))
             right)))
  (bench 'split-left 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (left value right) (pvector-split base-pvector 0))
             right)))
  (bench 'split-left 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (left value right) (unsafe:unsafe-pvector-split base-pvector 0))
             right)))
  (bench 'split-right 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (left value right) (pvector-split base-pvector (sub1 n)))
             left)))
  (bench 'split-right 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (left value right) (unsafe:unsafe-pvector-split base-pvector (sub1 n)))
             left)))
  (bench 'split-at-zero 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (left right) (pvector-split-at base-pvector 0))
             right)))
  (bench 'split-at-length 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (left right) (pvector-split-at base-pvector n))
             left)))
  (bench 'split-at-zero 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (left right) (unsafe:unsafe-pvector-split-at base-pvector 0))
             right)))
  (bench 'split-at-length 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (left right) (unsafe:unsafe-pvector-split-at base-pvector n))
             left)))
  (bench 'split-at-middle 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (left right) (pvector-split-at base-pvector half))
             right)))
  (bench 'split-at-middle 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (left right)
               (unsafe:unsafe-pvector-split-at base-pvector half))
             right)))

  (bench 'split-at-right-small 'pvector
         (lambda ()
           (for/fold ([r 0]) ([j (in-range m)])
             (define-values (right left)
               (adapter:pvector-split-at-right base-adapter-pvector narrow-subvector-len))
             (+ r (adapter:pvector-length right) (adapter:pvector-length left)))))
  (bench 'split-at-right-half 'pvector
         (lambda ()
           (for/fold ([r 0]) ([j (in-range m)])
             (define-values (right left)
               (adapter:pvector-split-at-right base-adapter-pvector half))
             (+ r (adapter:pvector-length right) (adapter:pvector-length left)))))

  (bench 'take-middle 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (take base-list half))))
  (bench 'take-middle 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (vector-take base-vector half))))
  (bench 'take-middle 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (treelist-take base-treelist half))))
  (bench 'take-middle 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (cutie:pvector-take base-cutie-pvector half))))
  (bench 'take-middle 'raw-pvector
         (lambda ()
           (for/fold ([r (raw:pvector-empty)]) ([j (in-range m)])
             (raw:pvector-take base-raw-pvector half))))
  (bench 'take-middle 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-take base-pvector half))))
  (bench 'take-zero 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-take base-pvector 0))))
  (bench 'take-length 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-take base-pvector n))))
  (bench 'take-middle 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-take base-pvector half))))
  (bench 'take-zero 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-take base-pvector 0))))
  (bench 'take-length 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-take base-pvector n))))

  (bench 'drop-middle 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (drop base-list half))))
  (bench 'drop-middle 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (vector-drop base-vector half))))
  (bench 'drop-middle 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (treelist-drop base-treelist half))))
  (bench 'drop-middle 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (cutie:pvector-drop base-cutie-pvector half))))
  (bench 'drop-middle 'raw-pvector
         (lambda ()
           (for/fold ([r (raw:pvector-empty)]) ([j (in-range m)])
             (raw:pvector-drop base-raw-pvector half))))
  (bench 'drop-middle 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-drop base-pvector half))))
  (bench 'drop-zero 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-drop base-pvector 0))))
  (bench 'drop-length 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-drop base-pvector n))))
  (bench 'drop-middle 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-drop base-pvector half))))
  (bench 'drop-zero 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-drop base-pvector 0))))
  (bench 'drop-length 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-drop base-pvector n))))

  (bench 'take-right-small 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-take-right base-pvector narrow-subvector-len))))
  (bench 'take-right-small 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-take-right base-pvector narrow-subvector-len))))
  (bench 'drop-right-small 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-drop-right base-pvector narrow-subvector-len))))
  (bench 'drop-right-small 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-drop-right base-pvector narrow-subvector-len))))
  (bench 'take-right-half 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-take-right base-pvector half))))
  (bench 'take-right-zero 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-take-right base-pvector 0))))
  (bench 'take-right-length 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-take-right base-pvector n))))
  (bench 'take-right-half 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-take-right base-pvector half))))
  (bench 'take-right-zero 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-take-right base-pvector 0))))
  (bench 'take-right-length 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-take-right base-pvector n))))
  (bench 'drop-right-half 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-drop-right base-pvector half))))
  (bench 'drop-right-zero 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-drop-right base-pvector 0))))
  (bench 'drop-right-length 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-drop-right base-pvector n))))
  (bench 'drop-right-half 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-drop-right base-pvector half))))
  (bench 'drop-right-zero 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-drop-right base-pvector 0))))
  (bench 'drop-right-length 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-drop-right base-pvector n))))

  (bench 'subvector-middle 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (take (drop base-list quarter) (- three-quarter quarter)))))
  (bench 'subvector-middle 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (vector-copy base-vector quarter three-quarter))))
  (bench 'subvector-middle 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (treelist-drop (treelist-take base-treelist three-quarter) quarter))))
  (bench 'subvector-middle 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (cutie:pvector-copy base-cutie-pvector quarter three-quarter))))
  (bench 'subvector-middle 'raw-pvector
         (lambda ()
           (for/fold ([r (raw:pvector-empty)]) ([j (in-range m)])
             (raw:pvector-copy base-raw-pvector quarter three-quarter))))
  (bench 'subvector-middle 'adapter-pvector
         (lambda ()
           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
             (adapter:pvector-copy base-adapter-pvector quarter three-quarter))))
  (bench 'subvector-middle 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-subvector base-pvector quarter three-quarter))))
  (bench 'subvector-middle 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-subvector base-pvector quarter three-quarter))))
  (bench 'subvector-empty 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-subvector base-pvector half half))))
  (bench 'subvector-empty 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-subvector base-pvector half half))))
  (bench 'subvector-full 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-subvector base-pvector 0 n))))
  (bench 'subvector-full 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-subvector base-pvector 0 n))))
  (bench 'subvector-tail-full 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-subvector base-pvector 0))))
  (bench 'subvector-empty-zero 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-subvector base-pvector 0 0))))
  (bench 'subvector-prefix 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-subvector base-pvector 0 half))))
  (bench 'subvector-prefix 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-subvector base-pvector 0 half))))
  (bench 'subvector-suffix 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-subvector base-pvector half n))))
  (bench 'subvector-suffix 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-subvector base-pvector half n))))
  (bench 'subvector-tail 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-subvector base-pvector half))))
  (bench 'subvector-singleton 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-subvector base-pvector half (add1 half)))))
  (bench 'subvector-singleton 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-subvector base-pvector half (add1 half)))))

  (bench 'subvector-left 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-subvector base-pvector left-subvector-start left-subvector-end))))
  (bench 'subvector-left 'adapter-pvector
         (lambda ()
           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
             (adapter:pvector-copy base-adapter-pvector left-subvector-start left-subvector-end))))
  (bench 'subvector-left 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-subvector base-pvector left-subvector-start left-subvector-end))))
  (bench 'subvector-right 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-subvector base-pvector right-subvector-start right-subvector-end))))
  (bench 'subvector-right 'adapter-pvector
         (lambda ()
           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
             (adapter:pvector-copy base-adapter-pvector right-subvector-start right-subvector-end))))
  (bench 'subvector-right 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-subvector base-pvector right-subvector-start right-subvector-end))))
  (bench 'subvector-wide 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-subvector base-pvector wide-subvector-start wide-subvector-end))))
  (bench 'subvector-wide 'adapter-pvector
         (lambda ()
           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
             (adapter:pvector-copy base-adapter-pvector wide-subvector-start wide-subvector-end))))
  (bench 'subvector-wide 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-subvector base-pvector wide-subvector-start wide-subvector-end))))
  (bench 'subvector-narrow 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-subvector base-pvector narrow-subvector-start narrow-subvector-end))))
  (bench 'subvector-narrow 'adapter-pvector
         (lambda ()
           (for/fold ([r (adapter:pvector-empty)]) ([j (in-range m)])
             (adapter:pvector-copy base-adapter-pvector narrow-subvector-start narrow-subvector-end))))
  (bench 'subvector-narrow 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-subvector base-pvector narrow-subvector-start narrow-subvector-end))))

  (bench 'subvector-small-2chunk 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-subvector base-pvector
                                small-subvector-start
                                small-2chunk-subvector-end))))
  (bench 'subvector-small-2chunk 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-subvector base-pvector
                                              small-subvector-start
                                              small-2chunk-subvector-end))))
  (bench 'subvector-small-3chunk 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-subvector base-pvector
                                small-subvector-start
                                small-3chunk-subvector-end))))
  (bench 'subvector-small-3chunk 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-subvector base-pvector
                                              small-subvector-start
                                              small-3chunk-subvector-end))))

  (bench 'ref-sequential 'list
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (list-ref base-list i))))
         #:when (n . <= . list-limit))
  (bench 'ref-sequential 'vector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (vector-ref base-vector i)))))
  (bench 'ref-sequential 'treelist
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (treelist-ref base-treelist i)))))
  (bench 'ref-sequential 'cutie-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (cutie:pvector-ref base-cutie-pvector i)))))
  (bench 'ref-sequential 'raw-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (raw:pvector-ref base-raw-pvector i)))))
  (bench 'ref-sequential 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (pvector-ref base-pvector i)))))
  (bench 'ref-sequential 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (unsafe:unsafe-pvector-ref base-pvector i)))))
  (bench 'set-middle-ref-sequential 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (pvector-ref set-middle-ref-pvector i)))))
	  (bench 'set-middle-ref-sequential 'unsafe-pvector
	         (lambda ()
	           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
	             (+ sum (unsafe:unsafe-pvector-ref unsafe-set-middle-ref-pvector i)))))
	  (bench 'cons-left-ref-sequential 'pvector
	         (lambda ()
	           (for*/fold ([sum 0])
	                      ([j (in-range m)]
	                       [i (in-range (pvector-length cons-left-ref-pvector))])
	             (+ sum (pvector-ref cons-left-ref-pvector i)))))
	  (bench 'cons-left-ref-sequential 'unsafe-pvector
	         (lambda ()
	           (for*/fold ([sum 0])
	                      ([j (in-range m)]
	                       [i (in-range (pvector-length unsafe-cons-left-ref-pvector))])
	             (+ sum (unsafe:unsafe-pvector-ref unsafe-cons-left-ref-pvector i)))))
	  (bench 'pop-left-ref-sequential 'pvector
	         (lambda ()
	           (for*/fold ([sum 0])
	                      ([j (in-range m)]
	                       [i (in-range (pvector-length pop-left-ref-pvector))])
	             (+ sum (pvector-ref pop-left-ref-pvector i)))))
	  (bench 'pop-left-ref-sequential 'unsafe-pvector
	         (lambda ()
	           (for*/fold ([sum 0])
	                      ([j (in-range m)]
	                       [i (in-range (pvector-length unsafe-pop-left-ref-pvector))])
	             (+ sum (unsafe:unsafe-pvector-ref unsafe-pop-left-ref-pvector i)))))
	  (bench 'insert-right-ref-sequential 'pvector
	         (lambda ()
	           (for*/fold ([sum 0])
	                      ([j (in-range m)]
                       [i (in-range (pvector-length insert-right-ref-pvector))])
             (+ sum (pvector-ref insert-right-ref-pvector i)))))
  (bench 'insert-right-ref-sequential 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0])
                      ([j (in-range m)]
                       [i (in-range (pvector-length unsafe-insert-right-ref-pvector))])
             (+ sum (unsafe:unsafe-pvector-ref unsafe-insert-right-ref-pvector i)))))
  (bench 'delete-right-ref-sequential 'pvector
         (lambda ()
           (for*/fold ([sum 0])
                      ([j (in-range m)]
                       [i (in-range (pvector-length delete-right-ref-pvector))])
             (+ sum (pvector-ref delete-right-ref-pvector i)))))
  (bench 'delete-right-ref-sequential 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0])
                      ([j (in-range m)]
                       [i (in-range (pvector-length unsafe-delete-right-ref-pvector))])
             (+ sum (unsafe:unsafe-pvector-ref unsafe-delete-right-ref-pvector i)))))
  (bench 'append-halves-ref-sequential 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (pvector-ref appended-halves-pvector i)))))
  (bench 'append-halves-ref-sequential 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (unsafe:unsafe-pvector-ref appended-halves-pvector i)))))
  (bench 'append-cached-halves-ref-sequential 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (pvector-ref appended-cached-halves-pvector i)))))
  (bench 'append-cached-halves-ref-sequential 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (unsafe:unsafe-pvector-ref appended-cached-halves-pvector i)))))
  (bench 'take-middle-ref-sequential 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range half)])
             (+ sum (pvector-ref left-pvector i)))))
  (bench 'take-middle-ref-sequential 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range half)])
             (+ sum (unsafe:unsafe-pvector-ref left-pvector i)))))
  (bench 'drop-middle-ref-sequential 'pvector
         (lambda ()
           (for*/fold ([sum 0])
                      ([j (in-range m)]
                       [i (in-range (- n half))])
             (+ sum (pvector-ref right-pvector i)))))
  (bench 'drop-middle-ref-sequential 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0])
                      ([j (in-range m)]
                       [i (in-range (- n half))])
             (+ sum (unsafe:unsafe-pvector-ref right-pvector i)))))
  (bench 'subvector-prefix-ref-sequential 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range half)])
             (+ sum (pvector-ref prefix-subvector-pvector i)))))
  (bench 'subvector-prefix-ref-sequential 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range half)])
             (+ sum (unsafe:unsafe-pvector-ref unsafe-prefix-subvector-pvector i)))))
  (bench 'subvector-suffix-ref-sequential 'pvector
         (lambda ()
           (for*/fold ([sum 0])
                      ([j (in-range m)]
                       [i (in-range (- n half))])
             (+ sum (pvector-ref suffix-subvector-pvector i)))))
  (bench 'subvector-suffix-ref-sequential 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0])
                      ([j (in-range m)]
                       [i (in-range (- n half))])
             (+ sum (unsafe:unsafe-pvector-ref unsafe-suffix-subvector-pvector i)))))
  (bench 'take-right-half-ref-sequential 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range half)])
             (+ sum (pvector-ref take-right-half-pvector i)))))
  (bench 'take-right-half-ref-sequential 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range half)])
             (+ sum (unsafe:unsafe-pvector-ref take-right-half-pvector i)))))
  (bench 'drop-right-half-ref-sequential 'pvector
         (lambda ()
           (for*/fold ([sum 0])
                      ([j (in-range m)]
                       [i (in-range (- n half))])
             (+ sum (pvector-ref drop-right-half-pvector i)))))
  (bench 'drop-right-half-ref-sequential 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0])
                      ([j (in-range m)]
                       [i (in-range (- n half))])
             (+ sum (unsafe:unsafe-pvector-ref drop-right-half-pvector i)))))
  (bench 'split-left-ref-sequential 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range half)])
             (+ sum (pvector-ref split-left-pvector i)))))
  (bench 'split-left-ref-sequential 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range half)])
             (+ sum (unsafe:unsafe-pvector-ref split-left-pvector i)))))
  (bench 'split-right-ref-sequential 'pvector
         (lambda ()
           (for*/fold ([sum 0])
                      ([j (in-range m)]
                       [i (in-range (- n half))])
             (+ sum (pvector-ref split-right-pvector i)))))
  (bench 'split-right-ref-sequential 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0])
                      ([j (in-range m)]
                       [i (in-range (- n half))])
             (+ sum (unsafe:unsafe-pvector-ref split-right-pvector i)))))
  (bench 'split-value-left-ref-sequential 'pvector
         (lambda ()
           (for*/fold ([sum 0])
                      ([j (in-range m)]
                       [i (in-range split-value-index)])
             (+ sum (pvector-ref split-value-left-pvector i)))))
  (bench 'split-value-left-ref-sequential 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0])
                      ([j (in-range m)]
                       [i (in-range split-value-index)])
             (+ sum (unsafe:unsafe-pvector-ref split-value-left-pvector i)))))
  (bench 'split-value-right-ref-sequential 'pvector
         (lambda ()
           (for*/fold ([sum 0])
                      ([j (in-range m)]
                       [i (in-range (pvector-length split-value-right-pvector))])
             (+ sum (pvector-ref split-value-right-pvector i)))))
  (bench 'split-value-right-ref-sequential 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0])
                      ([j (in-range m)]
                       [i (in-range (pvector-length split-value-right-pvector))])
             (+ sum (unsafe:unsafe-pvector-ref split-value-right-pvector i)))))
  (bench 'large-aligned-copy-ref-sequential 'pvector
         (lambda ()
           (for*/fold ([sum 0])
                      ([j (in-range m)]
                       [i (in-range large-copy-len)])
             (+ sum (pvector-ref large-aligned-copy-pvector i)))))
  (bench 'large-aligned-copy-ref-sequential 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0])
                      ([j (in-range m)]
                       [i (in-range large-copy-len)])
             (+ sum (unsafe:unsafe-pvector-ref large-aligned-copy-pvector i)))))
  (bench 'large-unaligned-copy-ref-sequential 'pvector
         (lambda ()
           (for*/fold ([sum 0])
                      ([j (in-range m)]
                       [i (in-range large-unaligned-copy-len)])
             (+ sum (pvector-ref large-unaligned-copy-pvector i)))))
  (bench 'large-unaligned-copy-ref-sequential 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0])
                      ([j (in-range m)]
                       [i (in-range large-unaligned-copy-len)])
             (+ sum (unsafe:unsafe-pvector-ref large-unaligned-copy-pvector i)))))
  (bench 'ref-singleton 'pvector
         (lambda ()
           (for/fold ([sum 0]) ([j (in-range m)])
             (+ sum (pvector-ref singleton-pvector 0)))))
  (bench 'ref-singleton 'unsafe-pvector
         (lambda ()
           (for/fold ([sum 0]) ([j (in-range m)])
             (+ sum (unsafe:unsafe-pvector-ref singleton-pvector 0)))))

  (bench 'set-sequential 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (for/fold ([xs base-list]) ([i (in-range n)])
               (list-set xs i (+ i j)))))
         #:when (n . <= . list-limit))
  (bench 'set-sequential 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (for/fold ([vec base-vector]) ([i (in-range n)])
               (vector-set/persistent vec i (+ i j)))))
         #:when (n . <= . list-limit))
  (bench 'set-sequential 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (for/fold ([tl base-treelist]) ([i (in-range n)])
               (treelist-set tl i (+ i j))))))
  (bench 'set-sequential 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-cutie-pvector]) ([i (in-range n)])
               (cutie:pvector-set pv i (+ i j))))))
  (bench 'set-sequential 'raw-pvector
         (lambda ()
           (for/fold ([r (raw:pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-raw-pvector]) ([i (in-range n)])
               (raw:pvector-set pv i (+ i j))))))
  (bench 'set-sequential 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-pvector]) ([i (in-range n)])
               (pvector-set pv i (+ i j))))))
  (bench 'set-sequential 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-pvector]) ([i (in-range n)])
               (unsafe:unsafe-pvector-set pv i (+ i j))))))

  (bench 'set-same 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-set base-pvector half half))))
  (bench 'set-same 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-set base-pvector half half))))
  (bench 'set-different 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-set base-pvector half 'different))))
  (bench 'set-different 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-set base-pvector half 'different))))
  (bench 'set-first 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-set base-pvector 0 'different))))
  (bench 'set-first 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-set base-pvector 0 'different))))
  (bench 'set-last 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-set base-pvector (sub1 n) 'different))))
  (bench 'set-last 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-set base-pvector (sub1 n) 'different))))
  (bench 'set-singleton-same 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-set singleton-pvector 0 0))))
  (bench 'set-singleton-same 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-set singleton-pvector 0 0))))
  (bench 'set-singleton-different 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-set singleton-pvector 0 'different))))
  (bench 'set-singleton-different 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-set singleton-pvector 0 'different))))

  (bench 'insert-middle 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (append (take base-list half)
                     (list j)
                     (drop base-list half))))
         #:when (n . <= . list-limit))
  (bench 'insert-middle 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (vector-append (vector-copy base-vector 0 half)
                            (vector j)
                            (vector-copy base-vector half n))))
         #:when (n . <= . list-limit))
  (bench 'insert-middle 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (treelist-insert base-treelist half j))))
  (bench 'insert-middle 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (cutie:pvector-insert base-cutie-pvector half j))))
  (bench 'insert-middle 'raw-pvector
         (lambda ()
           (for/fold ([r (raw:pvector-empty)]) ([j (in-range m)])
             (raw:pvector-insert base-raw-pvector half j))))
  (bench 'insert-middle 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-insert base-pvector half j))))
  (bench 'insert-middle 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-insert base-pvector half j))))
  (bench 'insert-left 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-insert base-pvector 0 j))))
  (bench 'insert-left 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-insert base-pvector 0 j))))
  (bench 'insert-right 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-insert base-pvector n j))))
  (bench 'insert-right 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-insert base-pvector n j))))

  (bench 'delete-middle 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (append (take base-list half)
                     (drop base-list (add1 half)))))
         #:when (n . <= . list-limit))
  (bench 'delete-middle 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (vector-append (vector-copy base-vector 0 half)
                            (vector-copy base-vector (add1 half) n))))
         #:when (n . <= . list-limit))
  (bench 'delete-middle 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (treelist-delete base-treelist half))))
  (bench 'delete-middle 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (define-values (pv value)
               (cutie:pvector-delete base-cutie-pvector half))
             pv)))
  (bench 'delete-middle 'raw-pvector
         (lambda ()
           (for/fold ([r (raw:pvector-empty)]) ([j (in-range m)])
             (define-values (pv value)
               (raw:pvector-delete base-raw-pvector half))
             pv)))
  (bench 'delete-middle 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (pv value)
               (pvector-delete base-pvector half))
             pv)))
  (bench 'delete-middle 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (pv value)
               (unsafe:unsafe-pvector-delete base-pvector half))
             pv)))
  (bench 'delete-inserted-singleton 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (pv value)
               (pvector-delete inserted-middle-pvector half))
             pv)))
  (bench 'delete-inserted-singleton 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (pv value)
               (unsafe:unsafe-pvector-delete inserted-middle-pvector half))
             pv)))
  (bench 'delete-boundary-inserted 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (pv value)
               (pvector-delete base-boundary-inserted-pvector 64))
             pv))
         #:when base-boundary-inserted-pvector)
  (bench 'delete-boundary-inserted 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (pv value)
               (unsafe:unsafe-pvector-delete base-boundary-inserted-pvector 64))
             pv))
         #:when base-boundary-inserted-pvector)
  (bench 'delete-left 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (pv value)
               (pvector-delete base-pvector 0))
             pv)))
  (bench 'delete-left 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (pv value)
               (unsafe:unsafe-pvector-delete base-pvector 0))
             pv)))
  (bench 'delete-right 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (pv value)
               (pvector-delete base-pvector (sub1 n)))
             pv)))
  (bench 'delete-right 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (pv value)
               (unsafe:unsafe-pvector-delete base-pvector (sub1 n)))
             pv)))
  (bench 'delete-singleton 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (pv value)
               (pvector-delete singleton-pvector 0))
             pv)))
  (bench 'delete-singleton 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (define-values (pv value)
               (unsafe:unsafe-pvector-delete singleton-pvector 0))
             pv)))

  (bench 'iterate 'list
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-list base-list)])
             (+ sum i))))
  (bench 'iterate 'vector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-vector base-vector)])
             (+ sum i))))
  (bench 'iterate 'treelist
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-treelist base-treelist)])
             (+ sum i))))
  (bench 'iterate 'cutie-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (cutie:in-pvector base-cutie-pvector)])
             (+ sum i))))
  (bench 'iterate 'raw-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (raw:in-pvector base-raw-pvector)])
             (+ sum i))))
  (bench 'iterate 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-pvector base-pvector)])
             (+ sum i))))
  (bench 'iterate 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (unsafe:unsafe-in-pvector base-pvector)])
             (+ sum i))))
  (bench 'iterate-consed 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-pvector consed-right-pvector)])
             (+ sum i)))
         #:when consed-right-pvector)
  (bench 'iterate-consed 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (unsafe:unsafe-in-pvector consed-right-pvector)])
             (+ sum i)))
         #:when consed-right-pvector)
  (bench 'iterate-proc 'adapter-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)])
             (define seq (adapter:in-pvector base-adapter-pvector))
             (for/fold ([sum sum]) ([i seq])
               (+ sum i)))))
  (bench 'iterate-proc 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)])
             (define seq (in-pvector base-pvector))
             (for/fold ([sum sum]) ([i seq])
               (+ sum i)))))
  (bench 'iterate-proc 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)])
             (define seq (unsafe:unsafe-in-pvector base-pvector))
             (for/fold ([sum sum]) ([i seq])
               (+ sum i)))))
  (bench 'iterate-proc-consed 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)])
             (define seq (in-pvector consed-right-pvector))
             (for/fold ([sum sum]) ([i seq])
               (+ sum i))))
         #:when consed-right-pvector)
  (bench 'iterate-proc-consed 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)])
             (define seq (unsafe:unsafe-in-pvector consed-right-pvector))
             (for/fold ([sum sum]) ([i seq])
               (+ sum i))))
         #:when consed-right-pvector)
  (bench 'iterate-proc-shifted 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)])
             (define seq (in-pvector shifted-pvector))
             (for/fold ([sum sum]) ([i seq])
               (+ sum i)))))
  (bench 'iterate-proc-shifted 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)])
             (define seq (unsafe:unsafe-in-pvector shifted-pvector))
             (for/fold ([sum sum]) ([i seq])
               (+ sum i)))))

  (bench 'iterate-indexed 'adapter-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)]
                                 [(x i) (adapter:in-pvector/index base-adapter-pvector)])
             (+ sum x i))))
  (bench 'iterate-indexed-alias 'adapter-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)]
                                 [(x i) (adapter:in-pvector-indexed base-adapter-pvector)])
             (+ sum x i))))
  (bench 'iterate-indexed-proc 'adapter-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)])
             (define seq (adapter:in-pvector/index base-adapter-pvector))
             (for/fold ([sum sum]) ([(x i) seq])
               (+ sum x i)))))
  (bench 'iterate-indexed-alias-proc 'adapter-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)])
             (define seq (adapter:in-pvector-indexed base-adapter-pvector))
             (for/fold ([sum sum]) ([(x i) seq])
               (+ sum x i)))))

  (bench 'iterate-sequence 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i base-pvector])
             (+ sum i))))
  (bench 'iterate-sequence-consed 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i consed-right-pvector])
             (+ sum i)))
         #:when consed-right-pvector)
  (bench 'iterate-sequence-shifted 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i shifted-pvector])
             (+ sum i))))

  (bench 'iterate-reverse 'list
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-list base-list-reverse)])
             (+ sum i))))
  (bench 'iterate-reverse 'vector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-vector base-vector-reverse)])
             (+ sum i))))
  (bench 'iterate-reverse 'treelist
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-treelist base-treelist-reverse)])
             (+ sum i))))
  (bench 'iterate-reverse 'cutie-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (cutie:in-pvector-reverse base-cutie-pvector)])
             (+ sum i))))
  (bench 'iterate-reverse 'raw-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (raw:in-pvector-reverse base-raw-pvector)])
             (+ sum i))))
  (bench 'iterate-reverse 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-pvector-reverse base-pvector)])
             (+ sum i))))
  (bench 'iterate-reverse 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (unsafe:unsafe-in-pvector-reverse base-pvector)])
             (+ sum i))))
  (bench 'iterate-reverse-consed 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-pvector-reverse consed-right-pvector)])
             (+ sum i)))
         #:when consed-right-pvector)
  (bench 'iterate-reverse-consed 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (unsafe:unsafe-in-pvector-reverse consed-right-pvector)])
             (+ sum i)))
         #:when consed-right-pvector)
  (bench 'iterate-reverse-proc 'adapter-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)])
             (define seq (adapter:in-pvector-reverse base-adapter-pvector))
             (for/fold ([sum sum]) ([i seq])
               (+ sum i)))))
  (bench 'iterate-reverse-proc 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)])
             (define seq (in-pvector-reverse base-pvector))
             (for/fold ([sum sum]) ([i seq])
               (+ sum i)))))
  (bench 'iterate-reverse-proc 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)])
             (define seq (unsafe:unsafe-in-pvector-reverse base-pvector))
             (for/fold ([sum sum]) ([i seq])
               (+ sum i)))))
  (bench 'iterate-reverse-proc-consed 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)])
             (define seq (in-pvector-reverse consed-right-pvector))
             (for/fold ([sum sum]) ([i seq])
               (+ sum i))))
         #:when consed-right-pvector)
  (bench 'iterate-reverse-proc-consed 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)])
             (define seq (unsafe:unsafe-in-pvector-reverse consed-right-pvector))
             (for/fold ([sum sum]) ([i seq])
               (+ sum i))))
         #:when consed-right-pvector)
  (bench 'iterate-reverse-proc-shifted 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)])
             (define seq (in-pvector-reverse shifted-pvector))
             (for/fold ([sum sum]) ([i seq])
               (+ sum i)))))
  (bench 'iterate-reverse-proc-shifted 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)])
             (define seq (unsafe:unsafe-in-pvector-reverse shifted-pvector))
             (for/fold ([sum sum]) ([i seq])
               (+ sum i)))))

  (bench 'list->seq 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (append base-list null))))
  (bench 'list->seq 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (list->vector base-list))))
  (bench 'list->seq 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (list->treelist base-list))))
  (bench 'list->seq 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (cutie:list->pvector base-list))))
  (bench 'list->seq 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (list->pvector base-list))))
  (bench 'sequence-list->seq 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector base-list))))
  (bench 'sequence-in-list->seq 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector (in-list base-list)))))

  (bench 'vector->seq 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (vector->list base-vector))))
  (bench 'vector->seq 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (vector-copy base-vector))))
  (bench 'vector->seq 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (vector->treelist base-vector))))
  (bench 'vector->seq 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (cutie:vector->pvector base-vector))))
  (bench 'vector->seq 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (vector->pvector base-vector))))
  (bench 'sequence-vector->seq 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector base-vector))))
  (bench 'sequence-in-vector->seq 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector (in-vector base-vector)))))
  (bench 'sequence-in-pvector->seq 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector (in-pvector base-pvector)))))
  (bench 'sequence-in-pvector-reverse->seq 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector (in-pvector-reverse base-pvector)))))

  (bench 'range->seq 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector (in-range n)))))
  (bench 'range-offset->seq 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector (in-range 1 (+ n 1))))))
  (bench 'range-step->seq 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector (in-range 0 (* n 2) 2)))))
  (bench 'integer->seq 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (sequence->pvector n))))

  (bench 'seq->list 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (append base-list null))))
  (bench 'seq->list 'vector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (vector->list base-vector))))
  (bench 'seq->list 'treelist
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (treelist->list base-treelist))))
  (bench 'seq->list 'cutie-pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (cutie:pvector->list base-cutie-pvector))))
  (bench 'seq->list 'raw-pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (raw:pvector->list base-raw-pvector))))
  (bench 'seq->list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (pvector->list base-pvector))))
  (bench 'seq->list 'unsafe-pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (unsafe:unsafe-pvector->list base-pvector))))

  (bench 'seq->vector 'list
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (list->vector base-list))))
  (bench 'seq->vector 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (vector-copy base-vector))))
  (bench 'seq->vector 'treelist
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (treelist->vector base-treelist))))
  (bench 'seq->vector 'cutie-pvector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (cutie:pvector->vector base-cutie-pvector))))
  (bench 'seq->vector 'raw-pvector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (raw:pvector->vector base-raw-pvector))))
  (bench 'seq->vector 'pvector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (pvector->vector base-pvector))))
  (bench 'seq->vector 'unsafe-pvector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (unsafe:unsafe-pvector->vector base-pvector))))

  (bench 'stream-list 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list base-list))))
  (bench 'stream-list 'treelist
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list base-treelist))))
  (bench 'stream-list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list base-pvector))))
  (bench 'stream-list 'unsafe-pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list base-pvector))))
  (bench 'stream-rest-singleton 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (stream-rest singleton-pvector))))
  (bench 'stream-rest-small 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (stream-rest base-pvector))))

  (bench 'stream-length 'list
         (lambda ()
           (for/fold ([r 0]) ([j (in-range m)])
             (stream-length base-list))))
  (bench 'stream-length 'treelist
         (lambda ()
           (for/fold ([r 0]) ([j (in-range m)])
             (stream-length base-treelist))))
  (bench 'stream-length 'pvector
         (lambda ()
           (for/fold ([r 0]) ([j (in-range m)])
             (stream-length base-pvector))))

  (bench 'stream-ref 'list
         (lambda ()
           (for/fold ([r #f]) ([j (in-range m)])
             (stream-ref base-list half))))
  (bench 'stream-ref 'treelist
         (lambda ()
           (for/fold ([r #f]) ([j (in-range m)])
             (stream-ref base-treelist half))))
  (bench 'stream-ref 'pvector
         (lambda ()
           (for/fold ([r #f]) ([j (in-range m)])
             (stream-ref base-pvector half))))

  (bench 'stream-tail 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream-tail base-list half))))
  (bench 'stream-tail 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (stream-tail base-treelist half))))
  (bench 'stream-tail 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (stream-tail base-pvector half))))

  (bench 'stream-take 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-take base-list half)))))
  (bench 'stream-take 'treelist
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-take base-treelist half)))))
  (bench 'stream-take 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (stream-take base-pvector half))))

  (bench 'stream-append-list 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-append left-list right-list)))))
  (bench 'stream-append-list 'treelist
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-append left-treelist right-treelist)))))
  (bench 'stream-append-list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-append left-pvector right-pvector)))))
  (bench 'stream-append-list-pvector-list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-append base-pvector base-list)))))
	  (bench 'stream-append-list-consed-list 'pvector
	         (lambda ()
	           (for/fold ([r null]) ([j (in-range m)])
	             (stream->list (stream-append consed-right-pvector base-list))))
	         #:when consed-right-pvector)
	  (bench 'stream-append-length-pvector-list 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-length (stream-append base-pvector base-list)))))
	  (bench 'stream-append-length-consed-list 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-length (stream-append consed-right-pvector base-list))))
	         #:when consed-right-pvector)
	  (bench 'stream-append-ref-pvector-list 'pvector
	         (lambda ()
	           (for/fold ([r #f]) ([j (in-range m)])
	             (stream-ref (stream-append base-pvector base-list) half))))
	  (bench 'stream-append-ref-consed-list 'pvector
	         (lambda ()
	           (for/fold ([r #f]) ([j (in-range m)])
	             (stream-ref (stream-append consed-right-pvector base-list) half)))
	         #:when consed-right-pvector)
	  (bench 'stream-append-tail-list-pvector-list 'pvector
	         (lambda ()
	           (for/fold ([r null]) ([j (in-range m)])
	             (stream->list (stream-tail (stream-append base-pvector base-list)
	                                        half)))))
	  (bench 'stream-append-tail-list-consed-list 'pvector
	         (lambda ()
	           (for/fold ([r null]) ([j (in-range m)])
	             (stream->list (stream-tail (stream-append consed-right-pvector
	                                                        base-list)
	                                        half))))
	         #:when consed-right-pvector)
	  (bench 'stream-append-take-list-pvector-list 'pvector
	         (lambda ()
	           (for/fold ([r null]) ([j (in-range m)])
	             (stream->list (stream-take (stream-append base-pvector base-list)
	                                        half)))))
	  (bench 'stream-append-take-list-consed-list 'pvector
	         (lambda ()
	           (for/fold ([r null]) ([j (in-range m)])
	             (stream->list (stream-take (stream-append consed-right-pvector
	                                                        base-list)
	                                        half))))
	         #:when consed-right-pvector)
	  (bench 'stream-append-count-even-pvector-list 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-count even? (stream-append base-pvector base-list)))))
	  (bench 'stream-append-count-even-consed-list 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-count even? (stream-append consed-right-pvector
	                                                base-list))))
	         #:when consed-right-pvector)
	  (bench 'stream-append-fold-sum-pvector-list 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-fold + 0 (stream-append base-pvector base-list)))))
	  (bench 'stream-append-fold-sum-consed-list 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-fold + 0 (stream-append consed-right-pvector
	                                             base-list))))
	         #:when consed-right-pvector)
	  (bench 'stream-append-for-each-sum-pvector-list 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (define sum 0)
	             (stream-for-each (lambda (v) (set! sum (+ sum v)))
	                              (stream-append base-pvector base-list))
	             sum)))
	  (bench 'stream-append-for-each-sum-consed-list 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (define sum 0)
	             (stream-for-each (lambda (v) (set! sum (+ sum v)))
	                              (stream-append consed-right-pvector
	                                             base-list))
	             sum))
	         #:when consed-right-pvector)
	  (bench 'stream-append-andmap-integer-pvector-list 'pvector
	         (lambda ()
	           (for/fold ([r #t]) ([j (in-range m)])
	             (stream-andmap exact-integer?
	                            (stream-append base-pvector base-list)))))
	  (bench 'stream-append-andmap-integer-consed-list 'pvector
	         (lambda ()
	           (for/fold ([r #t]) ([j (in-range m)])
	             (stream-andmap exact-integer?
	                            (stream-append consed-right-pvector
	                                           base-list))))
	         #:when consed-right-pvector)
	  (bench 'stream-append-ormap-last-pvector-list 'pvector
	         (lambda ()
	           (for/fold ([r #f]) ([j (in-range m)])
	             (stream-ormap (lambda (v) (and (= v (sub1 n)) v))
	                           (stream-append base-pvector base-list)))))
	  (bench 'stream-append-ormap-last-consed-list 'pvector
	         (lambda ()
	           (for/fold ([r #f]) ([j (in-range m)])
	             (stream-ormap (lambda (v) (and (= v (sub1 n)) v))
	                           (stream-append consed-right-pvector
	                                          base-list))))
	         #:when consed-right-pvector)

	  (bench 'stream-add-between-list 'list
	         (lambda ()
	           (for/fold ([r null]) ([j (in-range m)])
	             (stream->list (stream-add-between base-list 'x)))))
  (bench 'stream-add-between-list 'treelist
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-add-between base-treelist 'x)))))
  (bench 'stream-add-between-list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-add-between base-pvector 'x)))))
  (bench 'stream-add-between-list-consed 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-add-between consed-right-pvector 'x))))
         #:when consed-right-pvector)
  (bench 'stream-add-between 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (stream-add-between base-pvector 'x))))
  (bench 'stream-add-between-consed 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (stream-add-between consed-right-pvector 'x)))
         #:when consed-right-pvector)

  (bench 'stream-map-values-list 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-map values base-list)))))
  (bench 'stream-map-values-list 'treelist
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-map values base-treelist)))))
  (bench 'stream-map-values-list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-map values base-pvector)))))
  (bench 'stream-map-values-list-consed 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-map values consed-right-pvector))))
         #:when consed-right-pvector)

  (bench 'stream-map-void-list 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-map void base-list)))))
  (bench 'stream-map-void-list 'treelist
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-map void base-treelist)))))
  (bench 'stream-map-void-list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-map void base-pvector)))))
  (bench 'stream-map-void-list-consed 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-map void consed-right-pvector))))
         #:when consed-right-pvector)

  (bench 'stream-map-add1-list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-map add1 base-pvector)))))
	  (bench 'stream-map-add1-list-consed 'pvector
	         (lambda ()
	           (for/fold ([r null]) ([j (in-range m)])
	             (stream->list (stream-map add1 consed-right-pvector))))
	         #:when consed-right-pvector)
	  (bench 'stream-map-add1-length 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-length (stream-map add1 base-pvector)))))
	  (bench 'stream-map-add1-length-consed 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-length (stream-map add1 consed-right-pvector))))
	         #:when consed-right-pvector)
	  (bench 'stream-map-add1-ref 'pvector
	         (lambda ()
	           (for/fold ([r #f]) ([j (in-range m)])
	             (stream-ref (stream-map add1 base-pvector) half))))
	  (bench 'stream-map-add1-ref-consed 'pvector
	         (lambda ()
	           (for/fold ([r #f]) ([j (in-range m)])
	             (stream-ref (stream-map add1 consed-right-pvector) half)))
	         #:when consed-right-pvector)
	  (bench 'stream-map-add1-tail-list 'pvector
	         (lambda ()
	           (for/fold ([r null]) ([j (in-range m)])
	             (stream->list (stream-tail (stream-map add1 base-pvector)
	                                        half)))))
	  (bench 'stream-map-add1-tail-list-consed 'pvector
	         (lambda ()
	           (for/fold ([r null]) ([j (in-range m)])
	             (stream->list (stream-tail (stream-map add1 consed-right-pvector)
	                                        half))))
	         #:when consed-right-pvector)
	  (bench 'stream-map-add1-take-list 'pvector
	         (lambda ()
	           (for/fold ([r null]) ([j (in-range m)])
	             (stream->list (stream-take (stream-map add1 base-pvector)
	                                        half)))))
	  (bench 'stream-map-add1-take-list-consed 'pvector
	         (lambda ()
	           (for/fold ([r null]) ([j (in-range m)])
	             (stream->list (stream-take (stream-map add1 consed-right-pvector)
	                                        half))))
	         #:when consed-right-pvector)
	  (bench 'stream-map-add1-count-even 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-count even? (stream-map add1 base-pvector)))))
	  (bench 'stream-map-add1-count-even-consed 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-count even? (stream-map add1 consed-right-pvector))))
	         #:when consed-right-pvector)
	  (bench 'stream-map-add1-fold-sum 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-fold + 0 (stream-map add1 base-pvector)))))
	  (bench 'stream-map-add1-fold-sum-consed 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-fold + 0 (stream-map add1 consed-right-pvector))))
	         #:when consed-right-pvector)
	  (bench 'stream-map-add1-for-each-sum 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (define sum 0)
	             (stream-for-each (lambda (v) (set! sum (+ sum v)))
	                              (stream-map add1 base-pvector))
	             sum)))
	  (bench 'stream-map-add1-for-each-sum-consed 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (define sum 0)
	             (stream-for-each (lambda (v) (set! sum (+ sum v)))
	                              (stream-map add1 consed-right-pvector))
	             sum))
	         #:when consed-right-pvector)
	  (bench 'stream-map-add1-andmap-positive 'pvector
	         (lambda ()
	           (for/fold ([r #t]) ([j (in-range m)])
	             (stream-andmap positive? (stream-map add1 base-pvector)))))
	  (bench 'stream-map-add1-andmap-positive-consed 'pvector
	         (lambda ()
	           (for/fold ([r #t]) ([j (in-range m)])
	             (stream-andmap positive?
	                            (stream-map add1 consed-right-pvector))))
	         #:when consed-right-pvector)
	  (bench 'stream-map-add1-ormap-last 'pvector
	         (lambda ()
	           (for/fold ([r #f]) ([j (in-range m)])
	             (stream-ormap (lambda (v) (and (= v n) v))
	                           (stream-map add1 base-pvector)))))
	  (bench 'stream-map-add1-ormap-last-consed 'pvector
	         (lambda ()
	           (for/fold ([r #f]) ([j (in-range m)])
	             (stream-ormap (lambda (v) (and (= v n) v))
	                           (stream-map add1 consed-right-pvector))))
	         #:when consed-right-pvector)

	  (bench 'stream-filter-values-list 'list
	         (lambda ()
	           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-filter values base-filter-list)))))
  (bench 'stream-filter-values-list 'treelist
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-filter values base-filter-treelist)))))
  (bench 'stream-filter-values-list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-filter values base-filter-pvector)))))
  (bench 'stream-filter-values 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (stream-filter values base-filter-pvector))))
  (bench 'stream-filter-values-all-list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-filter values base-pvector)))))
  (bench 'stream-filter-values-all 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (stream-filter values base-pvector))))
  (bench 'stream-filter-values-all-consed-list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-filter values consed-right-pvector))))
         #:when consed-right-pvector)
  (bench 'stream-filter-values-all-consed 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (stream-filter values consed-right-pvector)))
         #:when consed-right-pvector)
  (bench 'stream-filter-values-none-list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-filter values base-false-pvector)))))
  (bench 'stream-filter-values-none 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (stream-filter values base-false-pvector))))
  (bench 'stream-filter-values-alt-consed-list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-filter values consed-filter-pvector))))
         #:when consed-filter-pvector)
  (bench 'stream-filter-values-alt-consed 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (stream-filter values consed-filter-pvector)))
         #:when consed-filter-pvector)

  (bench 'stream-filter-even-list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-filter even? base-pvector)))))
	  (bench 'stream-filter-even-list-consed 'pvector
	         (lambda ()
	           (for/fold ([r null]) ([j (in-range m)])
	             (stream->list (stream-filter even? consed-right-pvector))))
	         #:when consed-right-pvector)
	  (bench 'stream-filter-even-length 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-length (stream-filter even? base-pvector)))))
	  (bench 'stream-filter-even-length-consed 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-length (stream-filter even? consed-right-pvector))))
	         #:when consed-right-pvector)
	  (bench 'stream-filter-even-count-values 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-count values (stream-filter even? base-pvector)))))
	  (bench 'stream-filter-even-count-values-consed 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-count values
	                           (stream-filter even? consed-right-pvector))))
	         #:when consed-right-pvector)
	  (bench 'stream-filter-even-ref 'pvector
	         (lambda ()
	           (for/fold ([r #f]) ([j (in-range m)])
	             (stream-ref (stream-filter even? base-pvector) quarter))))
	  (bench 'stream-filter-even-ref-consed 'pvector
	         (lambda ()
	           (for/fold ([r #f]) ([j (in-range m)])
	             (stream-ref (stream-filter even? consed-right-pvector) quarter)))
	         #:when consed-right-pvector)
	  (bench 'stream-filter-even-take-list 'pvector
	         (lambda ()
	           (for/fold ([r null]) ([j (in-range m)])
	             (stream->list (stream-take (stream-filter even? base-pvector)
	                                        quarter)))))
	  (bench 'stream-filter-even-take-list-consed 'pvector
	         (lambda ()
	           (for/fold ([r null]) ([j (in-range m)])
	             (stream->list (stream-take (stream-filter even?
	                                                        consed-right-pvector)
	                                        quarter))))
	         #:when consed-right-pvector)
	  (bench 'stream-filter-even-take-count-values 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-count values
	                           (stream-take (stream-filter even? base-pvector)
	                                        quarter)))))
	  (bench 'stream-filter-even-take-count-values-consed 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-count values
	                           (stream-take
	                            (stream-filter even? consed-right-pvector)
	                            quarter))))
	         #:when consed-right-pvector)
	  (bench 'stream-filter-even-fold-sum 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-fold + 0 (stream-filter even? base-pvector)))))
	  (bench 'stream-filter-even-fold-sum-consed 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-fold + 0
	                          (stream-filter even? consed-right-pvector))))
	         #:when consed-right-pvector)
	  (bench 'stream-filter-even-take-fold-sum 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-fold + 0
	                          (stream-take (stream-filter even? base-pvector)
	                                       quarter)))))
	  (bench 'stream-filter-even-take-fold-sum-consed 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (stream-fold
	              + 0
	              (stream-take (stream-filter even? consed-right-pvector)
	                           quarter))))
	         #:when consed-right-pvector)
	  (bench 'stream-filter-even-for-each-sum 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (define sum 0)
	             (stream-for-each (lambda (v) (set! sum (+ sum v)))
	                              (stream-filter even? base-pvector))
	             sum)))
	  (bench 'stream-filter-even-for-each-sum-consed 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (define sum 0)
	             (stream-for-each
	              (lambda (v) (set! sum (+ sum v)))
	              (stream-filter even? consed-right-pvector))
	             sum))
	         #:when consed-right-pvector)
	  (bench 'stream-filter-even-take-for-each-sum 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (define sum 0)
	             (stream-for-each
	              (lambda (v) (set! sum (+ sum v)))
	              (stream-take (stream-filter even? base-pvector)
	                           quarter))
	             sum)))
	  (bench 'stream-filter-even-take-for-each-sum-consed 'pvector
	         (lambda ()
	           (for/fold ([r 0]) ([j (in-range m)])
	             (define sum 0)
	             (stream-for-each
	              (lambda (v) (set! sum (+ sum v)))
	              (stream-take (stream-filter even? consed-right-pvector)
	                           quarter))
	             sum))
	         #:when consed-right-pvector)
	  (bench 'stream-filter-even-andmap-even 'pvector
	         (lambda ()
	           (for/fold ([r #t]) ([j (in-range m)])
	             (stream-andmap even? (stream-filter even? base-pvector)))))
	  (bench 'stream-filter-even-andmap-even-consed 'pvector
	         (lambda ()
	           (for/fold ([r #t]) ([j (in-range m)])
	             (stream-andmap even?
	                            (stream-filter even? consed-right-pvector))))
	         #:when consed-right-pvector)
	  (bench 'stream-filter-even-ormap-last 'pvector
	         (lambda ()
	           (for/fold ([r #f]) ([j (in-range m)])
	             (stream-ormap (lambda (v) (and (= v (- n 2)) v))
	                           (stream-filter even? base-pvector)))))
	  (bench 'stream-filter-even-ormap-last-consed 'pvector
	         (lambda ()
	           (for/fold ([r #f]) ([j (in-range m)])
	             (stream-ormap (lambda (v) (and (= v (- n 2)) v))
	                           (stream-filter even? consed-right-pvector))))
	         #:when consed-right-pvector)
	  (bench 'stream-filter-even-take-andmap-even 'pvector
	         (lambda ()
	           (for/fold ([r #t]) ([j (in-range m)])
	             (stream-andmap even?
	                            (stream-take
	                             (stream-filter even? base-pvector)
	                             quarter)))))
	  (bench 'stream-filter-even-take-andmap-even-consed 'pvector
	         (lambda ()
	           (for/fold ([r #t]) ([j (in-range m)])
	             (stream-andmap even?
	                            (stream-take
	                             (stream-filter even? consed-right-pvector)
	                             quarter))))
	         #:when consed-right-pvector)
	  (bench 'stream-filter-even-tail-list 'pvector
	         (lambda ()
	           (for/fold ([r null]) ([j (in-range m)])
	             (stream->list (stream-tail (stream-filter even? base-pvector)
	                                        quarter)))))
	  (bench 'stream-filter-even-tail-list-consed 'pvector
	         (lambda ()
	           (for/fold ([r null]) ([j (in-range m)])
	             (stream->list (stream-tail (stream-filter even?
	                                                        consed-right-pvector)
	                                        quarter))))
	         #:when consed-right-pvector)
	  (bench 'stream-filter-all-list 'pvector
	         (lambda ()
	           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-filter exact-integer? base-pvector)))))
  (bench 'stream-filter-none-list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-filter even? base-odd-pvector)))))

  (bench 'stream-filter-void-list 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-filter void base-list)))))
  (bench 'stream-filter-void-list 'treelist
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-filter void base-treelist)))))
  (bench 'stream-filter-void-list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list (stream-filter void base-pvector)))))

  (bench 'stream-andmap-values 'list
         (lambda ()
           (for/fold ([r #t]) ([j (in-range m)])
             (stream-andmap values base-list))))
  (bench 'stream-andmap-values 'treelist
         (lambda ()
           (for/fold ([r #t]) ([j (in-range m)])
             (stream-andmap values base-treelist))))
  (bench 'stream-andmap-values 'pvector
         (lambda ()
           (for/fold ([r #t]) ([j (in-range m)])
             (stream-andmap values base-pvector))))

  (bench 'stream-andmap-void 'list
         (lambda ()
           (for/fold ([r #t]) ([j (in-range m)])
             (stream-andmap void base-list))))
  (bench 'stream-andmap-void 'treelist
         (lambda ()
           (for/fold ([r #t]) ([j (in-range m)])
             (stream-andmap void base-treelist))))
  (bench 'stream-andmap-void 'pvector
         (lambda ()
           (for/fold ([r #t]) ([j (in-range m)])
             (stream-andmap void base-pvector))))

  (bench 'stream-ormap-values 'list
         (lambda ()
           (for/fold ([r #f]) ([j (in-range m)])
             (stream-ormap values base-filter-list))))
  (bench 'stream-ormap-values 'treelist
         (lambda ()
           (for/fold ([r #f]) ([j (in-range m)])
             (stream-ormap values base-filter-treelist))))
  (bench 'stream-ormap-values 'pvector
         (lambda ()
           (for/fold ([r #f]) ([j (in-range m)])
             (stream-ormap values base-filter-pvector))))

  (bench 'stream-ormap-void 'list
         (lambda ()
           (for/fold ([r #f]) ([j (in-range m)])
             (stream-ormap void base-list))))
  (bench 'stream-ormap-void 'treelist
         (lambda ()
           (for/fold ([r #f]) ([j (in-range m)])
             (stream-ormap void base-treelist))))
  (bench 'stream-ormap-void 'pvector
         (lambda ()
           (for/fold ([r #f]) ([j (in-range m)])
             (stream-ormap void base-pvector))))

  (bench 'stream-for-each-sum 'list
         (lambda ()
           (for/fold ([total 0]) ([j (in-range m)])
             (define sum 0)
             (stream-for-each (lambda (v) (set! sum (+ sum v))) base-list)
             (+ total sum))))
  (bench 'stream-for-each-sum 'treelist
         (lambda ()
           (for/fold ([total 0]) ([j (in-range m)])
             (define sum 0)
             (stream-for-each (lambda (v) (set! sum (+ sum v))) base-treelist)
             (+ total sum))))
  (bench 'stream-for-each-sum 'pvector
         (lambda ()
           (for/fold ([total 0]) ([j (in-range m)])
             (define sum 0)
             (stream-for-each (lambda (v) (set! sum (+ sum v))) base-pvector)
             (+ total sum))))
  (bench 'stream-for-each-sum-consed 'pvector
         (lambda ()
           (for/fold ([total 0]) ([j (in-range m)])
             (define sum 0)
             (stream-for-each
              (lambda (v) (set! sum (+ sum v)))
              consed-right-pvector)
             (+ total sum)))
         #:when consed-right-pvector)

  (bench 'stream-for-each-void 'list
         (lambda ()
           (for/fold ([r (void)]) ([j (in-range m)])
             (stream-for-each void base-list))))
  (bench 'stream-for-each-void 'treelist
         (lambda ()
           (for/fold ([r (void)]) ([j (in-range m)])
             (stream-for-each void base-treelist))))
  (bench 'stream-for-each-void 'pvector
         (lambda ()
           (for/fold ([r (void)]) ([j (in-range m)])
             (stream-for-each void base-pvector))))
  (bench 'stream-for-each-void-consed 'pvector
         (lambda ()
           (for/fold ([r (void)]) ([j (in-range m)])
             (stream-for-each void consed-right-pvector)))
         #:when consed-right-pvector)

  (bench 'stream-fold-sum 'list
         (lambda ()
           (for/fold ([r 0]) ([j (in-range m)])
             (stream-fold + 0 base-list))))
  (bench 'stream-fold-sum 'treelist
         (lambda ()
           (for/fold ([r 0]) ([j (in-range m)])
             (stream-fold + 0 base-treelist))))
  (bench 'stream-fold-sum 'pvector
         (lambda ()
           (for/fold ([r 0]) ([j (in-range m)])
             (stream-fold + 0 base-pvector))))

  (bench 'stream-fold-void 'list
         (lambda ()
           (for/fold ([r (void)]) ([j (in-range m)])
             (stream-fold void 'init base-list))))
  (bench 'stream-fold-void 'treelist
         (lambda ()
           (for/fold ([r (void)]) ([j (in-range m)])
             (stream-fold void 'init base-treelist))))
  (bench 'stream-fold-void 'pvector
         (lambda ()
           (for/fold ([r (void)]) ([j (in-range m)])
             (stream-fold void 'init base-pvector))))

  (bench 'stream-count-even 'list
         (lambda ()
           (for/fold ([r 0]) ([j (in-range m)])
             (stream-count even? base-list))))
  (bench 'stream-count-even 'treelist
         (lambda ()
           (for/fold ([r 0]) ([j (in-range m)])
             (stream-count even? base-treelist))))
  (bench 'stream-count-even 'pvector
         (lambda ()
           (for/fold ([r 0]) ([j (in-range m)])
             (stream-count even? base-pvector))))

  (bench 'stream-count-values 'list
         (lambda ()
           (for/fold ([r 0]) ([j (in-range m)])
             (stream-count values base-filter-list))))
  (bench 'stream-count-values 'treelist
         (lambda ()
           (for/fold ([r 0]) ([j (in-range m)])
             (stream-count values base-filter-treelist))))
  (bench 'stream-count-values 'pvector
         (lambda ()
           (for/fold ([r 0]) ([j (in-range m)])
             (stream-count values base-filter-pvector))))

  (bench 'stream-count-void 'list
         (lambda ()
           (for/fold ([r 0]) ([j (in-range m)])
             (stream-count void base-list))))
  (bench 'stream-count-void 'treelist
         (lambda ()
           (for/fold ([r 0]) ([j (in-range m)])
             (stream-count void base-treelist))))
  (bench 'stream-count-void 'pvector
         (lambda ()
           (for/fold ([r 0]) ([j (in-range m)])
             (stream-count void base-pvector))))

  (bench 'stream-andmap 'list
         (lambda ()
           (for/fold ([r #t]) ([j (in-range m)])
             (stream-andmap exact-integer? base-list))))
  (bench 'stream-andmap 'treelist
         (lambda ()
           (for/fold ([r #t]) ([j (in-range m)])
             (stream-andmap exact-integer? base-treelist))))
  (bench 'stream-andmap 'pvector
         (lambda ()
           (for/fold ([r #t]) ([j (in-range m)])
             (stream-andmap exact-integer? base-pvector))))

  (bench 'stream-ormap 'list
         (lambda ()
           (for/fold ([r #f]) ([j (in-range m)])
             (stream-ormap (lambda (v) (= v (sub1 n))) base-list))))
  (bench 'stream-ormap 'treelist
         (lambda ()
           (for/fold ([r #f]) ([j (in-range m)])
             (stream-ormap (lambda (v) (= v (sub1 n))) base-treelist))))
  (bench 'stream-ormap 'pvector
         (lambda ()
           (for/fold ([r #f]) ([j (in-range m)])
             (stream-ormap (lambda (v) (= v (sub1 n))) base-pvector))))
  )

(module+ main
  (measure M N))
