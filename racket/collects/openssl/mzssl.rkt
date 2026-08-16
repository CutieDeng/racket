#lang racket/base

;; Compatibility module path. The historical libssl-based implementation
;; module lived here and upstream packages (for example net-lib) still
;; (require openssl/mzssl); the rktcrypto-based implementation keeps the
;; same export surface, so forward to it.

(require "private/rktcrypto-mzssl.rkt")
(provide (all-from-out "private/rktcrypto-mzssl.rkt"))
