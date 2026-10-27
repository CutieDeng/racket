#lang racket/base
(require ffi/unsafe/vm '#%linklet)
(define mode (string->symbol (vector-ref (current-command-line-arguments) 0)))
(define Z "/Users/cutiedeng/Library/Racket/9.3.10/pkgs/rackunit-lib/rackunit/private/compiled/base_rkt.zo")
(define c (parameterize ([read-accept-compiled #t]) (call-with-input-file Z read)))
(define b (linklet-bundle->hash (hash-ref (linklet-directory->hash c) #f)))
(define code-of (vm-eval '(lambda (lk) ((record-accessor (record-rtd lk) 0) lk))))
(define sf (vm-eval '(lambda (s) (let ([rtd (record-rtd s)]) (list ((record-accessor rtd 0) s) ((record-accessor rtd 1) s) ((record-accessor rtd 2) s))))))
(define lk (hash-ref b 'decl))
(define f (sf (code-of lk)))
(define area (car f)) (define start (cadr f)) (define len (caddr f))
(define-values (fmt cbv lits) ((vm-eval 'linklet-fasled-code+arguments) lk))
(printf "decl slice: start ~a (mod 16 = ~a) len ~a area ~a B; header bytes ~s; lits ~a\n" start (modulo start 16) len (bytes-length area) (subbytes area start (+ start 8)) (vector-length lits))
(flush-output)
(define rd (vm-eval '(lambda (bv start lits) (let ([p (open-bytevector-input-port bv)]) (set-port-position! p start) (fasl-read p 'load lits) (port-position p)))))
(define (go label bv st)
  (printf "~a: " label) (flush-output)
  (define pos (rd bv st lits))
  (printf "ok, pos after = ~a (= start+~a, slice end ~a)\n" pos (- pos st) (+ st len)))
(case mode
  [(inplace) (go "in place" area start)]
  [(copy0) (go "copy at offset 0" (subbytes area start (+ start len)) 0)]
  [(copyzeros) (go "copy at same offset, zeros before" (bytes-append (make-bytes start 0) (subbytes area start (+ start len)) (make-bytes 64 0)) start)]
  [(copyreal) (go "copy at same offset, real bytes before, zeros after" (bytes-append (subbytes area 0 (+ start len)) (make-bytes 64 0)) start)]
  [(copy16) (go "copy at offset 16" (bytes-append (make-bytes 16 0) (subbytes area start (+ start len))) 16)]
  [(copyoddsame) (go "copy at offset (start mod 4096)" (bytes-append (make-bytes (modulo start 4096) 0) (subbytes area start (+ start len))) (modulo start 4096))])
