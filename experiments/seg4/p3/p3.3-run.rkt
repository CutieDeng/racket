;; ===== P3.3 runner: real racket -n host; code supplied from .zo manifest =====
;; Usage:
;;   P33_ROLE=A racket -q -n -t p3.3-run.rkt     produce seg4z-* (A side)
;;   P33_ROLE=B racket -q -n -t p3.3-run.rkt     load seg4z-* WITHOUT racket/init
;;   P33_PROBES=0                                skip acceptance/probes (timing mode)
;; This file is byte-identical for both roles (boot-state fingerprint discipline);
;; the role only selects which driver body runs after the mark point.
(module p3.3-run '#%kernel
  (#%require '#%linklet)
  (#%require '#%paramz)
  (define-values (SP)
    ;; portable: the engine/products root comes from P33_SP (set by every
    ;; run script and the build pipeline); no baked-in scratchpad path
    (let-values ([(v) (environment-variables-ref
                       (current-environment-variables) #"P33_SP")])
      (if v
          (bytes->string/utf-8 v)
          (error 'p3.3-run "P33_SP is not set (engine root directory)"))))
  (define-values (P3) (string-append SP "/p3"))
  (define-values (chez-eval) (primitive-lookup 'eval))
  (define-values (sysw) (primitive-lookup 'call-with-system-wind))
  (define-values (ceval) (lambda (s) (sysw (lambda () (chez-eval s)))))
  (define-values (now) (lambda () (current-inexact-milliseconds)))
  (define-values (say)
    (lambda args
      (for-each (lambda (x) (display x)) args)
      (newline)
      (flush-output (current-output-port))))
  (define-values (getenv*)
    (lambda (k) (environment-variables-ref (current-environment-variables) k)))
  (define-values (role)
    (let-values ([(v) (getenv* #"P33_ROLE")])
      (if v (bytes->string/utf-8 v) "B")))
  (define-values (do-probes?)
    (let-values ([(v) (getenv* #"P33_PROBES")])
      (if v (if (equal? v #"0") #f #t) #t)))
  (define-values (t0) (now))
  ;; ---- 1. clean chez env + engines ----
  (ceval (list 'load (string-append P3 "/p3.2-boot.chez.ss")))
  (ceval (list 'begin
               (list 'p32-load-into (string-append P3 "/p3.2-head.chez.ss"))
               (list 'p32-load-into (string-append SP "/p1.engine.ss"))
               (list 'p32-load-into (string-append SP "/p1.engine-suppl.ss"))
               (list 'p32-load-into (string-append SP "/p2.writeset.ss"))
               (list 'p32-load-into (string-append P3 "/p3.naming.ss"))
               (list 'p32-load-into (string-append P3 "/p3.3-enum.chez.ss"))
               (list 'p32-load-into (string-append P3 "/p3.3-table.chez.ss"))
               (list 'p32-load-into (string-append P3 (if (equal? role "A")
                                                          "/p3.3a.chez.ss"
                                                          "/p3.3b.chez.ss")))))
  (define-values (t1) (now))
  (say "[p3.3] engines loaded in " (- t1 t0) " ms; role=" role " probes=" do-probes?)
  ;; ---- 2. MARK POINT: kernel attach + roots (same shape as P3.1/P3.2) ----
  (namespace-require ''#%kernel)
  (define-values (rootvec)
    (vector (current-namespace) (current-thread) (current-custodian) (current-logger)
            (current-plumber) (current-inspector) (current-code-inspector)
            (current-security-guard)))
  (define-values (rootnames)
    (vector 'ns 'current-thread 'current-custodian 'current-logger 'current-plumber
            'current-inspector 'current-code-inspector 'current-security-guard))
  ;; kernel primitive (name . closure) pairs; sorting happens Chez-side
  ;; (deterministic on both roles: same mark-point namespace)
  (define-values (kernel-prim-vec)
    (list->vector
     (letrec-values ([(f) (lambda (l)
                            (if (null? l)
                                '()
                                (letrec-values ([(v) (namespace-variable-value
                                                      (car l) #t (lambda () #f))])
                                  (if (procedure? v)
                                      (cons (cons (symbol->string (car l)) v)
                                            (f (cdr l)))
                                      (f (cdr l))))))])
       (f (namespace-mapped-symbols)))))
  ;; ---- 3. bridged racket-level operations ----
  ;; --- 3a. .zo container reader (replicates expander/compile/read-linklet.rkt) ---
  (define-values (zo-rx) (byte-regexp #"[.]zo$"))
  (define-values (zo-read-int)
    (lambda (i) (integer-bytes->integer (read-bytes 4 i) #f #f)))
  (define-values (zo-read-bundle-at)   ; port positioned after "#~" -> hash
    (lambda (i)
      (let-values ([(vers-len) (read-byte i)])
        (read-bytes vers-len i)
        (let-values ([(vm-len) (read-byte i)])
          (read-bytes vm-len i)
          (let-values ([(tag) (read-byte i)])
            (if (= tag 66) ; #\B
                (let-values ([(sha-1) (read-bytes 20 i)])
                  (let-values ([(h) (read-linklet-bundle-hash i #f)])
                    (if (hash? h)
                        (if (bytes=? sha-1 #"\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0")
                            h
                            (hash-set h 'hash-code sha-1))
                        'none)))
                'none))))))
  (define-values (zo-encode-symbols)   ; expected-mod -> directory name bytes
    (lambda (expected)
      (if (symbol? expected)
          #""
          (apply bytes-append
                 (map (lambda (s)
                        (let-values ([(bstr) (string->bytes/utf-8 (symbol->string s))])
                          (let-values ([(len) (bytes-length bstr)])
                            (if (< len 255)
                                (bytes-append (bytes len) bstr)
                                (bytes-append (bytes 255)
                                              (integer->integer-bytes len 4 #f #f)
                                              bstr)))))
                      (cdr expected))))))
  (define-values (zo-extract-bundle)   ; path-string encoded-name -> hash | 'none
    (lambda (path encoded)
      (let-values ([(i) (open-input-file path)])
        (begin0
          (let-values ([(hdr) (read-bytes 2 i)])
            (if (equal? hdr #"#~")
                (let-values ([(vers-len) (read-byte i)])
                  (read-bytes vers-len i)
                  (let-values ([(vm-len) (read-byte i)])
                    (read-bytes vm-len i)
                    (let-values ([(tag) (read-byte i)])
                      (if (= tag 66)  ; bare bundle: only the main module lives here
                          (if (equal? encoded #"")
                              (begin
                                (file-position i 2)
                                (zo-read-bundle-at i))
                              'none)
                          (if (= tag 68) ; #\D : directory
                              (let-values ([(count) (zo-read-int i)])
                                (letrec-values ([(loop)
                                  (lambda (n target)
                                  (if (> n 0)
                                      (let-values ([(name) (read-bytes (zo-read-int i) i)])
                                        (let-values ([(offset) (zo-read-int i)])
                                          (zo-read-int i) (zo-read-int i) (zo-read-int i)
                                          (loop (- n 1)
                                                (if (equal? name encoded) offset target))))
                                      (if target
                                          (begin
                                            (file-position i target)
                                            (let-values ([(hdr2) (read-bytes 2 i)])
                                              (if (equal? hdr2 #"#~")
                                                  (zo-read-bundle-at i)
                                                  'none)))
                                          'none)))])
                                  (loop count #f)))
                              'none)))))
                'none))
          (close-input-port i)))))
  (define-values (zo-prepare-bundle-hash)  ; strip 'pre/'post; eval-linklet all
    (lambda (h)
      (let-values ([(h) (hash-remove (hash-remove h 'pre) 'post)])
        (letrec-values ([(loop)
          (lambda (ks h2)
          (if (null? ks)
              h2
              (loop (cdr ks)
                    (let-values ([(v) (hash-ref h2 (car ks))])
                      (if (linklet? v)
                          (hash-set h2 (car ks) (eval-linklet v))
                          h2)))))])
          (loop (hash-map h (lambda (k v) k)) h)))))
  (define-values (zo-key-string)
    (lambda (k)
      (if (symbol? k)
          (string-append "s:" (symbol->string k))
          (if (number? k)
              (string-append "i:" (number->string k))
              (string-append "o:" (format "~s" k))))))
  (define-values (zo-sorted-linklet-pairs)
    (lambda (h)
      (let-values ([(prs)
                    (letrec-values ([(loop)
                      (lambda (ks acc)
                      (if (null? ks)
                          acc
                          (loop (cdr ks)
                                (let-values ([(v) (hash-ref h (car ks))])
                                  (if (linklet? v)
                                      (cons (cons (zo-key-string (car ks)) v) acc)
                                      acc)))))])
                      (loop (hash-map h (lambda (k v) k)) '()))])
        (letrec-values ([(isort)
          (lambda (l out)
          (if (null? l)
              out
              (isort (cdr l)
                     (letrec-values ([(ins)
                       (lambda (o)
                       (if (null? o)
                           (list (car l))
                           (if (string<? (car (car l)) (car (car o)))
                               (cons (car l) o)
                               (cons (car o) (ins (cdr o))))))])
                       (ins out)))))])
          (isort prs '())))))
  ;; --- 3b. A-side: require racket/init with load interception ---
  (define-values (require-init-intercept!)
    (lambda (on-event)
      (let-values ([(orig) (current-load)])
        (current-load
         (lambda (path expected)
           (let-values ([(ps) (if (path? path) (path->string path) path)])
             (if (if expected (regexp-match? zo-rx ps) #f)
                 (let-values ([(enc) (zo-encode-symbols expected)])
                   (let-values ([(h) (zo-extract-bundle ps enc)])
                     (if (hash? h)
                         (let-values ([(ph) (zo-prepare-bundle-hash h)])
                           (begin
                             (on-event (vector ps enc (zo-sorted-linklet-pairs ph)))
                             ((current-eval) (hash->linklet-bundle ph))))
                         (if (pair? expected)
                             (void)   ; missing submodule: default handler does nothing
                             (begin
                               (on-event (vector ps enc 'fallback))
                               (orig path expected))))))
                 (begin
                   (on-event (vector ps 'nonzo 'fallback))
                   (orig path expected))))))
        (namespace-require 'racket/init)
        (say "[p33] init done; xrepl step controlled by P33_XREPL env")
        (let-values ([(xmode) (getenv* #"P33_XREPL")])
          (if (equal? xmode #"none")
              (void)
              (begin
                (dynamic-require 'xrepl #f)
                (say "[p33] xrepl loaded")
                (if (equal? xmode #"require-only")
                    (void)
                    (begin
                      ((dynamic-require 'xrepl/xrepl 'toplevel-prefix) "")
                      (say "[p33] xrepl env set"))))))
        (say "[p33][A] ns census: " (rkt-ns-census))
        ;; A-side PREHEAT: run the full B acceptance workload BEFORE the
        ;; mark/write so every lazy syntax-literal these evals force is
        ;; forced ON A and ships in the segment. Root cause being fixed:
        ;; the old order wrote the segment first, so B's acceptance was
        ;; the first forcing of many module templates -- B-minted scopes
        ;; split the binding world (kw.rkt #%app unbound).
        ;; Runs before (current-load orig) so cold loads are intercepted.
        ;; P33_PREHEAT selects the preheat strategy (read here, inside the
        ;; A-only path: an env read before the mark point would allocate
        ;; differently on A and B and the segment is boot-state sensitive):
        ;;   workload (default) -- the 20-expr acceptance workload below
        ;;   force              -- targeted force of every declared module's
        ;;                         deserialized-syntax box via the module's
        ;;                         force-bulk-binding closure (7.2.1): no
        ;;                         user-level code, no new instantiations
        ;;   both               -- workload then force (diagnostic)
        ;;   none               -- no preheat at all (diagnostic)
        (if (equal? role "A")
            (let-values ([(pmode) (let-values ([(v) (getenv* #"P33_PREHEAT")])
                                    (if v (bytes->string/utf-8 v) "workload"))])
              (begin
                (if (if (equal? pmode "force") #t (equal? pmode "none"))
                    (void)
                    (run-workload-preheat!))
                (if (if (equal? pmode "workload") #t (equal? pmode "none"))
                    (void)
                    (run-force-preheat!))
                (if (equal? pmode "none")
                    (say "[p33][A] preheat: none (diagnostic)")
                    (void))))
            (void))
        (current-load orig)
        (collect-garbage)
        (collect-garbage))))
  (define-values (run-force-preheat!)
    (lambda ()
      (let-values ([(plan) (ceval (list 'p32-in
                                        (list 'quote
                                              (list 'p33-syntax-force-plan
                                                    (list 'quote (vector-ref rootvec 0))))))])
        (if (if (vector? plan) (eq? (vector-ref plan 0) 'ERR) #t)
            (say "[p33][A] force-preheat PLAN FAILED: " plan)
            (let-values ([(breg) (vector-ref plan 0)]
                         [(prs) (vector-ref plan 1)]
                         [(se2) (rkt-make-safe-eval)])
              (letrec-values ([(lp)
                               (lambda (i ok err)
                                 (if (= i (vector-length prs))
                                     (say "[p33][A] force-preheat: modules="
                                          (vector-length prs) " ok=" ok " err=" err)
                                     (let-values ([(r) (se2 (list (cdr (vector-ref prs i))
                                                                  breg))])
                                       (if (eq? (car r) 'val)
                                           (lp (+ i 1) (+ ok 1) err)
                                           (begin
                                             (if (< err 8)
                                                 (say "[p33][A] force-preheat ERR "
                                                      (car (vector-ref prs i)) ": " (cdr r))
                                                 (void))
                                             (lp (+ i 1) ok (+ err 1)))))))])
                (lp 0 0 0)))))))
  (define-values (run-workload-preheat!)
    (lambda ()
            (let-values ([(se) (rkt-make-safe-eval)])
              (let-values ([(res)
                            (map (lambda (e) (car (se e)))
                                 (list '(+ 1 2)
                                       '(map add1 (list 1 2))
                                       '(sort (list 3 1 2) <)
                                       '(require racket/list)
                                       '(last (list 1 2 3))
                                       '(require file/sha1)
                                       '(sha1 (open-input-bytes (string->bytes/utf-8 "abc")))
                                       '(with-handlers ([(lambda (x) #t) (lambda (x) 'e)]) (car 5))
                                       '(for/list ([i (in-range 3)]) (* i i))
                                       '(hash-ref (hash 'a 1 'b 2) 'b)
                                       '(sort (list (list 2) (list 1)) < #:key car)
                                       '(regexp-match (regexp "a(b+)") "xabbby")
                                       '(let ([o (open-output-string)])
                                          (parameterize ([current-output-port o])
                                            (printf "~a" (list 1 2)))
                                          (get-output-string o))
                                       '(match (list 1 2) [(list a b) (+ a b)])
                                       '(require racket/contract)
                                       '((contract (-> integer? integer?) add1 'pos 'neg) 5)
                                       '((contract (->i ([x integer?]) [r (x) (>=/c x)]) add1 'pos 'neg) 5)
                                       '(let ()
                                          (define c% (class object% (super-new) (define/public (m x) (add1 x))))
                                          (send (new c%) m 41))
                                       '(require racket/date)
                                       '(string? (date->string (seconds->date 0)))))])
                (say "[p33][A] preheat: " (length res) " exprs, fails="
                     (letrec-values ([(cnt) (lambda (l n)
                                              (if (null? l)
                                                  n
                                                  (cnt (cdr l)
                                                       (if (eq? (car l) 'err) (+ n 1) n))))])
                       (cnt res 0)))))))
  ;; --- 3c. B-side: load one recorded zo event (fasl decode only, NO declare) ---
  (define-values (rkt-load-zo-event)
    (lambda (ps enc)
      (let-values ([(h) (zo-extract-bundle ps enc)])
        (if (hash? h)
            (zo-sorted-linklet-pairs (zo-prepare-bundle-hash h))
            'none))))
  ;; --- 3d. shared bridges ---
  ;; P3.3: safe-eval is built from #%kernel machinery only (continuation prompt
  ;; + exception-handler-key), so it works without any racket/init state and
  ;; cannot itself crash the driver when the replayed state is broken.
  (define-values (p33-safe-tag) (make-continuation-prompt-tag 'p33-safe-eval))
  (define-values (rkt-make-safe-eval)
    (lambda ()
      (lambda (e)
        (call-with-continuation-prompt
         (lambda ()
           (with-continuation-mark
             exception-handler-key
             (lambda (x)
               (abort-current-continuation
                p33-safe-tag
                (cons 'err (if (exn? x)
                               (exn-message x)
                               (format "raised: ~s" x)))))
             (cons 'val (eval e))))
         p33-safe-tag
         (lambda (v) v)))))
  (define-values (rkt-mcc)
    (lambda ()
      (let-values ([(f) (namespace-variable-value 'module-cache-clear! #t (lambda () #f))])
        (if f (begin (f) 'ok) 'no-module-cache-clear!))))
  ;; canonical prefab rtd interning (rumble prefabs table) by key+total-count
  (define-values (rkt-prefab-rtd)
    (lambda (key count) (prefab-key->struct-type key count)))
  ;; diagnostics: L1 namespace census via the public API -- counts the
  ;; symbols the current namespace maps at the top level; if a symbol
  ;; is listed here but identifier-binding cannot resolve it, the
  ;; table survived and the failure is scope mismatch, whereas a
  ;; missing symbol means the table content itself was lost
  (define-values (rkt-ns-census)
    (lambda ()
      (let-values ([(syms) (namespace-mapped-symbols)])
        (list 'mapped-count (length syms)
              'require? (if (memq 'require syms) #t #f)
              'match? (if (memq 'match syms) #t #f)
              'plus? (if (memq '+ syms) #t #f)))))

  ;; diagnostics: for a symbol, report (a) whether the current
  ;; namespace resolves it to a binding, (b) whether the top-level
  ;; variable has a value -- distinguishing the binding layer from the
  ;; variable layer
  (define-values (rkt-hash-keys)
    (lambda (h)
      (call-with-continuation-prompt
       (lambda ()
         (with-continuation-mark
           exception-handler-key
           (lambda (x) (abort-current-continuation p33-safe-tag 'HK-ERR))
           (hash-map h (lambda (k v) k))))
       p33-safe-tag
       (lambda (v) v))))
  (define-values (rkt-hash-get)
    (lambda (h k)
      (call-with-continuation-prompt
       (lambda ()
         (with-continuation-mark
           exception-handler-key
           (lambda (x) (abort-current-continuation p33-safe-tag 'HG-ERR))
           (hash-ref h k #f)))
       p33-safe-tag
       (lambda (v) v))))
  (define-values (rkt-analyze-syntax-fail)
    ;; eval expr, catch exn:fail:syntax, and return syntax-debug-info of
    ;; the offending identifier -- shows its scope set and each candidate
    ;; binding's context with match? flags
    (lambda (expr)
      (call-with-continuation-prompt
       (lambda ()
         (with-continuation-mark
           exception-handler-key
           (lambda (x)
             (abort-current-continuation
              p33-safe-tag
              (if (exn:fail:syntax? x)
                  (let-values ([(stxes) (exn:fail:syntax-exprs x)]
                               [(sdi) (dynamic-require 'racket/base 'syntax-debug-info)])
                    (if (null? stxes)
                        "no exprs in syntax exn"
                        (format "~s" (sdi (car stxes)))))
                  (format "not a syntax exn: ~a" (if (exn? x) (exn-message x) x)))))
           (begin (eval expr) "EVAL-OK: no failure")))
       p33-safe-tag
       (lambda (v) v))))
  (define-values (rkt-debug-binding)
    (lambda (sym)
      (call-with-continuation-prompt
       (lambda ()
         (with-continuation-mark
           exception-handler-key
           (lambda (x) (abort-current-continuation
                        p33-safe-tag
                        (if (exn? x)
                            (string-append "DBG-ERR: " (exn-message x))
                            'DBG-ERR)))
           (let-values ([(sdi) (dynamic-require 'racket/base 'syntax-debug-info)]
                        [(nsi) (dynamic-require 'racket/base 'namespace-syntax-introduce)]
                        [(d->s) (dynamic-require 'racket/base 'datum->syntax)])
             (format "~s" (sdi (nsi (d->s #f sym)))))))
       p33-safe-tag
       (lambda (v) v))))
  (define-values (rkt-probe-layers)
    (lambda (sym)
      (let-values ([(binding)
                    (with-continuation-mark
                      exception-handler-key
                      (lambda (x) (abort-current-continuation
                                   p33-safe-tag
                                   (if (exn? x)
                                       (string-append "ERR: " (exn-message x))
                                       'BINDING-ERR)))
                      (call-with-continuation-prompt
                       (lambda ()
                         (eval (list 'identifier-binding
                                     (list 'quote-syntax sym))))
                       p33-safe-tag
                       (lambda (v) v)))]
                   [(varval)
                    (call-with-continuation-prompt
                     (lambda ()
                       (with-continuation-mark
                         exception-handler-key
                         (lambda (x) (abort-current-continuation p33-safe-tag 'NO-VALUE))
                         (namespace-variable-value sym #t)))
                     p33-safe-tag
                     (lambda (v) v))])
        (list sym
              'binding: (if (pair? binding) 'MODULE-BINDING binding)
              'value: (if (procedure? varval) 'PROC varval)))))
  ;; diagnostics: peek into a binding table's syms hash
  (define-values (rkt-syms-peek)
    (lambda (syms who)
      (list who
            'count: (hash-count syms)
            'require? (if (hash-ref syms 'require #f) #t #f)
            'match? (if (hash-ref syms 'match #f) #t #f)
            'lambda? (if (hash-ref syms 'lambda #f) #t #f))))

  ;; deep two-level merge of top-level binding tables: keep the B-side
  ;; table as the base (its scopes unify with B-side syntax literals)
  ;; and fold in every entry of the A-side table
  (define-values (rkt-merge-syms)
    (lambda (b-syms a-syms)
      (letrec-values ([(fold-hash)
                       (lambda (h f acc)
                         (letrec-values ([(loop)
                                          (lambda (pos acc)
                                            (if pos
                                                (loop (hash-iterate-next h pos)
                                                      (f (hash-iterate-key h pos)
                                                         (hash-iterate-value h pos)
                                                         acc))
                                                acc))])
                           (loop (hash-iterate-first h) acc)))])
        (fold-hash
         a-syms
         (lambda (sym a-inner t)
           (let-values ([(b-inner) (hash-ref t sym #f)])
             (hash-set t sym
                       (if b-inner
                           (fold-hash a-inner
                                      (lambda (sc bind h) (hash-set h sc bind))
                                      b-inner)
                           a-inner))))
         b-syms))))
  ;; creation probes: exercise runtime creation paths whose closures capture
  ;; boot-static codes (struct accessors/mutators/constructors, regexp
  ;; matchers); both roles run this at the mark point, so the enumerated code
  ;; sequence is identical and (probe, seq) is a valid cross-process name.
  (define-values (rkt-creation-probes)
    (lambda ()
      (let-values ([(st mk pred acc mut)
                    (make-struct-type 'p33probe #f 2 1 'auto-v '() (make-inspector)
                                      #f '(0) #f 'p33ctor)])
        (let-values ([(st2 mk2 pred2 acc2 mut2)
                      (make-struct-type 'p33probe2 st 1 2 'auto-v2 '() (make-inspector)
                                        #f '() #f 'p33ctor2)])
          (vector mk pred acc mut
                  (make-struct-field-accessor acc 0 'f0)
                  (make-struct-field-mutator mut 1 'f1)
                  mk2 pred2 acc2 mut2
                  (make-struct-field-accessor acc2 0 'g0)
                  (make-struct-field-mutator mut2 0 'g0)
                  (struct-type-make-constructor st)
                  (struct-type-make-predicate st)
                  (regexp "a(b+)[cd]*x?")
                  (byte-regexp #"z+(a|bc)")
                  (pregexp "\\d{2,3}(?:ab|c)*")
                  (regexp "^start.*end$"))))))
  (define-values (t2) (now))
  (say "[p3.3] mark point ready at " (- t2 t0) " ms")
  ;; ---- 4. run the driver body ----
  (if (equal? role "A")
      (ceval (list 'p32-in (list 'quote
                                 (list 'p33a-run!
                                       (list 'quote kernel-prim-vec)
                                       (list 'quote rootvec)
                                       (list 'quote rootnames)
                                       (list 'quote require-init-intercept!)
                                       (list 'quote rkt-make-safe-eval)
                                       (list 'quote string->keyword)
                                       (list 'quote rkt-creation-probes)))))
      (ceval (list 'p32-in (list 'quote
                                 (list 'p33b-run!
                                       (list 'quote kernel-prim-vec)
                                       (list 'quote rootvec)
                                       (list 'quote rkt-load-zo-event)
                                       (list 'quote string->keyword)
                                       (list 'quote bytes->path)
                                       (list 'quote make-resolved-module-path)
                                       (list 'quote rkt-make-safe-eval)
                                       (list 'quote rkt-mcc)
                                       (list 'quote rkt-prefab-rtd)
                                       (list 'quote rkt-creation-probes)
                                       (list 'quote rkt-merge-syms)
                                       (list 'quote rkt-probe-layers)
                                       (list 'quote rkt-debug-binding)
                                       (list 'quote rkt-analyze-syntax-fail)
                                       (list 'quote rkt-hash-keys)
                                       (list 'quote rkt-hash-get)
                                       (list 'quote rkt-syms-peek)
                                       (list 'quote rkt-ns-census)
                                       do-probes?)))))
  (define-values (t3) (now))
  (say "[p3.3] driver body done in " (- t3 t2) " ms; total " (- t3 t0) " ms")
  (say "P33-RUN-DONE role=" role))
