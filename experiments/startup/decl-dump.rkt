#lang racket/base
(require ffi/unsafe/vm '#%linklet racket/path)
(define mode (vector-ref (current-command-line-arguments) 0))
(define out (vector-ref (current-command-line-arguments) 1))
(define src "/Users/cutiedeng/Library/Racket/9.3.10/pkgs/rackunit-lib/rackunit/private/base.rkt")
(define Z "/Users/cutiedeng/Library/Racket/9.3.10/pkgs/rackunit-lib/rackunit/private/compiled/base_rkt.zo")
(define code-of (vm-eval '(lambda (lk) ((record-accessor (record-rtd lk) 0) lk))))
(define sf (vm-eval '(lambda (s) (let ([rtd (record-rtd s)]) (list ((record-accessor rtd 0) s) ((record-accessor rtd 1) s) ((record-accessor rtd 2) s))))))
(define (decl-of c) (hash-ref (linklet-bundle->hash (hash-ref (linklet-directory->hash c) #f)) 'decl))
(define bytes-out
  (case mode
    [("installed")
     (define c (parameterize ([read-accept-compiled #t]) (call-with-input-file Z read)))
     (define f (sf (code-of (decl-of c))))
     (subbytes (car f) (cadr f) (+ (cadr f) (caddr f)))]
    [("inproc" "env")   ; "env": run with PLT_LINKLET_VFASL=1 so the writer converts; "inproc": convert here
     (define ns (make-base-namespace))
     (define code (parameterize ([current-namespace ns] [read-accept-reader #t] [current-load-relative-directory (path-only src)])
                    (compile (call-with-input-file src (lambda (p) (port-count-lines! p) (read-syntax src p))))))
     (define bstr (let ([o (open-output-bytes)]) (parameterize ([current-write-relative-directory (path-only src)]) (write code o)) (get-output-bytes o)))
     (define c (parameterize ([read-accept-compiled #t]) (read (open-input-bytes bstr))))
     (define-values (fmt bv lits) ((vm-eval 'linklet-fasled-code+arguments) (decl-of c)))
     (if (equal? mode "inproc") ((vm-eval '(lambda (bv) (($primitive $vfasl-convert-bytevector) bv))) bv) bv)]))
(call-with-output-file out #:exists 'replace (lambda (o) (write-bytes bytes-out o)))
(printf "~a: ~a bytes, kind ~a\n" mode (bytes-length bytes-out) (bytes-ref bytes-out 0))
