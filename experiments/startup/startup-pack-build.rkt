#lang racket/base
;; startup-pack-build.rkt -- command-line front end for the startup pack
;; builder that lives in the installation (setup/private/startup-pack).
;; The format and the closure computation are owned there; this file only
;; exposes them for experiments.
;;
;;   racket startup-pack-build.rkt <out.pack> <root-module> ...
;;   racket startup-pack-build.rkt --verify <out.pack>
(require setup/private/startup-pack)

(module+ main
  (define args (vector->list (current-command-line-arguments)))
  (cond
    [(and (pair? args) (equal? (car args) "--verify"))
     (printf "verify: ~a mismatches\n" (verify-startup-pack (cadr args)))]
    [(and (pair? args) (pair? (cdr args)))
     (define-values (n skipped)
       (build-startup-pack (car args) (map string->symbol (cdr args))))
     (printf "wrote ~a: ~a members~a\n" (car args) n
             (if (null? skipped) "" (format ", skipped roots ~s" skipped)))]
    [else (error 'startup-pack "usage: <out.pack> <root> ... | --verify <pack>")]))
