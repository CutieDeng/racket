;; ===== P3.3a process A driver: seg4z generation; code named by (zo-event, seq) =====
;; Racket-level operations arrive as bridged procedure arguments.

(define SP "/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad")
(define P3 (string-append SP "/p3"))

;; ---- (h6) support: harvest by-value rtds and their rumble uid plists ----
;; rumble stores struct metadata (inspector/'prefab, struct-type properties)
;; on the rtd uid's SYMBOL PLIST; a deserialized rtd copy in B re-interns the
;; uid gensym but the plist does not travel.  A collects (rtd . property-list)
;; for every post-mark rtd that travels by value; B restores via putprop.
(define rtdprops-ht (make-eq-hashtable))
(define rtdprops-list '())
(define last-new-rtds 0)
(define rtdprops-dropped 0)
;; keep a plist entry only if its value's closure graph is fully resolvable in
;; B (all codes zo-named or bdw-named, or the object is pre-boot).  Values with
;; init-created closures over boot-static/runtime-generated codes are DROPPED:
;; B then sees the property as absent, which reproduces the benign fallback
;; behavior instead of a dummy-code landmine on hot paths (e.g. the expander's
;; introspection of transformer structs).
(define p33-drop-samples '())
;; rtds whose property values may carry closures over boot-static codes
;; (bdw-named via retained static relocation). Only these use the widened
;; resolvability test: opening it globally shipped ~4500 extra property
;; values and some were invalid at run time (measured d72 crash).
(define p33-rtdprops-rescue
  '(provide/contract-arrow-transformer provide/contract-transformer
    rename-transformer-parameter))
(define p33-current-rtd #f)
(define (p33-plist-value-ok? v)
  (let ([visited (make-eq-hashtable)] [ok #t] [budget 20000])
    (let loop ([stack (list v)])
      (unless (or (null? stack) (not ok) (fx<= budget 0))
        (let ([x (car stack)] [stack2 (cdr stack)])
          (set! budget (fx- budget 1))
          (cond
            [(not (heapish? x)) (loop stack2)]
            [(eq-hashtable-ref visited x #f) (loop stack2)]
            [(eq-hashtable-ref mark-ht x #f) (loop stack2)]
            [else
             (eq-hashtable-set! visited x #t)
             (when (procedure? x)
               (let ([cd (try (lambda () ($ccode x)) #f)])
                 (when (and cd
                            (not (zo-a-lookup cd))
                            (not (eq-hashtable-ref dw-codetab cd #f)))
                   (when (fx< (length p33-drop-samples) 24)
                     (set! p33-drop-samples
                           (cons (c-fmt "code=~a src=~a"
                                        (code-name cd) (trunc (p33-code-src cd) 90))
                                 p33-drop-samples)))
                   (set! ok #f))))
             (loop (append (try (lambda () (children x #f)) '()) stack2))]))))
    ok))
;; audit: for every rtdprops value, classify reachable heap objects into
;; mark-domain / dwseq-domain / NEITHER (the invalid-memory source: library
;; cells that would travel as dead in-graph copies)
(define (audit-plist-value-domains o)
  (let ([n-val 0] [n-mark 0] [n-seq 0] [n-neither 0]
        [neither-samples '()]
        [visited (make-eq-hashtable)])
    (for-each
     (lambda (r)
       (let ([pl (try (lambda () (#%property-list (c3-rtypeuid r))) '())])
         (let lp ([l pl])
           (when (and (pair? l) (pair? (cdr l)))
             (set! n-val (fx+ n-val 1))
             (let walk ([stack (list (cadr l))] [budget 4000])
               (unless (or (null? stack) (fx<= budget 0))
                 (let ([x (car stack)] [rest (cdr stack)])
                   (cond
                     [(not (heapish? x)) (walk rest budget)]
                     [(eq-hashtable-ref visited x #f) (walk rest budget)]
                     [else
                      (eq-hashtable-set! visited x #t)
                      (cond
                        [(eq-hashtable-ref mark-ht x #f)
                         (set! n-mark (fx+ n-mark 1))
                         (walk rest (fx- budget 1))]   ; boundary: externalized
                        [(eq-hashtable-ref dw-obj-seq x #f)
                         (set! n-seq (fx+ n-seq 1))
                         (walk rest (fx- budget 1))]   ; boundary: dwseq
                        [else
                         (set! n-neither (fx+ n-neither 1))
                         (when (fx< (length neither-samples) 16)
                           (set! neither-samples
                                 (cons (c-fmt "rtd=~a prop=~a obj=~a"
                                              (try (lambda () (record-type-name r)) '?)
                                              (trunc (c-fmt "~s" (car l)) 40)
                                              (obj-brief x))
                                       neither-samples)))
                         (walk (append (try (lambda () (children x #f)) '()) rest)
                               (fx- budget 1))])]))))
             (lp (cddr l))))))
     (reverse rtdprops-list))
    (o "plist-value domain audit: values=" n-val
       "  mark-hits=" n-mark "  dwseq-hits=" n-seq "  NEITHER=" n-neither)
    (for-each (lambda (x) (o "   neither: " x)) (reverse neither-samples))))

(define (rtdprops-vector)
  (list->vector
   (map (lambda (r)
          (set! p33-current-rtd r)
          (let ([pl (try (lambda () (#%property-list (c3-rtypeuid r))) '())])
            (vector r
                    (list->vector
                     (let lp ([l pl] [acc '()])
                       (cond
                         [(or (null? l) (null? (cdr l))) (reverse acc)]
                         [(p33-plist-value-ok? (cadr l))
                          (lp (cddr l) (cons (cadr l) (cons (car l) acc)))]
                         [else
                          (set! rtdprops-dropped (fx+ rtdprops-dropped 1))
                          (when (fx< (length p33-drop-samples) 24)
                            (set! p33-drop-samples
                                  (cons (c-fmt "DROP rtd=~a prop-key=~a"
                                               (try (lambda () (record-type-name r)) '?)
                                               (trunc (c-fmt "~s" (car l)) 60))
                                        p33-drop-samples)))
                          (lp (cddr l) acc)]))))))
        (reverse rtdprops-list))))
(define (harvest-rtds! root)
  (let ([new 0] [visited (make-eq-hashtable)] [stack (list root)])
    (let loop ()
      (unless (null? stack)
        (let ([x (car stack)])
          (set! stack (cdr stack))
          (when (and (heapish? x) (not (eq-hashtable-ref visited x #f)))
            (eq-hashtable-set! visited x #t)
            (unless (or ($code? x)
                        (eq-hashtable-ref forced-ht x #f)
                        (rule-tag x))
              (when (and (c3-rtd? x) (not (eq-hashtable-ref rtdprops-ht x #f)))
                (eq-hashtable-set! rtdprops-ht x #t)
                (set! rtdprops-list (cons x rtdprops-list))
                (set! new (fx+ new 1)))
              (for-each (lambda (ch)
                          (when (and (not (eq? ch 'UNREADABLE)) (heapish? ch))
                            (set! stack (cons ch stack))))
                        (try (lambda () (children x #f)) '()))
              ;; a record's OWN rtd is not among its fields, but it travels in
              ;; the fasl; proc-local struct types (e.g. the 7 specialized
              ;; predicate contracts in guts.rkt) are reachable ONLY this way
              (when ($rec? x)
                (let ([r (try (lambda () ($rtd x)) #f)])
                  (when (and r (heapish? r) (not (eq-hashtable-ref visited r #f)))
                    (set! stack (cons r stack))))))))
        (loop)))
    (set! last-new-rtds new)
    new))

;; best-effort source location of a code object (via $code-info)
(define (p33-code-src c)
  (try (lambda ()
         (let ([info (#%$code-info c)])
           (if ($rec? info)
               (let ([n (rtd-total-fields ($rtd info))])
                 (let loop ([i 0])
                   (if (fx>= i n)
                       "no-src-field"
                       (let ([f (try (lambda () ($rref info i)) #f)])
                         (if (and f ($rec? f) (not (hashtable? f))
                                  (eq? (rtd-name f) 'source))
                             (let ([sfd (try (lambda () ($rref f 0)) #f)]
                                   [bfp (try (lambda () ($rref f 1)) #f)])
                               (c-fmt "~a @~a"
                                      (if (and sfd ($rec? sfd))
                                          (fmt-val (try (lambda () ($rref sfd 0)) #f) 90)
                                          "?")
                                      bfp))
                             (loop (fx+ i 1)))))))
               "no-info")))
       "src-err"))

;; prefab detection: rumble keeps (key . total-count) on the uid plist
(define (p33-prefab-key+count v)
  (try (lambda () (#%getprop (c3-rtypeuid v) 'prefab-key+count #f)) #f))

(define (p33a-run! kernel-prims rootvec rootnames require-init-intercept! rkt-make-safe-eval rkt-string->keyword rkt-creation-probes)
  (set! dw-extra-roots kernel-prims)
   (let ([dummy-cimt #f])
   (let ([prog (c-oof (string-append P3 "/p3.3a.prog") 'replace)]
         [lp (c-oof (string-append P3 "/p3.3a.log") 'replace)])
     (define (p . xs) (for-each (lambda (x) (c-disp x prog)) xs)
       (c-disp " rt=" prog) (c-disp (real-time) prog) (c-nl prog) (c-flush prog))
     (define (o . xs) (for-each (lambda (x) (c-disp x lp)) xs) (c-nl lp) (c-flush lp))
     (o "==== P3.3a PROCESS A: generate seg4z files (zo-table code naming) ====")
     (p "driver entered (kernel attach was done racket-side)... cpu=" (c-cpu))
     (let* ([pre-ns (vector-ref rootvec 0)]
            [codes-tab (find-eq-code-table)]
            [codes-snap (let ([h (make-eq-hashtable)])
                          (when codes-tab
                            (let-values ([(ks vs) (hashtable-entries codes-tab)])
                              (let lp ([i (fx- (vector-length ks) 1)])
                                (when (fx>= i 0)
                                  (eq-hashtable-set! h (vector-ref ks i) #t)
                                  (lp (fx- i 1))))))
                          h)])
       (o "roots: " (vector-length rootvec))
       ;; ---- mark point scans ----
       (p "mark-point boot-code walk (bdw)... cpu=" (c-cpu))
       (let ([n (dw-walk! rootvec)])
         (let ([np (dw-walk-rtd-plists!)])
           (o "bdw rtd-plist extension: +" np " nodes"))
         (when (equal? (#%getenv "P33_DWFP") "1")
           (dw-dump-fingerprint! "/tmp/dwfp-A.txt"))
         (let ([st (dw-class-stats)])
           (o "bdw mark walk nodes: " n "  codes: " dw-ncodes
              "  classes: " (car st) "  multi-member classes: " (cadr st)
              "  max class size: " (caddr st))))
       (p "creation probes (cpb supply)... cpu=" (c-cpu))
       (cpb-build! (rkt-creation-probes) o)
       (set! dw-reloc-ok #f)   ; mark-phase walks done; reloc unsafe after GC
       (p "p2-scan (mark + snapshot prep)... cpu=" (c-cpu))
       (let ([n (p2-scan! (cons (cons 'ns pre-ns)
                                (let loop ([i 1] [acc '()])
                                  (if (fx>= i (vector-length rootvec))
                                      (reverse acc)
                                      (loop (fx+ i 1)
                                            (cons (cons (vector-ref rootnames i)
                                                        (vector-ref rootvec i))
                                                  acc)))))
                          3000000)])
         (o "pre-existing heapish objects marked (p2): " n))
       (p "n3-scan (structured parents)... cpu=" (c-cpu))
       (let ([n (n3-scan! rootvec 3000000)])
         (o "n3 structured scan visited: " n))
       (p "snapshotting mutable face... cpu=" (c-cpu))
       (p2-snapshot-all! o)
       (o "snapshotted containers: " (c2-htsize snap0))
       ;; ---- the segment-4 action ----
       (p "requiring racket/init (zo interception)... cpu=" (c-cpu))
       (require-init-intercept! (lambda (ev) (zo-a-on-event! ev)))
       (o "zo interception: events=" zo-a-nevents "  table-codes(w/dups)=" zo-a-ncodes
          "  distinct-codes=" (hashtable-size zo-a-tab)
          "  fallback-loads=" (length zo-a-fallbacks)
          "  wrapped-forced=" zo-enum-stats-wc "  wc-force-fail=" zo-enum-stats-wcfail
          "  wc-ann-compiled=" zo-wc-ann "  wc-ann-fail=" zo-wc-ann-fail)
       (for-each (lambda (pr) (o "   fallback load: " (car pr) " " (cdr pr)))
                 zo-a-fallbacks)
       ;; ---- write-set patch ----
       (p "building cumulative patch... cpu=" (c-cpu))
       (let-values ([(patch containers)
                     (p2-build-patch o (lambda (x tag d)
                                         (and (string=? (weak-label x) "strong")
                                              (not (eq? (car d) 'clos)))))])
         ;; changed leaf buffers (report only; not replayed = spike simplification)
         (let ([nbuf 0])
           (for-each
            (lambda (pr)
              (let* ([x (car pr)] [old (eq-hashtable-ref bufsnap0 x #f)])
                (when old
                  (let ([same (try (lambda ()
                                     (case (car old)
                                       [(str) (c2-str=? x (cdr old))]
                                       [(bv) (c2-bv=? x (cdr old))]
                                       [else #t]))
                                   #t)])
                    (unless same (set! nbuf (fx+ nbuf 1)))))))
            p2-bufs)
           (o "changed mutable leaf buffers since mark (NOT in patch): " nbuf))
         ;; per-entry tags
         (let* ([tagof (make-eq-hashtable)])
           (for-each (lambda (entry)
                       (eq-hashtable-set! tagof (car entry) (cadddr entry)))
                     containers)
           (let ([tags (make-vector (vector-length patch) 'unknown)])
             (let lp ([i 0])
               (when (fx< i (vector-length patch))
                 (vector-set! tags i
                              (eq-hashtable-ref tagof (vector-ref (vector-ref patch i) 1) 'unknown))
                 (lp (fx+ i 1))))
             ;; ---- externalization rules ----
             (reset-ext!)
             (add-rule! 'kw (lambda (v) (and (p3-kw? v) (p3-kw-str v) #t)))
             (add-rule! 'rmp (lambda (v) (and (p3-rmp? v) (p3-rmp-name-spec v) #t)))
             ;; pre-existing rtds: externalize with semantic name = nongenerative
             ;; uid (pretty . unique); B re-interns the uid gensym and looks up
             ;; the registered rtd via ($sgetprop uid '*rtd*).
             ;; any nongenerative rtd resolves by uid on B -- library-domain
             ;; rtds (outside the p2 mark) fell through to dwseq and broke
             ;; the fasl graph at read time (d78-d81)
             ;; boot-world rtds only: an init-created rtd has no B-side uid
             ;; registration, so externalizing it leaves a hole where a
             ;; record's rtd should be (measured lottery crashes d91-d94)
             (add-rule! 'rtd (lambda (v) (and (c3-rtd? v)
                                              (p3-rtd-spec v)
                                              (or (eq-hashtable-ref mark-ht v #f)
                                                  (staddr-static? v))
                                              #t)))
             (add-rule! 'prefab-rtd
                        (lambda (v) (and (c3-rtd? v)
                                         (not (eq-hashtable-ref mark-ht v #f))
                                         (p33-prefab-key+count v)
                                         #t)))
             ;; the top-level scope family must travel with the segment
             ;; as one lineage: externalizing these pre-existing objects
             ;; makes B resolve them to its own copies, splitting the
             ;; binding world into two scope lineages (bindings written
             ;; by A's init carry A-side scope keys that B-side lookup
             ;; scopes never match)
             ;; interned scopes resolve BY KEY on B's side (expander interns
             ;; them by symbol; a raw copy would create a second core scope
             ;; and split the binding world) -- must precede pre-boot-marked
             ;; static-generation objects resolve by anchor-relative address
             (add-rule! 'staddr
                        (lambda (v)
                          (and (equal? (#%getenv "P33_LIBID") "1")
                          (and (heapish? v)
                               (not ($code? v))
                               (not (c3-rtd? v))
                               (not (eq-hashtable-ref mark-ht v #f))
                               (staddr-static? v)
                               #t))))
             (add-rule! 'dwseq
                        (lambda (v)
                          (and (equal? (#%getenv "P33_LIBID") "1")
                               (heapish? v)
                               (not ($code? v))
                               ;; hashtables stay with the eqvht-aux rebuild
                               ;; machinery: double-handling corrupted the
                               ;; fasl graph (d78/d80 read-time crash)
                               (not (hashtable? v))
                               (not (c3-rtd? v))
                               (not (eq-hashtable-ref mark-ht v #f))
                               (eq-hashtable-ref dw-obj-seq v #f)
                               #t)))
             (add-rule! 'iscope
                        (lambda (v)
                          (and ($rec? v)
                               (eq-hashtable-ref mark-ht v #f)
                               (let ([k (scope-proper-key v)])
                                 (and k (cdr k)))
                               #t)))
             (add-rule! 'pre-boot-marked
                        (lambda (v)
                          (and (eq-hashtable-ref mark-ht v #f)
                               (not (and ($rec? v)
                                         (memq (rtd-name v)
                                               '(scope interned-scope
                                                 representative-scope multi-scope
                                                 shifted-multi-scope
                                                 shifted-to-label-phase propagation
                                                 root-expand-context
                                                 table-with-bulk-bindings))))
                               #t)))
             ;; 0-fv closures of zo-named codes: the cell closure and the
             ;; code's reloc self-literal are the SAME object on the load
             ;; process; letting the cell closure travel in-graph while B
             ;; replays the zo splits them into two eq-distinct closures
             ;; and breaks closure-object keying (stxparam mark key, 7.1).
             ;; Only externalize when A's closure IS its code's literal so
             ;; the replacement preserves A-side semantics exactly.
             (add-rule! 'zoclo
                        (lambda (v)
                          (and (procedure? v)
                               (not ($cont? v))
                               (eqv? (safe-clen v) 0)
                               (not (eq-hashtable-ref mark-ht v #f))
                               (let ([cd (try (lambda () ($ccode v)) #f)])
                                 (and cd
                                      (zo-a-lookup cd)
                                      (eq? (p33-zoclo-literal cd) v)))
                               #t)))
             ;; ---- fasl write with eqvht-aux fixpoint ----
             (p "fasl write loop... cpu=" (c-cpu))
             (let ([auxht (make-eq-hashtable)]  ; ht-obj -> (vector obj weak kind kvvec)
                   [auxlist '()])
               (define (aux-vector) (list->vector auxlist))
               (define (harvest-eqvhts! exts)
                 ;; returns number of new aux entries
                 (let ([new 0])
                   (for-each
                    (lambda (pr)
                      (let ([x (car pr)] [tag (cdr pr)])
                        (when (and (eq? tag 'generic-chez-hashtable)
                                   (not (eq-hashtable-ref auxht x #f)))
                          (set! new (fx+ new 1))
                          (let* ([hf (c2-hashfn x)]
                                 [kind (cond [(not hf) 'eqv]
                                             [(eq? hf c3-equalhash) 'equal]
                                             [else 'other])]
                                 [weak (c3-htweak? x)]
                                 [ks (c-htkeys x)]
                                 [kv (let ([v (make-vector (vector-length ks))])
                                       (let lp ([i 0])
                                         (when (fx< i (vector-length ks))
                                           (let ([k (vector-ref ks i)])
                                             (vector-set! v i (cons k (c-htref x k #f))))
                                           (lp (fx+ i 1))))
                                       v)])
                            (eq-hashtable-set! auxht x (vector x weak kind kv))
                            (set! auxlist (cons (vector x weak kind kv) auxlist))))))
                    exts)
                   new))
               (let write-loop ([iter 1])
                 (let* ([codes-delta
                         ;; (vector (obj . n) ...) for objs registered since mark
                         (if (not codes-tab)
                             (vector)
                             (let-values ([(ks vs) (hashtable-entries codes-tab)])
                               (let lp ([i (fx- (vector-length ks) 1)] [acc '()])
                                 (if (fx< i 0)
                                     (list->vector acc)
                                     (lp (fx- i 1)
                                         (if (eq-hashtable-ref codes-snap (vector-ref ks i) #f)
                                             acc
                                             (cons (cons (vector-ref ks i) (vector-ref vs i)) acc)))))))]
                        [root (vector 'p3-seg4 patch tags (aux-vector) (rtdprops-vector) codes-delta)]
                        [r (iterate-write root o 80)])
                   (cond
                     [(not (eq? (car r) 'ok))
                      (o "FATAL: fasl write did not converge: " (cadr r))
                      (p "FATAL write")
                      (c-flush lp)
                      (exit 1)]
                     [else
                      (let* ([bv (cadr r)] [exts (caddr r)]
                             [new (harvest-eqvhts! exts)])
                        (o "  write iter " iter ": bytes=" (c2-bvlen bv)
                           " externals=" (length exts) " new-eqvht-aux=" new
                           " new-rtdprops=" (harvest-rtds! root))
                        (cond
                          [(and (or (fx> new 0) (fx> last-new-rtds 0)) (fx< iter 8))
                           (write-loop (fx+ iter 1))]
                          [else
                           ;; ---- (P33_SEGPROF=1) per-root-slot fasl size profile ----
                           ;; each slot written alone with the SAME rule chain
                           ;; (silent printer); shared structure counts once per
                           ;; slot, so sizes overlap and need not sum to the
                           ;; total -- magnitude attribution only.  Runs after
                           ;; the main write converged: every object here
                           ;; already proved writable, so the rule-deriving
                           ;; crash path inside iterate-write stays cold.
                           ;; the graph is strongly shared: a slot written alone
                           ;; measures its REACHABLE size (patch alone ~= total),
                           ;; so attribution uses MARGINAL sizes instead --
                           ;; total minus a rewrite with that slot dropped =
                           ;; the slot's exclusive bytes
                           (when (equal? (#%getenv "P33_SEGPROF") "1")
                             (let* ([silent (lambda args (void))]
                                    [full (c2-bvlen bv)]
                                    [wr (lambda (v)
                                          (let ([rr (iterate-write v silent 8)])
                                            (and (eq? (car rr) 'ok)
                                                 (c2-bvlen (cadr rr)))))]
                                    [root-sans
                                     (lambda (k)
                                       (let ([v (vector 'p3-seg4
                                                        (vector-ref root 1)
                                                        (vector-ref root 2)
                                                        (vector-ref root 3)
                                                        (vector-ref root 4)
                                                        (vector-ref root 5))])
                                         (vector-set! v k '#())
                                         v))])
                               (o "  [segprof] total=" full)
                               (for-each
                                (lambda (k nm)
                                  (let ([b (wr (root-sans k))])
                                    (o "  [segprof/marginal] " nm ": exclusive="
                                       (if b (fx- full b) 'ERR) " bytes")))
                                '(1 2 3 4 5)
                                '(patch tags aux rtdprops codes-delta))
                               ;; patch by tag, marginal: rebuild patch/tags
                               ;; without each tag group and re-measure
                               (let ([tagset '()])
                                 (let lp ([j 0])
                                   (when (fx< j (vector-length tags))
                                     (let ([tg (vector-ref tags j)])
                                       (unless (member tg tagset)
                                         (set! tagset (cons tg tagset))))
                                     (lp (fx+ j 1))))
                                 (for-each
                                  (lambda (tg)
                                    (let* ([keep '()]
                                           [kt '()]
                                           [n-drop 0])
                                      (let lp ([j (fx- (vector-length patch) 1)])
                                        (when (fx>= j 0)
                                          (if (equal? (vector-ref tags j) tg)
                                              (set! n-drop (fx+ n-drop 1))
                                              (begin
                                                (set! keep (cons (vector-ref patch j) keep))
                                                (set! kt (cons (vector-ref tags j) kt))))
                                          (lp (fx- j 1))))
                                      (let* ([v (vector 'p3-seg4
                                                        (list->vector keep)
                                                        (list->vector kt)
                                                        (vector-ref root 3)
                                                        (vector-ref root 4)
                                                        (vector-ref root 5))]
                                             [b (wr v)])
                                        (o "  [segprof/patch-marginal] "
                                           (trunc (c-fmt "~s" tg) 60)
                                           ": n=" n-drop "  exclusive="
                                           (if b (fx- full b) 'ERR) " bytes"))))
                                  tagset))))
                           ;; ---- flip-set tracer (P33_TRACE_ZO="ev:seq,ev:seq,...") ----
                           ;; for each known run-flipping (event,seq) code, print
                           ;; whether THIS run's graph holds it and the holder path
                           (let ([spec (#%getenv "P33_TRACE_ZO")])
                             (when spec
                               (let* ([targets   ; list of (evt . seq)
                                       (let parse ([cs (string->list spec)] [cur '()] [acc '()])
                                         (define (fin cur acc)
                                           (if (null? cur) acc
                                               (let* ([s (list->string (reverse cur))]
                                                      [i (let f ([j 0])
                                                           (cond [(fx>= j (string-length s)) #f]
                                                                 [(char=? (string-ref s j) #\:) j]
                                                                 [else (f (fx+ j 1))]))])
                                                 (if i
                                                     (cons (cons (string->number (substring s 0 i))
                                                                 (string->number (substring s (fx+ i 1) (string-length s))))
                                                           acc)
                                                     acc))))
                                         (cond
                                           [(null? cs) (reverse (fin cur acc))]
                                           [(char=? (car cs) #\,) (parse (cdr cs) '() (fin cur acc))]
                                           [else (parse (cdr cs) (cons (car cs) cur) acc)]))]
                                      [code-of
                                       (lambda (evt seq)
                                         (call/cc
                                          (lambda (k)
                                            (let-values ([(ks vs) (hashtable-entries zo-a-tab)])
                                              (let f ([i (fx- (vector-length ks) 1)])
                                                (if (fx< i 0) #f
                                                    (let ([pr (vector-ref vs i)])
                                                      (if (and (fx= (car pr) evt) (fx= (cdr pr) seq))
                                                          (k (vector-ref ks i))
                                                          (f (fx- i 1))))))))))]
                                      [extset (make-eq-hashtable)])
                                 (for-each (lambda (pr) (eq-hashtable-set! extset (car pr) #t)) exts)
                                 (for-each
                                  (lambda (tgt)
                                    (let ([c (code-of (car tgt) (cdr tgt))])
                                      (cond
                                        [(not c) (o "  [flip-trace] " tgt " : NOT-IN-ZO-TAB")]
                                        [(not (eq-hashtable-ref extset c #f))
                                         (o "  [flip-trace] " tgt " code=" (code-name c) " : ABSENT from segment")]
                                        [else
                                         (o "  [flip-trace] " tgt " code=" (code-name c) " : PRESENT; path:")
                                         (let ([visited (make-eq-hashtable)]
                                               [parent (make-eq-hashtable)]
                                               [nodes 0] [done #f])
                                           (eq-hashtable-set! visited root #t)
                                           (let bfs ([qf (list root)] [qb '()])
                                             (unless (or done (and (null? qf) (null? qb)) (fx>= nodes 500000))
                                               (let* ([qf (if (null? qf) (reverse qb) qf)]
                                                      [x (car qf)])
                                                 (set! nodes (fx+ nodes 1))
                                                 (cond
                                                   [(eq? x c)
                                                    (set! done #t)
                                                    (let pth ([ob x] [n 0])
                                                      (let ([pr (eq-hashtable-ref parent ob #f)])
                                                        (when (and pr (fx< n 30))
                                                          (o "      <- " (obj-brief (car pr)) " [" (cdr pr) "]")
                                                          (pth (car pr) (fx+ n 1)))))]
                                                   [else
                                                    (let ([qb2
                                                           (if (and (not (eq? x root)) (eq-hashtable-ref extset x #f))
                                                               '()   ; boundary
                                                               (fold-left
                                                                (lambda (acc pr)
                                                                  (let ([ch (cdr pr)])
                                                                    (if (and (or (heapish? ch) ($code? ch))
                                                                             (not (eq-hashtable-ref visited ch #f)))
                                                                        (begin
                                                                          (eq-hashtable-set! visited ch #t)
                                                                          (eq-hashtable-set! parent ch (cons x (car pr)))
                                                                          (cons ch acc))
                                                                        acc)))
                                                                '() (try (lambda () (children/labeled x)) '())))])
                                                      (bfs (cdr qf) (append qb2 qb)))]))))
                                           (unless done (o "      (no path within cap; held via ext-boundary interior?)")))])))
                                  targets))))
                           ;; ---- final: build manifest ----
                           (p "manifest build... cpu=" (c-cpu))
                           (let* ([n-ext (length exts)]
                                  [mvec (make-vector n-ext #f)]
                                  [cnt-code 0] [cnt-code-unwalked 0] [cnt-zomiss 0] [cnt-bdw 0] [cnt-prefab 0] [cnt-cpb 0]
                                  [cnt-zoloc-sc-ok 0] [cnt-zoloc-sc-bad 0]
                                  [cnt-loc 0] [cnt-loc-fail 0] [cnt-rtd 0]
                                  [cnt-kw 0] [cnt-rmp 0] [cnt-eqvht 0] [cnt-unres 0]
                                  [unwalked '()]
                                  [fail-samples '()])
                             (let lp ([i 0] [l exts])
                               (when (pair? l)
                                 (let* ([x (car (car l))] [tag (cdr (car l))]
                                        [entry
                                         (case tag
                                           [(code)
                                            (let ([hit (zo-a-lookup x)])
                                              (cond
                                                [hit
                                                 (set! cnt-code (fx+ cnt-code 1))
                                                 (vector 'zo (car hit) (cdr hit))]
                                                [(eq-hashtable-ref dw-codetab x #f)
                                                 => (lambda (bhit)
                                                      (set! cnt-bdw (fx+ cnt-bdw 1))
                                                      (vector 'bdw (car bhit) (cdr bhit)))]
                                                [(cpb-lookup x)
                                                 => (lambda (ci)
                                                      (set! cnt-cpb (fx+ cnt-cpb 1))
                                                      (vector 'cpb ci))]
                                                [else
                                                 (let ([e (n3-encode x 6)])
                                                   (if e
                                                       (begin
                                                         (set! cnt-code-unwalked (fx+ cnt-code-unwalked 1))
                                                         (let ([r (n3-resolve e rootvec)])
                                                           (if (and (eq? (car r) 'ok) (eq? (cdr r) x))
                                                               (set! cnt-zoloc-sc-ok (fx+ cnt-zoloc-sc-ok 1))
                                                               (set! cnt-zoloc-sc-bad (fx+ cnt-zoloc-sc-bad 1))))
                                                         (vector 'zoloc e))
                                                       (begin
                                                         (set! cnt-zomiss (fx+ cnt-zomiss 1))
                                                         (set! unwalked (cons (cons i x) unwalked))
                                                         (vector 'zomiss (dw-code-key x)
                                                                 (try (lambda () (#%$code-free-count x)) 0)
                                                                 (try (lambda () (#%$code-arity-mask x)) -1)))))]))]
                                           [(rtd)
                                            (set! cnt-rtd (fx+ cnt-rtd 1))
                                            (let ([sp (p3-rtd-spec x)])
                                              (vector 'rtd (car sp) (cdr sp)))]
                                           [(prefab-rtd)
                                            (set! cnt-prefab (fx+ cnt-prefab 1))
                                            (let ([kc (p33-prefab-key+count x)])
                                              (vector 'prefab (car kc) (cdr kc)))]
                                           [(staddr)
                                            ;; rule-overlap guard (design doc 6.2): staddr is
                                            ;; ordered before 'zoclo; today they are disjoint
                                            ;; (zoclo targets are gen-4 dynamic, staddr wants
                                            ;; static) but that is inference, so assert it --
                                            ;; an address-resolved zoclo target would silently
                                            ;; reintroduce the 0-fv identity split on B
                                            (when (p33-zoclo-target? x)
                                              (o "FATAL: rule overlap: staddr captured a zoclo "
                                                 "target: code="
                                                 (try (lambda () (code-name ($ccode x))) #f))
                                              (p "FATAL zoclo-overlap")
                                              (exit 1))
                                            (let ([sp (staddr-spec x)])
                                              (if sp
                                                  (vector 'staddr (car sp) (cdr sp))
                                                  (vector 'staddr-fail 0 0)))]
                                           [(dwseq)
                                            ;; same overlap guard: dwseq membership is filled
                                            ;; at the mark point, zoclo targets are minted by
                                            ;; init (post-mark) -- disjoint today, asserted
                                            (when (p33-zoclo-target? x)
                                              (o "FATAL: rule overlap: dwseq captured a zoclo "
                                                 "target: code="
                                                 (try (lambda () (code-name ($ccode x))) #f))
                                              (p "FATAL zoclo-overlap")
                                              (exit 1))
                                            (vector 'dwseq (eq-hashtable-ref dw-obj-seq x #f))]
                                           [(zoclo)
                                            ;; roundtrip self-check: the (evt . seq) name must
                                            ;; resolve back -- through A's OWN event table and
                                            ;; the reloc self-literal, exactly the two steps B
                                            ;; will take -- to x itself.  Upgrades zo-enumeration
                                            ;; determinism from assumption to build-time
                                            ;; invariant (design doc 6.3); a failure here would
                                            ;; surface on B as a wrong-object wiring, so die now
                                            (let* ([cd ($ccode x)]
                                                   [hit (zo-a-lookup cd)]
                                                   [cd2 (and hit (zo-a-ref (car hit) (cdr hit)))]
                                                   [lit (and cd2 (p33-zoclo-literal cd2))])
                                              (cond
                                                [(and (eq? cd2 cd) (eq? lit x))
                                                 (vector 'zoclo (car hit) (cdr hit))]
                                                [else
                                                 (o "FATAL: zoclo roundtrip failed: name=" hit
                                                    " code-eq=" (eq? cd2 cd)
                                                    " literal-eq=" (eq? lit x)
                                                    " code=" (try (lambda () (code-name cd)) #f))
                                                 ;; (o flushes; the log-port var is shadowed
                                                 ;; here by the manifest loop's named let)
                                                 (p "FATAL zoclo-roundtrip")
                                                 (exit 1)]))]
                                           [(iscope)
                                            (vector 'iscope (scope-proper-key x))]
                                           [(kw)
                                            (set! cnt-kw (fx+ cnt-kw 1))
                                            (vector 'kw (p3-kw-str x))]
                                           [(rmp)
                                            (set! cnt-rmp (fx+ cnt-rmp 1))
                                            (vector 'rmp (p3-rmp-name-spec x))]
                                           [(pre-boot-marked)
                                            (let ([e (n3-encode x 6)])
                                              (if e
                                                  (begin (set! cnt-loc (fx+ cnt-loc 1))
                                                         (vector 'loc e))
                                                  (begin
                                                    (set! cnt-loc-fail (fx+ cnt-loc-fail 1))
                                                    (when (fx< (length fail-samples) 25)
                                                      (set! fail-samples
                                                            (cons (c-fmt "~a | ~a"
                                                                         (obj-brief x)
                                                                         (p2-path/trunc x 200))
                                                                  fail-samples)))
                                                    (vector 'unres 'pre-noname (obj-brief x)))))]
                                           [(generic-chez-hashtable)
                                            (set! cnt-eqvht (fx+ cnt-eqvht 1))
                                            (let ([a (eq-hashtable-ref auxht x #f)])
                                              (vector 'eqvht (vector-ref a 1) (vector-ref a 2)))]
                                           [else
                                            (set! cnt-unres (fx+ cnt-unres 1))
                                            (vector 'unres tag (obj-brief x))])])
                                   (vector-set! mvec i entry))
                                 (lp (fx+ i 1) (cdr l))))
                             ;; P3.3a: zo coverage census (no post-init rescan; the pre
                             ;; n3 parent state stays live for zoloc emission above)
                             (p "zo coverage census... cpu=" (c-cpu))
                             (let ([miss-names '()])
                               (for-each
                                (lambda (pr)
                                  (when (fx< (length miss-names) 40)
                                    (set! miss-names
                                          (cons (c-fmt "~a  src=~a"
                                                       (dw-code-key (cdr pr))
                                                       (p33-code-src (cdr pr)))
                                                miss-names))))
                                unwalked)
                               (o "")
                               (o "==== ZO COVERAGE (P3.3a) ====")
                               (let ([tot (fx+ (fx+ (fx+ cnt-code cnt-cpb) cnt-bdw)
                                               (fx+ cnt-code-unwalked cnt-zomiss))])
                                 (o "  code externals: " tot
                                    "  zo-named: " cnt-code
                                    "  mark-bdw-named: " cnt-bdw
                                    "  cpb-named: " cnt-cpb
                                    "  mark-loc-named (zoloc): " cnt-code-unwalked
                                    "  MISS (zomiss -> dummy in B): " cnt-zomiss)
                                 (o "  coverage per-mille (zo+bdw+cpb+zoloc): "
                                    (if (fx= tot 0) 1000
                                        (fxdiv (fx* 1000 (fx- tot cnt-zomiss)) tot)))
                                 (o "  zoloc A-side self-resolve (post-init heap; informational): ok="
                                    cnt-zoloc-sc-ok " bad=" cnt-zoloc-sc-bad)
                                 (audit-plist-value-domains o)
                                 (o "  rtdprops: rtds=" (length rtdprops-list)
                                    "  plist-entries-dropped(unresolvable-code)=" rtdprops-dropped)
                                 (for-each (lambda (x) (o "   drop-sample: " x)) (reverse p33-drop-samples)))
                               (for-each (lambda (s) (o "   zomiss code: " s)) miss-names))
                             ;; self-check the pre-heap 'loc entries too (identity roundtrip)
                             (let ([n-ok 0] [n-bad 0] [why (c2-mkht c3-equalhash c3-equalpred)])
                               (let lp ([i 0] [l exts])
                                 (when (pair? l)
                                   (let ([e (vector-ref mvec i)])
                                     (when (and (vector? e) (eq? (vector-ref e 0) 'loc))
                                       (let ([r (n3-resolve (vector-ref e 1) rootvec)])
                                         (if (and (eq? (car r) 'ok) (eq? (cdr r) (car (car l))))
                                             (set! n-ok (fx+ n-ok 1))
                                             (begin (set! n-bad (fx+ n-bad 1))
                                                    (hashtable-update! why
                                                                       (if (eq? (car r) 'ok) 'wrong-object (cdr r))
                                                                       (lambda (v) (fx+ v 1)) 0))))))
                                   (lp (fx+ i 1) (cdr l))))
                               (o "loc self-resolve (POST-heap NOTE: chains were recorded on the PRE heap): ok="
                                  n-ok " bad=" n-bad)
                               (dump-counts o why "  loc self-resolve fail why:"))
                             (o "")
                             (o "==== MANIFEST census ====")
                             (o "  total externals: " n-ext)
                             (o "  code named: " cnt-code "   code unwalked: " cnt-code-unwalked)
                             (o "  loc encoded: " cnt-loc "   loc FAILED->unres: " cnt-loc-fail)
                             (o "  rtd: " cnt-rtd "   prefab-rtd: " cnt-prefab
                                "   kw: " cnt-kw "   rmp: " cnt-rmp
                                "   eqvht: " cnt-eqvht "   other-unres: " cnt-unres)
                             (for-each (lambda (s) (o "   loc-fail sample: " s)) (reverse fail-samples))
                             ;; ---- write the three artifacts ----
                             (p "writing artifacts... cpu=" (c-cpu))
                             (p3-write-bv-file! (string-append P3 "/seg4z-state.fasl") bv)
                             (p3-fasl-to-file! (string-append P3 "/seg4z-externals.manifest")
                                               (vector 'p3-manifest 1 rootnames mvec))
                             (zo-a-write-list! (string-append P3 "/seg4z-zolist.fasl"))
                             (when (equal? (#%getenv "P33_CODEFASL") "1")
                               (let ([t0 (c-cpu)]
                                     [used (c2-mkht c3-equalhash c3-equalpred)])
                                 ;; demand set: (evt . seq) names the segment
                                 ;; manifest actually references
                                 (let lp ([i 0])
                                   (when (fx< i (vector-length mvec))
                                     (let ([e (vector-ref mvec i)])
                                       (when (and (vector? e)
                                                  (fx>= (vector-length e) 3)
                                                  (memq (vector-ref e 0) '(zo zoclo)))
                                         (c2-htset! used
                                                    (cons (vector-ref e 1)
                                                          (vector-ref e 2))
                                                    #t)))
                                     (lp (fx+ i 1))))
                                 (zo-a-write-codes! (string-append P3 "/seg4z-codes.fasl")
                                                    (string-append P3 "/seg4z-codes.manifest")
                                                    used o)
                                 (o "codes fasl written in " (- (c-cpu) t0) " ms")))
                             ;; textual patch digest
                             (let ([dg (c-oof (string-append P3 "/seg4z-patch.rktd") 'replace)])
                               (define (d . xs) (for-each (lambda (x) (c-disp x dg)) xs) (c-nl dg))
                               (d ";; P3 seg4 patch digest: " (vector-length patch)
                                  " entries (real patch travels inside seg4-state.fasl graph)")
                               (let ([kindcnt (c2-mkht c3-equalhash c3-equalpred)])
                                 (let lp ([i 0])
                                   (when (fx< i (vector-length patch))
                                     (let* ([e (vector-ref patch i)]
                                            [op (vector-ref e 0)]
                                            [x (vector-ref e 1)]
                                            [tag (vector-ref tags i)])
                                       (hashtable-update! kindcnt op (lambda (v) (fx+ v 1)) 0)
                                       (d "(" i " " op " tag=" tag
                                          " container=" (obj-category x)
                                          " path=\"" (p2-path/trunc x 180) "\""
                                          (case op
                                            [(ht+ ht~)
                                             (c-fmt " key=~a val=~a"
                                                    (p2-brief (vector-ref e 2))
                                                    (p2-brief (vector-ref e 3)))]
                                            [(ht-)
                                             (c-fmt " key=~a" (p2-brief (vector-ref e 2)))]
                                            [(slot)
                                             (c-fmt " kind=~a idx=~a val=~a"
                                                    (vector-ref e 2) (vector-ref e 3)
                                                    (p2-brief (vector-ref e 4)))]
                                            [else ""])
                                          ")"))
                                     (lp (fx+ i 1))))
                                 (d ";; ops by kind:")
                                 (let ([ks (vector->list (c-htkeys kindcnt))])
                                   (for-each (lambda (k) (d ";;   " k " : " (c-htref kindcnt k 0))) ks)))
                               (c-flush dg))
                             (o "")
                             (o "artifacts written: seg4z-state.fasl (" (c2-bvlen bv)
                                " bytes), seg4z-externals.manifest + seg4z-zolist.fasl (" n-ext
                                " entries), seg4z-patch.rktd (" (vector-length patch) " ops)")
                             ;; ---- control: run the same extended probes on A's OWN state ----
                             (let ([safe-eval (rkt-make-safe-eval)]
                                   [xp 0] [xf 0])
                               (define (probe name expr)
                                 (let ([r (safe-eval expr)])
                                   (cond
                                     [(eq? (car r) 'val)
                                      (set! xp (fx+ xp 1))
                                      (o "  [ok]   " name " => " (fmt-val (cdr r) 90))]
                                     [else
                                      (set! xf (fx+ xf 1))
                                      (o "  [FAIL] " name " => " (fmt-val (cdr r) 200))])))
                               (o "")
                               (o "==== A-SIDE CONTROL PROBES (same list as B extended diagnostics) ====")
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
                               (o "A-side control probes: ok=" xp " fail=" xf))
                             (when (equal? (#%getenv "P33_STX") "1")
                               (o "==== stxparam micro-test (A) ====")
                               (let ([se (rkt-make-safe-eval)])
                                 (let ([r (se '(begin
                                                 (require racket/stxparam)
                                                 (define-syntax-parameter P
                                                   (syntax-rules () [(_) 'default]))
                                                 (syntax-parameterize
                                                     ([P (syntax-rules () [(_) 'inside])])
                                                   (P))))])
                                   (o "  parameterize result: " (fmt-val (cdr r) 80))))
                               (o "  stxparamkey minsts: "
                                  (length (p33-find-minsts (vector-ref rootvec 0) "stxparamkey")))
                               (try (lambda ()
                                      (p33-stxkey-dissect o (vector-ref rootvec 0) "A"))
                                    'dissect-failed)
                               (let ([se2 (rkt-make-safe-eval)])
                                 (let ([r3 (se2
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
                                   (o "  peek-env differential (A): " (fmt-val (cdr r3) 120)))))
                             (when (equal? (#%getenv "P33_CLS2") "1")
                               (o "==== minst hunt (A) ====")
                               (let ([ms (p33-find-minsts (vector-ref rootvec 0) "class-internal")])
                                 (o "  minsts found: " (length ms))
                                 (for-each
                                  (lambda (pr)
                                    (o "  phase-key " (car pr) " -> " (obj-brief (cdr pr)))
                                    (p33-hunt-vars o (cdr pr) "super-new" "A" 4))
                                  ms)))
                             (p "all done cpu=" (c-cpu))
                             (c-flush lp))]))])))))))
       (void))))
   'p33a-done)
