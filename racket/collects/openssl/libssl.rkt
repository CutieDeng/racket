#lang racket/base

;; Compatibility shim. This Racket's crypto and TLS run on the in-tree
;; rktcrypto engine and never load OpenSSL, but upstream packages still
;; `(require openssl/libssl)` to probe for an OpenSSL libssl, and the
;; historical API always allowed the probe to come back empty. Keep the
;; historical exports with their "not available" values so those
;; packages load and take their own fallback paths.

(provide libssl
         libssl-load-fail-reason)

(define libssl #f)
(define libssl-load-fail-reason
  "OpenSSL is not used by this Racket: crypto and TLS run on the in-tree rktcrypto engine")
