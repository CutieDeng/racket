;; ===== P3.3 Chez-side deterministic code enumerator (loaded into p32-env) =====
;; Requires p3.2-head.chez.ss definitions ($rec? $rref $ccode $code? try rtd-name
;; rtd-total-fields safe-clen $cont? $stvec? $stlen $stref code-name obj-category ...)

(define zo-get-reloc
  (foreign-procedure "(cs)s_get_reloc" (scheme-object boolean) scheme-object))
(define zo-obvip open-bytevector-input-port)
(define zo-lcfp load-compiled-from-port)

;; force a wrapped-code record IN PLACE (replicates force-wrapped-code):
;; content(bv) -> procedure via load-compiled-from-port with its literals vector
;; content(annotation, 'jit mode) -> procedure via chez compile (deterministic
;; for identical input; A caches the result in place so init reuses OUR code)
(define zo-wc-ann 0)
(define zo-wc-ann-fail 0)
(define (zo-force-wrapped! r)
  (let ([content (try (lambda () ($rref r 0)) #f)])
    (cond
      [(procedure? content) 'already]
      [(bytevector? content)
       (let ([lits (try (lambda () ($rref r 1)) '#())])
         (let ([p (try (lambda () (zo-lcfp (zo-obvip content) lits)) #f)])
           (if (procedure? p)
               (begin (#%$record-set! r 0 p) 'forced)
               'force-fail)))]
      [(not content) 'not-bv]
      [else
       ;; 'jit mode: annotation or (vector hash annotation)
       (let* ([expr (if (vector? content)
                        (vector-ref content (fx- (vector-length content) 1))
                        content)]
              [p (try (lambda () (compile expr)) #f)])
         (cond
           [(procedure? p)
            (#%$record-set! r 0 p)
            (set! zo-wc-ann (fx+ zo-wc-ann 1))
            'forced]
           [else
            (set! zo-wc-ann-fail (fx+ zo-wc-ann-fail 1))
            'not-bv]))])))

;; deterministic DFS enumerating $code? objects reachable from a linklet record.
;; visit order: natural structural order (fields left-to-right, ccode before
;; freevars, reloc list in scan order).
;;
;; CODE-FOCUSED walk (P3.3a lesson): reloc descent goes ONLY into $code?
;; entries -- literal data reached from reloc can differ between A and B
;; (A-side literal unfasl connects to the declared-module registry; B has no
;; declarations), which would shift seq numbering.  Likewise records other
;; than the linklet itself (field 0 = code) and wrapped-code (field 0 =
;; content, forced) are treated as leaves.  Chez codes can never hide inside
;; racket literal data (fasl cannot serialize live codes), so this loses no
;; legitimate code, and it makes the enumeration a pure function of the .zo
;; bytes.
(define zo-enum-stats-ht 0)     ; hashtables skipped in last run
(define zo-enum-stats-wc 0)     ; wrapped-code forced in last run
(define zo-enum-stats-wcfail 0) ; wrapped-code force failures

(define (zo-enum-codes! root on-code)
  ;; on-code : code -> void   (called in deterministic first-encounter order)
  (define seen (make-eq-hashtable))
  (define stack (list root))
  (define (push-kids! kids)  ; kids in forward order
    (let loop ([ks (reverse kids)])
      (unless (null? ks)
        (set! stack (cons (car ks) stack))
        (loop (cdr ks)))))
  (let loop ()
    (unless (null? stack)
      (let ([x (car stack)])
        (set! stack (cdr stack))
        (when (and (or (heapish? x) ($code? x))
                   (not (eq-hashtable-ref seen x #f)))
          (eq-hashtable-set! seen x #t)
          (cond
            [($code? x)
             (on-code x)
             ;; descend into code-valued reloc entries (nested codes) and into
             ;; the CODE of closure-valued reloc entries (zero-freevar module
             ;; functions become static constant closures in the reloc).  A
             ;; closure's freevars are NOT walked: constant closures have none,
             ;; and live (boot) closures reached here must not leak
             ;; process-state content into the enumeration.
             (push-kids!
              (let lp ([l (reverse (zo-get-reloc x #f))] [acc '()])
                (cond
                  [(null? l) (reverse acc)]
                  [($code? (car l)) (lp (cdr l) (cons (car l) acc))]
                  [(and (procedure? (car l))
                        (not ($cont? (car l)))
                        (safe-clen (car l)))
                   (let ([cd (try (lambda () ($ccode (car l))) #f)])
                     (lp (cdr l) (if cd (cons cd acc) acc)))]
                  [else (lp (cdr l) acc)])))]
            [(procedure? x)
             (cond
               [($cont? x) (void)]
               [(safe-clen x)
                => (lambda (n)
                     (let ([cd (try (lambda () ($ccode x)) #f)])
                       (push-kids!
                        (cons (or cd '())
                              (let lp ([i 0] [acc '()])
                                (if (fx>= i n)
                                    (reverse acc)
                                    (lp (fx+ i 1) (cons ($cref x i) acc))))))))]
               [else (void)])]
            [(hashtable? x)
             (set! zo-enum-stats-ht (fx+ zo-enum-stats-ht 1))]
            [($rec? x)
             (case (rtd-name x)
               [(linklet)
                ;; only the code field (0); literals/exports-info etc. are
                ;; data and may be context-dependent
                (push-kids! (list (try (lambda () ($rref x 0)) 0)))]
               [(wrapped-code)
                (let ([r (zo-force-wrapped! x)])
                  (case r
                    [(forced) (set! zo-enum-stats-wc (fx+ zo-enum-stats-wc 1))]
                    [(force-fail) (set! zo-enum-stats-wcfail (fx+ zo-enum-stats-wcfail 1))]
                    [else (void)])
                  (push-kids! (list (try (lambda () ($rref x 0)) 0))))]
               [else (void)])]
            [(pair? x)
             (if (or (weak-pair? x) (ephemeron-pair? x))
                 (void)
                 (push-kids! (list (car x) (cdr x))))]
            [($stvec? x)
             (let ([n ($stlen x)])
               (push-kids!
                (let lp ([i 0] [acc '()])
                  (if (fx>= i n)
                      (reverse acc)
                      (lp (fx+ i 1) (cons (try (lambda () ($stref x i)) 0) acc))))))]
            [(box? x) (push-kids! (list (unbox x)))]
            [(vector? x)
             (let ([n (vector-length x)])
               (push-kids!
                (let lp ([i 0] [acc '()])
                  (if (fx>= i n)
                      (reverse acc)
                      (lp (fx+ i 1) (cons (vector-ref x i) acc))))))]
            [else (void)])))
      (loop))))

;; enumerate over a list of (key-string . linklet) pairs (already sorted by
;; caller); returns vector of codes in deterministic order
(define (zo-enum-linklets lst)
  (let ([acc '()] [n 0])
    (for-each
     (lambda (pr)
       (zo-enum-codes! (cdr pr)
                       (lambda (c)
                         (set! acc (cons c acc))
                         (set! n (fx+ n 1)))))
     lst)
    (list->vector (reverse acc))))
