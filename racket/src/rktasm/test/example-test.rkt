#lang racket

;; ============================================================
;; test/example-test.rkt - example 目录编译测试
;; ============================================================
;;
;; 测试 example/*.d 和 example/*.asm 能否成功编译
;;
;; 运行: racket test/example-test.rkt

(require rackunit
         rackunit/text-ui
         "../parser/frontend.rkt"
         "../parser/ast.rkt"
         "../semantic/control-flow.rkt"
         "../semantic/inline.rkt"
         "../semantic/ipa-callconv.rkt"
         "../pipeline/pipeline.rkt"
         "../pipeline/regalloc/abi-config.rkt"
         "../codegen/emit.rkt")

(define here (path-only (syntax-source #'here)))
(define repo-dir (simplify-path (build-path here "..")))
(define example-dir (simplify-path (build-path repo-dir "example")))
(define project-abi-config (simplify-path (build-path repo-dir "config" "abi.rktd")))

;; ============================================================
;; 编译函数
;; ============================================================

;; 编译文件，返回 (values success? error-msg asm-output)
(define (compile-file path)
  (with-handlers ([exn:fail? (lambda (e)
                               (values #f (exn-message e) #f))])
    (parameterize ([abi-config-path project-abi-config])
      (reload-abi-config project-abi-config #:force? #t)
      (define syntax-mode
        (if (regexp-match? #rx"\\.(asm|s)$" (path->string path))
            'gnu
            'sexp))
      (define source (file->string path))
      (define results (parse-string source
                                    #:source path
                                    #:syntax syntax-mode))

      ;; 检查解析错误
      (when (parse-results-has-errors? results)
        (error 'compile-file "解析错误:\n~a"
               (format-parse-errors-report results)))

      ;; 提取 AST
      (define items
        (for/list ([r (parse-results-items results)]
                   #:when (parse-result-ok? r))
          (parse-result-instruction r)))

      ;; 构建 CFG
      (define cfg0 (build-cfg items))
      (define hint-selections (collect-callconv-hint-selections cfg0))
      (define-values (cfg/ipa _summaries)
        (if (null? hint-selections)
            (values cfg0 '())
            (apply-callconv-selections cfg0 hint-selections)))
      (define cfg (expand-inline-cfg cfg/ipa))

      ;; 对每个函数运行流水线
      (define compiled-fns
        (for/list ([i (in-range (cfg-function-count cfg))])
          (define fn (cfg-get-function cfg i))
          (run-pipeline fn default-pipeline-config)))

      ;; 检查编译错误
      (for ([result (in-list compiled-fns)])
        (unless (null? (pipeline-result-errors result))
          (error 'compile-file "编译错误:\n~a"
                 (string-join (pipeline-result-errors result) "\n"))))

      ;; 生成汇编
      (define asm
        (string-join
         (for/list ([result (in-list compiled-fns)])
           (emit-function/result result))
         "\n\n"))

      (values #t #f asm))))

;; ============================================================
;; 发现 example 文件
;; ============================================================

(define (find-example-files)
  (if (directory-exists? example-dir)
      (for/list ([f (in-directory example-dir)]
                 #:when (regexp-match? #rx"\\.(d|asm)$" (path->string f)))
        f)
      '()))

;; ============================================================
;; 动态生成测试
;; ============================================================

(define (make-example-test path)
  (define name (path->string (file-name-from-path path)))
  (test-case
   (format "编译 ~a" name)
   (define-values (ok? err asm) (compile-file path))
   (check-true ok?
               (format "编译失败: ~a\n错误: ~a" name err))
   (check-true (and asm (> (string-length asm) 0))
               (format "~a 编译输出为空" name))))

(define example-tests
  (test-suite
   "example 目录编译测试"
   (for/list ([path (sort (find-example-files) path<?)])
     (make-example-test path))))

;; ============================================================
;; 运行测试
;; ============================================================

(module+ test
  (void (run-tests example-tests)))

(module+ main
  (define verbosity (make-parameter 'normal))

  (command-line
   #:program "example-test"
   #:once-each
   [("-v" "--verbose") "详细输出" (verbosity 'verbose)]
   #:args ()

   (printf "发现 ~a 个 example 文件\n\n" (length (find-example-files)))
   (void (run-tests example-tests (verbosity)))))
