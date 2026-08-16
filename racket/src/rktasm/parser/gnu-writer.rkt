#lang racket/base

;; ============================================================
;; parser/gnu-writer.rkt - gnu-parser 的逆: AST → GNU 前端 .asm 文本
;; ============================================================
;;
;; 为内核发射器 (rktcrypto Phase F "生成器 asmp 化") 服务: 发射器用本模块的
;; 构造器直接构造 parser/ast.rkt 结构, 再确定性序列化为 .asm 文本。
;;
;; 两条硬约束:
;;  1. 确定性: 同一 AST → 字节稳定输出。本模块无任何 hash 遍历序依赖
;;     (.function attrs 按固定键序渲染, .context 字段按声明序渲染)。
;;  2. 自校验: write-gnu-program / gnu-program->string #:check? #t 在序列化后
;;     立即用 gnu-parser 回读, 与构造的 AST 逐条比对 (忽略 srcloc)。
;;     构造/渲染错误在发射点即报, 而不是等差分门禁。
;;
;; 渲染风格对齐 rktcrypto asm/ 语料: 小写助记符/移位/条件码, 指令缩进
;; 两空格 (可配), 导出内核用三行 .function 头, 上下文内核用单行头。
;; 序列化覆盖面 = 语料实际用到的指示 (.function/.end/.save/.restore/
;; .context/.frame/.alloca/标签); 未覆盖的 directive 一律 fail-fast 报错, 不静默吞掉。

(require racket/match
         racket/list
         racket/string
         "ast.rkt"
         "frontend.rkt")

(provide
 ;; 操作数构造器 (全部挂 no-srcloc)
 rx rw rv rq rd rs-reg
 xzr wzr rsp
 im lab sh ext cnd
 mem mem-pre mem-post
 regs

 ;; 行构造器
 ins
 lbl
 doc rem blank
 fn-begin fn-end
 save-all restore-all save-regs restore-regs
 ctx-decl

 ;; 序列化与输出
 gnu-program->string
 write-gnu-program
 gnu-line->lines

 ;; 解析/比较助手 (语料往返测试与 .asm 对拍共用)
 parse-gnu-file->items
 ast-strip-loc)

;; ============================================================
;; 操作数构造器
;; ============================================================

;; 寄存器: id 为 symbol → 虚拟 (x.name), 为 number → 物理 (x4)。
;; element 接受 symbol 或 string ("4s"/"2d"/"16b" 以数字开头, string 更顺手)。
(define (make-reg kind id [element #f])
  (ast-reg kind id #f #f
           (and element
                (if (string? element) (string->symbol element) element))
           #f no-srcloc))

(define (rx id) (make-reg 'x id))
(define (rw id) (make-reg 'w id))
(define (rv id [element #f]) (make-reg 'v id element))
(define (rq id) (make-reg 'q id))
(define (rd id) (make-reg 'd id))
(define (rs-reg id) (make-reg 's id))

(define xzr (ast-reg 'x 'zr #f #f #f #f no-srcloc))
(define wzr (ast-reg 'w 'zr #f #f #f #f no-srcloc))
(define rsp (ast-reg 'x 'sp #f #f #f #f no-srcloc))

(define (im v)
  (unless (exact-integer? v)
    (error 'gnu-writer "immediate must be an exact integer: ~a" v))
  (ast-imm v no-srcloc))

(define (lab name)
  (ast-label (if (string? name) (string->symbol name) name) #f no-srcloc))

(define (sh kind [amount #f])
  (unless (memq kind '(lsl lsr asr ror msl))
    (error 'gnu-writer "unknown shift kind: ~a" kind))
  (ast-shift kind amount no-srcloc))

(define (ext kind [amount #f])
  (unless (memq kind '(uxtb uxth uxtw uxtx sxtb sxth sxtw sxtx))
    (error 'gnu-writer "unknown extend kind: ~a" kind))
  (ast-extend kind amount no-srcloc))

(define (cnd code)
  (unless (memq code '(eq ne cs hs cc lo mi pl vs vc hi ls ge lt gt le al nv))
    (error 'gnu-writer "unknown condition code: ~a" code))
  (ast-cond code no-srcloc))

;; [base], [base, #off], [base, xoff]
(define (mem base [offset #f])
  (ast-mem base (normalize-mem-offset offset) 'offset #f #f no-srcloc))

;; [base, #off]!
(define (mem-pre base offset)
  (ast-mem base (normalize-mem-offset offset) 'pre #f #f no-srcloc))

;; [base], #off
(define (mem-post base offset)
  (ast-mem base (normalize-mem-offset offset) 'post #f #f no-srcloc))

(define (normalize-mem-offset offset)
  (cond
    [(not offset) #f]
    [(exact-integer? offset) (ast-imm offset no-srcloc)]
    [(or (ast-imm? offset) (ast-reg? offset)) offset]
    [else (error 'gnu-writer "bad memory offset: ~a" offset)]))

;; { r1, r2, ... }
(define (regs . rs)
  (when (null? rs)
    (error 'gnu-writer "register list cannot be empty"))
  (for ([r (in-list rs)])
    (unless (ast-reg? r)
      (error 'gnu-writer "register list element must be a register: ~a" r)))
  (ast-reglist rs no-srcloc))

;; ============================================================
;; 行构造器
;; ============================================================

;; 注释与空行是纯排版行, 不参与回读比对
(struct gw-comment (kind text) #:transparent)   ; kind: 'doc (;;) | 'line (//)
(struct gw-blank () #:transparent)

;; 指令位置的带量 shift/extend 拆成两个操作数 (ast-shift kind #f) + (ast-imm n),
;; 与 gnu-parser 的表示一致 (见 ast.rkt: "普通指令中 amount 作为独立 ast-imm
;; 跟随"; 内存寻址内 amount 才存在 shift/extend 字段里)。
(define (split-shift-amount op)
  (match op
    [(ast-shift kind (? values amount) _)
     (list (ast-shift kind #f no-srcloc) (ast-imm amount no-srcloc))]
    [(ast-extend kind (? values amount) _)
     (list (ast-extend kind #f no-srcloc) (ast-imm amount no-srcloc))]
    [_ (list op)]))

(define (ins mnemonic #:suffix [suffix #f] . operands)
  (unless (symbol? mnemonic)
    (error 'gnu-writer "mnemonic must be a symbol: ~a" mnemonic))
  (ast-ins mnemonic suffix (append-map split-shift-amount operands) no-srcloc))

(define (lbl name)
  (ast-directive 'label
                 (if (string? name) (string->symbol name) name)
                 '() no-srcloc))

(define (doc . texts) (map (lambda (t) (gw-comment 'doc t)) texts))
(define (rem text) (gw-comment 'line text))
(define blank (gw-blank))

;; .function NAME [export] ( [context c ...,] in: ..., out: ..., inout: ... )
;; params: (listof (list 'in|'out|'inout ast-reg)), 顺序即签名顺序。
(define (fn-begin name
                  #:export? [export? #f]
                  #:in [in-regs '()]
                  #:out [out-regs '()]
                  #:inout [inout-regs '()]
                  #:params [params* #f]
                  #:contexts [contexts '()])
  (define params
    (or params*
        (append (map (lambda (r) (list 'in r)) in-regs)
                (map (lambda (r) (list 'out r)) out-regs)
                (map (lambda (r) (list 'inout r)) inout-regs))))
  (for ([p (in-list params)])
    (match p
      [(list (or 'in 'out 'inout) (? ast-reg? r))
       (unless (symbol? (ast-reg-id r))
         (error 'gnu-writer ".function parameter must be virtual: ~a" (ast->string r)))]
      [_ (error 'gnu-writer "bad .function parameter: ~a" p)]))
  (define attrs0 (hash 'function-params params))
  (define attrs1 (if export? (hash-set attrs0 'export #t) attrs0))
  (define attrs (if (null? contexts) attrs1 (hash-set attrs1 'contexts contexts)))
  (ast-directive 'function
                 (if (string? name) (string->symbol name) name)
                 attrs no-srcloc))

(define (fn-end) (ast-directive 'end-function #f '() no-srcloc))

(define (save-all)    (ast-directive 'save! #f (list 'all (list 'auto)) no-srcloc))
(define (restore-all) (ast-directive 'load! #f (list 'all (list 'auto)) no-srcloc))
(define (save-regs . rs)    (ast-directive 'save! #f (list rs (list 'unlimited)) no-srcloc))
(define (restore-regs . rs) (ast-directive 'load! #f (list rs (list 'unlimited)) no-srcloc))

;; .context NAME (scope S) field=reg ...
;; fields: (listof (cons field-symbol phys-ast-reg)), 声明序即渲染序。
(define (ctx-decl name fields #:scope [scope 'library])
  (unless (memq scope '(library process signal))
    (error 'gnu-writer ".context scope must be library/process/signal: ~a" scope))
  (for ([f (in-list fields)])
    (match f
      [(cons (? symbol?) (? ast-reg? r))
       (unless (number? (ast-reg-id r))
         (error 'gnu-writer ".context field ~a must map to a physical register" (car f)))]
      [_ (error 'gnu-writer "bad .context field: ~a" f)]))
  (ast-directive 'context
                 (if (string? name) (string->symbol name) name)
                 (list scope fields) no-srcloc))

;; ============================================================
;; srcloc 剥离 (结构比较用)
;; ============================================================

(define (ast-strip-loc x)
  (match x
    [(ast-reg k i g ix e p _) (ast-reg k i g ix e p no-srcloc)]
    [(ast-imm v _) (ast-imm v no-srcloc)]
    [(ast-label n r _) (ast-label n r no-srcloc)]
    [(ast-shift k a _) (ast-shift k a no-srcloc)]
    [(ast-extend k a _) (ast-extend k a no-srcloc)]
    [(ast-cond c _) (ast-cond c no-srcloc)]
    [(ast-mem b o m s e _)
     (ast-mem (ast-strip-loc b)
              (and o (ast-strip-loc o))
              m
              (and s (ast-strip-loc s))
              (and e (ast-strip-loc e))
              no-srcloc)]
    [(ast-reglist rs _) (ast-reglist (map ast-strip-loc rs) no-srcloc)]
    [(ast-ins m s ops _) (ast-ins m s (map ast-strip-loc ops) no-srcloc)]
    [(ast-directive k n args _)
     (ast-directive k n (ast-strip-loc args) no-srcloc)]
    [(? hash?)
     (for/hash ([(k v) (in-hash x)]) (values k (ast-strip-loc v)))]
    [(? list?) (map ast-strip-loc x)]
    [(cons a d) (cons (ast-strip-loc a) (ast-strip-loc d))]
    [_ x]))

;; ============================================================
;; 渲染: 操作数
;; ============================================================

(define (reg->text r)
  (match-define (ast-reg kind id group-size index element pred-mode _) r)
  (when (or group-size index)
    (error 'gnu-writer "register group syntax not supported by writer: ~a" (ast->string r)))
  (define prefix (symbol->string kind))
  (define base
    (match id
      ['sp (if (eq? kind 'x) "sp" "wsp")]
      ['zr (if (eq? kind 'x) "xzr" "wzr")]
      [(? symbol? name) (string-append prefix "." (symbol->string name))]
      [(? number? n) (string-append prefix (number->string n))]))
  (define with-elem
    (if element (string-append base "." (symbol->string element)) base))
  (if pred-mode
      (string-append with-elem "/" (symbol->string pred-mode))
      with-elem))

(define (operand->text op)
  (match op
    [(? ast-reg?) (reg->text op)]
    [(ast-imm v _) (string-append "#" (number->string v))]
    [(ast-label name reloc _)
     (when reloc
       (error 'gnu-writer "relocation operands not supported by writer: ~a" name))
     (symbol->string name)]
    [(ast-shift kind amount _)
     (if amount
         (format "~a #~a" kind amount)
         (symbol->string kind))]
    [(ast-extend kind amount _)
     (if amount
         (format "~a #~a" kind amount)
         (symbol->string kind))]
    [(ast-cond code _) (symbol->string code)]
    [(ast-mem base offset index-mode shift extend _)
     (define inner
       (string-join
        (filter values
                (list (reg->text base)
                      (and offset (operand->text offset))
                      (and shift (operand->text shift))
                      (and extend (operand->text extend))))
        ", "))
     (case index-mode
       [(offset) (format "[~a]" inner)]
       [(pre) (format "[~a]!" inner)]
       [(post) (format "[~a], ~a"
                       (reg->text base)
                       (operand->text offset))]
       [else (error 'gnu-writer "unsupported memory index mode: ~a" index-mode)])]
    [(ast-reglist rs _)
     (format "{ ~a }" (string-join (map reg->text rs) ", "))]
    [_ (error 'gnu-writer "unsupported operand: ~a" op)]))

;; ============================================================
;; 渲染: 指令与指示
;; ============================================================

;; 操作数连接规则与 codegen/emit.rkt 一致: shift/extend 之后的操作数
;; 用空格连接 (movk x1, #5, lsl #16 中 lsl 与 #16), 其余用 ", "。
(define (ins->text i indent)
  (match-define (ast-ins mnem suffix operands _) i)
  (define head
    (if suffix
        (format "~a~a.~a" indent mnem suffix)
        (format "~a~a" indent mnem)))
  (if (null? operands)
      head
      (string-append
       head " "
       (let loop ([ops operands] [prev #f] [acc '()])
         (match ops
           ['() (apply string-append (reverse acc))]
           [(cons op rest)
            (define sep
              (cond [(null? acc) ""]
                    [(or (ast-shift? prev) (ast-extend? prev)) " "]
                    [else ", "]))
            (loop rest op (cons (string-append sep (operand->text op)) acc))])))))

;; 参数列表 → "in: x.r, x.a, out: x.q" (模式变化处标注模式)
(define (params->text params)
  (let loop ([ps params] [mode #f] [acc '()])
    (match ps
      ['() (string-join (reverse acc) ", ")]
      [(cons (list m r) rest)
       (define piece
         (if (eq? m mode)
             (reg->text r)
             (format "~a: ~a" m (reg->text r))))
       (loop rest m (cons piece acc))])))

(define supported-function-attrs '(function-params export contexts align))

(define (directive->lines d indent)
  (match d
    [(ast-directive 'function name attrs _)
     (for ([k (in-hash-keys attrs)])
       (unless (memq k supported-function-attrs)
         (error 'gnu-writer ".function attribute not supported by writer: ~a" k)))
     (when (hash-ref attrs 'align #f)
       (error 'gnu-writer ".function align attribute not supported by writer"))
     (define export? (hash-ref attrs 'export #f))
     (define contexts (hash-ref attrs 'contexts '()))
     (define params (hash-ref attrs 'function-params '()))
     (define head (format ".function ~a~a" name (if export? " export" "")))
     (define ctx-part
       (and (not (null? contexts))
            (format "context ~a"
                    (string-join (map symbol->string contexts) " "))))
     (cond
       ;; 语料风格 1: 无参数 → 单行 (上下文内核)
       [(null? params)
        (if ctx-part
            (list (format "~a (~a)" head ctx-part))
            (list (format "~a ()" head)))]
       ;; 语料风格 2: 有参数、无上下文 → 三行头 (导出内核)
       [(null? contexts)
        (list (format "~a (" head)
              (format "~a~a" indent (params->text params))
              ")")]
       ;; 一般式: 单行
       [else
        (list (format "~a ( ~a, ~a )" head ctx-part (params->text params)))])]
    [(ast-directive 'end-function _ _ _) (list ".end")]
    [(ast-directive 'label name _ _) (list (format "~a:" name))]
    [(ast-directive (and kind (or 'save! 'load!)) _ (list spec _) _)
     (define word (if (eq? kind 'save!) ".save" ".restore"))
     (define arg
       (match spec
         ['all "all"]
         [(? list? rs) (string-join (map reg->text rs) ", ")]
         [_ (error 'gnu-writer "bad ~a spec: ~a" word spec)]))
     (list (format "~a~a ~a" indent word arg))]
    [(ast-directive 'context name (list scope fields) _)
     (list (format ".context ~a (scope ~a) ~a"
                   name scope
                   (string-join
                    (for/list ([f (in-list fields)])
                      (format "~a=~a" (car f) (reg->text (cdr f))))
                    " ")))]
    ;; M3 frame directives (see parser/gnu-parser.rkt parse-frame/alloca-directive)
    [(ast-directive 'frame _ (list local-bytes) _)
     (list (format "~a.frame ~a" indent local-bytes))]
    [(ast-directive 'alloca _ (list reg shift) _)
     (list (format "~a.alloca ~a, ~a" indent (reg->text reg) shift))]
    ;; .align / .p2align (parser folds both to 'align; body alignment before hot loops)
    [(ast-directive 'align _ (list n) _)
     (list (format "~a.align ~a" indent n))]
    [(ast-directive kind _ _ _)
     (error 'gnu-writer "directive not supported by writer: .~a" kind)]))

;; 单个"行值" → (listof string)。string 直接透传 (逃生舱, 仍受回读校验)。
(define (gnu-line->lines line indent)
  (match line
    [(? string?) (list line)]
    [(gw-blank) (list "")]
    [(gw-comment 'doc text) (list (format ";; ~a" text))]
    [(gw-comment 'line text) (list (format "~a// ~a" indent text))]
    [(? ast-ins?) (list (ins->text line indent))]
    [(? ast-directive?) (directive->lines line indent)]
    [_ (error 'gnu-writer "unsupported program line: ~a" line)]))

;; ============================================================
;; 程序序列化 + 回读自校验
;; ============================================================

;; lines 可嵌套列表 (doc 返回列表), 先展平。
(define (flatten-lines lines)
  (for/fold ([acc '()] #:result (reverse acc))
            ([l (in-list lines)])
    (if (list? l)
        (append (reverse (flatten-lines l)) acc)
        (cons l acc))))

(define (program-ast-items lines)
  (filter (lambda (l) (or (ast-ins? l) (ast-directive? l)))
          lines))

;; 回读校验: 序列化文本 → gnu-parser → 与构造的 AST 逐条比对 (忽略 srcloc)。
;; 纯文本行 (逃生舱 string) 也会被解析并计入回读侧, 因此构造侧无法预期它们;
;; 含 string 行的程序跳过逐条比对, 只做"可解析"校验。
(define (check-program lines text)
  (define results (parse-string text #:source 'gnu-writer #:syntax 'gnu))
  (when (parse-results-has-errors? results)
    (error 'gnu-writer
           "serialized program does not reparse:\n~a"
           (format-parse-errors-report results)))
  (define has-raw? (ormap string? lines))
  (unless has-raw?
    (define expected (map ast-strip-loc (program-ast-items lines)))
    (define got
      (map ast-strip-loc
           (filter values
                   (map parse-result-instruction
                        (parse-results-filter-ok results)))))
    (unless (= (length expected) (length got))
      (error 'gnu-writer
             "reparse item count mismatch: built ~a, reparsed ~a"
             (length expected) (length got)))
    (for ([e (in-list expected)]
          [g (in-list got)]
          [i (in-naturals)])
      (unless (equal? e g)
        (error 'gnu-writer
               "reparse mismatch at item ~a:\n  built:    ~a\n  reparsed: ~a"
               i (ast->string e) (ast->string g))))))

(define (gnu-program->string lines0
                             #:indent [indent "  "]
                             #:check? [check? #t])
  (define lines (flatten-lines lines0))
  (define text
    (string-append
     (string-join
      (append* (for/list ([l (in-list lines)]) (gnu-line->lines l indent)))
      "\n")
     "\n"))
  (when check?
    (check-program lines text))
  text)

(define (write-gnu-program path lines
                           #:indent [indent "  "]
                           #:check? [check? #t])
  (define text (gnu-program->string lines #:indent indent #:check? check?))
  (call-with-output-file path
    (lambda (out) (write-string text out))
    #:exists 'truncate/replace)
  (void))

;; ============================================================
;; 语料解析助手
;; ============================================================

;; 解析 .asm 文件为剥 loc 的 AST 条目列表; 解析错误即报。
;; 用途: 语料往返测试; 迁移期新旧 .asm 的 AST 级对拍。
(define (parse-gnu-file->items path)
  (define results (parse-file path #:syntax 'gnu))
  (when (parse-results-has-errors? results)
    (error 'gnu-writer "parse errors in ~a:\n~a"
           path (format-parse-errors-report results)))
  (map ast-strip-loc
       (filter values
               (map parse-result-instruction
                    (parse-results-filter-ok results)))))
