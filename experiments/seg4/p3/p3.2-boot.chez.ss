;; ===== P3.2 Chez bootstrap: build a CLEAN evaluation environment =====
;; Loaded (via Chez `load`) into the vm-eval interaction environment, which in a
;; real racket process is polluted by expander/env.ss imports (rumble/thread/io/
;; regexp/linklet shadow many scheme names with Racket variants).  Everything
;; here uses #%-primitive references only, so it works regardless of shadowing.
;;
;; Provides (in the interaction environment):
;;   p32-env        a mutable copy of the clean scheme environment
;;   p32-load-into  load a .ss file into p32-env (Chez reader, so #%$ works)
;;   p32-in         eval a datum in p32-env

(define p32-env (#%copy-environment (#%scheme-environment) #t))

;; make the clean environment able to name itself (for nested eval/import)
(#%eval (#%list 'define 'p32-here (#%list 'quote p32-env)) p32-env)

(define p32-load-into
  (lambda (path)
    (let ([ip (#%open-input-file path)])
      (let loop ()
        (let ([x (#%read ip)])
          (if (#%eof-object? x)
              (#%close-input-port ip)
              (begin (#%eval x p32-env) (loop)))))
      'loaded)))

(define p32-in (lambda (x) (#%eval x p32-env)))
