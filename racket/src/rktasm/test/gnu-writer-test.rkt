#lang racket

;; ============================================================
;; test/gnu-writer-test.rkt - gnu-writer (AST → GNU .asm 文本) 测试
;; ============================================================
;;
;; 覆盖:
;;   - 构造器程序: 序列化 → gnu-parser 回读 → AST 逐条相同 (写路径自校验)
;;   - 确定性: 同一程序两次序列化字节相同
;;   - 操作数渲染面: 虚拟/物理/zr/元素后缀/内存三种寻址/寄存器列表/
;;     shift 尾随立即数 (movk lsl)/条件码操作数/后缀指令 (b.ne)
;;   - 指示渲染面: 三行 .function 头 / 单行 context 头 / .save/.restore /
;;     .context 声明 / .end
;;   - 语料往返: rktcrypto asm/ 全部已提交 .asm 逐个 parse → serialize →
;;     reparse → AST 相同 (存在时启用; 目录可用 RKTCRYPTO_ASM_DIR 覆盖)
;;   - fail-fast: 不支持的 directive / 非虚拟形参 / 空寄存器列表报错
;;
;; 双进程确定性 (哈希稳定) 由外层驱动脚本验证: 同一发射程序在两个独立
;; racket 进程各跑一次, 比较输出 SHA (进程内两次序列化比较无法暴露
;; gensym/hash 遍历序类的跨进程漂移)。本文件提供 `--emit-sample` 模式
;; 供该脚本调用: racket test/gnu-writer-test.rkt --emit-sample

(require rackunit
         rackunit/text-ui
         racket/runtime-path
         "../parser/gnu-writer.rkt"
         "../parser/frontend.rkt"
         "../parser/ast.rkt")

;; ------------------------------------------------------------
;; 样例程序: 覆盖全部构造器面
;; ------------------------------------------------------------

(define (sample-program)
  (list
   (doc "gnu-writer 测试样例内核 (非真实算法)"
        "覆盖操作数/指示渲染面")
   (fn-begin 'gw_sample #:export? #t
             #:in (list (rx 'r) (rx 'a) (rx 'b)))
   (lbl 'entry)
   (save-all)
   (ins 'mov (rx 'acc0) xzr)
   (rem "column 0")
   (ins 'ldr (rx 't) (mem (rx 'a) 8))
   (ins 'mul (rx 'p) (rx 't) (rx 'bi))
   (ins 'adds (rx 'acc0) (rx 'acc0) (rx 'p))
   (ins 'adcs (rx 'acc1) (rx 'acc1) (rx 'p))
   (ins 'adc (rx 'acc2) (rx 'acc2) xzr)
   (ins 'movz (rx 'k) (im 42104))
   (ins 'movk (rx 'k) (im 53710) (sh 'lsl 16))
   (ins 'csel (rx 'd) (rx 'a) (rx 'b) (cnd 'cc))
   (ins 'ld1 (regs (rv 'st0 "2d")) (mem-post (rx 'st) 16))
   (ins 'st1 (regs (rv 'st0 "2d")) (mem (rx 'st)))
   (ins 'ldp (rx 'lo) (rx 'hi) (mem-pre (rx 'a) -16))
   (ins 'eor3 (rv 'x0 "16b") (rv 'x1 "16b") (rv 'x2 "16b") (rv 'x3 "16b"))
   (ins 'cbnz (rx 'n) (lab 'entry))
   (ins 'b #:suffix 'ne (lab 'entry))
   (ins 'str (rx 'acc0) (mem (rx 'r) 0))
   (restore-all)
   (ins 'ret)
   (fn-end)
   blank
   (ctx-decl 'gw_field
             (list (cons 'a0 (rx 4)) (cons 'a1 (rx 5)) (cons 'rp (rx 0)))
             #:scope 'library)
   (fn-begin 'gw_helper #:contexts '(gw_field))
   (lbl 'entry)
   (ins 'ldr (rx 'a0) (mem (rx 'rp) 8))
   (ins 'add (rx 'a1) (rx 'a0) (rx 'a0) (sh 'lsl 2))
   (ins 'ret)
   (fn-end)))

;; ------------------------------------------------------------
;; 语料目录
;; ------------------------------------------------------------

(define-runtime-path here ".")

(define corpus-dir
  (let ([env (getenv "RKTCRYPTO_ASM_DIR")])
    (cond
      [env (and (directory-exists? env) env)]
      [else
       ;; 入树布局: rktasm/test/ 与 crypto/ 同在 racket/src/ 下
       (define default (build-path here 'up 'up "crypto" "asm"))
       (and (directory-exists? default) default)])))

;; ------------------------------------------------------------
;; 测试
;; ------------------------------------------------------------

(define gnu-writer-tests
  (test-suite
   "gnu-writer"

   (test-case "样例程序: 序列化即回读自校验通过"
     ;; gnu-program->string 默认 #:check? #t: 回读失配会直接 error
     (check-pred string? (gnu-program->string (sample-program))))

   (test-case "确定性: 两次序列化字节相同"
     (check-equal? (gnu-program->string (sample-program))
                   (gnu-program->string (sample-program))))

   (test-case "渲染面抽查"
     (define text (gnu-program->string (sample-program)))
     (define (has? s) (check-true (string-contains? text s) s))
     (has? ".function gw_sample export (")
     (has? "  in: x.r, x.a, x.b")
     (has? "  .save all")
     (has? "  movk x.k, #53710, lsl #16")
     (has? "  csel x.d, x.a, x.b, cc")
     (has? "  ld1 { v.st0.2d }, [x.st], #16")
     (has? "  st1 { v.st0.2d }, [x.st]")
     (has? "  ldp x.lo, x.hi, [x.a, #-16]!")
     (has? "  b.ne entry")
     (has? "  .restore all")
     (has? ".end")
     (has? ".context gw_field (scope library) a0=x4 a1=x5 rp=x0")
     (has? ".function gw_helper (context gw_field)")
     (has? "  add x.a1, x.a0, x.a0, lsl #2"))

   (test-case "fail-fast: 非虚拟形参"
     (check-exn #rx"must be virtual"
                (lambda () (fn-begin 'f #:in (list (rx 0))))))

   (test-case "fail-fast: 空寄存器列表"
     (check-exn #rx"cannot be empty" (lambda () (regs))))

   (test-case "fail-fast: 不支持的 directive"
     (check-exn #rx"not supported by writer"
                (lambda ()
                  (gnu-program->string
                   (list (ast-directive 'byte #f (list 0) no-srcloc))))))

   (test-case "fail-fast: 回读失配被抓住 (故障注入)"
     ;; 逃生舱 string 行只做可解析校验; 直接构造一个解析后必然不同的
     ;; AST 条目来验证逐条比对真的在工作: 人为构造带错误后缀的指令,
     ;; 序列化 "ret.zz" 解析必失败 → error
     (check-exn exn:fail?
                (lambda ()
                  (gnu-program->string
                   (list (ins 'ret #:suffix 'zz))))))

   (test-case "语料往返: rktcrypto asm/ 全部 .asm"
     (cond
       [(not corpus-dir)
        (printf "  [skip] 语料目录不存在 (设 RKTCRYPTO_ASM_DIR 启用)\n")]
       [else
        (define files
          (sort (for/list ([f (in-directory corpus-dir)]
                           #:when (regexp-match? #rx"\\.asm$" (path->string f)))
                  f)
                string<? #:key path->string))
        (check-true (pair? files) "语料目录里应有 .asm 文件")
        (for ([f (in-list files)])
          (with-check-info (['corpus-file (path->string f)])
            (define items (parse-gnu-file->items f))
            ;; 序列化裸 AST 条目; #:check? #t 即 serialize→reparse→逐条比对
            (define text (gnu-program->string items))
            ;; 再独立断言一次往返闭合
            (define reparsed
              (let ([rs (parse-string text #:source f #:syntax 'gnu)])
                (check-false (parse-results-has-errors? rs)
                             (format-parse-errors-report rs))
                (map ast-strip-loc
                     (filter values
                             (map parse-result-instruction
                                  (parse-results-filter-ok rs))))))
            (check-equal? reparsed items)))
        (printf "  语料往返: ~a 个 .asm 全部闭合\n" (length files))]))))

;; --emit-sample: 双进程确定性驱动用 (打样例程序文本后退出, 不跑测试)
(module+ main
  (if (member "--emit-sample" (vector->list (current-command-line-arguments)))
      (display (gnu-program->string (sample-program)))
      (exit (run-tests gnu-writer-tests))))

(module+ test
  (void (run-tests gnu-writer-tests)))
