#lang racket

;; 操作级列表调度器单元测试 (docs/operation-scheduler-spec.md §5.1)

(require rackunit
         "../pipeline/schedule.rkt"
         "../pipeline/regalloc/types.rkt"
         "../parser/ast.rkt")

(define (vreg name) (reg-id 'gpr 64 name #t))
(define (mk idx uses defs [lat 1] [mem 'none]) (sched-node idx #f uses defs lat mem))

;; ------------------------------------------------------------
;; U1: DAG RAW/WAR/WAW 边
;; ------------------------------------------------------------
(define a (vreg 'a)) (define b (vreg 'b)) (define c (vreg 'c))
(let ()
  ;; 0: def a ; 1: use a def b (RAW 0->1) ; 2: def a (WAW 0->2, WAR 1->2)
  (define nodes (vector (mk 0 '() (list a))
                        (mk 1 (list a) (list b))
                        (mk 2 '() (list a))))
  (define-values (succs preds) (build-region-dag nodes))
  (check-true (and (member 1 (vector-ref succs 0)) #t) "RAW 0->1")
  (check-true (and (member 2 (vector-ref succs 0)) #t) "WAW 0->2")
  (check-true (and (member 2 (vector-ref succs 1)) #t) "WAR 1->2"))

;; ------------------------------------------------------------
;; U2: NZCV 进位链保持连续有序
;; ------------------------------------------------------------
(define (ins mnem . regs)
  ;; 构造一个 ast-ins；第一个 reg 为 def，其余为 use (供 extract-use-def)
  (ast-ins mnem #f
           (map (lambda (r) (ast-reg 'x (reg-id-id r) #f #f #f #f no-srcloc)) regs)
           no-srcloc))
(let ()
  (define r0 (vreg 'r0)) (define r1 (vreg 'r1)) (define x (vreg 'x)) (define y (vreg 'y))
  ;; adds r0,x,y ; <indep mov z,w> ; adcs r1,x,y  -> 进位链 adds->adcs 必须保持序
  ;; 用 sched-node 直接建模 NZCV：adds def NZCV，adcs use+def NZCV
  (define NZ (reg-id 'nzcv 0 'nzcv #f))
  (define z (vreg 'z)) (define w (vreg 'w))
  (define nodes (vector (mk 0 (list x y) (list r0 NZ))       ; adds
                        (mk 1 (list w) (list z))              ; indep mov
                        (mk 2 (list x y NZ) (list r1 NZ))))   ; adcs (reads NZCV)
  (define order (list-schedule-region nodes))
  (check-true (< (index-of order 0) (index-of order 2)) "adds before adcs (NZCV RAW)"))

;; ------------------------------------------------------------
;; U4: 排列不变 (输出是输入的排列)
;; ------------------------------------------------------------
(let ()
  (define nodes (for/vector ([i (in-range 8)])
                  (mk i (if (> i 0) (list (vreg (string->symbol (format "v~a" (sub1 i))))) '())
                      (list (vreg (string->symbol (format "v~a" i)))))))
  (define order (list-schedule-region nodes))
  (check-equal? (sort order <) (build-list 8 values) "输出是 0..7 的排列"))

;; ------------------------------------------------------------
;; U6: 确定性 (同输入同输出)
;; ------------------------------------------------------------
(let ()
  (define (mknodes)
    (vector (mk 0 '() (list a)) (mk 1 '() (list b)) (mk 2 (list a b) (list c))))
  (check-equal? (list-schedule-region (mknodes)) (list-schedule-region (mknodes)) "确定性"))

;; ------------------------------------------------------------
;; U7: 纯依赖链 → 恒等 (无重排空间)
;; ------------------------------------------------------------
(let ()
  (define v0 (vreg 'v0)) (define v1 (vreg 'v1)) (define v2 (vreg 'v2)) (define v3 (vreg 'v3))
  (define nodes (vector (mk 0 (list v0) (list v1))
                        (mk 1 (list v1) (list v2))
                        (mk 2 (list v2) (list v3))))
  (check-equal? (list-schedule-region nodes) '(0 1 2) "纯链恒等"))

;; ------------------------------------------------------------
;; F2/ILP: 独立长延迟节点被提前 (关键路径优先)
;; ------------------------------------------------------------
(let ()
  ;; 0: 高延迟(12) 无依赖 ; 1: 低延迟依赖0的输出 ; 2: 高延迟(12) 无依赖(独立)
  ;; 关键路径优先应把两个高延迟节点(0,2)排在前面
  (define m0 (vreg 'm0)) (define m2 (vreg 'm2)) (define d1 (vreg 'd1))
  (define nodes (vector (sched-node 0 #f '() (list m0) 12 'none)
                        (sched-node 1 #f (list m0) (list d1) 1 'none)
                        (sched-node 2 #f '() (list m2) 12 'none)))
  (define order (list-schedule-region nodes))
  ;; 节点2(独立高延迟)应在节点1(低延迟)之前被调度
  (check-true (< (index-of order 2) (index-of order 1)) "独立高延迟节点提前 (ILP)"))

;; ------------------------------------------------------------
;; P1: NEON/crypto 代价模型 (延迟 + 端口)
;; ------------------------------------------------------------
(let ()
  (define (i0 mnem) (ast-ins mnem #f '() no-srcloc))
  (check-equal? (stmt-latency (i0 'aese)) 2 "aese 延迟=2")
  (check-equal? (stmt-latency (i0 'pmull)) 3 "pmull 延迟=3")
  (check-equal? (stmt-latency (i0 'eor)) 1 "eor 延迟=1")
  (check-equal? (stmt-port (i0 'aese)) 'crypto "aese -> crypto 端口")
  (check-equal? (stmt-port (i0 'aesmc)) 'crypto "aesmc -> crypto 端口")
  (check-equal? (stmt-port (i0 'pmull)) 'crypto "pmull -> crypto 端口 (与 AES 共享)")
  (check-equal? (stmt-port (i0 'eor)) 'simd "eor -> simd 端口")
  (check-equal? (stmt-port (i0 'ld1)) 'ld "ld1 -> load 端口")
  (check-equal? (port-capacity 'crypto) 1 "crypto 端口容量=1 (实测 AES/PMULL 共享单管线)")
  (check-true (> (port-capacity 'simd) 1) "simd 端口更宽"))

;; ------------------------------------------------------------
;; P2: 端口感知调度 —— crypto 端口(容量1)串行化独立 AES,期间独立 simd 填空
;; ------------------------------------------------------------
(let ()
  (define (pn idx mnem defs lat) (sched-node idx (ast-ins mnem #f '() no-srcloc) '() defs lat 'none))
  ;; 三个独立 aese (crypto) + 一个独立 eor (simd),彼此无依赖
  (define nodes (vector (pn 0 'aese (list (vreg 'q0)) 2)
                        (pn 1 'aese (list (vreg 'q1)) 2)
                        (pn 2 'aese (list (vreg 'q2)) 2)
                        (pn 3 'eor  (list (vreg 'q3)) 1)))
  ;; 端口开 (默认): crypto 每周期只发 1 个 aese, simd 在第 0 周期即可填入 -> eor(3)
  ;; 先于第三个 aese(2) 被排出。
  (define order-on (parameterize () (list-schedule-region nodes)))
  (check-true (< (index-of order-on 3) (index-of order-on 2))
              "端口开: simd 填 crypto 端口空档 (eor 先于第三个 aese)")
  ;; 端口关: 无端口约束,三个 aese 按关键路径(延迟2 > eor 1)聚在前 -> eor 最后。
  (putenv "ASMP_SCHED_PORTS" "0")
  (define order-off (list-schedule-region nodes))
  (putenv "ASMP_SCHED_PORTS" "")
  (check-true (> (index-of order-off 3) (index-of order-off 2))
              "端口关: 无约束,eor 排在 aese 之后 (端口模型确有作用)"))

(displayln "schedule-test: all checks done")
