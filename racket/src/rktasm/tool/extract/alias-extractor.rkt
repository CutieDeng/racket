#!/usr/bin/env racket
#lang racket

;; ============================================================
;; alias-extractor.rkt - 从 MRS JSON 提取指令别名
;; ============================================================
;;
;; 从 Instructions.json 提取 InstructionAlias 定义
;;
;; 输出格式:
;;   (alias-mnemonic target-operation assembly-pattern)

(require json
         racket/cmdline)

;; ============================================================
;; JSON 处理
;; ============================================================

;; 递归查找所有 InstructionAlias 节点
(define (find-aliases node)
  (cond
    [(hash? node)
     (if (equal? (hash-ref node '_type #f) "Instruction.InstructionAlias")
         (list node)
         (append-map find-aliases (hash-values node)))]
    [(list? node)
     (append-map find-aliases node)]
    [else '()]))

;; 从 assembly 中提取助记符
(define (extract-mnemonic alias)
  (define asm (hash-ref alias 'assembly #f))
  (when asm
    (define symbols (hash-ref asm 'symbols '()))
    (for/first ([sym (in-list symbols)]
                #:when (and (hash? sym)
                           (equal? (hash-ref sym '_type #f) "Instruction.Symbols.Literal")))
      (hash-ref sym 'value #f))))

;; 从 assembly 提取操作数模式
(define (extract-operand-pattern alias)
  (define asm (hash-ref alias 'assembly #f))
  (when asm
    (define symbols (hash-ref asm 'symbols '()))
    ;; 跳过第一个 literal (mnemonic) 和 SPACE
    (define operand-syms
      (filter (λ (s)
                (and (hash? s)
                     (let ([t (hash-ref s '_type #f)])
                       (or (equal? t "Instruction.Symbols.RuleReference")
                           (and (equal? t "Instruction.Symbols.Literal")
                                (not (equal? (hash-ref s 'value "") (extract-mnemonic alias))))))))
              symbols))
    ;; 简化为操作数类型列表
    (for/list ([sym (in-list operand-syms)]
               #:when (hash? sym))
      (define type (hash-ref sym '_type #f))
      (cond
        [(equal? type "Instruction.Symbols.RuleReference")
         (hash-ref sym 'rule_id "?")]
        [(equal? type "Instruction.Symbols.Literal")
         (hash-ref sym 'value "")]
        [else "?"]))))

;; 处理别名，提取简化的信息
(define (process-alias alias)
  (define mnem (extract-mnemonic alias))
  (define op-id (hash-ref alias 'operation_id #f))
  (define name (hash-ref alias 'name #f))
  (define operands (extract-operand-pattern alias))

  (when (and mnem op-id)
    (list (string->symbol (string-downcase mnem))
          (string->symbol op-id)
          name
          operands)))

;; ============================================================
;; 主提取函数
;; ============================================================

(define (extract-aliases json-path)
  (define data (with-input-from-file json-path read-json))
  (define instructions (hash-ref data 'instructions '()))

  ;; 找所有别名
  (define aliases (find-aliases instructions))
  (printf "找到 ~a 个 InstructionAlias\n" (length aliases))

  ;; 处理别名
  (define processed
    (filter values (map process-alias aliases)))

  ;; 按助记符分组
  (define grouped (make-hash))
  (for ([entry (in-list processed)])
    (match entry
      [(list mnem op-id name operands)
       (hash-update! grouped mnem
                     (λ (lst) (cons (list op-id name operands) lst))
                     '())]))

  grouped)

;; ============================================================
;; 输出
;; ============================================================

(define (save-alias-db db output-path)
  (call-with-output-file output-path
    (lambda (out)
      (fprintf out ";; ============================================================\n")
      (fprintf out ";; instruction-aliases.rktd - 指令别名定义\n")
      (fprintf out ";; ============================================================\n")
      (fprintf out ";;\n")
      (fprintf out ";; 格式: (alias-mnemonic ((target-op-id alias-name operand-pattern) ...))\n")
      (fprintf out ";;\n")
      (fprintf out ";; alias-mnemonic: 别名助记符 (如 mov, cmp, tst)\n")
      (fprintf out ";; target-op-id: 目标操作标识符 (如 MOV_ORR_log_shift)\n")
      (fprintf out ";; alias-name: 别名编码名称\n")
      (fprintf out ";; operand-pattern: 操作数模式\n")
      (fprintf out ";;\n\n")

      (for ([(mnem targets) (in-hash db)])
        (fprintf out "~s\n" (list mnem targets))))
    #:exists 'replace)

  (printf "已保存别名数据库: ~a (~a 个别名助记符)\n"
          output-path (hash-count db)))

;; 生成简化的别名映射 (用于快速查询)
(define (save-simple-alias-map db output-path)
  (call-with-output-file output-path
    (lambda (out)
      (fprintf out ";; ============================================================\n")
      (fprintf out ";; alias-map.rktd - 简化别名映射\n")
      (fprintf out ";; ============================================================\n")
      (fprintf out ";;\n")
      (fprintf out ";; 格式: (alias-mnemonic (target-mnemonic ...))\n")
      (fprintf out ";;\n")
      (fprintf out ";; 用于快速判断一个助记符是否为别名以及它可能映射到哪些真实指令\n")
      (fprintf out ";;\n\n")

      ;; 提取目标助记符
      (for ([(mnem targets) (in-hash db)])
        (define target-mnems
          (remove-duplicates
           (for/list ([t (in-list targets)])
             (define op-id (car t))
             ;; 从 op-id 提取真正的目标助记符
             ;; 如 MOV_ORR_log_shift -> orr
             ;; 如 CMP_SUBS_addsub_imm -> subs
             (extract-target-mnem op-id))))
        (fprintf out "~s\n" (list mnem target-mnems))))
    #:exists 'replace)

  (printf "已保存简化映射: ~a\n" output-path))

;; 从 operation_id 提取目标助记符
;; MOV_ORR_log_shift -> orr
;; CMP_SUBS_addsub_imm -> subs
(define (extract-target-mnem op-id)
  (define s (symbol->string op-id))
  ;; 处理格式: ALIAS_TARGET_... 或 alias_target_...
  (define parts (regexp-split #rx"_" s))
  (cond
    [(>= (length parts) 2)
     ;; 跳过第一部分 (alias name)，取第二部分 (target)
     (string->symbol (string-downcase (cadr parts)))]
    [else op-id]))

;; ============================================================
;; 主程序
;; ============================================================

(module+ main
  (define json-path
    (make-parameter "AARCHMRS_OPENSOURCE_A_profile_FAT-2025-12/Instructions.json"))
  (define output-path
    (make-parameter "syntax/data/instruction-aliases.rktd"))
  (define map-path
    (make-parameter "syntax/data/alias-map.rktd"))

  (command-line
   #:program "alias-extractor"
   #:once-each
   [("-i" "--input") path
    "Path to Instructions.json"
    (json-path path)]
   [("-o" "--output") path
    "Output path for full alias database"
    (output-path path)]
   [("-m" "--map") path
    "Output path for simplified alias map"
    (map-path path)]
   #:args ()

   (printf "从 ~a 提取别名...\n" (json-path))
   (define db (extract-aliases (json-path)))

   (save-alias-db db (output-path))
   (save-simple-alias-map db (map-path))

   ;; 显示统计
   (printf "\n=== 统计 ===\n")
   (for ([(mnem targets) (in-hash db)]
         #:when (memq mnem '(mov cmp cmn tst mvn neg negs ngc ngcs
                            lsl lsr asr ror
                            sxtb sxth sxtw uxtb uxth
                            mul mneg smull umull
                            cinc cinv cneg cset csetm)))
     (printf "~a:\n" mnem)
     (for ([t (in-list (take targets (min 3 (length targets))))])
       (printf "  → ~a\n" (car t))))))
