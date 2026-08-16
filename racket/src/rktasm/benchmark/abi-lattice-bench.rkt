#!/usr/bin/env racket
#lang racket

;; abi-lattice-bench.rkt
;;
;; 微基准：评估 ABI 偏序/格操作的开销，以及 ABI 配置加载（含 extends 约束检查）开销。
;;
;; 用法：
;;   racket benchmark/abi-lattice-bench.rkt

(require "../pipeline/regalloc/abi.rkt"
         "../pipeline/regalloc/abi-config.rkt")

(define (bench name iters thunk)
  (collect-garbage)
  (collect-garbage)
  (define t0 (current-inexact-milliseconds))
  (for ([i (in-range iters)])
    (thunk))
  (define t1 (current-inexact-milliseconds))
  (define ms (- t1 t0))
  (define ns/op (inexact->exact (round (* 1000000.0 (/ ms (max iters 1))))))
  (printf "~a: ~a iters, ~a ms, ~a ns/op\n" name iters ms ns/op))

(define (main)
  (abi-config-path "config/abi.rktd")
  (void (reload-abi-config))
  (default-abi-name 'aapcs64)

  (define a (get-abi-by-name 'aapcs64))
  (define b (get-abi-by-name 'leaf))
  (define c (get-abi-by-name 'naked))
  (unless (and a b c)
    (error 'abi-lattice-bench "缺少 ABI 配置: aapcs64/leaf/naked"))

  (printf "=== ABI Lattice Microbench ===\n")
  (bench 'abi->effect 5000000
         (lambda () (abi->effect a)))
  (bench 'abi<=? 3000000
         (lambda () (abi<=? a b)))

  (define ea (abi->effect a))
  (define eb (abi->effect b))
  (define ec (abi->effect c))
  (bench 'abi-effect<=? 5000000
         (lambda () (abi-effect<=? ea eb)))
  (bench 'meet 4000000
         (lambda () (abi-effect-meet eb ec)))
  (bench 'join 4000000
         (lambda () (abi-effect-join ea eb)))

  (printf "\n=== Config Load (includes extends lattice checks) ===\n")
  (define n-load 5000)
  ;; 非强制模式：文件未变化时命中缓存（mtime+size）
  (collect-garbage)
  (collect-garbage)
  (define t0 (current-inexact-milliseconds))
  (for ([i (in-range n-load)])
    (void (reload-abi-config "config/abi.rktd")))
  (define t1 (current-inexact-milliseconds))
  (define ms (- t1 t0))
  (printf "reload-abi-config (incremental): ~a iters, ~a ms, ~a us/op\n"
          n-load ms
          (real->double-flonum (* 1000.0 (/ ms n-load))))

  ;; 强制模式：每次都重新解析，作为上界参考
  (collect-garbage)
  (collect-garbage)
  (define t2 (current-inexact-milliseconds))
  (for ([i (in-range n-load)])
    (void (reload-abi-config "config/abi.rktd" #:force? #t)))
  (define t3 (current-inexact-milliseconds))
  (define ms-force (- t3 t2))
  (printf "reload-abi-config (force): ~a iters, ~a ms, ~a us/op\n"
          n-load ms-force
          (real->double-flonum (* 1000.0 (/ ms-force n-load)))))

(module+ main
  (main))
