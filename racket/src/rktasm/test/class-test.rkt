#lang racket

(require rackunit
         rackunit/text-ui
         "../syntax/class.rkt")

;; ============================================================
;; syntax/class.rkt 单元测试
;; ============================================================

(define class-tests
  (test-suite
   "Class 单元测试"

   ;; --------------------------------------------------------
   ;; syntax-class?
   ;; --------------------------------------------------------
   (test-suite
    "syntax-class?"

    (test-case "基本类 cN"
      (check-true (syntax-class? 'c0))
      (check-true (syntax-class? 'c1))
      (check-true (syntax-class? 'c2))
      (check-true (syntax-class? 'c3))
      (check-true (syntax-class? 'c5))
      (check-true (syntax-class? 'c10)))

    (test-case "带内存类 cNm"
      (check-true (syntax-class? 'c1m))
      (check-true (syntax-class? 'c2m))
      (check-true (syntax-class? 'c0m)))

    (test-case "带后索引类 cNmK"
      (check-true (syntax-class? 'c1m1))
      (check-true (syntax-class? 'c2m1))
      (check-true (syntax-class? 'c1m2)))

    (test-case "花括号内存类 cmNm"
      (check-true (syntax-class? 'cm1m))
      (check-true (syntax-class? 'cm2m)))

    (test-case "无效类"
      (check-false (syntax-class? 'add))
      (check-false (syntax-class? 'x0))
      (check-false (syntax-class? 42))
      (check-false (syntax-class? "c3"))))

   ;; --------------------------------------------------------
   ;; parse-syntax-class
   ;; --------------------------------------------------------
   (test-suite
    "parse-syntax-class"

    (test-case "有效类解析"
      (check-equal? (parse-syntax-class 'c3) 'c3)
      (check-equal? (parse-syntax-class "c1m") 'c1m)
      (check-equal? (parse-syntax-class 'c2m1) 'c2m1))

    (test-case "无效类返回 #f"
      (check-false (parse-syntax-class 'invalid))
      (check-false (parse-syntax-class "xyz"))))

   ;; --------------------------------------------------------
   ;; classify-operand-count
   ;; --------------------------------------------------------
   (test-suite
    "classify-operand-count"

    (test-case "无内存"
      (check-equal? (classify-operand-count 0 #f) 'c0)
      (check-equal? (classify-operand-count 1 #f) 'c1)
      (check-equal? (classify-operand-count 3 #f) 'c3)
      (check-equal? (classify-operand-count 5 #f) 'c5))

    (test-case "有内存，无后索引"
      (check-equal? (classify-operand-count 1 #t) 'c1m)
      (check-equal? (classify-operand-count 2 #t) 'c2m)
      (check-equal? (classify-operand-count 0 #t) 'c0m))

    (test-case "有内存，有后索引"
      (check-equal? (classify-operand-count 1 #t 1) 'c1m1)
      (check-equal? (classify-operand-count 2 #t 1) 'c2m1)
      (check-equal? (classify-operand-count 1 #t 2) 'c1m2)))

   ;; --------------------------------------------------------
   ;; has-memory?
   ;; --------------------------------------------------------
   (test-suite
    "has-memory?"

    (test-case "无内存类"
      (check-false (has-memory? 'c0))
      (check-false (has-memory? 'c3))
      (check-false (has-memory? 'c5)))

    (test-case "有内存类"
      (check-true (has-memory? 'c1m))
      (check-true (has-memory? 'c2m))
      (check-true (has-memory? 'c1m1))
      (check-true (has-memory? 'c2m1))))

   ;; --------------------------------------------------------
   ;; has-post-index?
   ;; --------------------------------------------------------
   (test-suite
    "has-post-index?"

    (test-case "无后索引"
      (check-false (has-post-index? 'c0))
      (check-false (has-post-index? 'c3))
      (check-false (has-post-index? 'c1m)))

    (test-case "有后索引"
      (check-true (has-post-index? 'c1m1))
      (check-true (has-post-index? 'c2m1))
      (check-true (has-post-index? 'c1m2))))

   ;; --------------------------------------------------------
   ;; get-pre-count / get-post-count
   ;; --------------------------------------------------------
   (test-suite
    "get-pre-count / get-post-count"

    (test-case "get-pre-count"
      (check-equal? (get-pre-count 'c0) 0)
      (check-equal? (get-pre-count 'c1) 1)
      (check-equal? (get-pre-count 'c3) 3)
      (check-equal? (get-pre-count 'c1m) 1)
      (check-equal? (get-pre-count 'c2m1) 2))

    (test-case "get-post-count"
      (check-equal? (get-post-count 'c0) 0)
      (check-equal? (get-post-count 'c3) 0)
      (check-equal? (get-post-count 'c1m) 0)
      (check-equal? (get-post-count 'c1m1) 1)
      (check-equal? (get-post-count 'c2m1) 1)
      (check-equal? (get-post-count 'c1m2) 2)))

   ;; --------------------------------------------------------
   ;; syntax-class->string
   ;; --------------------------------------------------------
   (test-suite
    "syntax-class->string"

    (test-case "转换"
      (check-equal? (syntax-class->string 'c3) "c3")
      (check-equal? (syntax-class->string 'c1m) "c1m")
      (check-equal? (syntax-class->string 'c2m1) "c2m1")))))

;; ============================================================
;; 执行
;; ============================================================

(module+ main
  (void (run-tests class-tests)))

(module+ test
  (void (run-tests class-tests)))
