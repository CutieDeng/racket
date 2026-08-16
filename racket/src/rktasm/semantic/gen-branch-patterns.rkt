#!/usr/bin/env racket
#lang racket

;; ============================================================
;; gen-branch-patterns.rkt
;; 生成: data/branch-patterns.rktd
;; ============================================================
;;
;; 分支指令语义模式 (硬编码，非 MRS 来源)
;;
;; 格式: (mnemonic branch-type target-type is-call? is-return? condition-source)

(require racket/cmdline)

(provide BRANCH_PATTERNS
         generate-branch-patterns
         save-branch-patterns)

;; ============================================================
;; 分支指令模式定义
;; ============================================================

(define BRANCH_PATTERNS
  '(;; 无条件直接跳转
    (b       unconditional direct   #f #f #f)
    (bl      unconditional direct   #t #f #f)

    ;; 无条件间接跳转
    (br      unconditional indirect #f #f #f)
    (blr     unconditional indirect #t #f #f)
    (ret     unconditional indirect #f #t #f)

    ;; 带指针认证的跳转
    (braa    unconditional indirect #f #f #f)
    (brab    unconditional indirect #f #f #f)
    (blraa   unconditional indirect #t #f #f)
    (blrab   unconditional indirect #t #f #f)
    (braaz   unconditional indirect #f #f #f)
    (brabz   unconditional indirect #f #f #f)
    (blraaz  unconditional indirect #t #f #f)
    (blrabz  unconditional indirect #t #f #f)
    (retaa   unconditional indirect #f #t #f)
    (retab   unconditional indirect #f #t #f)

    ;; 条件跳转 - B.cond (suffix 条件码)
    (b.eq    conditional direct #f #f suffix)
    (b.ne    conditional direct #f #f suffix)
    (b.cs    conditional direct #f #f suffix)
    (b.hs    conditional direct #f #f suffix)
    (b.cc    conditional direct #f #f suffix)
    (b.lo    conditional direct #f #f suffix)
    (b.mi    conditional direct #f #f suffix)
    (b.pl    conditional direct #f #f suffix)
    (b.vs    conditional direct #f #f suffix)
    (b.vc    conditional direct #f #f suffix)
    (b.hi    conditional direct #f #f suffix)
    (b.ls    conditional direct #f #f suffix)
    (b.ge    conditional direct #f #f suffix)
    (b.lt    conditional direct #f #f suffix)
    (b.gt    conditional direct #f #f suffix)
    (b.le    conditional direct #f #f suffix)
    (b.al    unconditional direct #f #f suffix)
    (b.nv    unconditional direct #f #f suffix)

    ;; 比较跳转 - CBZ/CBNZ (register 条件)
    (cbz     conditional direct #f #f register)
    (cbnz    conditional direct #f #f register)

    ;; 测试跳转 - TBZ/TBNZ (bit 条件)
    (tbz     conditional direct #f #f bit)
    (tbnz    conditional direct #f #f bit)))

;; ============================================================
;; 生成函数
;; ============================================================

(define (generate-branch-patterns)
  BRANCH_PATTERNS)

;; ============================================================
;; 输出
;; ============================================================

(define (save-branch-patterns patterns output-path)
  (call-with-output-file output-path
    (lambda (out)
      (fprintf out ";; ============================================================\n")
      (fprintf out ";; branch-patterns.rktd - 分支指令语义模式\n")
      (fprintf out ";; ============================================================\n")
      (fprintf out ";;\n")
      (fprintf out ";; 格式: (mnemonic branch-type target-type is-call? is-return? condition-source)\n")
      (fprintf out ";;\n")
      (fprintf out ";; branch-type: unconditional | conditional\n")
      (fprintf out ";; target-type: direct | indirect\n")
      (fprintf out ";; condition-source: #f | suffix | register | bit\n")
      (fprintf out ";;\n")
      (fprintf out ";; 生成命令: racket semantic/gen-branch-patterns.rkt\n")
      (fprintf out ";;\n\n")

      ;; 分类输出
      (define categories
        '(("无条件直接跳转" b bl)
          ("无条件间接跳转" br blr ret)
          ("带指针认证的跳转" braa brab blraa blrab braaz brabz blraaz blrabz retaa retab)
          ("条件跳转 - B.cond" b.eq b.ne b.cs b.hs b.cc b.lo b.mi b.pl b.vs b.vc b.hi b.ls b.ge b.lt b.gt b.le b.al b.nv)
          ("比较跳转 - CBZ/CBNZ" cbz cbnz)
          ("测试跳转 - TBZ/TBNZ" tbz tbnz)))

      (for ([cat (in-list categories)])
        (define cat-name (car cat))
        (define cat-mnems (cdr cat))
        (fprintf out ";; ~a\n" cat-name)
        (for ([pat (in-list patterns)]
              #:when (memq (car pat) cat-mnems))
          (fprintf out "~s\n" pat))
        (fprintf out "\n")))
    #:exists 'replace)

  (printf "已保存: ~a (~a 条模式)\n" output-path (length patterns)))

;; ============================================================
;; 主程序
;; ============================================================

(module+ main
  (define output-path
    (make-parameter "semantic/data/branch-patterns.rktd"))

  (command-line
   #:program "gen-branch-patterns"
   #:once-each
   [("-o" "--output") path
    "输出文件路径"
    (output-path path)]
   #:args ()

   (printf "生成分支指令模式...\n")

   (define patterns (generate-branch-patterns))
   (save-branch-patterns patterns (output-path))

   (printf "完成!\n")))
