#!/usr/bin/env python3
# Generate P3.2 chez driver files from the P3.1 originals by anchored surgery.
import re, sys, os

SP = "/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad"
P3 = SP + "/p3"

def rd(p):
    with open(p) as f: return f.read()
def wr(p, s):
    with open(p, "w") as f: f.write(s)
def must(cond, msg):
    if not cond: sys.exit("SURGERY FAIL: " + msg)

def sub1(s, old, new, label, count=1):
    n = s.count(old)
    must(n == count, f"{label}: expected {count} occurrence(s), found {n}")
    return s.replace(old, new)

# ---------- head: p1.head.ss minus the .so loads ----------
head = rd(SP + "/p1.head.ss")
loads_start = head.index("(for-each load")
loads_end = head.index('expander.so"))') + len('expander.so"))') + 1
head2 = (";; ===== P3.2 head: p1.head.ss with the .so layer loads removed =====\n"
         ";; (real racket process: layers already live in racket.boot)\n"
         + head[:loads_start].split(";; Pure-Chez head")[0]
         + head[loads_end:])
wr(P3 + "/p3.2-head.chez.ss", head2)

# ---------- A driver ----------
a = rd(P3 + "/p3a.driver.ss")

a = sub1(a, ";; ===== P3 process A (generator): produce the cross-process pre-instantiated segment =====\n(import (rumble) (expander) (io))",
         ";; ===== P3.2 process A driver (real racket -n host; libraries hollow -> no imports) =====\n"
         ";; Racket-level operations arrive as bridged procedure arguments.",
         "A header")

a = sub1(a, """(call-in-main-thread
 (lambda ()
   (boot)
   (set-exec-file! (string->path "/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket"))
   (current-library-collection-links (find-library-collection-links))
   (current-library-collection-paths (find-library-collection-paths))
   (let ([prog (c-oof (string-append P3 "/p3a.prog") 'replace)]
         [lp (c-oof (string-append P3 "/p3a.log") 'replace)])
     (define (p . xs) (for-each (lambda (x) (c-disp x prog)) xs) (c-nl prog) (c-flush prog))
     (define (o . xs) (for-each (lambda (x) (c-disp x lp)) xs) (c-nl lp) (c-flush lp))
     (o "==== P3 PROCESS A: generate seg4 files (racket/init instantiation state) ====")
     (p "kernel attach... cpu=" (c-cpu))
     (namespace-require (list 'quote (string->symbol "#%kernel")))
     (let* ([pre-ns (eval '(current-namespace))]
            [extra-names '(current-thread current-custodian current-logger
                           current-plumber current-inspector current-code-inspector
                           current-security-guard)]
            [extras (eval (list 'map '(lambda (n)
                                        ((lambda (v)
                                           (if (procedure? v)
                                               (if (procedure-arity-includes? v 0) (v) v)
                                               v))
                                         (namespace-variable-value n #t (lambda () #f))))
                          (list 'quote extra-names)))]
            [rootvec (list->vector (cons pre-ns extras))]
            [rootnames (list->vector (cons 'ns extra-names))])""",
         """(define (p32a-run! rootvec rootnames require-init! rkt-make-safe-eval rkt-string->keyword)
   (let ([dummy-cimt #f])
   (let ([prog (c-oof (string-append P3 "/p3.2a.prog") 'replace)]
         [lp (c-oof (string-append P3 "/p3.2a.log") 'replace)])
     (define (p . xs) (for-each (lambda (x) (c-disp x prog)) xs)
       (c-disp " rt=" prog) (c-disp (real-time) prog) (c-nl prog) (c-flush prog))
     (define (o . xs) (for-each (lambda (x) (c-disp x lp)) xs) (c-nl lp) (c-flush lp))
     (o "==== P3.2 PROCESS A (real racket -n host): generate seg4r files ====")
     (p "driver entered (kernel attach was done racket-side)... cpu=" (c-cpu))
     (let* ([pre-ns (vector-ref rootvec 0)])""",
         "A wrapper")

a = sub1(a, "(namespace-require 'racket/init)", "(require-init!)", "A racket/init")

a = sub1(a, '(string-append P3 "/seg4-state.fasl")', '(string-append P3 "/seg4r-state.fasl")', "A state name")
a = sub1(a, '(string-append P3 "/seg4-externals.manifest")', '(string-append P3 "/seg4r-externals.manifest")', "A manifest name")
a = sub1(a, '(string-append P3 "/seg4-patch.rktd")', '(string-append P3 "/seg4r-patch.rktd")', "A patch name")
a = sub1(a, 'artifacts written: seg4-state.fasl (', 'artifacts written: seg4r-state.fasl (', "A artifact log")
a = sub1(a, '" bytes), seg4-externals.manifest ("', '" bytes), seg4r-externals.manifest ("', "A artifact log 2")
a = sub1(a, '" entries), seg4-patch.rktd ("', '" entries), seg4r-patch.rktd ("', "A artifact log 3")

a = sub1(a, """                             (let ([safe-eval
                                    (eval '(lambda (e)
                                             (with-handlers ([(lambda (x) #t)
                                                              (lambda (x) (cons 'err (if (exn? x)
                                                                                         (exn-message x)
                                                                                         (format "~s" x))))])
                                               (cons 'val (eval e)))))]
                                   [xp 0] [xf 0])""",
         """                             (let ([safe-eval (rkt-make-safe-eval)]
                                   [xp 0] [xf 0])""",
         "A safe-eval")

a = sub1(a, "(string->keyword \"key\")", "(rkt-string->keyword \"key\")", "A kw probe")

a = sub1(a, """                               (probe "regexp" '(regexp-match (regexp "a(b+)") "xabbby"))
""",
         """                               (probe "regexp" '(regexp-match (regexp "a(b+)") "xabbby"))
                               (probe "string port + printf"
                                      '(let ([o (open-output-string)])
                                         (parameterize ([current-output-port o])
                                           (printf "~a" (list 1 2)))
                                         (get-output-string o)))
""",
         "A printf probe insert")

# tail: original closes call-in-main-thread wrapper; new closes define+dummy-let
a = sub1(a, """                             (p "all done cpu=" (c-cpu))
                             (c-flush lp))]))])))))))
       (void)))
   (void)))
(exit)""",
         """                             (p "all done cpu=" (c-cpu))
                             (c-flush lp))]))])))))))
       (void))))
   'p32a-done)""",
         "A tail")

wr(P3 + "/p3.2a.chez.ss", a)

# ---------- B driver ----------
b = rd(P3 + "/p3b.driver.ss")

b = sub1(b, ";; ===== P3 process B (loader): resolve manifest, load seg4, replay patch, verify =====\n(import (rumble) (expander) (io))",
         ";; ===== P3.2 process B driver (real racket -n host; libraries hollow -> no imports) =====\n"
         ";; Racket-level operations arrive as bridged procedure arguments.",
         "B header")

b = sub1(b, "(define p3-skip-tags '(custodian thread))   ; (c)-class: process-local, not replayed",
         "(define p3-skip-tags '(custodian))   ; P3.2: 'thread ops now APPLIED (= thread-cell seeding hook)",
         "B skip-tags")

b = sub1(b, """(call-in-main-thread
 (lambda ()
   (boot)
   (set-exec-file! (string->path "/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket"))
   (current-library-collection-links (find-library-collection-links))
   (current-library-collection-paths (find-library-collection-paths))
   (let ([prog (c-oof (string-append P3 "/p3b.prog") 'replace)]
         [lp (c-oof (string-append P3 "/p3b.log") 'replace)])
     (define (p . xs) (for-each (lambda (x) (c-disp x prog)) xs) (c-nl prog) (c-flush prog))
     (define (o . xs) (for-each (lambda (x) (c-disp x lp)) xs) (c-nl lp) (c-flush lp))
     (o "==== P3 PROCESS B: load seg4 into a fresh process ====")
     (p "kernel attach... cpu=" (c-cpu))
     (namespace-require (list 'quote (string->symbol "#%kernel")))
     (let* ([pre-ns (eval '(current-namespace))]
            [extra-names '(current-thread current-custodian current-logger
                           current-plumber current-inspector current-code-inspector
                           current-security-guard)]
            [extras (eval (list 'map '(lambda (n)
                                        ((lambda (v)
                                           (if (procedure? v)
                                               (if (procedure-arity-includes? v 0) (v) v)
                                               v))
                                         (namespace-variable-value n #t (lambda () #f))))
                          (list 'quote extra-names)))]
            [rootvec (list->vector (cons pre-ns extras))])""",
         """(define p32-tcl 0)     ; cumulative codeloc n3-resolve cpu ms
(define p32-trmp 0)    ; cumulative rmp resolve cpu ms
(define p32-do-codeloc? #t)
(define (p32-gcms)
  (let ([t (sstats-gc-cpu (statistics))])
    (+ (* 1000 (time-second t)) (div (time-nanosecond t) 1000000))))
(define (p32b-run! rootvec require-init! rkt-string->keyword rkt-bytes->path
                    rkt-make-rmp rkt-make-safe-eval rkt-hook-module-cache-clear! do-probes?)
   (let ([dummy-cimt #f])
   (let ([prog (c-oof (string-append P3 "/p3.2b.prog") 'replace)]
         [lp (c-oof (string-append P3 "/p3.2b.log") 'replace)])
     (define (p . xs) (for-each (lambda (x) (c-disp x prog)) xs)
       (c-disp " rt=" prog) (c-disp (real-time) prog)
       (c-disp " gc=" prog) (c-disp (p32-gcms) prog) (c-nl prog) (c-flush prog))
     (define (o . xs) (for-each (lambda (x) (c-disp x lp)) xs) (c-nl lp) (c-flush lp))
     (o "==== P3.2 PROCESS B (real racket -n host): load seg4r into a fresh process ====")
     (p "driver entered (kernel attach was done racket-side)... cpu=" (c-cpu))
     (let* ([pre-ns (vector-ref rootvec 0)])""",
         "B wrapper")

b = sub1(b, '(p3-fasl-from-file (string-append P3 "/seg4-externals.manifest"))',
         '(p3-fasl-from-file (string-append P3 "/seg4r-externals.manifest"))', "B manifest name")

b = sub1(b, "(namespace-require 'racket/init)", "(require-init!)", "B racket/init")

b = sub1(b, """         (let ([safe-eval
                (eval '(lambda (e)
                         (with-handlers ([(lambda (x) #t)
                                          (lambda (x) (cons 'err (if (exn? x)
                                                                     (exn-message x)
                                                                     (format "~s" x))))])
                           (cons 'val (eval e)))))])""",
         """         (let ([safe-eval (if do-probes?
                              (rkt-make-safe-eval)
                              (lambda (e) (cons 'err "probes-disabled")))])""",
         "B safe-eval")

b = sub1(b, "(let ([k (try (lambda () (string->keyword (vector-ref e 1))) #f)])",
         "(let ([k (try (lambda () (rkt-string->keyword (vector-ref e 1))) #f)])",
         "B kw resolve")

b = sub1(b, """(try (lambda ()
                                                          (eval (list 'bytes->path (vector-ref s 1))))
                                                        #f)""",
         """(try (lambda ()
                                                          (rkt-bytes->path (vector-ref s 1)))
                                                        #f)""",
         "B bytes->path")

b = sub1(b, """(try (lambda ()
                                            (eval (list 'make-resolved-module-path
                                                        (list 'quote name))))
                                          #f)""",
         """(try (lambda () (rkt-make-rmp name))
                                          #f)""",
         "B make-rmp")

b = sub1(b, '(let* ([bv (p3-read-bv-file (string-append P3 "/seg4-state.fasl"))]\n                    [t0 (c-cpu)]',
         '(let* ([bv (p3-read-bv-file (string-append P3 "/seg4r-state.fasl"))]\n'
         '                    [stamp-bv (p "state-bv-read done... cpu=" (c-cpu))]\n'
         '                    [t0 (c-cpu)]',
         "B state name + bv stamp")

# hooks: inserted right before the provenance pre-snapshot (i.e. before replay)
b = sub1(b, """                    ;; ---- provenance pre-snapshot ----""",
         """                    ;; ---- (c)-class rebuild hooks (P3.2): explicit, BEFORE replay ----
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
                      (let ([r (try (lambda () (rkt-hook-module-cache-clear!)) 'HOOK-ERR)])
                        (o "")
                        (o "==== rebuild hooks (P3.2) ====")
                        (o "  (h1) registry lock-box reset: boxes-reset=" n-lock)
                        (o "  (h2) module-cache-clear!: " (if (eq? r 'HOOK-ERR) r 'ok))
                        (o "  (h3) links-cache: left as-is (filesystem-derived, process-valid)")
                        (o "  (h4) thread-cell seeding: 'thread-tagged ops now replayed (skip-tags=" p3-skip-tags ")")
                        (o "  (h5) counters/custodian: natural / skipped")))
                    ;; ---- provenance pre-snapshot ----""",
         "B hooks insert")

b = sub1(b, """(list 'sort '(list (list 2) (list 1)) '<
                                       (string->keyword "key") 'car)""",
         """(list 'sort '(list (list 2) (list 1)) '<
                                       (rkt-string->keyword "key") 'car)""",
         "B kw probe")

# codeloc branch: cumulative timing + skippable (899/901 are guaranteed misses;
# vfasl code segment removes this entirely in P3.3)
b = sub1(b, """                     [(codeloc)
                      (let ([r (n3-resolve (vector-ref e 1) rootvec)])""",
         """                     [(codeloc)
                      (let* ([tcl0 (c-cpu)]
                             [r (if p32-do-codeloc?
                                    (n3-resolve (vector-ref e 1) rootvec)
                                    (cons 'skipped 'skipped))]
                             [ignore (set! p32-tcl (+ p32-tcl (- (c-cpu) tcl0)))])""",
         "B codeloc timing")

b = sub1(b, """                     [(rmp)
                      (let* ([spec (vector-ref e 1)]""",
         """                     [(rmp)
                      (let* ([trmp0 (c-cpu)]
                             [spec (vector-ref e 1)]""",
         "B rmp timing head")

b = sub1(b, """                        (cond
                          [r (vector-set! extvec i r) (vector-set! resolved i #t)
                             (bump! 'rmp 'ok)]
                          [else (bump! 'rmp 'MISS)]))]""",
         """                        (set! p32-trmp (+ p32-trmp (- (c-cpu) trmp0)))
                        (cond
                          [r (vector-set! extvec i r) (vector-set! resolved i #t)
                             (bump! 'rmp 'ok)]
                          [else (bump! 'rmp 'MISS)]))]""",
         "B rmp timing tail")

b = sub1(b, """             (o "code placeholders wired (dummy code object): " n-dummy))""",
         """             (o "code placeholders wired (dummy code object): " n-dummy))
             (o "resolve sub-timing: codeloc-n3-resolve=" p32-tcl
                " ms  rmp-resolve=" p32-trmp " ms  (do-codeloc?=" p32-do-codeloc? ")")""",
         "B resolve subtiming report")

b = sub1(b, """                          (o "extended diagnostics: ok=" xp " fail=" xf)""",
         """                          (o "extended diagnostics: ok=" xp " fail=" xf)
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
                          (o "")
                          (o "==== CHEZ FORENSICS: post-replay instance census (selected modules) ====")
                          (let ([insts (find-instances (vector-ref rootvec 0))])
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
                             insts))""",
         "B attribution battery")

b = sub1(b, """           (p "all done cpu=" (c-cpu))
           (c-flush lp)))))
   (void)))
(exit)""",
         """           (p "all done cpu=" (c-cpu))
           (c-flush lp)))))
   'p32b-done))""",
         "B tail")

wr(P3 + "/p3.2b.chez.ss", b)
print("generated: p3.2-head.chez.ss p3.2a.chez.ss p3.2b.chez.ss")
