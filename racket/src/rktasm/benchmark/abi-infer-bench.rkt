#!/usr/bin/env racket
#lang racket

;; abi-infer-bench.rkt
;;
;; 评估 ABI 推断相关性能：
;; 1) 未知/声明调用查询路径（旧逻辑仿真 vs 预计算缓存）
;; 2) infer-all-abis 端到端吞吐
;;
;; 用法：
;;   racket benchmark/abi-infer-bench.rkt

(require "../pipeline/regalloc/abi.rkt"
         "../pipeline/regalloc/abi-config.rkt"
         "../pipeline/regalloc/abi-infer.rkt"
         "../semantic/control-flow.rkt"
         "../parser/frontend.rkt"
         "../parser/ast.rkt"
         racket/intbits
         racket/string)

(define (bench name iters thunk)
  (collect-garbage)
  (collect-garbage)
  (define t0 (current-inexact-milliseconds))
  (for ([i (in-range iters)])
    (thunk i))
  (define t1 (current-inexact-milliseconds))
  (define ms (- t1 t0))
  (printf "~a: ~a iters, ~a ms, ~a ns/op\n"
          name iters ms
          (inexact->exact (round (* 1000000.0 (/ ms (max iters 1)))))))

(define (abi->scratch-def abi)
  (define (class-scratch-def cfg)
    (define num-regs (reg-class-config-num-regs cfg))
    (define banned (reg-class-config-banned cfg))
    (define preserved (reg-class-config-preserved cfg))
    (define all-regs (for/intbits ([i (in-range num-regs)]) i))
    (intbits-subtract (intbits-subtract all-regs banned) preserved))
  (inferred-abi (class-scratch-def (abi-config-gpr abi))
                (class-scratch-def (abi-config-fpr abi))
                (class-scratch-def (abi-config-pred abi))))

(define (mk-ring-source n)
  (string-join
   (for/list ([i (in-range n)])
     (define fname (format "f~a" i))
     (define next (format "f~a" (modulo (add1 i) n)))
     (format "(: function ~a)\n(: label entry)\n  (bl ~a)\n  (blr x16)\n  (ret)\n(: end-function)\n"
             fname next))
   "\n"))

(define (mk-fanout-source n fanout)
  (string-join
   (for/list ([i (in-range n)])
     (define fname (format "f~a" i))
     (define call-lines
       (for/list ([k (in-range fanout)])
         (define target (format "f~a" (modulo (+ i (add1 k)) n)))
         (format "  (bl ~a)" target)))
     (string-join
      (append
       (list (format "(: function ~a)" fname)
             "(: label entry)")
       call-lines
       (list "  (blr x16)"
             "  (ret)"
             "(: end-function)"))
      "\n"))
   "\n\n"))

(define (source->cfg source)
  (define results (parse-string source))
  (when (parse-results-has-errors? results)
    (error 'abi-infer-bench "解析错误:\n~a" (format-parse-errors-report results)))
  (define items
    (for/list ([r (parse-results-items results)]
               #:when (parse-result-ok? r))
      (parse-result-instruction r)))
  (build-cfg items))

(define (bench-infer-case name cfg iters)
  ;; 冷启动：清空预处理缓存，测首轮分析（含预处理）
  (clear-abi-infer-cache!)
  (collect-garbage)
  (collect-garbage)
  (define cold-t0 (current-inexact-milliseconds))
  (void (infer-all-abis cfg))
  (define cold-t1 (current-inexact-milliseconds))
  (printf "~a-cold: 1 iter, ~a ms\n"
          name
          (- cold-t1 cold-t0))

  ;; 热路径：复用缓存，测持续吞吐
  (collect-garbage)
  (collect-garbage)
  (define t0 (current-inexact-milliseconds))
  (for ([i (in-range iters)])
    (void (infer-all-abis cfg)))
  (define t1 (current-inexact-milliseconds))
  (define ms (- t1 t0))
  (printf "~a-warm: ~a iters, ~a ms, ~a ms/op\n"
          name
          iters
          ms
          (real->double-flonum (/ ms (max iters 1)))))

(define (bench-cross-cfg-case name cfgs #:reset-each? [reset-each? #f])
  (collect-garbage)
  (collect-garbage)
  (define t0 (current-inexact-milliseconds))
  (for ([cfg (in-list cfgs)])
    (when reset-each?
      (clear-abi-infer-cache!))
    (void (infer-all-abis cfg)))
  (define t1 (current-inexact-milliseconds))
  (define ms (- t1 t0))
  (printf "~a: ~a cfgs, ~a ms, ~a ms/cfg\n"
          name
          (length cfgs)
          ms
          (real->double-flonum (/ ms (max (length cfgs) 1)))))

(define (main)
  (abi-config-path "config/abi.rktd")
  (void (reload-abi-config))
  (default-abi-name 'aapcs64)

  (define default-name (default-abi-name))
  (define default-abi (and default-name (get-abi-by-name default-name)))
  (define declared-abis
    (hash 'a (or (get-abi-by-name 'aapcs64) arm64-abi)
          'b (or (get-abi-by-name 'leaf) arm64-abi)))

  (define declared-scratch
    (for/hash ([(k abi) (in-hash declared-abis)])
      (values k (abi->scratch-def abi))))
  (define default-scratch (if default-abi (abi->scratch-def default-abi) inferred-abi-empty))

  (printf "=== ABI Infer Lookup Microbench ===\n")
  (bench 'old-unknown-call-path 2000000
         (lambda (_)
           ;; 仿真旧路径：每次未知调用都查默认 ABI 并转换 scratch-def
           (define name (default-abi-name))
           (define abi (and name (get-abi-by-name name)))
           (if abi (abi->scratch-def abi) inferred-abi-empty)))

  (bench 'new-unknown-call-path 2000000
         (lambda (_) default-scratch))

  (bench 'old-declared-call-path 2000000
         (lambda (i)
           ;; 仿真旧路径：每次命中声明 ABI 都重复转换 scratch-def
           (define abi (if (even? i) (hash-ref declared-abis 'a) (hash-ref declared-abis 'b)))
           (abi->scratch-def abi)))

  (bench 'new-declared-call-path 2000000
         (lambda (i)
           (if (even? i) (hash-ref declared-scratch 'a) (hash-ref declared-scratch 'b))))

  (printf "\n=== infer-all-abis End-to-End ===\n")
  (define sparse-n 300)
  (define sparse-cfg (source->cfg (mk-ring-source sparse-n)))
  (printf "sparse graph: ~a functions, each has 1 static call + 1 dynamic call\n" sparse-n)
  (bench-infer-case 'infer-all-abis-sparse sparse-cfg 200)

  (define dense-n 120)
  (define dense-fanout 24)
  (define dense-cfg (source->cfg (mk-fanout-source dense-n dense-fanout)))
  (printf "dense graph: ~a functions, each has ~a static calls + 1 dynamic call\n"
          dense-n dense-fanout)
  (bench-infer-case 'infer-all-abis-dense dense-cfg 80)

  (printf "\n=== cross-cfg Function Summary Cache ===\n")
  (define clones
    (for/list ([i (in-range 40)])
      (source->cfg (mk-ring-source 300))))
  (printf "40 different cfg objects with identical source\n")
  (bench-cross-cfg-case 'infer-cross-cfg-no-reuse clones #:reset-each? #t)
  (clear-abi-infer-cache!)
  (bench-cross-cfg-case 'infer-cross-cfg-with-reuse clones))

(module+ main
  (main))
