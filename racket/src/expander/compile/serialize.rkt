#lang racket/base
(require (for-syntax racket/base)
         racket/fasl
         (only-in '#%unsafe unsafe-hasheq-from-vectors unsafe-hasheqv-from-vectors)
         (only-in '#%kernel
                  core-pvector?
                  core-pvector-length
                  core-pvector-for-each
                  core-fresh-vector->pvector)
         "serialize-property.rkt"
         "serialize-state.rkt"
         "../common/set.rkt"
         "../syntax/syntax.rkt"
         "../syntax/binding-table.rkt"
         "../syntax/scope.rkt"
         "../syntax/binding.rkt"
         "../syntax/module-binding.rkt"
         "../syntax/local-binding.rkt"
         "../syntax/bulk-binding.rkt"
         "../syntax/like-ambiguous-binding.rkt"
         "../namespace/provided.rkt"
         "../common/module-path.rkt"
         "../common/module-path-intern.rkt"
         "../common/phase+space.rkt"
         "module-use.rkt"
         "../host/linklet.rkt"
         "built-in-symbol.rkt"
         "reserved-symbol.rkt")

;; Serialization is mostly for syntax objects and module path indexes.
;;
;; Serialization is implemented by a combination of direct handling
;; for some primitive datatypes, `prop:serialize` handlers attached
;; to some structure types, and deserialization functions provided
;; by the same modules as the serialization handlers.
;;
;; Module path indexes are serialized to code that runs to reconstruct
;; the module path indexes. Syntax objects and other data is
;; serialized to somewhat expression-shaped data and interpreted for
;; deserialization, where that interpretation can refer to an array of
;; already-deserialized module path indexes.
;;
;; To support sharing and cycles, serialized data is represented by:
;;
;;  - a vector of "shell" descriptions to allocate mutatable objects,
;;    such as mutable vectors and hash tables;
;;
;;  - a vector of initializations for shared, immutable values (which
;;    can refer to mutable values)
;;
;;  - a vector of "fill" descriptions to complete the construction of
;;    mutable values (which can refer to mutable and shared values);
;;    and
;;
;;  - a final value construction (which can refer to shared and
;;    mutable values).
;;
;; In general, a deserialized object is represented as a pair of a
;; symbol tag and data, including a `quote` tag to represent arbitrary
;; quoted data (that's non-cyclic and with no internal sharing). A few
;; special cases enable a more compact representation:
;;
;;  - numbers, booleans, symbols, and path srclocs are represented
;;    as themselves (i.e., self-quoting, in a sense);
;;
;;  - #&<number> is a reference to a mutable or shared value at
;;    position <number> in a deserialization array;
;;
;;  - #(<elem> ...) is a srcloc whose source is not a path
;;
;;  - #:inspector and #:bulk-binding-registry refer to
;;    instantiation-time values supplied as imported to the
;;    deserializing linklet
;;
;; In addition to all the complexities of detecting sharing and cycles
;; and breaking cycles on mutable boundaries, the serialization
;; process also prunes unreachable scopes and interns some values that
;; formerly were not shared.

(provide make-module-path-index-table
         add-module-path-index!
         add-module-path-index!/pos
         module-path-index-table-mpis
         generate-module-path-index-deserialize
         deserialize-module-path-index-data
         mpis-as-vector

         generate-module-data-linklet
         generate-module-declaration-linklet

         generate-deserialize ; i.e., `serialize`
         deserialize-data

         deserialize-instance
         deserialize-imports

         serialize-module-uses
         serialize-phase-to-link-module-uses)


;; ----------------------------------------
;; Byte-stream encoding of serialized data
;;
;; Each of the four streams produced by `generate-deserialize` is a
;; bytevector. An element starts with one byte that gives its class:
;;
;;   #x00 ..          an opcode (a `#:` tag below, by position);
;;   #x40 .. #xB7     a small integer 0..119 (value = byte - #x40);
;;   #xB8 / #xB9 / #xBA  #f / #t / '();
;;   #xBB             an exact integer: zigzag LEB128 follows;
;;   #xBC             a literal: LEB128 index into the literals vector;
;;   #xBD .. #xFF     a literal with index 0..66 (index = byte - #xBD).
;;
;; Symbols, keywords, strings, characters, and anything else that is
;; not an integer or a tag live in one literals vector per
;; serialization, so a stream contains no objects of its own, and
;; interning a repeated symbol happens once instead of per use.
;;
;; The streams are mutable byte strings on purpose: schemify keeps a
;; mutable byte string in the code's own fasl stream (see
;; `register-literal-serialization` in schemify's "literal.rkt"),
;; while an immutable one would count as a reader literal to intern
;; and would be lifted into the `racket/fasl` literals. The
;; previous encoding was a vector per stream whose every element was a
;; separate object (tags and repeated symbols as fasl graph
;; references); reading those vectors dominated the cost of loading a
;; module's declaration and syntax-literal data.

(begin-for-syntax
  (define opcode-list
    '(#:ref #:inspector #:bulk-binding-registry #:syntax #:datum->syntax
      #:syntax+props #:srcloc #:quote #:mpi #:box #:cons #:list #:vector
      #:pvector #:hash #:hasheq #:hasheqv #:hasheqv/phase+space #:set
      #:seteq #:seteqv #:prefab #:scope #:scope+kind #:interned-scope
      #:multi-scope #:shifted-multi-scope #:table-with-bulk-bindings
      #:bulk-binding-at #:representative-scope #:module-binding
      #:simple-module-binding #:local-binding #:bulk-binding
      #:like-ambiguous-binding #:bulk-binding+provides #:provided
      #:set-box! #:set-vector! #:set-hash! #:scope-fill!
      #:representative-scope-fill! #:srcloc/source))
  (define (opcode-of kw)
    (let loop ([l opcode-list] [i 0])
      (cond
        [(null? l) (raise-syntax-error 'case-op "unknown opcode" kw)]
        [(eq? (car l) kw) i]
        [else (loop (cdr l) (add1 i))]))))

;; `(make-opcode-table)` => hasheq from tag to opcode number; built
;; from individual keyword literals, because the expander's flattener
;; cannot lift a keyword out of a quoted vector
(define-syntax (make-opcode-table stx)
  (syntax-case stx ()
    [(_) (with-syntax ([((kw i) ...) (for/list ([kw (in-list opcode-list)] [i (in-naturals)])
                                       (list kw i))])
           #'(hasheq-from-pairs (list (cons (quote kw) i) ...)))]))

;; `(op-code #:tag)` => the opcode number
(define-syntax (op-code stx)
  (syntax-case stx ()
    [(_ kw) (datum->syntax stx (opcode-of (syntax-e #'kw)))]))

;; `(case-op b [(#:tag ...) body ...] ... [else body ...])`
(define-syntax (case-op stx)
  (syntax-case stx (else)
    [(_ e [(kw ...) body ...] ... [else ebody ...])
     (with-syntax ([((n ...) ...)
                    (map (lambda (kws) (map (lambda (k) (opcode-of (syntax-e k))) (syntax->list kws)))
                         (syntax->list #'((kw ...) ...)))])
       #'(case e [(n ...) body ...] ... [else ebody ...]))]))

(define (hasheq-from-pairs l)
  (for/hasheq ([p (in-list l)]) (values (car p) (cdr p))))
(define opcode-table (make-opcode-table))

;; A tag in the not-yet-encoded stream
(struct tag-elem (kw) #:authentic)

(define SMALL-BASE #x40)
(define SMALL-LIMIT 120)
(define FALSE-BYTE #xB8)
(define TRUE-BYTE #xB9)
(define NULL-BYTE #xBA)
(define INT-BYTE #xBB)
(define LIT-BYTE #xBC)
(define LIT-BASE #xBD)
(define LIT-LIMIT 67)

(define (write-uint n out)
  (let loop ([n n])
    (cond
      [(< n #x80) (write-byte n out)]
      [else
       (write-byte (bitwise-ior #x80 (bitwise-and n #x7F)) out)
       (loop (arithmetic-shift n -7))])))

(define (zigzag n)
  (if (< n 0)
      (- -1 (* 2 n))
      (* 2 n)))

(define (unzigzag n)
  (if (odd? n)
      (- -1 (arithmetic-shift n -1))
      (arithmetic-shift n -1)))

;; ----------------------------------------
;; Module path index serialization

(struct module-path-index-table (positions intern))

(define (make-module-path-index-table)
  (module-path-index-table (make-hasheq) ; module-path-index -> pos
                           (make-module-path-index-intern-table)))

(define (add-module-path-index! mpis mpi)
  (define pos
    (add-module-path-index!/pos mpis mpi))
  (and pos
       `(unsafe-vector*-ref ,mpi-vector-id ,pos)))

(define (add-module-path-index!/pos mpis mpi)
  (cond
   [(not mpi) #f]
   [mpi
    (let ([mpi (intern-module-path-index! (module-path-index-table-intern mpis) mpi)]
          [positions (module-path-index-table-positions mpis)])
      (or (hash-ref positions mpi #f)
          (let ([pos (hash-count positions)])
            (hash-set! positions mpi pos)
            pos)))]))

(define (module-path-index-table-mpis mpis)
  (define pos->mpi
    (for/hasheqv ([(mpi pos) (in-hash (module-path-index-table-positions mpis))])
      (values pos mpi)))
  (for/vector ([i (in-range (hash-count pos->mpi))])
    (hash-ref pos->mpi i)))

(define (generate-module-path-index-deserialize mpis
                                                #:as-data? [as-data? #f])
  (define (unique-list v)
    (if (pair? v)
        (for/list ([i (in-list v)]) i) ; avoid non-deterministic sharing
        v))
  (define positions (module-path-index-table-positions mpis))
  (define gen-order (make-hasheqv))
  (define rev-positions
    (for/hasheqv ([(k v) (in-hash positions)])
      (values v k)))
  ;; Create mpis used earlier first:
  (for ([i (in-range (hash-count rev-positions))])
    (define mpi (hash-ref rev-positions i))
    (let loop ([mpi mpi])
      (unless (hash-ref gen-order mpi #f)
        (define-values (name base) (module-path-index-split mpi))
        (when base
          (loop base))
        (hash-set! gen-order mpi (hash-count gen-order)))))
  (define rev-gen-order
    (for/hasheqv ([(k v) (in-hash gen-order)])
      (values v k)))
  (define gens
    (for/vector #:length (hash-count gen-order) ([i (in-range (hash-count gen-order))])
      (define mpi (hash-ref rev-gen-order i))
      (define-values (path base) (module-path-index-split mpi))
      (cond
       [(top-level-module-path-index? mpi)
        'top]
       [(not path)
        (box (or (unique-list
                  (resolved-module-path-name
                   (module-path-index-resolved mpi)))
                 'self))]
       [(not base)
        (vector path)]
       [base
        (vector path (hash-ref gen-order base))])))
  (define reorder-vec
    (for/vector ([i (in-range (hash-count rev-positions))])
      (hash-ref gen-order (hash-ref rev-positions i))))
  (cond
    [as-data? (vector gens reorder-vec)]
    [else
     `(deserialize-module-path-indexes
       ;; Vector of deserialization instructions, where earlier
       ;; must be constructed first:
       ',gens
       ;; Vector of reordering to match reference order:
       ',reorder-vec)]))

(define (deserialize-module-path-indexes gen-vec order-vec)
  (define gen (make-vector (vector-length gen-vec) #f))
  (for ([d (in-vector gen-vec)]
        [i (in-naturals)])
    (vector-set!
     gen
     i
     (cond
      [(eq? d 'top) (deserialize-module-path-index)]
      [(box? d) (deserialize-module-path-index (unbox d))]
      [else
       (deserialize-module-path-index (vector*-ref d 0)
                                      (and ((vector*-length d) . > . 1)
                                           (vector*-ref gen (vector*-ref d 1))))])))
  (for/vector #:length (vector-length order-vec) ([p (in-vector order-vec)])
              (vector*-ref gen p)))

(define (deserialize-module-path-index-data v)
  (unless (and (vector? v) (= 2 (vector-length v)))
    (error 'syntax-deserialize "ill-formed serialization"))
  (deserialize-module-path-indexes (vector-ref v 0) (vector-ref v 1)))

(define (mpis-as-vector mpis)
  (define positions (module-path-index-table-positions mpis))
  (define vec (make-vector (hash-count positions) #f))
  (for ([(mpi pos) (in-hash positions)])
    (vector-set! vec pos mpi))
  vec)

;; Convert `let*` into chunks of `let` as much as possible
(define (make-let* bindings body)
  (let loop ([vars #hasheq()] [group null] [bindings bindings])
    (cond
     [(null? bindings) `(let-values ,(reverse group) ,body)]
     [(has-symbol? (cadar bindings) vars)
      `(let-values ,(reverse group) ,(loop #hasheq() null bindings))]
     [else
      (loop (hash-set vars (caaar bindings) #t)
            (cons (car bindings) group)
            (cdr bindings))])))

(define (has-symbol? d vars)
  (or (and (symbol? d) (hash-ref vars d #f))
      (and (pair? d)
           (or (has-symbol? (car d) vars)
               (has-symbol? (cdr d) vars)))))

;; ----------------------------------------

(define (generate-module-data-linklet mpis)
  `(linklet
    ;; imports
    (,deserialize-imports)
    ;; exports
    (,mpi-vector-id)
    ;; body
    (define-values (,inspector-id) (current-code-inspector))
    (define-values (,mpi-vector-id)
      ,(generate-module-path-index-deserialize mpis))))

(define (generate-module-declaration-linklet mpis self requires recur-requires flattened-requires provides
                                             phase-to-link-module-uses-expr
                                             portal-stxes)
  `(linklet
    ;; imports
    (,deserialize-imports
     [,mpi-vector-id])
    ;; exports
    (self-mpi
     requires
     recur-requires 
     flattened-requires
     provides
     phase-to-link-modules
     portal-stxes)
    ;; body
    (define-values (self-mpi) ,(add-module-path-index! mpis self))
    (define-values (requires) ,(generate-deserialize requires #:mpis mpis #:syntax-support? #f))
    (define-values (recur-requires) (quote ,recur-requires))
    (define-values (flattened-requires) ,(if flattened-requires
                                             (generate-deserialize flattened-requires #:mpis mpis
                                                                   #:syntax-support? #f)
                                             '(quote #f)))
    (define-values (provides) ,(generate-deserialize provides #:mpis mpis #:syntax-support? #f
                                                     #:phase+space-hasheqv provides))
    (define-values (phase-to-link-modules) ,phase-to-link-module-uses-expr)
    (define-values (portal-stxes) (quote ,portal-stxes))))

;; ----------------------------------------
;; Module-use serialization --- as an expression, like module path
;; indexes, and unlike everything else

(define (serialize-module-uses mus mpis)
  (for/list ([mu (in-list mus)])
    `(module-use
      ,(add-module-path-index! mpis (module-use-module mu))
      ,(module-use-phase mu))))

(define (interned-literal? v)
  (or (null? v)
      (boolean? v)
      (and (fixnum? v)
           (v . < . (sub1 (expt 2 30)))
           (v . > . (- (expt 2 30))))
      (symbol? v)
      (char? v)
      (keyword? v)))

(define (serialize-phase-to-link-module-uses phase-to-link-module-uses mpis)
  (define phases-in-order (sort (hash-keys phase-to-link-module-uses) <))
  `(hasheqv ,@(apply
               append
               (for/list ([phase (in-list phases-in-order)])
                 (list phase `(list ,@(serialize-module-uses (hash-ref phase-to-link-module-uses phase)
                                                             mpis)))))))

;; ----------------------------------------
;; Serialization for everything else

(define (generate-deserialize v
                              #:mpis mpis
                              #:as-data? [as-data? #f]
                              #:syntax-support? [syntax-support? #t]
                              #:preserve-prop-keys [preserve-prop-keys #hasheq()]
                              #:keep-provides? [keep-provides? #f]
                              #:phase+space-hasheqv [phase+space-hasheqv #f] ; keys of this value must be interned
                              #:map-mpi [map-mpi (lambda (mpi) mpi)]
                              #:map-binding-symbol [map-binding-symbol (lambda (mpi sym phase) (values sym phase))]
                              #:report-mpi-shifts [report-mpi-shifts #f])
  (define bulk-shifts (and keep-provides? (list (make-hasheq))))

  (define-values (reachable-scopes implicitly-reachable-scopes)
    (find-reachable-scopes v bulk-shifts report-mpi-shifts))

  (define state (make-serialize-state reachable-scopes
                                      implicitly-reachable-scopes
                                      preserve-prop-keys
                                      (and keep-provides?
                                           (lambda (b)
                                             (define name (hash-ref (car bulk-shifts) b #f))
                                             (or (not name) ; shouldn't happen
                                                 (keep-provides? name))))
                                      (and report-mpi-shifts #t)
                                      map-binding-symbol))

  (define mutables (make-hasheq)) ; v -> pos
  (define objs (make-hasheq))     ; v -> step
  (define shares (make-hasheq))   ; v -> #t
  (define binding-interns (make-hash))
  (define obj-step 0)

  (define (serialize-maybe-intern v)
    (cond
      [(module-binding? v)
       (module-binding-maybe-intern v binding-interns
                                    map-binding-symbol
                                    (lambda (mpi) (add-module-path-index!/pos mpis (map-mpi mpi))))]
      [else #f]))

  ;; Build table of sharing and mutable values
  (define frontier null)
  (define add-frontier!
    (case-lambda
      [(v) (set! frontier (cons v frontier))]
      [(kind v) (add-frontier! v)]))
  (let frontier-loop ([v v])
    (let loop ([v v])
      (cond
       [(or (interned-literal? v)
            (module-path-index? v))
        ;; no need to find sharing
        (void)]
       [(serialize-maybe-intern v)
        => (lambda (v) (loop v))]
       [(hash-ref objs v #f)
        (unless (hash-ref mutables v #f)
          (hash-set! shares v #t))]
       [else
        (cond
         [(serialize-fill!? v)
          ;; Assume no sharing in non-mutable part
          (hash-set! mutables v (hash-count mutables))
          ((serialize-fill!-ref v) v add-frontier! state)]
         [(serialize? v)
          ((serialize-ref v) v 
           (case-lambda
             [(sub-v) (loop sub-v)]
             [(kind sub-v) (loop sub-v)])
           state)]
         [(pair? v)
          (loop (car v))
          (loop (cdr v))]
         [(vector? v)
          (if (or (immutable? v)
                  (zero? (vector-length v)))
              (for ([e (in-vector v)])
                (loop e))
              (begin
                (hash-set! mutables v (hash-count mutables))
                (for ([e (in-vector v)])
                  (add-frontier! e))))]
         [(box? v)
          (if (immutable? v)
              (loop (unbox v))
              (begin
                (hash-set! mutables v (hash-count mutables))
                (add-frontier! (unbox v))))]
         [(core-pvector? v)
          ;; immutable, like a vector that needs no shell
          (core-pvector-for-each v (lambda (e) (loop e)))]
         [(hash? v)
          (if (immutable? v)
              (for ([k (in-list (sorted-hash-keys v))])
                (loop k)
                (loop (hash-ref v k)))
              (begin
                (hash-set! mutables v (hash-count mutables))
                (for ([k (in-list (sorted-hash-keys v))])
                  (add-frontier! k)
                  (add-frontier! (hash-ref v k)))))]
         [(prefab-struct-key v)
          (for ([e (in-vector (struct->vector v) 1)])
            (loop e))]
         [(srcloc? v)
          (unless (path? (srcloc-source v))
            (for ([e (in-vector (struct->vector v) 1)])
              (loop e)))]
         [else
          (void)])
        ;; `v` may already be in `objs`, but to get the order right
        ;; for unmarshaling, we need to map it to a new step number
        (hash-set! objs v obj-step)
        (set! obj-step (add1 obj-step))]))
    (unless (null? frontier)
      (define l frontier)
      (set! frontier null)
      (for ([v (in-list l)])
        (frontier-loop v))))

  ;; Map object steps to positions in a vector after mutables
  (define num-mutables (hash-count mutables))
  (define share-step-positions
    (let ([share-steps (for/list ([obj (in-hash-keys shares)])
                         (hash-ref objs obj))])
      (for/hasheqv ([step (in-list (sort share-steps <))]
                    [pos (in-naturals num-mutables)])
        (values step pos))))
  
  ;; Accumulate the serialized stream:
  (define stream null)
  (define stream-size 0)

  (define (next-push-position) stream-size)
  
  (define (quoted? pos)
    (define v (list-ref stream (- stream-size (add1 pos))))
    (or (not (tag-elem? v))
        (eq? '#:quote (tag-elem-kw v))))
  
  (define (ser-reset! pos)
    (set! stream (list-tail stream (- stream-size pos)))
    (set! stream-size pos))

  ;; One source-holder srcloc per distinct source path
  (define source-holders (make-hash))
  (define (source-holder path)
    (or (hash-ref source-holders path #f)
        (let ([h (srcloc path #f #f #f #f)])
          (hash-set! source-holders path h)
          h)))

  ;; Literals shared by all streams of this serialization
  (define lit-table (make-hash))
  (define rev-lits null)
  (define lit-count 0)
  (define (lit-index! v)
    (define key (and (or (symbol? v) (keyword? v) (char? v) (number? v)
                         (and (string? v) (immutable? v))
                         (and (bytes? v) (immutable? v))
                         (srcloc? v))
                     v))
    (cond
      [(and key (hash-ref lit-table key #f))
       => (lambda (i) i)]
      [else
       (define i lit-count)
       (when key (hash-set! lit-table key i))
       (set! rev-lits (cons v rev-lits))
       (set! lit-count (add1 lit-count))
       i]))
  (define (reap-lits!)
    (begin0
     (list->vector (reverse rev-lits))
     (set! rev-lits null)
     (set! lit-count 0)
     (set! lit-table (make-hash))))

  ;; Encode the accumulated elements into a bytevector
  (define (reap-stream!)
    (define out (open-output-bytes))
    (for ([e (in-list (reverse stream))])
      (cond
        [(tag-elem? e)
         (define kw (tag-elem-kw e))
         (cond
           [(not kw)
            ;; a `#f` tag is the "nothing to fill" marker
            (write-byte FALSE-BYTE out)]
           [else
            (write-byte (hash-ref opcode-table kw
                                  (lambda () (error 'serialize "unknown tag: ~s" kw)))
                        out)])]
        [(eq? e #f) (write-byte FALSE-BYTE out)]
        [(eq? e #t) (write-byte TRUE-BYTE out)]
        [(null? e) (write-byte NULL-BYTE out)]
        [(fixnum? e)
         (cond
           [(and (e . >= . 0) (e . < . SMALL-LIMIT))
            (write-byte (+ SMALL-BASE e) out)]
           [else
            (write-byte INT-BYTE out)
            (write-uint (zigzag e) out)])]
        [else
         (define i (lit-index! e))
         (cond
           [(i . < . LIT-LIMIT) (write-byte (+ LIT-BASE i) out)]
           [else
            (write-byte LIT-BYTE out)
            (write-uint i out)])]))
    (set! stream null)
    (set! stream-size 0)
    (get-output-bytes out #t))

  ;; Handle a reference to an object that may be shared
  ;; or mutable
  (define ser-push!
    (case-lambda
      [(v)
       (cond
        [(hash-ref shares v #f)
         (define n (hash-ref share-step-positions (hash-ref objs v)))
         (ser-push! 'tag '#:ref)
         (ser-push! 'exact n)]
        [(hash-ref mutables v #f)
         => (lambda (n)
              (ser-push! 'tag '#:ref)
              (ser-push! 'exact n))]
        [else (ser-push-encoded! v)])]
      [(kind v)
       (case kind
         [(exact)
          (set! stream (cons v stream))
          (set! stream-size (add1 stream-size))]
         [(tag)
          (ser-push! 'exact (tag-elem v))]
         [(reference)
          (cond
           [(hash-ref shares v #f)
            (define n (hash-ref share-step-positions (hash-ref objs v)))
            (ser-push! 'exact n)]
           [(hash-ref mutables v #f)
            => (lambda (n)
                 (ser-push! 'exact n))]
           [else
            (ser-push! v)])]
         [else (ser-push! v)])]))
  
  ;; Handle an immutable, not-shared (or on RHS of binding) value
  (define (ser-push-encoded! v)
    (cond
     [(serialize-maybe-intern v)
      => (lambda (v) (ser-push! v))]
     [(keyword? v)
      (ser-push! 'tag '#:quote)
      (ser-push! 'exact v)]
     [(module-path-index? v)
      (ser-push! 'tag '#:mpi)
      (ser-push! 'exact (add-module-path-index!/pos mpis (map-mpi v)))]
     [(serialize? v)
      ((serialize-ref v) v ser-push! state)]
     [(and (list? v)
           (pair? v)
           (pair? (cdr v)))
      (define start-pos (next-push-position))
      (ser-push! 'tag '#:list)
      (ser-push! 'exact (length v))
      (define all-quoted?
        (for/fold ([all-quoted? #t]) ([i (in-list v)])
          (define i-pos (next-push-position))
          (ser-push! i)
          (and all-quoted?
               (quoted? i-pos))))
      (when all-quoted?
        (ser-reset! start-pos)
        (ser-push-optional-quote!)
        (ser-push! 'exact v))]
     [(pair? v)
      (define start-pos (next-push-position))
      (ser-push! 'tag '#:cons)
      (define a-pos (next-push-position))
      (ser-push! (car v))
      (define d-pos (next-push-position))
      (ser-push! (cdr v))
      (when (and (quoted? a-pos) (quoted? d-pos))
        (ser-reset! start-pos)
        (ser-push-optional-quote!)
        (ser-push! 'exact v))]
     [(box? v)
      (define start-pos (next-push-position))
      (ser-push! 'tag '#:box)
      (define v-pos (next-push-position))
      (ser-push! (unbox v))
      (when (quoted? v-pos)
        (ser-reset! start-pos)
        (ser-push-optional-quote!)
        (ser-push! 'exact v))]
     [(vector? v)
      (define start-pos (next-push-position))
      (ser-push! 'tag '#:vector)
      (ser-push! 'exact (vector-length v))
      (define all-quoted?
        (for/fold ([all-quoted? #t]) ([i (in-vector v)])
          (define i-pos (next-push-position))
          (ser-push! i)
          (and all-quoted?
               (quoted? i-pos))))
      (when all-quoted?
        (ser-reset! start-pos)
        (ser-push-optional-quote!)
        (ser-push! 'exact v))]
     [(core-pvector? v)
      (define start-pos (next-push-position))
      (ser-push! 'tag '#:pvector)
      (ser-push! 'exact (core-pvector-length v))
      (define all-quoted? #t)
      (core-pvector-for-each v (lambda (i)
                                 (define i-pos (next-push-position))
                                 (ser-push! i)
                                 (unless (quoted? i-pos)
                                   (set! all-quoted? #f))))
      (when all-quoted?
        (ser-reset! start-pos)
        (ser-push-optional-quote!)
        (ser-push! 'exact v))]
     [(hash? v)
      (define start-pos (next-push-position))
      (define as-set? (for/and ([val (in-hash-values v)])
                        (eq? val #t)))
      (ser-push! 'tag (if as-set?
                          (cond
                           [(hash-eq? v) '#:seteq]
                           [(hash-eqv? v) '#:seteqv]
                           [else '#:set])
                          (cond
                           [(hash-eq? v) '#:hasheq]
                           [(hash-eqv? v) (if (eq? v phase+space-hasheqv)
                                              '#:hasheqv/phase+space
                                              '#:hasheqv)]
                           [else '#:hash])))
      (ser-push! 'exact (hash-count v))
      (define ks (sorted-hash-keys v))
      (define all-quoted?
        (for/fold ([all-quoted? #t]) ([k (in-list ks)])
          (define k-pos (next-push-position))
          (ser-push! k)
          (define v-pos (next-push-position))
          (unless as-set?
            (ser-push! (hash-ref v k)))
          (and all-quoted?
               (quoted? k-pos)
               (or as-set? (quoted? v-pos)))))
      (when all-quoted?
        (ser-reset! start-pos)
        (ser-push-optional-quote!)
        (ser-push! 'exact v))]
     [(prefab-struct-key v)
      => (lambda (k)
           (define vec (struct->vector v))
           (define start-pos (next-push-position))
           (ser-push! 'tag '#:prefab)
           (ser-push! 'exact k)
           (ser-push! 'exact (sub1 (vector-length vec)))
           (define all-quoted?
             (for/fold ([all-quoted? #t]) ([i (in-vector vec 1)])
               (define i-pos (next-push-position))
               (ser-push! i)
               (and all-quoted?
                    (quoted? i-pos))))
           (when all-quoted?
             (ser-reset! start-pos)
             (ser-push-optional-quote!)
             (ser-push! 'exact v)))]
     [(srcloc? v)
      (cond
        [(path? (srcloc-source v))
         ;; A module's syntax literals carry thousands of srclocs that
         ;; share one source path. Serialize them as the four location
         ;; integers in the stream plus one shared "source holder"
         ;; literal per source: a srcloc with only the source, so that
         ;; `racket/fasl` still makes the path relative or truncates it
         ;; exactly as it did when every srcloc was a literal
         (ser-push! 'tag '#:srcloc/source)
         (ser-push! 'exact (source-holder (srcloc-source v)))
         (ser-push! (srcloc-line v))
         (ser-push! (srcloc-column v))
         (ser-push! (srcloc-position v))
         (ser-push! (srcloc-span v))]
        [else
         (ser-push! 'tag '#:srcloc)
         (ser-push! (srcloc-source v))
         (ser-push! (srcloc-line v))
         (ser-push! (srcloc-column v))
         (ser-push! (srcloc-position v))
         (ser-push! (srcloc-span v))])]
     [else
      (ser-push-optional-quote!)
      (ser-push! 'exact v)]))

  ;; A no-op, but can be made to push '#:quote as a debugging aid
  (define (ser-push-optional-quote!)
    ;; (ser-push! 'tag '#:quote)
    (void))
  
  ;; Generate the shell of a mutable value --- uses a different
  ;; encoding then the one for most other purposes
  (define (ser-shell! v)
    (cond
     [(serialize-fill!? v) ((serialize-ref v) v ser-push! state)]
     [(box? v) (ser-push! 'tag '#:box)]
     [(vector? v)
      (ser-push! 'tag '#:vector)
      (ser-push! 'exact (vector-length v))]
     [(hash? v) (ser-push! 'tag (cond
                                 [(hash-eq? v) '#:hasheq]
                                 [(hash-eqv? v) '#:hasheqv]
                                 [else '#:hash]))]
     [else
      (error 'ser-shell "unknown mutable: ~e" v)]))
  
  ;; Fill in the content of a mutable shell --- also a different
  ;; encoding
  (define (ser-shell-fill! v)
    (cond
     [(serialize-fill!? v) ((serialize-fill!-ref v) v ser-push! state)]
     [(box? v)
      (ser-push! 'tag '#:set-box!)
      (ser-push! (unbox v))]
     [(vector? v)
      (ser-push! 'tag '#:set-vector!)
      (ser-push! 'exact (vector-length v))
      (for ([v (in-vector v)])
        (ser-push! v))]
     [(hash? v)
      (ser-push! 'tag '#:set-hash!)
      (ser-push! 'exact (hash-count v))
      (define ks (sorted-hash-keys v))
      (for ([k (in-list ks)])
        (ser-push! k)
        (ser-push! (hash-ref v k)))]
     [else
      (error 'ser-shell-fill "unknown mutable: ~e" v)]))
  
  ;; Prepare mutable shells, first:
  (define rev-mutables (for/hasheqv ([(k v) (in-hash mutables)])
                         (values v k)))
  (define mutable-shell-bindings
    (begin
      (for ([i (in-range (hash-count mutables))])
        (ser-shell! (hash-ref rev-mutables i)))
      (reap-stream!)))
  
  ;; Prepare shared values:
  (define rev-shares (for/hasheqv ([obj (in-hash-keys shares)])
                       (values (hash-ref share-step-positions (hash-ref objs obj))
                               obj)))
  (define shared-bindings
    (begin
      (for ([i (in-range num-mutables (+ num-mutables (hash-count shares)))])
        (ser-push-encoded! (hash-ref rev-shares i)))
      (reap-stream!)))
  
  ;; Fill in mutable values
  (define mutable-fills
    (begin
      (for ([i (in-range (hash-count mutables))])
        (ser-shell-fill! (hash-ref rev-mutables i)))
      (reap-stream!)))

  ;; Final result:
  (define result
    (begin
      (ser-push! v)
      (reap-stream!)))

  ;; The literals that the four streams refer to:
  (define lits (reap-lits!))
  
  ;; Put it all together:
  (cond
    [as-data?
     (vector (hash-count mutables)
             mutable-shell-bindings
             (hash-count shares)
             shared-bindings
             mutable-fills
             result
             lits)]
    [else
     (define (finish mutable-shell-bindings-expr shared-bindings-expr  mutable-fills-expr result-expr lits-expr)
       `(deserialize
         ,mpi-vector-id
         ,(if syntax-support? inspector-id #f)
         ,(if syntax-support? bulk-binding-registry-id #f)
         ',(hash-count mutables)
         ,mutable-shell-bindings-expr
         ',(hash-count shares)
         ,shared-bindings-expr
         ,mutable-fills-expr
         ,result-expr
         ,lits-expr))

     ;; Putting the quoted-data construction into one vector makes
     ;; it easy to specialize in some back ends to a more compact
     ;; format.
     `(let-values ([(data) ',(vector mutable-shell-bindings
                                     shared-bindings
                                     mutable-fills
                                     result
                                     lits)])
        ,(finish '(unsafe-vector*-ref data 0)
                 '(unsafe-vector*-ref data 1)
                 '(unsafe-vector*-ref data 2)
                 '(unsafe-vector*-ref data 3)
                 '(unsafe-vector*-ref data 4)))]))

(define (sorted-hash-keys ht)
  (define ks (hash-keys ht))
  (cond
   [(null? ks) ks]
   [(null? (cdr ks)) ks]
   [(andmap symbol? ks)
    (sort ks symbol<?)]
   [(andmap scope? ks)
    (sort ks scope<?)]
   [(andmap shifted-multi-scope? ks)
    (sort ks shifted-multi-scope<?)]
   [(andmap real? ks)
    (sort ks <)]
   [else
    ;; (log-error "unable to sort hash keys ~s" ks)
    ks]))

;; ----------------------------------------
;; Deserialization

;; The `deserialize` function interprets the encoding generated by
;; serialization (with hardwired calls to various deserialization
;; functions provided by other modules)

(define (deserialize mpis inspector bulk-binding-registry
                     num-mutables mutable-vec 
                     num-shared shared-vec
                     mutable-fill-vec
                     result-vec
                     [lits #f])
  (cond
    [(bytes? mutable-vec)
     (deserialize/b mpis inspector bulk-binding-registry
                    num-mutables mutable-vec num-shared shared-vec mutable-fill-vec result-vec lits)]
    [else
     (deserialize/v mpis inspector bulk-binding-registry
                    num-mutables mutable-vec num-shared shared-vec mutable-fill-vec result-vec)]))

(define (deserialize-data mpis inspector bulk-binding-registry data)
  (unless (and (vector? data) (or (= 7 (vector-length data)) (= 6 (vector-length data))))
    (error 'syntax-deserialize "ill-formed serialization"))
  (deserialize mpis inspector bulk-binding-registry
               (vector-ref data 0)
               (vector-ref data 1)
               (vector-ref data 2)
               (vector-ref data 3)
               (vector-ref data 4)
               (vector-ref data 5)
               (and (= 7 (vector-length data)) (vector-ref data 6))))

(define (deserialize/b mpis inspector bulk-binding-registry
                       num-mutables mutable-bv
                       num-shared shared-bv
                       mutable-fill-bv
                       result-bv
                       lits)
  (define shared (make-vector (+ num-mutables num-shared) 'uninit))
  ;; Make mutable shells
  (for/fold ([pos 0]) ([i (in-range num-mutables)])
    (define-values (d next-pos)
      (decode-shell mutable-bv pos mpis inspector bulk-binding-registry shared lits))
    (vector-set! shared i d)
    next-pos)
  ;; Construct shared values; note that later constructions can refer
  ;; to earlier ones
  (for/fold ([pos 0]) ([i (in-range num-mutables (+ num-mutables num-shared))])
    (define-values (d next-pos)
      (decode shared-bv pos mpis inspector bulk-binding-registry shared lits))
    (vector-set! shared i d)
    next-pos)
  ;; Fill in mutable shells
  (for/fold ([pos 0]) ([i (in-range num-mutables)]
                       [v (in-vector shared)])
    (decode-fill! v mutable-fill-bv pos mpis inspector bulk-binding-registry shared lits))
  ;; Construct the final result
  (define-values (result done-pos)
    (decode result-bv 0 mpis inspector bulk-binding-registry shared lits))
  result)

;; Read a LEB128 unsigned integer at `pos`
(define (read-uint bv pos)
  (let loop ([pos pos] [shift 0] [n 0])
    (define b (bytes-ref bv pos))
    (define n2 (bitwise-ior n (arithmetic-shift (bitwise-and b #x7F) shift)))
    (if (< b #x80)
        (values n2 (+ pos 1))
        (loop (+ pos 1) (+ shift 7) n2))))

;; An element at `pos` whose class byte is `b` and that is known not
;; to be an opcode: returns the value
(define (decode-value b bv pos lits)
  (cond
    [(< b FALSE-BYTE) (values (- b SMALL-BASE) (+ pos 1))]
    [(= b FALSE-BYTE) (values #f (+ pos 1))]
    [(= b TRUE-BYTE) (values #t (+ pos 1))]
    [(= b NULL-BYTE) (values null (+ pos 1))]
    [(= b INT-BYTE)
     (define-values (n next-pos) (read-uint bv (+ pos 1)))
     (values (unzigzag n) next-pos)]
    [(= b LIT-BYTE)
     (define-values (i next-pos) (read-uint bv (+ pos 1)))
     (values (vector*-ref lits i) next-pos)]
    [else (values (vector*-ref lits (- b LIT-BASE)) (+ pos 1))]))

;; An integer element (small or zigzag) at `pos`
(define (decode-int bv pos)
  (define b (bytes-ref bv pos))
  (cond
    [(< b FALSE-BYTE) (values (- b SMALL-BASE) (+ pos 1))]
    [else
     (define-values (n next-pos) (read-uint bv (+ pos 1)))
     (values (unzigzag n) next-pos)]))

(define (int-class? b)
  (or (and (>= b SMALL-BASE) (< b FALSE-BYTE))
      (= b INT-BYTE)))

;; Decode the construction of a mutable variable
(define (decode-shell bv pos mpis inspector bulk-binding-registry shared lits)
  (define b (bytes-ref bv pos))
  (case-op b
    [(#:box) (values (box #f) (+ pos 1))]
    [(#:vector)
     (define-values (len next-pos) (decode-int bv (+ pos 1)))
     (values (make-vector len) next-pos)]
    [(#:hash) (values (make-hasheq) (+ pos 1))]
    [(#:hasheq) (values (make-hasheq) (+ pos 1))]
    [(#:hasheqv) (values (make-hasheqv) (+ pos 1))]
    [else (decode bv pos mpis inspector bulk-binding-registry shared lits)]))

;; The decoder that is used for most purposes
(define (decode bv pos mpis inspector bulk-binding-registry shared lits)
  (define-syntax decodes
    (syntax-rules ()
      [(_ (id ...) rhs) (decodes #:pos (+ pos 1) (id ...) rhs)]
      [(_ #:pos pos () rhs) (values rhs pos)]
      [(_ #:pos pos ([#:ref id0] id ...) rhs)
       (let-values ([(id0 next-pos) (let ([b (bytes-ref bv pos)])
                                      (if (int-class? b)
                                          (let-values ([(i next-pos) (decode-int bv pos)])
                                            (values (vector*-ref shared i) next-pos))
                                          (decode bv pos mpis inspector bulk-binding-registry shared lits)))])
         (decodes #:pos next-pos (id ...) rhs))]
      [(_ #:pos pos (id0 id ...) rhs)
       (let-values ([(id0 next-pos) (decode bv pos mpis inspector bulk-binding-registry shared lits)])
         (decodes #:pos next-pos (id ...) rhs))]))
  (define-syntax-rule (decode* (deser id ...))
    (decodes (id ...) (deser id ...)))
  (define b (bytes-ref bv pos))
  (cond
    [(>= b SMALL-BASE)
     (decode-value b bv pos lits)]
    [else
     (case-op b
       [(#:ref)
        (define-values (i next-pos) (decode-int bv (+ pos 1)))
        (values (vector*-ref shared i) next-pos)]
       [(#:inspector) (values inspector (+ pos 1))]
       [(#:bulk-binding-registry) (values bulk-binding-registry (+ pos 1))]
       [(#:syntax)
        (decodes
         (content [#:ref context] [#:ref srcloc])
         (deserialize-syntax content
                             context
                             srcloc
                             #f
                             #f
                             inspector))]
       [(#:datum->syntax)
        (decodes
         (content [#:ref context] [#:ref srcloc])
         (deserialize-datum->syntax content
                                    context
                                    srcloc
                                    inspector))]
       [(#:syntax+props)
        (decodes
         (content [#:ref context] [#:ref srcloc] props tamper)
         (deserialize-syntax content
                             context
                             srcloc
                             props
                             tamper
                             inspector))]
       [(#:srcloc)
        (decode* (srcloc source line column position span))]
       [(#:srcloc/source)
        (decodes
         (holder line column position span)
         (srcloc (srcloc-source holder) line column position span))]
       [(#:quote)
        (define q-pos (+ pos 1))
        (decode-value (bytes-ref bv q-pos) bv q-pos lits)]
       [(#:mpi)
        (define-values (i next-pos) (decode-int bv (+ pos 1)))
        (values (vector*-ref mpis i) next-pos)]
       [(#:box)
        (decode* (box-immutable v))]
       [(#:cons)
        (decode* (cons a d))]
       [(#:list #:vector #:pvector)
        (define-values (len start-pos) (decode-int bv (+ pos 1)))
        (define r (make-vector len))
        (define next-pos
          (for/fold ([pos start-pos]) ([i (in-range len)])
            (define-values (v next-pos) (decodes #:pos pos (v) v))
            (vector-set! r i v)
            next-pos))
        (values (cond
                  [(= b (op-code #:list)) (vector->list r)]
                  [(= b (op-code #:pvector)) (core-fresh-vector->pvector r)]
                  [else (vector->immutable-vector r)])
                next-pos)]
       [(#:hash)
        (define-values (len start-pos) (decode-int bv (+ pos 1)))
        (for/fold ([ht (hash)] [pos start-pos]) ([i (in-range len)])
          (decodes #:pos pos (k v) (hash-set ht k v)))]
       [(#:hasheq #:hasheqv #:hasheqv/phase+space)
        ;; Decode the entries into vectors and build the table from them in
        ;; one pass: adding entries one at a time path-copies the trie, which
        ;; allocates several times the table's size, and a module's provides
        ;; tables run to thousands of entries
        (define-values (len start-pos) (decode-int bv (+ pos 1)))
        (define phase+space? (= b (op-code #:hasheqv/phase+space)))
        (define keys (make-vector len #f))
        (define vals (make-vector len #f))
        (define next-pos
          (for/fold ([pos start-pos]) ([i (in-range len)])
            (define-values (k k-pos) (decodes #:pos pos (k) k))
            (define-values (v v-pos) (decodes #:pos k-pos (v) v))
            (vector-set! keys i (if phase+space? (intern-phase+space k) k))
            (vector-set! vals i v)
            v-pos))
        (values (if (= b (op-code #:hasheq))
                    (unsafe-hasheq-from-vectors keys vals)
                    (unsafe-hasheqv-from-vectors keys vals))
                next-pos)]
       [(#:set #:seteq #:seteqv)
        (define s (cond
                    [(= b (op-code #:set)) (set)]
                    [(= b (op-code #:seteq)) (seteq)]
                    [else (seteqv)]))
        (define-values (len start-pos) (decode-int bv (+ pos 1)))
        (for/fold ([s s] [pos start-pos]) ([i (in-range len)])
          (decodes #:pos pos (k) (set-add s k)))]
       [(#:prefab)
        (define-values (key next-pos) (decodes #:pos (+ pos 1) (k) k))
        (define-values (len start-pos) (decode-int bv next-pos))
        (define-values (r done-pos)
          (for/fold ([r null] [pos start-pos]) ([i (in-range len)])
            (decodes #:pos pos (v) (cons v r))))
        (values (apply make-prefab-struct key (reverse r))
                done-pos)]
       [(#:scope)
        (decode* (deserialize-scope))]
       [(#:scope+kind)
        (decode* (deserialize-scope kind))]
       [(#:interned-scope)
        (decode* (make-interned-scope id))]
       [(#:multi-scope)
        (decode* (deserialize-multi-scope name scopes))]
       [(#:shifted-multi-scope)
        (decode* (deserialize-shifted-multi-scope phase multi-scope))]
       [(#:table-with-bulk-bindings)
        (decode* (deserialize-table-with-bulk-bindings syms bulk-bindings))]
       [(#:bulk-binding-at)
        (decode* (deserialize-bulk-binding-at scopes bulk))]
       [(#:representative-scope)
        (decode* (deserialize-representative-scope kind phase))]
       [(#:module-binding)
        (decode* (deserialize-full-module-binding
                  module sym phase
                  nominal-module
                  nominal-phase
                  nominal-sym
                  nominal-require-phase
                  free=id
                  extra-inspector
                  extra-nominal-bindings))]
       [(#:simple-module-binding)
        (decode* (deserialize-simple-module-binding module sym phase nominal-module))]
       [(#:local-binding)
        (decode* (deserialize-full-local-binding key free=id))]
       [(#:bulk-binding)
        (decode* (deserialize-bulk-binding prefix excepts mpi provide-phase-level phase-shift bulk-binding-registry))]
       [(#:like-ambiguous-binding)
        (decode* (like-ambiguous-binding))]
       [(#:bulk-binding+provides)
        (decode* (deserialize-bulk-binding+provides provides self prefix excepts mpi provide-phase-level phase-shift bulk-binding-registry))]
       [(#:provided)
        (decode* (deserialize-provided binding protected? syntax?))]
       [else
        (error 'deserialize "bad encoding: ~v" b)])]))

;; Decode the filling of mutable values, which has its own encoding
;; variant
(define (decode-fill! v bv pos mpis inspector bulk-binding-registry shared lits)
  (define b (bytes-ref bv pos))
  (cond
    [(= b FALSE-BYTE) (+ pos 1)]
    [else
     (case-op b
       [(#:set-box!)
        (define-values (c next-pos)
          (decode bv (+ pos 1) mpis inspector bulk-binding-registry shared lits))
        (set-box! v c)
        next-pos]
       [(#:set-vector!)
        (define-values (len start-pos) (decode-int bv (+ pos 1)))
        (for/fold ([pos start-pos]) ([i (in-range len)])
          (define-values (c next-pos)
            (decode bv pos mpis inspector bulk-binding-registry shared lits))
          (vector-set! v i c)
          next-pos)]
       [(#:set-hash!)
        (define-values (len start-pos) (decode-int bv (+ pos 1)))
        (for/fold ([pos start-pos]) ([i (in-range len)])
          (define-values (key next-pos)
            (decode bv pos mpis inspector bulk-binding-registry shared lits))
          (define-values (val done-pos)
            (decode bv next-pos mpis inspector bulk-binding-registry shared lits))
          (hash-set! v key val)
          done-pos)]
       [(#:scope-fill!)
        (define-values (c next-pos)
          (decode bv (+ pos 1) mpis inspector bulk-binding-registry shared lits))
        (deserialize-scope-fill! v c)
        next-pos]
       [(#:representative-scope-fill!)
        (define-values (a next-pos)
          (decode bv (+ pos 1) mpis inspector bulk-binding-registry shared lits))
        (define-values (d done-pos)
          (decode bv next-pos mpis inspector bulk-binding-registry shared lits))
        (deserialize-representative-scope-fill! v a d)
        done-pos]
       [else
        (error 'deserialize "bad fill encoding: ~v" b)])]))

;; ----------------------------------------
;; Deserialization of the previous vector-stream encoding, kept so
;; that already-compiled modules load until they are recompiled

(define (deserialize/v mpis inspector bulk-binding-registry
                     num-mutables mutable-vec 
                     num-shared shared-vec
                     mutable-fill-vec
                     result-vec)
  (define shared (make-vector (+ num-mutables num-shared) 'uninit))
  ;; Make mutable shells
  (for/fold ([pos 0]) ([i (in-range num-mutables)])
    (define-values (d next-pos)
      (decode-shell/v mutable-vec pos mpis inspector bulk-binding-registry shared))
    (vector-set! shared i d)
    next-pos)
  ;; Construct shared values; note that later constructions can refer
  ;; to earlier ones
  (for/fold ([pos 0]) ([i (in-range num-mutables (+ num-mutables num-shared))])
    (define-values (d next-pos)
      (decode/v shared-vec pos mpis inspector bulk-binding-registry shared))
    (vector-set! shared i d)
    next-pos)
  ;; Fill in mutable shells
  (for/fold ([pos 0]) ([i (in-range num-mutables)]
                       [v (in-vector shared)])
    (decode-fill!/v v mutable-fill-vec pos mpis inspector bulk-binding-registry shared))
  ;; Construct the final result
  (define-values (result done-pos)
    (decode/v result-vec 0 mpis inspector bulk-binding-registry shared))
  result)

;; Decode the construction of a mutable variable
(define (decode-shell/v vec pos mpis inspector bulk-binding-registry shared)
  (case (vector*-ref vec pos)
    [(#:box) (values (box #f) (add1 pos))]
    [(#:vector) (values (make-vector (vector*-ref vec (add1 pos))) (+ pos 2))]
    [(#:hash) (values (make-hasheq) (add1 pos))]
    [(#:hasheq) (values (make-hasheq) (add1 pos))]
    [(#:hasheqv) (values (make-hasheqv) (add1 pos))]
    [else (decode/v vec pos mpis inspector bulk-binding-registry shared)]))

;; The decoder that is used for most purposes
(define (decode/v vec pos mpis inspector bulk-binding-registry shared)
  (define-syntax decodes
    (syntax-rules ()
      [(_ (id ...) rhs) (decodes #:pos (add1 pos) (id ...) rhs)]
      [(_ #:pos pos () rhs) (values rhs pos)]
      [(_ #:pos pos ([#:ref id0] id ...) rhs)
       (let-values ([(id0 next-pos) (let ([i (vector*-ref vec pos)])
                                      (if (exact-integer? i)
                                          (values (vector*-ref shared i) (add1 pos))
                                          (decode/v vec pos mpis inspector bulk-binding-registry shared)))])
         (decodes #:pos next-pos (id ...) rhs))]
      [(_ #:pos pos (id0 id ...) rhs)
       (let-values ([(id0 next-pos) (decode/v vec pos mpis inspector bulk-binding-registry shared)])
         (decodes #:pos next-pos (id ...) rhs))]))
  (define-syntax-rule (decode* (deser id ...))
    (decodes (id ...) (deser id ...)))
  (case (vector*-ref vec pos)
    [(#:ref)
     (values (vector*-ref shared (vector*-ref vec (add1 pos)))
             (+ pos 2))]
    [(#:inspector) (values inspector (add1 pos))]
    [(#:bulk-binding-registry) (values bulk-binding-registry (add1 pos))]
    [(#:syntax)
     (decodes
      (content [#:ref context] [#:ref srcloc])
      (deserialize-syntax content
                          context
                          srcloc
                          #f
                          #f
                          inspector))]
    [(#:datum->syntax)
     (decodes
      (content [#:ref context] [#:ref srcloc])
      (deserialize-datum->syntax content
                                 context
                                 srcloc
                                 inspector))]
    [(#:syntax+props)
     (decodes
      (content [#:ref context] [#:ref srcloc] props tamper)
      (deserialize-syntax content
                          context
                          srcloc
                          props
                          tamper
                          inspector))]
    [(#:srcloc)
     (decode* (srcloc source line column position span))]
    [(#:quote)
     (values (vector*-ref vec (add1 pos)) (+ pos 2))]
    [(#:mpi)
     (values (vector*-ref mpis (vector*-ref vec (add1 pos)))
             (+ pos 2))]
    [(#:box)
     (decode* (box-immutable v))]
    [(#:cons)
     (decode* (cons a d))]
    [(#:list #:vector #:pvector)
     (define len (vector*-ref vec (add1 pos)))
     (define r (make-vector len))
     (define next-pos
       (for/fold ([pos (+ pos 2)]) ([i (in-range len)])
         (define-values (v next-pos) (decodes #:pos pos (v) v))
         (vector-set! r i v)
         next-pos))
     (values (case (vector*-ref vec pos)
               [(#:list) (vector->list r)]
               [(#:pvector) (core-fresh-vector->pvector r)]
               [else (vector->immutable-vector r)])
             next-pos)]
    [(#:hash)
     (define len (vector*-ref vec (add1 pos)))
     (for/fold ([ht (hash)] [pos (+ pos 2)]) ([i (in-range len)])
       (decodes #:pos pos (k v) (hash-set ht k v)))]
    [(#:hasheq #:hasheqv #:hasheqv/phase+space)
     ;; Decode the entries into vectors and build the table from them in
     ;; one pass: adding entries one at a time path-copies the trie, which
     ;; allocates several times the table's size, and a module's provides
     ;; tables run to thousands of entries
     (define tag (vector*-ref vec pos))
     (define len (vector*-ref vec (add1 pos)))
     (define keys (make-vector len #f))
     (define vals (make-vector len #f))
     (define next-pos
       (for/fold ([pos (+ pos 2)]) ([i (in-range len)])
         (define-values (k k-pos) (decodes #:pos pos (k) k))
         (define-values (v v-pos) (decodes #:pos k-pos (v) v))
         (vector-set! keys i (if (eq? tag '#:hasheqv/phase+space) (intern-phase+space k) k))
         (vector-set! vals i v)
         v-pos))
     (values (if (eq? tag '#:hasheq)
                 (unsafe-hasheq-from-vectors keys vals)
                 (unsafe-hasheqv-from-vectors keys vals))
             next-pos)]
    [(#:set #:seteq #:seteqv)
     (define s (case (vector*-ref vec pos)
                 [(#:set) (set)]
                 [(#:seteq) (seteq)]
                 [(#:seteqv) (seteqv)]))
     (define len (vector*-ref vec (add1 pos)))
     (for/fold ([s s] [pos (+ pos 2)]) ([i (in-range len)])
       (decodes #:pos pos (k) (set-add s k)))]
    [(#:prefab)
     (define-values (key next-pos) (decodes #:pos (add1 pos) (k) k))
     (define len (vector*-ref vec next-pos))
     (define-values (r done-pos)
       (for/fold ([r null] [pos (add1 next-pos)]) ([i (in-range len)])
         (decodes #:pos pos (v) (cons v r))))
     (values (apply make-prefab-struct key (reverse r))
             done-pos)]
    [(#:scope)
     (decode* (deserialize-scope))]
    [(#:scope+kind)
     (decode* (deserialize-scope kind))]
    [(#:interned-scope)
     (decode* (make-interned-scope id))]
    [(#:multi-scope)
     (decode* (deserialize-multi-scope name scopes))]
    [(#:shifted-multi-scope)
     (decode* (deserialize-shifted-multi-scope phase multi-scope))]
    [(#:table-with-bulk-bindings)
     (decode* (deserialize-table-with-bulk-bindings syms bulk-bindings))]
    [(#:bulk-binding-at)
     (decode* (deserialize-bulk-binding-at scopes bulk))]
    [(#:representative-scope)
     (decode* (deserialize-representative-scope kind phase))]
    [(#:module-binding)
     (decode* (deserialize-full-module-binding
               module sym phase
               nominal-module
               nominal-phase
               nominal-sym
               nominal-require-phase
               free=id
               extra-inspector
               extra-nominal-bindings))]
    [(#:simple-module-binding)
     (decode* (deserialize-simple-module-binding module sym phase nominal-module))]
    [(#:local-binding)
     (decode* (deserialize-full-local-binding key free=id))]
    [(#:bulk-binding)
     (decode* (deserialize-bulk-binding prefix excepts mpi provide-phase-level phase-shift bulk-binding-registry))]
    [(#:like-ambiguous-binding)
     (decode* (like-ambiguous-binding))]
    [(#:bulk-binding+provides)
     (decode* (deserialize-bulk-binding+provides provides self prefix excepts mpi provide-phase-level phase-shift bulk-binding-registry))]
    [(#:provided)
     (decode* (deserialize-provided binding protected? syntax?))]
    [else
     (values (vector*-ref vec pos) (add1 pos))]))

;; Decode the filling of mutable values, which has its own encoding
;; variant
(define (decode-fill!/v v vec pos mpis inspector bulk-binding-registry shared)
  (case (vector*-ref vec pos)
    [(#f) (add1 pos)]
    [(#:set-box!)
     (define-values (c next-pos)
       (decode/v vec (add1 pos) mpis inspector bulk-binding-registry shared))
     (set-box! v c)
     next-pos]
    [(#:set-vector!)
     (define len (vector*-ref vec (add1 pos)))
     (for/fold ([pos (+ pos 2)]) ([i (in-range len)])
       (define-values (c next-pos)
         (decode/v vec pos mpis inspector bulk-binding-registry shared))
       (vector-set! v i c)
       next-pos)]
    [(#:set-hash!)
     (define len (vector*-ref vec (add1 pos)))
     (for/fold ([pos (+ pos 2)]) ([i (in-range len)])
       (define-values (key next-pos)
         (decode/v vec pos mpis inspector bulk-binding-registry shared))
       (define-values (val done-pos)
         (decode/v vec next-pos mpis inspector bulk-binding-registry shared))
       (hash-set! v key val)
       done-pos)]
    [(#:scope-fill!)
     (define-values (c next-pos)
       (decode/v vec (add1 pos) mpis inspector bulk-binding-registry shared))
     (deserialize-scope-fill! v c)
     next-pos]
    [(#:representative-scope-fill!)
     (define-values (a next-pos)
       (decode/v vec (add1 pos) mpis inspector bulk-binding-registry shared))
     (define-values (d done-pos)
       (decode/v vec next-pos mpis inspector bulk-binding-registry shared))
     (deserialize-representative-scope-fill! v a d)
     done-pos]
    [else
     (error 'deserialize "bad fill encoding: ~v" (vector*-ref vec pos))]))
 
;; ----------------------------------------
;; For pruning unreachable scopes in serialization

(define (find-reachable-scopes v bulk-shifts report-mpi-shifts)
  (define seen (make-hasheq))
  (define reachable-scopes (interned-scopes))
  (define implicitly-reachable-scopes (interned-scopes))
  (define (get-reachable-scopes) reachable-scopes)
  (define scope-triggers (make-hasheq))

  (define report-shifts
    (and report-mpi-shifts
         ;; Serialization context wants to know how reachable mpis are resolved
         ;; by their context, so report as we discover them
         (lambda (mpi bulk-shifts)
           (report-mpi-shifts mpi (apply-syntax-shifts mpi (cdr bulk-shifts))))))

  ;; `bulk-shifts` is used to propagate shifts from a syntax object to
  ;; binding tables when bulk-binding provides will be preserved, in
  ;; case scope-specific bindings need to be reified; a `bulk-shifts`
  ;; list is an `extra-shifts` prefixed by an eq-based table to record
  ;; resolved module paths; setting it to #f means that bulk-binding
  ;; provides are not preserved (i.e., they will be shared with the
  ;; providing module on demand), and no bulk-shifts propagation is
  ;; needed; for now, we conservatively force all bulk-binding
  ;; provides to be reified when any will be preserved

  (let loop ([v v] [bulk-shifts bulk-shifts])
    (cond
     [(interned-literal? v) (void)]
     [(hash-ref seen v #f) (void)]
     [else
      (hash-set! seen v #t)
      (cond
       [(scope-with-bindings? v)
        (set! reachable-scopes (set-add reachable-scopes v))

        ((reach-scopes-ref v) v bulk-shifts loop)

        (for ([proc (in-list (hash-ref scope-triggers v null))])
          (proc loop))
        (hash-remove! scope-triggers v)
 
        ;; A binding may have a `free-id=?` equivalence;
        ;; that equivalence is reachable if all the scopes in the
        ;; binding set are reachable; for a so-far unreachable scope,
        ;; record a trigger in case the scope becomes reachable later
        ((scope-with-bindings-ref v)
         v
         get-reachable-scopes
         bulk-shifts
         loop
         (lambda (sc-unreachable b)
           (hash-update! scope-triggers
                         sc-unreachable
                         (lambda (l) (cons b l))
                         null))
         (lambda (sc)
           (unless (set-member? reachable-scopes sc)
             (set! implicitly-reachable-scopes (set-add implicitly-reachable-scopes sc))))
         report-shifts)]
       [(reach-scopes? v)
        ((reach-scopes-ref v) v bulk-shifts loop)]
       [(pair? v)
        (loop (car v) bulk-shifts)
        (loop (cdr v) bulk-shifts)]
       [(vector? v)
        (for ([e (in-vector v)])
          (loop e bulk-shifts))]
       [(box? v)
        (loop (unbox v) bulk-shifts)]
       [(hash? v)
        (for ([(k v) (in-hash v)])
          (loop k bulk-shifts)
          (loop v bulk-shifts))]
       [(prefab-struct-key v)
        (for ([e (in-vector (struct->vector v) 1)])
          (loop e bulk-shifts))]
       [(srcloc? v)
        (loop (srcloc-source v) bulk-shifts)]
       [else
        (void)])]))
  
  (values reachable-scopes
          implicitly-reachable-scopes))

;; ----------------------------------------

;; See `generate-lazy-syntax-literals!`. This function is called on demand to
;; shift a syntax-object literal for a given module instantiation.
(define (force-syntax-object syntax-literals pos
                             mpi self-mpi phase-shift inspector
                             deserialized-syntax-vector/box bulk-binding-registry
                             deserialize-syntax)
  (define deserialized-syntax-vector
    (or (unbox deserialized-syntax-vector/box)
        (begin
          (deserialize-syntax bulk-binding-registry)
          (unbox deserialized-syntax-vector/box))))
  (define stx (syntax-module-path-index-shift
               (syntax-shift-phase-level
                (vector*-ref deserialized-syntax-vector pos)
                phase-shift)
               mpi
               self-mpi
               inspector))
  ;; loop in case of spurious CAS failure
  (let loop ()
    (vector-cas! syntax-literals pos #f stx)
    (define new-stx (vector*-ref syntax-literals pos))
    (if new-stx
        new-stx
        (loop))))

;; ----------------------------------------
;; Set up the instance to import into deserializing linklets

(define deserialize-imports
  '(deserialize-module-path-indexes
    syntax-module-path-index-shift
    syntax-shift-phase-level
    force-syntax-object
    module-use
    deserialize))

;; To avoid a higher-order use of a keyword-accepting function:
(define syntax-module-path-index-shift/no-keywords
  (let ([syntax-module-path-index-shift
         (lambda (s from-mpi to-mpi [inspector #f])
           (syntax-module-path-index-shift s from-mpi to-mpi inspector))])
    syntax-module-path-index-shift))
    
(define deserialize-instance
  (make-instance 'deserialize #f 'consistent
                 'deserialize-module-path-indexes deserialize-module-path-indexes
                 'syntax-module-path-index-shift syntax-module-path-index-shift/no-keywords
                 'syntax-shift-phase-level syntax-shift-phase-level
                 'force-syntax-object force-syntax-object
                 'module-use module-use
                 'deserialize deserialize))
