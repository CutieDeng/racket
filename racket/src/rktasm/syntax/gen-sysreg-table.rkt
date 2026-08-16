#lang racket
;; ============================================================
;; gen-sysreg-table.rkt
;; 从 AARCHMRS Registers.json 提取具名 AArch64 系统寄存器 -> 编码表。
;; 产物: syntax/data/generated/sysreg-table.rktd
;;   格式: (NAME op0 op1 CRn CRm op2)
;; 用于 mrs/msr 的具名 system-register 操作数编码(如 CNTVCTSS_EL0)。
;;
;; 只收 op0 ∈ {2,3}(AArch64 MRS/MSR 可寻址)且编码定长的寄存器;
;; 变量/索引族(DBGBVR<m>_EL1 等)当前跳过(需范围展开,后续再做)。
;;
;; 设计:前端全靠生成器/元编程,对输入 JSON 做**软断言**——schema 漂移
;; (ARM 未来改键/改结构)时响亮失败并指明位置,而非默默产出错表。
;; 已知真值锚点(KNOWN-ANCHORS)把少量寄存器编码钉死,为后向维护提供导引。
;; ============================================================
(require json racket/cmdline)
(provide extract-sysreg-table write-sysreg-table validate-sysreg-table)

(define WHO 'gen-sysreg-table)

;; 各字段位宽上限(超界即说明解析/数据出错)
(define FIELD-MAX (hash 'op0 3 'op1 7 'CRn 15 'CRm 15 'op2 7))

;; 已知真值锚点:这些必须存在且编码精确匹配,否则视为 schema 漂移。
;; 覆盖计数器族(FEAT_ECV SS 变体)与几个常见控制/状态寄存器。
(define KNOWN-ANCHORS
  '(("CNTVCTSS_EL0" 3 3 14 0 6)
    ("CNTPCTSS_EL0" 3 3 14 0 5)
    ("CNTVCT_EL0"   3 3 14 0 2)
    ("CNTFRQ_EL0"   3 3 14 0 0)
    ("SCTLR_EL1"    3 0  1 0 0)
    ("NZCV"         3 3  4 2 0)
    ("DAIF"         3 3  4 2 1)
    ("TPIDR_EL0"    3 3 13 0 2)
    ("PMCCNTR_EL0"  3 3  9 13 0)))

;; 期望的具名 AArch64 sysreg 数量下限:远低于此说明提取塌了。
(define MIN-EXPECTED 500)

;; "'110'" -> 6 ; #f 表示非定长二进制字面量(变量字段)
(define (parse-bits v)
  (and (string? v)
       (let ([m (regexp-match #px"^'([01]+)'$" (string-trim v))])
         (and m (string->number (cadr m) 2)))))

;; 软断言:取键,缺失即带位置报错(schema 漂移引导)
(define (ref/req h key ctx)
  (hash-ref h key
            (lambda () (error WHO "~a: 缺少预期键 '~a'(AARCHMRS schema 可能已变)" ctx key))))

(define (enc-field es key)
  (define f (hash-ref es key #f))
  (and (hash? f) (parse-bits (hash-ref f 'value #f))))

;; 读入并断言顶层结构
(define (read-registers json-path)
  (define d (call-with-input-file json-path read-json))
  (unless (list? d)
    (error WHO "Registers.json 顶层应为寄存器数组,实为 ~a(schema 漂移?)" (if (hash? d) "对象" d)))
  (when (null? d)
    (error WHO "Registers.json 为空数组"))
  d)

;; -> (values table conflicts skipped) ; table: name -> (list op0 op1 CRn CRm op2)
(define (extract-sysreg-table json-path)
  (define regs (read-registers json-path))
  (define tbl (make-hash))
  (define conflicts (make-hash))
  (define skipped 0)                          ; 变量/索引族计数(可见跳过,非静默)
  (for* ([reg (in-list regs)]
         [acc (in-list (hash-ref reg 'accessors '()))]   ; accessors 合法可缺
         [enc (in-list (hash-ref acc 'encoding '()))])
    (define name (hash-ref enc 'asmvalue #f))
    (define es   (hash-ref enc 'encodings #f))
    (when (and (string? name) (hash? es))
      (define fields (map (lambda (k) (enc-field es k)) '(op0 op1 CRn CRm op2)))
      (cond
        [(not (andmap values fields)) (set! skipped (add1 skipped))]  ; 变量编码,可见跳过
        [else
         ;; 软断言:字段值须落在其位宽内,否则解析/数据异常
         (for ([k '(op0 op1 CRn CRm op2)] [v fields])
           (when (> v (hash-ref FIELD-MAX k))
             (error WHO "~a 的字段 ~a=~a 超出位宽上限 ~a" name k v (hash-ref FIELD-MAX k))))
         (when (memv (first fields) '(2 3))     ; 仅 AArch64 mrs/msr
           (cond
             [(and (hash-has-key? tbl name) (not (equal? (hash-ref tbl name) fields)))
              (hash-set! conflicts name (list (hash-ref tbl name) fields))]
             [else (hash-set! tbl name fields)]))])))
  (values tbl conflicts skipped))

;; 后置安全检查:数量下限 + 已知真值锚点 + 无冲突。任一不满足即报错引导。
(define (validate-sysreg-table tbl conflicts)
  (when (< (hash-count tbl) MIN-EXPECTED)
    (error WHO "仅提取到 ~a 个具名 sysreg,低于下限 ~a——提取逻辑或数据可能已破" (hash-count tbl) MIN-EXPECTED))
  (for ([a (in-list KNOWN-ANCHORS)])
    (match-define (cons nm want) a)
    (define got (hash-ref tbl nm #f))
    (unless got
      (error WHO "锚点寄存器 ~a 缺失(schema 漂移或名称改变?)" nm))
    (unless (equal? got want)
      (error WHO "锚点 ~a 编码不符: 期望 ~a, 实得 ~a(AARCHMRS 编码变更?)" nm want got)))
  (unless (zero? (hash-count conflicts))
    (error WHO "~a 个名字存在冲突编码(应唯一): ~a" (hash-count conflicts)
           (sort (hash-keys conflicts) string<?))))

(define (write-sysreg-table tbl out-path)
  (call-with-output-file out-path #:exists 'replace
    (lambda (o)
      (fprintf o ";; ============================================================\n")
      (fprintf o ";; sysreg-table.rktd - 具名 AArch64 系统寄存器 -> 编码\n")
      (fprintf o ";; 由 syntax/gen-sysreg-table.rkt 从 AARCHMRS Registers.json 生成 - 请勿手改\n")
      (fprintf o ";; 格式: (NAME op0 op1 CRn CRm op2)\n")
      (fprintf o ";; ============================================================\n\n")
      (for ([name (sort (hash-keys tbl) string<?)])
        (match-define (list op0 op1 crn crm op2) (hash-ref tbl name))
        (fprintf o "(~a ~a ~a ~a ~a ~a)\n" name op0 op1 crn crm op2)))))

(module+ main
  (define json-path
    (make-parameter "AARCHMRS_OPENSOURCE_A_profile_FAT-2025-12/Registers.json"))
  (define out-path
    (make-parameter "syntax/data/generated/sysreg-table.rktd"))
  (command-line
   #:once-each
   [("-j" "--json") p "Path to Registers.json" (json-path p)]
   [("-o" "--out")  p "Output .rktd path"      (out-path p)])
  (printf "从 ~a 提取系统寄存器表...\n" (json-path))
  (define-values (tbl conflicts skipped) (extract-sysreg-table (json-path)))
  (validate-sysreg-table tbl conflicts)        ; 软断言/安全检查:不过则响亮失败
  (write-sysreg-table tbl (out-path))
  (printf "已保存: ~a (~a 个具名 AArch64 系统寄存器;可见跳过 ~a 个变量/索引编码)\n"
          (out-path) (hash-count tbl) skipped)
  (printf "锚点校验通过: ~a 个已知真值全部匹配\n" (length KNOWN-ANCHORS)))
