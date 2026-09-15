;; ===== P7.3 code-fasl roundtrip battery =====
;; Validates the native code channel: fasl.ss wrf-code/bld-code (live code
;; objects into fasl_type_code wire format) + prim5.c s_fasl_code_info.
;; Run: <worktree>/racket/bin/racket -q -n -t p73-code-roundtrip.rkt
;; Expect: every pair in P73 RESULT has cdr 'ok.
;; The test form is evaluated in a fresh (scheme-environment), where the
;; $-primitives and foreign-procedure are bound as plain names (the #%
;; reader shorthand is Chez-reader-only and unusable in a racket-read
;; datum -- see the project discipline notes).
(module p73-code-roundtrip '#%kernel
  (#%require '#%linklet)
  (define-values (chez-eval) (primitive-lookup 'eval))
  (define-values (chez-senv) (primitive-lookup 'scheme-environment))
  (define-values (sysw) (primitive-lookup 'call-with-system-wind))
  (define-values (ceval) (lambda (s) (sysw (lambda () (chez-eval s (chez-senv))))))
  (define-values (say)
    (lambda args
      (for-each (lambda (x) (display x)) args)
      (newline)
      (flush-output (current-output-port))))
  (define-values (r)
    (ceval
     '(let ([SE (scheme-environment)]
            [res '()])
        (let ([rt (lambda (v)
                    (call-with-values
                      (lambda () (open-bytevector-output-port))
                      (lambda (op get)
                        (fasl-write v op)
                        (fasl-read (open-bytevector-input-port (get))))))]
              [chk (lambda (name ok)
                     (set! res (cons (cons name
                                           (if (eq? ok #t) 'ok
                                               (if ok ok 'FAIL)))
                                     res)))])
          ;; t1: 1-free-variable closure; code holds symbol/string literals
          (let ([f ((eval '(lambda (y) (lambda (x) (vector 'tagged (+ x y) "lit"))) SE) 25)])
            (let ([f2 (rt f)])
              (chk 't1-behavior (equal? (f2 5) (f 5)))
              (chk 't1-distinct (not (eq? f2 f)))
              (let ([c (($primitive $closure-code) f)] [c2 (($primitive $closure-code) f2)])
                (chk 't1-code-fields
                     (if (not (eq? c c2))
                         (if (equal? (($primitive $code-name) c) (($primitive $code-name) c2))
                             (if (eqv? (($primitive $code-arity-mask) c) (($primitive $code-arity-mask) c2))
                                 (eqv? (($primitive $code-free-count) c) (($primitive $code-free-count) c2))
                                 #f)
                             #f)
                         #f)))))
          ;; t2: 0-free-variable closure
          (let ([g (eval '(lambda (x) (* x 3)) SE)])
            (let ([g2 (rt g)])
              (chk 't2-behavior (eqv? (g2 14) 42))))
          ;; t3: mutual recursion -- two codes cross-linked through closures
          (let ([h (eval '(letrec ([o? (lambda (n) (if (= n 0) #f (e? (- n 1))))]
                                   [e? (lambda (n) (if (= n 0) #t (o? (- n 1))))])
                            (lambda (n) (o? n)))
                         SE)])
            (let ([h2 (rt h)])
              (chk 't3-behavior (if (eq? (h2 7) #t) (eq? (h2 8) #f) #f))))
          ;; t4: 0-fv closure that uses ITSELF AS A VALUE (the stxparam
          ;; shape) -- the compiler embeds the closure as its code's
          ;; reloc self-literal (plain self-CALLS compile to direct code
          ;; references instead, no literal; measured).  The read side
          ;; must unify the cell closure with the reloc literal: the
          ;; behavior check (sf2 sf2)='self holds iff they are eq
          (let ([sf (eval '(letrec ([f (lambda (n)
                                         (if (eq? n f) 'self
                                             (if (= n 0) 'done (f (- n 1)))))])
                             f)
                          SE)])
            (let ([sf2 (rt sf)])
              (chk 't4-premise
                   (let loop ([l ((eval '(foreign-procedure "(cs)s_get_reloc" (ptr boolean) ptr) SE)
                                  (($primitive $closure-code) sf) #f)])
                     (if (null? l) #f (if (eq? (car l) sf) #t (loop (cdr l))))))
              (chk 't4-behavior (eq? (sf2 3) 'done))
              (chk 't4-unified-behavior (eq? (sf2 sf2) 'self))
              (let ([fp (eval '(foreign-procedure "(cs)s_get_reloc" (ptr boolean) ptr) SE)])
                (chk 't4-self-literal
                     (let loop ([l (fp (($primitive $closure-code) sf2) #f)])
                       (if (null? l)
                           #f
                           (if (eq? (car l) sf2) #t (loop (cdr l)))))))))
          ;; t5: raw code object roundtrip (not via a closure)
          (let ([c (($primitive $closure-code) (eval '(lambda (x) (cons x 'k)) SE))])
            (let ([c2 (rt c)])
              (chk 't5-fields
                   (if (($primitive $code?) c2)
                       (if (not (eq? c c2))
                           (eqv? (($primitive $code-arity-mask) c) (($primitive $code-arity-mask) c2))
                           #f)
                       #f))))
          (reverse res)))))
  (say "P73 RESULT: " r))
