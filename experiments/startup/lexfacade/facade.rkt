#lang racket/base
;; prototype: contract-out facade over a plain-variable core (racket-lexer/status)
(require racket/contract/base
         syntax-color/lexer-contract
         (only-in syntax-color/racket-lexer racket-lexer/status))
(define (racket-lexer in)
  (let-values ([(lexeme type paren start end adj) (racket-lexer/status in)])
    (values lexeme type paren start end)))
(provide (contract-out [racket-lexer lexer/c]))
