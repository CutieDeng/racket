#lang racket/base

;; asm/gen/asm-equiv.rkt — 两个 .asm 的 AST 级对拍 (Phase F 迁移仪器)
;;
;; 用 asmp gnu-parser 解析两个 .asm, 剥 srcloc 后逐条比较。排版差异
;; (缩进/对齐/多行签名折行) 不影响判定; 任何语义可见的差异 (指令、
;; 操作数、指示) 逐条报出。迁移协议中的用途: 证明 Racket 发射器输出
;; 与退役 Python 生成器的已提交 .asm 语义相同 (Gate A 的 .asm 侧)。
;;
;; 用法: [RKTASM=<rktasm 路径>] racket asm/gen/asm-equiv.rkt old.asm new.asm
;; 退出码: 0 = AST 相同; 1 = 有差异 (已打印首个及计数)。

(require "gw.rkt")

(module+ main
  (define argv (current-command-line-arguments))
  (unless (= (vector-length argv) 2)
    (error 'asm-equiv "usage: racket asm/gen/asm-equiv.rkt <a.asm> <b.asm>"))
  (define fa (vector-ref argv 0))
  (define fb (vector-ref argv 1))
  (define ia (parse-gnu-file->items fa))
  (define ib (parse-gnu-file->items fb))
  (define na (length ia))
  (define nb (length ib))
  (cond
    [(equal? ia ib)
     (printf "EQUIV: ~a == ~a (~a AST items)\n" fa fb na)
     (exit 0)]
    [else
     (unless (= na nb)
       (printf "item count differs: ~a has ~a, ~a has ~a\n" fa na fb nb))
     (define shown
       (for/fold ([shown 0])
                 ([a (in-list ia)] [b (in-list ib)] [i (in-naturals)]
                  #:when (not (equal? a b))
                  #:final (>= shown 4))
         (printf "item ~a differs:\n  ~a: ~s\n  ~a: ~s\n" i fa a fb b)
         (add1 shown)))
     (define ndiff
       (for/sum ([a (in-list ia)] [b (in-list ib)])
         (if (equal? a b) 1 0)))
     (printf "NOT-EQUIV: ~a/~a paired items differ (+~a count skew)\n"
             (- (min na nb) ndiff) (min na nb) (abs (- na nb)))
     (exit 1)]))
