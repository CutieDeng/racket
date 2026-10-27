#lang racket/base
;; resolver-hook.rkt -- install before racket/init: racket -I racket/base -t <this> -l racket/init -i
;; Wraps current-module-name-resolver and the load handler; at exit prints per-shape call counts,
;; self ms (load-handler and nested resolver time subtracted) and total ms to stderr.
(define old (current-module-name-resolver))
(define stats (make-hash))
(define (shape mp load?)
  (define s
    (cond [(symbol? mp) 'symbol] [(string? mp) 'string] [(path? mp) 'path]
          [(and (pair? mp) (eq? (car mp) 'submod))
           (if (equal? (cadr mp) "..") 'submod-up (if (equal? (cadr mp) ".") 'submod-self 'submod))]
          [(and (pair? mp) (eq? (car mp) 'lib)) 'lib] [(and (pair? mp) (eq? (car mp) 'file)) 'file]
          [(and (pair? mp) (eq? (car mp) 'quote)) 'quote] [(module-path-index? mp) 'mpi]
          [(resolved-module-path? mp) 'resolved] [else 'other]))
  (string->symbol (format "~a~a" s (if load? "/load" ""))))
(define (now) (current-inexact-monotonic-milliseconds))
(define nested 0.0)
(define old-load (current-load/use-compiled))
(define load-ms 0.0) (define load-n 0)
(current-load/use-compiled
 (lambda (path expected)
   (define t0 (now))
   (begin0 (old-load path expected)
     (let ([dt (- (now) t0)])
       (set! load-ms (+ load-ms dt)) (set! load-n (add1 load-n)) (set! nested (+ nested dt))))))
(current-module-name-resolver
 (case-lambda
   [(r ns) (old r ns)]
   [(mp rel stx load?)
    (define t0 (now)) (define saved nested) (set! nested 0.0)
    (begin0 (old mp rel stx load?)
      (let* ([total (- (now) t0)] [self (- total nested)]
             [v (hash-ref! stats (shape mp load?) (lambda () (vector 0 0.0 0.0)))])
        (vector-set! v 0 (add1 (vector-ref v 0)))
        (vector-set! v 1 (+ (vector-ref v 1) self))
        (vector-set! v 2 (+ (vector-ref v 2) total))
        (set! nested (+ saved total))))]))
(plumber-add-flush! (current-plumber)
  (lambda (h)
    (define p (current-error-port))
    (fprintf p "RESOLVER-STATS begin\n")
    (for ([(k v) stats])
      (fprintf p "~a ~a ~a ~a\n" k (vector-ref v 0) (real->decimal-string (vector-ref v 1) 2) (real->decimal-string (vector-ref v 2) 2)))
    (fprintf p "LOADS ~a ~a\n" load-n (real->decimal-string load-ms 2))
    (fprintf p "RESOLVER-STATS end\n")
    (flush-output p)))
