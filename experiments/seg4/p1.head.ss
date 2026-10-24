;; ===== P1: whole-graph fasl roundtrip of a real module instance =====
;; Pure-Chez head: everything here is defined BEFORE importing Racket layers.
(for-each load
  (list "/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/src/build/cs/c/chezpart.so"
        "/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/src/build/cs/c/rumble.so"
        "/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/src/build/cs/c/thread.so"
        "/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/src/build/cs/c/io.so"
        "/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/src/build/cs/c/regexp.so"
        "/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/src/build/cs/c/schemify.so"
        "/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/src/build/cs/c/linklet.so"
        "/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/src/build/cs/c/expander.so"))

;; --- Chez introspection wrappers (captured while environment is clean) ---
(define ($clen p) (#%$closure-length p))
(define ($cref p i) (#%$closure-ref p i))
(define ($ccode p) (#%$closure-code p))
(define ($rec? x) (#%$record? x))
(define ($rtd x) (#%$record-type-descriptor x))
(define ($rref r i) (#%$record-ref r i))
(define ($cont? x) (#%$continuation? x))
(define ($code? x) (#%$code? x))
(define ($stvec? x) (#%$stencil-vector? x))   ; any stencil vector (incl. system)
(define ($stlen x) (#%$stencil-vector-length x))
(define ($stref x i) (#%$stencil-vector-ref x i))

;; Clean I/O + misc captured for later use (Racket io shadows these after import)
(define c-oof open-output-file)
(define c-disp display)
(define c-wr write)
(define c-nl newline)
(define c-flush flush-output-port)
(define c-fmt format)
(define c-faslw fasl-write)
(define c-faslr fasl-read)
(define c-obvop open-bytevector-output-port)
(define c-obvip open-bytevector-input-port)
(define c-arity procedure-arity-mask)
(define c-dispcond display-condition)
(define c-oos open-output-string)
(define c-gos get-output-string)
(define c-sort sort)

;; guarded evaluation
(define (try th fv)
  (call/cc (lambda (k)
    (with-exception-handler (lambda (e) (k fv)) th))))

(define (safe-clen p) (try (lambda () ($clen p)) #f))

(define ($cname p) ; code-name of a closure, guarded
  (try (lambda () (#%$code-name ($ccode p))) 'ANON))

(define (code-name c) (try (lambda () (#%$code-name c)) 'ANON))

(define (rtd-name x)
  (let ([n (record-type-name ($rtd x))])
    (if (symbol? n) n (string->symbol (c-fmt "~a" n)))))

(define (rtd-total-fields rtd)
  (let loop ([r rtd] [n 0])
    (if r (loop (record-type-parent r) (fx+ n (vector-length (record-type-field-names r)))) n)))

;; ---- classification ----
(define (obj-category x)
  (cond
    [($code? x) 'code]
    [(procedure? x)
     (cond
       [($cont? x) 'continuation]
       [(safe-clen x) 'closure]
       [else 'opaque-procedure])]
    [(hashtable? x)
     (cond [(eq-hashtable? x) 'eq-hashtable]
           [(symbol-hashtable? x) 'symbol-hashtable]
           [else 'other-chez-hashtable])]
    [($rec? x) (string->symbol (string-append "rec:" (symbol->string (rtd-name x))))]
    [(and (pair? x) (weak-pair? x)) 'weak-pair]
    [(and (pair? x) (ephemeron-pair? x)) 'ephemeron-pair]
    [(pair? x) 'pair]
    [($stvec? x) 'stencil-vector]
    [(vector? x) 'vector]
    [(fxvector? x) 'fxvector]
    [(flvector? x) 'flvector]
    [(box? x) 'box]
    [(port? x) 'chez-port]
    [(bytevector? x) 'bytevector]
    [(string? x) 'string]
    [(symbol? x) (if (gensym? x) 'gensym 'symbol)]
    [(char? x) 'char]
    [(number? x) 'number]
    [(boolean? x) 'boolean]
    [(null? x) 'null]
    [(eof-object? x) 'eof]
    [(eq? x (void)) 'void]
    [else 'other]))

;; heap object worth descending / graphing
(define (heapish? x)
  (or (procedure? x) ($rec? x) (pair? x) (vector? x) (box? x) (hashtable? x)
      ($stvec? x)))

;; ---- children enumeration for the census BFS (with pruning, as in R2) ----
(define stop-descend-rec-names
  '(module linklet linklet-bundle linklet-directory faslable-correlated-linklet
    wrapped-code compiled-in-memory
    syntax correlated correlated-object
    scope multi-scope representative-scope interned-scope
    binding module-binding local-binding
    provided prefab-key
    code))

(define (rec-stop? x)
  (and ($rec? x) (memq (rtd-name x) stop-descend-rec-names) #t))

(define (children obj prune?)
  (cond
    [(procedure? obj)
     (cond
       [($cont? obj) '()]
       [(safe-clen obj)
        => (lambda (n)
             (let loop ([i 0] [acc '()])
               (if (fx>= i n) (reverse acc)
                   (loop (fx+ i 1) (cons ($cref obj i) acc)))))]
       [else '()])]
    [(hashtable? obj)
     (let ([ks (hashtable-keys obj)])
       (let loop ([i 0] [acc '()])
         (if (fx>= i (vector-length ks)) acc
             (let ([k (vector-ref ks i)])
               (loop (fx+ i 1)
                     (cons k (cons (hashtable-ref obj k #f) acc)))))))]
    [(and prune? (rec-stop? obj)) '()]
    [($rec? obj)
     (let ([n (rtd-total-fields ($rtd obj))])
       (let loop ([i 0] [acc '()])
         (if (fx>= i n) (reverse acc)
             (loop (fx+ i 1)
                   (cons (try (lambda () ($rref obj i)) 'UNREADABLE) acc)))))]
    [(pair? obj) (list (car obj) (cdr obj))]
    [($stvec? obj)
     (let ([n ($stlen obj)])
       (let loop ([i 0] [acc '()])
         (if (fx>= i n) (reverse acc)
             (loop (fx+ i 1) (cons (try (lambda () ($stref obj i)) 'UNREADABLE) acc)))))]
    [(box? obj) (list (unbox obj))]
    [(vector? obj)
     (let ([n (vector-length obj)])
       (let loop ([i 0] [acc '()])
         (if (fx>= i n) (reverse acc)
             (loop (fx+ i 1) (cons (vector-ref obj i) acc)))))]
    [else '()]))

;; ---- generic BFS collecting instance records (pruned walk) ----
(define (find-instances root)
  (define visited (make-eq-hashtable))
  (define instances '())
  (define qfront (list root))
  (define qback '())
  (define (enq! x) (set! qback (cons x qback)))
  (define (deq!) (when (null? qfront) (set! qfront (reverse qback)) (set! qback '()))
    (let ([x (car qfront)]) (set! qfront (cdr qfront)) x))
  (define (q-empty?) (and (null? qfront) (null? qback)))
  (eq-hashtable-set! visited root #t)
  (let bfs ([n 0])
    (unless (q-empty?)
      (let ([obj (deq!)])
        (when (and ($rec? obj) (not (hashtable? obj)) (eq? (rtd-name obj) 'instance))
          (set! instances (cons obj instances)))
        (for-each (lambda (child)
                    (when (and (not (eq? child 'UNREADABLE)) (heapish? child)
                               (not (eq-hashtable-ref visited child #f)))
                      (eq-hashtable-set! visited child #t)
                      (enq! child)))
                  (children obj #t))
        (bfs (fx+ n 1)))))
  (reverse instances))

;; ---- instance accessors (instance record: name=0 data=1 hash=2) ----
(define (inst-name inst) (try (lambda () ($rref inst 0)) 'NONAME))
(define (inst-name-str inst) (c-fmt "~a" (inst-name inst)))
(define (inst-data inst) (try (lambda () ($rref inst 1)) 'NODATA))

(define (inst-eq-ht inst)  ; the Chez eq-hashtable inside the Racket hash record
  (let ([h (try (lambda () ($rref inst 2)) #f)])
    (and h ($rec? h)
         (let ([n (rtd-total-fields ($rtd h))])
           (let loop ([i 0])
             (cond
               [(fx>= i n) #f]
               [(let ([f (try (lambda () ($rref h i)) #f)])
                  (and (hashtable? f) f))]
               [else (loop (fx+ i 1))]))))))

(define (inst-vars inst)  ; -> list of (sym . variable-record), sorted by symbol name
  (let ([ht (inst-eq-ht inst)])
    (if ht
        (c-sort (lambda (a b) (string<? (c-fmt "~a" (car a)) (c-fmt "~a" (car b))))
                (map (lambda (k) (cons k (hashtable-ref ht k #f)))
                     (vector->list (hashtable-keys ht))))
        '())))

(define (var-val var) (try (lambda () ($rref var 0)) 'UNREADABLE))

(define (closure-val? v) (and (procedure? v) (not ($cont? v)) (safe-clen v) #t))
(define (capturing-closure? v) (and (closure-val? v) (fx> ($clen v) 0)))
