#lang racket

;; ============================================================
;; semantic/control-flow.rkt - 控制流分析 (MultiGraph 版)
;; ============================================================
;;
;; 使用 core 持久化数据结构 (原 vendor cutie-ftree, 已吸收进 core)：
;;   - racket/graph: 存储控制流边
;;   - racket/pvector: 指令序列
;;   - racket/intmap / 不可变 hash: ID -> 数据 映射
;;
;; 设计原则：
;;   - basic-block 只存核心数据 (id, instructions) + 扩展 (debug, info)
;;   - asm-function 用 graph 管理边，维护 bb-id <-> label 双向映射
;;   - 所有 bb-id 统一封装为 (bb-id val) 类型

(require "../parser/ast.rkt"
         "function-identity.rkt"
         "../syntax/operand-type.rkt"
         (only-in "use-def.rkt"
                  extract-use-def
                  use-def-flat-defs
                  reg-ref-id
                  reg-ref-position)
         "branch-info.rkt"
         racket/pvector
         racket/intmap
         racket/intbits
         racket/graph)

(provide
  ;; ID 类型
  (struct-out bb-id)
  bb-id-compare

  ;; 数据结构
  (struct-out function-version)
  make-canonical-function-version
  make-clone-function-version
  default-clone-linkage-symbol
  function-version-clone?
  function-version-display-name
  (struct-out bb-debug)
  (struct-out basic-block)
  (struct-out fn-debug)
  (struct-out asm-function)
  (struct-out cfg-debug)
  (struct-out control-flow-graph)

  ;; 常量
  bb-debug-empty
  fn-debug-empty
  cfg-debug-empty
  default-public-abi-profile
  known-public-abi-profiles
  known-public-abi-profile?

  ;; 基本块操作
  make-basic-block
  bb-set-info
  bb-get-info
  bb-has-info?
  bb-label        ; 从 debug 获取 label

  ;; 函数操作
  fn-set-info
  fn-get-info
  fn-public-abi-root?
  fn-public-header?
  fn-public-abi-barrier?
  fn-public-abi-profile
  fn-public-abi-profile-explicit?
  fn-function-version
  fn-logical-name
  fn-linkage-symbol
  fn-debug-display-name
  fn-with-function-version
  fn-clone-version
  fn-get-label    ; bb-id -> symbol | #f
  fn-get-id       ; symbol -> bb-id | #f

  ;; CFG 操作
  cfg-set-info
  cfg-get-info

  ;; 构建
  build-cfg
  cfg-empty

  ;; 查询 - CFG 级别
  cfg-get-function
  cfg-get-function-by-name
  cfg-function-count

  ;; 查询 - Function 级别
  fn-get-block
  fn-get-block-by-label
  fn-block-count
  fn-entry-block
  fn-exit-blocks
  fn-successors
  fn-predecessors

  ;; 遍历
  cfg-for-each-function
  fn-for-each-block
  fn-dfs
  fn-bfs

  ;; 格式化
  format-cfg
  format-cfg-function
  format-cfg-dot
  format-function-dot

  ;; 验证
  verify-label-references       ; fn cfg -> pvector of label-ref-error
  (struct-out label-ref-error)  ; 标签引用错误信息
  verify-sp-write-discipline    ; fn -> pvector of sp-write-error
  (struct-out sp-write-error)   ; 源码层直接写 SP 的诊断信息

  ;; 符号名验证
  valid-asm-symbol?             ; symbol -> boolean
  verify-symbol-names           ; fn -> pvector of symbol-name-error
  (struct-out symbol-name-error) ; 符号名错误信息
  sanitize-symbol               ; symbol -> string (转换不合法字符)

  ;; Pedantic 检查
  check-linear-fallthrough      ; fn -> (or/c linear-fallthrough-warning? #f)
  (struct-out linear-fallthrough-warning)
  )

;; ============================================================
;; ID 类型
;; ============================================================

(struct bb-id (val) #:transparent)

(define (bb-id-compare a b)
  (let ([av (bb-id-val a)] [bv (bb-id-val b)])
    (cond
      [(< av bv) '<]
      [(= av bv) '=]
      [else '>])))

;; ============================================================
;; 数据结构
;; ============================================================

;; 块调试信息 (包含 label)
(struct bb-debug
  (label          ; symbol | #f - 源码标签
   stx-begin      ; srcloc | #f - 块起始位置
   stx-end)       ; srcloc | #f - 块结束位置
  #:transparent)

(define bb-debug-empty (bb-debug #f #f #f))

;; 基本块
(struct basic-block
  (id             ; bb-id
   instructions   ; pvector of ast-ins
   debug          ; bb-debug
   info)          ; hasheq[symbol -> any]
  #:transparent)

;; 创建基本块
(define (make-basic-block id instructions
                          #:label [label #f]
                          #:stx-begin [stx-begin #f]
                          #:stx-end [stx-end #f]
                          #:info [info (hasheq)])
  (basic-block id instructions (bb-debug label stx-begin stx-end) info))

;; 块操作
(define (bb-set-info block key value)
  (struct-copy basic-block block
               [info (hash-set (basic-block-info block) key value)]))

(define (bb-get-info block key [default #f])
  (hash-ref (basic-block-info block) key default))

(define (bb-has-info? block key)
  (hash-has-key? (basic-block-info block) key))

(define (bb-label block)
  (bb-debug-label (basic-block-debug block)))

;; ============================================================
;; 函数结构
;; ============================================================

;; 函数调试信息
(struct fn-debug
  (stx-begin      ; srcloc | #f
   stx-end)       ; srcloc | #f
  #:transparent)

(define fn-debug-empty (fn-debug #f #f))

;; 汇编函数
(struct asm-function
  (id             ; 函数 ID (整数)
   name           ; symbol
   entry          ; bb-id | #f
   graph          ; graph (控制流边, 内部用 vertex-id)
   blocks         ; intmap[bb-id-val -> basic-block]
   id->label      ; intmap[bb-id-val -> symbol]
   label->id      ; hasheq[symbol -> bb-id]
   vid->bbid      ; intmap[vertex-id-val -> bb-id] (graph 内部映射)
   bbid->vid      ; intmap[bb-id-val -> vertex-id]
   debug          ; fn-debug
   info)          ; hasheq[symbol -> any]
  #:transparent)

;; 函数操作
(define (fn-set-info fn key value)
  (struct-copy asm-function fn
               [info (hash-set (asm-function-info fn) key value)]))

(define (fn-remove-info fn key)
  (if (hash-has-key? (asm-function-info fn) key)
      (struct-copy asm-function fn
                   [info (hash-remove (asm-function-info fn) key)])
      fn))

(define (fn-remove-info* fn keys)
  (for/fold ([fn* fn])
            ([key (in-list keys)])
    (fn-remove-info fn* key)))

(define (fn-get-info fn key [default #f])
  (hash-ref (asm-function-info fn) key default))

(define (fn-public-abi-root? fn)
  (and (fn-get-info fn 'public-abi-root? #f) #t))

(define (fn-public-header? fn)
  (and (fn-public-abi-root? fn)
       (fn-get-info fn 'public-header? #t)
       #t))

(define (fn-public-abi-barrier? fn)
  (and (fn-public-abi-root? fn)
       (fn-public-header? fn)
       #t))

(define (fn-public-abi-profile fn)
  (fn-get-info fn 'public-abi-profile #f))

(define (fn-public-abi-profile-explicit? fn)
  (and (fn-get-info fn 'public-abi-profile-explicit? #f) #t))

(define (fn-function-version fn)
  (or (fn-get-info fn 'function-version #f)
      (make-canonical-function-version
       (asm-function-name fn)
       #:linkage-symbol (asm-function-name fn))))

(define (fn-logical-name fn)
  (function-version-logical-name (fn-function-version fn)))

(define (fn-linkage-symbol fn)
  (function-version-linkage-symbol (fn-function-version fn)))

(define (fn-debug-display-name fn)
  (function-version-display-name (fn-function-version fn)))

(define (fn-with-function-version fn version)
  (struct-copy asm-function fn
               [name (function-version-linkage-symbol version)]
               [info (hash-set (asm-function-info fn)
                                      'function-version
                                      version)]))

(define public-boundary-info-keys
  '(export
    profile
    public-abi-profile
    public-abi-profile-explicit?
    public-header?
    public-abi-root?
    export-profile))

(define (fn-clone-version fn
                          #:version-id version-id
                          #:version-kind [version-kind 'clone]
                          #:clone-reason [clone-reason 'unspecified]
                          #:specialization-key [specialization-key #f]
                          #:linkage-symbol [linkage-symbol
                                            (default-clone-linkage-symbol
                                             (fn-logical-name fn)
                                             version-id)])
  (fn-with-function-version
   (fn-remove-info* fn public-boundary-info-keys)
   (make-clone-function-version
    (fn-function-version fn)
    #:version-id version-id
    #:version-kind version-kind
    #:clone-reason clone-reason
    #:specialization-key specialization-key
    #:linkage-symbol linkage-symbol)))

(define (fn-get-label fn bbid)
  (define key (if (bb-id? bbid) (bb-id-val bbid) bbid))
  (intmap-ref (asm-function-id->label fn) key #f))

(define (fn-get-id fn label)
  (hash-ref (asm-function-label->id fn) label #f))

;; ============================================================
;; CFG 结构
;; ============================================================

(struct cfg-debug
  (build-time     ; number | #f
   source-hash)   ; string | #f
  #:transparent)

(define cfg-debug-empty (cfg-debug #f #f))

(struct control-flow-graph
  (source         ; path-string | symbol
   functions      ; intmap[fn-id -> asm-function]
   fn-names       ; hasheq[symbol -> fn-id]
   next-fn-id     ; 下一个函数 ID
   debug          ; cfg-debug
   info)          ; hasheq[symbol -> any]
  #:transparent)

(define (cfg-set-info cfg key value)
  (struct-copy control-flow-graph cfg
               [info (hash-set (control-flow-graph-info cfg) key value)]))

(define (cfg-get-info cfg key [default #f])
  (hash-ref (control-flow-graph-info cfg) key default))

(define (cfg-empty [source 'unknown])
  (control-flow-graph
   source
   intmap-empty
   (hasheq)
   0
   cfg-debug-empty
   (hasheq)))

(define default-public-abi-profile 'c-aapcs64)

(define known-public-abi-profiles
  '(c-aapcs64
    apple-c-arm64
    linux-syscall
    kernel-aarch64
    jit-private
    project-abi))

(define (known-public-abi-profile? profile)
  (and (symbol? profile)
       (if (memq profile known-public-abi-profiles) #t #f)))

(define (hash-remove* h keys)
  (for/fold ([h* h])
            ([key (in-list keys)])
    (hash-remove h* key)))

(define (function-public-profile attrs)
  (or (hash-ref attrs 'profile #f)
      (hash-ref attrs 'public-abi-profile #f)
      (hash-ref attrs 'export-profile #f)))

(define known-symbol-visibilities '(public hidden local))
(define known-symbol-bindings '(weak))

(define (known-symbol-visibility? visibility)
  (and (symbol? visibility)
       (if (memq visibility known-symbol-visibilities) #t #f)))

(define (header-attr-value->boolean value name)
  (cond
    [(boolean? value) value]
    [(symbol? value)
     (case value
       [(true yes on 1 header) #t]
       [(false no off 0 none) #f]
       [else
        (error 'control-flow
               ".function ~a header expects true/false, got: ~a"
               name
               value)])]
    [else
     (error 'control-flow
            ".function ~a header expects true/false, got: ~v"
            name
            value)]))

(define (function-public-header-attr attrs name)
  (define has-header? (hash-has-key? attrs 'header))
  (define has-public-header? (hash-has-key? attrs 'public-header?))
  (define no-header? (or (hash-ref attrs 'no-header #f)
                         (hash-ref attrs 'noheader #f)))
  (when (and (or has-header? has-public-header?) no-header?)
    (error 'control-flow
           ".function ~a cannot combine header and no-header"
           name))
  (cond
    [has-public-header?
     (values #t (header-attr-value->boolean (hash-ref attrs 'public-header?) name))]
    [has-header?
     (values #t (header-attr-value->boolean (hash-ref attrs 'header) name))]
    [no-header? (values #t #f)]
    [else (values #f #f)]))

(define (normalize-function-visibility attrs name)
  (define visibility (hash-ref attrs 'visibility #f))
  (when (and visibility (not (known-symbol-visibility? visibility)))
    (error 'control-flow
           ".function ~a uses unknown visibility: ~a"
           name
           visibility))
  visibility)

(define (normalize-function-binding attrs name)
  (define binding (hash-ref attrs 'binding #f))
  (when (and binding
             (not (and (symbol? binding)
                       (if (memq binding known-symbol-bindings) #t #f))))
    (error 'control-flow
           ".function ~a uses unknown binding: ~a"
           name
           binding))
  binding)

(define (normalize-function-public-abi attrs name)
  (define export? (hash-ref attrs 'export #f))
  (define profile (function-public-profile attrs))
  (define visibility (normalize-function-visibility attrs name))
  (define binding (normalize-function-binding attrs name))
  (define-values (has-public-header-attr? public-header?)
    (function-public-header-attr attrs name))
  (when (and profile (not export?))
    (error 'control-flow
           ".function ~a uses profile=~a without export"
           name
           profile))
  (when (and profile (not (symbol? profile)))
    (error 'control-flow
           ".function ~a profile expects profile=<name>, got: ~v"
           name
           profile))
  (when (and profile (not (known-public-abi-profile? profile)))
    (error 'control-flow
           ".function ~a uses unknown public ABI profile: ~a"
           name
           profile))
  (define explicit-profile? (and profile #t))
  (define attrs/base
    (hash-remove* attrs
                  '(profile
                    public-abi-profile
                    export-profile
                    header
                    no-header
                    noheader
                    public-header?)))
  (define attrs/visibility
    (if visibility
        (hash-set attrs/base 'visibility visibility)
        attrs/base))
  (define attrs/binding
    (if binding
        (hash-set attrs/visibility 'binding binding)
        attrs/visibility))
  (define attrs/header
    (if has-public-header-attr?
        (hash-set attrs/binding 'public-header? public-header?)
        attrs/binding))
  (if export?
      (hash-set (hash-set
                 (hash-set attrs/header
                           'public-abi-profile
                           (or profile default-public-abi-profile))
                 'public-abi-profile-explicit?
                 explicit-profile?)
                'public-abi-root? #t)
      attrs/base))

(define (function-variant-specialization-key attrs)
  (define feature (hash-ref attrs 'target-feature #f))
  (and feature
       (list 'target-feature feature)))

(define (make-source-function-version name attrs loc)
  (define logical-name (hash-ref attrs 'variant-of #f))
  (define version-id (hash-ref attrs 'version-id #f))
  (when (and version-id (not logical-name))
    (error 'control-flow
           ".function ~a uses version=~a without variant-of=<logical-function>"
           name
           version-id))
  (when (and logical-name (equal? logical-name name))
    (error 'control-flow
           ".function ~a cannot be a variant of itself"
           name))
  (if logical-name
      (make-clone-function-version
       (make-canonical-function-version logical-name
                                        #:debug-origin loc
                                        #:linkage-symbol logical-name)
       #:version-id (or version-id name)
       #:version-kind 'source-variant
       #:clone-reason 'handwritten
       #:specialization-key (function-variant-specialization-key attrs)
       #:debug-origin loc
       #:linkage-symbol name)
      (make-canonical-function-version name
                                       #:debug-origin loc
                                       #:linkage-symbol name)))

(define function-clone-groups-info-key 'function-clone-groups)

(define (append-unique xs x)
  (if (member x xs)
      xs
      (append xs (list x))))

(define (front-unique xs x)
  (cons x (filter (lambda (item) (not (equal? item x))) xs)))

(define (cfg-record-function-version-group cfg fn)
  (define version (fn-function-version fn))
  (define logical-name (function-version-logical-name version))
  (define groups (cfg-get-info cfg function-clone-groups-info-key (hash)))
  (define existing (hash-ref groups logical-name '()))
  (define updated
    (cond
      [(function-version-canonical? version)
       (and (hash-has-key? groups logical-name)
            (front-unique existing logical-name))]
      [else
       (define with-canonical
         (if (cfg-get-function-by-name cfg logical-name)
             (append-unique existing logical-name)
             existing))
       (append-unique with-canonical (asm-function-name fn))]))
  (if updated
      (cfg-set-info cfg function-clone-groups-info-key
                    (hash-set groups logical-name updated))
      cfg))

(define module-directive-kinds
  '(section align global label ascii asciz byte byte2 byte4 byte8 byte16 byte32))

(define (module-directive? item)
  (and (ast-directive? item)
       (memq (ast-directive-kind item) module-directive-kinds)))

(define (append-module-item cfg item)
  (define items (cfg-get-info cfg 'module-items '()))
  (cfg-set-info cfg 'module-items (append items (list item))))

(define (drop-function-global-module-items cfg)
  (define function-names
    (for/set ([kv (in-hash-pairs (control-flow-graph-fn-names cfg))])
      (car kv)))
  (define items
    (filter (lambda (item)
              (not (match item
                     [(ast-directive 'global name _ _)
                      (set-member? function-names name)]
                     [_ #f])))
            (cfg-get-info cfg 'module-items '())))
  (cfg-set-info cfg 'module-items items))

(define (extern-arg-kind args)
  (if (and (list? args)
           (member 'var args))
      'var
      'func))

(define (extern-arg-abi args)
  (and (list? args)
       (for/first ([arg (in-list args)]
                   #:when (and (list? arg)
                               (= (length arg) 2)
                               (eq? (car arg) 'abi)))
         (cadr arg))))

;; ============================================================
;; CFG 构建
;; ============================================================

(struct builder
  (cfg current-fn-id current-fn-name current-fn-attrs current-items next-bb-id)
  #:transparent)

(define (build-cfg items [source 'unknown])
  (define initial-builder
    (builder (cfg-empty source) #f #f (hash) '() 0))

  (define final-builder
    (for/fold ([b initial-builder])
              ([item (in-list items)]
               #:when (or (ast-ins? item) (ast-directive? item)))
      (process-item b item)))

  (drop-function-global-module-items
   (builder-cfg (finalize-current-function final-builder))))

(define (process-item b item)
  (match item
    [(ast-directive 'function name attrs loc)
     (define b1 (finalize-current-function b))
     (define cfg (builder-cfg b1))
     (define fn-id (control-flow-graph-next-fn-id cfg))
     (define new-cfg
       (struct-copy control-flow-graph cfg
                    [next-fn-id (add1 fn-id)]))
     ;; attrs 是 hash，保存到 builder 中
     (define attrs0 (normalize-function-public-abi
                     (if (hash? attrs) attrs (hash))
                     name))
     (define attrs/function-loc
       (hash-set attrs0 'function-loc loc))
     (define fn-attrs
       (if (hash-has-key? attrs/function-loc 'function-version)
           attrs/function-loc
           (hash-set attrs/function-loc
                     'function-version
                     (make-source-function-version name attrs/function-loc loc))))
     (builder new-cfg fn-id name fn-attrs '() (builder-next-bb-id b1))]

    [(ast-directive 'end-function _ _ _)
     (finalize-current-function b)]

    [(ast-directive 'extern name args _)
     ;; 将 extern 符号添加到 CFG 的 info 中
     ;; args: '(func) / '(var) 表示符号类型，可附带 '(abi <name>) 作为调用 ABI。
     (define cfg (builder-cfg b))
     (define kind (extern-arg-kind args))
     (define abi-name (extern-arg-abi args))
     (define extern-syms (cfg-get-info cfg 'extern-symbols (set)))
     (define extern-vars (cfg-get-info cfg 'extern-vars (set)))
     (define extern-abi-names (cfg-get-info cfg 'extern-abi-names (hash)))
     (define new-cfg
       (let* ([cfg* (if (eq? kind 'var)
                        (cfg-set-info (cfg-set-info cfg 'extern-symbols (set-add extern-syms name))
                                      'extern-vars (set-add extern-vars name))
                        (cfg-set-info cfg 'extern-symbols (set-add extern-syms name)))]
              [cfg** (if (and (eq? kind 'func) abi-name)
                         (cfg-set-info cfg* 'extern-abi-names
                                       (hash-set extern-abi-names name abi-name))
                         cfg*)])
         cfg**))
     (struct-copy builder b [cfg new-cfg])]

    [_
     (if (builder-current-fn-id b)
         (struct-copy builder b
                      [current-items (cons item (builder-current-items b))])
         (if (module-directive? item)
             (struct-copy builder b
                          [cfg (append-module-item (builder-cfg b) item)])
             b))]))

(define (finalize-current-function b)
  (cond
    [(not (builder-current-fn-id b)) b]
    [else
     (define fn-id (builder-current-fn-id b))
     (define fn-name (builder-current-fn-name b))
     (define fn-attrs (builder-current-fn-attrs b))
     (define items (reverse (builder-current-items b)))
     (define cfg (builder-cfg b))
     (define start-bb-id (builder-next-bb-id b))

     (define-values (fn0 next-bb-id)
       (build-single-function fn-id fn-name items start-bb-id))

     ;; 将函数属性存储到 info 中
     (define fn
       (for/fold ([f fn0])
                 ([(k v) (in-hash fn-attrs)])
         (fn-set-info f k v)))

     (define new-cfg0
       (struct-copy control-flow-graph cfg
                    [functions (intmap-set
                                (control-flow-graph-functions cfg)
                                fn-id fn)]
                    [fn-names (hash-set
                               (control-flow-graph-fn-names cfg)
                               fn-name fn-id)]))
     (define new-cfg
       (cfg-record-function-version-group new-cfg0 fn))

     (builder new-cfg #f #f (hash) '() next-bb-id)]))

;; 构建单个函数
(define (build-single-function fn-id fn-name items start-bb-id)
  (define-values (instructions label-positions max-internal-align)
    (collect-instructions-and-labels items))

  (define n-instructions (pvector-length instructions))

  ;; 将内部最大对齐存储到 info 中
  (define base-info
    (hash-set (hasheq)
              'max-internal-align max-internal-align))

  (cond
    [(= n-instructions 0)
     (values
      (asm-function fn-id fn-name #f
                    graph-empty
                    intmap-empty
                    intmap-empty
                    (hasheq)
                    intmap-empty
                    intmap-empty
                    fn-debug-empty
                    base-info)
      start-bb-id)]
    [else
     (define block-starts (compute-block-starts instructions label-positions))

     (define-values (g blocks id->label label->id vid->bbid bbid->vid entry next-bb)
       (create-blocks-with-graph instructions label-positions block-starts start-bb-id))

     (define g-connected
       (connect-edges g instructions block-starts bbid->vid label->id))

     (values
      (asm-function fn-id fn-name entry g-connected blocks
                    id->label label->id vid->bbid bbid->vid
                    fn-debug-empty
                    base-info)
      next-bb)]))

(define (collect-instructions-and-labels items)
  ;; 返回: instructions, label-positions, max-align
  (define-values (instructions label-positions max-align)
    (for/fold ([instructions (pvector-empty)]
               [label-positions (hash)]
               [max-align 2])  ;; 默认最小对齐 2
              ([item (in-list items)])
      (match item
        [(ast-directive 'label name _ _)
         (values instructions
                 (hash-set label-positions name (pvector-length instructions))
                 max-align)]
        [(ast-directive 'align #f (list n) _)
         (values (pvector-cons-right instructions item)
                 label-positions
                 (max max-align n))]  ;; 更新最大对齐
        [(? ast-ins?)
         (values (pvector-cons-right instructions item)
                 label-positions
                 max-align)]
        ;; 保留 save!/load!/weak-mov/inline/call/reg-interfere/frame/alloca 指令在指令流中
        [(ast-directive (or 'save! 'load! 'weak-mov 'inline 'call 'reg-interfere 'frame 'alloca) _ _ _)
         (values (pvector-cons-right instructions item)
                 label-positions
                 max-align)]
        [_ (values instructions label-positions max-align)])))
  (values instructions label-positions max-align))

(define (compute-block-starts instructions label-positions)
  (define starts (mutable-set 0))

  (for ([(_ pos) (in-hash label-positions)])
    (set-add! starts pos))

  (for ([i (in-range (pvector-length instructions))])
    (define ins (pvector-ref instructions i))
    (when (branch-instruction? ins)
      (define next-idx (add1 i))
      (when (< next-idx (pvector-length instructions))
        (set-add! starts next-idx))))

  (sort (for/list ([s (in-set starts)]
                   #:when (< s (pvector-length instructions)))
          s)
        <))

;; 创建块和图
;; 返回: (values graph blocks id->label label->id vid->bbid bbid->vid entry next-bb-id)
(define (create-blocks-with-graph instructions label-positions block-starts start-bb-id)
  (define n-instructions (pvector-length instructions))

  (define pos-to-labels
    (for/fold ([h (hash)])
              ([(name pos) (in-hash label-positions)])
      (hash-update h pos (lambda (labels) (cons name labels)) '())))

  (define (sort-labels labels)
    (sort labels
          (lambda (a b)
            (string<? (symbol->string a) (symbol->string b)))))

  (for/fold ([g graph-empty]
             [blocks intmap-empty]
             [id->label intmap-empty]
             [label->id (hasheq)]
             [vid->bbid intmap-empty]
             [bbid->vid intmap-empty]
             [entry #f]
             [next-bb start-bb-id])
            ([start (in-list block-starts)]
             [i (in-naturals)])
    ;; 分配 bb-id 和 vertex-id
    (define bbid (bb-id next-bb))
    (define-values (g* vid) (graph-add-vertex g))

    ;; 块范围
    (define end
      (if (< i (sub1 (length block-starts)))
          (list-ref block-starts (add1 i))
          n-instructions))

    ;; 提取指令
    (define block-instructions
      (for/fold ([pv (pvector-empty)])
                ([idx (in-range start end)])
        (pvector-cons-right pv (pvector-ref instructions idx))))

    ;; 标签
    (define labels (sort-labels (hash-ref pos-to-labels start '())))
    (define label (and (pair? labels) (car labels)))

    ;; debug 信息
    (define stx-begin
      (if (> (pvector-length block-instructions) 0)
          (ast-srcloc (pvector-ref block-instructions 0))
          #f))
    (define stx-end
      (if (> (pvector-length block-instructions) 0)
          (ast-srcloc (pvector-ref block-instructions
                                   (sub1 (pvector-length block-instructions))))
          #f))

    ;; 创建块
    (define block
      (make-basic-block bbid block-instructions
                        #:label label
                        #:stx-begin stx-begin
                        #:stx-end stx-end))

    ;; 更新映射
    (define new-blocks (intmap-set blocks next-bb block))
    (define new-id->label
      (if label (intmap-set id->label next-bb label) id->label))
    (define new-label->id
      (for/fold ([m label->id])
                ([lbl (in-list labels)])
        (hash-set m lbl bbid)))
    (define new-vid->bbid (intmap-set vid->bbid (vertex-id-val vid) bbid))
    (define new-bbid->vid (intmap-set bbid->vid next-bb vid))

    (define new-entry (or entry bbid))

    (values g* new-blocks new-id->label new-label->id
            new-vid->bbid new-bbid->vid new-entry (add1 next-bb))))

;; 连接边
(define (connect-edges g instructions block-starts bbid->vid label->id)
  (define base-bbid (car (intmap-min-entry bbid->vid)))

  (for/fold ([current-g g])
            ([start (in-list block-starts)]
             [i (in-naturals)])
    (define end
      (if (< i (sub1 (length block-starts)))
          (list-ref block-starts (add1 i))
          (pvector-length instructions)))

    (cond
      [(= start end) current-g]
      [else
       (define last-ins (pvector-ref instructions (sub1 end)))
       (define current-bbid (+ base-bbid i))
       (define current-vid (intmap-ref bbid->vid current-bbid))

       (define successors
         (cond
           [(return-instruction? last-ins) '()]

           ;; 调用指令 (bl, blr): 对于函数内 CFG，只考虑 fall-through
           ;; 调用返回后继续执行下一条指令
           [(call-instruction? last-ins)
            (if (< i (sub1 (length block-starts)))
                (let ([next-vid (intmap-ref bbid->vid (+ current-bbid 1) #f)])
                  (if next-vid (list next-vid) '()))
                '())]

           [(unconditional-branch? last-ins)
            (define target (extract-branch-target last-ins))
            (if (and target (eq? (target-info-kind target) 'label))
                (let ([target-bbid (hash-ref label->id (target-info-value target) #f)])
                  (if target-bbid
                      (list (intmap-ref bbid->vid (bb-id-val target-bbid)))
                      '()))
                '())]

           [(conditional-branch? last-ins)
            (define taken
              (let ([target (extract-branch-target last-ins)])
                (and target
                     (eq? (target-info-kind target) 'label)
                     (let ([target-bbid (hash-ref label->id (target-info-value target) #f)])
                       (and target-bbid
                            (intmap-ref bbid->vid (bb-id-val target-bbid)))))))
            (define fallthrough
              (and (< i (sub1 (length block-starts)))
                   (intmap-ref bbid->vid (+ current-bbid 1) #f)))
            (filter values (list taken fallthrough))]

           [else
            (if (< i (sub1 (length block-starts)))
                (let ([next-vid (intmap-ref bbid->vid (+ current-bbid 1) #f)])
                  (if next-vid (list next-vid) '()))
                '())]))

       (for/fold ([g current-g])
                 ([succ-vid (in-list successors)])
         (define-values (g* _) (graph-add-edge g current-vid succ-vid))
         g*)])))

;; ============================================================
;; 查询函数
;; ============================================================

(define (cfg-get-function cfg fn-id)
  (intmap-ref (control-flow-graph-functions cfg) fn-id #f))

(define (cfg-get-function-by-name cfg name)
  (define fn-id (hash-ref (control-flow-graph-fn-names cfg) name #f))
  (and fn-id (cfg-get-function cfg fn-id)))

(define (cfg-function-count cfg)
  (intmap-count (control-flow-graph-functions cfg)))

(define (fn-get-block fn bbid)
  (define key (if (bb-id? bbid) (bb-id-val bbid) bbid))
  (intmap-ref (asm-function-blocks fn) key #f))

(define (fn-get-block-by-label fn label)
  (define bbid (fn-get-id fn label))
  (and bbid (fn-get-block fn bbid)))

(define (fn-block-count fn)
  (intmap-count (asm-function-blocks fn)))

(define (fn-entry-block fn)
  (and (asm-function-entry fn)
       (fn-get-block fn (asm-function-entry fn))))

(define (fn-exit-blocks fn)
  (define g (asm-function-graph fn))
  (for/list ([kv (in-intmap-pairs (asm-function-blocks fn))]
             #:when (let* ([block (cdr kv)]
                           [bbid (basic-block-id block)]
                           [vid (intmap-ref (asm-function-bbid->vid fn) (bb-id-val bbid) #f)])
                      (and vid (= (graph-out-degree g vid) 0))))
    (cdr kv)))

(define (fn-successors fn bbid)
  (define g (asm-function-graph fn))
  (define key (if (bb-id? bbid) (bb-id-val bbid) bbid))
  (define vid (intmap-ref (asm-function-bbid->vid fn) key #f))
  (if vid
      (for/list ([succ-vid (in-graph-successors g vid)])
        (intmap-ref (asm-function-vid->bbid fn) (vertex-id-val succ-vid) #f))
      '()))

(define (fn-predecessors fn bbid)
  (define g (asm-function-graph fn))
  (define key (if (bb-id? bbid) (bb-id-val bbid) bbid))
  (define vid (intmap-ref (asm-function-bbid->vid fn) key #f))
  (if vid
      (for/list ([pred-vid (in-graph-predecessors g vid)])
        (intmap-ref (asm-function-vid->bbid fn) (vertex-id-val pred-vid) #f))
      '()))

;; ============================================================
;; 遍历
;; ============================================================

(define (cfg-for-each-function cfg proc)
  (for ([kv (in-intmap-pairs (control-flow-graph-functions cfg))])
    (proc (cdr kv))))

(define (fn-for-each-block fn proc)
  (for ([kv (in-intmap-pairs (asm-function-blocks fn))])
    (proc (cdr kv))))

(define (fn-dfs fn start-bbid proc)
  (define visited (mutable-set))
  (let dfs ([bbid start-bbid])
    (define key (if (bb-id? bbid) (bb-id-val bbid) bbid))
    (unless (set-member? visited key)
      (set-add! visited key)
      (define block (fn-get-block fn key))
      (when block
        (proc block)
        (for ([succ-bbid (in-list (fn-successors fn key))])
          (when succ-bbid (dfs succ-bbid)))))))

(define (fn-bfs fn start-bbid proc)
  (define visited (mutable-set))
  (define start-key (if (bb-id? start-bbid) (bb-id-val start-bbid) start-bbid))
  (define queue (list start-key))
  (let bfs ()
    (unless (null? queue)
      (define key (car queue))
      (set! queue (cdr queue))
      (unless (set-member? visited key)
        (set-add! visited key)
        (define block (fn-get-block fn key))
        (when block
          (proc block)
          (for ([succ-bbid (in-list (fn-successors fn key))])
            (when succ-bbid
              (define succ-key (if (bb-id? succ-bbid) (bb-id-val succ-bbid) succ-bbid))
              (unless (set-member? visited succ-key)
                (set! queue (append queue (list succ-key))))))))
      (bfs))))

;; ============================================================
;; 格式化
;; ============================================================

(define (format-cfg cfg)
  (string-join
   (cons "=== Control Flow Graph ==="
         (for/list ([kv (in-intmap-pairs (control-flow-graph-functions cfg))])
           (format-cfg-function (cdr kv))))
   "\n"))

(define (format-cfg-function fn)
  (define g (asm-function-graph fn))
  (define lines
    (list (format "\nFunction[~a]: ~a" (asm-function-id fn) (asm-function-name fn))
          (format "Entry: ~a"
                  (if (asm-function-entry fn)
                      (format "bb~a" (bb-id-val (asm-function-entry fn)))
                      "none"))
          (format "Vertices: ~a, Edges: ~a"
                  (graph-vertex-count g)
                  (graph-edge-count g))
          "Blocks:"))

  (define block-lines
    (for/list ([kv (in-intmap-pairs (asm-function-blocks fn))])
      (format-block fn (cdr kv))))

  (string-join (append lines block-lines) "\n"))

(define (format-block fn block)
  (define bbid (basic-block-id block))
  (define label (bb-label block))
  (define label-str (if label (format " [~a]" label) ""))

  (define preds
    (for/list ([p (in-list (fn-predecessors fn bbid))]
               #:when p)
      (format "bb~a" (bb-id-val p))))
  (define succs
    (for/list ([s (in-list (fn-successors fn bbid))]
               #:when s)
      (format "bb~a" (bb-id-val s))))

  (string-join
   (list (format "  bb~a~a:" (bb-id-val bbid) label-str)
         (format "    preds: ~a" (if (null? preds) "(none)" (string-join preds ", ")))
         (format "    succs: ~a" (if (null? succs) "(none)" (string-join succs ", ")))
         (format "    instructions: ~a" (pvector-length (basic-block-instructions block)))
         (for/fold ([s ""])
                   ([i (in-range (pvector-length (basic-block-instructions block)))])
           (define ins (pvector-ref (basic-block-instructions block) i))
           (string-append s (format "      ~a\n" (ast->string ins)))))
   "\n"))

;; ============================================================
;; DOT 格式
;; ============================================================

(define (format-cfg-dot cfg)
  (string-join
   (append
    (list "digraph CFG {"
          "  rankdir=TB;")
    (for/list ([kv (in-intmap-pairs (control-flow-graph-functions cfg))])
      (format-function-dot-subgraph (cdr kv)))
    (list "}"))
   "\n"))

(define (format-function-dot fn)
  (string-join
   (list "digraph CFG {"
         "  rankdir=TB;"
         (format-function-dot-body fn)
         "}")
   "\n"))

(define (format-function-dot-subgraph fn)
  (format "  subgraph cluster_~a {\n    label=\"~a\";\n~a\n  }"
          (asm-function-name fn)
          (asm-function-name fn)
          (format-function-dot-body fn)))

(define (format-function-dot-body fn)
  (define node-lines
    (for/list ([kv (in-intmap-pairs (asm-function-blocks fn))])
      (define block (cdr kv))
      (define bbid (basic-block-id block))
      (define bb-val (bb-id-val bbid))
      (define label (bb-label block))
      (define label-str
        (if label
            (format "bb~a\\n[~a]" bb-val label)
            (format "bb~a" bb-val)))
      (define ins-preview
        (if (= (pvector-length (basic-block-instructions block)) 0)
            ""
            (let ([first-ins (pvector-ref (basic-block-instructions block) 0)])
              (format "\\n~a..." (ast-ins-mnemonic first-ins)))))
      (format "    bb~a [label=\"~a~a\" shape=box];" bb-val label-str ins-preview)))

  (define edge-lines
    (for*/list ([kv (in-intmap-pairs (asm-function-blocks fn))]
                [succ-bbid (in-list (fn-successors fn (car kv)))]
                #:when succ-bbid)
      (format "    bb~a -> bb~a;" (car kv) (bb-id-val succ-bbid))))

  (string-join (append node-lines edge-lines) "\n"))

;; ============================================================
;; SP 写入纪律验证
;; ============================================================

;; 源码层直接写 SP 的诊断信息
(struct sp-write-error
  (function-name  ; symbol - 所在函数名
   instruction    ; ast-ins - 写入 SP 的源指令
   srcloc         ; srcloc - 源码位置
   reason)        ; string - 写入原因
  #:transparent)

(define (sp-reg? op)
  (and (ast-reg? op)
       (eq? (ast-reg-id op) 'sp)))

(define (sp-reg-ref? ref)
  (eq? (reg-ref-id ref) 'sp))

(define (sp-indexed-memory-write? op)
  (and (ast-mem? op)
       (sp-reg? (ast-mem-base op))
       (memq (ast-mem-index-mode op) '(pre post))))

(define (instruction-sp-write-reason ins)
  (match ins
    [(ast-ins _ _ operands _)
     (define sp-defs
       (filter sp-reg-ref?
               (use-def-flat-defs (extract-use-def ins))))
     (cond
       [(for/or ([op (in-list operands)])
          (sp-indexed-memory-write? op))
        "pre/post-index 内存寻址会更新 sp"]
       [(for/or ([ref (in-list sp-defs)])
          (eq? (reg-ref-position ref) 'direct))
        "指令定义了 sp"]
       [(pair? sp-defs)
        "指令通过寻址副作用更新 sp"]
       [else #f])]
    [_ #f]))

;; 验证函数中的源码层 SP 写入。
;; .save/.restore 是 ast-directive，后续由 save-load 管线展开，不在这里拦截。
(define (verify-sp-write-discipline fn)
  (define fn-name (asm-function-name fn))
  (define errors (box (pvector-empty)))
  (fn-for-each-block
   fn
   (lambda (block)
     (for ([ins (in-pvector (basic-block-instructions block))])
       (when (ast-ins? ins)
         (define reason (instruction-sp-write-reason ins))
         (when reason
           (set-box! errors
                     (pvector-cons-right
                      (unbox errors)
                      (sp-write-error
                       fn-name
                       ins
                       (ast-srcloc ins)
                       reason))))))))
  (unbox errors))

;; ============================================================
;; 标签引用验证
;; ============================================================

;; 标签引用错误信息
(struct label-ref-error
  (label         ; symbol - 未定义的标签名
   instruction   ; ast-ins - 引用该标签的指令
   srcloc        ; srcloc - 源码位置
   function-name ; symbol - 所在函数名
   defined-labels) ; (listof symbol) - 该函数中已定义的标签
  #:transparent)

;; 从指令中提取所有标签引用
(define (extract-label-refs ins)
  (match ins
    [(ast-ins _ _ operands _)
     (for/list ([op (in-list operands)]
                #:when (and (ast-label? op)
                            (not (and (not (ast-label-reloc op))
                                      (label-looks-like-system-reg? (ast-label-name op))))))
       (ast-label-name op))]
    [_ '()]))

;; 验证函数中的标签引用
;; 返回 pvector of label-ref-error
(define (verify-label-references fn cfg)
  (define fn-name (asm-function-name fn))

  ;; 收集本函数定义的所有标签
  (define local-labels
    (for/set ([kv (in-hash-pairs (asm-function-label->id fn))])
      (car kv)))

  ;; 收集 CFG 中所有函数名 (作为有效的外部引用)
  (define external-symbols
    (for/set ([kv (in-hash-pairs (control-flow-graph-fn-names cfg))])
      (car kv)))

  ;; 收集声明的 extern 符号
  (define extern-symbols (cfg-get-info cfg 'extern-symbols (set)))

  ;; 收集模块级数据/全局符号，允许函数引用同文件数据标签
  (define module-symbols
    (for/fold ([symbols (set)])
              ([item (in-list (cfg-get-info cfg 'module-items '()))])
      (match item
        [(ast-directive (or 'label 'global) name _ _)
         (set-add symbols name)]
        [_ symbols])))

  ;; 有效的标签 = 本地标签 + 外部函数名 + extern 符号
  (define valid-labels
    (set-union local-labels external-symbols extern-symbols module-symbols))

  ;; 遍历所有指令，检查标签引用
  (define errors (box (pvector-empty)))
  (fn-for-each-block fn
    (lambda (block)
      (for ([ins (in-pvector (basic-block-instructions block))])
        (when (ast-ins? ins)
          (for ([label (in-list (extract-label-refs ins))])
            (unless (set-member? valid-labels label)
              (set-box! errors
                        (pvector-cons-right
                         (unbox errors)
                         (label-ref-error
                          label
                          ins
                          (ast-srcloc ins)
                          fn-name
                          (set->list local-labels))))))))))
  (unbox errors))

;; ============================================================
;; 符号名验证
;; ============================================================

;; 符号名错误信息
(struct symbol-name-error
  (symbol         ; symbol - 不合法的符号名
   kind           ; 'function | 'label - 符号类型
   function-name  ; symbol - 所在函数名 (如果是标签)
   reason)        ; string - 错误原因
  #:transparent)

;; 检查托管函数符号是否是合法的 asmp 符号名。
;; 规则：segment(.segment)*；segment 以字母或下划线开头，可包含字母、数字、_、$、-。
(define (valid-asm-symbol? sym)
  (define str (if (symbol? sym) (symbol->string sym) sym))
  (regexp-match? #rx"^[A-Za-z_][A-Za-z0-9_$-]*(\\.[A-Za-z_][A-Za-z0-9_$-]*)*$" str))

;; 将不合法的符号转换为合法符号
;; 规则：不合法字符替换为 _
(define (sanitize-symbol sym)
  (define str (if (symbol? sym) (symbol->string sym) sym))
  (define sanitized
    (list->string
     (for/list ([c (in-string str)]
                [i (in-naturals)])
       (cond
         ;; 首字符必须是字母或下划线
         [(and (= i 0)
               (not (or (char-alphabetic? c) (char=? c #\_))))
          #\_]
         ;; 其他字符：字母、数字、下划线
         [(or (char-alphabetic? c)
              (char-numeric? c)
              (char=? c #\_))
          c]
         ;; 不合法字符替换为下划线
         [else #\_]))))
  sanitized)

;; 验证函数中的符号名
;; 返回 pvector of symbol-name-error
(define (verify-symbol-names fn)
  (define fn-name (asm-function-name fn))
  (define errors (box (pvector-empty)))

  ;; 检查函数名
  (unless (valid-asm-symbol? fn-name)
    (set-box! errors
              (pvector-cons-right
               (unbox errors)
               (symbol-name-error
                fn-name
                'function
                #f
                (format "函数名 '~a' 不合法 (应为 segment(.segment)*，segment 以字母或下划线开头，可包含字母、数字、_、$、-)"
                        fn-name)))))

  ;; 检查局部标签 (这里只是警告，因为局部标签会被转换)
  ;; 实际上局部标签不需要验证，因为会被自动转换
  ;; 但如果用户想知道哪些标签被转换了，可以开启详细模式

  (unbox errors))

;; ============================================================
;; Pedantic 检查：线性 fallthrough
;; ============================================================

;; 警告信息
(struct linear-fallthrough-warning
  (function-name    ; symbol
   instruction-count ; integer - 指令数量
   last-instruction  ; ast-ins | #f - 最后一条指令
   srcloc)           ; srcloc | #f - 源码位置
  #:transparent)

;; 检查是否是跳转/终止指令
(define (terminator-instruction? ins)
  (and (ast-ins? ins)
       (let ([mnem (ast-ins-mnemonic ins)])
         (or (eq? mnem 'ret)
             (eq? mnem 'eret)
             (eq? mnem 'br)
             (eq? mnem 'blr)
             ;; 无条件跳转
             (eq? mnem 'b)
             ;; 条件分支也算（有跳转可能）
             (and (symbol? mnem)
                  (let ([s (symbol->string mnem)])
                    (and (> (string-length s) 2)
                         (string=? (substring s 0 2) "b."))))))))

;; 检查函数是否为"纯线性代码但无终止指令"
;; 条件：
;;   1. 只有一个基本块（无跳转）
;;   2. 有指令（非空函数）
;;   3. 最后一条指令不是终止指令
;; 返回 linear-fallthrough-warning 或 #f
(define (check-linear-fallthrough fn)
  (define fn-name (asm-function-name fn))
  (define block-count (fn-block-count fn))

  ;; 只检查单基本块函数
  (cond
    [(not (= block-count 1)) #f]
    [else
     (define entry (asm-function-entry fn))
     (cond
       [(not entry) #f]  ; 空函数
       [else
        (define block (fn-get-block fn entry))
        (cond
          [(not block) #f]
          [else
           (define instrs (basic-block-instructions block))
           (define len (pvector-length instrs))
           (cond
             [(= len 0) #f]  ; 空块
             [else
              (define last-ins (pvector-ref instrs (sub1 len)))
              (if (terminator-instruction? last-ins)
                  #f
                  (linear-fallthrough-warning
                   fn-name
                   len
                   last-ins
                   (and (ast-ins? last-ins) (ast-srcloc last-ins))))])])])]))

;; ============================================================
;; 测试
;; ============================================================

(module+ test
  (require "../parser/parser.rkt")

  (displayln "=== CFG 测试 ===\n")

  (define test-items
    (list
     (ast-directive 'function 'main '() no-srcloc)
     (ast-directive 'label 'start '() no-srcloc)
     (parse-instruction '(mov x0 0))
     (parse-instruction '(cmp x0 10))
     (parse-instruction '(b.ge done))
     (ast-directive 'label 'loop '() no-srcloc)
     (parse-instruction '(add x0 x0 1))
     (parse-instruction '(cmp x0 10))
     (parse-instruction '(b.lt loop))
     (ast-directive 'label 'done '() no-srcloc)
     (parse-instruction '(ret))))

  (define cfg (build-cfg test-items 'test))

  (displayln (format-cfg cfg))
  (displayln "")
  (displayln "=== DOT ===")
  (displayln (format-cfg-dot cfg)))
