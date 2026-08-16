#lang racket

;; ============================================================
;; pipeline/regalloc/types.rkt - 寄存器分配类型定义
;; ============================================================
;;
;; 统一的寄存器标识类型，用于整个寄存器分配流程

(require "../../semantic/use-def.rkt"
         racket/omap)

(provide
  ;; 数据结构
  (struct-out reg-id)
  (struct-out reg-group)

  ;; 比较器
  reg-id-compare
  reg-group-compare
  reg<?

  ;; reg-id 键单态化有序映射 (racket/omap 实例, 替代 vendor ordered-map)
  reg-om-empty
  reg-om-empty?
  reg-om?
  reg-om-count
  reg-om-set
  reg-om-ref
  reg-om-has-key?
  reg-om-delete
  reg-om-min
  reg-om->pairs
  in-reg-om

  ;; 转换
  reg-ref->reg-id

  ;; 查询
  reg-id-virtual?
  reg-id-physical?
  reg-id-gpr?
  reg-id-fpr?
  canonical-width

  ;; 寄存器组
  make-reg-group
  reg-group-member-at
  reg-group-has-virtual?

  ;; 构造辅助
  make-gpr
  make-fpr
  make-virtual-gpr
  make-virtual-fpr)

;; ============================================================
;; 数据结构
;; ============================================================

;; 统一寄存器标识
;; class: 'gpr | 'fpr | 'predicate
;; id: number (物理) | symbol (虚拟)
;; virtual?: boolean
;;
;; 注意: 同一物理寄存器的不同视图 (如 d0, s0, v0.4s) 归一化为同一个 reg-id
;; width 字段保留但不参与身份比较，仅用于调试/格式化
(struct reg-id (class width id virtual?) #:transparent)

;; 寄存器组 - 必须连续分配的寄存器序列
;; id: symbol - 组的唯一标识
;; members: (listof reg-id) - 成员寄存器（按顺序）
;; class: 'gpr | 'fpr - 寄存器类
;; alignment: integer - 对齐要求（1=无要求，2=偶数起始，4=4对齐...）
(struct reg-group (id members class alignment) #:transparent)

;; 每类寄存器的规范 width（用于归一化）
(define (canonical-width class)
  (case class
    [(gpr) 64]
    [(fpr) 128]
    [(predicate) 16]
    [else 64]))

;; ============================================================
;; 比较器
;; ============================================================

;; 本地三态比较基元 (原 vendor comparator 语义)
(define (integer-compare a b)
  (cond [(< a b) '<]
        [(= a b) '=]
        [else '>]))

(define (symbol-compare a b)
  (let ([sa (symbol->string a)] [sb (symbol->string b)])
    (cond [(string<? sa sb) '<]
          [(string=? sa sb) '=]
          [else '>])))

(define (reg-class->int c)
  (case c
    [(gpr) 0]
    [(fpr) 1]
    [(predicate) 2]
    [else 3]))

;; 比较时忽略 width，只比较 class + virtual? + id
(define (reg-id-compare a b)
  (define (class->int c) (reg-class->int c))

  (define class-cmp (integer-compare (class->int (reg-id-class a))
                                      (class->int (reg-id-class b))))
  (if (not (eq? class-cmp '=))
      class-cmp
      (let ([virt-cmp (integer-compare (if (reg-id-virtual? a) 1 0)
                                        (if (reg-id-virtual? b) 1 0))])
        (if (not (eq? virt-cmp '=))
            virt-cmp
            (cond
              [(and (number? (reg-id-id a)) (number? (reg-id-id b)))
               (integer-compare (reg-id-id a) (reg-id-id b))]
              [(and (symbol? (reg-id-id a)) (symbol? (reg-id-id b)))
               (symbol-compare (reg-id-id a) (reg-id-id b))]
              [(number? (reg-id-id a)) '<]
              [else '>])))))

;; 寄存器组比较器
(define (reg-group-compare a b)
  (symbol-compare (reg-group-id a) (reg-group-id b)))

;; reg-id 严格小于谓词 — 语义与 reg-id-compare 的 '< 分支逐位一致
;; (class→int 字典序, 再 virtual? (物理<虚拟), 再 id: 数值/符号名,
;;  数值 id < 符号 id)
(define (reg<? a b)
  (define ca (reg-class->int (reg-id-class a)))
  (define cb (reg-class->int (reg-id-class b)))
  (cond
    [(< ca cb) #t]
    [(> ca cb) #f]
    [else
     (define va (if (reg-id-virtual? a) 1 0))
     (define vb (if (reg-id-virtual? b) 1 0))
     (cond
       [(< va vb) #t]
       [(> va vb) #f]
       [else
        (define ia (reg-id-id a))
        (define ib (reg-id-id b))
        (cond
          [(and (number? ia) (number? ib)) (< ia ib)]
          [(and (symbol? ia) (symbol? ib))
           (string<? (symbol->string ia) (symbol->string ib))]
          [(number? ia) #t]
          [else #f])])]))

;; reg-id 键宏单态化有序映射实例
(define-omap reg-om #:key-compare reg-id-compare)

;; ============================================================
;; 寄存器组辅助函数
;; ============================================================

;; 创建寄存器组
;; 自动生成组 ID，推断 class
(define group-counter 0)

(define (make-reg-group members #:alignment [alignment 1])
  (when (null? members)
    (error 'make-reg-group "寄存器组不能为空"))
  (set! group-counter (add1 group-counter))
  (define id (string->symbol (format "group~a" group-counter)))
  (define class (reg-id-class (car members)))
  ;; 验证所有成员是同一 class
  (for ([m (in-list members)])
    (unless (eq? (reg-id-class m) class)
      (error 'make-reg-group "寄存器组成员必须是同一类: ~a vs ~a" class (reg-id-class m))))
  (reg-group id members class alignment))

;; 获取组中第 i 个成员
(define (reg-group-member-at group i)
  (list-ref (reg-group-members group) i))

;; 组中是否有虚拟寄存器
(define (reg-group-has-virtual? group)
  (for/or ([m (in-list (reg-group-members group))])
    (reg-id-virtual? m)))

;; ============================================================
;; 从 use-def 的 reg-ref 转换
;; ============================================================

;; 将 reg-ref 转换为归一化的 reg-id
;; 同一物理寄存器的不同视图 (x0/w0, v0/d0/s0/h0/b0) 得到相同的 reg-id
(define (reg-ref->reg-id ref)
  (define kind (reg-ref-kind ref))
  (define id (reg-ref-id ref))

  (define class
    (case kind
      [(x w) 'gpr]
      [(z v d s h b q) 'fpr]
      [(p) 'predicate]
      [else 'gpr]))

  ;; sp 和 zr 是特殊符号，不是虚拟寄存器
  (define virtual? (and (symbol? id)
                        (not (memq id '(sp zr)))))

  (define actual-id
    (cond
      [(eq? id 'sp) 31]
      [(eq? id 'zr) 31]
      [else id]))

  ;; 使用规范 width，忽略实际视图的 width
  (reg-id class (canonical-width class) actual-id virtual?))

;; ============================================================
;; 查询函数
;; ============================================================

(define (reg-id-physical? r)
  (not (reg-id-virtual? r)))

(define (reg-id-gpr? r)
  (eq? (reg-id-class r) 'gpr))

(define (reg-id-fpr? r)
  (eq? (reg-id-class r) 'fpr))

;; ============================================================
;; 构造辅助函数
;; ============================================================

(define (make-gpr id)
  (reg-id 'gpr (canonical-width 'gpr) id #f))

(define (make-fpr id)
  (reg-id 'fpr (canonical-width 'fpr) id #f))

(define (make-virtual-gpr name)
  (reg-id 'gpr (canonical-width 'gpr) name #t))

(define (make-virtual-fpr name)
  (reg-id 'fpr (canonical-width 'fpr) name #t))
