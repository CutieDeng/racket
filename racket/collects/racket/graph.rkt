#lang racket/base

;; ============================================================
;; racket/graph — 持久化 MultiGraph + 图算法
;; ============================================================
;;
;; 原 rktasm vendor cutie-ftree graph（graph.rkt + graph/unsafe.rkt +
;; graph-scc.rkt / graph-algorithms.rkt 及其 graph/{scc,traversal,
;; reachability}.rkt 实现体），2026-08-06 合并吸收进 core，单模块。
;;
;; 内部数据结构改用 core 原生实现：
;;   - vendor pvector     → racket/pvector
;;   - vendor bitset      → racket/intbits (bitset-add→intbits-set 等)
;;   - vendor ordered-map → racket/intmap (整数键；迭代序同为键升序)
;;   - vendor comparator  → 本地三态整数比较 (vertex-id-compare/edge-id-compare)
;;
;; 语义说明（相对 vendor 版）：
;;   - 具体 (Graph 类型) API 全部保留，遍历序 bit-exact 一致：
;;     in-intbits 升序 = in-bitset 升序；私有降序迭代 = in-bitset/reverse；
;;     intmap 键升序 = ordered-map integer-compare 升序。
;;   - 参数化 (callbacks) API 保留签名；内部 visited/index 等以节点为键的
;;     映射从「comparator 键 ordered-map」改为 equal? 键不可变 hash——
;;     node-compare 参数仅保留占位不再参与判等；节点判等即 equal?。
;;     reachable-from-set 的返回值相应从 ordered-map 集合改为
;;     不可变 hash 集合 (键为节点, 值 #t)。
;;
;; 安全特性（与原 safe API 相同）：
;;   - vertex-id / edge-id 构造器不导出，只有图操作能造出合法 ID
;;   - 所有输入做类型与存在性校验
;; ============================================================

(require racket/match
         racket/dict
         racket/generic
         racket/generator
         racket/sequence
         racket/pvector
         racket/intbits
         racket/intmap)

;; ============================================================
;; gen:graph-view — 图算法的通用遍历接口 (方案 A: 一套算法, 多种表示)
;; ============================================================
;;
;; 下方 graph-* 算法 (SCC/DFS/BFS/拓扑/可达/路径) 只依赖三个 intbits 原语
;; (顶点集 / 后继 / 前驱, 顶点为稠密整数 id) + 输入节点→id 解包 + 能力位。
;; graph (有向多重标注) 与 ugraph (无向简单紧凑) 底层同为 "整数 id + intbits",
;; 各自 O(1) 提供这些原语 ⇒ 同一套算法对两种表示都保持 intbits 速度, 不退化。
;; 外部自定义图表示实现 gen:graph-view 即免费获得全部算法。
;;
;; 无向图上 SCC = 连通分量; 前驱≡后继 (转置恒等); 拓扑排序对含边无向图返回 #f
;; (有环), 均为正确语义。#:defaults 按 graph?/ugraph? 谓词挂实现 (免改结构定义;
;; 谓词与 -impl 均为模块级运行期前向引用)。

;; 接口只在此声明 (方法名在算法之前绑定); 实现挂在 graph / ugraph 的结构体
;; 定义处 (#:methods gen:graph-view)。
(define-generics graph-view
  (graph-view-vertex-bits graph-view)     ; -> intbits: 全部顶点 id
  (graph-view-succ-bits graph-view id)    ; -> intbits: id 的后继
  (graph-view-pred-bits graph-view id)    ; -> intbits: id 的前驱
  (graph-view-node->id graph-view node)   ; 输入节点 -> 整数 id
  (graph-view-directed? graph-view)
  (graph-view-multi? graph-view)
  (graph-view-edge-labeled? graph-view))

;; ugraph 全顶点位集 (id 0..nv-1)
(define (ugraph-vertex-bits g)
  (for/fold ([b intbits-empty]) ([i (in-range (ugraph-nv g))])
    (intbits-set b i)))

;; 任何图表示 (graph / ugraph / 外部实现 gen:graph-view)
(define (graph-object? x)
  (or (graph? x) (ugraph? x) (graph-view? x)))

;; 能力位公开别名
(define (graph-directed? g) (graph-view-directed? g))
(define (graph-multi? g) (graph-view-multi? g))
(define (graph-edge-labeled? g) (graph-view-edge-labeled? g))

(provide gen:graph-view graph-view?
         graph-view-vertex-bits graph-view-succ-bits graph-view-pred-bits
         graph-view-node->id
         graph-view-directed? graph-view-multi? graph-view-edge-labeled?
         graph-object?
         graph-directed? graph-multi? graph-edge-labeled?)

;; ========================================
;; 内部工具：intbits 迭代 / 收集
;; ========================================

;; 升序迭代 = vendor in-bitset
;; racket/intbits 的 in-intbits 即升序，直接使用。

;; 降序迭代 = vendor in-bitset/reverse
(define (in-intbits/descending bs)
  (make-do-sequence
   (lambda ()
     (initiate-sequence
      #:init-pos bs
      #:pos->element intbits-last
      #:continue-with-pos? (lambda (s) (not (intbits-empty? s)))
      #:next-pos (lambda (s) (intbits-clear s (intbits-last s)))))))

;; 反转 pvector（利用高效反向迭代）
(define (pvector-reverse pv)
  (for/pvector ([x (in-pvector-reverse pv)])
    x))

;; ========================================
;; ID 类型（构造器不导出）
;; ========================================

(struct vertex-id (val) #:transparent)
(struct edge-id (val) #:transparent)

(define (vertex-id-compare a b)
  (let ([av (vertex-id-val a)] [bv (vertex-id-val b)])
    (cond [(< av bv) '<] [(= av bv) '=] [else '>])))

(define (edge-id-compare a b)
  (let ([av (edge-id-val a)] [bv (edge-id-val b)])
    (cond [(< av bv) '<] [(= av bv) '=] [else '>])))

;; ============================================================
;; 底层实现（原 graph/unsafe.rkt — 裸整数 ID，无输入校验）
;; ============================================================

(struct graph
  (
    ;; ID 分配
    next-vertex-id    ; integer: 下一个新顶点 ID
    next-edge-id      ; integer: 下一个新边 ID

    ;; 活跃集合
    vertices          ; intbits: 活跃顶点 ID 值
    edges             ; intbits: 活跃边 ID 值

    ;; 计数缓存
    vertex-count*     ; integer
    edge-count*       ; integer

    ;; 边 → 端点映射
    edge-src*         ; intmap: edge-val → vertex-val
    edge-dst*         ; intmap: edge-val → vertex-val

    ;; 边配对
    edge-pair*        ; intmap: edge-val → edge-val

    ;; 顶点邻接
    in-edges*         ; intmap: vertex-val → intbits
    out-edges*        ; intmap: vertex-val → intbits

    ;; 三层嵌套: adjacency[src][dst] = {edges...}
    adjacency         ; intmap: vertex-val → intmap → intbits
  )
  #:transparent
  #:methods gen:graph-view
  [(define (graph-view-vertex-bits g) (graph-vertices-set-impl g))
   (define (graph-view-succ-bits g id) (graph-successors-impl g id))
   (define (graph-view-pred-bits g id) (graph-predecessors-impl g id))
   (define (graph-view-node->id g node) (vertex-id-val node))
   (define (graph-view-directed? g) #t)
   (define (graph-view-multi? g) #t)
   (define (graph-view-edge-labeled? g) #t)])

(define graph-empty
  (graph
    0                  ; next-vertex-id
    0                  ; next-edge-id
    intbits-empty      ; vertices
    intbits-empty      ; edges
    0                  ; vertex-count*
    0                  ; edge-count*
    intmap-empty       ; edge-src*
    intmap-empty       ; edge-dst*
    intmap-empty       ; edge-pair*
    intmap-empty       ; in-edges*
    intmap-empty       ; out-edges*
    intmap-empty))

;; ---- ID 分配 ----

(define (alloc-vertex-id g)
  (match-define (graph next-v next-e verts edges
                       v-cnt e-cnt e-src e-dst e-pair
                       in-e out-e adj) g)
  (values (graph (add1 next-v) next-e
                 verts edges v-cnt e-cnt e-src e-dst e-pair
                 in-e out-e adj)
          next-v))

(define (alloc-edge-id g)
  (match-define (graph next-v next-e verts edges
                       v-cnt e-cnt e-src e-dst e-pair
                       in-e out-e adj) g)
  (values (graph next-v (add1 next-e)
                 verts edges v-cnt e-cnt e-src e-dst e-pair
                 in-e out-e adj)
          next-e))

;; ---- 顶点操作 (impl) ----

(define (graph-add-vertex-impl g)
  (define-values (g1 vid) (alloc-vertex-id g))
  (match-define (graph next-v next-e verts edges
                       v-cnt e-cnt e-src e-dst e-pair
                       in-e out-e adj) g1)
  (values
    (graph next-v next-e
           (intbits-set verts vid)
           edges
           (add1 v-cnt)
           e-cnt
           e-src e-dst e-pair
           (intmap-set in-e vid intbits-empty)
           (intmap-set out-e vid intbits-empty)
           (intmap-set adj vid intmap-empty))
    vid))

(define (graph-vertex?-impl g vid)
  (intbits-ref (graph-vertices g) vid))

(define (graph-vertices-set-impl g)
  (graph-vertices g))

(define (graph-vertex-count-impl g)
  (graph-vertex-count* g))

(define (graph-remove-vertex-impl g vid)
  (match-define (graph next-v next-e verts edges
                       v-cnt e-cnt e-src e-dst e-pair
                       in-e-map out-e-map adj) g)
  (graph next-v next-e
         (intbits-clear verts vid)
         edges
         (sub1 v-cnt)
         e-cnt
         e-src e-dst e-pair
         (intmap-remove in-e-map vid)
         (intmap-remove out-e-map vid)
         (intmap-remove adj vid)))

;; ---- 边操作 (impl) ----

(define (graph-add-edge-impl g src-v dst-v)
  (define-values (g1 eid) (alloc-edge-id g))
  (match-define (graph next-v next-e verts edges
                       v-cnt e-cnt e-src e-dst e-pair
                       in-e out-e adj) g1)

  ;; 端点
  (define new-e-src (intmap-set e-src eid src-v))
  (define new-e-dst (intmap-set e-dst eid dst-v))

  ;; in-edges / out-edges
  (define src-out (intmap-ref out-e src-v intbits-empty))
  (define dst-in (intmap-ref in-e dst-v intbits-empty))
  (define new-out-e (intmap-set out-e src-v (intbits-set src-out eid)))
  (define new-in-e (intmap-set in-e dst-v (intbits-set dst-in eid)))

  ;; 三层邻接
  (define src-adj (intmap-ref adj src-v intmap-empty))
  (define src-dst-edges (intmap-ref src-adj dst-v intbits-empty))
  (define new-src-adj (intmap-set src-adj dst-v (intbits-set src-dst-edges eid)))
  (define new-adj (intmap-set adj src-v new-src-adj))

  (values
    (graph next-v next-e
           verts
           (intbits-set edges eid)
           v-cnt
           (add1 e-cnt)
           new-e-src new-e-dst e-pair
           new-in-e new-out-e new-adj)
    eid))

(define (graph-add-edge-pair-impl g v1 v2)
  (define-values (g1 e1) (graph-add-edge-impl g v1 v2))
  (define-values (g2 e2) (graph-add-edge-impl g1 v2 v1))
  (match-define (graph next-v next-e verts edges
                       v-cnt e-cnt e-src e-dst e-pair
                       in-e out-e adj) g2)
  (define new-e-pair
    (intmap-set (intmap-set e-pair e1 e2) e2 e1))
  (values
    (graph next-v next-e verts edges
           v-cnt e-cnt e-src e-dst new-e-pair
           in-e out-e adj)
    e1 e2))

(define (graph-edge?-impl g eid)
  (intbits-ref (graph-edges g) eid))

(define (graph-edges-set-impl g)
  (graph-edges g))

(define (graph-edge-count-impl g)
  (graph-edge-count* g))

(define (graph-edge-src-impl g eid)
  (intmap-ref (graph-edge-src* g) eid #f))

(define (graph-edge-dst-impl g eid)
  (intmap-ref (graph-edge-dst* g) eid #f))

(define (graph-edge-endpoints-impl g eid)
  (values (graph-edge-src-impl g eid) (graph-edge-dst-impl g eid)))

(define (graph-edge-pair-impl g eid)
  (intmap-ref (graph-edge-pair* g) eid #f))

(define (graph-remove-edge-impl g eid)
  (define src-v (graph-edge-src-impl g eid))
  (define dst-v (graph-edge-dst-impl g eid))
  (define paired (graph-edge-pair-impl g eid))

  (match-define (graph next-v next-e verts edges
                       v-cnt e-cnt e-src e-dst e-pair
                       in-e out-e adj) g)

  (define new-e-src (intmap-remove e-src eid))
  (define new-e-dst (intmap-remove e-dst eid))

  (define new-e-pair
    (if paired
        (intmap-remove (intmap-remove e-pair eid) paired)
        (intmap-remove e-pair eid)))

  (define src-out (intmap-ref out-e src-v intbits-empty))
  (define new-out-e (intmap-set out-e src-v (intbits-clear src-out eid)))

  (define dst-in (intmap-ref in-e dst-v intbits-empty))
  (define new-in-e (intmap-set in-e dst-v (intbits-clear dst-in eid)))

  (define src-adj (intmap-ref adj src-v intmap-empty))
  (define src-dst-edges (intmap-ref src-adj dst-v intbits-empty))
  (define new-src-dst-edges (intbits-clear src-dst-edges eid))
  (define new-src-adj
    (if (intbits-empty? new-src-dst-edges)
        (intmap-remove src-adj dst-v)
        (intmap-set src-adj dst-v new-src-dst-edges)))
  (define new-adj (intmap-set adj src-v new-src-adj))

  (graph next-v next-e
         verts
         (intbits-clear edges eid)
         v-cnt
         (sub1 e-cnt)
         new-e-src new-e-dst new-e-pair
         new-in-e new-out-e new-adj))

(define (graph-remove-edge*-impl g eid)
  (define paired (graph-edge-pair-impl g eid))
  (define g1 (graph-remove-edge-impl g eid))
  (if (and paired (graph-edge?-impl g1 paired))
      (graph-remove-edge-impl g1 paired)
      g1))

;; ---- 邻接查询 (impl) ----

(define (graph-in-edges-impl g vid)
  (intmap-ref (graph-in-edges* g) vid intbits-empty))

(define (graph-out-edges-impl g vid)
  (intmap-ref (graph-out-edges* g) vid intbits-empty))

(define (graph-in-degree-impl g vid)
  (intbits-count (graph-in-edges-impl g vid)))

(define (graph-out-degree-impl g vid)
  (intbits-count (graph-out-edges-impl g vid)))

(define (graph-edges-between-impl g src-v dst-v)
  (define src-adj (intmap-ref (graph-adjacency g) src-v #f))
  (if src-adj
      (intmap-ref src-adj dst-v intbits-empty)
      intbits-empty))

(define (graph-has-edge-to?-impl g src-v dst-v)
  (not (intbits-empty? (graph-edges-between-impl g src-v dst-v))))

(define (graph-successors-impl g vid)
  (define v-adj (intmap-ref (graph-adjacency g) vid #f))
  (if v-adj
      (for/fold ([bs intbits-empty])
                ([kv (in-intmap-pairs v-adj)])
        (intbits-set bs (car kv)))
      intbits-empty))

(define (graph-predecessors-impl g vid)
  (define in-e (graph-in-edges-impl g vid))
  (for/fold ([bs intbits-empty])
            ([eid (in-intbits in-e)])
    (intbits-set bs (graph-edge-src-impl g eid))))

;; ============================================================
;; 安全 API（原 graph.rkt）
;; ============================================================

;; ---- 输入校验 ----

(define (check-vertex-id who g v pos)
  (unless (vertex-id? v)
    (raise-argument-error who "vertex-id?" pos v))
  (unless (graph-vertex?-impl g (vertex-id-val v))
    (error who "vertex does not exist in graph: ~a" v)))

(define (check-edge-id who g e pos)
  (unless (edge-id? e)
    (raise-argument-error who "edge-id?" pos e))
  (unless (graph-edge?-impl g (edge-id-val e))
    (error who "edge does not exist in graph: ~a" e)))

;; ---- 顶点操作 ----

(define (graph-add-vertex g)
  (define-values (g* vid) (graph-add-vertex-impl g))
  (values g* (vertex-id vid)))

(define (graph-vertex? g v)
  (if (vertex-id? v)
      (graph-vertex?-impl g (vertex-id-val v))
      #f))

(define (graph-vertices-set g)
  (for/pvector ([v (in-intbits (graph-vertices-set-impl g))])
    (vertex-id v)))

(define (graph-vertex-count g)
  (graph-vertex-count-impl g))

(define (graph-remove-vertex g v)
  (check-vertex-id 'graph-remove-vertex g v 1)
  (define vid (vertex-id-val v))
  (define in-e (graph-in-edges-impl g vid))
  (define out-e (graph-out-edges-impl g vid))
  (unless (intbits-empty? in-e)
    (error 'graph-remove-vertex "vertex has in-edges: ~a" v))
  (unless (intbits-empty? out-e)
    (error 'graph-remove-vertex "vertex has out-edges: ~a" v))
  (graph-remove-vertex-impl g vid))

(define (graph-remove-vertex* g v)
  (check-vertex-id 'graph-remove-vertex* g v 1)
  (define vid (vertex-id-val v))
  (define in-e (graph-in-edges-impl g vid))
  (define out-e (graph-out-edges-impl g vid))
  (define all-edges (intbits-union in-e out-e))
  (define g1
    (for/fold ([g g])
              ([eid (in-intbits all-edges)])
      (if (graph-edge?-impl g eid)
          (graph-remove-edge-impl g eid)
          g)))
  (graph-remove-vertex-impl g1 vid))

;; ---- 边操作 ----

(define (graph-add-edge g src dst)
  (check-vertex-id 'graph-add-edge g src 1)
  (check-vertex-id 'graph-add-edge g dst 2)
  (define-values (g* eid)
    (graph-add-edge-impl g (vertex-id-val src) (vertex-id-val dst)))
  (values g* (edge-id eid)))

(define (graph-add-edge-pair g v1 v2)
  (check-vertex-id 'graph-add-edge-pair g v1 1)
  (check-vertex-id 'graph-add-edge-pair g v2 2)
  (define-values (g* e1 e2)
    (graph-add-edge-pair-impl g (vertex-id-val v1) (vertex-id-val v2)))
  (values g* (edge-id e1) (edge-id e2)))

(define (graph-edge? g e)
  (if (edge-id? e)
      (graph-edge?-impl g (edge-id-val e))
      #f))

(define (graph-edges-set g)
  (for/pvector ([e (in-intbits (graph-edges-set-impl g))])
    (edge-id e)))

(define (graph-edge-count g)
  (graph-edge-count-impl g))

(define (graph-edge-src g e)
  (check-edge-id 'graph-edge-src g e 1)
  (vertex-id (graph-edge-src-impl g (edge-id-val e))))

(define (graph-edge-dst g e)
  (check-edge-id 'graph-edge-dst g e 1)
  (vertex-id (graph-edge-dst-impl g (edge-id-val e))))

(define (graph-edge-endpoints g e)
  (check-edge-id 'graph-edge-endpoints g e 1)
  (define-values (src dst) (graph-edge-endpoints-impl g (edge-id-val e)))
  (values (vertex-id src) (vertex-id dst)))

(define (graph-edge-pair g e)
  (check-edge-id 'graph-edge-pair g e 1)
  (define paired (graph-edge-pair-impl g (edge-id-val e)))
  (and paired (edge-id paired)))

(define (graph-remove-edge g e)
  (check-edge-id 'graph-remove-edge g e 1)
  (graph-remove-edge-impl g (edge-id-val e)))

(define (graph-remove-edge* g e)
  (check-edge-id 'graph-remove-edge* g e 1)
  (graph-remove-edge*-impl g (edge-id-val e)))

(define (graph-remove-edge-between g src dst)
  (check-vertex-id 'graph-remove-edge-between g src 1)
  (check-vertex-id 'graph-remove-edge-between g dst 2)
  (define edges
    (graph-edges-between-impl g (vertex-id-val src) (vertex-id-val dst)))
  (cond
    [(intbits-empty? edges)
     (error 'graph-remove-edge-between "no edge from ~a to ~a" src dst)]
    [(> (intbits-count edges) 1)
     (error 'graph-remove-edge-between
            "multiple edges from ~a to ~a, use graph-remove-edges-between" src dst)]
    [else
     (graph-remove-edge-impl g (intbits-first edges))]))

(define (graph-remove-edges-between g src dst)
  (check-vertex-id 'graph-remove-edges-between g src 1)
  (check-vertex-id 'graph-remove-edges-between g dst 2)
  (define edges
    (graph-edges-between-impl g (vertex-id-val src) (vertex-id-val dst)))
  (for/fold ([g g])
            ([eid (in-intbits edges)])
    (graph-remove-edge-impl g eid)))

;; ---- 邻接查询 ----

(define (graph-in-edges g v)
  (check-vertex-id 'graph-in-edges g v 1)
  (for/pvector ([e (in-intbits (graph-in-edges-impl g (vertex-id-val v)))])
    (edge-id e)))

(define (graph-out-edges g v)
  (check-vertex-id 'graph-out-edges g v 1)
  (for/pvector ([e (in-intbits (graph-out-edges-impl g (vertex-id-val v)))])
    (edge-id e)))

(define (graph-in-degree g v)
  (check-vertex-id 'graph-in-degree g v 1)
  (graph-in-degree-impl g (vertex-id-val v)))

(define (graph-out-degree g v)
  (check-vertex-id 'graph-out-degree g v 1)
  (graph-out-degree-impl g (vertex-id-val v)))

(define (graph-edges-between g src dst)
  (check-vertex-id 'graph-edges-between g src 1)
  (check-vertex-id 'graph-edges-between g dst 2)
  (for/pvector ([e (in-intbits (graph-edges-between-impl
                                g (vertex-id-val src) (vertex-id-val dst)))])
    (edge-id e)))

(define (graph-has-edge-to? g src dst)
  (check-vertex-id 'graph-has-edge-to? g src 1)
  (check-vertex-id 'graph-has-edge-to? g dst 2)
  (graph-has-edge-to?-impl g (vertex-id-val src) (vertex-id-val dst)))

(define (graph-successors g v)
  (check-vertex-id 'graph-successors g v 1)
  (for/pvector ([vid (in-intbits (graph-successors-impl g (vertex-id-val v)))])
    (vertex-id vid)))

(define (graph-predecessors g v)
  (check-vertex-id 'graph-predecessors g v 1)
  (for/pvector ([vid (in-intbits (graph-predecessors-impl g (vertex-id-val v)))])
    (vertex-id vid)))

;; ---- 迭代 ----

(define (in-graph-vertices g)
  (in-generator
    (for ([v (in-intbits (graph-vertices-set-impl g))])
      (yield (vertex-id v)))))

(define (in-graph-edges g)
  (in-generator
    (for ([e (in-intbits (graph-edges-set-impl g))])
      (yield (edge-id e)))))

(define (in-graph-out-edges g v)
  (check-vertex-id 'in-graph-out-edges g v 1)
  (define vid (vertex-id-val v))
  (in-generator
    (for ([eid (in-intbits (graph-out-edges-impl g vid))])
      (define-values (src dst) (graph-edge-endpoints-impl g eid))
      (yield (values (edge-id eid) (vertex-id src) (vertex-id dst))))))

(define (in-graph-successors g v)
  (check-vertex-id 'in-graph-successors g v 1)
  (in-generator
    (for ([vid (in-intbits (graph-successors-impl g (vertex-id-val v)))])
      (yield (vertex-id vid)))))

(define (in-graph-predecessors g v)
  (check-vertex-id 'in-graph-predecessors g v 1)
  (in-generator
    (for ([vid (in-intbits (graph-predecessors-impl g (vertex-id-val v)))])
      (yield (vertex-id vid)))))

;; ============================================================
;; SCC 算法（原 graph/scc.rkt）
;; ============================================================

;; graph-scc: Graph -> pvector[intbits]
;; Tarjan；返回逆拓扑序的 SCC（每个 SCC 是顶点值的 intbits 集合）。
(define (graph-scc g)
  (define vertices (graph-view-vertex-bits g))

  (define index-counter 0)
  (define index intmap-empty)     ; vertex-val -> int
  (define lowlink intmap-empty)   ; vertex-val -> int
  (define on-stack intbits-empty)
  (define stack (pvector-empty))
  (define sccs (pvector-empty))

  (define (strongconnect v)
    (set! index (intmap-set index v index-counter))
    (set! lowlink (intmap-set lowlink v index-counter))
    (set! index-counter (add1 index-counter))

    (set! stack (pvector-cons-right stack v))
    (set! on-stack (intbits-set on-stack v))

    (define succs (graph-view-succ-bits g v))
    (for ([w (in-intbits/descending succs)])
      (cond
        [(not (intmap-has-key? index w))
         (strongconnect w)
         (define new-low (min (intmap-ref lowlink v 0) (intmap-ref lowlink w 0)))
         (set! lowlink (intmap-set lowlink v new-low))]
        [(intbits-ref on-stack w)
         (define new-low (min (intmap-ref lowlink v 0) (intmap-ref index w 0)))
         (set! lowlink (intmap-set lowlink v new-low))]))

    (when (= (intmap-ref lowlink v 0) (intmap-ref index v 0))
      (define-values (scc new-stack)
        (let loop ([component intbits-empty] [stk stack])
          (define-values (top stk*) (pvector-pop-right stk))
          (set! on-stack (intbits-clear on-stack top))
          (define new-component (intbits-set component top))
          (if (= top v)
              (values new-component stk*)
              (loop new-component stk*))))
      (set! stack new-stack)
      (set! sccs (pvector-cons-right sccs scc))))

  (for ([v (in-intbits/descending vertices)])
    (unless (intmap-has-key? index v)
      (strongconnect v)))

  sccs)

;; graph-condensation: Graph -> (values node->scc scc-nodes scc-successors)
;;   node->scc     : intmap[vertex-val -> scc-idx]
;;   scc-nodes     : pvector[intbits]
;;   scc-successors: procedure (scc-idx -> intbits of scc-idx)
(define (graph-condensation g)
  (define sccs (graph-scc g))

  (define node->scc
    (for/fold ([m intmap-empty])
              ([scc (in-pvector sccs)]
               [id (in-naturals)])
      (for/fold ([m* m]) ([v (in-intbits/descending scc)])
        (intmap-set m* v id))))

  (define vertices (graph-view-vertex-bits g))
  (define scc-adj
    (for/fold ([adj intmap-empty])
              ([v (in-intbits/descending vertices)])
      (define src-scc (intmap-ref node->scc v 0))
      (define succs (graph-view-succ-bits g v))
      (for/fold ([adj* adj])
                ([w (in-intbits/descending succs)])
        (define dst-scc (intmap-ref node->scc w 0))
        (if (= src-scc dst-scc)
            adj*
            (let ([existing (intmap-ref adj* src-scc intbits-empty)])
              (intmap-set adj* src-scc (intbits-set existing dst-scc)))))))

  (define (scc-successors scc-id)
    (intmap-ref scc-adj scc-id intbits-empty))

  (values node->scc sccs scc-successors))

;; ---- 参数化 SCC（节点判等 = equal?；node-compare 仅保留占位）----

;; scc-tarjan: node-compare nodes get-successors -> pvector[pvector]
(define (scc-tarjan node-compare nodes get-successors)
  (define index-counter 0)
  (define index (hash))
  (define lowlink (hash))
  (define on-stack (hash))
  (define stack (pvector-empty))
  (define sccs (pvector-empty))

  (define (strongconnect node)
    (set! index (hash-set index node index-counter))
    (set! lowlink (hash-set lowlink node index-counter))
    (set! index-counter (+ index-counter 1))

    (set! stack (pvector-cons-right stack node))
    (set! on-stack (hash-set on-stack node #t))

    (for ([succ (in-pvector (get-successors node))])
      (cond
        [(not (hash-has-key? index succ))
         (strongconnect succ)
         (define new-low (min (hash-ref lowlink node 0) (hash-ref lowlink succ 0)))
         (set! lowlink (hash-set lowlink node new-low))]
        [(hash-has-key? on-stack succ)
         (define new-low (min (hash-ref lowlink node 0) (hash-ref index succ 0)))
         (set! lowlink (hash-set lowlink node new-low))]))

    (when (= (hash-ref lowlink node 0) (hash-ref index node 0))
      (define-values (scc new-stack)
        (let loop ([component (pvector-empty)] [stk stack])
          (define-values (top stk*) (pvector-pop-right stk))
          (set! on-stack (hash-remove on-stack top))
          (define new-component (pvector-cons-left component top))
          (if (equal? top node)
              (values new-component stk*)
              (loop new-component stk*))))
      (set! stack new-stack)
      (set! sccs (pvector-cons-right sccs scc))))

  (for ([node (in-pvector nodes)])
    (unless (hash-has-key? index node)
      (strongconnect node)))

  sccs)

;; scc-kosaraju: node-compare nodes get-successors get-predecessors -> pvector[pvector]
(define (scc-kosaraju node-compare nodes get-successors get-predecessors)
  (define visited (hash))
  (define finish-order (pvector-empty))

  (define (dfs1 node)
    (unless (hash-has-key? visited node)
      (set! visited (hash-set visited node #t))
      (for ([succ (in-pvector (get-successors node))])
        (dfs1 succ))
      (set! finish-order (pvector-cons-right finish-order node))))

  (for ([node (in-pvector nodes)])
    (dfs1 node))

  (set! visited (hash))
  (define sccs (pvector-empty))

  (define (dfs2 node component)
    (cond
      [(hash-has-key? visited node) component]
      [else
       (set! visited (hash-set visited node #t))
       (define new-component (pvector-cons-right component node))
       (for/fold ([comp new-component])
                 ([pred (in-pvector (get-predecessors node))])
         (dfs2 pred comp))]))

  (for ([node (in-pvector (pvector-reverse finish-order))])
    (unless (hash-has-key? visited node)
      (set! sccs (pvector-cons-right sccs (dfs2 node (pvector-empty))))))

  sccs)

;; condensation-graph: node-compare nodes get-successors ->
;;   (values node->scc-id scc-nodes scc-successors)
;;   node->scc-id  : 不可变 hash[node -> scc-id]
;;   scc-nodes     : pvector[pvector]
;;   scc-successors: procedure (scc-id -> pvector of scc-ids, 升序)
(define (condensation-graph node-compare nodes get-successors)
  (define sccs (scc-tarjan node-compare nodes get-successors))

  (define node->scc-id
    (for/fold ([m (hash)])
              ([scc (in-pvector sccs)]
               [id (in-naturals)])
      (for/fold ([m* m])
                ([node (in-pvector scc)])
        (hash-set m* node id))))

  ;; SCC 邻接: intmap[src-scc -> intmap[dst-scc -> #t]] (键升序 = 原 integer-compare 序)
  (define scc-adj
    (for/fold ([adj intmap-empty])
              ([node (in-pvector nodes)])
      (define src-scc (hash-ref node->scc-id node 0))
      (for/fold ([adj* adj])
                ([succ (in-pvector (get-successors node))])
        (define dst-scc (hash-ref node->scc-id succ 0))
        (if (= src-scc dst-scc)
            adj*
            (let ([existing (intmap-ref adj* src-scc intmap-empty)])
              (intmap-set adj* src-scc (intmap-set existing dst-scc #t)))))))

  (define (scc-successors scc-id)
    (define adj-map (intmap-ref scc-adj scc-id intmap-empty))
    (list->pvector
     (for/list ([k (in-intmap-keys adj-map)]) k)))

  (values node->scc-id sccs scc-successors))

;; scc-id: node->scc-id (dict) + node -> integer SCC id
(define (scc-id node->scc-id node)
  (dict-ref node->scc-id node #f))

;; scc-members: scc-nodes scc-id -> pvector
(define (scc-members scc-nodes scc-id)
  (pvector-ref scc-nodes scc-id))

;; ============================================================
;; 遍历算法（原 graph/traversal.rkt）
;; ============================================================

;; graph-dfs-preorder: Graph, vertex-id -> pvector[vertex-val]
(define (graph-dfs-preorder g start)
  (define visited intbits-empty)

  (define (visit v result)
    (cond
      [(intbits-ref visited v) result]
      [else
       (set! visited (intbits-set visited v))
       (define result* (pvector-cons-right result v))
       (for/fold ([r result*])
                 ([succ (in-intbits/descending (graph-view-succ-bits g v))])
         (visit succ r))]))

  (visit (graph-view-node->id g start) (pvector-empty)))

;; graph-dfs-postorder: Graph, vertex-id -> pvector[vertex-val]
(define (graph-dfs-postorder g start)
  (define visited intbits-empty)

  (define (visit v result)
    (cond
      [(intbits-ref visited v) result]
      [else
       (set! visited (intbits-set visited v))
       (define result*
         (for/fold ([r result])
                   ([succ (in-intbits/descending (graph-view-succ-bits g v))])
           (visit succ r)))
       (pvector-cons-right result* v)]))

  (visit (graph-view-node->id g start) (pvector-empty)))

;; graph-dfs-reverse-postorder: Graph, vertex-id -> pvector[vertex-val]
(define (graph-dfs-reverse-postorder g start)
  (pvector-reverse (graph-dfs-postorder g start)))

;; graph-bfs: Graph, vertex-id -> pvector[vertex-val]
(define (graph-bfs g start)
  (define start-val (graph-view-node->id g start))
  (define visited (intbits-set intbits-empty start-val))

  (let loop ([queue (pvector-cons-right (pvector-empty) start-val)]
             [result (pvector-empty)])
    (cond
      [(pvector-empty? queue) result]
      [else
       (define-values (v queue*) (pvector-pop-left queue))
       (define result* (pvector-cons-right result v))
       (define-values (new-queue new-visited)
         (for/fold ([q queue*] [vis visited])
                   ([succ (in-intbits/descending (graph-view-succ-bits g v))])
           (if (intbits-ref vis succ)
               (values q vis)
               (values (pvector-cons-right q succ)
                       (intbits-set vis succ)))))
       (set! visited new-visited)
       (loop new-queue result*)])))

;; graph-topo-sort: Graph -> pvector[vertex-val] or #f (Kahn)
(define (graph-topo-sort g)
  (define vertices (graph-view-vertex-bits g))
  (define in-degree
    (for/fold ([m intmap-empty])
              ([v (in-intbits/descending vertices)])
      (intmap-set m v (intbits-count (graph-view-pred-bits g v)))))

  (define initial-queue
    (for/fold ([q (pvector-empty)])
              ([v (in-intbits/descending vertices)])
      (if (= (intmap-ref in-degree v 0) 0)
          (pvector-cons-right q v)
          q)))

  (define vertex-count (intbits-count vertices))

  (let loop ([queue initial-queue]
             [result (pvector-empty)]
             [degrees in-degree])
    (cond
      [(pvector-empty? queue)
       (if (= (pvector-length result) vertex-count)
           result
           #f)]
      [else
       (define-values (v queue*) (pvector-pop-left queue))
       (define result* (pvector-cons-right result v))
       (define-values (new-queue new-degrees)
         (for/fold ([q queue*] [d degrees])
                   ([succ (in-intbits/descending (graph-view-succ-bits g v))])
           (define new-deg (- (intmap-ref d succ 0) 1))
           (define d* (intmap-set d succ new-deg))
           (if (= new-deg 0)
               (values (pvector-cons-right q succ) d*)
               (values q d*))))
       (loop new-queue result* new-degrees)])))

;; ---- 参数化遍历（节点判等 = equal?）----

;; dfs-preorder: node-compare get-successors start -> pvector
(define (dfs-preorder node-compare get-successors start)
  (define visited (hash))

  (define (visit node result)
    (cond
      [(hash-has-key? visited node) result]
      [else
       (set! visited (hash-set visited node #t))
       (define result* (pvector-cons-right result node))
       (for/fold ([r result*])
                 ([succ (in-pvector (get-successors node))])
         (visit succ r))]))

  (visit start (pvector-empty)))

;; dfs-postorder: node-compare get-successors start -> pvector
(define (dfs-postorder node-compare get-successors start)
  (define visited (hash))

  (define (visit node result)
    (cond
      [(hash-has-key? visited node) result]
      [else
       (set! visited (hash-set visited node #t))
       (define result*
         (for/fold ([r result])
                   ([succ (in-pvector (get-successors node))])
           (visit succ r)))
       (pvector-cons-right result* node)]))

  (visit start (pvector-empty)))

;; dfs-reverse-postorder: node-compare get-successors start -> pvector
(define (dfs-reverse-postorder node-compare get-successors start)
  (pvector-reverse (dfs-postorder node-compare get-successors start)))

;; bfs: node-compare get-successors start -> pvector
(define (bfs node-compare get-successors start)
  (define visited (hash-set (hash) start #t))

  (let loop ([queue (pvector-cons-right (pvector-empty) start)]
             [result (pvector-empty)])
    (cond
      [(pvector-empty? queue) result]
      [else
       (define-values (node queue*) (pvector-pop-left queue))
       (define result* (pvector-cons-right result node))
       (define-values (new-queue new-visited)
         (for/fold ([q queue*] [v visited])
                   ([succ (in-pvector (get-successors node))])
           (if (hash-has-key? v succ)
               (values q v)
               (values (pvector-cons-right q succ)
                       (hash-set v succ #t)))))
       (set! visited new-visited)
       (loop new-queue result*)])))

;; topology-sort: node-compare nodes get-successors get-predecessors
;;   -> pvector or #f
(define (topology-sort node-compare nodes get-successors get-predecessors)
  (define in-degree
    (for/fold ([m (hash)])
              ([node (in-pvector nodes)])
      (hash-set m node (pvector-length (get-predecessors node)))))

  (define initial-queue
    (for/fold ([q (pvector-empty)])
              ([node (in-pvector nodes)])
      (if (= (hash-ref in-degree node 0) 0)
          (pvector-cons-right q node)
          q)))

  (let loop ([queue initial-queue]
             [result (pvector-empty)]
             [degrees in-degree])
    (cond
      [(pvector-empty? queue)
       (if (= (pvector-length result) (pvector-length nodes))
           result
           #f)]
      [else
       (define-values (node queue*) (pvector-pop-left queue))
       (define result* (pvector-cons-right result node))
       (define-values (new-queue new-degrees)
         (for/fold ([q queue*] [d degrees])
                   ([succ (in-pvector (get-successors node))])
           (define new-deg (- (hash-ref d succ 0) 1))
           (define d* (hash-set d succ new-deg))
           (if (= new-deg 0)
               (values (pvector-cons-right q succ) d*)
               (values q d*))))
       (loop new-queue result* new-degrees)])))

;; ============================================================
;; 可达性 / 路径算法（原 graph/reachability.rkt）
;; ============================================================

;; graph-reachable-from: Graph, vertex-id -> intbits
(define (graph-reachable-from g start)
  (define visited intbits-empty)

  (define (visit v)
    (unless (intbits-ref visited v)
      (set! visited (intbits-set visited v))
      (for ([succ (in-intbits/descending (graph-view-succ-bits g v))])
        (visit succ))))

  (visit (graph-view-node->id g start))
  visited)

;; graph-reachable-from-set: Graph, intbits -> intbits
(define (graph-reachable-from-set g starts)
  (define visited intbits-empty)

  (define (visit v)
    (unless (intbits-ref visited v)
      (set! visited (intbits-set visited v))
      (for ([succ (in-intbits/descending (graph-view-succ-bits g v))])
        (visit succ))))

  (for ([start (in-intbits/descending starts)])
    (visit start))
  visited)

;; graph-find-path: Graph, vertex-id, vertex-id -> pvector[vertex-val] or #f
(define (graph-find-path g start end)
  (define end-val (graph-view-node->id g end))
  (define visited intbits-empty)

  (define (search v path)
    (cond
      [(= v end-val)
       (pvector-cons-right path v)]
      [(intbits-ref visited v) #f]
      [else
       (set! visited (intbits-set visited v))
       (define path* (pvector-cons-right path v))
       (for/or ([succ (in-intbits/descending (graph-view-succ-bits g v))])
         (search succ path*))]))

  (search (graph-view-node->id g start) (pvector-empty)))

;; graph-all-paths: Graph, vertex-id, vertex-id -> pvector[pvector[vertex-val]]
(define (graph-all-paths g start end)
  (define end-val (graph-view-node->id g end))

  (define (search v path visited)
    (cond
      [(= v end-val)
       (pvector-cons-right (pvector-empty) (pvector-cons-right path v))]
      [(intbits-ref visited v) (pvector-empty)]
      [else
       (define new-visited (intbits-set visited v))
       (define path* (pvector-cons-right path v))
       (for/fold ([paths (pvector-empty)])
                 ([succ (in-intbits/descending (graph-view-succ-bits g v))])
         (pvector-append paths (search succ path* new-visited)))]))

  (search (graph-view-node->id g start) (pvector-empty) intbits-empty))

;; ---- 参数化可达性（节点判等 = equal?）----

;; reachable-from: node-compare get-successors start -> pvector
(define (reachable-from node-compare get-successors start)
  (define visited (hash))

  (define (visit node result)
    (cond
      [(hash-has-key? visited node) result]
      [else
       (set! visited (hash-set visited node #t))
       (define result* (pvector-cons-right result node))
       (for/fold ([r result*])
                 ([succ (in-pvector (get-successors node))])
         (visit succ r))]))

  (visit start (pvector-empty)))

;; reachable-from-set: node-compare get-successors starts
;;   -> 不可变 hash 集合 (node -> #t)  [原为 ordered-map 集合]
(define (reachable-from-set node-compare get-successors starts)
  (define visited (hash))

  (define (visit node)
    (unless (hash-has-key? visited node)
      (set! visited (hash-set visited node #t))
      (for ([succ (in-pvector (get-successors node))])
        (visit succ))))

  (for ([start (in-pvector starts)])
    (visit start))
  visited)

;; find-path: node-compare get-successors start end -> pvector or #f
(define (find-path node-compare get-successors start end)
  (define visited (hash))

  (define (search node path)
    (cond
      [(equal? node end)
       (pvector-cons-right path node)]
      [(hash-has-key? visited node) #f]
      [else
       (set! visited (hash-set visited node #t))
       (define path* (pvector-cons-right path node))
       (for/or ([succ (in-pvector (get-successors node))])
         (search succ path*))]))

  (search start (pvector-empty)))

;; all-paths: node-compare get-successors start end -> pvector[pvector]
(define (all-paths node-compare get-successors start end)
  (define (search node path visited)
    (cond
      [(equal? node end)
       (pvector-cons-right (pvector-empty) (pvector-cons-right path node))]
      [(hash-has-key? visited node) (pvector-empty)]
      [else
       (define new-visited (hash-set visited node #t))
       (define path* (pvector-cons-right path node))
       (for/fold ([paths (pvector-empty)])
                 ([succ (in-pvector (get-successors node))])
         (pvector-append paths (search succ path* new-visited)))]))

  (search start (pvector-empty) (hash)))

;; ============================================================
;; Exports
;; ============================================================

;; ID 类型 — 不导出构造器
(provide vertex-id? vertex-id-val)
(provide edge-id? edge-id-val)
(provide vertex-id-compare edge-id-compare)

;; Graph struct
(provide graph graph? graph-empty)

;; 顶点操作
(provide graph-add-vertex)
(provide graph-remove-vertex graph-remove-vertex*)
(provide graph-vertex? graph-vertices-set graph-vertex-count)

;; 边操作
(provide graph-add-edge graph-add-edge-pair)
(provide graph-remove-edge graph-remove-edge*)
(provide graph-remove-edge-between graph-remove-edges-between)
(provide graph-edge? graph-edges-set graph-edge-count)
(provide graph-edge-src graph-edge-dst graph-edge-endpoints)
(provide graph-edge-pair)

;; 邻接查询
(provide graph-in-edges graph-out-edges)
(provide graph-in-degree graph-out-degree)
(provide graph-edges-between graph-has-edge-to?)
(provide graph-successors graph-predecessors)

;; 迭代
(provide in-graph-vertices in-graph-edges)
(provide in-graph-out-edges)
(provide in-graph-successors in-graph-predecessors)

;; SCC 算法（原 graph-scc.rkt / graph-algorithms.rkt）
(provide graph-scc graph-condensation)
(provide scc-tarjan scc-kosaraju condensation-graph)
(provide scc-id scc-members)

;; 遍历算法
(provide graph-dfs-preorder graph-dfs-postorder graph-dfs-reverse-postorder)
(provide graph-bfs graph-topo-sort)
(provide dfs-preorder dfs-postorder dfs-reverse-postorder bfs topology-sort)

;; 可达性 / 路径算法
(provide graph-reachable-from graph-reachable-from-set)
(provide graph-find-path graph-all-paths)
(provide reachable-from reachable-from-set find-path all-paths)

;; ============================================================
;; ugraph — 无向紧凑图 (undirected graph)
;; ============================================================
;;
;; 与上面的 graph (有向标注多重图, intmap[v→intmap[v→intbits]]) 互补:
;; ugraph 是**无向、无标注、无重边的简单图**, 用 pvector[intbits] 紧凑表示,
;; 面向"稠密整数顶点 + 极快 degree/邻居集运算"的场景 (寄存器干涉图是典型)。
;;
;; 三原语各司其职:
;;   - intbits : 每顶点邻居集 = 位集 (has-edge? 位测、degree = popcount、
;;               neighbors 直接是集合可做位运算)。
;;   - pvector : id → 邻接位集 的持久数组 (函数式 O(log n) 更新); 内插模下
;;               另存 id → 顶点 反向表。
;;   - immutable hash : 内插模下 顶点 → 稠密 id。持久图要求内插表也持久,
;;               故用不可变 HAMT 而非可变 swisstable。
;;
;; 两种模式, 同一套 API:
;;   - identity 整数模 (make-ugraph n): 顶点即 id ∈ [0,n), 零哈希开销——
;;       add-edge/has-edge? 直接整数索引 pvector[intbits] (干涉图热路径)。
;;   - 内插模 (make-ugraph): 任意 equal? 可哈希顶点, 首次出现即内插成稠密 id,
;;       图随边增长。
;;
;; 修改函数式 (返回新图)。add-edge 幂等; edge-count O(1) 增量维护。

;; vtoi  : #f (identity) | immutable-hash[vertex→id] (内插)
;; itov  : #f (identity) | pvector[id→vertex]        (内插反向表)
;; adj   : pvector[id→intbits]  邻居 id 位集
;; nv    : fixnum 顶点数
;; ne    : fixnum 无向边数 (O(1) 维护)
(struct ugraph (vtoi itov adj nv ne)
  #:property prop:custom-write
  (lambda (g port mode)
    (fprintf port "#<ugraph: ~a vertices, ~a edges>" (ugraph-nv g) (ugraph-ne g)))
  #:methods gen:graph-view
  [(define (graph-view-vertex-bits g) (ugraph-vertex-bits g))
   (define (graph-view-succ-bits g id) (pvector-ref (ugraph-adj g) id))
   (define (graph-view-pred-bits g id) (pvector-ref (ugraph-adj g) id))
   (define (graph-view-node->id g node)
     (or (ugraph-vertex->id g node)
         (raise-arguments-error 'graph-algorithm "vertex not in graph"
                                "vertex" node)))
   (define (graph-view-directed? g) #f)
   (define (graph-view-multi? g) #f)
   (define (graph-view-edge-labeled? g) #f)])

;; (make-ugraph)   -> 空内插图 (任意顶点)
;; (make-ugraph n) -> identity 整数图, 顶点 [0,n)
(define make-ugraph
  (case-lambda
    [() (ugraph (hash) (pvector-empty) (pvector-empty) 0 0)]
    [(n)
     (unless (exact-nonnegative-integer? n)
       (raise-argument-error 'make-ugraph "exact-nonnegative-integer?" n))
     (ugraph #f #f
             (for/fold ([pv (pvector-empty)]) ([_ (in-range n)])
               (pvector-cons-right pv intbits-empty))
             n 0)]))

;; 顶点 → id, 不存在返回 #f
(define (ugraph-vertex->id g v)
  (cond
    [(ugraph-vtoi g) (hash-ref (ugraph-vtoi g) v #f)]
    [(and (exact-nonnegative-integer? v) (< v (ugraph-nv g))) v]
    [else #f]))

;; 内插 v → (values id g')
(define (ugraph-intern g v)
  (define vtoi (ugraph-vtoi g))
  (cond
    [vtoi
     (define existing (hash-ref vtoi v #f))
     (cond
       [existing (values existing g)]
       [else
        (define id (ugraph-nv g))
        (values id
                (ugraph (hash-set vtoi v id)
                        (pvector-cons-right (ugraph-itov g) v)
                        (pvector-cons-right (ugraph-adj g) intbits-empty)
                        (add1 id) (ugraph-ne g)))])]
    [(and (exact-nonnegative-integer? v) (< v (ugraph-nv g)))
     (values v g)]
    [else
     (raise-arguments-error 'ugraph
                            "vertex out of range for integer-vertex graph"
                            "vertex" v "size" (ugraph-nv g))]))

(define (ugraph-id->vertex g id)
  (if (ugraph-itov g) (pvector-ref (ugraph-itov g) id) id))

;; 加入孤立顶点
(define (ugraph-add-vertex g v)
  (define-values (_id g*) (ugraph-intern g v))
  g*)

;; 加无向边 v1-v2 (幂等)
(define (ugraph-add-edge g v1 v2)
  (define-values (id1 g1) (ugraph-intern g v1))
  (define-values (id2 g2) (ugraph-intern g1 v2))
  (define adj (ugraph-adj g2))
  (cond
    [(intbits-ref (pvector-ref adj id1) id2) g2]      ; 已有此边 → 幂等
    [else
     (define adj1 (pvector-set adj  id1 (intbits-set (pvector-ref adj  id1) id2)))
     (define adj2 (pvector-set adj1 id2 (intbits-set (pvector-ref adj1 id2) id1)))
     (ugraph (ugraph-vtoi g2) (ugraph-itov g2) adj2 (ugraph-nv g2)
             (add1 (ugraph-ne g2)))]))

(define (ugraph-has-vertex? g v) (and (ugraph-vertex->id g v) #t))

;; v1-v2 边是否存在 - O(log n)
(define (ugraph-has-edge? g v1 v2)
  (define id1 (ugraph-vertex->id g v1))
  (define id2 (ugraph-vertex->id g v2))
  (and id1 id2 (intbits-ref (pvector-ref (ugraph-adj g) id1) id2) #t))

;; v 的邻居 id 位集 (intbits)。顶点不存在 → 空位集。
(define (ugraph-neighbors g v)
  (define id (ugraph-vertex->id g v))
  (if id (pvector-ref (ugraph-adj g) id) intbits-empty))

(define (ugraph-degree g v) (intbits-count (ugraph-neighbors g v)))
(define (ugraph-vertex-count g) (ugraph-nv g))
(define (ugraph-edge-count g) (ugraph-ne g))     ; O(1)

;; v 的邻居顶点序列 (按 id 升序)。identity 模即整数邻居。
(define (in-ugraph-neighbors g v)
  (define bits (ugraph-neighbors g v))
  (if (ugraph-itov g)
      (in-list (for/list ([nid (in-intbits bits)]) (ugraph-id->vertex g nid)))
      (in-intbits bits)))

(define (ugraph-adjacent g v) (for/list ([nv (in-ugraph-neighbors g v)]) nv))

(define (in-ugraph-vertices g)
  (if (ugraph-itov g) (in-pvector (ugraph-itov g)) (in-range (ugraph-nv g))))

(define (ugraph-vertices g) (for/list ([v (in-ugraph-vertices g)]) v))

;; ugraph 导出
(provide make-ugraph ugraph?
         ugraph-add-vertex ugraph-add-edge
         ugraph-has-vertex? ugraph-has-edge?
         ugraph-neighbors ugraph-degree
         ugraph-vertex-count ugraph-edge-count
         ugraph-vertices ugraph-adjacent
         in-ugraph-neighbors in-ugraph-vertices)
