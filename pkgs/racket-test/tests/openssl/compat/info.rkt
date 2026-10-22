#lang info

;; Failing tests that document known defects of the rktcrypto-based
;; openssl collection; see "README.md". Excluded from `raco test` until
;; each is fixed and moved up to "tests/openssl/".
(define test-omit-paths (quote all))
