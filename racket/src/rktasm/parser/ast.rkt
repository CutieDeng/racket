#lang racket

(provide
  ;; 源位置
  (struct-out srcloc)
  no-srcloc

  ;; AST 类型
  (struct-out ast-reg)
  (struct-out ast-imm)
  (struct-out ast-label)
  (struct-out ast-shift)
  (struct-out ast-extend)
  (struct-out ast-mem)
  (struct-out ast-reglist)
  (struct-out ast-cond)
  (struct-out ast-ins)
  (struct-out ast-directive)

  ;; 契约
  reg-kind/c
  shift-kind/c
  extend-kind/c
  cond-code/c
  index-mode/c
  pred-mode/c
  reloc-kind/c
  directive-kind/c

  ;; 工具函数
  ast->string
  ast-srcloc)

;; ============================================================
;; 源位置信息
;; ============================================================

;; 源位置: 文件名、行号、列号、位置、长度
(struct srcloc (source line column position span) #:transparent)

;; 空位置 (用于测试或无位置信息时)
(define no-srcloc (srcloc #f #f #f #f #f))

;; ============================================================
;; AST 定义 - Lisp 风格汇编语法
;; ============================================================
;;
;; 设计原则:
;; - 纯语法解析，不关心语义约束
;; - shift/extend 的 kind 和 amount 分离为独立节点
;; - 寄存器支持组大小 (*n) 和索引 (@n)
;; - 所有节点携带源位置信息
;;
;; 寄存器语法: <kind><id>[*<count>][@<index>][.<element>][/<pred-mode>]
;;   物理: x0, z31.B, p7/m, z0*4@2.D
;;   虚拟: x.name, z.vec*4@2.D, p.mask/z

;; ============================================================
;; 契约定义
;; ============================================================

(define reg-kind/c (or/c 'x 'w 'z 'v 'p 'b 'h 's 'd 'q))
(define shift-kind/c (or/c 'lsl 'lsr 'asr 'ror 'msl))
(define extend-kind/c (or/c 'uxtb 'uxth 'uxtw 'uxtx 'sxtb 'sxth 'sxtw 'sxtx))
(define cond-code/c (or/c 'eq 'ne 'cs 'hs 'cc 'lo 'mi 'pl
                          'vs 'vc 'hi 'ls 'ge 'lt 'gt 'le 'al 'nv))
(define index-mode/c (or/c 'offset 'pre 'post))
(define pred-mode/c (or/c #f 'm 'z))
(define reloc-kind/c (or/c #f 'PAGE 'PAGEOFF 'GOTPAGE 'GOTPAGEOFF))
(define directive-kind/c
  (or/c 'function 'end-function 'label 'section 'align 'global 'extern
        'ascii 'asciz 'byte 'byte2 'byte4 'byte8 'byte16 'byte32
        'save! 'load! 'weak-mov 'inline 'call 'context
        'frame 'alloca))

;; ============================================================
;; AST 结构 (所有节点携带 srcloc)
;; ============================================================

;; 寄存器
;; kind: 'x 'w 'z 'v 'p 'b 'h 's 'd 'q
;; id: number (物理) | symbol (虚拟) | 'sp | 'zr
;; group-size: number | #f (连续寄存器组大小, *n)
;; index: number | #f (组内索引, @n)
;; element: symbol | #f (元素大小: 'B 'H 'S 'D 'Q 或排列 '4s '2d 等)
;; pred-mode: 'm | 'z | #f (谓词模式)
;; loc: srcloc
(struct ast-reg (kind id group-size index element pred-mode loc) #:transparent)

;; 立即数
(struct ast-imm (value loc) #:transparent)

;; 标签/符号 (可带 relocation 修饰符)
;; reloc: #f | 'PAGE | 'PAGEOFF | 'GOTPAGE | 'GOTPAGEOFF
;;   Apple 语法: sym@PAGE / sym@PAGEOFF / sym@GOTPAGE / sym@GOTPAGEOFF
;;   GNU 语法:   :pg_hi21:sym / :lo12:sym / :got:sym / :got_lo12:sym
(struct ast-label (name reloc loc) #:transparent)

;; 移位 (kind + 可选的 amount)
;; 普通指令中 amount 作为独立 ast-imm 跟随
;; 内存寻址中 amount 存在此字段
(struct ast-shift (kind amount loc) #:transparent)

;; 扩展 (kind + 可选的 amount)
;; 普通指令中 amount 作为独立 ast-imm 跟随
;; 内存寻址中 amount 存在此字段
(struct ast-extend (kind amount loc) #:transparent)

;; 条件码
(struct ast-cond (code loc) #:transparent)

;; 内存寻址
;; base: ast-reg
;; offset: ast-reg | ast-imm | #f
;; index-mode: 'offset | 'pre | 'post
;; shift: ast-shift | #f
;; extend: ast-extend | #f
;; loc: srcloc
(struct ast-mem (base offset index-mode shift extend loc) #:transparent)

;; 寄存器列表 (显式 { reg ... })
(struct ast-reglist (regs loc) #:transparent)

;; 指令
;; mnemonic: symbol
;; suffix: symbol | #f (条件后缀，如 b.eq 中的 'eq)
;; operands: list
;; loc: srcloc
(struct ast-ins (mnemonic suffix operands loc) #:transparent)

;; 元语法指令 (directives)
;; kind: 'function | 'end-function | 'label | 'section | 'align | 'global
;; name: symbol | #f
;; args: (listof any) - 额外参数
;; loc: srcloc
(struct ast-directive (kind name args loc) #:transparent)

;; ============================================================
;; 获取 AST 节点的 srcloc
;; ============================================================

(define (ast-srcloc node)
  (match node
    [(ast-reg _ _ _ _ _ _ loc) loc]
    [(ast-imm _ loc) loc]
    [(ast-label _ _ loc) loc]
    [(ast-shift _ _ loc) loc]
    [(ast-extend _ _ loc) loc]
    [(ast-cond _ loc) loc]
    [(ast-mem _ _ _ _ _ loc) loc]
    [(ast-reglist _ loc) loc]
    [(ast-ins _ _ _ loc) loc]
    [(ast-directive _ _ _ loc) loc]
    [_ no-srcloc]))

;; ============================================================
;; 字符串转换 (用于调试输出)
;; ============================================================

(define (reg-kind->prefix kind)
  (match kind
    ['x "x"] ['w "w"] ['z "z"] ['v "v"] ['p "p"]
    ['b "b"] ['h "h"] ['s "s"] ['d "d"] ['q "q"]))

(define (ast-reg->string r)
  (match-define (ast-reg kind id group-size index element pred-mode _) r)
  (define base
    (match id
      ['sp (if (eq? kind 'x) "sp" "wsp")]
      ['zr (if (eq? kind 'x) "xzr" "wzr")]
      [(? symbol? name) (format "~a.~a" (reg-kind->prefix kind) name)]
      [(? number? n) (format "~a~a" (reg-kind->prefix kind) n)]))
  (define with-group
    (match group-size
      [#f base]
      [n (format "~a*~a" base n)]))
  (define with-index
    (match index
      [#f with-group]
      [n (format "~a@~a" with-group n)]))
  (define with-elem
    (match element
      [#f with-index]
      [e (format "~a.~a" with-index e)]))
  (match pred-mode
    [#f with-elem]
    [m (format "~a/~a" with-elem m)]))

(define (ast->string node)
  (match node
    [(ast-reg _ _ _ _ _ _ _) (ast-reg->string node)]
    [(ast-imm v _) (format "#~a" v)]
    [(ast-label name reloc _)
     (if reloc
         (format "~a@~a" name reloc)
         (symbol->string name))]
    [(ast-shift kind amount _)
     (if amount
         (format "~a #~a" (symbol->string kind) amount)
         (symbol->string kind))]
    [(ast-extend kind amount _)
     (if amount
         (format "~a #~a" (symbol->string kind) amount)
         (symbol->string kind))]
    [(ast-cond code _) (symbol->string code)]
    [(ast-mem base offset index-mode shift extend _)
     (define inner-parts
       (filter values
               (list (ast->string base)
                     (and offset (ast->string offset))
                     (and shift (ast->string shift))
                     (and extend (ast->string extend)))))
     (define inner (string-join inner-parts " "))
     (match index-mode
       ['offset (format "(~a)" inner)]
       ['pre (format "(~a !)" inner)]
       ['post (format "(~a) post" inner)])]
    [(ast-reglist regs _)
     (format "{ ~a }" (string-join (map ast->string regs) " "))]
    [(ast-ins mnem suffix operands _)
     (define mnem-str
       (match suffix
         [#f (symbol->string mnem)]
         [s (format "~a.~a" mnem s)]))
     (match operands
       ['() (format "(~a)" mnem-str)]
       [ops (format "(~a ~a)" mnem-str (string-join (map ast->string ops) " "))])]
    [(ast-directive kind name args _)
     (match* (kind name args)
       [('function n attrs)
        (define attr-str
          (if (and (hash? attrs) (> (hash-count attrs) 0))
              (string-join
               (for/list ([(k v) (in-hash attrs)])
                 (if (eq? v #t)
                     (format "(~a)" k)
                     (format "(~a ~a)" k v)))
               " ")
              ""))
        (if (string=? attr-str "")
            (format "(: function ~a)" n)
            (format "(: function ~a ~a)" n attr-str))]
       [('end-function #f _) "(: end-function)"]
       [('label n _) (format "(: label ~a)" n)]
       [('section n _) (format "(: section ~a)" n)]
       [('align #f (list n)) (format "(: align ~a)" n)]
       [('global n _) (format "(: global ~a)" n)]
       [(_ n args)
        (if n
            (format "(: ~a ~a~a)" kind n
                    (if (null? args) "" (format " ~a" (string-join (map ~a args) " "))))
            (format "(: ~a~a)" kind
                    (if (null? args) "" (format " ~a" (string-join (map ~a args) " ")))))])]))
