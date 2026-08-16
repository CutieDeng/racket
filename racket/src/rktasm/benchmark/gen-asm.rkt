#!/usr/bin/env racket
#lang racket

;; gen-asm.rkt - 从 DSL 生成 SHA1 汇编代码

(require "../parser/frontend.rkt"
         "../parser/ast.rkt"
         "../semantic/control-flow.rkt"
         "../semantic/inline.rkt"
         "../pipeline/pipeline.rkt"
         "../pipeline/regalloc/abi-config.rkt"
         "../codegen/emit.rkt")

(define (main args)
  (define use-apple-config?
    (or (member "--apple" args)
        (member "-a" args)))

  ;; 设置默认 ABI
  (default-abi-name 'aapcs64)

  (define source (file->string "../example/000-neon-sha1.d"))
  (define results (parse-string source))
  (define items
    (for/list ([r (parse-results-items results)]
               #:when (parse-result-ok? r))
      (parse-result-instruction r)))
  (define cfg (expand-inline-cfg (build-cfg items)))

  (parameterize ([current-emit-config
                  (if use-apple-config? apple-emit-config default-emit-config)])
    (for ([i (in-range (cfg-function-count cfg))])
      (define fn (cfg-get-function cfg i))
      (displayln (emit-function/result (run-pipeline fn default-pipeline-config)))
      (newline))))

(main (vector->list (current-command-line-arguments)))
