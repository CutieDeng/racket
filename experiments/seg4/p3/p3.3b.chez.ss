;; ===== P3.3b process B driver: NO racket/init; code from fasl-level zo table =====
;; Racket-level operations arrive as bridged procedure arguments.

(define SP
  ;; portable: root from P33_SP, matching the runner
  (let ([v (getenv "P33_SP")])
    (or v (errorf 'seg4-driver "P33_SP is not set"))))
(define P3 (string-append SP "/p3"))

(define p3-skip-tags '(custodian))   ; precise skip via predicate below   ; P3.2: 'thread ops now APPLIED (= thread-cell seeding hook)

(define p32-tcl 0)     ; cumulative codeloc n3-resolve cpu ms
(define p32-trmp 0)    ; cumulative rmp resolve cpu ms
(define p32-do-codeloc? #t)
(define (p32-gcms)
  (let ([t (sstats-gc-cpu (statistics))])
    (+ (* 1000 (time-second t)) (div (time-nanosecond t) 1000000))))
(define p33-dummies '())   ; (ext-index . dummy-code) for forensics

(define (p33-dummy-holders! o patch tags dummies)
  ;; summarize, per patch entry, the dummy-wired closures in its value graph
  (let ([dummy-tab (make-eq-hashtable)]
        [total 0])
    (for-each (lambda (pr) (eq-hashtable-set! dummy-tab (cdr pr) (car pr))) dummies)
    (let lp ([j 0])
      (when (fx< j (vector-length patch))
        (when (equal? (#%getenv "P33_DH_TRACE") "1")
          (o "  [dh] probing patch[" j "] tag=" (vector-ref tags j)))
        (let ([e (vector-ref patch j)]
              [seen (make-eq-hashtable)]
              [parent (make-eq-hashtable)]
              [hits '()])
          (let walk ([stack (let ve ([k 2] [acc '()])
                              (if (fx< k (vector-length e))
                                  (ve (fx+ k 1) (cons (vector-ref e k) acc))
                                  acc))])
            (unless (null? stack)
              (let ([x (car stack)] [rest (cdr stack)])
                (cond
                  [(or (not (heapish? x)) (eq-hashtable-ref seen x #f))
                   (walk rest)]
                  [else
                   (eq-hashtable-set! seen x #t)
                   (when (and (procedure? x) (not ($cont? x)) (safe-clen x))
                     (let* ([cd (try (lambda () ($ccode x)) #f)]
                            [hit (and cd (eq-hashtable-ref dummy-tab cd #f))])
                       (when hit
                         (set! hits (cons (cons hit (eq-hashtable-ref parent x 'root))
                                          hits)))))
                   (let ([kids (try (lambda () (children x #f)) '())])
                     (for-each (lambda (ch)
                                 (when (and (heapish? ch)
                                            (not (eq-hashtable-ref parent ch #f)))
                                   (eq-hashtable-set!
                                    parent ch
                                    (if (and (procedure? x) (not ($cont? x))
                                             (eqv? (safe-clen x) 3)
                                             (substr? (c-fmt "~a" (try (lambda () (code-name ($ccode x))) #f))
                                                      "wrapper-apply"))
                                        (c-fmt "wrapper data=~a"
                                               (fmt-val (try (lambda () ($cref x 2)) #f) 110))
                                        (obj-brief x)))))
                               kids)
                     (walk (append kids rest)))]))))
          (when (pair? hits)
            (set! total (fx+ total (length hits)))
            (o "  DUMMY-HOLDERS in patch[" j "]: op=" (vector-ref e 0)
               " tag=" (vector-ref tags j)
               " container=" (obj-brief (vector-ref e 1))
               " key=" (if (fx> (vector-length e) 2) (fmt-val (vector-ref e 2) 80) "-")
               " n-hits=" (length hits))
            (let ([cnt (c2-mkht c3-equalhash c3-equalpred)])
              (for-each (lambda (h)
                          (hashtable-update! cnt (cons (car h) (cdr h))
                                             (lambda (v) (fx+ v 1)) 0))
                        hits)
              (dump-counts o cnt "    (ext-i . parent-brief) census:"))))
        (lp (fx+ j 1))))
    (when (fx= total 0) (o "  (no dummy-wired closures inside patch entries)"))))

(define p33-seg-scope-ht (make-eq-hashtable))

;; ---- dup holder trace (top-level; called post-acceptance only) ----
;; For the first few duplicated (name . neg-id) scope keys, print the holder
;; chain of each member (dw-kids search space; labels from children/labeled)
;; plus lineage tags and the eq-divergence depth of the two chains.
(define (p33-trace-chain o rootvec target)
  ;; -> chain list (target .. root) or '() if not found
  (let ([visited (make-eq-hashtable)]
        [parent (make-eq-hashtable)]
        [nodes 0]
        [result '()])
    (let lp ([i (fx- (vector-length rootvec) 1)])
      (when (fx>= i 0)
        (eq-hashtable-set! visited (vector-ref rootvec i) #t)
        (eq-hashtable-set! parent (vector-ref rootvec i) 'ROOT)
        (lp (fx- i 1))))
    (call/cc
     (lambda (k)
       (let bfs ([qf (vector->list rootvec)] [qb '()])
         (unless (and (null? qf) (null? qb))
           (let* ([qf (if (null? qf) (reverse qb) qf)]
                  [x (car qf)])
             (set! nodes (fx+ nodes 1))
             (when (fx> nodes 3000000) (k #f))
             (if (eq? x target)
                 (begin
                   (let pth ([ob x] [acc '()])
                     (let ([par (eq-hashtable-ref parent ob #f)])
                       (if (or (eq? par 'ROOT) (not par))
                           (set! result (reverse (cons ob acc)))
                           (pth par (cons ob acc)))))
                   (k #t))
                 (let ([qb2 (fold-left
                             (lambda (acc ch)
                               (if (and (dw-node? ch)
                                        (not (eq-hashtable-ref visited ch #f)))
                                   (begin
                                     (eq-hashtable-set! visited ch #t)
                                     (eq-hashtable-set! parent ch x)
                                     (cons ch acc))
                                   acc))
                             '() (try (lambda () (dw-kids x)) '()))])
                   (bfs (cdr qf) (append qb2 qb)))))))
       #f))
    ;; result is already (target .. root)
    result))

(define (p33-edge-label par ob)
  (if (hashtable? par)
      (let ([ks (try (lambda () (c-htkeys par)) (vector))])
        (let ksc ([i 0])
          (cond
            [(fx>= i (vector-length ks)) "hval<?>"]
            [(eq? (try (lambda () (c-htref par (vector-ref ks i) #f)) #f) ob)
             (string-append "hval<"
                            (try (lambda () (trunc (c-fmt "~s" (vector-ref ks i)) 130)) "?")
                            ">")]
            [else (ksc (fx+ i 1))])))
      (let scan ([ecs (try (lambda () (children/labeled par)) '())])
        (cond
          [(null? ecs) "?"]
          [(eq? (cdar ecs) ob) (c-fmt "~a" (caar ecs))]
          [else (scan (cdr ecs))]))))

(define (p33-print-chain o label chain)
  ;; chain = (target .. root)
  (if (null? chain)
      (o "    " label " : no path in dw-kids space")
      (begin
        (o "    " label " holder chain (nearest 14):")
        (let pr ([l chain] [n 0])
          (cond
            [(null? (cdr l)) (o "      <- ROOT")]
            [(fx< n 14)
             (o "      <- " (obj-brief (cadr l)) " [" (p33-edge-label (cadr l) (car l)) "]")
             (pr (cdr l) (fx+ n 1))]
            [else (o "      <- ... (deeper elided)") (o "      <- ROOT")])))))

(define (p33-lineage tag-obj)
  (cond
    [(eq-hashtable-ref native-scope-tab tag-obj #f) " [native@mark]"]
    [(eq-hashtable-ref phase-a-scope-tab tag-obj #f) " [B-minted-pre-fasl]"]
    [(eq-hashtable-ref p33-seg-scope-ht tag-obj #f) " [seg-graph]"]
    [else " [post-fasl-minted]"]))

(define (p33-rmp-str k)
  ;; decode a resolved-module-path key into a readable path string
  (try (lambda ()
         (if (and ($rec? k) (eq? (try (lambda () (rtd-name k)) #f) 'resolved-module-path))
             (let ([nm (#%$record-ref k 0)])
               (cond
                 [(and ($rec? nm) (eq? (try (lambda () (rtd-name nm)) #f) 'path))
                  (utf8->string (#%$record-ref nm 0))]
                 [(symbol? nm) (symbol->string nm)]
                 [(pair? nm)
                  (string-append
                   "(submod "
                   (let ([base (car nm)])
                     (cond
                       [(and ($rec? base) (eq? (try (lambda () (rtd-name base)) #f) 'path))
                        (utf8->string (#%$record-ref base 0))]
                       [else (c-fmt "~s" base)]))
                   " " (c-fmt "~s" (cdr nm)) ")")]
                 [else (trunc (c-fmt "~s" nm) 120)]))
             (trunc (c-fmt "~s" k) 120)))
       "key:unprintable"))

(define (p33-dup-trace! o rootvec post)
  (let ([bykey (c2-mkht c3-equalhash c3-equalpred)])
    (for-each
     (lambda (pr)
       (let* ([t (cdr pr)] [id (cadr t)])
         (when (and (number? id) (negative? id))
           (hashtable-update! bykey (cons (car t) id)
                              (lambda (l) (cons (car pr) l)) '()))))
     post)
    (let ([dups (let-values ([(ks vs) (hashtable-entries bykey)])
                  (let f ([i (fx- (vector-length ks) 1)] [acc '()])
                    (if (fx< i 0) acc
                        (f (fx- i 1)
                           (if (fx> (length (vector-ref vs i)) 1)
                               (cons (cons (vector-ref ks i) (vector-ref vs i)) acc)
                               acc)))))])
      (o "==== dup holder trace (" (length dups) " dup keys) ====")
      (let show ([l dups] [n 0])
        (when (and (pair? l) (fx< n 3))
          (let* ([k (caar l)] [members (cdar l)])
            (o "  DUP " k " members=" (length members))
            (let ([chains
                   (let mem ([ms members] [i 0] [acc '()])
                     (if (null? ms)
                         (reverse acc)
                         (let ([ch (p33-trace-chain o rootvec (car ms))])
                           (p33-print-chain
                            o
                            (string-append "member" (number->string i)
                                           (p33-lineage (car ms)))
                            ch)
                           (mem (cdr ms) (fx+ i 1) (cons ch acc)))))])
              (when (and (fx>= (length chains) 2)
                         (pair? (car chains)) (pair? (cadr chains)))
                ;; compare root-side first: chains are (target .. root)
                (let ([r1 (reverse (car chains))]
                      [r2 (reverse (cadr chains))])
                  (let dv ([a r1] [b r2] [d 0])
                    (cond
                      [(or (null? a) (null? b))
                       (o "    [chain-compare] one chain is a prefix of the other; shared depth=" d)]
                      [(eq? (car a) (car b)) (dv (cdr a) (cdr b) (fx+ d 1))]
                      [else
                       (o "    [chain-compare] chains DIVERGE at depth " d " from root:")
                       (let ([tagof (lambda (x)
                                      (if (and dw-mark-seen (eq-hashtable-ref dw-mark-seen x #f))
                                          " @mark" " post-mark"))]
                             [keyof (lambda (x)
                                      ;; if the SHARED parent is a hashtable, find x's key
                                      (let ([par (and (fx> d 0)
                                                      (list-ref r1 (fx- d 1)))])
                                        (if (and par (hashtable? par))
                                            (let ([ks (try (lambda () (c-htkeys par)) (vector))])
                                              (let ksc ([i 0])
                                                (cond
                                                  [(fx>= i (vector-length ks)) "key:?"]
                                                  [(eq? (try (lambda () (c-htref par (vector-ref ks i) #f)) #f) x)
                                                   (p33-rmp-str (vector-ref ks i))]
                                                  [else (ksc (fx+ i 1))])))
                                            "")))])
                         (o "      chain1: " (obj-brief (car a)) (tagof (car a)) "  " (keyof (car a)))
                         (o "      chain2: " (obj-brief (car b)) (tagof (car b)) "  " (keyof (car b))))]))))))
          (show (cdr l) (fx+ n 1)))))))

(define phase-a-scope-tab (make-eq-hashtable))  ; scopes minted between mark and fasl-read  ; scope-proper objects inside the segment fasl graph

(define (p33b-run! kernel-prims rootvec rkt-load-zo-event rkt-string->keyword rkt-bytes->path
                    rkt-make-rmp rkt-make-safe-eval rkt-hook-module-cache-clear!
                    rkt-prefab-rtd rkt-creation-probes rkt-merge-syms rkt-probe-layers rkt-debug-binding rkt-analyze-syntax-fail rkt-hash-keys rkt-hash-get rkt-syms-peek rkt-ns-census do-probes?)
   (set! dw-extra-roots kernel-prims)
   (let ([dummy-cimt #f])
   (let ([prog (c-oof (string-append P3 "/p3.3b.prog") 'replace)]
         [lp (c-oof (string-append P3 "/p3.3b.log") 'replace)])
     (define (p . xs) (for-each (lambda (x) (c-disp x prog)) xs)
       (c-disp " rt=" prog) (c-disp (real-time) prog)
       (c-disp " gc=" prog) (c-disp (p32-gcms) prog) (c-nl prog) (c-flush prog))
     (define (o . xs) (for-each (lambda (x) (c-disp x lp)) xs) (c-nl lp) (c-flush lp))
     (o "==== P3.3b PROCESS B: load seg4z WITHOUT racket/init (zo code table) ====")
     ;; forward-analysis: on any serious condition, dump the Scheme-level
     ;; frame chain of the CRASHING continuation (handlers run before
     ;; unwind) -- identifies who dereferenced the poison
     (when (equal? (#%getenv "P33_CF_NECRO") "1")
       (base-exception-handler
        (let ([orig (base-exception-handler)])
          (lambda (c)
            (when (and (serious-condition? c)
                       (try (lambda ()
                              (and (message-condition? c)
                                   (let ([m (condition-message c)])
                                     (and (string? m)
                                          (p33-substr? m "invalid memory")))))
                            #f))
              (o "==== NECROPSY (serious condition at crash point) ====")
              (o "  condition: " (trunc (cond->string c) 200))
              (p33-stack-necropsy o))
            (orig c)))))
     (p "driver entered (kernel attach was done racket-side)... cpu=" (c-cpu))
     (let* ([pre-ns (vector-ref rootvec 0)]
            [codes-tab (find-eq-code-table)])
       ;; ---- mark-point boot-code walk (bdw): heap identical to A's mark ----
       (p "mark-point boot-code walk (bdw)... cpu=" (c-cpu))
       (let ([n (dw-walk! rootvec)])
         (let ([np (dw-walk-rtd-plists!)])
           (o "bdw rtd-plist extension: +" np " nodes"))
         (when (equal? (#%getenv "P33_DWFP") "1")
           (dw-dump-fingerprint! "/tmp/dwfp-B.txt"))
         (dw-freeze-classes!)
         (let ([st (dw-class-stats)])
           (o "scope-name histogram: "
              (let-values ([(ks vs) (hashtable-entries scope-name-histo)])
                (let lp ([i (fx- (vector-length ks) 1)] [acc '()])
                  (if (fx< i 0) acc
                      (lp (fx- i 1) (cons (cons (vector-ref ks i) (vector-ref vs i)) acc))))))
           (o "iscope-tab size: " (hashtable-size iscope-tab)
              "  keys: " (vector->list (hashtable-keys iscope-tab)))
           (o "bdw mark walk nodes: " n "  codes: " dw-ncodes
              "  classes: " (car st) "  multi-member classes: " (cadr st)
              "  max class size: " (caddr st))))
       (p "creation probes (cpb supply)... cpu=" (c-cpu))
       (cpb-build! (rkt-creation-probes) o)
       (set! dw-reloc-ok #f)   ; mark-phase walks done; reloc unsafe after GC
       ;; ---- read manifest; resolve locator entries AT THE MARK POINT ----
       (p "manifest read + loc resolution at mark point... cpu=" (c-cpu))
       (let* ([m (p3-fasl-from-file (string-append P3 "/seg4z-externals.manifest"))]
              [mvec (vector-ref m 3)]
              [n-ext (vector-length mvec)]
              [extvec (make-vector n-ext #f)]
              [resolved (make-vector n-ext #f)]  ; #t once filled
              [n-loc 0] [n-loc-ok 0]
              [loc-fail-why (c2-mkht c3-equalhash c3-equalpred)]
              [loc-fail-samples '()])
         (o "manifest entries: " n-ext)
         (let lp ([i 0])
           (when (fx< i n-ext)
             (let ([e (vector-ref mvec i)])
               (when (memq (vector-ref e 0) '(loc zoloc))
                 (set! n-loc (fx+ n-loc 1))
                 (let ([r (n3-resolve (vector-ref e 1) rootvec)])
                   (cond
                     [(and (eq? (car r) 'ok)
                           (or (eq? (vector-ref e 0) 'loc)
                               ($code? (cdr r))))
                      (set! n-loc-ok (fx+ n-loc-ok 1))
                      (vector-set! extvec i (cdr r))
                      (vector-set! resolved i #t)]
                     [else
                      (hashtable-update! loc-fail-why
                                         (if (eq? (car r) 'ok) 'zoloc-not-code (cdr r))
                                         (lambda (v) (fx+ v 1)) 0)
                      (when (fx< (length loc-fail-samples) 20)
                        (set! loc-fail-samples
                              (cons (c-fmt "i=~a why=~a edges=~a" i (cdr r)
                                           (trunc (c-fmt "~s" (vector-ref e 1)) 160))
                                    loc-fail-samples)))]))))
             (lp (fx+ i 1))))
         (o "loc+zoloc entries: " n-loc "  resolved at mark point: " n-loc-ok
            "  failed: " (fx- n-loc n-loc-ok))
         (dump-counts o loc-fail-why "  loc failure reasons:")
         (for-each (lambda (s) (o "   loc-fail: " s)) (reverse loc-fail-samples))
         ;; ---- code supply (P3.3: fasl-level zo loading, NO instantiation) ----
         (p "zo table build (fasl decode, no instantiation)... cpu=" (c-cpu))
         (if (equal? (#%getenv "P33_CODEFASL") "1")
             (begin
               (if (equal? (#%getenv "P33_CF_SEGMENTED") "1")
                   ;; segmented supply: one fasl per event, minor
                   ;; collections between batches -- the zo-replay
                   ;; materialization rhythm
                   (let* ([segs (vector-ref
                                 (p3-fasl-from-file
                                  (string-append P3 "/seg4z-codes-segs.fasl"))
                                 2)]
                          [n (vector-length segs)])
                     (let lp ([i 0])
                       (when (fx< i n)
                         (let ([e (vector-ref segs i)])
                           (zo-b-build-from-codes!
                            (string-append P3 "/seg4z-codes-"
                                           (number->string e) ".fasl")
                            (string-append P3 "/seg4z-codes-"
                                           (number->string e) ".manifest")
                            (string-append P3 "/seg4z-zolist.fasl")
                            rkt-string->keyword rkt-bytes->path
                            rkt-make-rmp rkt-prefab-rtd #t o))
                         (when (fx= 0 (fxmodulo i 8)) (collect 0 1))
                         (lp (fx+ i 1))))
                     (o "segmented codes supply: " n " segments loaded"))
                   (zo-b-build-from-codes! (string-append P3 "/seg4z-codes.fasl")
                                           (string-append P3 "/seg4z-codes.manifest")
                                           (string-append P3 "/seg4z-zolist.fasl")
                                           rkt-string->keyword rkt-bytes->path
                                           rkt-make-rmp rkt-prefab-rtd #f o))
               ;; hybrid cross-check: also replay natively and audit the
               ;; codes-supply slots against the native world, then put
               ;; the codes table back so the run stays on the codes line
               ;; forward-analysis: GC-evolution audit of the rebuilt
               ;; reloc tables (deterministic poison observation)
               (when (equal? (#%getenv "P33_CF_GCEVO") "1")
                 (zo-b-gc-evolution-audit! o))
               (when (member (#%getenv "P33_CF_XCHECK") '("1" "2"))
                 (let ([codes-vecs zo-b-vecs])
                   (zo-b-build! (string-append P3 "/seg4z-zolist.fasl")
                                rkt-load-zo-event o)
                   (zo-b-xcheck! codes-vecs zo-b-vecs o)
                   (set! zo-b-vecs codes-vecs))))
             (zo-b-build! (string-append P3 "/seg4z-zolist.fasl") rkt-load-zo-event o))
         ;; Racket-level guarded eval (uses current-namespace at call time)
         (let* ([safe-eval-cell (box #f)]
                [gcstress? (equal? (#%getenv "P33_CF_GCSTRESS") "1")]
                [safe-eval (lambda (e)
                             (if do-probes?
                                 (begin
                                   ;; crash amplifier v2: a full collection
                                   ;; before the eval DEFUSED the crash
                                   ;; (measured 8/8 green), so the trigger
                                   ;; is a MINOR collection inside the
                                   ;; eval -- shrink the trip so minors
                                   ;; fire often, and turn on the heap
                                   ;; checker so the poisoned pointer is
                                   ;; caught in the collection that meets
                                   ;; it, not at a later use
                                   ;; (small trip + checker measured
                                   ;; ~100% gc time -- checker alone
                                   ;; keeps collection count natural)
                                   (when gcstress?
                                     (try (lambda ()
                                            (($primitive $enable-check-heap) #t))
                                          #f))
                                   (unless (unbox safe-eval-cell)
                                     (set-box! safe-eval-cell
                                               (try (lambda () (rkt-make-safe-eval)) #f)))
                                   (let ([f (unbox safe-eval-cell)])
                                     (if f (f e) (cons 'err "safe-eval-creation-failed"))))
                                 (cons 'err "probes-disabled")))])
           ;; ---- resolve remaining manifest entries ----
           (p "resolving code/kw/rmp/eqvht externals... cpu=" (c-cpu))
           (let ([cnt (c2-mkht c3-equalhash c3-equalpred)]   ; (tag . ok?) -> n
                 [clwhy (c2-mkht c3-equalhash c3-equalpred)] ; codeloc fail why -> n
                 [cl-samples '()]
                 [code-miss-samples '()]
                 [zoclo-miss-samples '()])
             (define (bump! tag ok?)
               (hashtable-update! cnt (cons tag ok?) (lambda (v) (fx+ v 1)) 0))
             (let lp ([i 0])
               (when (fx< i n-ext)
                 (let* ([e (vector-ref mvec i)]
                        [tag (vector-ref e 0)])
                   (case tag
                     [(loc) (bump! 'loc (if (vector-ref resolved i) 'ok 'MISS))]
                     [(zoloc) (bump! 'zoloc (if (vector-ref resolved i) 'ok 'MISS))]
                     [(zo)
                      (let ([c (zo-b-lookup (vector-ref e 1) (vector-ref e 2))])
                        (cond
                          [c (vector-set! extvec i c) (vector-set! resolved i #t)
                             (bump! 'zo 'ok)]
                          [else
                           (bump! 'zo 'MISS)
                           (when (fx< (length code-miss-samples) 20)
                             (set! code-miss-samples
                                   (cons (c-fmt "i=~a evt=~a seq=~a" i
                                                (vector-ref e 1) (vector-ref e 2))
                                         code-miss-samples)))]))]
                     [(zomiss) (bump! 'zomiss 'MISS)]
                     [(zoclo)
                      ;; canonical 0-fv closure = the replayed code's reloc
                      ;; self-literal (see p33-zoclo-literal)
                      (let* ([c (zo-b-lookup (vector-ref e 1) (vector-ref e 2))]
                             [lit (and c (p33-zoclo-literal c))])
                        (cond
                          [lit (vector-set! extvec i lit) (vector-set! resolved i #t)
                               (bump! 'zoclo 'ok)]
                          [else
                           ;; not covered by the dummy-code fallback below:
                           ;; the slot would silently wire #f into a closure
                           ;; position; recorded here, fatal after the census
                           (bump! 'zoclo 'MISS)
                           (set! zoclo-miss-samples
                                 (cons (c-fmt "i=~a evt=~a seq=~a code=~a" i
                                              (vector-ref e 1) (vector-ref e 2)
                                              (if c "replayed;no-self-literal" "no-code"))
                                       zoclo-miss-samples))]))]
                     [(cpb)
                      (let ([c (cpb-ref (vector-ref e 1))])
                        (cond
                          [(and c ($code? c))
                           (vector-set! extvec i c) (vector-set! resolved i #t)
                           (bump! 'cpb 'ok)]
                          [else (bump! 'cpb 'MISS)]))]
                     [(staddr)
                      (let ([r (staddr-resolve (vector-ref e 1) (vector-ref e 2))])
                        (cond
                          [(and r (heapish? r))
                           (vector-set! extvec i r) (vector-set! resolved i #t)
                           (bump! 'staddr 'ok)]
                          [else (bump! 'staddr 'MISS)]))]
                     [(staddr-fail) (bump! 'staddr-fail 'MISS)]
                     [(dwseq)
                      (let ([r (c-htref dw-seq-obj (vector-ref e 1) #f)])
                        (cond
                          [r (vector-set! extvec i r) (vector-set! resolved i #t)
                             (bump! 'dwseq 'ok)]
                          [else (bump! 'dwseq 'MISS)]))]
                     [(iscope)
                      (let ([r (iscope-lookup (vector-ref e 1))])
                        (cond
                          [r (o "  [iscope ok] key: " (vector-ref e 1))
                             (vector-set! extvec i r) (vector-set! resolved i #t)
                             (bump! 'iscope 'ok)]
                          [else (o "  [iscope MISS] key: " (vector-ref e 1))
                                (bump! 'iscope 'MISS)]))]
                     [(prefab)
                      (let ([r (try (lambda ()
                                      (rkt-prefab-rtd (vector-ref e 1) (vector-ref e 2)))
                                    #f)])
                        (cond
                          [(and r (c3-rtd? r))
                           (vector-set! extvec i r) (vector-set! resolved i #t)
                           (bump! 'prefab 'ok)]
                          [else (bump! 'prefab 'MISS)]))]
                     [(bdw)
                      (let ([c (dw-lookup-code (vector-ref e 1) (vector-ref e 2))])
                        (cond
                          [(and c ($code? c))
                           (vector-set! extvec i c) (vector-set! resolved i #t)
                           (bump! 'bdw 'ok)]
                          [else (bump! 'bdw 'MISS)]))]
                     [(code)
                      (let ([c (dw-lookup-code (vector-ref e 1) (vector-ref e 2))])
                        (cond
                          [c (vector-set! extvec i c) (vector-set! resolved i #t)
                             (bump! 'code 'ok)]
                          [else
                           (bump! 'code 'MISS)
                           (when (fx< (length code-miss-samples) 20)
                             (set! code-miss-samples
                                   (cons (c-fmt "i=~a key=~s occ=~a" i
                                                (trunc (vector-ref e 1) 80) (vector-ref e 2))
                                         code-miss-samples)))]))]
                     [(code-unwalked)
                      (let ([v (c-htref dw-classvecs (vector-ref e 1) #f)])
                        (cond
                          [(and v (fx= (vector-length v) 1))
                           (vector-set! extvec i (vector-ref v 0))
                           (vector-set! resolved i #t)
                           (bump! 'code-unwalked 'ok)]
                          [else (bump! 'code-unwalked 'MISS)]))]
                     [(codeloc)
                      (let* ([tcl0 (c-cpu)]
                             [r (if p32-do-codeloc?
                                    (n3-resolve (vector-ref e 1) rootvec)
                                    (cons 'skipped 'skipped))]
                             [ignore (set! p32-tcl (+ p32-tcl (- (c-cpu) tcl0)))])
                        (cond
                          [(and (eq? (car r) 'ok) ($code? (cdr r)))
                           (vector-set! extvec i (cdr r))
                           (vector-set! resolved i #t)
                           (bump! 'codeloc 'ok)]
                          [else
                           (let ([why (if (eq? (car r) 'ok) 'not-code (cdr r))])
                             (hashtable-update! clwhy why (lambda (v) (fx+ v 1)) 0)
                             (when (fx< (length cl-samples) 12)
                               (set! cl-samples
                                     (cons (c-fmt "i=~a why=~a edges=~a" i why
                                                  (trunc (c-fmt "~s" (vector-ref e 1)) 220))
                                           cl-samples))))
                           (bump! 'codeloc 'MISS)]))]
                     [(rtd)
                      (let ([r ($rtd-by-uid (vector-ref e 1) (vector-ref e 2))])
                        (cond
                          [r (vector-set! extvec i r) (vector-set! resolved i #t)
                             (bump! 'rtd 'ok)]
                          [else (bump! 'rtd 'MISS)]))]
                     [(kw)
                      (let ([k (try (lambda () (rkt-string->keyword (vector-ref e 1))) #f)])
                        (cond
                          [k (vector-set! extvec i k) (vector-set! resolved i #t)
                             (bump! 'kw 'ok)]
                          [else (bump! 'kw 'MISS)]))]
                     [(rmp)
                      (let* ([trmp0 (c-cpu)]
                             [spec (vector-ref e 1)]
                             [name (let dec ([s spec])
                                     (and s
                                          (case (vector-ref s 0)
                                            [(sym) (vector-ref s 1)]
                                            [(pth) (try (lambda ()
                                                          (rkt-bytes->path (vector-ref s 1)))
                                                        #f)]
                                            [(lst) (let ([b (dec (vector-ref s 1))])
                                                     (and b (cons b (vector-ref s 2))))]
                                            [else #f])))]
                             [r (and name
                                     (try (lambda () (rkt-make-rmp name))
                                          #f))])
                        (set! p32-trmp (+ p32-trmp (- (c-cpu) trmp0)))
                        (cond
                          [r (vector-set! extvec i r) (vector-set! resolved i #t)
                             (bump! 'rmp 'ok)]
                          [else (bump! 'rmp 'MISS)]))]
                     [(eqvht)
                      (let* ([weak (vector-ref e 1)]
                             [kind (vector-ref e 2)]
                             [t (case kind
                                  [(equal) (c2-mkht c3-equalhash c3-equalpred)]
                                  [else (if weak (c3-mkweqv) (c2-mkeqvht))])])
                        (vector-set! extvec i t)
                        (vector-set! resolved i #t)
                        (bump! 'eqvht 'ok))]
                     [(unres) (bump! (vector-ref e 1) 'MISS)]
                     [else (bump! tag 'MISS)]))
                 (lp (fx+ i 1))))
             (o "")
             (o "==== external resolution census (tag . verdict) ====")
             (dump-counts o cnt "  resolution:")
             (dump-counts o clwhy "  codeloc failure reasons:")
             (for-each (lambda (s) (o "   codeloc-fail: " s)) (reverse cl-samples))
             (for-each (lambda (s) (o "   code-miss: " s)) (reverse code-miss-samples))
             ;; zoclo MISS is protocol breakage (zo replay determinism or the
             ;; A/B literal correspondence broke); abort before the dummy
             ;; wiring / fasl-read can turn it into silent corruption
             (unless (null? zoclo-miss-samples)
               (for-each (lambda (s) (o "   zoclo-miss: " s)) (reverse zoclo-miss-samples))
               (o "FATAL: unresolved zoclo external(s); aborting segment install")
               (p "FATAL zoclo")
               (c-flush lp)
               (exit 1))
             ;; any unresolved code-family external would make the closure-fasl
             ;; read blow up; wire an identifiable dummy code object instead
             (let ([dummy-code
                    (lambda (e i)
                      (let* ([label (c-fmt "seg4 placeholder code invoked: i=~a tag=~a name=~a"
                                           i (vector-ref e 0)
                                           (if (fx> (vector-length e) 1)
                                               (trunc (c-fmt "~a" (vector-ref e 1)) 80)
                                               "?"))]
                             [fc (if (and (eq? (vector-ref e 0) 'zomiss)
                                          (fx> (vector-length e) 2)
                                          (fixnum? (vector-ref e 2)))
                                     (vector-ref e 2)
                                     0)]
                             [vars (let lp ([k 0] [acc '()])
                                     (if (fx= k fc)
                                         acc
                                         (lp (fx+ k 1)
                                             (cons (string->symbol (c-fmt "p33dv~a" k)) acc))))]
                             [mk (eval (list 'lambda vars
                                             (list 'lambda 'args
                                                   (cons 'error
                                                         (cons ''p3-dummy-code
                                                               (cons label vars))))))]
                             [cl (apply mk (let lp ([k 0] [acc '()])
                                             (if (fx= k fc) acc (lp (fx+ k 1) (cons 0 acc)))))])
                        ($ccode cl)))]
                   [n-dummy 0])
               (let lp ([i 0])
                 (when (fx< i n-ext)
                   (let ([e (vector-ref mvec i)])
                     (when (and (not (vector-ref resolved i))
                                (memq (vector-ref e 0) '(code code-unwalked codeloc zo zomiss zoloc bdw cpb)))
                       (let ([dc (dummy-code e i)])
                         (vector-set! extvec i dc)
                         (set! p33-dummies (cons (cons i dc) p33-dummies)))
                       (set! n-dummy (fx+ n-dummy 1))))
                   (lp (fx+ i 1))))
               (o "code placeholders wired (dummy code object): " n-dummy))
             (o "resolve sub-timing: codeloc-n3-resolve=" p32-tcl
                " ms  rmp-resolve=" p32-trmp " ms  (do-codeloc?=" p32-do-codeloc? ")")
             (let ([tot-ok 0])
               (let lp ([i 0])
                 (when (fx< i n-ext)
                   (when (vector-ref resolved i) (set! tot-ok (fx+ tot-ok 1)))
                   (lp (fx+ i 1))))
               (o "TOTAL resolved: " tot-ok " / " n-ext
                  "  (" (fxdiv (fx* 1000 tot-ok) (fxmax 1 n-ext)) " per-mille)"))
             ;; ---- load the state fasl ----
             (when (equal? (#%getenv "P33_DUPTRACE") "1")
               ;; phase census t-a: scopes minted since mark by zo replay/bridges
               (let ([c (scope-census rootvec)])
                 (let f ([l c] [fresh 0])
                   (if (null? l)
                       (o "[t-a pre-fasl] scopes reachable: " (length c)
                          "  minted-since-mark: " fresh)
                       (f (cdr l)
                          (if (eq-hashtable-ref native-scope-tab (caar l) #f)
                              fresh
                              (begin (eq-hashtable-set! phase-a-scope-tab (caar l) #t)
                                     (fx+ fresh 1))))))))
             (p "fasl-read of seg4-state... cpu=" (c-cpu))
             (let* ([bv (p3-read-bv-file (string-append P3 "/seg4z-state.fasl"))]
                    [stamp-bv (p "state-bv-read done... cpu=" (c-cpu))]
                    [t0 (c-cpu)]
                    [root (call/cc
                           (lambda (k)
                             (with-exception-handler
                               (lambda (ex) (k (list 'READ-ERR (cond->string ex))))
                               (lambda ()
                                 (let ([ip (c-obvip bv)])
                                   (c-faslr ip 'load extvec))))))])
               (cond
                 [(and (pair? root) (eq? (car root) 'READ-ERR))
                  (o "FATAL: fasl-read failed: " (cadr root))
                  (p "FATAL read")
                  (c-flush lp)
                  (exit 1)]
                 [else
                  (o "fasl-read OK in " (- (c-cpu) t0) "ms; bytes=" (c2-bvlen bv))
                  (when (equal? (#%getenv "P33_DUPTRACE") "1")
                    (let ([c (scope-census (vector root))])
                      (for-each (lambda (pr) (eq-hashtable-set! p33-seg-scope-ht (car pr) #t)) c)
                      (o "[t-b post-fasl] scopes in segment graph: " (length c))))
                  ;; NOTE: no heap/segment walks inside the attach window
                  ;; (fasl-read -> replay -> acceptance): a diagnostic walk's
                  ;; allocations shift GC timing and perturb weak/ephemeron
                  ;; state -- measured as pass=2 -> pass=0 (d15/d20 regressions).
                  ;; The seg-leak audit ran once and reported ZERO true A-copies.
                  ;; ---- (h7) eq-hash-code registration sync: racket hasheq
                  ;; HAMTs in the segment are organized by A's registration
                  ;; numbers; install A's post-mark registrations into B's
                  ;; codes table (install-if-absent; conflicts counted)
                  (let ([delta (if (fx> (vector-length root) 5) (vector-ref root 5) (vector))])
                    (let ([n-inst 0] [n-conf 0] [n-dead 0])
                      (when codes-tab
                        (let lp ([i 0])
                          (when (fx< i (vector-length delta))
                            (let* ([pr (vector-ref delta i)]
                                   [obj (car pr)] [num (cdr pr)])
                              (cond
                                [(not (heapish? obj)) (set! n-dead (fx+ n-dead 1))]
                                [else
                                 (let ([cur (eq-hashtable-ref codes-tab obj #f)])
                                   (cond
                                     [(not cur)
                                      (eq-hashtable-set! codes-tab obj num)
                                      (set! n-inst (fx+ n-inst 1))]
                                     [(fx= cur num) (void)]
                                     [else (set! n-conf (fx+ n-conf 1))]))]))
                            (lp (fx+ i 1)))))
                      (o "h7 eq-hash-code sync: delta=" (vector-length delta)
                         " installed=" n-inst " conflicts=" n-conf " nonheap=" n-dead
                         (if codes-tab "" "  (codes table NOT FOUND)"))))
                  (let ([patch (vector-ref root 1)]
                        [tags (vector-ref root 2)]
                        [aux (vector-ref root 3)])
                    (o "patch entries: " (vector-length patch)
                       "  aux eqvht entries: " (vector-length aux))
                    ;; ---- populate reconstructed eqv hashtables ----
                    (let ([n-aux-kv 0])
                      (let lp ([i 0])
                        (when (fx< i (vector-length aux))
                          (let* ([a (vector-ref aux i)]
                                 [t (vector-ref a 0)]
                                 [kv (vector-ref a 3)])
                            (when (hashtable? t)
                              (let lp2 ([j 0])
                                (when (fx< j (vector-length kv))
                                  (let ([pr (vector-ref kv j)])
                                    (try (lambda () (c2-htset! t (car pr) (cdr pr))) #f)
                                    (set! n-aux-kv (fx+ n-aux-kv 1)))
                                  (lp2 (fx+ j 1))))))
                          (lp (fx+ i 1))))
                      (o "aux kv entries installed: " n-aux-kv))
                    ;; ---- (h6) restore rumble rtd plists (P3.3): deserialized
                    ;; rtd copies re-intern their uid gensyms, but rumble keeps
                    ;; inspector/'prefab and struct-type properties on the uid
                    ;; symbol plist, which does not travel in the fasl ----
                    (let ([rps (if (fx> (vector-length root) 4) (vector-ref root 4) '#())]
                          [n-put 0] [n-rtd 0] [n-skip 0]
                          [h6-lo 0] [h6-hi 999999] [h6-idx 0])
                      (let ([spec (#%getenv "P33_H6_RANGE")])
                        (when spec
                          (let ([sl (string-length spec)])
                            (let f ([i 0])
                              (cond
                                [(fx>= i sl) (void)]
                                [(char=? (string-ref spec i) #\:)
                                 (set! h6-lo (string->number (substring spec 0 i)))
                                 (set! h6-hi (string->number (substring spec (fx+ i 1) sl)))]
                                [else (f (fx+ i 1))])))))
                      (let lp ([i 0])
                        (when (fx< i (vector-length rps))
                          (let* ([e (vector-ref rps i)]
                                 [r (vector-ref e 0)]
                                 [pl (vector-ref e 1)])
                            (if (c3-rtd? r)
                                (begin
                                  (set! n-rtd (fx+ n-rtd 1))
                                  (let ([uid (try (lambda () (c3-rtypeuid r)) #f)])
                                    (when uid
                                      (let plp ([j 0])
                                        (when (fx< (fx+ j 1) (vector-length pl))
                                          (begin
                                            (set! h6-idx (fx+ h6-idx 1))
                                            (if (and (fx>= h6-idx h6-lo) (fx<= h6-idx h6-hi))
                                                (if (try (lambda ()
                                                           (#%putprop uid
                                                                      (vector-ref pl j)
                                                                      (vector-ref pl (fx+ j 1)))
                                                           #t)
                                                         #f)
                                                    (set! n-put (fx+ n-put 1))
                                                    (set! n-skip (fx+ n-skip 1)))
                                                (set! n-skip (fx+ n-skip 1))))
                                          (plp (fx+ j 2)))))))
                                (set! n-skip (fx+ n-skip 1))))
                          (lp (fx+ i 1))))
                      (o "h6 rtd-plist restore: rtds=" n-rtd "  props-put=" n-put
                         "  skipped=" n-skip))
                    ;; ---- (c)-class rebuild hooks (P3.2): explicit, BEFORE replay ----
                    (p "rebuild hooks... cpu=" (c-cpu))
                    (let ([nsr (vector-ref rootvec 0)]
                          [n-lock 0])
                      ;; (h1) module-registry lock-box reset (heap surgery)
                      (let ([nf (rtd-total-fields ($rtd nsr))])
                        (let hloop ([i 0])
                          (when (fx< i nf)
                            (let ([f (try (lambda () ($rref nsr i)) #f)])
                              (when (and f ($rec? f) (not (hashtable? f))
                                         (eq? (rtd-name f) 'module-registry))
                                (let ([rf (rtd-total-fields ($rtd f))])
                                  (let bloop ([j 0])
                                    (when (fx< j rf)
                                      (let ([bx (try (lambda () ($rref f j)) #f)])
                                        (when (box? bx)
                                          (set-box! bx #f)
                                          (set! n-lock (fx+ n-lock 1))))
                                      (bloop (fx+ j 1)))))))
                            (hloop (fx+ i 1)))))
                      ;; (h2) expander module-cache clear (ready-made racket-level hook)
                      (let ([r (if (equal? (#%getenv "P33_SKIP_H2") "1")
                                   'skipped-by-env
                                   (try (lambda () (rkt-hook-module-cache-clear!)) 'HOOK-ERR))])
                        (o "")
                        (o "==== rebuild hooks (P3.2) ====")
                        (o "  (h1) registry lock-box reset: boxes-reset=" n-lock)
                        (o "  (h2) module-cache-clear!: " (if (eq? r 'HOOK-ERR) r r)
                           "  [env P33_SKIP_H2=" (try (lambda () (#%getenv "P33_SKIP_H2")) 'GETENV-ERR) "]")
                        (o "  (h3) links-cache: left as-is (filesystem-derived, process-valid)")
                        (o "  (h4) thread-cell seeding: 'thread-tagged ops now replayed (skip-tags=" p3-skip-tags ")")
                        (o "  (h5) counters/custodian: natural / skipped")))
                    ;; ---- provenance pre-snapshot ----
                    (let ([sort-pre (cons 'err "no-preload (P3.3: B never instantiates)")]
                          [map-pre (cons 'err "no-preload (P3.3: B never instantiates)")])
                      ;; ---- patch replay ----
                      (p "patch replay... cpu=" (c-cpu))
                      (let ([n-applied 0] [n-skip 0] [n-fail 0] [n-noctr 0]
                            [fail-samples '()]
                            [opcnt (c2-mkht c3-equalhash c3-equalpred)])
                        (let lp ([i 0])
                          (when (fx< i (vector-length patch))
                            (let* ([e (vector-ref patch i)]
                                   [op (vector-ref e 0)]
                                   [x (vector-ref e 1)]
                                   [tag (vector-ref tags i)])
                              (cond
                                [(memq tag p3-skip-tags)
                                 (set! n-skip (fx+ n-skip 1))]
                                ;; D1: the root-expand-context's
                                ;; representative-scope binding table can
                                ;; neither be overwritten (A-side scopes do
                                ;; not unify with B-side syntax literals)
                                ;; nor skipped (racket/init's top-level
                                ;; bindings live only in the A table), so
                                ;; deep-merge the A entries into the B
                                ;; table, keeping the B record's identity
                                [(and (eq? op 'slot)
                                      ($rec? x)
                                      (eq? (rtd-name x) 'representative-scope))
                                 ;; single-lineage world (post-preheat): A's binding
                                 ;; table is a strict superset of B's boot table and
                                 ;; every scope it references resolves consistently
                                 ;; (iscope trio + in-graph A scopes), so a PLAIN
                                 ;; overwrite is the correct semantics. The old D1
                                 ;; "deep merge" assumed Chez hashtables, silently
                                 ;; no-op'd on the racket immutable-hash syms, and
                                 ;; blocked racket/init's 1404 top-level bindings.
                                 (let ([ok (try (lambda ()
                                                  (o "  [slot-overwrite] rep-scope f" (vector-ref e 3))
                                                  ($rset! x (vector-ref e 3) (vector-ref e 4))
                                                  #t)
                                                #f)])
                                   (if ok
                                       (set! n-applied (fx+ n-applied 1))
                                       (set! n-fail (fx+ n-fail 1))))]
                                [(not x)
                                 (set! n-noctr (fx+ n-noctr 1))]
                                [else
                                 (let ([ok
                                        (try
                                         (lambda ()
                                           (case op
                                             [(ht+ ht~)
                                              (and (hashtable? x)
                                                   (begin (c2-htset! x (vector-ref e 2)
                                                                     (vector-ref e 3))
                                                          #t))]
                                             [(ht-)
                                              (and (hashtable? x)
                                                   (begin (c2-htdel! x (vector-ref e 2)) #t))]
                                             [(slot)
                                              (let ([kind (vector-ref e 2)]
                                                    [idx (vector-ref e 3)]
                                                    [val (vector-ref e 4)])
                                                (case kind
                                                  [(rec) ($rset! x idx val) #t]
                                                  [(vec) (vector-set! x idx val) #t]
                                                  [(box) (set-box! x val) #t]
                                                  [(pair) (if (fx= idx 0)
                                                              (set-car! x val)
                                                              (set-cdr! x val))
                                                          #t]
                                                  [(stvec) ($stset! x idx val) #t]
                                                  [else #f]))]
                                             [else #f]))
                                         #f)])
                                   (cond
                                     [ok (set! n-applied (fx+ n-applied 1))
                                         (hashtable-update! opcnt op (lambda (v) (fx+ v 1)) 0)]
                                     [else
                                      (set! n-fail (fx+ n-fail 1))
                                      (when (fx< (length fail-samples) 15)
                                        (set! fail-samples
                                              (cons (c-fmt "i=~a op=~a tag=~a ctr=~a"
                                                           i op tag (obj-brief x))
                                                    fail-samples)))]))]))
                            (lp (fx+ i 1))))
                        (o "")
                        (o "==== replay ====")
                        (o "  applied: " n-applied "  skipped(tag): " n-skip
                           "  container-unresolved: " n-noctr "  failed: " n-fail)
                        (dump-counts o opcnt "  applied ops by kind:")
                        (for-each (lambda (s) (o "   replay-fail: " s)) (reverse fail-samples)))
                      ;; ---- dummy-holder forensics: retired scaffolding (it walks
                      ;; the full phase-table graphs and costs ~2min); re-enable by
                      ;; calling (p33-dummy-holders! o patch tags p33-dummies) here ----
                      ;; ---- provenance post ----
                      (let ([sort-post (safe-eval 'sort)]
                            [map-post (safe-eval 'map)])
                        (o "")
                        (o "==== provenance ====")
                        (o "  sort binding changed by replay (expect #t): "
                           (not (and (eq? (car sort-pre) 'val) (eq? (car sort-post) 'val)
                                     (eq? (cdr sort-pre) (cdr sort-post)))))
                        (o "  map binding unchanged kernel prim (P3.3: pre n/a, expect #f): "
                           (and (eq? (car map-pre) 'val) (eq? (car map-post) 'val)
                                (eq? (cdr map-pre) (cdr map-post)))))
                      ;; ---- layer probes (binding vs variable) ----
                      (if (equal? (#%getenv "P33_LPROBES") "0")
                          (o "==== layer probes SKIPPED (P33_LPROBES=0) ====")
                          (begin
                            (o "==== layer probes ====")
                            (o "  [B] ns census: " (rkt-ns-census))
                            (o "  " (rkt-probe-layers 'require))
                            (o "  " (rkt-probe-layers 'match))
                            (o "  " (rkt-probe-layers '+))
                            (o "  " (rkt-probe-layers 'lambda))
                            (o "==== syntax-debug-info (query ctx vs table bindings) ====")
                            (o "  require: " (rkt-debug-binding 'require))
                            (o "  lambda:  " (rkt-debug-binding 'lambda))))
                      (when (equal? (#%getenv "P33_TL") "1")
                        ;; top-level scope table probe: B's rep-scope 11/2
                        (o "==== B trio binding-table peek ====")
                        (for-each
                         (lambda (k)
                           (let ([sc (iscope-lookup k)])
                             (if (not sc)
                                 (o "  " k " not in iscope-tab")
                                 (let* ([bt (try (lambda () (#%$record-ref sc 2)) #f)]
                                        [syms (cond
                                                [(and bt ($rec? bt)
                                                      (eq? (try (lambda () (rtd-name bt)) #f)
                                                           'table-with-bulk-bindings))
                                                 (try (lambda () (#%$record-ref bt 0)) #f)]
                                                [else bt])])
                                   (o "  " k " bt=" (obj-brief bt)
                                      " peek=" (try (lambda () (rkt-syms-peek syms k)) 'PEEK-ERR))))))
                         '((scope . 0) (representative-scope . 11/2)))
                        ;; TL2+TL3: ns REC scopes + ms-5 phase->rep internals
                        (o "==== TL0: trio-11/2 syms via raw stencil scan ====")
                        (let ([sc (iscope-lookup '(representative-scope . 11/2))])
                          (when sc
                            (let* ([bt (try (lambda () (#%$record-ref sc 2)) #f)]
                                   [syms (if (and ($rec? bt)
                                                  (eq? (try (lambda () (rtd-name bt)) #f)
                                                       'table-with-bulk-bindings))
                                             (try (lambda () (#%$record-ref bt 0)) #f)
                                             bt)]
                                   [nsym 0] [hits '()]
                                   [seen (make-eq-hashtable)])
                              (let scan ([x syms] [d 0])
                                (when (and x (fx< d 12)
                                           (or (not (heapish? x))
                                               (not (eq-hashtable-ref seen x #f))))
                                  (when (heapish? x) (eq-hashtable-set! seen x #t))
                                  (cond
                                    [($stvec? x)
                                     (let ([m ($stlen x)])
                                       (let sl ([j 0])
                                         (when (fx< j m)
                                           (scan (try (lambda () ($stref x j)) #f) (fx+ d 1))
                                           (sl (fx+ j 1)))))]
                                    [(pair? x) (scan (car x) (fx+ d 1)) (scan (cdr x) (fx+ d 1))]
                                    [(symbol? x)
                                     (set! nsym (fx+ nsym 1))
                                     (when (memq x '(require sort match lambda + for/list))
                                       (set! hits (cons x hits)))]
                                    [else (void)])))
                              (o "  bt=" (obj-brief bt) " syms=" (obj-brief syms)
                                 " symbols-in-stencil=" nsym " notable=" hits)
                              ;; bulk-bindings chain health
                              (let ([bulks (try (lambda () (#%$record-ref bt 2)) #f)])
                                (o "  bulk-bindings: " (obj-brief bulks)
                                   " len=" (if (list? bulks) (length bulks) 'n/a))
                                (when (and (pair? bulks) ($rec? (car bulks)))
                                  (let* ([bba (car bulks)]
                                         [scs (try (lambda () (#%$record-ref bba 0)) #f)]
                                         [blk (try (lambda () (#%$record-ref bba 1)) #f)])
                                    (o "  bba[0]: scopes=" (obj-brief scs) " bulk=" (obj-brief blk)
                                       " bulk-rtd=" (try (lambda () (rtd-name blk)) '?))
                                    ;; scope-set membership identity
                                    (when ($stvec? scs)
                                      (let ([m ($stlen scs)])
                                        (let sl ([j 0])
                                          (when (fx< j m)
                                            (let ([e (try (lambda () ($stref scs j)) #f)])
                                              (when (and ($rec? e)
                                                         (try (lambda () (scope-proper-key e)) #f))
                                                (let ([k (scope-proper-key e)])
                                                  (o "    scope-set member: " k
                                                     " trio-eq=" (if (eq? e (iscope-lookup k)) 'y 'n)))))
                                            (sl (fx+ j 1))))))
                                    ;; bulk record fields
                                    (when ($rec? blk)
                                      (let ([n (try (lambda () (rtd-total-fields ($rtd blk))) 0)])
                                        (let bf ([i 0])
                                          (when (fx< i n)
                                            (o "    bulk.f" i ": "
                                               (obj-brief (try (lambda () (#%$record-ref blk i)) '?)))
                                            (bf (fx+ i 1))))))
                                    ;; TL5: identity confrontation
                                    (let* ([ns (vector-ref rootvec 0)]
                                           [nsreg (try (lambda () (#%$record-ref ns 9)) #f)]
                                           [breg (try (lambda () (#%$record-ref blk 7)) #f)]
                                           [count-stencil-syms
                                            (lambda (sv)
                                              (let ([n 0] [seen (make-eq-hashtable)])
                                                (let scan ([x sv] [d 0])
                                                  (when (and x (fx< d 12)
                                                             (or (not (heapish? x))
                                                                 (not (eq-hashtable-ref seen x #f))))
                                                    (when (heapish? x) (eq-hashtable-set! seen x #t))
                                                    (cond
                                                      [($stvec? x)
                                                       (let ([m ($stlen x)])
                                                         (let sl ([j 0])
                                                           (when (fx< j m)
                                                             (scan (try (lambda () ($stref x j)) #f) (fx+ d 1))
                                                             (sl (fx+ j 1)))))]
                                                      [(pair? x) (scan (car x) (fx+ d 1)) (scan (cdr x) (fx+ d 1))]
                                                      [(symbol? x) (set! n (fx+ n 1))]
                                                      [else (void)])))
                                                n))])
                                      (o "  [TL5] ns.f9 reg: " (obj-brief nsreg)
                                         "  bulk.f7 reg: " (obj-brief breg)
                                         "  eq? " (if (eq? nsreg breg) 'YES 'NO))
                                      (when ($rec? nsreg)
                                        (let ([nf (try (lambda () (rtd-total-fields ($rtd nsreg))) 0)])
                                          (let rf ([i 0])
                                            (when (fx< i nf)
                                              (let* ([v (try (lambda () (#%$record-ref nsreg i)) '?)]
                                                     [vv (if (box? v) (unbox v) v)])
                                                (o "    nsreg.f" i ": " (obj-brief v)
                                                   (if (hashtable? vv)
                                                       (c-fmt " (ht size ~a)" (hashtable-size vv))
                                                       "")))
                                              (rf (fx+ i 1))))))
                                      (o "  [TL5] bulk.f0 provides-cache symbol-count: "
                                         (count-stencil-syms (try (lambda () (#%$record-ref blk 0)) #f))))))))))
                        (o "==== TL2: ns root-expand-context scopes ====")
                        (let* ([ns (vector-ref rootvec 0)]
                               [recbox (try (lambda () (#%$record-ref ns 2)) #f)]
                               [rec0 (and (box? recbox) (unbox recbox))]
                               [rec (if (and rec0 ($rec? rec0)
                                             (eq? (try (lambda () (rtd-name rec0)) #f)
                                                  'root-expand-context))
                                        rec0
                                        #f)]
                               [inner (and rec
                                           (let ([i0 (try (lambda () (#%$record-ref rec 0)) #f)])
                                             (if (and i0 ($rec? i0)) i0 #f)))]
                               [peek1
                                (lambda (x)
                                  (let ([k (try (lambda () (scope-proper-key x)) #f)])
                                    (if (not k)
                                        ""
                                        (string-append
                                         "  key=" (try (lambda () (c-fmt "~s" k)) "?")
                                         " trio-eq=" (if (eq? x (iscope-lookup k)) "y" "n")
                                         (if (memq (car k) '(scope interned-scope representative-scope))
                                             (try (lambda ()
                                                    (let* ([bt (#%$record-ref x 2)]
                                                           [syms (if (and ($rec? bt)
                                                                          (eq? (try (lambda () (rtd-name bt)) #f)
                                                                               'table-with-bulk-bindings))
                                                                     (#%$record-ref bt 0)
                                                                     bt)])
                                                      (c-fmt " peek=~s" (rkt-syms-peek syms (car k)))))
                                                  " peek-err")
                                             "")))))]
                               [dumprec
                                (lambda (label r)
                                  (when (and r ($rec? r))
                                    (let ([n (try (lambda () (rtd-total-fields ($rtd r))) 0)])
                                      (let fl ([i 0])
                                        (when (fx< i n)
                                          (let ([v (try (lambda () (#%$record-ref r i)) 'UNREADABLE)])
                                            (o "  " label ".f" i ": " (obj-brief v)
                                               (try (lambda () (peek1 v)) " <peek1-err>"))
                                            (when (and ($rec? v)
                                                       (eq? (try (lambda () (rtd-name v)) #f)
                                                            'shifted-multi-scope))
                                              (let ([ms (try (lambda () (#%$record-ref v 1)) #f)])
                                                (when (and ms ($rec? ms))
                                                  (o "      owner-ms: " (obj-brief ms)
                                                     (try (lambda () (peek1 ms)) ""))))))
                                          (fl (fx+ i 1)))))))])
                          (if (not rec)
                              (o "  nav failed")
                              (begin
                                (dumprec "rec" rec)
                                (dumprec "inner" inner)))
                          (o "==== TL3: trio ms-5 phase->rep table ====")
                          (let ([ms (iscope-lookup '(multi-scope . 5))])
                            (when ms
                              ;; TL3b: exact phase->rep PAIRS via racket hash bridge
                              (let* ([f2 (try (lambda () (#%$record-ref ms 2)) #f)]
                                     [h (if (box? f2) (unbox f2) f2)]
                                     [ks (try (lambda () (rkt-hash-keys h)) 'ERR)])
                                (o "  [TL3b] phase keys: " (if (list? ks) ks ks))
                                (when (list? ks)
                                  (for-each
                                   (lambda (k)
                                     (let ([v (try (lambda () (rkt-hash-get h k)) #f)])
                                       (o "    phase " k " -> " (obj-brief v)
                                          " " (try (lambda () (scope-proper-key v)) '?)
                                          " trio-eq=" (if (and v (eq? v (iscope-lookup
                                                                          (try (lambda () (scope-proper-key v)) #f))))
                                                          'y 'n))))
                                   ks)))))
                          (let ([ms (iscope-lookup '(multi-scope . 5))])
                            (when ms
                              (let ([n (try (lambda () (rtd-total-fields ($rtd ms))) 0)])
                                (let fl ([i 0])
                                  (when (fx< i n)
                                    (let* ([v (try (lambda () (#%$record-ref ms i)) 'UNREADABLE)]
                                           [vv (if (box? v) (unbox v) v)])
                                      (o "  ms.f" i ": " (obj-brief v)
                                         (if (box? v) (string-append " -> " (obj-brief vv)) ""))
                                      (when (hashtable? vv)
                                        (let ([ks (try (lambda () (c-htkeys vv)) (vector))])
                                          (let ke ([j 0])
                                            (when (and (fx< j (vector-length ks)) (fx< j 6))
                                              (let* ([k (vector-ref ks j)]
                                                     [rv (try (lambda () (c-htref vv k #f)) #f)])
                                                (o "    [" (try (lambda () (trunc (c-fmt "~s" k) 40)) "?")
                                                   "] -> " (obj-brief rv)
                                                   (try (lambda () (peek1 rv)) "")))
                                              (ke (fx+ j 1))))))
                                      (when ($stvec? vv)
                                        ;; racket immutable hash (HAMT stencil): scan for scope recs
                                        (let ([seen (make-eq-hashtable)])
                                          (let scan ([x vv] [d 0])
                                            (when (and (fx< d 8) (not (eq-hashtable-ref seen x #f)))
                                              (eq-hashtable-set! seen x #t)
                                              (cond
                                                [($stvec? x)
                                                 (let ([m ($stlen x)])
                                                   (let sl ([j 0])
                                                     (when (fx< j m)
                                                       (scan (try (lambda () ($stref x j)) #f) (fx+ d 1))
                                                       (sl (fx+ j 1)))))]
                                                [(pair? x) (scan (car x) (fx+ d 1)) (scan (cdr x) (fx+ d 1))]
                                                [(and ($rec? x) (try (lambda () (scope-proper-key x)) #f))
                                                 (o "    stencil-resident: " (obj-brief x)
                                                    (try (lambda () (peek1 x)) ""))]
                                                [else (void)])))))
                                      (when (and ($rec? vv) (not (hashtable? vv)))
                                        (o "    (rec) " (try (lambda () (peek1 vv)) ""))))
                                    (fl (fx+ i 1)))))))))
                      (when (equal? (#%getenv "P33_SDI") "1")
                        (o "==== offending-syntax debug-info for (+ 1 2) ====")
                        (o "  " (try (lambda () (rkt-analyze-syntax-fail '(+ 1 2))) 'SDI-ERR)))
                      (when (equal? (#%getenv "P33_REBIND") "1")
                        ;; re-hang top-level bulk bindings via the core form:
                        ;; all modules are already instantiated in the segment,
                        ;; so this only re-installs binding-table entries
                        (o "==== rebind: (#%require racket/init) ====")
                        (o "  racket/base: "
                           (try (lambda () (rkt-analyze-syntax-fail '(#%require racket/base))) 'ERR))
                        (o "  racket/init: "
                           (try (lambda () (rkt-analyze-syntax-fail '(#%require racket/init))) 'ERR)))
                      ;; forward-analysis mount 2: after the state world
                      ;; is loaded and replayed, does GC evolution now
                      ;; corrupt the codes tables (state-world writes as
                      ;; the poisoning agent)?
                      (when (equal? (#%getenv "P33_CF_GCEVO") "2")
                        (zo-b-gc-evolution-audit! o))
                      ;; solution-2 forensics: weak-structure audit in
                      ;; the open poison window (before the clearing
                      ;; collection below)
                      (when (equal? (#%getenv "P33_CF_WEAKAUDIT") "1")
                        (p33-weak-audit! rootvec "post-replay" o))
                      ;; mitigation discipline (solution 3, measured
                      ;; 8/8 crash-free): a full collection before the
                      ;; first eval closes the known poison window --
                      ;; an unswept heap meeting the eval's first minor
                      ;; collections.  Default ON for the codes supply;
                      ;; P33_CF_NOCLEAR=1 disables it for control runs.
                      (when (and (equal? (#%getenv "P33_CODEFASL") "1")
                                 (not (equal? (#%getenv "P33_CF_NOCLEAR") "1")))
                        (let ([t0 (c-cpu)])
                          (collect (collect-maximum-generation))
                          (p "pre-eval clearing collection... cpu=" (c-cpu))
                          (o "pre-eval clearing collection: "
                             (- (c-cpu) t0) " ms")))
                      ;; ---- acceptance ----
                      (p "acceptance... cpu=" (c-cpu))
                      (o "")
                      (o "==== ACCEPTANCE on NS* ====")
                      (let ([n-pass 0] [n-fail 0])
                        (define pre-eval-scopes
                          (let ([c (scope-census rootvec)])
                            (o "pre-eval scope census: " (length c) " scopes")
                            ;; duplicate detector: same (name . id) seen on
                            ;; two DIFFERENT objects = split scope world
                            (let ([idtab (c2-mkht c3-equalhash c3-equalpred)])
                              (for-each
                               (lambda (pr)
                                 (let* ([t (cdr pr)]
                                        [k (cons (car t) (cadr t))])
                                   (hashtable-update! idtab k (lambda (v) (fx+ v 1)) 0)))
                               c)
                              (let-values ([(ks vs) (hashtable-entries idtab)])
                                (let dp ([i (fx- (vector-length ks) 1)] [nd 0])
                                  (if (fx< i 0)
                                      (o "  duplicated (name . id) keys: " nd)
                                      (begin
                                        (when (fx> (vector-ref vs i) 1)
                                          (let* ([k (vector-ref ks i)]
                                                 [members
                                                  (let mf ([l c] [acc '()])
                                                    (cond
                                                      [(null? l) acc]
                                                      [(equal? (cons (car (cdar l)) (cadr (cdar l))) k)
                                                       (mf (cdr l)
                                                           (cons (if (eq-hashtable-ref p33-seg-scope-ht (caar l) #f)
                                                                     'seg 'native)
                                                                 acc))]
                                                      [else (mf (cdr l) acc)]))])
                                            (o "  DUP scope: " k " x" (vector-ref vs i)
                                               " lineage: " members)))
                                        (dp (fx- i 1)
                                            (if (fx> (vector-ref vs i) 1) (fx+ nd 1) nd)))))))
                            c))
                        (define (check name expr pred expect-desc)
                          (let ([r (safe-eval expr)])
                            (cond
                              [(and (eq? (car r) 'val)
                                    (try (lambda () (pred (cdr r))) #f))
                               (set! n-pass (fx+ n-pass 1))
                               (o "  [PASS] " name " => " (fmt-val (cdr r) 100))]
                              [else
                               (set! n-fail (fx+ n-fail 1))
                               (o "  [FAIL] " name " expected " expect-desc
                                  " got " (car r) ": " (fmt-val (cdr r) 200))])))
                        (p "check-a about to run... cpu=" (c-cpu))
                        (check "(a) (+ 1 2)"
                               '(+ 1 2)
                               (lambda (v) (eqv? v 3)) "3")
                        (p "check-a done... cpu=" (c-cpu))
                        (check "(b) (map add1 (list 1 2))"
                               '(map add1 (list 1 2))
                               (lambda (v) (c3-equalpred v '(2 3))) "(2 3)")
                        (check "(c) (sort (list 3 1 2) <)"
                               '(sort (list 3 1 2) <)
                               (lambda (v) (c3-equalpred v '(1 2 3))) "(1 2 3)")
                        (check "(d1) (require racket/list)"
                               '(require racket/list)
                               (lambda (v) #t) "void")
                        (check "(d1') (last (list 1 2 3))"
                               '(last (list 1 2 3))
                               (lambda (v) (eqv? v 3)) "3")
                        (check "(d2) (require file/sha1) [cold module load]"
                               '(require file/sha1)
                               (lambda (v) #t) "void")
                        (check "(d2') (sha1 (open-input-bytes (string->bytes/utf-8 \"abc\")))"
                               '(sha1 (open-input-bytes (string->bytes/utf-8 "abc")))
                               (lambda (v) (and (string? v)
                                                (c2-str=? v "a9993e364706816aba3e25717850c26c9cd0d89d")))
                               "sha1 hex of abc")
                        (check "(e) (car 5) raises contract error"
                               '(with-handlers ([(lambda (x) #t)
                                                 (lambda (x) (if (exn? x) (exn-message x) x))])
                                  (car 5))
                               (lambda (v) (and (string? v)
                                                (substr? v "car")
                                                (substr? v "contract violation")))
                               "exn message with car contract violation")
                        (let* ([post (scope-census rootvec)]
                               [pre-ht (let ([h (make-eq-hashtable)])
                                         (for-each (lambda (pr) (eq-hashtable-set! h (car pr) #t))
                                                   pre-eval-scopes)
                                         h)]
                               [fresh (let f ([l post] [acc '()])
                                        (cond
                                          [(null? l) acc]
                                          [(eq-hashtable-ref pre-ht (caar l) #f) (f (cdr l) acc)]
                                          [else (f (cdr l) (cons (cdar l) acc))]))])
                          (o "")
                          (o "post-eval scope census: " (length post)
                             "  fresh scopes created during acceptance: " (length fresh))
                          (for-each (lambda (t) (o "    fresh: " t)) fresh)
                          (when (equal? (#%getenv "P33_DUPTRACE") "1")
                            (p33-dup-trace! o rootvec post)))
                        ;; x1-x3: xrepl-tier acceptance (meaningful under P33_XREPL=full segment)
                        (o "")
                        (o "==== x1-x3 xrepl-tier probes (xmode=" (#%getenv "P33_XREPL") ") ====")
                        (check "(x1) current-prompt-read is a procedure"
                               '(procedure? (current-prompt-read))
                               (lambda (v) (eq? v #t)) "#t")
                        (check "(x2) xrepl toplevel-prefix reachable+stringy"
                               '(let ([p (dynamic-require 'xrepl/xrepl 'toplevel-prefix)])
                                  (string? (p)))
                               (lambda (v) (eq? v #t)) "#t")
                        (check "(x3) current-interaction-info announced (tstring/expeditor)"
                               '(with-handlers ([(lambda (x) #t) (lambda (x) 'no-param)])
                                  (if ((dynamic-require 'racket/interaction-info
                                                        'current-interaction-info))
                                      'announced 'unset))
                               (lambda (v) (memq v '(announced unset))) "announced|unset")
                        (when (equal? (#%getenv "P33_STX") "1")
                          (o "==== stxparam micro-test ====")
                          (let ([r (safe-eval
                                    '(begin
                                       (require racket/stxparam)
                                       (define-syntax-parameter P
                                         (syntax-rules () [(_) 'default]))
                                       (syntax-parameterize
                                           ([P (syntax-rules () [(_) 'inside])])
                                         (P))))])
                            (o "  parameterize result: " (fmt-val (cdr r) 80)
                               "  (expect inside)"))
                          (o "  stxparamkey minsts: "
                             (length (p33-find-minsts (vector-ref rootvec 0) "stxparamkey")))
                          (o "  stxparam minsts: "
                             (length (p33-find-minsts (vector-ref rootvec 0) "stxparam.rkt")))
                          ;; identity check: the mark key closure seen by
                          ;; env-extension vs by lookup -- compare the
                          ;; current-parameter-environment variable value
                          ;; across all stxparamkey instances found
                          (for-each
                           (lambda (pr)
                             (p33-hunt-vars o (cdr pr) "parameter-environment" "B" 4))
                           (p33-find-minsts (vector-ref rootvec 0) "stxparamkey"))
                          (try (lambda ()
                                 (p33-stxkey-dissect o (vector-ref rootvec 0) "B"))
                               'dissect-failed)
                          ;; racket-level differential: is the mark set by
                          ;; let-local-keys visible to phase-1 code that
                          ;; requires stxparamkey directly?
                          (let ([r3 (safe-eval
                                     '(begin
                                        (require racket/stxparam
                                                 (for-syntax racket/base
                                                             racket/private/stxparamkey))
                                        (define-syntax-parameter Q
                                          (syntax-rules () [(_) 'default]))
                                        (define-syntax (peek-env stx)
                                          (datum->syntax
                                           stx
                                           (list 'quote
                                                 (hash-count
                                                  (current-parameter-environment)))))
                                        (list
                                         (syntax-parameterize
                                             ([Q (syntax-rules () [(_) 'inside])])
                                           (list (peek-env) (Q)))
                                         (peek-env))))])
                            (o "  peek-env differential: " (fmt-val (cdr r3) 120)
                               "  (A-expect ((1 inside) 0))"))
                          ;; self-consistency: phase-1 wcm under the DIRECTLY
                          ;; required cpe, read back by the same cpe
                          (let ([r4 (safe-eval
                                     '(begin
                                        (require (for-syntax racket/base
                                                             racket/private/stxparamkey))
                                        (define-syntax (probe2 stx)
                                          (with-continuation-mark
                                              current-parameter-environment
                                              (hasheq 'probe2 'here)
                                            (datum->syntax
                                             stx
                                             (list 'quote
                                                   (hash-count
                                                    (current-parameter-environment))))))
                                        (probe2)))])
                            (o "  probe2 self-wcm: " (fmt-val (cdr r4) 60)
                               "  (expect 1 if required inst self-consistent)"))
                          ;; layer bisection: where does the wcm roundtrip break?
                          (let ([r5 (safe-eval
                                     '(with-continuation-mark 'p33k 'v
                                        (continuation-mark-set-first #f 'p33k 'MISS)))])
                            (o "  probe3 phase0 wcm: " (fmt-val (cdr r5) 40)
                               "  (expect v)"))
                          (let ([r6 (safe-eval
                                     ;; NOTE: literal #%unsafe would blow up the
                                     ;; CHEZ reader loading this driver -- build
                                     ;; the module path at runtime instead
                                     '(let ([rt (dynamic-require
                                                 (list 'quote (string->symbol "#%unsafe"))
                                                 'unsafe-root-continuation-prompt-tag)])
                                        (with-continuation-mark 'p33k2 'v2
                                          (continuation-mark-set-first
                                           #f 'p33k2 'MISS (rt)))))])
                            (o "  probe4 phase0 wcm root-tag: " (fmt-val (cdr r6) 60)
                               "  (expect v2)"))
                          (let ([r7 (safe-eval
                                     '(begin
                                        (require (for-syntax racket/base))
                                        (define-syntax (probe5 stx)
                                          (define k (gensym))
                                          (with-continuation-mark k 'v3
                                            (datum->syntax
                                             stx
                                             (list 'quote
                                                   (continuation-mark-set-first
                                                    #f k 'MISS)))))
                                        (probe5)))])
                            (o "  probe5 phase1 fresh-key wcm: " (fmt-val (cdr r7) 60)
                               "  (expect v3)"))
                          ;; probe6: ROOT PROMPT TAG identity -- does the
                          ;; traveled cpe closure carry A's root tag?
                          (let ([r8 (safe-eval
                                     '((dynamic-require
                                        (list 'quote (string->symbol "#%unsafe"))
                                        'unsafe-root-continuation-prompt-tag)))])
                            (let ([b-tag (and (eq? (car r8) 'val) (cdr r8))]
                                  [cpe (try (lambda ()
                                              (p33-find-cpe-closure (vector-ref rootvec 0)))
                                            #f)])
                              (o "  probe6 b-live-root-tag: " (obj-brief b-tag))
                              (if cpe
                                  (let ([tags (try (lambda () (p33-hunt-ptags cpe 6)) '())])
                                    (o "  probe6 traveled-cpe ptags: " (length tags)
                                       "  eq-to-b-root: "
                                       (if (memq b-tag tags) 'YES 'NO))
                                    (for-each
                                     (lambda (t)
                                       (o "    ptag " (obj-brief t)
                                          " f0=" (fmt-val (try (lambda () ($rref t 0)) '?) 30)))
                                     tags))
                                  (o "  probe6: traveled cpe NOT FOUND"))
                              (when cpe
                                (o "  probe6 cpe clen=" (safe-clen cpe)
                                   " code=" (fmt-val (try (lambda ()
                                                            (code-name ($ccode cpe))) '?) 40)
                                   " code-gen=" (try (lambda ()
                                                       (staddr-gen ($ccode cpe))) '?)
                                   " (7=static/named, else=in-graph copy)")))
                          ;; probe7/8: set mark under TRAVELED key, read with
                          ;; B-native cmsf -- no tag, then with B-live root tag
                          (let ([r9 (safe-eval
                                     '(begin
                                        (require (for-syntax racket/base
                                                             racket/private/stxparamkey))
                                        (define-syntax (probe7 stx)
                                          (with-continuation-mark
                                              current-parameter-environment 'SETV
                                            (datum->syntax
                                             stx
                                             (list 'quote
                                                   (continuation-mark-set-first
                                                    #f current-parameter-environment
                                                    'MISS)))))
                                        (probe7)))])
                            (o "  probe7 traveled-key, b-cmsf no-tag: "
                               (fmt-val (cdr r9) 40) "  (SETV=mark readable)"))
                          (let ([r10 (safe-eval
                                      '(begin
                                         (require (for-syntax racket/base
                                                              racket/private/stxparamkey))
                                         (define-syntax (probe8 stx)
                                           (define rt ((dynamic-require
                                                        (list 'quote (string->symbol "#%unsafe"))
                                                        'unsafe-root-continuation-prompt-tag)))
                                           (with-continuation-mark
                                               current-parameter-environment 'SETV8
                                             (datum->syntax
                                              stx
                                              (list 'quote
                                                    (continuation-mark-set-first
                                                     #f current-parameter-environment
                                                     'MISS rt)))))
                                         (probe8)))])
                            (o "  probe8 traveled-key, b-cmsf b-root-tag: "
                               (fmt-val (cdr r10) 40) "  (SETV8=tag path ok)"))
                          ;; probe9: is the traveled cpe's CODE the zo-replayed
                          ;; one (named, resolved) or a stray in-graph copy?
                          (try
                           (lambda ()
                             (let ([cpe (p33-find-cpe-closure (vector-ref rootvec 0))])
                               (when cpe
                                 (let ([cd ($ccode cpe)] [hit #f] [named '()])
                                   (when zo-b-vecs
                                     (let loope ([e 0])
                                       (when (fx< e (vector-length zo-b-vecs))
                                         (let ([v (vector-ref zo-b-vecs e)])
                                           (let loops ([s 0])
                                             (when (fx< s (vector-length v))
                                               (let ([c (vector-ref v s)])
                                                 (when (eq? c cd)
                                                   (set! hit (cons e s)))
                                                 (when (and ($code? c)
                                                            (p33-substr?
                                                             (c-fmt "~a" (try (lambda () (code-name c)) ""))
                                                             "current-parameter-environment"))
                                                   (set! named (cons (cons (cons e s) c) named))))
                                               (loops (fx+ s 1)))))
                                         (loope (fx+ e 1)))))
                                   (o "  probe9 cpe-code in zo table: " (if hit hit 'NO))
                                   (o "  probe9 zo codes named cpe: " (length named)
                                      "  any-eq-to-cpe-code: "
                                      (if (assp (lambda (k) #t) named)
                                          (if (memq cd (map cdr named)) 'YES 'NO)
                                          'NONE))
                                   ;; probe10: dump the code's reloc constants
                                   ;; (dynamic-gen code reloc is GC-maintained,
                                   ;; safe to read here)
                                   (let ([rl (try (lambda () (dw-get-reloc cd #f)) 'RELOC-FAIL)])
                                     (if (pair? rl)
                                         (let ([b-tag (let ([r (safe-eval
                                                                '((dynamic-require
                                                                   (list 'quote (string->symbol "#%unsafe"))
                                                                   'unsafe-root-continuation-prompt-tag)))])
                                                        (and (eq? (car r) 'val) (cdr r)))])
                                           (o "  probe10 reloc entries: " (length rl))
                                           (for-each
                                            (lambda (x)
                                              (let ([cat (obj-category x)])
                                                (unless (memq cat '(symbol string number boolean null))
                                                  (o "    reloc " (obj-brief x)
                                                     (if (procedure? x)
                                                         (c-fmt " name=~a clen=~a gen=~a"
                                                                (try (lambda () (code-name ($ccode x))) '?)
                                                                (safe-clen x)
                                                                (try (lambda () (staddr-gen x)) '?))
                                                         "")
                                                     (if (eq? x b-tag) "  <== EQ B-ROOT-TAG" "")
                                                     (if (and ($rec? x) (not (hashtable? x))
                                                              (p33-substr?
                                                               (c-fmt "~a" (try (lambda () (rtd-name x)) ""))
                                                               "continuation-prompt-tag")
                                                              (not (eq? x b-tag)))
                                                         "  <== FOREIGN PROMPT TAG" "")))))
                                            rl))
                                         (o "  probe10 reloc: " rl))
                                     ;; probe11: the reloc self-literal vs the
                                     ;; traveled cell closure -- eq? and the
                                     ;; behavioral crossover (write under the
                                     ;; literal, read by calling the cell one)
                                     (when (pair? rl)
                                       (let ([lit #f])
                                         (for-each
                                          (lambda (x)
                                            (when (and (procedure? x)
                                                       (eqv? (safe-clen x) 0)
                                                       (eq? (try (lambda () ($ccode x)) #f) cd))
                                              (set! lit x)))
                                          rl)
                                         (o "  probe11 self-literal found: " (if lit 'YES 'NO)
                                            "  eq-to-cell-closure: "
                                            (if lit (if (eq? lit cpe) 'YES 'NO) '-))
                                         (when (and lit (not (eq? lit cpe)))
                                           (let ([r (safe-eval
                                                     (list 'with-continuation-mark
                                                           lit
                                                           (list 'hasheq ''x11 ''y11)
                                                           (list 'hash-count (list cpe))))])
                                             (o "  probe11 write-lit/read-cell: "
                                                (fmt-val (cdr r) 40)
                                                "  (1 = split-identity model CONFIRMED)"))))))))))
                           'probe9-failed))
                          (let ([r2 (safe-eval
                                     '(let ()
                                        (define c% (class object%
                                                     (super-new)
                                                     (define/public (m) 'ok)))
                                        (send (new c%) m)))])
                            (o "  class retry: " (fmt-val (cdr r2) 120))))
                        (when (equal? (#%getenv "P33_CLS2") "1")
                          (o "==== minst hunt (B) ====")
                          (let ([ms (p33-find-minsts (vector-ref rootvec 0) "class-internal")])
                            (o "  minsts found: " (length ms))
                            (for-each
                             (lambda (pr)
                               (o "  phase-key " (car pr) " -> " (obj-brief (cdr pr)))
                               (p33-hunt-vars o (cdr pr) "super-new" "B" 4))
                             ms)))
                        (o "")
                        (o "ACCEPTANCE SUMMARY: pass=" n-pass " fail=" n-fail)
                        (o (if (fx= n-fail 0)
                               "VERDICT: (A) all acceptance checks passed"
                               "VERDICT: partial - see failures above"))
                        ;; ---- extended diagnostics: hunt for dummy-code landmines ----
                        (o "")
                        (o "==== EXTENDED DIAGNOSTICS (dummy-code exposure probes) ====")
                        (let ([xp 0] [xf 0])
                          (define (probe name expr)
                            (let ([r (safe-eval expr)])
                              (cond
                                [(eq? (car r) 'val)
                                 (set! xp (fx+ xp 1))
                                 (o "  [ok]   " name " => " (fmt-val (cdr r) 90))]
                                [else
                                 (set! xf (fx+ xf 1))
                                 (o "  [FAIL] " name " => " (fmt-val (cdr r) 200)
                                    (if (and (string? (cdr r)) (substr? (cdr r) "p3-dummy-code"))
                                        "   <<< DUMMY CODE HIT" ""))])))
                          (probe "for/list" '(for/list ([i (in-range 3)]) (* i i)))
                          (probe "hash literal" '(hash-ref (hash 'a 1 'b 2) 'b))
                          (probe "keyword-apply sort #:key"
                                 (list 'sort '(list (list 2) (list 1)) '<
                                       (rkt-string->keyword "key") 'car))
                          (probe "regexp" '(regexp-match (regexp "a(b+)") "xabbby"))
                          (probe "string port + printf"
                                 '(let ([o (open-output-string)])
                                    (parameterize ([current-output-port o])
                                      (printf "~a" (list 1 2)))
                                    (get-output-string o)))
                          (probe "match" '(match (list 1 2) [(list a b) (+ a b)]))
                          (probe "require racket/contract" '(require racket/contract))
                          (probe "flat contract app"
                                 '((contract (-> integer? integer?) add1 'pos 'neg) 5))
                          (probe "->i contract app"
                                 '((contract (->i ([x integer?]) [r (x) (>=/c x)]) add1 'pos 'neg) 5))
                          (probe "class/object"
                                 '(let ()
                                    (define c% (class object% (super-new) (define/public (m x) (add1 x))))
                                    (send (new c%) m 41)))
                          (probe "require racket/date (cold)" '(require racket/date))
                          (probe "date->string" '(string? (date->string (seconds->date 0))))
                          (o "extended diagnostics: ok=" xp " fail=" xf)
                          (o "")
                          (o "==== ATTRIBUTION PROBES (dual-lineage forensics) ====")
                          (probe "attr1 (contract? any/c) [intra-lineage check]"
                                 '(contract? any/c))
                          (probe "attr2 any/c dual-instance (eq? top registry) [expect #f if dual]"
                                 '(eq? any/c (dynamic-require 'racket/contract/base 'any/c)))
                          (probe "attr3 sort dual-instance (eq? top registry) [expect #f if dual]"
                                 '(eq? sort (dynamic-require 'racket/base 'sort)))
                          (probe "attr4 expand for/list [expansion vs run]"
                                 '(begin (expand '(for/list ([i (in-range 3)]) (* i i))) 'expansion-ok))
                          (probe "attr5 expand match [expansion vs run]"
                                 '(begin (expand '(match (list 1 2) [(list a b) (+ a b)])) 'expansion-ok))
                          (probe "attr6 for/list retry after expands"
                                 '(for/list ([i (in-range 3)]) (* i i)))
                          (probe "attr7 dynamic-require contract/base any/c [registry path only]"
                                 '(list 'got ((dynamic-require 'racket/contract/base 'flat-contract?)
                                              (dynamic-require 'racket/contract/base 'any/c))))
                          (probe "attr8 RETRY match eval"
                                 '(match (list 1 2) [(list a b) (+ a b)]))
                          (probe "attr9 RETRY flat contract app"
                                 '((contract (-> integer? integer?) add1 'pos 'neg) 5))
                          (probe "attr10 RETRY ->i contract app"
                                 '((contract (->i ([x integer?]) [r (x) (>=/c x)]) add1 'pos 'neg) 5))
                          (probe "attr11 RETRY class/object"
                                 '(let ()
                                    (define c% (class object% (super-new) (define/public (m x) (add1 x))))
                                    (send (new c%) m 41)))
                          (probe "attr12 RETRY require racket/date"
                                 '(require racket/date))
                          (probe "attr13 RETRY date->string"
                                 '(string? (date->string (seconds->date 0))))
                          (probe "attr14 (contract? any/c) after retries"
                                 '(contract? any/c))
                          (probe "attr15 natural-number/c triple"
                                 '(let ([nn (dynamic-require 'racket/contract 'natural-number/c)])
                                    (list (contract? nn) (flat-contract? nn)
                                          (contract nn 5 'p 'n))))
                          (probe "attr16 require racket/format (cold, contract-out)"
                                 '(require racket/format))
                          (probe "attr17 (~a 42) via racket/format"
                                 '((dynamic-require 'racket/format '~a) 42))
                          (probe "attr18 coerce string? singleton (string?/c)"
                                 '(contract string? "abc" 'p 'n))
                          (probe "attr19 coerce exact-integer? (plain predicate-contract)"
                                 '(contract exact-integer? 5 'p 'n))
                          (probe "attr20 coerce boolean? singleton (boolean?/c)"
                                 '(contract boolean? #t 'p 'n))
                          (probe "attr21 (symbols 'a 'b) app"
                                 '(contract (symbols 'a 'b) 'a 'p 'n))
                          (probe "attr22 parameter/c app"
                                 '(parameter? (contract (parameter/c symbol?)
                                                        (make-parameter 'x) 'p 'n)))
                          (probe "attr23 class creation only"
                                 '(let ([c% (class object% (super-new))]) 'class-made))
                          (probe "attr24 new on plain class"
                                 '(let ([c% (class object% (super-new))]) (object? (new c%))))
                          (probe "attr25 method class creation only"
                                 '(let ([c% (class object% (super-new)
                                              (define/public (m x) x))])
                                    'method-class-made))
                          (o "")
                          (o "==== CHEZ FORENSICS: post-replay instance census (selected modules) ====")
                          (try (lambda () (let ([insts (find-instances (vector-ref rootvec 0))])
                            (o "total instance records reachable from ns: " (length insts))
                            (for-each
                             (lambda (i)
                               (let ([nm (inst-name-str i)])
                                 (when (or (substr? nm "contract/base") (substr? nm "racket/match")
                                           (substr? nm "class-internal") (substr? nm "pkg/path")
                                           (substr? nm "arrow-val-first") (substr? nm "match/runtime"))
                                   (let ([vars (inst-vars i)])
                                     (o "  inst " (trunc nm 130) " nvars=" (length vars)
                                        " any/c=" (if (assq 'any/c vars) 'yes 'no)
                                        " match=" (if (assq 'match vars) 'yes 'no)
                                        " new=" (if (assq 'new vars) 'yes 'no)
                                        " ->/c=" (if (assq '->/c vars) 'yes 'no))))))
                             insts))) 'FORENSICS-SKIPPED)))))])))
           (p "all done cpu=" (c-cpu))
           (c-flush lp)))))
   'p33b-done))
