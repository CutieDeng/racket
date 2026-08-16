#lang racket

;; ============================================================
;; codegen/emit.rkt - 汇编文件生成 (高性能 printf 模式)
;; ============================================================
;;
;; 将内部 AST 转换为标准 ARM64 汇编格式 (.s 文件)
;;
;; 性能优化:
;;   - 直接写入端口，避免中间字符串分配
;;   - 缓存常用字符串
;;   - 使用 display/write-string 代替 format

(require "../parser/ast.rkt"
         "../parser/comments.rkt"
         "../semantic/control-flow.rkt"
         "../semantic/branch-info.rkt"
         "../syntax/operand-type.rkt"
         "../syntax/sysreg.rkt"
         "../pipeline/pipeline.rkt"
         racket/pvector
         "../pipeline/regalloc/types.rkt")

(provide
  ;; 配置
  (struct-out emit-config)
  default-emit-config
  apple-emit-config
  current-emit-config  ; 参数化配置
  make-debug-file-state
  current-debug-file-state
  call-with-fresh-debug-file-state
  emit-debug-text-begin
  emit-debug-text-end
  emit-debug-dwarf-footer

  ;; 单元素输出 (返回字符串，兼容旧 API)
  emit-reg            ; ast-reg → string
  emit-operand        ; ast-node → string
  emit-instruction    ; ast-ins → string
  emit-directive      ; ast-directive → string

  ;; 函数输出
  emit-function       ; asm-function → string
  emit-function/result ; pipeline-result → string

  ;; 高性能端口输出 (直接写入，无中间字符串)
  emit-function/port       ; asm-function port → void
  emit-module/port         ; cfg port → void

  ;; 完整文件输出
  emit-module         ; cfg → string
  emit-to-file        ; cfg path → void
  emit-to-port        ; cfg port → void

  ;; 工具
  format-label        ; symbol → string (根据配置添加前缀)
  indent-line)        ; string → string

;; ============================================================
;; 配置
;; ============================================================

(struct emit-config
  (syntax             ; 'gnu | 'apple - 汇编器语法
   indent             ; string - 指令缩进 (默认 "    ")
   label-prefix       ; string - 标签前缀 (Apple: "_", GNU: "")
   comment-char       ; char - 注释字符 (默认 #\;, Apple 也支持 //)
   emit-debug-info?   ; boolean - 是否输出调试信息
   emit-cfi?          ; boolean - 是否输出 CFI 指令
   align-operands?    ; boolean - 是否对齐操作数列
   skip-redundant-mov? ; boolean - 跳过冗余 mov (如 mov x0, x0)
   max-line-width     ; integer - 最大行宽 (用于注释换行)
   merge-colocated-labels?) ; boolean - 合并同位置的标签 (入口块局部标签合并到函数名)
  #:transparent)

(define default-emit-config
  (emit-config
   'gnu               ; GNU as 语法
   "    "             ; 4 空格缩进
   ""                 ; 无标签前缀
   #\;                ; 分号注释
   #f                 ; 不输出调试信息
   #f                 ; 不输出 CFI
   #f                 ; 不对齐操作数
   #f                 ; 不跳过冗余 mov (保留用户指令)
   80                 ; 80 列宽
   #f))               ; 不合并同位置标签

(define apple-emit-config
  (emit-config
   'apple             ; Apple as 语法
   "    "             ; 4 空格缩进
   "_"                ; 下划线前缀
   #\;                ; 分号注释
   #f                 ; 不输出调试信息
   #f                 ; 不输出 CFI
   #f                 ; 不对齐操作数
   #f                 ; 不跳过冗余 mov (保留用户指令)
   80                 ; 80 列宽
   #f))               ; 不合并同位置标签

;; 当前配置 (参数化)
(define current-emit-config (make-parameter default-emit-config))

;; .file/.loc emission state. A module should share one state so every source
;; file gets one stable numeric id across all emitted functions.
(struct debug-variable
  (name byte-size dwarf-reg)
  #:transparent)

(struct debug-variable-spec
  (reg name byte-size)
  #:transparent)

(struct debug-function
  (name low-label high-label variables)
  #:transparent)

(struct debug-file-state
  (source->id next-id last-loc functions)
  #:mutable
  #:transparent)

(define (make-debug-file-state)
  (debug-file-state (make-hash) 1 #f '()))

(define current-debug-file-state (make-parameter #f))

(define (call-with-fresh-debug-file-state thunk)
  (parameterize ([current-debug-file-state (make-debug-file-state)])
    (thunk)))

(struct cfi-state
  (sp-offset cfa-reg cfa-offset)
  #:mutable
  #:transparent)

(define (make-cfi-state)
  (cfi-state 0 #f 0))

(define current-cfi-state (make-parameter #f))

;; ============================================================
;; 缓存的字符串常量
;; ============================================================

(define *reg-prefix-cache*
  (hasheq 'x "x" 'w "w" 'z "z" 'v "v" 'p "p"
          'b "b" 'h "h" 's "s" 'd "d" 'q "q"))

(define (reg-kind->asm-prefix kind)
  (hash-ref *reg-prefix-cache* kind "?"))

(define (emit-comment-prefix config)
  (case (emit-config-syntax config)
    [(gnu) "//"]
    [else (string (emit-config-comment-char config))]))

(define (asm-symbol-token name [prefix ""])
  (define raw (string-append prefix (if (symbol? name) (symbol->string name) (~a name))))
  (if (regexp-match? #rx"^[A-Za-z_.$][A-Za-z0-9_.$]*$" raw)
      raw
      (let ([out (open-output-string)])
        (write raw out)
        (get-output-string out))))

(define (emit-asm-symbol/port name port [prefix ""])
  (port-write-string port (asm-symbol-token name prefix)))

(define (emit-symbol-visibility/port fn-name visibility port prefix config)
  (case visibility
    [(hidden)
     (case (emit-config-syntax config)
       [(apple)
        (port-write-string port ".private_extern ")
        (emit-asm-symbol/port fn-name port prefix)
        (port-newline port)]
       [else
        (port-write-string port ".hidden ")
        (emit-asm-symbol/port fn-name port prefix)
        (port-newline port)])]
    [else (void)]))

(define (emit-symbol-binding/port fn-name binding port prefix config)
  (case binding
    [(weak)
     (case (emit-config-syntax config)
       [(apple)
        (port-write-string port ".weak_definition ")
        (emit-asm-symbol/port fn-name port prefix)
        (port-newline port)
        (port-write-string port ".globl ")]
       [else
        (port-write-string port ".weak ")])
     (emit-asm-symbol/port fn-name port prefix)
     (port-newline port)]
    [else
     (port-write-string port ".globl ")
     (emit-asm-symbol/port fn-name port prefix)
     (port-newline port)]))

;; ============================================================
;; 端口输出辅助函数
;; ============================================================

(define-syntax-rule (port-write-string port str)
  (write-string str port))

(define-syntax-rule (port-newline port)
  (newline port))

(define-syntax-rule (port-display port v)
  (display v port))

(define (valid-debug-loc? loc)
  (and (srcloc? loc)
       (srcloc-source loc)
       (integer? (srcloc-line loc))
       (positive? (srcloc-line loc))))

(define (debug-source->string src)
  (cond
    [(path? src) (path->string src)]
    [(symbol? src) (symbol->string src)]
    [else (~a src)]))

(define (debug-loc-column loc)
  (define col (srcloc-column loc))
  (if (and (integer? col) (>= col 0)) col 0))

(define (debug-file-id/emit source port)
  (define state (current-debug-file-state))
  (unless state
    (error 'emit-debug-loc "debug file state is not initialized"))
  (define source-key (debug-source->string source))
  (hash-ref
   (debug-file-state-source->id state)
   source-key
   (lambda ()
     (define id (debug-file-state-next-id state))
     (hash-set! (debug-file-state-source->id state) source-key id)
     (set-debug-file-state-next-id! state (add1 id))
     (port-write-string port ".file ")
     (port-display port id)
     (port-write-string port " ")
     (write source-key port)
     (port-newline port)
     id)))

(define (debug-state-has-files? state)
  (and state
       (not (zero? (hash-count (debug-file-state-source->id state))))))

(define (debug-primary-source state)
  (define pairs (hash->list (debug-file-state-source->id state)))
  (car (car (sort pairs < #:key cdr))))

(define (debug-current-comp-dir)
  (path->string (simplify-path (current-directory))))

(define (debug-label-base)
  (case (emit-config-syntax (current-emit-config))
    [(gnu) ".Lasmp_debug"]
    [else "Lasmp_debug"]))

(define (debug-text-begin-label)
  (string-append (debug-label-base) "_text_begin"))

(define (debug-text-end-label)
  (string-append (debug-label-base) "_text_end"))

(define (debug-function-end-label fn-name)
  (format "~a_func_~a_end" (debug-label-base) (sanitize-symbol fn-name)))

(define (debug-info-start-label)
  (string-append (debug-label-base) "_info_start"))

(define (debug-info-end-label)
  (string-append (debug-label-base) "_info_end"))

(define (debug-info-section-label)
  (string-append (debug-label-base) "_info_section"))

(define (debug-u64-type-label)
  (string-append (debug-label-base) "_type_u64"))

(define (debug-u32-type-label)
  (string-append (debug-label-base) "_type_u32"))

(define (debug-reg-id->name r)
  (define prefix
    (case (reg-id-class r)
      [(gpr) (if (<= (reg-id-width r) 32) "w" "x")]
      [(fpr) (case (reg-id-width r)
               [(8) "b"]
               [(16) "h"]
               [(32) "s"]
               [(64) "d"]
               [else "q"])]
      [(predicate) "p"]
      [else "?"]))
  (if (reg-id-virtual? r)
      (format "~a.~a" prefix (reg-id-id r))
      (format "~a~a" prefix (reg-id-id r))))

(define (debug-internal-reg-id? r)
  (and (reg-id-virtual? r)
       (symbol? (reg-id-id r))
       (regexp-match? #rx"^__asmp_" (symbol->string (reg-id-id r)))))

(define (debug-alloc-record-empty? record)
  (define alloc (hash-ref record 'allocation #f))
  (or (not alloc)
      (and (reg-om-empty? (alloc-result-assignment alloc))
           (reg-om-empty? (alloc-result-coalesced alloc))
           (= (pvector-length (alloc-result-spilled alloc)) 0))))

(define (debug-allocation-records fn)
  (define records (fn-get-info fn 'debug-reg-maps '()))
  (define non-empty
    (filter (lambda (record) (not (debug-alloc-record-empty? record)))
            records))
  (if (null? non-empty) records non-empty))

(define (debug-resolve-coalesced reg coalesced)
  (let loop ([r reg] [seen (set)])
    (cond
      [(set-member? seen r) r]
      [(reg-om-ref coalesced r #f)
       => (lambda (next) (loop next (set-add seen r)))]
      [else r])))

(define (debug-register-byte-size reg)
  (case (reg-id-class reg)
    [(gpr) (if (<= (reg-id-width reg) 32) 4 8)]
    [(fpr) (case (reg-id-width reg)
             [(8) 1]
             [(16) 2]
             [(32) 4]
             [(64) 8]
             [else 16])]
    [else #f]))

(define (debug-dwarf-reg-number reg phys)
  (case (reg-id-class reg)
    [(gpr) phys]
    [(fpr) (+ 64 phys)]
    [else #f]))

(define (debug-record-view-specs record)
  (for/list ([view (in-list (hash-ref record 'views '()))]
             #:unless (debug-internal-reg-id? (hash-ref view 'reg)))
    (debug-variable-spec (hash-ref view 'reg)
                         (hash-ref view 'name)
                         (hash-ref view 'byte-size))))

(define (debug-fallback-variable-specs alloc)
  (define assignment (alloc-result-assignment alloc))
  (define coalesced (alloc-result-coalesced alloc))
  (define assigned-regs
    (for/list ([kv (in-reg-om assignment)]
               #:when (reg-id-virtual? (car kv)))
      (car kv)))
  (define coalesced-regs
    (for/list ([kv (in-reg-om coalesced)]
               #:when (reg-id-virtual? (car kv)))
      (car kv)))
  (define candidate-regs
    (filter (lambda (reg) (not (debug-internal-reg-id? reg)))
            (remove-duplicates (append assigned-regs coalesced-regs))))
  (for/list ([reg (in-list candidate-regs)])
    (debug-variable-spec reg
                         (debug-reg-id->name reg)
                         (or (debug-register-byte-size reg) 8))))

(define (debug-variable-specs record alloc)
  (define view-specs (debug-record-view-specs record))
  (define view-names
    (for/set ([spec (in-list view-specs)])
      (debug-variable-spec-name spec)))
  (define view-regs
    (for/set ([spec (in-list view-specs)])
      (debug-variable-spec-reg spec)))
  (append
   view-specs
   (for/list ([spec (in-list (debug-fallback-variable-specs alloc))]
              #:unless (or (set-member? view-regs (debug-variable-spec-reg spec))
                            (set-member? view-names (debug-variable-spec-name spec))))
     spec)))

(define (debug-record->variables record)
  (define alloc (hash-ref record 'allocation #f))
  (define abi (hash-ref record 'effective-abi #f))
  (if (and alloc abi)
      (let* ([assignment (alloc-result-assignment alloc)]
             [coalesced (alloc-result-coalesced alloc)]
             [specs (debug-variable-specs record alloc)])
        (filter
         values
         (for/list ([spec (in-list specs)])
           (define reg (debug-variable-spec-reg spec))
           (define resolved (debug-resolve-coalesced reg coalesced))
           (define color
             (cond
               [(reg-id-physical? resolved)
                (abi-reg->color abi (reg-id-class resolved) (reg-id-id resolved))]
               [else
                (reg-om-ref assignment resolved #f)]))
           (define phys
             (and color
                  (abi-color->reg abi (reg-id-class resolved) color)))
           (define dwarf-reg
             (and phys (debug-dwarf-reg-number reg phys)))
           (and dwarf-reg
                (debug-variable (debug-variable-spec-name spec)
                                (debug-variable-spec-byte-size spec)
                                dwarf-reg)))))
      '()))

(define (debug-register-function!/port fn low-label high-label port)
  (define state (current-debug-file-state))
  (when (and state
             (emit-config-emit-debug-info? (current-emit-config)))
    (define new-vars
      (append-map debug-record->variables
                  (debug-allocation-records fn)))
    (define deduped
      (for/fold ([vars '()]
                 [names (set)]
                 #:result (reverse vars))
                ([var (in-list new-vars)])
        (define name (debug-variable-name var))
        (if (set-member? names name)
            (values vars names)
             (values (cons var vars) (set-add names name)))))
    (set-debug-file-state-functions!
     state
     (append (debug-file-state-functions state)
             (list (debug-function (fn-debug-display-name fn)
                                   low-label
                                   high-label
                                   deduped))))))

(define (emit-debug-section/port name port)
  (case (emit-config-syntax (current-emit-config))
    [(apple)
     (port-write-string port ".section __DWARF,__")
     (port-write-string port name)
     (port-write-string port ",regular,debug")]
    [else
     (port-write-string port ".section .")
     (port-write-string port name)])
  (port-newline port))

(define (emit-asm-directive/port directive value port)
  (port-write-string port directive)
  (port-write-string port " ")
  (port-display port value)
  (port-newline port))

(define (emit-asm-string-directive/port directive value port)
  (port-write-string port directive)
  (port-write-string port " ")
  (write value port)
  (port-newline port))

(define (emit-asm-label/port label port)
  (port-write-string port label)
  (port-write-string port ":")
  (port-newline port))

(define (emit-dwarf-attr/port attr form port)
  (emit-asm-directive/port ".byte" attr port)
  (emit-asm-directive/port ".byte" form port))

(define (emit-dwarf-abbrev/port code tag children? attrs port)
  (emit-asm-directive/port ".byte" code port)
  (emit-asm-directive/port ".byte" tag port)
  (emit-asm-directive/port ".byte" (if children? 1 0) port)
  (for ([attr (in-list attrs)])
    (emit-dwarf-attr/port (car attr) (cdr attr) port))
  (emit-asm-directive/port ".byte" 0 port)
  (emit-asm-directive/port ".byte" 0 port))

(define (emit-debug-ref4/port target-label port)
  (port-write-string port ".long ")
  (port-write-string port target-label)
  (port-write-string port "-")
  (port-write-string port (debug-info-section-label))
  (port-newline port))

(define (emit-debug-exprloc-reg/port dwarf-reg port)
  (cond
    [(<= 0 dwarf-reg 31)
     (emit-asm-directive/port ".byte" 1 port)
     (emit-asm-directive/port ".byte" (+ #x50 dwarf-reg) port)]
    [else
     (emit-asm-directive/port ".byte" 2 port)
     (emit-asm-directive/port ".byte" #x90 port)
     (emit-asm-directive/port ".uleb128" dwarf-reg port)]))

(define (debug-variable-type-label var)
  (if (<= (debug-variable-byte-size var) 4)
      (debug-u32-type-label)
      (debug-u64-type-label)))

(define (emit-debug-text-label/port label port)
  (when (emit-config-emit-debug-info? (current-emit-config))
    (port-write-string port label)
    (port-write-string port ":")
    (port-newline port)))

(define (emit-debug-text-begin/port port)
  (emit-debug-text-label/port (debug-text-begin-label) port))

(define (emit-debug-text-end/port port)
  (emit-debug-text-label/port (debug-text-end-label) port))

(define (emit-debug-text-begin)
  (define out (open-output-string))
  (emit-debug-text-begin/port out)
  (get-output-string out))

(define (emit-debug-text-end)
  (define out (open-output-string))
  (emit-debug-text-end/port out)
  (get-output-string out))

(define (emit-debug-dwarf-footer/port port)
  (define config (current-emit-config))
  (define state (current-debug-file-state))
  (when (and (emit-config-emit-debug-info? config)
             (debug-state-has-files? state))
    (define primary-source (debug-primary-source state))
    (define comp-dir (debug-current-comp-dir))
    (define info-start (debug-info-start-label))
    (define info-end (debug-info-end-label))
    (define text-begin (debug-text-begin-label))
    (define text-end (debug-text-end-label))

    ;; Minimal DWARF v4 compile unit. The assembler emits .debug_line from
    ;; .file/.loc; this CU gives debuggers a DIE that points at that line table.
    ;; Virtual registers with stable physical-register assignments are exported
    ;; as whole-text DW_TAG_variable entries. This is intentionally coarse; it
    ;; makes the current mapping inspectable without pretending to have precise
    ;; per-instruction location lists.
    (define info-section (debug-info-section-label))
    (define u64-type (debug-u64-type-label))
    (define u32-type (debug-u32-type-label))
    (define functions
      (let ([registered (debug-file-state-functions state)])
        (if (null? registered)
            (list (debug-function "asmp_text" text-begin text-end '()))
            registered)))

    (port-newline port)
    (emit-debug-section/port "debug_abbrev" port)
    (emit-dwarf-abbrev/port
     1 17 #t
     (list (cons 37 8)    ; DW_AT_producer, DW_FORM_string
           (cons 19 5)    ; DW_AT_language, DW_FORM_data2
           (cons 3 8)     ; DW_AT_name, DW_FORM_string
           (cons 27 8)    ; DW_AT_comp_dir, DW_FORM_string
           (cons 16 23)   ; DW_AT_stmt_list, DW_FORM_sec_offset
           (cons 17 1)    ; DW_AT_low_pc, DW_FORM_addr
           (cons 18 1))   ; DW_AT_high_pc, DW_FORM_addr
     port)
    (emit-dwarf-abbrev/port
     2 36 #f
     (list (cons 3 8)     ; DW_AT_name, DW_FORM_string
           (cons 62 11)   ; DW_AT_encoding, DW_FORM_data1
           (cons 11 11))  ; DW_AT_byte_size, DW_FORM_data1
     port)
    (emit-dwarf-abbrev/port
     3 46 #t
     (list (cons 3 8)     ; DW_AT_name, DW_FORM_string
           (cons 17 1)    ; DW_AT_low_pc, DW_FORM_addr
           (cons 18 1)    ; DW_AT_high_pc, DW_FORM_addr
           (cons 64 24))  ; DW_AT_frame_base, DW_FORM_exprloc
     port)
    (emit-dwarf-abbrev/port
     4 52 #f
     (list (cons 3 8)     ; DW_AT_name, DW_FORM_string
           (cons 73 19)   ; DW_AT_type, DW_FORM_ref4
           (cons 2 24))   ; DW_AT_location, DW_FORM_exprloc
     port)
    (emit-asm-directive/port ".byte" 0 port)

    (emit-debug-section/port "debug_info" port)
    (emit-asm-label/port info-section port)
    (port-write-string port ".long ")
    (port-write-string port info-end)
    (port-write-string port "-")
    (port-write-string port info-start)
    (port-newline port)
    (emit-asm-label/port info-start port)
    (emit-asm-directive/port ".short" 4 port)
    (emit-asm-directive/port ".long" 0 port)
    (emit-asm-directive/port ".byte" 8 port)
    (emit-asm-directive/port ".byte" 1 port)
    (emit-asm-string-directive/port ".asciz" "asmp" port)
    ;; LLDB treats DW_LANG_Mips_Assembler as line-only assembly and does not
    ;; surface local variables. C11 keeps source line support while allowing
    ;; register-backed asmp virtual variables to show up in `frame variable`.
    (emit-asm-directive/port ".short" 29 port)
    (emit-asm-string-directive/port ".asciz" primary-source port)
    (emit-asm-string-directive/port ".asciz" comp-dir port)
    (emit-asm-directive/port ".long" 0 port)
    (emit-asm-directive/port ".quad" text-begin port)
    (emit-asm-directive/port ".quad" text-end port)

    (emit-asm-label/port u64-type port)
    (emit-asm-directive/port ".byte" 2 port)
    (emit-asm-string-directive/port ".asciz" "asmp_u64" port)
    (emit-asm-directive/port ".byte" 7 port)
    (emit-asm-directive/port ".byte" 8 port)

    (emit-asm-label/port u32-type port)
    (emit-asm-directive/port ".byte" 2 port)
    (emit-asm-string-directive/port ".asciz" "asmp_u32" port)
    (emit-asm-directive/port ".byte" 7 port)
    (emit-asm-directive/port ".byte" 4 port)

    (for ([fn (in-list functions)])
      (emit-asm-directive/port ".byte" 3 port)
      (emit-asm-string-directive/port ".asciz" (debug-function-name fn) port)
      (emit-asm-directive/port ".quad" (debug-function-low-label fn) port)
      (emit-asm-directive/port ".quad" (debug-function-high-label fn) port)
      (emit-asm-directive/port ".byte" 1 port)
      (emit-asm-directive/port ".byte" #x9c port)
      (for ([var (in-list (debug-function-variables fn))])
        (emit-asm-directive/port ".byte" 4 port)
        (emit-asm-string-directive/port ".asciz" (debug-variable-name var) port)
        (emit-debug-ref4/port (debug-variable-type-label var) port)
        (emit-debug-exprloc-reg/port (debug-variable-dwarf-reg var) port))
      (emit-asm-directive/port ".byte" 0 port))
    (emit-asm-directive/port ".byte" 0 port)
    (emit-asm-label/port info-end port)))

(define (emit-debug-dwarf-footer)
  (define out (open-output-string))
  (emit-debug-dwarf-footer/port out)
  (get-output-string out))

(define (emit-debug-loc/port node port)
  (define config (current-emit-config))
  (when (emit-config-emit-debug-info? config)
    (define loc (ast-srcloc node))
    (when (valid-debug-loc? loc)
      (define file-id (debug-file-id/emit (srcloc-source loc) port))
      (define line (srcloc-line loc))
      (define column (debug-loc-column loc))
      (define loc-key (list file-id line column))
      (define state (current-debug-file-state))
      (unless (equal? loc-key (debug-file-state-last-loc state))
        (set-debug-file-state-last-loc! state loc-key)
        (port-write-string port ".loc ")
        (port-display port file-id)
        (port-write-string port " ")
        (port-display port line)
        (port-write-string port " ")
        (port-display port column)
        (port-newline port)))))

(define (gpr-reg-num r)
  (and (ast-reg? r)
       (memq (ast-reg-kind r) '(x w))
       (number? (ast-reg-id r))
       (ast-reg-id r)))

(define (sp-reg? r)
  (and (ast-reg? r)
       (eq? (ast-reg-kind r) 'x)
       (eq? (ast-reg-id r) 'sp)))

(define (cfi-reg-name reg)
  (match reg
    ['sp "sp"]
    [(? number? n) (format "w~a" n)]))

(define (emit-cfi-directive/port port directive . args)
  (port-write-string port ".")
  (port-write-string port directive)
  (for ([arg (in-list args)]
        [i (in-naturals)])
    (if (= i 0)
        (port-write-string port " ")
        (port-write-string port ", "))
    (port-display port arg))
  (port-newline port))

(define (emit-cfi-def-cfa/port reg offset port)
  (define state (current-cfi-state))
  (when (and state
             (not (and (equal? reg (cfi-state-cfa-reg state))
                       (= offset (cfi-state-cfa-offset state)))))
    (set-cfi-state-cfa-reg! state reg)
    (set-cfi-state-cfa-offset! state offset)
    (emit-cfi-directive/port port "cfi_def_cfa" (cfi-reg-name reg) offset)))

(define (emit-cfi-def-cfa-offset/port offset port)
  (define state (current-cfi-state))
  (when (and state
             (eq? (cfi-state-cfa-reg state) 'sp)
             (not (= offset (cfi-state-cfa-offset state))))
    (set-cfi-state-cfa-offset! state offset)
    (emit-cfi-directive/port port "cfi_def_cfa_offset" offset)))

(define (emit-cfi-offset/port reg offset port)
  (emit-cfi-directive/port port "cfi_offset" (cfi-reg-name reg) offset))

(define (emit-cfi-restore/port reg port)
  (emit-cfi-directive/port port "cfi_restore" (cfi-reg-name reg)))

(define (imm-int op)
  (and (ast-imm? op) (ast-imm-value op)))

(define (sp-mem-offset mem)
  (and (ast-mem? mem)
       (sp-reg? (ast-mem-base mem))
       (imm-int (ast-mem-offset mem))))

(define (cfi-update-sp-offset!/port delta port)
  (define state (current-cfi-state))
  (when state
    (define new-offset (+ (cfi-state-sp-offset state) delta))
    (set-cfi-state-sp-offset! state new-offset)
    (emit-cfi-def-cfa-offset/port (- new-offset) port)))

(define (cfi-current-stack-slot-offset slot-offset)
  (define state (current-cfi-state))
  (+ (cfi-state-sp-offset state) slot-offset))

(define (emit-cfi-saved-gpr/port reg slot-offset port)
  (define n (gpr-reg-num reg))
  (when n
    (emit-cfi-offset/port n (cfi-current-stack-slot-offset slot-offset) port)))

(define (emit-cfi-restore-gpr/port reg port)
  (define n (gpr-reg-num reg))
  (when n
    (define state (current-cfi-state))
    (when (and state (equal? n (cfi-state-cfa-reg state)))
      (emit-cfi-def-cfa/port 'sp (- (cfi-state-sp-offset state)) port))
    (emit-cfi-restore/port n port)))

(define (emit-cfi-after-ins/port ins port)
  (define config (current-emit-config))
  (when (and (emit-config-emit-cfi? config)
             (current-cfi-state)
             (ast-ins? ins))
    (match ins
      [(ast-ins 'sub #f (list (? sp-reg?) (? sp-reg?) imm) _)
       (define n (imm-int imm))
       (when n (cfi-update-sp-offset!/port (- n) port))]
      [(ast-ins 'add #f (list (? sp-reg?) (? sp-reg?) imm) _)
       (define n (imm-int imm))
       (when n (cfi-update-sp-offset!/port n port))]
      [(ast-ins 'mov #f (list dst (? sp-reg?)) _)
       (define dst-num (gpr-reg-num dst))
       (when dst-num
         (define state (current-cfi-state))
         (emit-cfi-def-cfa/port dst-num (- (cfi-state-sp-offset state)) port))]
      [(ast-ins 'stp #f (list r1 r2 mem) _)
       (define off (sp-mem-offset mem))
       (when off
         (case (ast-mem-index-mode mem)
           [(pre)
            (cfi-update-sp-offset!/port off port)
            (emit-cfi-saved-gpr/port r1 0 port)
            (emit-cfi-saved-gpr/port r2 8 port)]
           [(offset)
            (emit-cfi-saved-gpr/port r1 off port)
            (emit-cfi-saved-gpr/port r2 (+ off 8) port)]
           [else (void)]))]
      [(ast-ins 'str #f (list r mem) _)
       (define off (sp-mem-offset mem))
       (when (and off (eq? (ast-mem-index-mode mem) 'offset))
         (emit-cfi-saved-gpr/port r off port))]
      [(ast-ins 'ldp #f (list r1 r2 mem) _)
       (define off (sp-mem-offset mem))
       (when off
         (case (ast-mem-index-mode mem)
           [(post)
            (cfi-update-sp-offset!/port off port)
            (emit-cfi-restore-gpr/port r1 port)
            (emit-cfi-restore-gpr/port r2 port)]
           [(offset)
            (emit-cfi-restore-gpr/port r1 port)
            (emit-cfi-restore-gpr/port r2 port)]
           [else (void)]))]
      [(ast-ins 'ldr #f (list r mem) _)
       (define off (sp-mem-offset mem))
       (when (and off (eq? (ast-mem-index-mode mem) 'offset))
         (emit-cfi-restore-gpr/port r port))]
      [_ (void)])))

;; ============================================================
;; 寄存器输出
;; ============================================================

;; 直接写入端口版本
(define (emit-reg/port reg port)
  (match-define (ast-reg kind id group-size index element pred-mode _) reg)

  ;; 基础寄存器名
  (match* (kind id)
    ;; 特殊寄存器
    [('x 'sp) (port-write-string port "sp")]
    [('w 'sp) (port-write-string port "wsp")]
    [('x 'zr) (port-write-string port "xzr")]
    [('w 'zr) (port-write-string port "wzr")]
    ;; 物理寄存器
    [(_ (? number? n))
     (port-write-string port (reg-kind->asm-prefix kind))
     (port-display port n)]
    ;; 虚拟寄存器 (应该已经被分配，这里是错误情况)
    [(_ (? symbol? name))
     (error 'emit-reg "未分配的虚拟寄存器: ~a.~a" kind name)])

  ;; 添加元素大小/排列 (SVE/NEON)
  (when element
    (port-write-string port ".")
    (port-display port element))

  ;; 添加 lane index (SIMD 元素访问，无 group-size 时)
  (when (and index (not group-size))
    (port-write-string port "[")
    (port-display port index)
    (port-write-string port "]"))

  ;; 添加谓词模式
  (case pred-mode
    [(m) (port-write-string port "/m")]
    [(z) (port-write-string port "/z")]
    [else (void)]))

;; 返回字符串版本 (兼容)
(define (emit-reg reg)
  (define out (open-output-string))
  (emit-reg/port reg out)
  (get-output-string out))

;; ============================================================
;; 操作数输出
;; ============================================================

(define (reloc->gnu-prefix reloc)
  (case reloc
    ;; GNU AArch64 assemblers infer the page relocation from ADRP's operand.
    ;; LLVM integrated assembler rejects ":pg_hi21:sym" in that position.
    [(PAGE) ""]
    [(PAGEOFF) ":lo12:"]
    [(GOTPAGE) ":got:"]
    [(GOTPAGEOFF) ":got_lo12:"]
    [else (error 'emit-operand "未知 relocation 修饰符: ~a" reloc)]))

(define (reloc->apple-suffix reloc)
  (case reloc
    [(PAGE) "@PAGE"]
    [(PAGEOFF) "@PAGEOFF"]
    [(GOTPAGE) "@GOTPAGE"]
    [(GOTPAGEOFF) "@GOTPAGEOFF"]
    [else (error 'emit-operand "未知 relocation 修饰符: ~a" reloc)]))

(define (emit-data-value/port value port)
  (cond
    [(integer? value) (port-display port value)]
    [(string? value) (write value port)]
    [(ast-label? value) (emit-operand/port value port)]
    [else (port-display port value)]))

(define (emit-data-values/port values port)
  (for ([value (in-list values)]
        [i (in-naturals)])
    (when (> i 0)
      (port-write-string port ", "))
    (emit-data-value/port value port)))

(define (sized-data-directive->asm kind)
  (case kind
    [(byte) ".byte"]
    [(byte2) ".2byte"]
    [(byte4) ".4byte"]
    [(byte8) ".8byte"]
    [(byte16 byte32) ".octa"]
    [else #f]))

(define (sized-data-width kind)
  (case kind
    [(byte) 1]
    [(byte2) 2]
    [(byte4) 4]
    [(byte8) 8]
    [(byte16) 16]
    [(byte32) 32]
    [else (error 'emit-directive "未知数据宽度 directive: ~a" kind)]))

(define (integer-in-sized-data-range? kind n)
  (define bits (* 8 (sized-data-width kind)))
  (<= (- (expt 2 (sub1 bits))) n (sub1 (expt 2 bits))))

(define (integer->unsigned-sized-data kind n)
  (define bits (* 8 (sized-data-width kind)))
  (define modulus (expt 2 bits))
  (if (negative? n) (+ modulus n) n))

(define (byte32-octa-parts n)
  (define unit (expt 2 128))
  (define u (integer->unsigned-sized-data 'byte32 n))
  (values (modulo u unit) (quotient u unit)))

(define (emit-sized-data-values/port kind values port)
  (case kind
    [(byte32)
     (for ([value (in-list values)]
           [i (in-naturals)])
       (unless (integer? value)
         (error 'emit-directive ".byte32 supports integer values only"))
       (unless (integer-in-sized-data-range? kind value)
         (error 'emit-directive ".byte32 integer out of range: ~a" value))
       (define-values (low high) (byte32-octa-parts value))
       (when (> i 0)
         (port-write-string port ", "))
       (port-display port low)
       (port-write-string port ", ")
       (port-display port high))]
    [else
     (for ([value (in-list values)])
       (when (integer? value)
         (unless (integer-in-sized-data-range? kind value)
           (error 'emit-directive ".~a integer out of range: ~a" kind value)))
       (when (and (> (sized-data-width kind) 8)
                  (not (integer? value)))
         (error 'emit-directive ".~a supports integer values only" kind)))
     (emit-data-values/port values port)]))

(define (section-name-for-config name config)
  (define raw (format "~a" name))
  (case (emit-config-syntax config)
    [(apple)
     (case (string->symbol raw)
       [(.rodata) "__TEXT,__const"]
       [(.data) "__DATA,__data"]
       [(.bss) "__DATA,__bss"]
       [else raw])]
    [else raw]))

(define (emit-label-name/port name port)
  (define fn-name (current-function-name))
  (define local-labels (current-function-labels))
  (define label-aliases (current-function-label-aliases))
  (define canonical-name (hash-ref label-aliases name name))
  ;; 输出基础标签名
  (cond
    ;; 被合并的标签 -> 输出函数名
    [(set-member? (merged-labels) canonical-name)
     (define prefix (emit-config-label-prefix (current-emit-config)))
     (emit-asm-symbol/port fn-name port prefix)]
    ;; 函数内的局部标签
    [(and fn-name (set-member? local-labels name))
     (port-write-string port (make-local-label fn-name canonical-name))]
    ;; 外部引用 (函数名等)
    [else
     (define prefix (emit-config-label-prefix (current-emit-config)))
     (emit-asm-symbol/port name port prefix)]))

;; 直接写入端口版本
(define (emit-operand/port op port)
  (match op
    ;; 寄存器 - 带 group-size 但无 index 的作为寄存器列表输出
    ;; 有 index 的表示从组中选择单个寄存器，按普通寄存器输出
    [(ast-reg kind id group-size index element _ _)
     #:when (and group-size (>= group-size 1) (not index))
     (port-write-string port "{ ")
     (emit-reg/port op port)
     ;; 如果 group-size > 1，输出范围表示法 (如 z0.B - z3.B)
     (when (> group-size 1)
       (port-write-string port " - ")
       ;; 计算结束寄存器编号
       (define end-id
         (if (number? id)
             (+ id group-size -1)
             id))  ; 虚拟寄存器暂时不处理范围
       (port-write-string port (symbol->string kind))
       (if (number? end-id)
           (port-display port end-id)
           (begin
             (port-write-string port ".")
             (port-display port end-id)))
       (when element
         (port-write-string port ".")
         (port-write-string port (symbol->string element))))
     (port-write-string port " }")]

    ;; 普通寄存器 (包括带 index 的)
    [(ast-reg _ _ _ _ _ _ _)
     (emit-reg/port op port)]

    ;; 立即数
    [(ast-imm v _)
     (port-write-string port "#")
     (port-display port v)]

    ;; 标签引用
    [(ast-label name reloc _)
     (case (emit-config-syntax (current-emit-config))
       [(gnu)
        (when reloc
          (port-write-string port (reloc->gnu-prefix reloc)))
        (emit-label-name/port name port)]
       [(apple)
        (emit-label-name/port name port)
        (when reloc
          (port-write-string port (reloc->apple-suffix reloc)))]
       [else
        (emit-label-name/port name port)
        (when reloc
          (port-write-string port "@")
          (port-display port reloc))])]

    ;; 移位
    [(ast-shift kind amount _)
     (port-write-string port (string-upcase (symbol->string kind)))
     (when amount
       (port-write-string port " #")
       (port-display port amount))]

    ;; 扩展
    [(ast-extend kind amount _)
     (port-write-string port (string-upcase (symbol->string kind)))
     (when amount
       (port-write-string port " #")
       (port-display port amount))]

    ;; 条件码
    [(ast-cond code _)
     (port-write-string port (string-upcase (symbol->string code)))]

    ;; 内存寻址
    [(ast-mem base offset index-mode shift extend _)
     (emit-memory/port base offset index-mode shift extend port)]

    ;; 寄存器列表
    [(ast-reglist regs _)
     (port-write-string port "{ ")
     (for ([r (in-list regs)]
           [i (in-naturals)])
       (when (> i 0) (port-write-string port ", "))
       (emit-reg/port r port))
     (port-write-string port " }")]

    ;; 其他 (fallback)
    [_ (port-display port op)]))

;; 返回字符串版本 (兼容)
(define (emit-operand op)
  (define out (open-output-string))
  (emit-operand/port op out)
  (get-output-string out))

;; 内存寻址输出
(define (emit-memory/port base offset index-mode shift extend port)
  (case index-mode
    [(offset)
     (port-write-string port "[")
     (emit-reg/port base port)
     (when offset
       (port-write-string port ", ")
       (emit-operand/port offset port))
     (when shift
       (port-write-string port ", ")
       (emit-operand/port shift port))
     (when extend
       (port-write-string port ", ")
       (emit-operand/port extend port))
     (port-write-string port "]")]

    [(pre)
     (port-write-string port "[")
     (emit-reg/port base port)
     (when offset
       (port-write-string port ", ")
       (emit-operand/port offset port))
     (when shift
       (port-write-string port ", ")
       (emit-operand/port shift port))
     (when extend
       (port-write-string port ", ")
       (emit-operand/port extend port))
     (port-write-string port "]!")]

    [(post)
     (port-write-string port "[")
     (emit-reg/port base port)
     (port-write-string port "]")
     (when offset
       (port-write-string port ", ")
       (emit-operand/port offset port))]

    ;; SVE: [base, #imm, mul vl]
    [(sve-vl)
     (port-write-string port "[")
     (emit-reg/port base port)
     (when offset
       (port-write-string port ", ")
       (emit-operand/port offset port)
       (port-write-string port ", mul vl"))
     (port-write-string port "]")]))

;; ============================================================
;; 指令输出
;; ============================================================

;; 检测冗余指令 (如 mov x0, x0)
(define (redundant-instruction? ins)
  (match ins
    [(ast-ins (or 'mov 'fmov) #f (list dst src) _)
     (and (ast-reg? dst) (ast-reg? src)
          (equal? (ast-reg-kind dst) (ast-reg-kind src))
          (equal? (ast-reg-id dst) (ast-reg-id src)))]
    [(ast-ins 'orr #f (list dst src1 src2) _)
     (and (ast-reg? dst) (ast-reg? src1) (ast-reg? src2)
          (eq? (ast-reg-kind dst) 'z)
          (eq? (ast-reg-kind src1) 'z)
          (eq? (ast-reg-kind src2) 'z)
          (equal? (ast-reg-id dst) (ast-reg-id src1))
          (equal? (ast-reg-id dst) (ast-reg-id src2)))]
    [_ #f]))

;; mrs/msr 的系统寄存器操作数应按原名输出，不参与 Apple 符号前缀规则。
(define (sysreg-operand? mnem op)
  (and (memq mnem '(mrs msr))
       (ast-label? op)
       (not (ast-label-reloc op))
       (label-looks-like-system-reg? (ast-label-name op))))

;; 直接写入端口版本
(define (emit-instruction/port ins port)
  (match-define (ast-ins mnem suffix operands ins-loc) ins)
  (define config (current-emit-config))

  ;; 缩进
  (port-write-string port (emit-config-indent config))

  ;; 助记符
  (port-display port mnem)
  (when suffix
    (port-write-string port ".")
    (port-display port suffix))

  ;; 操作数
  ;; 注意: shift/extend 操作数后面的 amount 用空格分隔，不用逗号
  (unless (null? operands)
    (port-write-string port " ")
    (for ([op (in-list operands)]
          [prev (in-list (cons #f operands))]  ; 前一个操作数
          [i (in-naturals)])
      ;; 在操作数之间加逗号，但 shift/extend 后面只加空格
      (when (> i 0)
        (if (or (ast-shift? prev) (ast-extend? prev))
            (port-write-string port " ")    ; 空格: LSL #16
            (port-write-string port ", "))) ; 逗号: w1, #123
      (if (sysreg-operand? mnem op)
          ;; 具名系统寄存器发射时翻成结构式 Sx_x_Cx_Cx_x(下游汇编器都认,
          ;; 不依赖它是否认识新名字如 CNTVCTSS_EL0);结构式/未知名原样输出
          (let ([nm (ast-label-name op)])
            (port-write-string port
                               (or (sysreg->structural nm)
                                   (if (symbol? nm) (symbol->string nm) (format "~a" nm)))))
          (emit-operand/port op port))))

  ;; 源尾注释透传（侧表非空时按 loc 反查；见 parser/comments.rkt）
  (let ([comment (and (srcloc? ins-loc)
                      (source-comment-ref (srcloc-source ins-loc)
                                          (srcloc-line ins-loc)))])
    (when comment
      (port-write-string port "    ")
      (port-write-string port (emit-comment-prefix config))
      (port-write-string port " ")
      (port-write-string port comment))))

;; 返回字符串版本 (兼容)
(define (emit-instruction ins)
  (define out (open-output-string))
  (emit-instruction/port ins out)
  (get-output-string out))

;; ============================================================
;; Directive 输出
;; ============================================================

;; 直接写入端口版本，返回是否输出了内容
(define (emit-directive/port dir port)
  (match-define (ast-directive kind name args _) dir)
  (define config (current-emit-config))
  (define prefix (emit-config-label-prefix config))

  (case kind
    ;; 函数开始 (旧兼容路径 - 不输出 .globl，由 emit-function/port 根据 export 属性处理)
    [(function)
     (when (eq? (emit-config-syntax config) 'apple)
       (port-write-string port ".p2align 2")
       (port-newline port))
     (emit-asm-symbol/port name port prefix)
     (port-write-string port ":")
     #t]

    ;; 函数结束
    [(end-function)
     (when (emit-config-emit-cfi? config)
       (port-write-string port ".cfi_endproc")
       #t)
     #f]

    ;; 标签
    [(label)
     (port-write-string port prefix)
     (port-display port name)
     (port-write-string port ":")
     #t]

    ;; 节
    [(section)
     (port-write-string port ".section ")
     (port-display port (section-name-for-config name config))
     #t]

    ;; 对齐 (在代码段中使用 nop 填充)
    [(align)
     (port-write-string port (emit-config-indent config))
     (port-write-string port ".p2align ")
     (port-display port (car args))
     ;; ARM64 nop = 0xd503201f，汇编器在代码段默认会用 nop 填充
     #t]

    ;; 全局符号
    [(global)
     (port-write-string port ".globl ")
     (emit-asm-symbol/port name port prefix)
     #t]

    ;; 数据
    [(ascii asciz)
     (port-write-string port ".")
     (port-display port kind)
     (port-write-string port " ")
     (emit-data-values/port args port)
     #t]

    [(byte byte2 byte4 byte8 byte16 byte32)
     (port-write-string port (sized-data-directive->asm kind))
     (port-write-string port " ")
     (emit-sized-data-values/port kind args port)
     #t]

    ;; save!/load!/weak-mov/reg-interfere - 不直接输出 (由寄存器分配器处理)
    [(save! load! weak-mov reg-interfere) #f]

    ;; 其他
    [else
     (port-write-string port (emit-comment-prefix config))
     (port-write-string port " unknown directive: ")
     (port-display port kind)
     #t]))

;; 返回字符串版本 (兼容)
(define (emit-directive dir)
  (define out (open-output-string))
  (if (emit-directive/port dir out)
      (get-output-string out)
      ""))

;; ============================================================
;; 局部标签名称生成
;; ============================================================

;; 当前函数名 (用于生成局部标签)
(define current-function-name (make-parameter #f))

;; 当前函数的局部标签集合 (用于区分局部/外部引用)
(define current-function-labels (make-parameter (set)))

;; Same-position labels are represented as aliases of the one label emitted
;; for a block. This keeps inline-expanded call-site labels branchable.
(define current-function-label-aliases (make-parameter (hash)))

;; 被合并到函数名的标签集合 (当 merge-colocated-labels? 启用时使用)
(define merged-labels (make-parameter (set)))

;; 局部标签名到唯一 ID 的映射 (用于处理转换后可能重名的情况)
(define local-label-ids (make-parameter (hash)))

;; 生成局部标签名: L<func>$<label>
;; 使用 L 前缀使其成为局部标签（不导出到符号表）
;; 自动转换不合法的字符，并确保唯一性
(define (make-local-label fn-name label-name)
  (define sanitized-fn (sanitize-symbol fn-name))
  (define ids (local-label-ids))
  ;; 从预计算的映射中获取唯一标签名
  (define unique-label (hash-ref ids label-name (sanitize-symbol label-name)))
  (format "L~a$~a" sanitized-fn unique-label))

;; ============================================================
;; 函数输出 (高性能端口版本)
;; ============================================================

(define (emit-function/port fn port)
  (if (current-debug-file-state)
      (emit-function/port* fn port)
      (call-with-fresh-debug-file-state
       (lambda () (emit-function/port* fn port)))))

(define (emit-function/port* fn port)
  (define config (current-emit-config))
  (define prefix (emit-config-label-prefix config))
  (define fn-name (asm-function-name fn))
  (define merge-labels? (emit-config-merge-colocated-labels? config))
  (define debug-low-label (asm-symbol-token fn-name prefix))
  (define debug-high-label (debug-function-end-label fn-name))
  (debug-register-function!/port fn debug-low-label debug-high-label port)

  ;; 收集函数内的所有局部标签
  (define local-labels
    (for/set ([kv (in-hash-pairs (asm-function-label->id fn))])
      (car kv)))

  ;; Map every known label to the primary label printed for its basic block.
  (define label-aliases
    (for/hash ([kv (in-hash-pairs (asm-function-label->id fn))])
      (define label (car kv))
      (define bbid (cdr kv))
      (values label (or (fn-get-label fn bbid) label))))

  ;; 计算需要合并的标签 (入口块的局部标签，且不等于函数名)
  (define entry-id (asm-function-entry fn))
  (define entry-label
    (and entry-id (fn-get-label fn entry-id)))
  (define labels-to-merge
    (if (and merge-labels? entry-label (not (eq? entry-label fn-name)))
        (set entry-label)
        (set)))

  ;; 预计算所有标签的唯一映射 (处理转换后可能重名的情况)
  (define-values (label-id-map _used)
    (for/fold ([ids (hash)]
               [used-names (set)])
              ([label (in-set local-labels)])
      (define sanitized (sanitize-symbol label))
      (define unique-name
        (if (set-member? used-names sanitized)
            ;; 需要添加后缀
            (let loop ([i 1])
              (define candidate (format "~a_~a" sanitized i))
              (if (set-member? used-names candidate)
                  (loop (add1 i))
                  candidate))
            sanitized))
      (values (hash-set ids label unique-name)
              (set-add used-names unique-name))))

  ;; 设置当前函数上下文
  (parameterize ([current-function-name fn-name]
                 [current-function-labels local-labels]
                 [current-function-label-aliases label-aliases]
                 [merged-labels labels-to-merge]
                 [local-label-ids label-id-map]
                 [current-cfi-state (make-cfi-state)])

    ;; 获取函数对齐属性
    ;; = max(用户指定的对齐, 函数内部最大对齐)
    (define user-align (fn-get-info fn 'align 2))
    (define internal-align (fn-get-info fn 'max-internal-align 2))
    (define fn-align (max user-align internal-align))

    ;; 函数头 - 仅在有 (export) 属性时输出 .globl
    (define is-export? (fn-get-info fn 'export #f))
    (define visibility (fn-get-info fn 'visibility #f))
    (define binding (fn-get-info fn 'binding #f))
    (when (and is-export? (not (eq? visibility 'local)))
      (emit-symbol-binding/port fn-name binding port prefix config)
      (emit-symbol-visibility/port fn-name visibility port prefix config))

    ;; 对齐指令 (使用函数属性或默认值)
    (port-write-string port ".p2align ")
    (port-display port fn-align)
    (port-newline port)

    (emit-asm-symbol/port fn-name port prefix)
    (port-write-string port ":")
    (port-newline port)

    (when (emit-config-emit-cfi? config)
      (port-write-string port ".cfi_startproc")
      (port-newline port)
      (emit-cfi-def-cfa/port 'sp 0 port))

    ;; 按基本块顺序输出
    (define visited (make-hash))

    (define (ins-branch-info ins)
      (and (ast-ins? ins)
           (let ([info (branch-instruction? ins)])
             (and (branch-info? info) info))))

    (define (ins-return? ins)
      (define info (ins-branch-info ins))
      (and info (branch-info-is-return? info)))

    (define (ins-unconditional-branch? ins)
      (define info (ins-branch-info ins))
      (and info (eq? (branch-info-branch-type info) 'unconditional)))

    (define (ins-conditional-branch? ins)
      (define info (ins-branch-info ins))
      (and info (eq? (branch-info-branch-type info) 'conditional)))

    (define (branch-target-label ins)
      (and (ins-branch-info ins)
           (let ([target (extract-branch-target ins)])
             (and target
                  (eq? (target-info-kind target) 'label)
                  (target-info-value target)))))

    (define (skip-terminal-branch? block succs)
      (and (= (length succs) 1)
           (not (hash-has-key? visited (bb-id-val (car succs))))
           (let* ([instructions (basic-block-instructions block)]
                  [n (pvector-length instructions)])
             (and (> n 0)
                  (let* ([last-ins (pvector-ref instructions (sub1 n))]
                         [target (branch-target-label last-ins)]
                         [target-id (and target (fn-get-id fn target))])
                    (and target-id
                         (= (bb-id-val target-id)
                            (bb-id-val (car succs)))))))))

    (define (block-last-instruction block)
      (define instructions (basic-block-instructions block))
      (define n (pvector-length instructions))
      (and (> n 0) (pvector-ref instructions (sub1 n))))

    (define (conditional-fallthrough block succs)
      (define last-ins (block-last-instruction block))
      (and (ast-ins? last-ins)
           (ins-conditional-branch? last-ins)
           (let* ([target (branch-target-label last-ins)]
                  [target-id (and target (fn-get-id fn target))])
             (for/first ([succ (in-list succs)]
                         #:unless (and target-id
                                       (= (bb-id-val succ)
                                          (bb-id-val target-id))))
               succ))))

    (define (implicit-fallthrough block succs)
      (define last-ins (block-last-instruction block))
      (cond
        [(not (ast-ins? last-ins)) (and (= (length succs) 1) (car succs))]
        [(ins-return? last-ins) #f]
        [(ins-unconditional-branch? last-ins) #f]
        [(ins-conditional-branch? last-ins) (conditional-fallthrough block succs)]
        [else (and (= (length succs) 1) (car succs))]))

    (define (ordered-successors block succs)
      (define fallthrough (conditional-fallthrough block succs))
      (if fallthrough
          (cons fallthrough
                (filter (lambda (succ)
                          (not (= (bb-id-val succ) (bb-id-val fallthrough))))
                        succs))
          succs))

    (define (emit-synthetic-branch-to target-bbid)
      (define label (fn-get-label fn target-bbid))
      (when label
        (emit-instruction/port
         (ast-ins 'b #f (list (ast-label label #f no-srcloc)) no-srcloc)
         port)
        (port-newline port)))

    ;; BFS 遍历基本块
    (define (emit-block bb-id)
      (unless (hash-has-key? visited (bb-id-val bb-id))
        (hash-set! visited (bb-id-val bb-id) #t)
        (define block (fn-get-block fn (bb-id-val bb-id)))
        (when block
          (define succs (fn-successors fn bb-id))
          (define skip-last-branch? (skip-terminal-branch? block succs))
          ;; 标签
          (define label (fn-get-label fn bb-id))
          (when label
            ;; 跳过: 函数名标签、被合并的标签
            (unless (or (eq? label fn-name)
                        (set-member? labels-to-merge label))
              ;; 输出局部标签 (L<func>$<label>:)
              (port-write-string port (make-local-label fn-name label))
              (port-write-string port ":")
              (port-newline port)))

          ;; 指令
          (define instructions (basic-block-instructions block))
          (for ([ins (in-pvector instructions)]
                [i (in-naturals)])
            (cond
              [(ast-ins? ins)
               ;; 检查是否跳过冗余指令
               (unless (or (and skip-last-branch?
                                (= i (sub1 (pvector-length instructions))))
                           (and (emit-config-skip-redundant-mov? config)
                                (redundant-instruction? ins)))
                 (emit-debug-loc/port ins port)
                 (emit-instruction/port ins port)
                 (port-newline port)
                 (emit-cfi-after-ins/port ins port))]
              [(ast-directive? ins)
               (when (emit-directive/port ins port)
                 (port-newline port))]))

          (define fallthrough (implicit-fallthrough block succs))
          (when (and fallthrough
                     (hash-has-key? visited (bb-id-val fallthrough)))
            (emit-synthetic-branch-to fallthrough))

          ;; 后继块
          (for ([succ (in-list (ordered-successors block succs))])
            (emit-block succ)))))

    ;; 只有非空函数才输出基本块
    (when entry-id
      (emit-block entry-id))

    (when (emit-config-emit-cfi? config)
      (port-write-string port ".cfi_endproc")
      (port-newline port))
    (emit-debug-text-label/port debug-high-label port)))

;; 返回字符串版本 (兼容)
(define (emit-function fn)
  (define out (open-output-string))
  (emit-function/port fn out)
  ;; 移除末尾的换行符以保持与旧 API 兼容
  (define result (get-output-string out))
  (if (and (> (string-length result) 0)
           (char=? (string-ref result (sub1 (string-length result))) #\newline))
      (substring result 0 (sub1 (string-length result)))
      result))

;; 从 pipeline-result 输出
(define (emit-function/result result)
  (emit-function (pipeline-result-function result)))

;; ============================================================
;; 模块输出 (高性能端口版本)
;; ============================================================

(define (emit-module/port cfg port)
  (if (current-debug-file-state)
      (emit-module/port* cfg port)
      (call-with-fresh-debug-file-state
       (lambda () (emit-module/port* cfg port)))))

(define (emit-module/port* cfg port)
  (define config (current-emit-config))
  (define comment-prefix (emit-comment-prefix config))

  ;; 文件头
  (port-write-string port comment-prefix)
  (port-write-string port " Generated by asmp")
  (port-newline port)
  (port-write-string port comment-prefix)
  (port-write-string port " Syntax: ")
  (port-display port (emit-config-syntax config))
  (port-newline port)
  (port-newline port)
  (port-write-string port ".text")
  (port-newline port)
  (port-newline port)
  (emit-debug-text-begin/port port)

  ;; 所有函数
  (for ([i (in-range (cfg-function-count cfg))])
    (define fn (cfg-get-function cfg i))
    (when (and fn (not (fn-get-info fn 'inline-only #f)))
      (emit-function/port fn port)
      (port-newline port)))

  (emit-debug-text-end/port port)
  (emit-module-items/port (cfg-get-info cfg 'module-items '()) port)
  (emit-debug-dwarf-footer/port port)
  (when (eq? (emit-config-syntax config) 'apple)
    (port-write-string port ".subsections_via_symbols")
    (port-newline port)))

(define (emit-module-items/port items port)
  (when (pair? items)
    (port-newline port)
    (for ([item (in-list items)])
      (define rendered (emit-directive item))
      (unless (string=? rendered "")
        (port-write-string port rendered)
        (port-newline port)))))

;; 返回字符串版本 (兼容)
(define (emit-module cfg)
  (define out (open-output-string))
  (emit-module/port cfg out)
  (get-output-string out))

;; 输出到文件 (使用高性能端口版本)
(define (emit-to-file cfg path #:config [config (current-emit-config)])
  (parameterize ([current-emit-config config])
    (call-with-output-file path
      (lambda (out)
        (emit-module/port cfg out))
      #:exists 'truncate/replace)))

;; 输出到端口 (使用高性能端口版本)
(define (emit-to-port cfg port #:config [config (current-emit-config)])
  (parameterize ([current-emit-config config])
    (emit-module/port cfg port)))

;; ============================================================
;; 工具函数
;; ============================================================

(define (format-label name)
  (define config (current-emit-config))
  (define prefix (emit-config-label-prefix config))
  (asm-symbol-token name prefix))

(define (indent-line line)
  (define config (current-emit-config))
  (string-append (emit-config-indent config) line))
