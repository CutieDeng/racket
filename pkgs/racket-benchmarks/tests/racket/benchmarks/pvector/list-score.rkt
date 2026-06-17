#lang racket/base

(require racket/cmdline
         racket/list
         racket/pvector
         (prefix-in adapter: racket/private/pvector-runtime-adapter)
         racket/string
         racket/treelist
         racket/vector)

(define M 100)
(define target-ms 15)
(define max-m 1000000)
(define max-size 1024)
(define explicit-sizes #f)
(define impl-names '(list vector treelist pvector adapter-pvector))
(define cutie-module
  (string->path "/Users/cutiedeng/Y2026/M03/D28/cutie-ftree.rkt/pvector.rkt"))
(define ops #f)
(define baseline-name 'list)
(define speed-score-weight 0.7)
(define cost-score-weight 0.3)

;; The academic-clean profile is a direct-interface score for a clean
;; engineering baseline: each implementation is called through its concrete
;; operations, and the cost side models the necessary result shape instead of
;; rewarding accidental wrapper, cache, or representation shortcuts. Use this
;; score to justify representation changes only when the benefit survives
;; across the power-of-two size distribution.
(define score-profile-name 'academic-clean)
(define size-weight-model 'equal-per-power-size)
(define operation-weight-model 'equal-per-operation-within-size)
(define interface-model-name 'direct-concrete-interface)
(define speed-metric-name 'real-ns/op)
(define cost-model-name 'academic-result-cost)
(define cost-metric-name 'academic-result-cost-units/op)
(define speed-ratio-model-name 'baseline/target)
(define cost-ratio-model-name 'zero-aware-add1-baseline/target)
(define run-racket-version (version))
(define run-vm (system-type 'vm))
(define run-machine (system-type 'machine))
(define run-os (system-type 'os))
(define run-jit-enabled (if (eval-jit-enabled) 'yes 'no))

(define default-ops
  '(build length sum ref-first ref-middle ref-last
          cons-left cons-right append-self take-half drop-half map-add1 to-list))

(define (parse-count who s)
  (define n (string->number s))
  (unless (exact-positive-integer? n)
    (raise-user-error who "expected a positive exact integer, got ~e" s))
  n)

(define (parse-size who s)
  (define n (string->number s))
  (unless (exact-nonnegative-integer? n)
    (raise-user-error who "expected a nonnegative exact integer, got ~e" s))
  n)

(define (parse-nonnegative-integer who s)
  (define n (string->number s))
  (unless (exact-nonnegative-integer? n)
    (raise-user-error who "expected a nonnegative exact integer, got ~e" s))
  n)

(define (parse-nonnegative-real who s)
  (define n (string->number s))
  (unless (and (real? n) (not (negative? n)))
    (raise-user-error who "expected a nonnegative real number, got ~e" s))
  n)

(define (parse-size-list who s)
  (for/list ([part (in-list (string-split s ","))]
             #:unless (string=? part ""))
    (parse-size who part)))

(define (parse-symbol-list s)
  (for/list ([part (in-list (string-split s ","))]
             #:unless (string=? part ""))
    (string->symbol part)))

(define (power-sizes limit)
  (define powers
    (let loop ([n 1] [acc null])
      (if (> n limit)
          (reverse acc)
          (loop (* n 2) (cons n acc)))))
  (cons 0 powers))

(command-line
 #:program "pvector-list-score"
 #:once-each
 [("--m") n "Initial/minimum repeat count per operation"
          (set! M (parse-count '--m n))]
 [("--target-ms") n "Auto-scale repeats until each detail row reaches this many real milliseconds; 0 disables auto-scaling"
                  (set! target-ms (parse-nonnegative-integer '--target-ms n))]
 [("--max-m") n "Maximum auto-scaled repeat count per operation"
              (set! max-m (parse-count '--max-m n))]
 [("--max-size") n "Largest generated power-of-two size"
                 (set! max-size (parse-count '--max-size n))]
 [("--sizes") s "Explicit comma-separated sizes; overrides --max-size"
              (set! explicit-sizes (parse-size-list '--sizes s))]
 [("--impls") s "Comma-separated implementations: list,vector,treelist,cutie-pvector,pvector,adapter-pvector"
              (set! impl-names (parse-symbol-list s))]
 [("--cutie-module") p "Path to the original cutie-ftree pvector.rkt"
                     (set! cutie-module (string->path p))]
 [("--ops") s "Comma-separated operations"
           (set! ops (parse-symbol-list s))]
 [("--baseline") s "Primary scoring baseline implementation"
                 (set! baseline-name (string->symbol s))]
 [("--speed-weight") n "Composite score weight for speed"
                     (set! speed-score-weight
                           (parse-nonnegative-real '--speed-weight n))]
 [("--cost-weight") n "Composite score weight for retained-result cost"
                    (set! cost-score-weight
                          (parse-nonnegative-real '--cost-weight n))])

(when (zero? (+ speed-score-weight cost-score-weight))
  (raise-user-error 'pvector-list-score
                    "speed and cost weights cannot both be zero"))

(define (score-method-label)
  (format "weighted-geomean(speed=~a,cost=~a;speed-ratio=~a;cost-ratio=~a)"
          speed-score-weight
          cost-score-weight
          speed-ratio-model-name
          cost-ratio-model-name))

(define sizes
  (or explicit-sizes (power-sizes max-size)))

(define enabled-ops
  (or ops default-ops))

(define (enabled-impl? name)
  (memq name impl-names))

(define (vector-cons-left vec value)
  (define len (vector-length vec))
  (define out (make-vector (add1 len)))
  (vector-set! out 0 value)
  (vector-copy! out 1 vec 0 len)
  out)

(define (vector-cons-right vec value)
  (define len (vector-length vec))
  (define out (make-vector (add1 len)))
  (vector-copy! out 0 vec 0 len)
  (vector-set! out len value)
  out)

(struct impl
  (name build length ref sum cons-left cons-right append take drop map to-list)
  #:transparent)

(struct row
  (size op impl iterations cpu-ms real-ms real-ns/op gc-ms live-bytes
        cost-model generated-result-cost-units result-cost-units/op result
        weight)
  #:transparent)

(define current-repeat-count (make-parameter M))

(define cutie-pvector? (lambda (_) #f))
(define cutie-pvector-length
  (lambda (v)
    (error 'cutie-pvector-length "cutie pvector support has not been loaded")))

(define (load-cutie name)
  (dynamic-require cutie-module name))

(define list-impl
  (impl 'list
        (lambda (len)
          (for/list ([i (in-range len)]) i))
        length
        list-ref
        (lambda (xs)
          (for/fold ([sum 0]) ([x (in-list xs)]) (+ sum x)))
        cons
        (lambda (value xs) (append xs (list value)))
        append
        take
        drop
        (lambda (xs proc) (map proc xs))
        values))

(define vector-impl
  (impl 'vector
        (lambda (len)
          (for/vector #:length len ([i (in-range len)]) i))
        vector-length
        vector-ref
        (lambda (vec)
          (for/fold ([sum 0]) ([x (in-vector vec)]) (+ sum x)))
        (lambda (value vec) (vector-cons-left vec value))
        (lambda (value vec) (vector-cons-right vec value))
        vector-append
        (lambda (vec pos) (vector-copy vec 0 pos))
        (lambda (vec pos) (vector-copy vec pos))
        (lambda (vec proc) (vector-map proc vec))
        vector->list))

(define treelist-impl
  (impl 'treelist
        (lambda (len)
          (for/treelist ([i (in-range len)]) i))
        treelist-length
        treelist-ref
        (lambda (tl)
          (for/fold ([sum 0]) ([x (in-treelist tl)]) (+ sum x)))
        (lambda (value tl) (treelist-cons tl value))
        (lambda (value tl) (treelist-add tl value))
        treelist-append
        treelist-take
        treelist-drop
        treelist-map
        treelist->list))

(define pvector-impl
  (impl 'pvector
        (lambda (len)
          (for/pvector ([i (in-range len)]) i))
        pvector-length
        pvector-ref
        (lambda (pv)
          (for/fold ([sum 0]) ([x (in-pvector pv)]) (+ sum x)))
        (lambda (value pv) (pvector-cons-left pv value))
        (lambda (value pv) (pvector-cons-right pv value))
        pvector-append
        pvector-take
        pvector-drop
        pvector-map
        pvector->list))

(define adapter-pvector-impl
  (impl 'adapter-pvector
        (lambda (len)
          (adapter:for/pvector ([i (in-range len)]) i))
        adapter:pvector-length
        adapter:pvector-ref
        (lambda (pv)
          (for/fold ([sum 0]) ([x (adapter:in-pvector pv)]) (+ sum x)))
        (lambda (value pv) (adapter:pvector-cons-left pv value))
        (lambda (value pv) (adapter:pvector-cons-right pv value))
        adapter:pvector-append
        adapter:pvector-take
        adapter:pvector-drop
        adapter:pvector-map
        adapter:pvector->list))

(define (make-cutie-pvector-impl)
  (define cutie:pvector? (load-cutie 'pvector?))
  (define cutie:pvector-empty (load-cutie 'pvector-empty))
  (define cutie:pvector-length* (load-cutie 'pvector-length))
  (define cutie:pvector-ref (load-cutie 'pvector-ref))
  (define cutie:pvector-cons-left (load-cutie 'pvector-cons-left))
  (define cutie:pvector-cons-right (load-cutie 'pvector-cons-right))
  (define cutie:pvector-append (load-cutie 'pvector-append))
  (define cutie:pvector-take (load-cutie 'pvector-take))
  (define cutie:pvector-drop (load-cutie 'pvector-drop))
  (define cutie:pvector->list (load-cutie 'pvector->list))
  (define cutie:in-pvector (load-cutie 'in-pvector))
  (set! cutie-pvector? cutie:pvector?)
  (set! cutie-pvector-length cutie:pvector-length*)
  (impl 'cutie-pvector
        (lambda (len)
          (for/fold ([pv (cutie:pvector-empty)]) ([i (in-range len)])
            (cutie:pvector-cons-right pv i)))
        cutie:pvector-length*
        cutie:pvector-ref
        (lambda (pv)
          (for/fold ([sum 0]) ([x (cutie:in-pvector pv)]) (+ sum x)))
        (lambda (value pv) (cutie:pvector-cons-left pv value))
        (lambda (value pv) (cutie:pvector-cons-right pv value))
        cutie:pvector-append
        cutie:pvector-take
        cutie:pvector-drop
        (lambda (pv proc)
          (for/fold ([out (cutie:pvector-empty)]) ([x (cutie:in-pvector pv)])
            (cutie:pvector-cons-right out (proc x))))
        cutie:pvector->list))

(define (available-impls)
  (list list-impl
        vector-impl
        treelist-impl
        (and (enabled-impl? 'cutie-pvector)
             (make-cutie-pvector-impl))
        pvector-impl
        adapter-pvector-impl))

(define selected-impls
  (for/list ([candidate (in-list (available-impls))]
             #:when (and candidate
                         (enabled-impl? (impl-name candidate))))
    candidate))

(define (repeat-result m proc)
  (for/fold ([result #f]) ([i (in-range m)])
    (proc i)))

(define (summarize-result result)
  (cond
    [(list? result) (format "list:~a" (length result))]
    [(vector? result) (format "vector:~a" (vector-length result))]
    [(treelist? result) (format "treelist:~a" (treelist-length result))]
    [(cutie-pvector? result)
     (format "cutie-pvector:~a" (cutie-pvector-length result))]
    [(pvector? result) (format "pvector:~a" (pvector-length result))]
    [(adapter:pvector? result)
     (format "adapter-pvector:~a" (adapter:pvector-length result))]
    [else (format "~s" result)]))

(define (pvector-academic-cost-units len)
  (cond
    [(zero? len) 0]
    [(= len 1) 2]
    [else
     (define digit-slots (min len 8))
     (define middle-slots (max 0 (- len digit-slots)))
     (+ 3 digit-slots (ceiling (/ (* middle-slots 3) 2)))]))

(define (adapter-pvector-cost-units pv)
  (define stats (adapter:pvector-shape-stats pv))
  (case (hash-ref stats 'representation #f)
    [(empty) 0]
    [(single) 2]
    [(large-finger)
     (+ 1
        (hash-ref stats 'digit-vectors 0)
        (hash-ref stats 'prefix-length 0)
        (hash-ref stats 'suffix-length 0)
        (* 3 (hash-ref stats 'node2 0))
        (* 4 (hash-ref stats 'node3 0))
        (* 2 (hash-ref stats 'payload-vectors 0)))]
    [else (pvector-academic-cost-units (adapter:pvector-length pv))]))

(define (academic-result-cost-units result)
  (cond
    [(list? result) (* 3 (length result))]
    [(vector? result) (+ 1 (vector-length result))]
    [(treelist? result) (+ 1 (treelist-length result))]
    [(cutie-pvector? result)
     (pvector-academic-cost-units (cutie-pvector-length result))]
    [(pvector? result) (pvector-academic-cost-units (pvector-length result))]
    [(adapter:pvector? result) (adapter-pvector-cost-units result)]
    [else 0]))

(define (real-ns/op real-ms iterations)
  (/ (* real-ms 1000000.0) iterations))

(define (measure-speed iterations op-proc)
  (collect-garbage)
  (collect-garbage)
  (define before-bytes (current-memory-use))
  (define start-ms (current-inexact-monotonic-milliseconds))
  (define-values (vals cpu real gc)
    (parameterize ([current-repeat-count iterations])
      (time-apply
       (lambda ()
         (repeat-result (current-repeat-count) op-proc))
       null)))
  (define real* (- (current-inexact-monotonic-milliseconds) start-ms))
  (define result (if (pair? vals) (car vals) (void)))
  (define cost-units (academic-result-cost-units result))
  (collect-garbage)
  (define after-bytes (current-memory-use))
  (values cpu
          real*
          (real-ns/op real* iterations)
          gc
          (- after-bytes before-bytes)
          cost-units
          (summarize-result result)))

(define (measure-row size op imp iterations op-proc)
  (define-values (cpu real real/op gc live cost-units result)
    (measure-speed iterations op-proc))
  (row size
       op
       (impl-name imp)
       iterations
       cpu
       real
       real/op
       gc
       live
       cost-model-name
       (* iterations cost-units)
       cost-units
       result
       1.0))

(define (next-iteration-count r)
  (define iterations (row-iterations r))
  (define real-ms (row-real-ms r))
  (cond
    [(zero? real-ms) (min max-m (* iterations 10))]
    [else
     (min max-m
          (max (* iterations 2)
               (inexact->exact
                (ceiling (* iterations (/ target-ms real-ms))))))]))

(define (bench size op imp op-proc)
  (let loop ([iterations M])
    (define r (measure-row size op imp iterations op-proc))
    (if (or (zero? target-ms)
            (>= (row-real-ms r) target-ms)
            (>= iterations max-m))
        r
        (loop (next-iteration-count r)))))

(define (row-key size op impl-name)
  (list size op impl-name))

(define rows-by-key (make-hash))
(define rows null)

(define (add-row! r)
  (set! rows (cons r rows))
  (hash-set! rows-by-key
             (row-key (row-size r) (row-op r) (row-impl r))
             r))

(define (enabled-for-size? op size)
  (case op
    [(ref-first ref-middle ref-last) (> size 0)]
    [else #t]))

(define (make-op-proc size op imp base)
  (define half (quotient size 2))
  (define last-index (sub1 size))
  (case op
    [(build)
     (lambda (_) ((impl-build imp) size))]
    [(length)
     (lambda (_) ((impl-length imp) base))]
    [(sum)
     (lambda (_) ((impl-sum imp) base))]
    [(ref-first)
     (lambda (_) ((impl-ref imp) base 0))]
    [(ref-middle)
     (lambda (_) ((impl-ref imp) base half))]
    [(ref-last)
     (lambda (_) ((impl-ref imp) base last-index))]
    [(cons-left)
     (lambda (i) ((impl-cons-left imp) (- i) base))]
    [(cons-right)
     (lambda (i) ((impl-cons-right imp) (- i) base))]
    [(append-self)
     (lambda (_) ((impl-append imp) base base))]
    [(take-half)
     (lambda (_) ((impl-take imp) base half))]
    [(drop-half)
     (lambda (_) ((impl-drop imp) base half))]
    [(map-add1)
     (lambda (_) ((impl-map imp) base add1))]
    [(to-list)
     (lambda (_) ((impl-to-list imp) base))]
    [else
     (raise-user-error 'pvector-list-score "unknown operation: ~e" op)]))

(define (run-op size op imp base)
  (define op-proc (make-op-proc size op imp base))
  (bench size op imp op-proc))

(define (safe-positive n)
  (max 1 n))

(define (speed-score-ratio baseline-value target-value)
  (/ (safe-positive baseline-value)
     (safe-positive target-value)))

(define (cost-score-ratio baseline-value target-value)
  (/ (add1 baseline-value)
     (add1 target-value)))

(define (row-score r baseline metric)
  (and r
       baseline
       (case metric
         [(speed) (speed-score-ratio (row-real-ns/op baseline)
                                     (row-real-ns/op r))]
         [(cost) (cost-score-ratio (row-result-cost-units/op baseline)
                                   (row-result-cost-units/op r))])))

(define (composite-score speed-score cost-score)
  (and speed-score
       cost-score
       (positive? speed-score)
       (positive? cost-score)
       (exp (/ (+ (* speed-score-weight (log speed-score))
                  (* cost-score-weight (log cost-score)))
               (+ speed-score-weight cost-score-weight)))))

(define (format-number v)
  (cond
    [(not v) ""]
    [(integer? v) (number->string v)]
    [else (real->decimal-string v 4)]))

(define (score-values score-samples)
  (define weighted-logs
    (for/list ([sample (in-list score-samples)])
      (and sample
           (positive? (cdr sample))
           (cons (car sample) (log (cdr sample))))))
  (define samples (filter values weighted-logs))
  (if (null? samples)
      #f
      (exp (/ (for/sum ([sample (in-list samples)])
                (* (car sample) (cdr sample)))
              (for/sum ([sample (in-list samples)])
                (car sample))))))

(define (size-power-label size)
  (cond
    [(zero? size) "zero"]
    [else
     (let loop ([n size] [power 0])
       (cond
         [(= n 1) (format "2^~a" power)]
         [(even? n) (loop (quotient n 2) (add1 power))]
         [else (format "n=~a" size)]))]))

(define (size-band-label size)
  (cond
    [(zero? size) "empty"]
    [(= size 1) "single"]
    [(<= size 8) "tiny"]
    [(<= size 64) "small"]
    [(<= size 512) "medium"]
    [else "large"]))

(define (baseline-row r baseline)
  (hash-ref rows-by-key
            (row-key (row-size r) (row-op r) baseline)
            #f))

(define (power-scores impl-name size baseline)
  (define impl-rows
    (for/list ([r (in-list rows)]
               #:when (and (eq? (row-impl r) impl-name)
                           (= (row-size r) size)))
      r))
  (define speed
    (score-values
     (for/list ([r (in-list impl-rows)])
       (define b (baseline-row r baseline))
       (define s (row-score r b 'speed))
       (and s (cons (row-weight r) s)))))
  (define cost
    (score-values
     (for/list ([r (in-list impl-rows)])
       (define b (baseline-row r baseline))
       (define s (row-score r b 'cost))
       (and s (cons (row-weight r) s)))))
  (values speed cost (composite-score speed cost) (length impl-rows)))

(define (all-power-scores impl-name baseline)
  (for/list ([size (in-list sizes)])
    (define-values (speed cost total samples)
      (power-scores impl-name size baseline))
    (and total
         (list size speed cost total samples))))

(define (total-scores impl-name baseline)
  (define power-samples
    (filter values (all-power-scores impl-name baseline)))
  (define speed
    (score-values
     (for/list ([sample (in-list power-samples)])
       (cons 1.0 (list-ref sample 1)))))
  (define cost
    (score-values
     (for/list ([sample (in-list power-samples)])
       (cons 1.0 (list-ref sample 2)))))
  (values speed
          cost
          (composite-score speed cost)
          (length power-samples)))

(unless (enabled-impl? baseline-name)
  (raise-user-error 'pvector-list-score
                    "baseline implementation ~e is not enabled"
                    baseline-name))

(for ([size (in-list sizes)])
  (for ([imp (in-list selected-impls)])
    (define base ((impl-build imp) size))
    (for ([op (in-list enabled-ops)]
          #:when (enabled-for-size? op size))
      (add-row! (run-op size op imp base)))))

(define (cell->string v)
  (cond
    [(not v) ""]
    [(number? v) (format-number v)]
    [else (format "~a" v)]))

(define (emit-row cells)
  (displayln (string-join (map cell->string cells) "\t")))

(define run-metadata-header
  '("racket-version" "vm" "machine" "os" "jit-enabled"))

(define run-metadata-cells
  (list run-racket-version
        run-vm
        run-machine
        run-os
        run-jit-enabled))

(define (emit-data-row cells)
  (emit-row (append cells run-metadata-cells)))

(define (power-score-result impl-name size baseline)
  (define-values (speed cost total samples)
    (power-scores impl-name size baseline))
  (list speed cost total samples))

(define (total-score-result impl-name baseline)
  (define-values (speed cost total samples)
    (total-scores impl-name baseline))
  (list speed cost total samples))

(emit-row
 (append
  '("kind" "size" "power" "band" "op" "impl" "iterations" "cpu-ms"
    "real-ms" "real-ns/op" "gc-ms" "live-bytes" "cost-model"
    "generated-result-cost-units" "result-cost-units/op" "result" "baseline"
    "speed-score/list" "speed-score/vector" "cost-score/list"
    "cost-score/vector" "speed-score" "cost-score"
    "total-score" "sample-count" "weight" "score-profile" "size-weight-model"
    "operation-weight-model" "interface-model" "score-method" "speed-metric"
    "cost-metric")
  run-metadata-header))

(for ([r (in-list (reverse rows))])
  (define list-row
    (hash-ref rows-by-key (row-key (row-size r) (row-op r) 'list) #f))
  (define vector-row
    (hash-ref rows-by-key (row-key (row-size r) (row-op r) 'vector) #f))
  (define primary-row (baseline-row r baseline-name))
  (define speed-score (row-score r primary-row 'speed))
  (define cost-score (row-score r primary-row 'cost))
  (emit-data-row
   (list 'detail
         (row-size r)
         (size-power-label (row-size r))
         (size-band-label (row-size r))
         (row-op r)
         (row-impl r)
         (row-iterations r)
         (row-cpu-ms r)
         (row-real-ms r)
         (row-real-ns/op r)
         (row-gc-ms r)
         (row-live-bytes r)
         (row-cost-model r)
         (row-generated-result-cost-units r)
         (row-result-cost-units/op r)
         (row-result r)
         baseline-name
         (row-score r list-row 'speed)
         (row-score r vector-row 'speed)
         (row-score r list-row 'cost)
         (row-score r vector-row 'cost)
         speed-score
         cost-score
         (composite-score speed-score cost-score)
         1
         (row-weight r)
         score-profile-name
         size-weight-model
         operation-weight-model
         interface-model-name
         (score-method-label)
         speed-metric-name
         cost-metric-name)))

(for ([imp (in-list selected-impls)])
  (define name (impl-name imp))
  (for ([size (in-list sizes)])
    (define primary (power-score-result name size baseline-name))
    (define list-score (power-score-result name size 'list))
    (define vector-score (power-score-result name size 'vector))
    (when (list-ref primary 2)
      (emit-data-row
       (list 'power-score
             size
             (size-power-label size)
             (size-band-label size)
             'all
             name
             #f #f #f #f #f #f #f #f #f #f
             baseline-name
             (list-ref list-score 0)
             (list-ref vector-score 0)
             (list-ref list-score 1)
             (list-ref vector-score 1)
             (list-ref primary 0)
             (list-ref primary 1)
             (list-ref primary 2)
             (list-ref primary 3)
             1.0
             score-profile-name
             size-weight-model
             operation-weight-model
             interface-model-name
             (score-method-label)
             speed-metric-name
             cost-metric-name))))
  (define primary (total-score-result name baseline-name))
  (define list-score (total-score-result name 'list))
  (define vector-score (total-score-result name 'vector))
  (emit-data-row
   (list 'total-score
         'all
         'all
         'all
         'all
         name
         #f #f #f #f #f #f #f #f #f #f
         baseline-name
         (list-ref list-score 0)
         (list-ref vector-score 0)
         (list-ref list-score 1)
         (list-ref vector-score 1)
         (list-ref primary 0)
         (list-ref primary 1)
         (list-ref primary 2)
         (list-ref primary 3)
         1.0
         score-profile-name
         size-weight-model
         operation-weight-model
         interface-model-name
         (score-method-label)
         speed-metric-name
         cost-metric-name)))
