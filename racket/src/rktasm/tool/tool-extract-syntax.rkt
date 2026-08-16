#lang racket

;; ============================================================
;; tool-extract-syntax.rkt
;; 从 AARCHMRS Instructions.json 提取语法信息的工具
;; ============================================================

(require "extract/syntax-variant.rkt"
         "../parser/parser.rkt"
         "../syntax/main.rkt")

(provide extract-and-save
         diagnose-sexp
         run-interactive)

;; 默认路径
(define default-json-path
  "AARCHMRS_OPENSOURCE_A_profile_FAT-2025-12/Instructions.json")

(define default-output-dir
  "syntax/data")

;; ============================================================
;; 提取并保存
;; ============================================================

(define (extract-and-save [json-path default-json-path]
                          [output-dir default-output-dir])
  (printf "读取 ~a ...\n" json-path)
  (define db (build-syntax-variant-db-from-json json-path))
  (printf "提取了 ~a 个助记符\n" (hash-count db))

  ;; 统计
  (define total-instructions
    (for/sum ([variants (in-hash-values db)])
      (length variants)))
  (printf "共 ~a 条具体指令\n" total-instructions)

  (define all-classes
    (for*/set ([variants (in-hash-values db)]
               [v (in-list variants)])
      (extract-syntax-variant-syntax-class v)))
  (printf "语法大类: ~a\n" (sort (set->list all-classes) symbol<?))

  (printf "\n保存到 ~a/ ...\n" output-dir)
  (save-syntax-variant-db db output-dir)

  db)

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
    [(string=? (vector-ref args 0) "extract")
     (extract-and-save)]
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
     (printf "  racket tool-extract-syntax.rkt          # 交互式\n")
     (printf "  racket tool-extract-syntax.rkt extract  # 提取并保存\n")
     (printf "  racket tool-extract-syntax.rkt test     # 运行测试\n")]))
