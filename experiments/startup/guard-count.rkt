#lang racket/base
;; guard-count.rkt -- install before racket/init:
;;   racket -I racket/base -t <this> -l racket/init -l racket/interactive -e '(void)'
;; Counts filesystem accesses seen by the security guard, by (who . mode), and
;; lists directory-existence probes grouped by parent directory.
(define counts (make-hash))
(define dir-probes (make-hash))
(define path-probes (make-hash))
(define t-total 0.0)
(current-security-guard
 (make-security-guard
  (current-security-guard)
  (lambda (who path modes)
    (hash-update! counts (cons who modes) add1 0)
    (when (and path (memq 'exists modes))
      (define-values (base name dir?) (split-path path))
      (hash-update! dir-probes (if (path? base) (path->string base) base) add1 0)
      (hash-update! path-probes (path->string path) add1 0)))
  (lambda (who host port mode) (void))))
(plumber-add-flush! (current-plumber)
  (lambda (h)
    (define p (current-error-port))
    (fprintf p "GUARD-STATS begin\n")
    (for ([(k v) (in-hash counts)] #:when (> v 20))
      (fprintf p "~a ~a ~a\n" (car k) (cdr k) v))
    (fprintf p "-- exists probes by parent dir (top 12)\n")
    (for ([kv (in-list (let ([l (hash->list dir-probes)]) (take-sorted l 12)))])
      (fprintf p "~a ~a\n" (cdr kv) (car kv)))
    (fprintf p "-- repeated identical exists probes (count>=3, top 12)\n")
    (for ([kv (in-list (take-sorted (filter (lambda (kv) (>= (cdr kv) 3)) (hash->list path-probes)) 12))])
      (fprintf p "~a ~a\n" (cdr kv) (car kv)))
    (fprintf p "GUARD-STATS end\n")
    (flush-output p)))
(define (take-sorted l n)
  (let loop ([l (sort l > #:key cdr)] [n n])
    (if (or (null? l) (zero? n)) '() (cons (car l) (loop (cdr l) (sub1 n))))))
