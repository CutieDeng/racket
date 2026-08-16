#lang racket

;; ============================================================
;; pipeline/regalloc/liveness.rkt - 活跃变量分析
;; ============================================================

(require "../../semantic/control-flow.rkt"
         "../../semantic/use-def.rkt"
         "../../parser/ast.rkt"
         "types.rkt"
         racket/pvector
         racket/intmap
         racket/intbits)

(provide
  (struct-out bb-liveness)
  (struct-out fn-liveness)
  analyze-liveness
  get-live-in
  get-live-out
  get-live-at-instruction
  liveness-get-reg-index
  liveness-get-index-reg
  format-liveness)

;; ============================================================
;; 数据结构
;; ============================================================

(struct bb-liveness
  (live-in live-out live-gen live-kill)
  #:transparent)

(struct fn-liveness
  (reg-index index-reg block-info num-vars)
  #:transparent)

;; ============================================================
;; 收集变量
;; ============================================================

;; 收集所有变量 (纯函数式版本)
;; 使用 reg-om 自动去重并保持排序
(define (collect-all-variables fn)
  (define var-map
    (for*/fold ([m reg-om-empty])
               ([kv (in-intmap-pairs (asm-function-blocks fn))]
                [ins (in-pvector (basic-block-instructions (cdr kv)))]
                #:when (ast-ins? ins))
      (define use-def (extract-use-def ins))
      (define m1
        (for/fold ([acc m])
                  ([ref (in-list (use-def-flat-defs use-def))])
          (define rid (reg-ref->reg-id ref))
          (reg-om-set acc rid #t)))
      (for/fold ([acc m1])
                ([ref (in-list (use-def-flat-uses use-def))])
        (define rid (reg-ref->reg-id ref))
        (reg-om-set acc rid #t))))
  ;; reg-om 已按 reg<? 升序排序，提取键
  (for/list ([kv (in-reg-om var-map)])
    (car kv)))

(define (build-var-index-map vars)
  (for/fold ([reg-index reg-om-empty]
             [index-reg (pvector-empty)])
            ([var (in-list vars)]
             [i (in-naturals)])
    (values (reg-om-set reg-index var i)
            (pvector-cons-right index-reg var))))

;; ============================================================
;; 计算 gen/kill
;; ============================================================

(define (compute-gen-kill block reg-index)
  (define gen intbits-empty)
  (define kill intbits-empty)
  (for ([ins (in-pvector (basic-block-instructions block))])
    (when (ast-ins? ins)
      (define use-def (extract-use-def ins))
      (for ([ref (in-list (use-def-flat-uses use-def))])
        (define rid (reg-ref->reg-id ref))
        (define idx (reg-om-ref reg-index rid #f))
        (when idx
          (unless (intbits-ref kill idx)
            (set! gen (intbits-set gen idx)))))
      (for ([ref (in-list (use-def-flat-defs use-def))])
        (define rid (reg-ref->reg-id ref))
        (define idx (reg-om-ref reg-index rid #f))
        (when idx
          (set! kill (intbits-set kill idx))))))
  (values gen kill))

;; ============================================================
;; 主分析函数
;; ============================================================

(define (analyze-liveness fn)
  (define vars (collect-all-variables fn))
  (define num-vars (length vars))
  (define-values (reg-index index-reg) (build-var-index-map vars))

  (define block-gen-kill
    (for/fold ([m intmap-empty])
              ([kv (in-intmap-pairs (asm-function-blocks fn))])
      (define blk-id-val (car kv))
      (define block (cdr kv))
      (define-values (gen kill) (compute-gen-kill block reg-index))
      (intmap-set m blk-id-val (cons gen kill))))

  (define initial-block-info
    (for/fold ([m intmap-empty])
              ([kv (in-intmap-pairs (asm-function-blocks fn))])
      (define blk-id-val (car kv))
      (define gen-kill (intmap-ref block-gen-kill blk-id-val))
      (intmap-set m blk-id-val
                       (bb-liveness intbits-empty intbits-empty
                                    (car gen-kill) (cdr gen-kill)))))

  (define (iterate block-info)
    (define changed? #f)
    (define new-info
      (for/fold ([m block-info])
                ([kv (in-intmap-pairs/reverse (asm-function-blocks fn))])
        (define blk-id-val (car kv))
        (define block (cdr kv))
        (define old-liveness (intmap-ref m blk-id-val))
        (define gen (bb-liveness-live-gen old-liveness))
        (define kill (bb-liveness-live-kill old-liveness))
        (define old-out (bb-liveness-live-out old-liveness))

        (define new-out
          (for/fold ([out intbits-empty])
                    ([succ-bbid (in-list (fn-successors fn (basic-block-id block)))])
            (when succ-bbid
              (define succ-key (if (bb-id? succ-bbid) (bb-id-val succ-bbid) succ-bbid))
              (define succ-info (intmap-ref m succ-key #f))
              (when succ-info
                (set! out (intbits-union out (bb-liveness-live-in succ-info)))))
            out))

        (define new-in (intbits-union gen (intbits-subtract new-out kill)))

        (unless (and (= new-out old-out)
                     (= new-in (bb-liveness-live-in old-liveness)))
          (set! changed? #t))

        (intmap-set m blk-id-val (bb-liveness new-in new-out gen kill))))

    (if changed? (iterate new-info) new-info))

  (define final-block-info (iterate initial-block-info))
  (fn-liveness reg-index index-reg final-block-info num-vars))

;; ============================================================
;; 查询函数
;; ============================================================

(define (get-live-in liveness bb-id)
  (define key (if (bb-id? bb-id) (bb-id-val bb-id) bb-id))
  (define info (intmap-ref (fn-liveness-block-info liveness) key #f))
  (if info (bb-liveness-live-in info) intbits-empty))

(define (get-live-out liveness bb-id)
  (define key (if (bb-id? bb-id) (bb-id-val bb-id) bb-id))
  (define info (intmap-ref (fn-liveness-block-info liveness) key #f))
  (if info (bb-liveness-live-out info) intbits-empty))

(define (get-live-at-instruction fn liveness block ins-index)
  (define reg-index (fn-liveness-reg-index liveness))
  (define instructions (basic-block-instructions block))
  (define n-instructions (pvector-length instructions))
  (define initial-live (get-live-out liveness (basic-block-id block)))

  (for/fold ([live initial-live])
            ([i (in-range (sub1 n-instructions) (sub1 ins-index) -1)])
    (define ins (pvector-ref instructions i))
    (if (ast-ins? ins)
        (let* ([use-def (extract-use-def ins)]
               [live1 (for/fold ([l live])
                               ([ref (in-list (use-def-flat-defs use-def))])
                        (define rid (reg-ref->reg-id ref))
                        (define idx (reg-om-ref reg-index rid #f))
                        (if idx (intbits-clear l idx) l))]
               [live2 (for/fold ([l live1])
                               ([ref (in-list (use-def-flat-uses use-def))])
                        (define rid (reg-ref->reg-id ref))
                        (define idx (reg-om-ref reg-index rid #f))
                        (if idx (intbits-set l idx) l))])
          live2)
        live)))

(define (liveness-get-reg-index liveness reg)
  (reg-om-ref (fn-liveness-reg-index liveness) reg #f))

(define (liveness-get-index-reg liveness idx)
  (pvector-ref (fn-liveness-index-reg liveness) idx))

;; ============================================================
;; 辅助
;; ============================================================

(define (in-intmap-pairs/reverse m)
  (in-list (reverse (for/list ([kv (in-intmap-pairs m)]) kv))))

;; ============================================================
;; 格式化
;; ============================================================

(define (format-liveness fn liveness)
  (define lines '())
  (define (add-line! s) (set! lines (cons s lines)))

  (add-line! (format "=== 活跃变量分析: ~a ===" (asm-function-name fn)))
  (add-line! (format "变量数: ~a" (fn-liveness-num-vars liveness)))
  (add-line! "")
  (add-line! "变量索引:")
  (for ([i (in-range (fn-liveness-num-vars liveness))])
    (define reg (pvector-ref (fn-liveness-index-reg liveness) i))
    (add-line! (format "  [~a] ~a" i (format-reg-id reg))))

  (add-line! "")
  (add-line! "块活跃信息:")
  (fn-for-each-block fn
    (lambda (block)
      (define bb-id (basic-block-id block))
      (define info (intmap-ref (fn-liveness-block-info liveness) (bb-id-val bb-id) #f))
      (when info
        (add-line! (format "  bb~a:" (bb-id-val bb-id)))
        (add-line! (format "    live-in:  ~a" (format-live-vars liveness (bb-liveness-live-in info))))
        (add-line! (format "    live-out: ~a" (format-live-vars liveness (bb-liveness-live-out info))))
        (add-line! (format "    gen:      ~a" (format-live-vars liveness (bb-liveness-live-gen info))))
        (add-line! (format "    kill:     ~a" (format-live-vars liveness (bb-liveness-live-kill info)))))))

  (string-join (reverse lines) "\n"))

(define (format-live-vars liveness bs)
  (if (intbits-empty? bs)
      "{}"
      (format "{ ~a }"
              (string-join
               (for/list ([i (in-intbits bs)])
                 (format-reg-id (pvector-ref (fn-liveness-index-reg liveness) i)))
               ", "))))

(define (format-reg-id r)
  (define class-str (case (reg-id-class r) [(gpr) "x"] [(fpr) "v"] [(predicate) "p"] [else "?"]))
  (if (reg-id-virtual? r)
      (format "~a.~a" (if (eq? (reg-id-width r) 32) "w" class-str) (reg-id-id r))
      (format "~a~a" (if (eq? (reg-id-width r) 32) "w" class-str) (reg-id-id r))))
