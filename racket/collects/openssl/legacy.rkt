#lang racket/base

;; Compatibility module path. Historically this loaded OpenSSL's legacy
;; EVP provider as a side effect; this Racket's crypto runs on the
;; in-tree rktcrypto engine with no OpenSSL to configure, so requiring
;; this module is now a no-op.
