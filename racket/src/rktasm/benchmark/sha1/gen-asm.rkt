#!/usr/bin/env racket
#lang racket

;; gen-asm.rkt - 从 DSL 生成 SHA1 汇编代码

(require "../../parser/frontend.rkt"
         "../../parser/ast.rkt"
         "../../semantic/control-flow.rkt"
         "../../semantic/inline.rkt"
         "../../pipeline/pipeline.rkt"
         "../../pipeline/regalloc/abi-config.rkt"
         "../../codegen/emit.rkt"
         racket/string)

(define default-source "../../example/000-neon-sha1.d")

(struct cli-config (use-apple? source-path symbol-prefix) #:transparent)

(define (usage)
  (displayln "Usage: racket gen-asm.rkt [--apple|-a] [--source PATH] [--prefix SYMBOL_PREFIX]")
  (displayln "  --source PATH     DSL 源文件 (默认 ../../example/000-neon-sha1.d)")
  (displayln "  --prefix PREFIX   给本文件所有函数名增加前缀 (含函数间调用)")
  (exit 2))

(define (parse-cli args)
  (let loop ([rest args]
             [use-apple? #f]
             [source-path default-source]
             [symbol-prefix ""])
    (match rest
      ['() (cli-config use-apple? source-path symbol-prefix)]
      [(list "--apple" tail ...) (loop tail #t source-path symbol-prefix)]
      [(list "-a" tail ...) (loop tail #t source-path symbol-prefix)]
      [(list "--source" path tail ...)
       (loop tail use-apple? path symbol-prefix)]
      [(list "--prefix" prefix tail ...)
       (loop tail use-apple? source-path prefix)]
      [_ (usage)])))

(define (collect-function-names items)
  (for/list ([item (in-list items)]
             #:when (and (ast-directive? item)
                         (eq? (ast-directive-kind item) 'function)
                         (symbol? (ast-directive-name item))))
    (ast-directive-name item)))

(define (build-rename-map fn-names prefix)
  (if (string=? prefix "")
      (hash)
      (for/hash ([name (in-list fn-names)])
        (values name
                (string->symbol (string-append prefix (symbol->string name)))))))

(define (rename-symbol sym rename-map)
  (hash-ref rename-map sym sym))

(define (rename-operand op rename-map)
  (match op
    [(ast-label name reloc loc)
     (ast-label (rename-symbol name rename-map) reloc loc)]
    [(ast-mem base offset mode shift extend loc)
     (ast-mem (rename-operand base rename-map)
              (and offset (rename-operand offset rename-map))
              mode shift extend loc)]
    [(ast-reglist regs loc)
     (ast-reglist (for/list ([r (in-list regs)])
                    (rename-operand r rename-map))
                  loc)]
    [_ op]))

(define (rename-item item rename-map)
  (match item
    [(ast-directive kind name args loc)
     (define new-name
       (if (and name (memq kind '(function global extern)))
           (rename-symbol name rename-map)
           name))
     (ast-directive kind new-name args loc)]
    [(ast-ins mnemonic suffix operands loc)
     (ast-ins mnemonic suffix
              (for/list ([op (in-list operands)])
                (rename-operand op rename-map))
              loc)]
    [_ item]))

(define (main args)
  (define cfg (parse-cli args))

  ;; 设置默认 ABI
  (default-abi-name 'aapcs64)

  (define source-content (file->string (cli-config-source-path cfg)))
  (define parsed (parse-string source-content))
  (when (parse-results-has-errors? parsed)
    (for ([e (in-list (parse-results-filter-errors parsed))])
      (define pe (parse-result-parse-error e))
      (eprintf "Parse error: ~a\n" (parse-error-message pe)))
    (exit 1))

  (define items
    (for/list ([r (in-list (parse-results-filter-ok parsed))])
      (parse-result-instruction r)))

  (define rename-map
    (build-rename-map (collect-function-names items)
                      (cli-config-symbol-prefix cfg)))

  (define renamed-items
    (if (zero? (hash-count rename-map))
        items
        (for/list ([item (in-list items)])
          (rename-item item rename-map))))

  (define built-cfg (expand-inline-cfg (build-cfg renamed-items)))

  (parameterize ([current-emit-config
                  (if (cli-config-use-apple? cfg)
                      apple-emit-config
                      default-emit-config)])
    (for ([i (in-range (cfg-function-count built-cfg))])
      (define fn (cfg-get-function built-cfg i))
      (displayln (emit-function/result (run-pipeline fn default-pipeline-config)))
      (newline))))

(main (vector->list (current-command-line-arguments)))
