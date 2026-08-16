#lang racket

;; ============================================================
;; pipeline/regalloc/loop-analysis.rkt - 循环深度分析
;; ============================================================
;;
;; 在 CFG 上检测循环（回边）并计算每个 basic block 的循环嵌套深度。
;; 用于溢出代价计算：热循环中的变量代价高，优先保留在寄存器中。
;;
;; 算法：
;;   1. DFS 计算支配树（简化：用 DFS 序 + 回边检测）
;;   2. 检测回边（u→v 且 v 支配 u）
;;   3. 每个 basic block 标记循环嵌套深度

(require "../../semantic/control-flow.rkt")

(provide
  ;; 主函数
  compute-loop-depths      ; asm-function -> hash[bb-id-val -> integer]

  ;; 查询
  get-loop-depth)          ; hash bb-id-val -> integer

;; ============================================================
;; 支配树（简化版 Cooper-Harvey-Kennedy 算法）
;; ============================================================

;; 计算支配树
;; fn : asm-function
;; → (values hash[bb-id-val -> bb-id-val]   ; idom: 直接支配者
;;           (listof bb-id-val))             ; rpo: 逆后序
(define (compute-dominators fn)
  (define entry (asm-function-entry fn))
  (unless entry
    (values (make-hash) '()))

  (define entry-val (if (bb-id? entry) (bb-id-val entry) entry))

  ;; 1. DFS 计算逆后序
  (define visited (mutable-set))
  (define rpo-rev '())

  (let dfs ([bbid-val entry-val])
    (unless (set-member? visited bbid-val)
      (set-add! visited bbid-val)
      (for ([succ (in-list (fn-successors fn bbid-val))])
        (when succ
          (define succ-val (if (bb-id? succ) (bb-id-val succ) succ))
          (dfs succ-val)))
      (set! rpo-rev (cons bbid-val rpo-rev))))

  (define rpo rpo-rev)  ; 已经是逆后序（DFS 后序的反转）

  ;; 2. 建立 RPO 编号
  (define rpo-num (make-hash))
  (for ([b (in-list rpo)]
        [i (in-naturals)])
    (hash-set! rpo-num b i))

  ;; 3. Cooper-Harvey-Kennedy 不动点迭代计算 idom
  (define idom (make-hash))
  (hash-set! idom entry-val entry-val)

  (define (intersect b1 b2)
    (let loop ([f1 b1] [f2 b2])
      (cond
        [(equal? f1 f2) f1]
        [(> (hash-ref rpo-num f1 +inf.0) (hash-ref rpo-num f2 +inf.0))
         (loop (hash-ref idom f1 f1) f2)]
        [else
         (loop f1 (hash-ref idom f2 f2))])))

  (let iterate ()
    (define changed? #f)
    (for ([b (in-list rpo)]
          #:unless (equal? b entry-val))
      (define preds
        (for/list ([p (in-list (fn-predecessors fn b))]
                   #:when p)
          (if (bb-id? p) (bb-id-val p) p)))

      ;; 找到第一个已处理的前驱
      (define processed-preds
        (filter (lambda (p) (hash-has-key? idom p)) preds))

      (when (pair? processed-preds)
        (define new-idom
          (for/fold ([d (car processed-preds)])
                    ([p (in-list (cdr processed-preds))])
            (intersect d p)))

        (unless (equal? (hash-ref idom b #f) new-idom)
          (hash-set! idom b new-idom)
          (set! changed? #t))))

    (when changed? (iterate)))

  (values idom rpo))

;; ============================================================
;; 循环检测与深度计算
;; ============================================================

;; 检测 v 是否支配 u
(define (dominates? idom v u)
  (let loop ([current u] [steps 0])
    (cond
      [(equal? current v) #t]
      [(> steps 10000) #f]  ; 防止无限循环
      [(not (hash-has-key? idom current)) #f]
      [(equal? current (hash-ref idom current)) #f]  ; 到达入口
      [else (loop (hash-ref idom current) (add1 steps))])))

;; 计算每个 basic block 的循环嵌套深度
;; fn : asm-function
;; → hash[bb-id-val -> integer]  (0 = 不在循环中)
(define (compute-loop-depths fn)
  (define entry (asm-function-entry fn))
  (unless entry
    (make-hash))

  (define-values (idom rpo) (compute-dominators fn))

  ;; 检测回边：u→v 且 v 支配 u
  ;; 每条回边定义一个自然循环
  (define back-edges '())
  (for ([b (in-list rpo)])
    (for ([succ (in-list (fn-successors fn b))])
      (when succ
        (define succ-val (if (bb-id? succ) (bb-id-val succ) succ))
        (when (dominates? idom succ-val b)
          (set! back-edges (cons (cons b succ-val) back-edges))))))

  ;; 对每条回边，找到自然循环体（从尾节点回溯到头节点的所有节点）
  ;; 然后增加这些节点的深度
  (define depths (make-hash))
  (for ([b (in-list rpo)])
    (hash-set! depths b 0))

  (for ([edge (in-list back-edges)])
    (define tail (car edge))
    (define head (cdr edge))

    ;; 自然循环体：从 tail 反向 BFS/DFS 到 head
    (define loop-body (mutable-set head))
    (define worklist (if (equal? tail head) '() (list tail)))
    (set-add! loop-body tail)

    (let process ()
      (unless (null? worklist)
        (define node (car worklist))
        (set! worklist (cdr worklist))
        (for ([pred (in-list (fn-predecessors fn node))])
          (when pred
            (define pred-val (if (bb-id? pred) (bb-id-val pred) pred))
            (unless (set-member? loop-body pred-val)
              (set-add! loop-body pred-val)
              (set! worklist (cons pred-val worklist)))))
        (process)))

    ;; 增加循环体中所有节点的深度
    (for ([b (in-set loop-body)])
      (hash-set! depths b (add1 (hash-ref depths b 0)))))

  depths)

;; 查询基本块的循环深度
(define (get-loop-depth depths bb-id-val)
  (hash-ref depths bb-id-val 0))
