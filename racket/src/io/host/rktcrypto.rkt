#lang racket/base
(require racket/include
         (only-in '#%linklet primitive-table))

;; Names are provided by macros below, driven by "rktcrypto.rktl";
;; the callable values come from the host's `#%rktcrypto` primitive
;; table. Unlike rktio, rktcrypto functions are stateless and
;; thread-safe, so no lock discipline is needed around calls.

(define rktcrypto-table
  (or (primitive-table '#%rktcrypto)
      (error '#%rktcrypto "rktcrypto not supported by host")))

(define (lookup n)
  (hash-ref rktcrypto-table n))

(define-syntax-rule (define-constant n v)
  (begin
    (define n v)
    (provide n)))

(define-syntax-rule (define-type . _) (void))
(define-syntax-rule (define-struct-type . _) (void))

(define-syntax-rule (define-function _ _ name . _)
  (begin
    (define name (lookup 'name))
    (provide name)))

(define-syntax-rule (define-function/errno _ _ _ name . _)
  (define-function () #f name))
(define-syntax-rule (define-function/errno+step _ _ _ name . _)
  (define-function () #f name))
(define-syntax-rule (define-function/result_t _ _ _ name . _)
  (define-function () #f name))
(define-syntax-rule (define-function/alloc_result_t _ _ _ name . _)
  (define-function () #f name))

(include "../../crypto/rktcrypto.rktl")
