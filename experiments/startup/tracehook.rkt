#lang racket/base
;; tracehook.rkt -- install in the real REPL in its real order: racket -i -t <this>
;; (`-t` before `-i` would clear the init library). Logs every module load and every top-level eval
;; with wall/cpu/gc/alloc stamps to $TH_OUT (default /tmp/th.log).
(define out (open-output-file (or (getenv "TH_OUT") "/tmp/th.log") #:exists 'replace))
(define t0 (current-inexact-monotonic-milliseconds))
(define (stamp tag info)
  (fprintf out "~a ~a ~a ~a ~a ~a\n" tag (- (current-inexact-monotonic-milliseconds) t0)
           (current-process-milliseconds) (current-gc-milliseconds) (current-memory-use 'cumulative) info)
  (flush-output out))
(define depth 0)
(define old-load (current-load/use-compiled))
(current-load/use-compiled
 (lambda (path expected)
   (define name (current-module-declare-name))
   (set! depth (add1 depth))
   (stamp "L>" (format "~a ~a" depth (if name (resolved-module-path-name name) path)))
   (begin0 (old-load path expected)
     (stamp "L<" (format "~a ~a" depth (if name (resolved-module-path-name name) path)))
     (set! depth (sub1 depth)))))
(define old-eval (current-eval))
(current-eval
 (lambda (form)
   (cond
     [(or (> depth 0) (compiled-expression? (if (syntax? form) (syntax-e form) form))) (old-eval form)]
     [else
      (define head (let ([d (if (syntax? form) (syntax->datum form) form)]) (if (pair? d) (car d) d)))
      (stamp "E>" head)
      (begin0 (old-eval form) (stamp "E<" head))])))
(stamp "HOOK" (format "installed mono=~a" (current-inexact-monotonic-milliseconds)))
