;; ===== P3.3 zo code table (loaded into p32-env after p3.3-enum.chez.ss) =====
;; Naming protocol: code external name = (event-index . seq), where event-index
;; counts intercepted/replayed zo bundle-load events in order, and seq is the
;; code's position in the deterministic enumeration of that event's bundle
;; (sorted linklet keys, structural DFS with reloc descent).

;; ---------- A side: code -> name ----------
(define zo-a-tab (make-eq-hashtable))   ; code -> (cons evt seq); first event wins
(define zo-a-events '())                ; reversed list of (vector path enc ncodes)
(define zo-a-codevecs '())              ; reversed, parallel to zo-a-events; for
                                        ; the (evt . seq) -> code roundtrip check
(define zo-a-nevents 0)
(define zo-a-fallbacks '())             ; (path . enc/why) not table-covered
(define zo-a-ncodes 0)

(define (zo-a-on-event! ev)
  (let ([path (vector-ref ev 0)] [enc (vector-ref ev 1)] [prs (vector-ref ev 2)])
    (cond
      [(eq? prs 'fallback)
       (set! zo-a-fallbacks (cons (cons path enc) zo-a-fallbacks))]
      [else
       (let ([idx zo-a-nevents]
             [codes (zo-enum-linklets prs)])
         (let lp ([j 0])
           (when (fx< j (vector-length codes))
             (let ([c (vector-ref codes j)])
               (unless (eq-hashtable-ref zo-a-tab c #f)
                 (eq-hashtable-set! zo-a-tab c (cons idx j))))
             (lp (fx+ j 1))))
         (set! zo-a-ncodes (fx+ zo-a-ncodes (vector-length codes)))
         (set! zo-a-events (cons (vector path enc (vector-length codes)) zo-a-events))
         (set! zo-a-codevecs (cons codes zo-a-codevecs))
         (set! zo-a-nevents (fx+ zo-a-nevents 1)))])))

(define (zo-a-lookup c) (eq-hashtable-ref zo-a-tab c #f))

(define (zo-a-ref evt seq)
  ;; name -> code on A itself (mirror of zo-b-lookup); the list is reversed,
  ;; so event evt sits at position (- nevents 1 evt) from the head
  (let ([v (let lp ([l zo-a-codevecs] [i (fx- zo-a-nevents 1)])
             (cond
               [(null? l) #f]
               [(fx= i evt) (car l)]
               [else (lp (cdr l) (fx- i 1))]))])
    (and v (fx< seq (vector-length v)) (vector-ref v seq))))

(define (zo-a-write-list! path)
  (p3-fasl-to-file! path (vector 'p3-zolist 1 (list->vector (reverse zo-a-events)))))

(define (zo-a-write-codes! bv-path manifest-path used o)
  ;; used: equal-ht of (evt . seq) actually referenced by the segment
  ;; manifest (zo/zoclo names); unreferenced slots write #f -- B never
  ;; looks them up, and each dropped code drops its constant-pool
  ;; hazards (live callback tables etc.) with it
  ;; native code supply (P33_CODEFASL): the per-event enumeration
  ;; vectors written through the kernel's live-code fasl writer as one
  ;; shared graph; (evt . seq) indexing is unchanged on the B side.
  ;; Static-generation codes (reachable both as enumeration entries and
  ;; through dynamic codes' reloc recursion) have no reloc table to
  ;; serialize and exist in B's own boot heap anyway: they leave the
  ;; graph through fasl-write's external-predicate hook (the engine's
  ;; own mechanism) and travel as bdw names in a side manifest, in
  ;; collection order = B's extvec order.
  (let* ([all-vecs (list->vector (reverse zo-a-codevecs))]
         [vecs (let ([nv (make-vector (vector-length all-vecs) '#())])
                 (let lp ([i 0] [kept 0] [dropped 0])
                   (if (fx= i (vector-length all-vecs))
                       (o "codes fasl: demand-filter kept=" kept
                          "  dropped=" dropped)
                       (let* ([cv (vector-ref all-vecs i)]
                              [m (vector-length cv)]
                              [fv (make-vector m #f)]
                              [k2 (let lp2 ([j 0] [k2 kept])
                                    (if (fx= j m)
                                        k2
                                        (if (c-htref used (cons i j) #f)
                                            (begin
                                              (vector-set! fv j (vector-ref cv j))
                                              (lp2 (fx+ j 1) (fx+ k2 1)))
                                            (lp2 (fx+ j 1) k2))))])
                         ;; an event with no demanded codes writes an
                         ;; EMPTY vector, so a segmented merge can tell
                         ;; "not mine" from "mine but sparse"
                         (vector-set! nv i (if (fx= k2 kept) '#() fv))
                         (lp (fx+ i 1) k2 (fx+ dropped (fx- m (fx- k2 kept)))))))
                 nv)]
         [root (vector 'p3-codes 1 vecs)]
         [forced (make-eq-hashtable)]   ; crash-learned unfaslable objects
         [exts '()]
         [next 0])
    (define (pred v)
      (cond
        ;; static code WITH a walk name externalizes (identity kept);
        ;; a nameless static code falls through and INLINES natively --
        ;; its reloc table is readable under RETAIN, and the measured
        ;; alternative was a 3/3-poisoned address draw (B's same-delta
        ;; objects were strings/vectors: the code area is not
        ;; layout-isomorphic).  Without RETAIN the inline attempt dies
        ;; loudly in wrf-code, making the RETAIN prerequisite explicit.
        [(and ($code? v)
              (eqv? (try (lambda () (staddr-gen v)) #f) 7)
              (eq-hashtable-ref dw-codetab v #f))
         (set! exts (cons (cons 'scode v) exts))
         (set! next (fx+ next 1))
         #t]
        ;; racket-interned identity domains (P3.1 lesson, retriggered
        ;; by native code supply): keywords are eq-matched by the
        ;; deserializer's fill instructions, resolved-module-paths key
        ;; the linklet cross-instance wiring -- copies split the world
        [(p3-kw? v)
         (set! exts (cons (cons 'kw v) exts))
         (set! next (fx+ next 1))
         #t]
        [(p3-rmp? v)
         (set! exts (cons (cons 'rmp v) exts))
         (set! next (fx+ next 1))
         #t]
        ;; prefab rtds intern by racket prefab KEY, not by Chez uid --
        ;; a fasl rtd copy splits minimatch struct dispatch (#<sim:...>).
        ;; (An early "malformed fasl closure" scare was run-to-run
        ;; variance, not this channel: the A-side self-read passes with
        ;; the channel on, and the full pair holds 12/12.)
        [(and (c3-rtd? v) (p33-prefab-key+count v))
         (set! exts (cons (cons 'prefab v) exts))
         (set! next (fx+ next 1))
         #t]
        [(eq-hashtable-ref forced v #f)
         (set! exts (cons (cons 'alien v) exts))
         (set! next (fx+ next 1))
         #t]
        ;; unmanaged tagged pointers (boot-static data outside SegInfo
        ;; coverage: measured as #<foreign>, $generation errors, all
        ;; type predicates #f) -- name them by static address; an
        ;; immediate misclassified here is harmless (its delta
        ;; roundtrips to the same value on B)
        [(and (not (fixnum? v))
              (not (char? v)) (not (null? v)) (not (boolean? v))
              (not (eof-object? v)) (not (bwp-object? v))
              ;; $generation returns #f (not an error) for pointers
              ;; outside SegInfo coverage -- measured on this batch
              (let ([g (try (lambda () (staddr-gen v)) 'BAD)])
                (if (eq? g 'BAD) #t (not g))))
         (set! exts (cons (cons 'alien v) exts))
         (set! next (fx+ next 1))
         #t]
        [else #f]))
    (let attempt ([iter 1])
      (set! exts '())
      (set! next 0)
      (let ([r (call/cc
                (lambda (k)
                  (with-exception-handler
                    (lambda (e) (k (cons 'err e)))
                    (lambda ()
                      (call-with-values
                        (lambda () (c-obvop))
                        (lambda (op get)
                          (c-faslw root op pred)
                          (cons 'ok (get))))))))])
        (cond
          [(eq? (car r) 'ok)
           (p3-write-bv-file! bv-path (cdr r))]
          [(fx> iter 40)
           (o "FATAL: codes fasl write did not converge after 40 iters")
           (exit 1)]
          [else
           (let ([irr (first-irritant (cdr r))])
             (o "  codes-write learn iter " iter ": " (obj-brief irr)
                "  code?=" ($code? irr)
                " rec?=" ($rec? irr)
                " proc?=" (procedure? irr)
                " sym?=" (symbol? irr)
                " pair?=" (pair? irr)
                " tlc?=" (try (lambda () ($tlc? irr)) '?)
                " gen=" (try (lambda () (staddr-gen irr)) '?)
                " fxaddr=" (try (lambda () (staddr-fxaddr irr)) '?)
                " delta=" (try (lambda () (fx- (staddr-fxaddr irr) staddr-anchor)) '?)
                " spec=" (try (lambda () (staddr-spec irr)) '?))
             (if (eq? irr 'NO-IRRITANT)
                 (begin
                   (o "FATAL: codes fasl crash with no irritant: "
                      (cond->string (cdr r)))
                   (exit 1))
                 (begin
                   (eq-hashtable-set! forced irr #t)
                   (attempt (fx+ iter 1)))))])))
    (let ([mv (make-vector next #f)]
          [nunnamed 0]
          [nalien 0])
      (let lp ([i 0] [l (reverse exts)])
        (when (pair? l)
          (let ([tag (car (car l))] [v (cdr (car l))])
            (cond
              [(eq? tag 'kw)
               (vector-set! mv i (vector 'kw (p3-kw-str v)))]
              [(eq? tag 'rmp)
               (vector-set! mv i (vector 'rmp (p3-rmp-name-spec v)))]
              [(eq? tag 'prefab)
               (let ([kc (p33-prefab-key+count v)])
                 (vector-set! mv i (vector 'prefab (car kc) (cdr kc))))]
              [(eq? tag 'alien)
               ;; measured identity: 4-byte-aligned raw C addresses --
               ;; FFI targets relinked into THIS process by eval-linklet
               ;; materialization (tag 4 is not a legal object tag).
               ;; They must go back to symbolic form: reverse the
               ;; address to its foreign-entry name; B re-resolves in
               ;; its own address space.  staddr naming is WRONG here
               ;; (the region is not the static generation; measured
               ;; B-side GC "copy: illegal type" / OOM from wrong
               ;; pointers under ASLR).
               (set! nalien (fx+ nalien 1))
               (let* ([seq (eq-hashtable-ref dw-obj-seq v #f)]
                      [sp (and (not seq) (staddr-spec v))]
                      [addr (and sp (fxlogor (fxsll (fx+ staddr-anchor (car sp)) 3)
                                             (cdr sp)))]
                      [nm (and addr (try (lambda () (foreign-address-name addr)) #f))])
                 (cond
                   ;; boot-era object with a walk-sequence name (some
                   ;; crash-learned generic hashtables live here)
                   [seq (vector-set! mv i (vector 'dwseq seq))]
                   [nm (vector-set! mv i (vector 'fentry nm))]
                   ;; init-minted generic hashtable (compiler dispatch
                   ;; tables burned into constant pools): rebuild by
                   ;; content on B, eqvht-aux style -- the zo-replay
                   ;; line materializes a fresh one per process too
                   [(hashtable? v)
                    (let* ([hf (c2-hashfn v)]
                           [kind (cond
                                   [(not hf) 'eqv]
                                   [(eq? hf c3-equalhash) 'equal]
                                   [else 'other])]
                           [weak (c3-htweak? v)]
                           [ks (c-htkeys v)]
                           [enc (lambda (x)
                                  ;; dispatch-table values are often zo
                                  ;; codes; carry them by name (the
                                  ;; manifest fasl has no externals)
                                  (cond
                                    [(and ($code? x) (zo-a-lookup x))
                                     => (lambda (hit)
                                          (vector 'zo (car hit) (cdr hit)))]
                                    [else x]))]
                           [plain? (lambda (x)
                                     ;; safe for a plain (predicate-free)
                                     ;; manifest fasl write
                                     (or (symbol? x) (fixnum? x) (string? x)
                                         (boolean? x) (null? x) (char? x)
                                         (bytevector? x) (flonum? x)
                                         (and (vector? x)
                                              (eq? (vector-ref x 0) 'zo))))]
                           [kv (call/cc
                                (lambda (kk)
                                  (let ([vec (make-vector (vector-length ks))])
                                    (let lp2 ([k 0])
                                      (when (fx< k (vector-length ks))
                                        (let* ([key (enc (vector-ref ks k))]
                                               [val (enc (c-htref v (vector-ref ks k) #f))])
                                          (unless (and (plain? key) (plain? val))
                                            ;; live values (closures over
                                            ;; expander callbacks): this is
                                            ;; a runtime cache -- ship EMPTY
                                            (kk #f))
                                          (vector-set! vec k (cons key val)))
                                        (lp2 (fx+ k 1))))
                                    vec)))])
                      (if kv
                          (vector-set! mv i (vector 'ht kind weak kv))
                          (vector-set! mv i (vector 'ht-empty kind weak))))]
                   ;; genuinely static-generation object the fasl layer
                   ;; refuses (boot tlc / symbol cells): same-layout
                   ;; address identity applies (gen 7 IS the static
                   ;; generation, unlike the FFI raw addresses)
                   [(and sp (eqv? (try (lambda () (staddr-gen v)) #f) 7))
                    ;; forensics: if this is a tlc (top-level variable
                    ;; cell living on a symbol-table bucket chain), its
                    ;; address-identity legitimacy is the current crash
                    ;; suspect -- print its identity
                    (when (try (lambda () ($tlc? v)) #f)
                      (o "  [static-tlc-extern] i=" i
                         " delta=" (car sp) " tag=" (cdr sp)
                         " keyval=" (trunc (c-fmt "~s" (try (lambda () ($tlc-keyval v)) '?)) 120)
                         " next=" (trunc (c-fmt "~a" (try (lambda () (obj-brief ($tlc-next v))) '?)) 60)))
                    (vector-set! mv i (vector 'staddr (car sp) (cdr sp)))]
                   [else
                    (o "  [alien-residue] i=" i " brief=" (obj-brief v)
                       " gen=" (try (lambda () (staddr-gen v)) 'ERR)
                       " tag=" (and sp (cdr sp))
                       " delta=" (and sp (car sp))
                       " fxaddr=" (try (lambda () (staddr-fxaddr v)) '?))
                    (vector-set! mv i (vector 'alien (obj-brief v)
                                              (and sp (cdr sp))))]))]
              [(eq-hashtable-ref dw-codetab v #f)
               => (lambda (pr)
                    (vector-set! mv i (vector 'bdw (car pr) (cdr pr))))]
              [else
               ;; static code outside the mark-point bdw walk (~107,
               ;; reachable only through init-dynamic codes' relocs).
               ;; Every option was measured: staddr address identity is
               ;; an A/B DRAW (4/6 pairs "malformed fasl closure" --
               ;; the code area is not layout-isomorphic, which is WHY
               ;; the segment rule chain excludes code from staddr);
               ;; loud dummies kill the world (2/11 -- kw.rkt-family
               ;; transformers among them ARE called); RETAIN recovers
               ;; 104/107 into the bdw walk but trips an unresolved
               ;; invalid-memory in B's walk (next campaign, logged).
               ;; Until then: staddr, accepting the draw -- winning
               ;; runs hold 12/12.
               (set! nunnamed (fx+ nunnamed 1))
               (let ([sp (staddr-spec v)])
                 (if sp
                     ;; distinct tag so B can TYPE-CHECK the resolved
                     ;; object (must be a code): a wrong draw becomes a
                     ;; loud identified FATAL instead of a poisoned read
                     (vector-set! mv i (vector 'scode-addr (car sp) (cdr sp)))
                     (vector-set! mv i (vector 'sdummy (dw-code-key v)
                                               (try (lambda () (#%$code-free-count v)) 0)))))]))
          (lp (fx+ i 1) (cdr l))))
      (o "codes fasl: externals=" next "  bdw-unnamed=" nunnamed
         "  alien=" nalien)
      ;; (P33_CF_K4=1) kind-4 immediate census over the kept codes:
      ;; a c-entry miss falls through to a raw value shipped verbatim;
      ;; if any of those are ADDRESSES (not small immediates), they are
      ;; process-local poison on B -- the suspected acceptance-phase
      ;; crash source under the codes supply
      (when (equal? (#%getenv "P33_CF_K4") "1")
        (let ([n4 0] [nbig 0] [samples '()]
              [$fasl-code-info
               (foreign-procedure "(cs)s_fasl_code_info" (ptr) ptr)])
          (let lp ([i 0])
            (when (fx< i (vector-length vecs))
              (let ([cv (vector-ref vecs i)])
                (let lp2 ([j 0])
                  (when (fx< j (vector-length cv))
                    (let ([c (vector-ref cv j)])
                      (when ($code? c)
                        (let ([info ($fasl-code-info c)])
                          (when info
                            (for-each
                              (lambda (e)
                                (when (eqv? (vector-ref e 4) 4)
                                  (set! n4 (fx+ n4 1))
                                  (let ([pv (vector-ref e 5)])
                                    (when (> pv 65536)
                                      (set! nbig (fx+ nbig 1))
                                      (when (fx< (length samples) 10)
                                        (set! samples
                                              (cons (cons (code-name c) pv)
                                                    samples)))))))
                              (vector-ref info 4))))))
                    (lp2 (fx+ j 1)))))
              (lp (fx+ i 1))))
          (o "kind-4 census: total=" n4 "  address-like(>65536)=" nbig)
          (for-each (lambda (pr) (o "   k4-big: " (car pr) " val=" (cdr pr)))
                    samples)))
      (p3-fasl-to-file! manifest-path (vector 'p3-codes-manifest 1 mv))
      ;; (P33_CF_SELFRD=1) same-process roundtrip: read the file back
      ;; with the REAL A-side externals -- separates writer-side stream
      ;; desync from B-side resolution differences
      (when (equal? (#%getenv "P33_CF_SELFRD") "1")
        (let ([extv (make-vector next #f)])
          (let lp ([i 0] [l (reverse exts)])
            (when (pair? l)
              (vector-set! extv i (cdr (car l)))
              (lp (fx+ i 1) (cdr l))))
          (let ([r (call/cc
                    (lambda (k)
                      (with-exception-handler
                        (lambda (c)
                          (k (list 'SELFRD-FAIL
                                   (if (message-condition? c)
                                       (condition-message c)
                                       'no-msg))))
                        (lambda ()
                          (let* ([bv (p3-read-bv-file bv-path)]
                                 [ip (c-obvip bv)]
                                 [m (c-faslr ip 'load extv)])
                            (list 'SELFRD-OK
                                  (vector-length (vector-ref m 2))))))))])
            (o "codes fasl self-read: " r)))))))

;; ---------- B side: name -> code ----------
(define zo-b-vecs #f)                   ; vector of per-event code vectors
(define zo-b-nmismatch 0)

(define (zo-b-build! zolist-path loader o)
  ;; loader : (path enc) -> list of (key-string . linklet) | 'none
  (let* ([m (p3-fasl-from-file zolist-path)]
         [evs (vector-ref m 2)]
         [n (vector-length evs)]
         [nbad 0] [ncodes 0])
    (set! zo-b-vecs (make-vector n '#()))
    (let lp ([i 0])
      (when (fx< i n)
        (let* ([ev (vector-ref evs i)]
               [prs (try (lambda () (loader (vector-ref ev 0) (vector-ref ev 1))) 'none)])
          (cond
            [(eq? prs 'none)
             (set! nbad (fx+ nbad 1))
             (o "  zo-load FAILED: " (vector-ref ev 0))]
            [else
             (let ([codes (zo-enum-linklets prs)])
               (vector-set! zo-b-vecs i codes)
               (set! ncodes (fx+ ncodes (vector-length codes)))
               (unless (fx= (vector-length codes) (vector-ref ev 2))
                 (set! zo-b-nmismatch (fx+ zo-b-nmismatch 1))
                 (o "  zo COUNT MISMATCH evt=" i " path=" (vector-ref ev 0)
                    " a-codes=" (vector-ref ev 2) " b-codes=" (vector-length codes))))]))
        (lp (fx+ i 1))))
    (o "zo table: events=" n "  load-failures=" nbad
       "  codes=" ncodes "  count-mismatch-events=" zo-b-nmismatch
       "  wrapped-forced=" zo-enum-stats-wc "  wc-force-fail=" zo-enum-stats-wcfail)
    n))

(define (zo-b-build-from-codes! bv-path manifest-path zolist-path
                                rkt-string->keyword rkt-bytes->path rkt-make-rmp
                                rkt-prefab-rtd merge? o)
  ;; single fasl-read replaces the 330-file zo replay.  The side
  ;; manifest names the externalized static codes (bdw keys) resolved
  ;; against B's own boot heap into the extvec BEFORE the read; any
  ;; unresolved slot is fatal (it would silently wire #f into a reloc
  ;; span -- the zoclo-MISS lesson).  The zolist still supplies
  ;; per-event expected counts as a parity check.
  (let* ([mm (p3-fasl-from-file manifest-path)]
         [mv (vector-ref mm 2)]
         [nx (vector-length mv)]
         [extvec (make-vector nx #f)]
         [ht-pending '()]   ; (table . kv) -- filled AFTER the codes read
         [nmiss 0])
    (let lp ([i 0])
      (when (fx< i nx)
        (let ([e (vector-ref mv i)])
          (case (vector-ref e 0)
            [(bdw)
             (let ([r (dw-lookup-code (vector-ref e 1) (vector-ref e 2))])
               (if r
                   (vector-set! extvec i r)
                   (begin
                     (set! nmiss (fx+ nmiss 1))
                     (when (fx<= nmiss 8)
                       (o "  codes-manifest MISS i=" i
                          " key=" (vector-ref e 1)
                          " occ=" (vector-ref e 2))))))]
            [(kw)
             ;; re-intern through racket's keyword table
             (let ([k (try (lambda () (rkt-string->keyword (vector-ref e 1))) #f)])
               (if k
                   (vector-set! extvec i k)
                   (begin
                     (set! nmiss (fx+ nmiss 1))
                     (when (fx<= nmiss 8)
                       (o "  codes-manifest KW-MISS i=" i
                          " str=" (vector-ref e 1))))))]
            [(rmp)
             ;; re-intern through racket's resolved-module-path table
             ;; (spec decoding mirrors the segment resolver's rmp case)
             (let* ([spec (vector-ref e 1)]
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
                    [r (and name (try (lambda () (rkt-make-rmp name)) #f))])
               (if r
                   (vector-set! extvec i r)
                   (begin
                     (set! nmiss (fx+ nmiss 1))
                     (when (fx<= nmiss 8)
                       (o "  codes-manifest RMP-MISS i=" i)))))]
            [(scode-addr)
             ;; static code by address, TYPE-CHECKED: resolving to a
             ;; non-code identifies the layout draw loudly
             (let ([r (staddr-resolve (vector-ref e 1) (vector-ref e 2))])
               (if (and r ($code? r))
                   (vector-set! extvec i r)
                   (begin
                     (set! nmiss (fx+ nmiss 1))
                     (when (fx<= nmiss 8)
                       (o "  codes-manifest SCODE-ADDR wrong-type i=" i
                          " delta=" (vector-ref e 1)
                          " tag=" (vector-ref e 2)
                          " got=" (if r (obj-brief r) 'unresolved))))))]
            [(sdummy)
             ;; boot-static code with no cross-process name: wire an
             ;; identifiable dummy (calling it errors loudly)
             (let* ([fc (vector-ref e 2)]
                    [vars (let lp2 ([k 0] [acc '()])
                            (if (fx= k fc)
                                acc
                                (lp2 (fx+ k 1)
                                     (cons (string->symbol (c-fmt "p3sdv~a" k))
                                           acc))))]
                    [mk (eval (list 'lambda vars
                                    (list 'lambda 'args
                                          (list 'error ''p3-sdummy
                                                (vector-ref e 1)))))]
                    [cl (apply mk (let lp2 ([k 0] [acc '()])
                                    (if (fx= k fc)
                                        acc
                                        (lp2 (fx+ k 1) (cons 0 acc)))))])
               (vector-set! extvec i ($ccode cl)))]
            [(prefab)
             ;; canonical prefab rtd by racket key + total field count
             (let ([r (try (lambda ()
                             (rkt-prefab-rtd (vector-ref e 1) (vector-ref e 2)))
                           #f)])
               (if (and r (c3-rtd? r))
                   (vector-set! extvec i r)
                   (begin
                     (set! nmiss (fx+ nmiss 1))
                     (when (fx<= nmiss 8)
                       (o "  codes-manifest PREFAB-MISS i=" i)))))]
            [(ht-empty)
             ;; runtime cache table shipped empty (cold-start semantics)
             (let* ([kind (vector-ref e 1)]
                    [weak (vector-ref e 2)]
                    [t (case kind
                         [(equal other) (c2-mkht c3-equalhash c3-equalpred)]
                         [else (if weak (c3-mkweqv) (c2-mkeqvht))])])
               (vector-set! extvec i t))]
            [(ht)
             ;; init-minted dispatch table: the empty table enters the
             ;; extvec now (its identity is all the reloc patch needs);
             ;; kv values may name zo codes, so filling waits until the
             ;; codes read below has built zo-b-vecs
             (let* ([kind (vector-ref e 1)]
                    [weak (vector-ref e 2)]
                    [kv (vector-ref e 3)]
                    [t (case kind
                         [(equal other) (c2-mkht c3-equalhash c3-equalpred)]
                         [else (if weak (c3-mkweqv) (c2-mkeqvht))])])
               (set! ht-pending (cons (cons t kv) ht-pending))
               (vector-set! extvec i t))]
            [(dwseq)
             ;; boot-era object named by walk sequence (B's own walk
             ;; produced the same numbering at the mark point)
             (let ([r (c-htref dw-seq-obj (vector-ref e 1) #f)])
               (if r
                   (vector-set! extvec i r)
                   (begin
                     (set! nmiss (fx+ nmiss 1))
                     (when (fx<= nmiss 8)
                       (o "  codes-manifest DWSEQ-MISS i=" i
                          " seq=" (vector-ref e 1))))))]
            [(fentry)
             ;; FFI target: re-resolve the foreign name in THIS
             ;; process's address space.
             ;; (P33_CF_FENTRY0=1: bisection probe -- wire address 0
             ;; instead; if the crash rate vanishes, this channel's
             ;; image-region addresses are what the GC chokes on)
             (let ([a (if (equal? (#%getenv "P33_CF_FENTRY0") "1")
                          0
                          (try (lambda () (foreign-entry (vector-ref e 1))) #f))])
               (if a
                   (vector-set! extvec i (staddr-a2o a 0))
                   (begin
                     (set! nmiss (fx+ nmiss 1))
                     (when (fx<= nmiss 8)
                       (o "  codes-manifest FENTRY-MISS i=" i
                          " name=" (vector-ref e 1))))))]
            [(staddr)
             ;; static-generation code outside the bdw walk: same-layout
             ;; address identity (A-side spec carried a roundtrip proof)
             (let ([r (staddr-resolve (vector-ref e 1) (vector-ref e 2))])
               (when (and r (try (lambda () ($tlc? r)) #f))
                 (o "  [static-tlc-resolve] i=" i
                    " keyval=" (trunc (c-fmt "~s" (try (lambda () ($tlc-keyval r)) '?)) 120)
                    " next=" (trunc (c-fmt "~a" (try (lambda () (obj-brief ($tlc-next r))) '?)) 60)))
               (if r
                   (vector-set! extvec i r)
                   (begin
                     (set! nmiss (fx+ nmiss 1))
                     (when (fx<= nmiss 8)
                       (o "  codes-manifest STADDR-MISS i=" i
                          " delta=" (vector-ref e 1)
                          " tag=" (vector-ref e 2))))))]
            [else
             (set! nmiss (fx+ nmiss 1))
             (when (fx<= nmiss 8)
               (o "  codes-manifest UNNAMED i=" i
                  " info=" (vector-ref e 1)))]))
        (lp (fx+ i 1))))
    (when (fx> nmiss 0)
      (o "FATAL: codes manifest unresolved static codes: " nmiss " / " nx
         "; aborting (a #f extvec slot would corrupt a reloc span)")
      (exit 1))
    (let* ([bv (p3-read-bv-file bv-path)]
           [ip (c-obvip bv)]
           [m (c-faslr ip 'load extvec)]
           [vecs (vector-ref m 2)]
           [meta (p3-fasl-from-file zolist-path)]
           [evs (vector-ref meta 2)]
           [n (vector-length vecs)]
         [ncodes 0]
         [nbad 0])
      (if (and merge? (vector? zo-b-vecs))
          ;; segmented supply: fold this segment's non-empty event
          ;; vectors into the accumulated table
          (let lp ([i 0])
            (when (fx< i (vector-length vecs))
              (let ([cv (vector-ref vecs i)])
                (when (fx> (vector-length cv) 0)
                  (vector-set! zo-b-vecs i cv)))
              (lp (fx+ i 1))))
          (set! zo-b-vecs vecs))
      ;; deferred dispatch-table fill: zo names resolve now
      (let ([decode (lambda (x)
                      (if (and (vector? x)
                               (fx= (vector-length x) 3)
                               (eq? (vector-ref x 0) 'zo))
                          (zo-b-lookup (vector-ref x 1) (vector-ref x 2))
                          x))])
        (for-each
          (lambda (pr)
            (let ([t (car pr)] [kv (cdr pr)])
              (let lp2 ([k 0])
                (when (fx< k (vector-length kv))
                  (let ([e2 (vector-ref kv k)])
                    (c2-htset! t (decode (car e2)) (decode (cdr e2))))
                  (lp2 (fx+ k 1))))))
          ht-pending))
      (unless (fx= n (vector-length evs))
        (set! nbad (fx+ nbad 1))
        (o "  codes-fasl EVENT-COUNT MISMATCH: codes=" n
           " zolist=" (vector-length evs)))
      (let lp ([i 0])
        (when (fx< i n)
          (let ([m2 (vector-length (vector-ref vecs i))])
            (set! ncodes (fx+ ncodes m2))
            ;; a merge segment is sparse: only its own event slot is
            ;; populated, so the per-event count check only applies to
            ;; non-empty slots there
            (when (and (fx< i (vector-length evs))
                       (or (not merge?) (fx> m2 0)))
              (unless (fx= m2 (vector-ref (vector-ref evs i) 2))
                (set! nbad (fx+ nbad 1))
                (o "  codes-fasl COUNT MISMATCH evt=" i
                   " codes=" m2
                   " expected=" (vector-ref (vector-ref evs i) 2)))))
          (lp (fx+ i 1))))
      (o "zo table (native codes fasl): events=" n "  codes=" ncodes
         "  static-extvec=" nx "  count-mismatches=" nbad)
      n)))

(define (zo-b-gc-evolution-audit! o)
  ;; forward-analysis probe (P33_CF_GCEVO): the one unverified link in
  ;; the crash's causal chain is what happens to fasl-rebuilt reloc
  ;; tables ACROSS the first collections.  Snapshot an identity
  ;; fingerprint of every kept code's reloc view, force minor
  ;; collections, re-snapshot, and report drift -- deterministic
  ;; observation of the poison forming, replacing the crash draw.
  (let* ([fci (foreign-procedure "(cs)s_fasl_code_info" (ptr) ptr)]
         [sig (lambda (e)
                ;; per-entry identity fingerprint, stable across
                ;; legitimate GC moves
                (let ([k (vector-ref e 4)] [p (vector-ref e 5)])
                  (cons k
                        (cond
                          [(fx> k 0) p]              ; index/imm value
                          [(and (symbol? p) (not (gensym? p))) p]
                          [(fixnum? p) p]
                          [(string? p) (string-length p)]
                          [($code? p) 'code]
                          [(procedure? p) 'proc]
                          [(pair? p) 'pair]
                          [(vector? p) 'vec]
                          [($rec? p) (try (lambda () (rtd-name p)) '?)]
                          [(flonum? p) 'flo]
                          [(bytevector? p) 'bv]
                          [(char? p) p]
                          [(null? p) 'nil]
                          [(boolean? p) p]
                          [else 'ALIEN]))))]
         [snap (lambda ()
                 (let ([acc '()])
                   (let lp ([i 0])
                     (when (fx< i (vector-length zo-b-vecs))
                       (let ([cv (vector-ref zo-b-vecs i)])
                         (let lp2 ([j 0])
                           (when (fx< j (vector-length cv))
                             (let ([c (vector-ref cv j)])
                               (when ($code? c)
                                 (let ([info (try (lambda () (fci c)) #f)])
                                   (set! acc
                                         (cons (cons (cons i j)
                                                     (and (vector? info)
                                                          (map sig (vector-ref info 4))))
                                               acc)))))
                             (lp2 (fx+ j 1)))))
                       (lp (fx+ i 1))))
                   acc))]
         [cmp (lambda (label s0 s1)
                (let ([nd 0] [samples '()])
                  (for-each
                    (lambda (a b)
                      (unless (equal? (cdr a) (cdr b))
                        (set! nd (fx+ nd 1))
                        (when (fx< (length samples) 8)
                          ;; find the first differing entry
                          (let lp ([x (cdr a)] [y (cdr b)] [k 0])
                            (cond
                              [(or (not (pair? x)) (not (pair? y)))
                               (set! samples
                                     (cons (list (car a) 'len-drift k) samples))]
                              [(equal? (car x) (car y))
                               (lp (cdr x) (cdr y) (fx+ k 1))]
                              [else
                               (set! samples
                                     (cons (list (car a) k (car x) '=> (car y))
                                           samples))])))))
                    s0 s1)
                  (o "GCEVO " label ": codes-drifted=" nd)
                  (for-each (lambda (s)
                              (o "   drift: " (trunc (c-fmt "~s" s) 200)))
                            (reverse samples))))])
    (let ([s0 (snap)])
      (collect 0 1)
      (let ([s1 (snap)])
        (cmp "after-1st-minor" s0 s1)
        (collect 0 1)
        (let ([s2 (snap)])
          (cmp "after-2nd-minor" s1 s2)
          (collect (collect-maximum-generation))
          (let ([s3 (snap)])
            (cmp "after-full" s2 s3)))))))

(define (zo-b-xcheck! codes-vecs native-vecs o)
  ;; deterministic hybrid cross-check (P33_CF_XCHECK): for every slot
  ;; the codes supply materialized, compare the fasl copy against the
  ;; replay-native code -- structural fields, reloc classification
  ;; sequence, and process-singleton identity (interned symbols and
  ;; entry indices must agree; gensyms exempt).  Turns the 2/12 crash
  ;; draw into a deterministic accusation.
  (let ([fci (foreign-procedure "(cs)s_fasl_code_info" (ptr) ptr)]
        [ndiff 0]
        [nslot 0]
        [samples '()])
    (define (diff! evt seq why a b)
      (set! ndiff (fx+ ndiff 1))
      (when (fx< (length samples) 25)
        (set! samples
              (cons (list evt seq why (obj-brief a) (obj-brief b)) samples))))
    (let lp ([i 0])
      (when (fx< i (vector-length codes-vecs))
        (let ([cv (vector-ref codes-vecs i)]
              [nv (if (fx< i (vector-length native-vecs))
                      (vector-ref native-vecs i)
                      '#())])
          (let lp2 ([j 0])
            (when (fx< j (vector-length cv))
              (let ([c (vector-ref cv j)])
                (when ($code? c)
                  (set! nslot (fx+ nslot 1))
                  (let ([n (and (fx< j (vector-length nv)) (vector-ref nv j))])
                    (cond
                      [(not (and n ($code? n))) (diff! i j 'native-not-code c n)]
                      [else
                       (unless (equal? (code-name c) (code-name n))
                         (diff! i j 'name c n))
                       (let ([ic (try (lambda () (fci c)) #f)]
                             [in (try (lambda () (fci n)) #f)])
                         (cond
                           [(not (and (vector? ic) (vector? in)))
                            (diff! i j 'info-unavailable ic in)]
                           [else
                            (unless (eqv? (vector-ref ic 0) (vector-ref in 0))
                              (diff! i j 'flags c n))
                            (unless (eqv? (vector-ref ic 1) (vector-ref in 1))
                              (diff! i j 'length c n))
                            (unless (eqv? (vector-ref ic 3) (vector-ref in 3))
                              (diff! i j 'free c n))
                            ;; v2 (P33_CF_XCHECK=2): byte-compare the
                            ;; machine code OUTSIDE the reloc spans; a
                            ;; difference there is a reference the
                            ;; reloc table does not cover -- the
                            ;; hidden-pointer smoking gun
                            (when (equal? (#%getenv "P33_CF_XCHECK") "2")
                              (let* ([bc (vector-ref ic 2)]
                                     [bn (vector-ref in 2)]
                                     [nb (bytevector-length bc)]
                                     [disp 0]
                                     [spans
                                      (let sp ([l (vector-ref ic 4)] [a 0] [acc '()])
                                        (if (null? l)
                                            acc
                                            (let ([a2 (+ a (vector-ref (car l) 2))])
                                              (sp (cdr l) a2 (cons a2 acc)))))]
                                     [in-span?
                                      (lambda (ix)
                                        (let lp3 ([l spans])
                                          (cond
                                            [(null? l) #f]
                                            ;; span values include
                                            ;; code-data-disp while ix is a
                                            ;; bv index: widen the window to
                                            ;; absorb the unknown disp --
                                            ;; misses are tolerable, false
                                            ;; accusations are not
                                            [(and (fx>= ix (fx- (car l) 88))
                                                  (fx< ix (fx+ (car l) 24)))
                                             #t]
                                            [else (lp3 (cdr l))])))])
                                (if (not (fx= nb (bytevector-length bn)))
                                    (diff! i j 'bytes-length c n)
                                    (let lp3 ([ix 0] [reported 0])
                                      (when (and (fx< ix nb) (fx< reported 1))
                                        (if (and (not (fx= (bytevector-u8-ref bc ix)
                                                           (bytevector-u8-ref bn ix)))
                                                 (not (in-span? ix)))
                                            (begin
                                              (diff! i j (cons 'bytes-at ix) c n)
                                              (lp3 (fx+ ix 1) (fx+ reported 1)))
                                            (lp3 (fx+ ix 1) reported)))))))
                            (let cmp ([lc (vector-ref ic 4)]
                                      [ln (vector-ref in 4)]
                                      [k 0])
                              (cond
                                [(and (null? lc) (null? ln)) (void)]
                                [(or (null? lc) (null? ln))
                                 (diff! i j (cons 'reloc-count k) c n)]
                                [else
                                 (let ([ec (car lc)] [en (car ln)])
                                   (unless (and (eqv? (vector-ref ec 0) (vector-ref en 0))
                                                (equal? (vector-ref ec 2) (vector-ref en 2))
                                                (equal? (vector-ref ec 3) (vector-ref en 3))
                                                (eqv? (vector-ref ec 4) (vector-ref en 4)))
                                     (diff! i j (cons 'reloc-shape k) ec en))
                                   (when (eqv? (vector-ref ec 4) (vector-ref en 4))
                                     (let ([pc (vector-ref ec 5)] [pn (vector-ref en 5)])
                                       (case (vector-ref ec 4)
                                         [(1 2 3)
                                          (unless (eqv? pc pn)
                                            (diff! i j (cons 'entry-idx k) pc pn))]
                                         [(4)
                                          (unless (eqv? pc pn)
                                            (diff! i j (cons 'imm k) pc pn))]
                                         [(0)
                                          (cond
                                            [(and (symbol? pn) (not (gensym? pn)))
                                             (unless (eq? pc pn)
                                               (diff! i j (cons 'sym-not-eq k) pc pn))]
                                            [($code? pn)
                                             (unless ($code? pc)
                                               (diff! i j (cons 'obj-class k) pc pn))]
                                            [(and (procedure? pn)
                                                  (not (procedure? pc)))
                                             (diff! i j (cons 'obj-class k) pc pn)]
                                            [(and ($rec? pn)
                                                  (not (and ($rec? pc)
                                                            (eq? (try (lambda () (rtd-name pc)) '?)
                                                                 (try (lambda () (rtd-name pn)) '??)))))
                                             (diff! i j (cons 'rec-class k) pc pn)]
                                            [else
                                             ;; v3: neither side has a
                                             ;; recognizable class -- the
                                             ;; copy value must then MATCH
                                             ;; the native bits (raw image
                                             ;; addresses do); anything
                                             ;; else is patch garbage
                                             (unless (or (eqv? pc pn)
                                                         (heapish? pc)
                                                         ($code? pc)
                                                         (symbol? pc)
                                                         (fixnum? pc)
                                                         (flonum? pc)
                                                         (string? pc)
                                                         (bytevector? pc)
                                                         (char? pc))
                                               (diff! i j (cons 'garbage k) pc pn))])]
                                         [else (void)])))
                                   (cmp (cdr lc) (cdr ln) (fx+ k 1)))]))]))])))
                (lp2 (fx+ j 1)))))
          (lp (fx+ i 1)))))
    (o "XCHECK: slots=" nslot "  diffs=" ndiff)
    (for-each (lambda (s) (o "   xdiff: " (trunc (c-fmt "~s" s) 220)))
              (reverse samples))))

(define (zo-b-lookup evt seq)
  (and zo-b-vecs
       (fx< evt (vector-length zo-b-vecs))
       (let ([v (vector-ref zo-b-vecs evt)])
         (and (fx< seq (vector-length v)) (vector-ref v seq)))))

;; ---------- creation-probe supply (cpb) ----------
;; Both roles run the same creation probes at the mark point; the deterministic
;; walk below turns the probe results into an indexed code table.  This names
;; boot-static codes that only gain closures at init time (struct machinery
;; accessors/mutators/constructors, regexp matchers).
(define cpb-codes '#())
(define cpb-tab (make-eq-hashtable))    ; code -> idx

(define (cpb-build! probe-vec o)
  (let ([acc '()] [n 0] [seen-c (make-eq-hashtable)] [seen-o (make-eq-hashtable)])
    (define (grab! c)
      (when (and c ($code? c) (not (eq-hashtable-ref seen-c c #f)))
        (eq-hashtable-set! seen-c c #t)
        (set! acc (cons c acc))
        (set! n (fx+ n 1))))
    (define (walk x depth)
      (when (and (fx> depth 0)
                 (heapish? x)
                 (not (eq-hashtable-ref seen-o x #f)))
        (eq-hashtable-set! seen-o x #t)
        (cond
          [(procedure? x)
           (unless ($cont? x)
             (grab! (try (lambda () ($ccode x)) #f))
             (let ([cl (safe-clen x)])
               (when cl
                 (let lp ([i 0])
                   (when (fx< i cl)
                     (walk (try (lambda () ($cref x i)) 0) (fx- depth 1))
                     (lp (fx+ i 1)))))))]
          [(hashtable? x) (void)]
          [($rec? x)
           (let ([nf (rtd-total-fields ($rtd x))])
             (let lp ([i 0])
               (when (fx< i nf)
                 (walk (try (lambda () ($rref x i)) 0) (fx- depth 1))
                 (lp (fx+ i 1)))))]
          [(pair? x)
           (if (or (weak-pair? x) (ephemeron-pair? x))
               (void)
               (begin (walk (car x) (fx- depth 1))
                      (walk (cdr x) (fx- depth 1))))]
          [(vector? x)
           (let lp ([i 0])
             (when (fx< i (vector-length x))
               (walk (vector-ref x i) (fx- depth 1))
               (lp (fx+ i 1))))]
          [(box? x) (walk (unbox x) (fx- depth 1))]
          [else (void)])))
    (walk probe-vec 9)
    (set! cpb-codes (list->vector (reverse acc)))
    (let lp ([i 0])
      (when (fx< i (vector-length cpb-codes))
        (eq-hashtable-set! cpb-tab (vector-ref cpb-codes i) i)
        (lp (fx+ i 1))))
    (o "creation-probe supply (cpb): codes=" n)))

(define (cpb-lookup c) (eq-hashtable-ref cpb-tab c #f))
(define (cpb-ref i)
  (and (fx>= i 0) (fx< i (vector-length cpb-codes)) (vector-ref cpb-codes i)))
