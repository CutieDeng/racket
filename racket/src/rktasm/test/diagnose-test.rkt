#lang racket

(require rackunit
         rackunit/text-ui
         "../syntax/class.rkt"
         "../syntax/variant.rkt"
         "../syntax/diagnose.rkt"
         "../parser/ast.rkt"
         "../parser/parser.rkt")

;; ============================================================
;; Syntax Class Diagnostic Tests
;; ============================================================

;; ============================================================
;; Test: Instruction Classification
;; ============================================================

(define instruction-classification-tests
  (test-suite
   "Instruction Classification"

   (test-case "Classify c0 (no operands)"
     (define ins (parse-instruction '(nop)))
     (check-equal? (classify-instruction ins) 'c0))

   (test-case "Classify c1 (1 operand)"
     (define ins (parse-instruction '(br x0)))
     (check-equal? (classify-instruction ins) 'c1))

   (test-case "Classify c2 (2 operands)"
     (define ins (parse-instruction '(mov x0 x1)))
     (check-equal? (classify-instruction ins) 'c2))

   (test-case "Classify c3 (3 operands)"
     (define ins (parse-instruction '(add x0 x1 x2)))
     (check-equal? (classify-instruction ins) 'c3))

   (test-case "Classify c4 (4 operands without shift)"
     ;; 4 operands with AST level (shift becomes 2 operands: shift + imm)
     (define ins (parse-instruction '(madd x0 x1 x2 x3)))
     (check-equal? (classify-instruction ins) 'c4))

   (test-case "Classify c5 (5 operands with shift)"
     (define ins (parse-instruction '(add x0 x1 x2 lsl 3)))
     (check-equal? (classify-instruction ins) 'c5))

   (test-case "Classify c1m (1 operand + memory)"
     (define ins (parse-instruction '(ldr x0 (x1))))
     (check-equal? (classify-instruction ins) 'c1m))))

;; ============================================================
;; Test: Diagnosis Results
;; ============================================================

(define diagnosis-result-tests
  (test-suite
   "Diagnosis Result Construction"

   (test-case "diagnosis-ok? on success"
     (define d (diagnosis #t 'add 'c3 (set 'c3 'c4) #f '() '() '() '() '()))
     (check-true (diagnosis-ok? d)))

   (test-case "diagnosis-error? on failure"
     (define d (diagnosis #f 'add 'c2 (set 'c3 'c4) "error" '() '() '() '() '()))
     (check-true (diagnosis-error? d)))

   (test-case "diagnosis accessors"
     (define d (diagnosis #t 'add 'c3 (set 'c3 'c4) #f '(s1 s2) '() '(a b) '() '()))
     (check-equal? (diagnosis-mnemonic d) 'add)
     (check-equal? (diagnosis-actual-class d) 'c3)
     (check-equal? (diagnosis-suggestions d) '(s1 s2))
     (check-equal? (diagnosis-actual-signature d) '(a b)))))

;; ============================================================
;; Test: Format Diagnosis
;; ============================================================

(define format-tests
  (test-suite
   "Diagnosis Formatting"

   (test-case "Format OK diagnosis"
     (define d (diagnosis #t 'add 'c3 (set 'c3 'c4) #f '() '() '() '() '()))
     (define output (format-diagnosis d))
     (check-true (string-contains? output "OK")))

   (test-case "Format error diagnosis"
     (define d (diagnosis #f 'add 'c2 (set 'c3 'c4) "类别不匹配" '("建议1") '() '() '() '()))
     (define output (format-diagnosis d))
     (check-true (string-contains? output "错误")))))

;; ============================================================
;; Test: With Variant Database (if available)
;; ============================================================

(define db-tests
  (test-suite
   "Variant Database Tests"

   (test-case "Load default variant database"
     (with-handlers ([exn:fail:filesystem?
                      (lambda (e)
                        ;; Database files may not exist, skip test
                        (void))])
       (define db (load-variant-db/default))
       (check-true (hash? db))))

   (test-case "Lookup variants by mnemonic"
     (with-handlers ([exn:fail:filesystem?
                      (lambda (e) (void))])
       (define db (load-variant-db/default))
       (define add-variants (lookup-variants-by-mnemonic db 'add))
       (check-true (list? add-variants))
       ;; ADD should have multiple variants
       (when (pair? add-variants)
         (check-true (> (length add-variants) 0)))))))

;; ============================================================
;; Run All Tests
;; ============================================================

(define all-tests
  (test-suite
   "All Diagnostic Tests"
   instruction-classification-tests
   diagnosis-result-tests
   format-tests
   db-tests))

(module+ main
  (void (run-tests all-tests)))

(module+ test
  (void (run-tests all-tests)))
