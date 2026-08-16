#lang racket/base

;; Compatibility shim. This Racket's crypto and TLS run on the in-tree
;; rktcrypto engine and never load OpenSSL, but upstream packages still
;; `(require openssl/libcrypto)` to probe for an OpenSSL libcrypto (for
;; example web-server-lib's HMAC stuffer and crypto-lib), and the
;; historical API always allowed the probe to come back empty. Keep the
;; historical exports with their "not available" values so those
;; packages load and take their own fallback paths.

(provide libcrypto
         libcrypto-load-fail-reason
         openssl-lib-versions)

(define libcrypto #f)
(define libcrypto-load-fail-reason
  "OpenSSL is not used by this Racket: crypto and TLS run on the in-tree rktcrypto engine")
(define openssl-lib-versions '())
