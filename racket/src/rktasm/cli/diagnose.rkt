#!/usr/bin/env racket
#lang racket

;; ============================================================
;; diagnose.rkt
;; 交互式指令语法诊断工具
;; ============================================================

(require "../syntax/extract/syntax-variant.rkt"
         "../syntax/diagnose.rkt"
         "../syntax/variant.rkt"
         "../parser/parser.rkt"
         "../syntax/main.rkt")

(provide diagnose-sexp
         run-interactive)

;; 默认路径
(define default-json-path
  "AARCHMRS_OPENSOURCE_A_profile_FAT-2025-12/Instructions.json")

;; ============================================================
;; 诊断接口 (使用运行时数据库)
;; ============================================================

(define (diagnose-sexp sexp db)
  (define ins (parse-instruction sexp))
  (define diag (diagnose-instruction ins db))

  (define (fmt-variant v)
    (format "~a (~a)"
            (syntax-variant-encoding-id v)
            (syntax-variant-template v)))

  (displayln (format-diagnosis diag fmt-variant))
  diag)

;; ============================================================
;; 交互式测试
;; ============================================================

(define (run-interactive)
  (printf "加载数据库...\n")
  (define-values (by-mnem _enc _cls) (load-variant-db/default))
  (printf "就绪。输入指令 S-expr 进行诊断，输入 quit 退出。\n\n")

  (let loop ()
    (printf "> ")
    (flush-output)
    (define line (read-line))
    (cond
      [(eof-object? line) (void)]
      [(string=? (string-trim line) "quit") (printf "再见!\n")]
      [else
       (with-handlers ([exn:fail? (lambda (e)
                                    (printf "错误: ~a\n\n" (exn-message e)))])
         (define sexp (read (open-input-string line)))
         (diagnose-sexp sexp by-mnem)
         (printf "\n"))
       (loop)])))

;; ============================================================
;; Main
;; ============================================================

(module+ main
  (define args (current-command-line-arguments))
  (cond
    [(= (vector-length args) 0)
     (run-interactive)]
    [(string=? (vector-ref args 0) "test")
     ;; 使用运行时数据库进行测试
     (define-values (by-mnem _enc _cls) (load-variant-db/default))
     (printf "\n=== 测试诊断 ===\n\n")
     (diagnose-sexp '(add x0 x1 x2) by-mnem)
     (newline)
     (diagnose-sexp '(add x0 x1) by-mnem)
     (newline)
     (diagnose-sexp '(ldr x0 x1) by-mnem)
     (void)]
    [else
     (printf "用法:\n")
     (printf "  racket cli/diagnose.rkt        # 交互式\n")
     (printf "  racket cli/diagnose.rkt test   # 运行测试\n")]))
