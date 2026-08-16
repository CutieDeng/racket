#lang racket

(require json)

(provide read-instructions-json
         get-assembly-rules
         get-instructions
         get-a64-instruction-set)

;; ============================================================
;; JSON Loader for AARCHMRS Instructions.json
;; ============================================================

;; Read the full Instructions.json file
(define (read-instructions-json path)
  (call-with-input-file path read-json))

;; Extract assembly_rules hash table
(define (get-assembly-rules json-data)
  (hash-ref json-data 'assembly_rules
            (lambda () (error 'get-assembly-rules "missing 'assembly_rules' key"))))

;; Extract instructions array
(define (get-instructions json-data)
  (hash-ref json-data 'instructions
            (lambda () (error 'get-instructions "missing 'instructions' key"))))

;; Extract the A64 instruction set (first element of instructions array)
(define (get-a64-instruction-set json-data)
  (match (get-instructions json-data)
    [(list a64 _ ...) a64]
    ['() (error 'get-a64-instruction-set "empty instructions array")]))
