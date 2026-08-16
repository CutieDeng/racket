#lang racket

;; ============================================================
;; test/save-load/test-save-load.rkt - save!/load! 端到端测试
;; ============================================================
;;
;; 编译 .d 测试文件，检查生成的汇编是否包含预期模式

(require rackunit
         rackunit/text-ui
         "../../parser/frontend.rkt"
         "../../parser/ast.rkt"
         "../../semantic/control-flow.rkt"
         "../../semantic/inline.rkt"
         "../../pipeline/pipeline.rkt"
         "../../pipeline/regalloc/abi-config.rkt"
         "../../codegen/emit.rkt")

;; ============================================================
;; 辅助函数
;; ============================================================

;; 当前文件所在目录 (用于定位 .d 文件)
(define here (path-only (syntax-source #'here)))

;; 编译 .d 文件，返回生成的汇编字符串
;; file : string — .d 文件名
;; → string
(define (compile-test-file file)
  (default-abi-name 'aapcs64)
  (define path (build-path here file))
  (define source (file->string path))
  (define results (parse-string source))
  (define items
    (for/list ([r (parse-results-items results)]
               #:when (parse-result-ok? r))
      (parse-result-instruction r)))
  (define cfg (expand-inline-cfg (build-cfg items)))

  (parameterize ([current-emit-config apple-emit-config])
    (string-join
     (for/list ([i (in-range (cfg-function-count cfg))])
       (define fn (cfg-get-function cfg i))
       (emit-function/result (run-pipeline fn default-pipeline-config)))
     "\n\n")))

;; 检查汇编中是否包含正则模式
;; asm     : string
;; pattern : string (正则表达式)
;; → boolean
(define (asm-contains? asm pattern)
  (regexp-match? (regexp pattern) asm))

;; 统计正则模式出现次数
;; asm     : string
;; pattern : string (正则表达式)
;; → integer
(define (asm-count-matches asm pattern)
  (length (regexp-match* (regexp pattern) asm)))

;; ============================================================
;; 测试套件
;; ============================================================

(define save-load-tests
  (test-suite
   "save!/load! 端到端测试"

   ;; ----------------------------------------------------------
   ;; 001: 基本 GPR save!/load! (all 关键字)
   ;; ----------------------------------------------------------
   (test-case "001 基本 GPR save!/load!"
     (define asm (compile-test-file "001-basic-gpr.d"))
     ;; 应该有栈分配 (旧路径 sub sp 或优化路径 pre-index stp)
     (define has-sub? (asm-contains? asm "sub sp, sp, #[0-9]+"))
     (define has-preindex? (asm-contains? asm "stp x29, x30, \\[sp, #-[0-9]+\\]!"))
     (check-true (or has-sub? has-preindex?) "缺少栈分配指令")
     ;; 若已经使用 pre-index，不应再有冗余 sub sp
     (when has-preindex?
       (check-false has-sub? "有 pre-index stp 却还有冗余 sub sp"))
     ;; 应该有成对保存/恢复
     (check-true (asm-contains? asm "stp") "缺少 stp")
     (check-true (asm-contains? asm "ldp") "缺少 ldp")
     ;; 应该包含帧指针和链接寄存器
     (check-true (asm-contains? asm "x29") "缺少 x29")
     (check-true (asm-contains? asm "x30") "缺少 x30"))

   ;; ----------------------------------------------------------
   ;; 002: 显式寄存器指定
   ;; ----------------------------------------------------------
   (test-case "002 显式寄存器指定"
     (define asm (compile-test-file "002-explicit-regs.d"))
     (check-true (asm-contains? asm "x19") "缺少 x19")
     (check-true (asm-contains? asm "x20") "缺少 x20"))

   ;; ----------------------------------------------------------
   ;; 003: FPR save!/load!
   ;; ----------------------------------------------------------
   (test-case "003 FPR save!/load!"
     (define asm (compile-test-file "003-fpr.d"))
     ;; 应该有 q 寄存器保存指令
     (check-true (or (asm-contains? asm "stp q[0-9]+, q[0-9]+")
                     (asm-contains? asm "str q[0-9]+"))
                 "缺少 FPR 保存指令")
     ;; 应该有 q 寄存器恢复指令
     (check-true (or (asm-contains? asm "ldp q[0-9]+, q[0-9]+")
                     (asm-contains? asm "ldr q[0-9]+"))
                 "缺少 FPR 恢复指令"))

   ;; ----------------------------------------------------------
   ;; 004: 多基本块 (多个 load! 点)
   ;; ----------------------------------------------------------
   (test-case "004 多基本块多 load!"
     (define asm (compile-test-file "004-multi-block.d"))
     ;; 应该有至少 2 个 ldp x29, x30 (两条执行路径)
     (define count (asm-count-matches asm "ldp x29, x30"))
     (check-true (>= count 2)
                 (format "需要至少 2 个 ldp x29, x30，实际 ~a" count)))

   ;; ----------------------------------------------------------
   ;; 005: 嵌套函数调用
   ;; ----------------------------------------------------------
   (test-case "005 嵌套函数调用"
     (define asm (compile-test-file "005-nested-call.d"))
     (check-true (asm-contains? asm "bl") "缺少 bl")
     (check-true (asm-contains? asm "x30") "缺少 x30 保存"))

   ;; ----------------------------------------------------------
   ;; 006: 单寄存器边界情况
   ;; ----------------------------------------------------------
   (test-case "006 单寄存器"
     (define asm (compile-test-file "006-single-reg.d"))
     ;; 应该保存 x19
     (check-true (or (asm-contains? asm "str x19")
                     (asm-contains? asm "stp.*x19"))
                 "缺少 x19 保存指令")
     ;; 栈对齐: sub sp, sp, #N 中 N 应是 16 的倍数
     (define m (regexp-match #rx"sub sp, sp, #([0-9]+)" asm))
     (when m
       (define n (string->number (cadr m)))
       (check-equal? (modulo n 16) 0
                     (format "栈未对齐到 16: ~a" n))))

   ;; ----------------------------------------------------------
   ;; 007: Post-index 优化
   ;; ----------------------------------------------------------
   (test-case "007 post-index 优化"
     (define asm (compile-test-file "007-post-index.d"))
     ;; 应该有 post-index ldp
     (check-true (asm-contains? asm "ldp x29, x30, \\[sp\\], #[0-9]+")
                 "缺少 post-index ldp")
     ;; 有 post-index 就不应有额外的 add sp, sp
     (define has-post-index? (asm-contains? asm "ldp x29, x30, \\[sp\\], #[0-9]+"))
     (define has-add-sp? (asm-contains? asm "add sp, sp, #[0-9]+$"))
     (when has-post-index?
       (check-false has-add-sp? "有 post-index 却还有 add sp")))

   ;; ----------------------------------------------------------
   ;; 008: 栈不平衡警告 (编译应成功)
   ;; ----------------------------------------------------------
   (test-case "008 栈不平衡 (编译成功)"
     (define asm (compile-test-file "008-unbalanced.d"))
     (check-true (string? asm) "应该编译成功"))

   ;; ----------------------------------------------------------
   ;; 009: save! pre-index 优化
   ;; ----------------------------------------------------------
   (test-case "009 save! pre-index 优化"
     (define asm (compile-test-file "009-save-pre-index.d"))
     ;; save! 应该用 pre-index stp 一步完成栈分配 + 保存 x29/x30
     (check-true (asm-contains? asm "stp x29, x30, \\[sp, #-[0-9]+\\]!")
                 "缺少 pre-index stp x29, x30")
     ;; 有 pre-index stp 时不应再有单独的 sub sp
     (check-false (asm-contains? asm "sub sp, sp, #[0-9]+")
                  "存在冗余 sub sp, sp"))

   ;; ----------------------------------------------------------
   ;; 010: 中间 load! 不释放栈
   ;; ----------------------------------------------------------
   (test-case "010 中间 load! 不释放栈"
     (define asm (compile-test-file "010-middle-load-no-dealloc.d"))
     ;; 两次 load x19 都应存在
     (check-true (>= (asm-count-matches asm "ldr x19, \\[sp, #0\\]") 2)
                 "应至少包含两次 ldr x19")
     ;; 栈释放只能发生一次（结尾 load!）
     (check-equal? (asm-count-matches asm "add sp, sp, #[0-9]+") 1
                   "中间 load! 不应释放栈"))))

;; ============================================================
;; 执行
;; ============================================================

(module+ main
  (void (run-tests save-load-tests)))

(module+ test
  (void (run-tests save-load-tests)))
