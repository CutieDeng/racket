#lang racket

;; ============================================================
;; pipeline/regalloc/abi-config.rkt - ABI 配置加载
;; ============================================================
;;
;; 从配置文件加载 ABI 定义，支持命名 ABI
;; 支持新配置格式：
;;   - (args 0 1 2 ...) - 参数寄存器列表
;;   - (return 0 1 ...) - 返回寄存器列表
;;   - (extends parent) - 继承父 ABI
;;   - (special-regs ...) - 特殊寄存器映射

(require "abi.rkt"
         racket/intbits
         racket/file
         racket/string)

(provide
  ;; 配置加载
  load-abi-config
  get-abi-by-name
  reload-abi-config                      ; [新增] 重新加载配置

  ;; 参数
  abi-config-path
  default-abi-name

  ;; 验证
  validate-function-abi

  ;; 特殊寄存器查询 [新增]
  abi-get-special-regs
  abi-get-special-reg)

;; ============================================================
;; 配置参数
;; ============================================================

(define abi-config-path (make-parameter "config/abi.rktd"))
(define default-abi-name (make-parameter #f))

;; ============================================================
;; 配置加载
;; ============================================================

;; 缓存
(define *abi-cache* (box #f))

;; 清除缓存并重新加载
(define (reload-abi-config [path (abi-config-path)] #:force? [force? #f])
  (if force?
      (begin
        (set-box! *abi-cache* #f)
        (load-abi-config path))
      ;; 默认走增量刷新：文件未变化则直接复用缓存
      (load-abi-config path)))

(struct abi-cache-state
  (path       ; path-string - 规范化后的配置路径
   exists?    ; boolean
   mtime      ; integer|#f
   size       ; integer|#f
   configs)   ; hash[symbol -> abi-config]
  #:transparent)

(define (normalize-config-path path)
  (define p (if (path? path) path (string->path path)))
  (path->string (simplify-path (path->complete-path p))))

(define (config-stamp path-str)
  (if (file-exists? path-str)
      (values #t
              (file-or-directory-modify-seconds path-str)
              (file-size path-str))
      (values #f #f #f)))

;; 加载配置文件
(define (load-abi-config [path (abi-config-path)])
  (define path* (normalize-config-path path))
  (define-values (exists? mtime size) (config-stamp path*))
  (define cached (unbox *abi-cache*))

  (define cache-hit?
    (and (abi-cache-state? cached)
         (equal? path* (abi-cache-state-path cached))
         (equal? exists? (abi-cache-state-exists? cached))
         (equal? mtime (abi-cache-state-mtime cached))
         (equal? size (abi-cache-state-size cached))))

  (if cache-hit?
      (abi-cache-state-configs cached)
      (let ()
        (define raw-configs
          (if exists?
              (with-input-from-file path*
                (lambda ()
                  (let loop ([items '()])
                    (define datum (read))
                    (if (eof-object? datum)
                        (reverse items)
                        (loop (cons datum items))))))
              '()))

        ;; 第一遍：收集所有原始配置
        (define raw-hash (make-hash))
        (for ([cfg (in-list raw-configs)])
          (match cfg
            [(cons name props)
             (hash-set! raw-hash name props)]
            [_ (void)]))

        ;; 第二遍：解析配置（支持继承）
        (define parsed-hash (make-hash))
        (for ([(name props) (in-hash raw-hash)])
          (hash-set! parsed-hash name
                     (parse-abi-props-with-inherit name props raw-hash parsed-hash)))

        (set-box! *abi-cache*
                  (abi-cache-state path* exists? mtime size parsed-hash))
        parsed-hash)))

;; 解析 ABI 属性（带继承支持）
(define (parse-abi-props-with-inherit name props raw-hash parsed-hash)
  ;; 检查是否有 extends
  (define extends-name
    (for/first ([p (in-list props)]
                #:when (and (pair? p) (eq? (car p) 'extends)))
      (cadr p)))

  ;; 如果有继承，先确保父 ABI 已解析
  (when (and extends-name (not (hash-has-key? parsed-hash extends-name)))
    (when (hash-has-key? raw-hash extends-name)
      (hash-set! parsed-hash extends-name
                 (parse-abi-props-with-inherit extends-name
                                               (hash-ref raw-hash extends-name)
                                               raw-hash parsed-hash))))

  ;; 获取父配置（如果有）
  (define parent-abi
    (and extends-name (hash-ref parsed-hash extends-name #f)))

  ;; 解析当前配置
  (define abi (parse-abi-props props parent-abi))
  (define errs (abi-invariant-errors abi))
  (when (pair? errs)
    (error 'load-abi-config
           (format "ABI '~a' 定义非法:\n~a"
                   name
                   (string-join errs "\n"))))

  ;; extends 的偏序约束：parent ⊑ child（按 scratch-effect）
  (when parent-abi
    (define parent-eff (abi->effect parent-abi))
    (define child-eff (abi->effect abi))
    (unless (abi-effect<=? parent-eff child-eff)
    (define gpr-missing
      (for/list ([r (in-intbits (intbits-subtract (abi-effect-gpr-scratch parent-eff)
                                                (abi-effect-gpr-scratch child-eff)))])
        r))
    (define fpr-missing
      (for/list ([r (in-intbits (intbits-subtract (abi-effect-fpr-scratch parent-eff)
                                                (abi-effect-fpr-scratch child-eff)))])
        r))
    (define pred-missing
      (for/list ([r (in-intbits (intbits-subtract (abi-effect-pred-scratch parent-eff)
                                                (abi-effect-pred-scratch child-eff)))])
        r))
    (error 'load-abi-config
           (format "ABI '~a' extends '~a' 违反 ABI 格约束 (需要 parent ⊑ child)\n  缺失 scratch: gpr=~a fpr=~a pred=~a"
                   name extends-name gpr-missing fpr-missing pred-missing))))
  abi)

;; 解析 ABI 属性到 abi-config
;;
;; 新配置格式:
;;   (gpr (num-regs N) (banned BITS) (preserved BITS) (args 0 1 ...) (return 0))
;;   (fpr ...)
;;   (pred ...)
;;   (extends parent-name)
;;   (special-regs (sp 31) (fp 29) ...)
;;
;; 旧配置格式（向后兼容）:
;;   (class num-regs banned preserved)
(define (parse-abi-props props parent-abi)
  (define class-configs (make-hash))  ; symbol -> reg-class-config

  (for ([p (in-list props)])
    (match p
      ;; 新格式: (class (key val) ...) - 列表格式配置
      [(list (== 'gpr) (list 'num-regs num) rest ...)
       (hash-set! class-configs 'gpr
                  (parse-class-config-new 'gpr num rest
                    (and parent-abi (abi-config-gpr parent-abi))))]
      [(list (== 'fpr) (list 'num-regs num) rest ...)
       (hash-set! class-configs 'fpr
                  (parse-class-config-new 'fpr num rest
                    (and parent-abi (abi-config-fpr parent-abi))))]
      [(list (== 'pred) (list 'num-regs num) rest ...)
       (hash-set! class-configs 'pred
                  (parse-class-config-new 'pred num rest
                    (and parent-abi (abi-config-pred parent-abi))))]

      ;; 旧格式: (class num-regs banned preserved) - 向后兼容
      [(list class-name num-regs banned preserved)
       #:when (memq class-name '(gpr fpr pred))
       (hash-set! class-configs class-name
                  (make-reg-class-config
                    #:num-regs num-regs
                    #:banned (integer->intbits banned)
                    #:preserved (integer->intbits preserved)))]

      ;; special-regs: (special-regs (sp 31) (fp 29) ...) - 记录但暂不使用
      [(list 'special-regs regs ...) (void)]

      ;; extends - 已在外层处理
      [(list 'extends _) (void)]

      ;; (key . value) - 忽略其他属性
      [(cons key value) (void)]
      [_ (void)]))

  ;; 构建结果
  (define gpr-cfg
    (hash-ref class-configs 'gpr
              (lambda ()
                (or (and parent-abi (abi-config-gpr parent-abi))
                    (make-reg-class-config #:num-regs 31)))))
  (define fpr-cfg
    (hash-ref class-configs 'fpr
              (lambda ()
                (or (and parent-abi (abi-config-fpr parent-abi))
                    (make-reg-class-config #:num-regs 32)))))
  (define pred-cfg
    (hash-ref class-configs 'pred
              (lambda ()
                (or (and parent-abi (abi-config-pred parent-abi))
                    (make-reg-class-config #:num-regs 16)))))

  ;; 返回标准 abi-config
  (abi-config gpr-cfg fpr-cfg pred-cfg))

;; 解析新格式的类配置
(define (parse-class-config-new class-name num-regs props parent-cfg)
  (define banned intbits-empty)
  (define preserved intbits-empty)
  (define arg-regs '())
  (define return-regs '())

  (for ([p (in-list props)])
    (match p
      [(list 'banned val)
       (set! banned (integer->intbits val))]
      [(list 'preserved val)
       (set! preserved (integer->intbits val))]
      [(list 'args regs ...)
       (set! arg-regs regs)]
      [(list 'return regs ...)
       (set! return-regs regs)]
      [_ (void)]))

  ;; 如果有父配置且未指定，从父配置继承 arg-regs 和 return-regs
  (when parent-cfg
    (when (null? arg-regs)
      (set! arg-regs (reg-class-config-arg-regs parent-cfg)))
    (when (null? return-regs)
      (set! return-regs (reg-class-config-return-regs parent-cfg))))

  (make-reg-class-config
    #:num-regs num-regs
    #:banned banned
    #:preserved preserved
    #:arg-regs arg-regs
    #:return-regs return-regs))

;; 整数位域 -> intbits
(define (integer->intbits n)
  (for/fold ([bs intbits-empty])
            ([i (in-range 64)]  ; 最多 64 位
             #:when (bitwise-bit-set? n i))
    (intbits-set bs i)))

;; ============================================================
;; 查询
;; ============================================================

;; 按名称获取 ABI
(define (get-abi-by-name name)
  (define configs (load-abi-config))
  (hash-ref configs name #f))

;; 获取特殊寄存器映射表
(define (abi-get-special-regs abi)
  ;; special-regs 存储在 abi 的 extra 属性中
  ;; 由于 abi-config 是 transparent struct，我们使用 hash 来存储
  ;; 这里返回默认的特殊寄存器映射
  (hash 'sp 31 'fp 29 'lr 30 'platform 18))

;; 获取单个特殊寄存器编号
(define (abi-get-special-reg abi name [default #f])
  (define special-regs (abi-get-special-regs abi))
  (hash-ref special-regs name default))

;; ============================================================
;; 验证
;; ============================================================

;; 解析函数 ABI 声明；未声明时返回内建 arm64-abi。
;; fn-attrs: hash 函数属性
;; 返回: (values abi-config error-message)
(define (validate-function-abi fn-name fn-attrs)
  (define abi-name
    (cond
      [(and (hash? fn-attrs) (hash-ref fn-attrs 'abi #f))]
      [(default-abi-name)]
      [else #f]))

  (cond
    [(not abi-name)
     (values arm64-abi #f)]
    [else
     (define abi (get-abi-by-name abi-name))
     (if abi
         (values abi #f)
         (values #f (format "函数 ~a 指定的 ABI '~a' 未定义" fn-name abi-name)))]))

;; ============================================================
;; 测试
;; ============================================================

(module+ test
  (displayln "=== ABI 配置测试 ===\n")

  (define configs (load-abi-config))
  (printf "已加载 ~a 个 ABI 配置\n" (hash-count configs))

  (for ([(name cfg) (in-hash configs)])
    (printf "\n~a:\n" name)
    (printf "  GPR 可分配: ~a\n" (reg-num-allocatable (abi-config-gpr cfg)))
    (printf "  FPR 可分配: ~a\n" (reg-num-allocatable (abi-config-fpr cfg)))
    (printf "  Pred 可分配: ~a\n" (reg-num-allocatable (abi-config-pred cfg)))))
