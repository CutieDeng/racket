#lang racket/base
(require "../host/linklet.rkt")

(provide version-bytes
         vm-bytes
         version-bytes-compatible?
         version-string-compatible?)

(define version-bytes (string->bytes/utf-8 (version)))
(define vm-bytes (linklet-virtual-machine-bytes))

;; This runtime is an X.Y.Z fork release of the upstream X.Y series, and
;; its bytecode is interchangeable with the series: accept code stamped
;; with the exact version, the plain X.Y series version (upstream release
;; builds, e.g. built package catalogs), or another X.Y.* release.
(define series-bytes
  (let* ([bstr version-bytes]
         [len (bytes-length bstr)]
         [dot (char->integer #\.)])
    (let loop ([i 0] [dots 0])
      (cond
        [(= i len) bstr]
        [(eqv? (bytes-ref bstr i) dot)
         (if (= dots 1)
             (subbytes bstr 0 i)
             (loop (add1 i) (add1 dots)))]
        [else (loop (add1 i) dots)]))))

(define (version-bytes-compatible? vers)
  (or (equal? vers version-bytes)
      (equal? vers series-bytes)
      (let ([slen (bytes-length series-bytes)])
        (and (> (bytes-length vers) slen)
             (eqv? (bytes-ref vers slen) (char->integer #\.))
             (equal? (subbytes vers 0 slen) series-bytes)))))

(define (version-string-compatible? vers)
  (and (string? vers)
       (version-bytes-compatible? (string->bytes/utf-8 vers))))
