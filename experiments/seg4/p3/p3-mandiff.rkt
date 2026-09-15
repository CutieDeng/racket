;; ===== manifest comparator: characterize A-run nondeterminism =====
;; Usage: M1=<man1> M2=<man2> racket -q -n -t p3-mandiff.rkt
(module p3-mandiff '#%kernel
  (#%require '#%linklet)
  (define-values (SP)
    "/private/tmp/claude-501/-Users-cutiedeng-Y2026-M07-D16-racket-feat-swisstable/d5d1ca89-29ba-48e9-9226-2d4a258a56cd/scratchpad")
  (define-values (P3) (string-append SP "/p3"))
  (define-values (chez-eval) (primitive-lookup 'eval))
  (define-values (sysw) (primitive-lookup 'call-with-system-wind))
  (define-values (ceval) (lambda (s) (sysw (lambda () (chez-eval s)))))
  (define-values (getenv*)
    (lambda (k) (environment-variables-ref (current-environment-variables) k)))
  (define-values (m1) (bytes->string/utf-8 (getenv* #"M1")))
  (define-values (m2) (bytes->string/utf-8 (getenv* #"M2")))
  (ceval (list 'load (string-append P3 "/p3.2-boot.chez.ss")))
  (ceval (list 'begin
               (list 'p32-load-into (string-append P3 "/p3.2-head.chez.ss"))
               (list 'p32-load-into (string-append SP "/p1.engine.ss"))
               (list 'p32-load-into (string-append SP "/p2.writeset.ss"))
               (list 'p32-load-into (string-append P3 "/p3.naming.ss"))
               (list 'p32-load-into (string-append P3 "/p3-mandiff.chez.ss"))))
  (ceval (list 'p32-in (list 'quote (list 'mandiff-run! m1 m2)))))
