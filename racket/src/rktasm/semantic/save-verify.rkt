#lang racket

;; ============================================================
;; semantic/save-verify.rkt - save!/load! 控制流验证
;; ============================================================
;;
;; 采用边界配对语义:
;; 1. 仅检查函数内首个 save!/load! 指令是否为 save!
;; 2. 仅检查函数内末个 save!/load! 指令是否为 load!
;; 3. 中间出现的 save!/load! 不要求逐点配对
;;
;; 说明:
;; - 这是面向 DSL 的宽松验证策略，不做严格的控制流深度分析
;; - 详细的栈正确性由后续代码生成与运行时行为共同保障

(require "control-flow.rkt"
         "../parser/ast.rkt"
         racket/pvector
)

(provide
  ;; 验证
  verify-save-load

  ;; 结果
  (struct-out save-load-info)
  (struct-out save-point)
  (struct-out load-point)

  ;; 查询
  get-save-points
  get-load-points
  get-pairing
  save-load-errors)

;; ============================================================
;; 数据结构
;; ============================================================

;; 保存点
(struct save-point
  (id              ; symbol - 唯一标识
   registers       ; (listof ast-reg) - 要保存的寄存器
   size-spec       ; (list 'exact N) | (list 'at-most N) | (list 'unlimited)
   bb-id           ; bb-id - 所在基本块
   ins-index       ; integer - 块内指令索引
   loc)            ; srcloc
  #:transparent)

;; 加载点
(struct load-point
  (id              ; symbol - 唯一标识
   registers       ; (listof ast-reg) - 要恢复的寄存器
   size-spec       ; size-spec
   bb-id           ; bb-id
   ins-index       ; integer
   loc)            ; srcloc
  #:transparent)

;; 分析结果
(struct save-load-info
  (save-points     ; (listof save-point)
   load-points     ; (listof load-point)
   pairings        ; hasheq[save-id -> (listof load-point)]
   depth-at-exit   ; hasheq[reg-key -> integer] - 出口深度
   errors)         ; (listof string)
  #:transparent)

;; ============================================================
;; 主验证函数
;; ============================================================

(define (verify-save-load fn)
  ;; 空函数 (无入口块) 直接返回空结果
  (define entry (asm-function-entry fn))
  (if (not entry)
      (save-load-info '() '()
                      (hasheq)
                      (hasheq)
                      '())
      (verify-save-load-impl fn)))

(define (verify-save-load-impl fn)
  ;; 1. 收集所有 save!/load! 点
  (define-values (saves loads) (collect-save-load-points fn))

  ;; 2. 边界配对检查（首个是 save!，末个是 load!）
  (define boundary-errors (verify-boundary-pairing saves loads))
  ;; 3. 全局寄存器集合合法性（非逐点配对）
  (define regset-errors (verify-load-regs-covered-by-saves saves loads))
  (define errors (append boundary-errors regset-errors))

  ;; pairings/depth-at-exit 在边界模式下不使用，保留空结构以维持 API 兼容
  (save-load-info saves loads (hasheq)
                  (hasheq)
                  errors))

;; ============================================================
;; 边界配对验证
;; ============================================================

;; 事件编码:
;;   (list kind bb-val ins-index loc)
;;   kind: 'save! | 'load!
(define (save-point->event sp)
  (list 'save!
        (bb-id-val (save-point-bb-id sp))
        (save-point-ins-index sp)
        (save-point-loc sp)))

(define (load-point->event lp)
  (list 'load!
        (bb-id-val (load-point-bb-id lp))
        (load-point-ins-index lp)
        (load-point-loc lp)))

(define (event<? a b)
  (define abb (list-ref a 1))
  (define aidx (list-ref a 2))
  (define bbb (list-ref b 1))
  (define bidx (list-ref b 2))
  (or (< abb bbb)
      (and (= abb bbb) (< aidx bidx))))

(define (format-loc loc)
  (match loc
    [(srcloc src line col _ _)
     (define src-str
       (cond
         [(path? src) (path->string src)]
         [(symbol? src) (symbol->string src)]
         [(string? src) src]
         [else "unknown"]))
     (if (and line col)
         (format "~a:~a:~a" src-str line col)
         src-str)]
    [_ "unknown"]))

(define (verify-boundary-pairing saves loads)
  (cond
    [(and (null? saves) (null? loads))
     '()]
    [(and (pair? saves) (null? loads))
     (list (format "函数包含 save! 但缺少结尾 load!（共 ~a 个 save!）"
                   (length saves)))]
    [(and (null? saves) (pair? loads))
     (list (format "函数包含 load! 但缺少开头 save!（共 ~a 个 load!）"
                   (length loads)))]
    [else
     (define events
       (sort (append (map save-point->event saves)
                     (map load-point->event loads))
             event<?))
     (define first-event (car events))
     (define last-event (car (reverse events)))
     (define errors '())
     (unless (eq? (car first-event) 'save!)
       (set! errors
             (cons (format "~a: 首个 save!/load! 指令应为 save!，实际为 load!"
                           (format-loc (list-ref first-event 3)))
                   errors)))
     (unless (eq? (car last-event) 'load!)
       (set! errors
             (cons (format "~a: 末个 save!/load! 指令应为 load!，实际为 save!"
                           (format-loc (list-ref last-event 3)))
                   errors)))
     (reverse errors)]))

;; ============================================================
;; 全局寄存器集合合法性（非逐点配对）
;; ============================================================

(define (reg-node-key reg)
  (cons (ast-reg-kind reg) (ast-reg-id reg)))

(define (verify-load-regs-covered-by-saves saves loads)
  (cond
    [(or (null? saves) (null? loads)) '()]
    [else
     (define save-all?
       (for/or ([sp (in-list saves)])
         (eq? (save-point-registers sp) 'all)))

     (define save-regs
       (for/fold ([h (hash)])
                 ([sp (in-list saves)]
                  #:when (not (eq? (save-point-registers sp) 'all)))
         (for/fold ([acc h])
                   ([r (in-list (save-point-registers sp))]
                    #:when (ast-reg? r))
           (hash-set acc (reg-node-key r) #t))))

     (if save-all?
         '()
         (for/fold ([errs '()])
                   ([lp (in-list loads)])
           (define regs (load-point-registers lp))
           (cond
             [(eq? regs 'all)
              (cons (format "~a: 使用 load! all 但函数中没有 save! all"
                            (format-loc (load-point-loc lp)))
                    errs)]
             [else
              (for/fold ([acc errs])
                        ([r (in-list regs)]
                         #:when (and (ast-reg? r)
                                     (not (hash-ref save-regs (reg-node-key r) #f))))
                (cons (format "~a: load! 寄存器 ~a 未出现在任何 save! 中"
                              (format-loc (load-point-loc lp))
                              (ast->string r))
                      acc))])))]))

;; ============================================================
;; 收集 save!/load! 点
;; ============================================================

(define save-counter 0)
(define load-counter 0)

(define (collect-save-load-points fn)
  (define saves '())
  (define loads '())

  (fn-for-each-block fn
    (lambda (block)
      (define bb-id (basic-block-id block))
      (for ([ins (in-pvector (basic-block-instructions block))]
            [i (in-naturals)])
        (when (ast-directive? ins)
          (case (ast-directive-kind ins)
            [(save!)
             (set! save-counter (add1 save-counter))
             (define args (ast-directive-args ins))
             (define sp (save-point
                         (string->symbol (format "save~a" save-counter))
                         (first args)   ; registers
                         (second args)  ; size-spec
                         bb-id
                         i
                         (ast-directive-loc ins)))
             (set! saves (cons sp saves))]
            [(load!)
             (set! load-counter (add1 load-counter))
             (define args (ast-directive-args ins))
             (define lp (load-point
                         (string->symbol (format "load~a" load-counter))
                         (first args)
                         (second args)
                         bb-id
                         i
                         (ast-directive-loc ins)))
             (set! loads (cons lp loads))])))))

  (values (reverse saves) (reverse loads)))

;; ============================================================
;; 查询函数
;; ============================================================

(define (get-save-points info)
  (save-load-info-save-points info))

(define (get-load-points info)
  (save-load-info-load-points info))

(define (get-pairing info save-id)
  (hash-ref (save-load-info-pairings info) save-id '()))

(define (save-load-errors info)
  (save-load-info-errors info))
