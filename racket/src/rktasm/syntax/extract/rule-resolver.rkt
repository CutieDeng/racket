#lang racket

(provide resolve-rule
         resolve-assembly
         resolved-token
         resolved-choice
         resolved-token?
         resolved-choice?
         resolved-token-id
         resolved-token-pattern
         resolved-choice-alternatives)

;; ============================================================
;; Rule Chain Resolver
;; ============================================================

;; Resolved tokens represent terminal symbols
(struct resolved-token (id pattern) #:transparent)

;; Resolved choices represent alternation
(struct resolved-choice (alternatives) #:transparent)

;; Resolve a rule by its ID from the assembly_rules hash
;; Returns either:
;;   - resolved-token for terminals
;;   - resolved-choice for choice nodes
;;   - list of resolved elements for sequences
(define (resolve-rule rules rule-id)
  ;; rule-id can be a string or symbol; normalize to symbol for lookup
  (define key (if (string? rule-id) (string->symbol rule-id) rule-id))
  (define rule (hash-ref rules key
                         (lambda () (error 'resolve-rule "unknown rule: ~a" rule-id))))
  (resolve-rule-node rules key rule))

;; Resolve a rule node based on its _type
(define (resolve-rule-node rules rule-id rule)
  (match (hash-ref rule '_type #f)
    ["Instruction.Rules.Token"
     ;; Terminal token with a pattern
     (resolved-token rule-id (hash-ref rule 'pattern ""))]

    ["Instruction.Rules.Rule"
     ;; Sequence rule - resolve all symbols
     (define symbols (hash-ref rule 'symbols #f))
     (define symbol-list (get-symbol-list symbols))
     (if symbol-list
         (flatten (map (lambda (sym) (resolve-symbol rules sym)) symbol-list))
         (list))]

    ["Instruction.Rules.Choice"
     ;; Choice rule - multiple alternatives
     (match (hash-ref rule 'choices #f)
       [#f (resolved-choice '())]
       [(? list? choices)
        (resolved-choice (map (lambda (c) (resolve-assembly rules c)) choices))]
       [other
        (error 'resolve-rule-node "invalid choices format: ~a" other)])]

    [other
     (error 'resolve-rule-node "unknown rule type for ~a: ~a" rule-id other)]))

;; Extract symbol list from symbols field (can be list or hash with 'symbols key)
(define (get-symbol-list symbols)
  (cond
    [(list? symbols) symbols]
    [(and (hash? symbols) (hash-ref symbols 'symbols #f)) => identity]
    [else #f]))

;; Resolve a symbol reference within a rule
(define (resolve-symbol rules sym)
  (match (hash-ref sym '_type #f)
    ["Instruction.Symbols.Literal"
     ;; Literal text - create inline token
     (list (resolved-token #f (hash-ref sym 'value "")))]

    ["Instruction.Symbols.RuleReference"
     ;; Reference to another rule
     (match (hash-ref sym 'rule_id #f)
       [#f (error 'resolve-symbol "RuleReference missing rule_id")]
       [rule-id (list (resolve-rule rules rule-id))])]

    ["Instruction.Symbols.Whitespace"
     ;; Whitespace - usually ignored in parsing
     (list)]

    ["Instruction.Symbols.Optional"
     ;; Optional sequence
     (define symbols (hash-ref sym 'symbols #f))
     (define symbol-list (get-symbol-list symbols))
     (if symbol-list
         (list (resolved-choice
                (list (flatten (map (lambda (s) (resolve-symbol rules s)) symbol-list))
                      '())))
         (list))]

    [other
     (error 'resolve-symbol "unknown symbol type: ~a" other)]))

;; Resolve an assembly structure (from instruction or choice)
(define (resolve-assembly rules assembly)
  (if (not (hash? assembly))
      '()  ; Handle null or invalid assembly
      (let* ([symbols (hash-ref assembly 'symbols #f)]
             [symbol-list (get-symbol-list symbols)])
        (if symbol-list
            (flatten (map (lambda (sym) (resolve-symbol rules sym)) symbol-list))
            '()))))
