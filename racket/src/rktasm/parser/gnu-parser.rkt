#lang racket

;; ============================================================
;; parser/gnu-parser.rkt - GNU-ish AArch64 frontend
;; ============================================================
;;
;; This parser is deliberately thin: it accepts traditional assembly syntax
;; and lowers it into the existing AST. All semantic checks still flow through
;; syntax/validator.rkt and the shared CFG/regalloc pipeline.

(require "ast.rkt"
         "parser.rkt"
         "comments.rkt"
         racket/string)

(provide
 make-gnu-state
 parse-gnu-line/state
 finish-gnu-state)

(struct gnu-state
  (in-function?
   current-function
   globals
   function-types
   pending-align
   section
   pending-inline-function
   pending-function
   pending-call)
  #:transparent)

(define (make-gnu-state)
  (gnu-state #f #f (set) (set) #f 'text #f #f #f))

(define (loc source line [column 0] [span 0])
  (srcloc source line column #f span))

;; 切分一行的代码与尾注释：返回 (values code comment-or-#f)。
;; comment 不含注释引导符（`;` 或 `//`），未去除首尾空白。
(define (split-comment s)
  (let loop ([i 0] [in-string? #f] [escaped? #f])
    (cond
      [(>= i (string-length s)) (values s #f)]
      [escaped? (loop (add1 i) in-string? #f)]
      [in-string?
       (define c (string-ref s i))
       (cond
         [(char=? c #\\) (loop (add1 i) #t #t)]
         [(char=? c #\") (loop (add1 i) #f #f)]
         [else (loop (add1 i) #t #f)])]
      [else
       (define c (string-ref s i))
       (cond
         [(char=? c #\") (loop (add1 i) #t #f)]
         [(char=? c #\;) (values (substring s 0 i) (substring s (add1 i)))]
         [(and (char=? c #\/)
               (< (add1 i) (string-length s))
               (char=? (string-ref s (add1 i)) #\/))
          (values (substring s 0 i) (substring s (+ i 2)))]
         [else (loop (add1 i) #f #f)])])))

(define (strip-comment s)
  (define-values (code _comment) (split-comment s))
  code)

(define (blank-or-comment? s)
  (string=? (string-trim (strip-comment s)) ""))

(define (trim-token s)
  (string-trim s))

(define (symbol-ci s)
  (string->symbol (string-downcase s)))

(define (valid-symbol-start? c)
  (or (char-alphabetic? c)
      (char=? c #\_)
      (char=? c #\.)
      (char=? c #\$)))

(define (valid-symbol-char? c)
  (or (valid-symbol-start? c)
      (char-numeric? c)))

(define (parse-symbol-token s)
  (define trimmed (string-trim s))
  (when (string=? trimmed "")
    (error 'gnu-parser "empty symbol"))
  (unless (valid-symbol-start? (string-ref trimmed 0))
    (error 'gnu-parser "invalid symbol: ~a" trimmed))
  (for ([c (in-string trimmed)])
    (unless (valid-symbol-char? c)
      (error 'gnu-parser "invalid symbol: ~a" trimmed)))
  (string->symbol trimmed))

(define managed-symbol-pattern
  #rx"^[A-Za-z_][A-Za-z0-9_$-]*(\\.[A-Za-z_][A-Za-z0-9_$-]*)*$")

(define managed-symbol-head-pattern
  #rx"^([A-Za-z_][A-Za-z0-9_$-]*(?:\\.[A-Za-z_][A-Za-z0-9_$-]*)*)(?:[ \t]+(.*))?$")

(define (parse-managed-symbol-token s what)
  (define trimmed (string-trim s))
  (unless (regexp-match? managed-symbol-pattern trimmed)
    (error 'gnu-parser
           "invalid ~a name: ~a (expected segment(.segment)*; segment starts with letter/_ and may contain -.$)"
           what
           trimmed))
  (string->symbol trimmed))

(define (parse-number-token s)
  (define trimmed0 (string-trim s))
  (define trimmed
    (if (string-prefix? trimmed0 "#")
        (substring trimmed0 1)
        trimmed0))
  (define normalized
    (cond
      [(regexp-match #rx"^([+-]?)0[xX]([0-9a-fA-F]+)$" trimmed)
       => (lambda (m)
            (string-append (cadr m) "#x" (caddr m)))]
      [else trimmed]))
  (define n (string->number normalized))
  (and (integer? n) n))

(define (gnu-reloc->ast kind text)
  (case (string->symbol (string-downcase kind))
    [(pg_hi21 page) 'PAGE]
    [(lo12 lo12_nc) 'PAGEOFF]
    [(got gotpage) 'GOTPAGE]
    [(got_lo12 got_lo12_nc gotpageoff) 'GOTPAGEOFF]
    [else
     (error 'gnu-parser
            "unsupported relocation modifier: ~a (supported: :pg_hi21:, :lo12:, :got:, :got_lo12:)"
            text)]))

(define (parse-label-token text label-loc)
  (define trimmed0 (string-trim text))
  ;; GAS commonly allows #:lo12:sym in immediate-looking operand positions.
  (define trimmed
    (if (string-prefix? trimmed0 "#:")
        (substring trimmed0 1)
        trimmed0))
  (cond
    [(regexp-match #rx"^:([A-Za-z_][A-Za-z0-9_]*):(.+)$" trimmed)
     => (lambda (m)
          (define reloc (gnu-reloc->ast (cadr m) trimmed))
          (define name (parse-symbol-token (caddr m)))
          (ast-label name reloc label-loc))]
    [(regexp-match #rx"^(.+)@(PAGE|PAGEOFF|GOTPAGE|GOTPAGEOFF)$" trimmed)
     => (lambda (m)
          (define name (parse-symbol-token (cadr m)))
          (ast-label name (string->symbol (caddr m)) label-loc))]
    [(or (string-prefix? trimmed ":")
         (regexp-match? #rx"@" trimmed))
     (error 'gnu-parser "invalid or unsupported relocation expression: ~a" text)]
    [else
     (ast-label (parse-symbol-token trimmed) #f label-loc)]))

(define (split-top-level s #:separator [separator #\,])
  (define parts '())
  (define current '())
  (define bracket-depth 0)
  (define brace-depth 0)
  (define in-string? #f)
  (define escaped? #f)
  (for ([c (in-string s)])
    (cond
      [escaped?
       (set! escaped? #f)
       (set! current (cons c current))]
      [in-string?
       (cond
         [(char=? c #\\)
          (set! escaped? #t)
          (set! current (cons c current))]
         [(char=? c #\")
          (set! in-string? #f)
          (set! current (cons c current))]
         [else
          (set! current (cons c current))])]
      [(char=? c #\")
       (set! in-string? #t)
       (set! current (cons c current))]
      [(char=? c #\[)
       (set! bracket-depth (add1 bracket-depth))
       (set! current (cons c current))]
      [(char=? c #\])
       (set! bracket-depth (sub1 bracket-depth))
       (set! current (cons c current))]
      [(char=? c #\{)
       (set! brace-depth (add1 brace-depth))
       (set! current (cons c current))]
      [(char=? c #\})
       (set! brace-depth (sub1 brace-depth))
       (set! current (cons c current))]
      [(and (char=? c separator)
            (= bracket-depth 0)
            (= brace-depth 0))
       (set! parts (cons (string-trim (list->string (reverse current))) parts))
       (set! current '())]
      [else
       (set! current (cons c current))]))
  (define tail (string-trim (list->string (reverse current))))
  (reverse (filter (lambda (part) (not (string=? part "")))
                   (cons tail parts))))

(define shift-keywords '(lsl lsr asr ror msl))
(define extend-keywords '(uxtb uxth uxtw uxtx sxtb sxth sxtw sxtx))
(define cond-keywords '(eq ne cs hs cc lo mi pl vs vc hi ls ge lt gt le al nv))

(define (parse-shift-or-extend text source line)
  (define pieces (regexp-split #rx"[ \t]+" (string-trim text)))
  (match pieces
    [(list kw)
     (define sym (symbol-ci kw))
     (cond
       [(memq sym shift-keywords) (list (ast-shift sym #f (loc source line)))]
       [(memq sym extend-keywords) (list (ast-extend sym #f (loc source line)))]
       [else #f])]
    [(list kw amount)
     (define sym (symbol-ci kw))
     (define n (parse-number-token amount))
     (and n
          (cond
            [(memq sym shift-keywords)
             (list (ast-shift sym #f (loc source line))
                   (ast-imm n (loc source line)))]
            [(memq sym extend-keywords)
             (list (ast-extend sym #f (loc source line))
                   (ast-imm n (loc source line)))]
            [else #f]))]
    [_ #f]))

(define (parse-memory-modifier text source line)
  (define pieces (regexp-split #rx"[ \t]+" (string-trim text)))
  (match pieces
    [(list kw)
     (define sym (symbol-ci kw))
     (cond
       [(memq sym shift-keywords) (values (ast-shift sym #f (loc source line)) #f)]
       [(memq sym extend-keywords) (values #f (ast-extend sym #f (loc source line)))]
       [else (error 'gnu-parser "invalid memory modifier: ~a" text)])]
    [(list kw amount)
     (define sym (symbol-ci kw))
     (define n (parse-number-token amount))
     (unless n
       (error 'gnu-parser "invalid memory modifier amount: ~a" amount))
     (cond
       [(memq sym shift-keywords) (values (ast-shift sym n (loc source line)) #f)]
       [(memq sym extend-keywords) (values #f (ast-extend sym n (loc source line)))]
       [else (error 'gnu-parser "invalid memory modifier: ~a" text)])]
    [_ (error 'gnu-parser "invalid memory modifier: ~a" text)]))

(define (parse-reg text source line)
  (or (try-parse-register (string->symbol (string-trim text)))
      (error 'gnu-parser "invalid register: ~a" text)))

(define (parse-memory text source line #:post-offset [post-offset #f])
  (define trimmed (string-trim text))
  (define pre? (string-suffix? trimmed "!"))
  (define body0 (if pre? (string-trim (substring trimmed 0 (sub1 (string-length trimmed)))) trimmed))
  (unless (and (string-prefix? body0 "[") (string-suffix? body0 "]"))
    (error 'gnu-parser "invalid memory operand: ~a" text))
  (define inner (substring body0 1 (sub1 (string-length body0))))
  (define parts (split-top-level inner))
  (when (null? parts)
    (error 'gnu-parser "memory operand needs a base register: ~a" text))
  (define base (parse-reg (car parts) source line))
  (define offset #f)
  (define shift #f)
  (define extend #f)
  (match (cdr parts)
    ['() (void)]
    [(list off)
     (define n (parse-number-token off))
     (set! offset
           (if n
               (ast-imm n (loc source line))
               (or (try-parse-register (string->symbol (string-trim off)))
                   (parse-label-token off (loc source line)))))]
    [(list off modifier)
     (set! offset (parse-reg off source line))
     (define-values (s e) (parse-memory-modifier modifier source line))
     (set! shift s)
     (set! extend e)]
    [(or (list off "mul" "vl")
         (list off "mul vl"))
     (set! offset (or (parse-number-token off)
                      (error 'gnu-parser "invalid SVE VL offset: ~a" off)))]
    [_
     (error 'gnu-parser "unsupported memory operand: ~a" text)])
  (cond
    [post-offset
     (ast-mem base (ast-imm post-offset (loc source line)) 'post shift extend (loc source line))]
    [pre?
     (ast-mem base offset 'pre shift extend (loc source line))]
    [else
     (ast-mem base offset 'offset shift extend (loc source line))]))

(define (parse-reglist text source line)
  (define trimmed (string-trim text))
  (unless (and (string-prefix? trimmed "{") (string-suffix? trimmed "}"))
    (error 'gnu-parser "invalid register list: ~a" text))
  (define inner (string-trim (substring trimmed 1 (sub1 (string-length trimmed)))))
  (define regs
    (apply append
           (for/list ([part (in-list (split-top-level inner))])
             (define range-parts (regexp-split #rx"[ \t]*-[ \t]*" part))
             (match range-parts
               [(list one)
                (list (parse-reg one source line))]
               [(list first last)
                (define r0 (parse-reg first source line))
                (define r1 (parse-reg last source line))
                (unless (and (eq? (ast-reg-kind r0) (ast-reg-kind r1))
                             (number? (ast-reg-id r0))
                             (number? (ast-reg-id r1))
                             (<= (ast-reg-id r0) (ast-reg-id r1)))
                  (error 'gnu-parser "invalid register range: ~a" part))
                (for/list ([i (in-range (ast-reg-id r0) (add1 (ast-reg-id r1)))])
                  (struct-copy ast-reg r0 [id i]))]
               [_ (error 'gnu-parser "invalid register list element: ~a" part)]))))
  (ast-reglist regs (loc source line)))

(define (parse-operand-piece text source line)
  (define trimmed (string-trim text))
  (cond
    [(string=? trimmed "") '()]
    [(string-prefix? trimmed "[")
     (list (parse-memory trimmed source line))]
    [(string-prefix? trimmed "{")
     (list (parse-reglist trimmed source line))]
    [(parse-shift-or-extend trimmed source line) => values]
    [else
     (define n (parse-number-token trimmed))
     (cond
       [n (list (ast-imm n (loc source line)))]
       [(try-parse-register (string->symbol trimmed))
        => (lambda (r) (list r))]
       [(member (symbol-ci trimmed) cond-keywords)
        (list (ast-cond (symbol-ci trimmed) (loc source line)))]
       [else
        (list (parse-label-token trimmed (loc source line)))])]))

(define (parse-operands text source line)
  (define raw-parts (if (string=? (string-trim text) "")
                        '()
                        (split-top-level text)))
  (let loop ([parts raw-parts] [out '()])
    (match parts
      ['() (reverse out)]
      [(cons part rest)
       (cond
         [(and (string-prefix? (string-trim part) "[")
               (not (string-suffix? (string-trim part) "!"))
               (pair? rest)
               (parse-number-token (car rest)))
          => (lambda (post)
               (loop (cdr rest)
                     (cons (parse-memory part source line #:post-offset post) out)))]
         [else
          (loop rest
                (append (reverse (parse-operand-piece part source line)) out))])])))

(define (parse-instruction-line text source line)
  (define m (regexp-match #rx"^([^ \t]+)(?:[ \t]+(.*))?$" (string-trim text)))
  (unless m
    (error 'gnu-parser "invalid instruction: ~a" text))
  (define-values (mnem suffix) (split-mnemonic (string->symbol (string-downcase (cadr m)))))
  (define operands (parse-operands (or (caddr m) "") source line))
  (ast-ins mnem suffix operands (loc source line)))

(define (parse-list-after-directive rest)
  (filter (lambda (s) (not (string=? s "")))
          (map string-trim (split-top-level rest))))

(define (parse-token-list-after-directive rest)
  (filter (lambda (s) (not (string=? s "")))
          (regexp-split #rx"[ \t,]+" (string-trim rest))))

(define (parse-string-literal text)
  (define trimmed (string-trim text))
  (unless (and (string-prefix? trimmed "\"")
               (string-suffix? trimmed "\""))
    (error 'gnu-parser "expected string literal: ~a" text))
  (with-handlers
    ([exn:fail?
      (lambda (_)
        (error 'gnu-parser "invalid string literal: ~a" text))])
    (define value (read (open-input-string trimmed)))
    (unless (string? value)
      (error 'gnu-parser "expected string literal: ~a" text))
    value))

(define (parse-string-list rest)
  (define parts (split-top-level rest))
  (when (null? parts)
    (error 'gnu-parser ".ascii/.asciz needs at least one string literal"))
  (map parse-string-literal parts))

(define (canonical-data-directive directive)
  (case (string->symbol (string-downcase directive))
    [(byte) 'byte]
    [(byte2 2byte short hword) 'byte2]
    [(byte4 4byte long word) 'byte4]
    [(byte8 8byte quad xword) 'byte8]
    [(byte16 octa) 'byte16]
    [(byte32) 'byte32]
    [else #f]))

(define (data-directive-width kind)
  (case kind
    [(byte) 1]
    [(byte2) 2]
    [(byte4) 4]
    [(byte8) 8]
    [(byte16) 16]
    [(byte32) 32]
    [else (error 'gnu-parser "unknown data directive: ~a" kind)]))

(define (symbol-data-width-supported? kind)
  (<= (data-directive-width kind) 8))

(define (data-integer-range-ok? kind n)
  (define bits (* 8 (data-directive-width kind)))
  (<= (- (expt 2 (sub1 bits))) n (sub1 (expt 2 bits))))

(define (parse-data-value kind text source line)
  (define trimmed (string-trim text))
  (when (and (string-prefix? trimmed "\"")
             (string-suffix? trimmed "\""))
    (error 'gnu-parser ".~a expects integers or label expressions; use .ascii/.asciz for strings" kind))
  (define n (parse-number-token trimmed))
  (cond
    [n
     (unless (data-integer-range-ok? kind n)
       (error 'gnu-parser ".~a integer out of range: ~a" kind n))
     n]
    [else
     (unless (symbol-data-width-supported? kind)
       (error 'gnu-parser ".~a supports integer values only; symbolic data is supported up to .byte8" kind))
     (parse-label-token trimmed (loc source line))]))

(define (parse-data-values kind rest source line)
  (define parts (split-top-level rest))
  (when (null? parts)
    (error 'gnu-parser ".~a needs at least one value" kind))
  (map (lambda (part) (parse-data-value kind part source line))
       parts))

(define (section-kind name)
  (define s (string-downcase (format "~a" name)))
  (cond
    [(regexp-match? #rx"(^|[ \t,])\\.text($|[ \t,])" s) 'text]
    [else 'data]))

(define (parse-asmp-attrs parts)
  (for/hash ([part (in-list parts)])
    (define pieces (regexp-split #rx"=" part))
    (match pieces
      [(list key value)
       (values (string->symbol (string-downcase (string-trim key)))
               (string->symbol (string-trim value)))]
      [(list key)
       (values (string->symbol (string-downcase (string-trim key))) #t)]
      [_ (error 'gnu-parser "invalid .asmp.function attribute: ~a" part)])))

(define (asmp-extern-args attrs)
  (define kind
    (cond
      [(eq? (hash-ref attrs 'kind #f) 'var) 'var]
      [(hash-ref attrs 'var #f) 'var]
      [else 'func]))
  (define abi-name (hash-ref attrs 'abi #f))
  (filter values
          (list kind
                (and abi-name (list 'abi abi-name)))))

(define (parse-named-binding kind part source line)
  (define m (regexp-match #rx"^([^=]+)=(.+)$" part))
  (if m
      (let ([formal (string-trim (cadr m))]
            [actual (string-trim (caddr m))])
        (define formal-reg (parse-reg formal source line))
        (unless (symbol? (ast-reg-id formal-reg))
          (error 'gnu-parser ".~a binding formal must be virtual: ~a" kind formal))
        (list formal-reg (parse-reg actual source line)))
      (error 'gnu-parser "invalid .~a binding: ~a" kind part)))

(define (parse-inline-binding part source line)
  (parse-named-binding "inline" part source line))

(define (parse-inline-bindings parts source line)
  (for/list ([part (in-list parts)])
    (parse-inline-binding part source line)))

(define (parse-call-bindings parts source line)
  (for/list ([part (in-list parts)])
    (parse-named-binding "call" part source line)))

(define (split-call-options arg-text source line)
  (let loop ([text (string-trim arg-text)] [attrs (hash)])
    (cond
      [(regexp-match #rx"^(abi|variant|version|feature)=([^ \t()]+)[ \t]*(.*)$" text)
       => (lambda (m)
            (define key (string->symbol (cadr m)))
            (define value (caddr m))
            (define attr-key
              (case key
                [(abi) 'abi]
                [(variant version) 'variant-id]
                [(feature) 'target-feature]))
            (define what
              (case key
                [(abi) "call ABI"]
                [(variant version) "call variant"]
                [(feature) "call target feature"]))
            (define parsed
              (parse-managed-symbol-token value what))
            (loop (string-trim (cadddr m))
                  (hash-set attrs attr-key parsed)))]
      [else (values attrs text)])))

(define (call-directive-args bindings attrs)
  (if (zero? (hash-count attrs))
      bindings
      (hash-set attrs 'bindings bindings)))

(define (parse-paren-list text what)
  (define trimmed (string-trim text))
  (unless (and (string-prefix? trimmed "(")
               (string-suffix? trimmed ")"))
    (error 'gnu-parser "~a must use (...) syntax: ~a" what text))
  (split-top-level (substring trimmed 1 (sub1 (string-length trimmed)))))

(define (parse-inline-call rest source line)
  (define m (regexp-match managed-symbol-head-pattern rest))
  (unless m
    (error 'gnu-parser ".inline needs a target"))
  (define target (parse-managed-symbol-token (cadr m) "inline target"))
  (define arg-text (string-trim (or (caddr m) "")))
  (define parts (parse-paren-list arg-text ".inline arguments"))
  (values target (parse-inline-bindings parts source line)))

(define (parse-call rest source line)
  (define m (regexp-match managed-symbol-head-pattern rest))
  (unless m
    (error 'gnu-parser ".call needs a target"))
  (define target (parse-managed-symbol-token (cadr m) "call target"))
  (define arg-text (string-trim (or (caddr m) "")))
  (define-values (attrs paren-text) (split-call-options arg-text source line))
  (define parts (parse-paren-list paren-text ".call arguments"))
  (values target (call-directive-args (parse-call-bindings parts source line) attrs)))

(define (make-call-item target arg-text source line)
  (define-values (attrs paren-text) (split-call-options arg-text source line))
  (define parts (parse-paren-list paren-text ".call arguments"))
  (ast-directive 'call
                 target
                 (call-directive-args (parse-call-bindings parts source line) attrs)
                 (loc source line)))

(define (parse-call-start rest source line st)
  (define m (regexp-match managed-symbol-head-pattern rest))
  (unless m
    (error 'gnu-parser ".call needs a target"))
  (define target (parse-managed-symbol-token (cadr m) "call target"))
  (define arg-text (string-trim (or (caddr m) "")))
  (cond
    [(inline-signature-complete? arg-text)
     (values (list (make-call-item target arg-text source line)) st)]
    [else
     (values '()
             (struct-copy gnu-state st
                          [pending-call (list target (list arg-text) line)]))]))

(define (continue-call text source line st)
  (match (gnu-state-pending-call st)
    [(list target pieces start-line)
     (define pieces* (append pieces (list text)))
     (define arg-text (string-join pieces* " "))
     (if (inline-signature-complete? arg-text)
         (values (list (make-call-item target arg-text source start-line))
                 (struct-copy gnu-state st [pending-call #f]))
         (values '()
                 (struct-copy gnu-state st
                              [pending-call (list target pieces* start-line)])))]))

;; ============================================================
;; .context 声明解析
;; ============================================================
;;
;; 语法: .context NAME  field=reg  field=reg ...
;;   NAME  : 命名上下文标识
;;   field : 上下文字段名 (虚拟寄存器名, 如 a0/acc0)
;;   reg   : 物理寄存器 (x4/x14/w0 等)
;;
;; 产出 (ast-directive 'context NAME field-map loc), 其中 field-map 为
;; assoc-list: (listof (cons field-symbol phys-ast-reg))。
;; 该 directive 由 semantic/apply-contexts.rkt 在 CFG 构建前消费并剥离。

(define (parse-context-field tok source line)
  (define mm (regexp-match #rx"^([A-Za-z_][A-Za-z0-9_]*)=(.+)$" tok))
  (unless mm
    (error 'gnu-parser
           "invalid .context field mapping: ~a (expected field=reg)" tok))
  (define field (string->symbol (cadr mm)))
  (define reg (parse-reg (caddr mm) source line))
  (unless (number? (ast-reg-id reg))
    (error 'gnu-parser
           ".context field ~a must map to a physical register, got: ~a"
           field (caddr mm)))
  (cons field reg))

(define (parse-context-fields body source line name)
  (define tokens
    (filter (lambda (s) (not (string=? s "")))
            (regexp-split #rx"[ \t,]+" (string-trim body))))
  (when (null? tokens)
    (error 'gnu-parser
           ".context ~a needs at least one field=reg mapping" name))
  (for/list ([tok (in-list tokens)])
    (parse-context-field tok source line)))

(define (parse-context-directive rest source line)
  (define m (regexp-match managed-symbol-head-pattern rest))
  (unless m
    (error 'gnu-parser ".context needs a name"))
  (define name (parse-managed-symbol-token (cadr m) "context"))
  (define body0 (string-trim (or (caddr m) "")))
  ;; 可选前导 (scope library|process|signal [reserve=...])。默认 library。
  ;; scope 与"寄存器如何映射"(field=reg)正交, 见 docs §3.4。
  (define-values (scope body)
    (let ([sm (regexp-match #px"^\\(scope[ \t]+([a-z]+)[^)]*\\)[ \t]*(.*)$" body0)])
      (if sm
          (let ([sc (string->symbol (cadr sm))])
            (unless (memq sc '(library process signal))
              (error 'gnu-parser
                     ".context ~a: 未知 scope '~a' (须 library/process/signal)" name sc))
            (values sc (string-trim (caddr sm))))
          (values 'library body0))))
  ;; args = (list scope field-map-assoc); apply-contexts 消费。
  (ast-directive 'context name
                 (list scope (parse-context-fields body source line name))
                 (loc source line)))

(define (make-inline-param mode reg-text source line)
  (define reg (parse-reg reg-text source line))
  (unless (symbol? (ast-reg-id reg))
    (error 'gnu-parser "inline parameter must be virtual: ~a" reg-text))
  (list mode reg))

(define (parse-inline-param-piece part current-mode source line)
  (define trimmed (string-trim part))
  (cond
    [(regexp-match #rx"^(inout|in|out)[ \t]*:[ \t]*(.*)$" trimmed)
     => (lambda (m)
          (define mode (string->symbol (cadr m)))
          (define rest (string-trim (caddr m)))
          (values (if (string=? rest "")
                      '()
                      (list (make-inline-param mode rest source line)))
                  mode))]
    [(regexp-match #rx"^(inout|in|out)[ \t]+(.+)$" trimmed)
     => (lambda (m)
          (define mode (string->symbol (cadr m)))
          (values (list (make-inline-param mode (caddr m) source line))
                  mode))]
    [current-mode
     (values (list (make-inline-param current-mode trimmed source line))
             current-mode)]
    [else
     (error 'gnu-parser "invalid inline parameter: ~a" part)]))

(define (parse-inline-params/parts parts source line)
  (let loop ([parts parts]
             [current-mode #f]
             [out '()])
    (match parts
      ['() (reverse out)]
      [(cons part rest)
       (define-values (params next-mode)
         (parse-inline-param-piece part current-mode source line))
       (loop rest next-mode (append (reverse params) out))])))

(define (parse-inline-params text source line)
  (parse-inline-params/parts (parse-paren-list text ".function signature")
                             source line))

;; ----------------------------------------------------------------
;; .function 签名里的 (context NAME ...) 条目
;; ----------------------------------------------------------------
;; 签名 (逗号分隔) 中形如 `context NAME [NAME ...]` 的条目声明该函数 import
;; 一个或多个上下文 (见 .context)。它们不是调用参数, 从参数列表剥离后单独
;; 记入函数 attrs 的 'contexts 键。

(define (signature-context-part? part)
  (regexp-match? #rx"^context([ \t]|$)" (string-trim part)))

(define (signature-context-names parts)
  (append*
   (for/list ([part (in-list parts)]
              #:when (signature-context-part? part))
     (define m (regexp-match #rx"^context[ \t]+(.*)$" (string-trim part)))
     (define names-text (if m (string-trim (cadr m)) ""))
     (define names
       (filter (lambda (s) (not (string=? s "")))
               (regexp-split #rx"[ \t,]+" names-text)))
     (when (null? names)
       (error 'gnu-parser ".function (context ...) needs a context name"))
     (map string->symbol names))))

(define (signature-param-parts parts)
  (filter (lambda (part) (not (signature-context-part? part))) parts))

;; 把签名文本切成 (values 括号部分 括号后尾随属性)。
;; 支持 `.function foo (context c, in: x.a) export` —— 括号后的 `export`
;; 作为额外属性并回 attrs-text。若无匹配右括号则整体视为括号部分。
(define (split-signature-trailing signature-text)
  (define s (string-trim signature-text))
  (define open (for/first ([i (in-range (string-length s))]
                           #:when (char=? (string-ref s i) #\())
                 i))
  (cond
    [(not open) (values s "")]
    [else
     (define close
       (let loop ([i open] [depth 0])
         (cond
           [(>= i (string-length s)) #f]
           [(char=? (string-ref s i) #\() (loop (add1 i) (add1 depth))]
           [(char=? (string-ref s i) #\))
            (if (= depth 1) i (loop (add1 i) (sub1 depth)))]
           [else (loop (add1 i) depth)])))
     (if close
         (values (substring s open (add1 close))
                 (string-trim (substring s (add1 close))))
         (values (substring s open) ""))]))

(define (parse-function-params text source line)
  (parse-inline-params text source line))

(define (inline-signature-complete? text)
  (and (regexp-match? #rx"\\(" text)
       (regexp-match? #rx"\\)" text)))

(define (make-inline-function-items name signature-text source line pending-align close?)
  (define params (parse-inline-params signature-text source line))
  (define attrs0 (hash 'inline-only #t
                       'inline-params params))
  (define attrs (if pending-align
                    (hash-set attrs0 'align pending-align)
                    attrs0))
  (append (if close?
              (list (ast-directive 'end-function #f '() (loc source line)))
              '())
          (list (ast-directive 'function name attrs (loc source line)))))

(define (parse-function-attrs text)
  (for/fold ([attrs (hash)])
            ([part (in-list (filter (lambda (s) (not (string=? s "")))
                                    (regexp-split #rx"[ \t]+" (string-trim text))))])
    (cond
      [(regexp-match #rx"^([^=]+)=(.+)$" part)
       => (lambda (m)
            (define key (string->symbol (string-downcase (string-trim (cadr m)))))
            (define value (string-trim (caddr m)))
            (case key
              [(profile)
               (hash-set attrs 'profile
                         (parse-managed-symbol-token value ".function profile"))]
              [(abi)
               (hash-set attrs 'abi
                         (parse-managed-symbol-token value ".function ABI"))]
              [(variant-of logical logical-name)
               (hash-set attrs 'variant-of
                         (parse-managed-symbol-token value ".function variant-of"))]
              [(version version-id)
               (hash-set attrs 'version-id
                         (parse-managed-symbol-token value ".function version"))]
              [(feature target target-feature)
               (hash-set attrs 'target-feature
                         (parse-managed-symbol-token value ".function target feature"))]
              [(visibility)
               (hash-set attrs 'visibility
                         (string->symbol (string-downcase value)))]
              [(binding)
               (hash-set attrs 'binding
                         (string->symbol (string-downcase value)))]
              [(header)
               (hash-set attrs 'header
                         (string->symbol (string-downcase value)))]
              [else
               (error 'gnu-parser "invalid .function attribute: ~a" part)]))]
      [else
       (case (string->symbol (string-downcase part))
         [(export) (hash-set attrs 'export #t)]
         [(weak) (hash-set attrs 'binding 'weak)]
         [(header) (hash-set attrs 'header #t)]
         [(no-header noheader) (hash-set attrs 'no-header #t)]
         [else (error 'gnu-parser "invalid .function attribute: ~a" part)])])))

(define (split-function-attrs/signature text)
  (define trimmed (string-trim text))
  (define open-pos
    (for/first ([i (in-range (string-length trimmed))]
                #:when (char=? (string-ref trimmed i) #\())
      i))
  (if open-pos
      (values (string-trim (substring trimmed 0 open-pos))
              (string-trim (substring trimmed open-pos)))
      (values trimmed "()")))

(define (make-function-items name attrs-text signature-text source line pending-align)
  ;; 括号后的尾随属性 (如 `(context c) export`) 并入 attrs-text
  (define-values (paren-text trailing-attrs) (split-signature-trailing signature-text))
  (define full-attrs-text
    (string-trim (string-append (string-trim attrs-text) " " trailing-attrs)))
  (define parts (parse-paren-list paren-text ".function signature"))
  (define contexts (signature-context-names parts))
  (define params (parse-inline-params/parts (signature-param-parts parts) source line))
  (define base-attrs (hash-set (parse-function-attrs full-attrs-text)
                               'function-params
                               params))
  (define attrs0 (if (null? contexts)
                     base-attrs
                     (hash-set base-attrs 'contexts contexts)))
  (define attrs (if pending-align
                    (hash-set attrs0 'align pending-align)
                    attrs0))
  (list (ast-directive 'function name attrs (loc source line))))

(define (parse-function-start rest source line st)
  (when (gnu-state-in-function? st)
    (error 'gnu-parser ".function cannot start before .end"))
  (define m (regexp-match managed-symbol-head-pattern rest))
  (unless m
    (error 'gnu-parser ".function needs a name"))
  (define name (parse-managed-symbol-token (cadr m) "function"))
  (define tail (string-trim (or (caddr m) "")))
  (define-values (attrs-text signature-text) (split-function-attrs/signature tail))
  (cond
    [(inline-signature-complete? signature-text)
     (values (make-function-items name attrs-text signature-text source line (gnu-state-pending-align st))
             (struct-copy gnu-state st
                          [in-function? #t]
                          [current-function name]
                          [pending-align #f]))]
    [else
     (values '()
             (struct-copy gnu-state st
                          [pending-align #f]
                          [pending-function
                           (list name attrs-text (list signature-text) line (gnu-state-pending-align st))]))]))

(define (continue-function-signature text source line st)
  (match (gnu-state-pending-function st)
    [(list name attrs-text pieces start-line pending-align)
     (define pieces* (append pieces (list text)))
     (define signature-text (string-join pieces* " "))
     (if (inline-signature-complete? signature-text)
         (values (make-function-items name attrs-text signature-text source start-line pending-align)
                 (struct-copy gnu-state st
                              [in-function? #t]
                              [current-function name]
                              [pending-function #f]))
         (values '()
                 (struct-copy gnu-state st
                              [pending-function
                               (list name attrs-text pieces* start-line pending-align)])))]))

(define (parse-inline-function-start rest source line st)
  (define m (regexp-match managed-symbol-head-pattern rest))
  (unless m
    (error 'gnu-parser ".inline-function needs a name"))
  (define name (parse-managed-symbol-token (cadr m) "inline function"))
  (define signature-text (string-trim (or (caddr m) "()")))
  (define close? (gnu-state-in-function? st))
  (cond
    [(inline-signature-complete? signature-text)
     (values (make-inline-function-items name signature-text source line (gnu-state-pending-align st) close?)
             (struct-copy gnu-state st
                          [in-function? #t]
                          [current-function name]
                          [pending-align #f]))]
    [else
     (values (if close?
                 (list (ast-directive 'end-function #f '() (loc source line)))
                 '())
             (struct-copy gnu-state st
                          [in-function? #f]
                          [current-function #f]
                          [pending-align #f]
                          [pending-inline-function
                           (list name (list signature-text) line (gnu-state-pending-align st))]))]))

(define (continue-inline-function-signature text source line st)
  (match (gnu-state-pending-inline-function st)
    [(list name pieces start-line pending-align)
     (define pieces* (append pieces (list text)))
     (define signature-text (string-join pieces* " "))
     (if (inline-signature-complete? signature-text)
         (values (make-inline-function-items name signature-text source start-line pending-align #f)
                 (struct-copy gnu-state st
                              [in-function? #t]
                              [current-function name]
                              [pending-inline-function #f]))
         (values '()
                 (struct-copy gnu-state st
                              [pending-inline-function
                               (list name pieces* start-line pending-align)])))]))

(define (function-start-label? label st)
  (define local-label?
    (string-prefix? (symbol->string label) "."))
  (and (eq? (gnu-state-section st) 'text)
       (or (set-member? (gnu-state-globals st) label)
           (set-member? (gnu-state-function-types st) label)
           (and (not (gnu-state-in-function? st))
                (not local-label?)))))

(define (start-function-items label st source line)
  (define attrs0
    (if (set-member? (gnu-state-globals st) label)
        (hash 'export #t)
        (hash)))
  (define attrs
    (if (gnu-state-pending-align st)
        (hash-set attrs0 'align (gnu-state-pending-align st))
        attrs0))
  (define close (if (gnu-state-in-function? st)
                    (list (ast-directive 'end-function #f '() (loc source line)))
                    '()))
  (define items
    (append close
            (list (ast-directive 'function label attrs (loc source line))
                  (ast-directive 'label label '() (loc source line)))))
  (values items
          (struct-copy gnu-state st
                       [in-function? #t]
                       [current-function label]
                       [pending-align #f])))

(define (parse-directive text source line st)
  (define m (regexp-match #rx"^\\.([^ \t]+)(?:[ \t]+(.*))?$" text))
  (unless m
    (error 'gnu-parser "invalid directive: ~a" text))
  (define directive (string-downcase (cadr m)))
  (define rest (string-trim (or (caddr m) "")))
  (match directive
    ["text"
     (values '() (struct-copy gnu-state st [section 'text]))]
    ["data"
     (values (list (ast-directive 'section ".data" '() (loc source line)))
             (struct-copy gnu-state st [section 'data]))]
    ["section"
     (define name (if (string=? rest "") ".text" rest))
     (define section (section-kind name))
     (values (if (eq? section 'text)
                 '()
                 (list (ast-directive 'section name '() (loc source line))))
             (struct-copy gnu-state st [section section]))]
    [(or "globl" "global")
     (define names (map parse-symbol-token (parse-token-list-after-directive rest)))
     (values (for/list ([name (in-list names)])
               (ast-directive 'global name '() (loc source line)))
             (struct-copy gnu-state st
                          [globals (for/fold ([s (gnu-state-globals st)])
                                              ([name (in-list names)])
                                     (set-add s name))]))]
    ["extern"
     (define names (map parse-symbol-token (parse-token-list-after-directive rest)))
     (values (for/list ([name (in-list names)])
               (ast-directive 'extern name '(func) (loc source line)))
             st)]
    ["type"
     (define parts (parse-list-after-directive rest))
     (if (and (>= (length parts) 2)
              (regexp-match? #rx"%?function$" (cadr parts)))
         (values '()
                 (struct-copy gnu-state st
                              [function-types
                               (set-add (gnu-state-function-types st)
                                        (parse-symbol-token (car parts)))]))
         (values '() st))]
    ["size"
     (define parts (parse-list-after-directive rest))
     (define maybe-name (and (pair? parts) (parse-symbol-token (car parts))))
     (if (and (gnu-state-in-function? st)
              maybe-name
              (eq? maybe-name (gnu-state-current-function st)))
         (values (list (ast-directive 'end-function #f '() (loc source line)))
                 (struct-copy gnu-state st [in-function? #f] [current-function #f]))
         (values '() st))]
    [(or "p2align" "align")
     (define n (parse-number-token (car (parse-list-after-directive rest))))
     (unless n
       (error 'gnu-parser "invalid alignment: ~a" rest))
     (cond
       [(gnu-state-in-function? st)
        (values (list (ast-directive 'align #f (list n) (loc source line))) st)]
       [(eq? (gnu-state-section st) 'text)
        (values '() (struct-copy gnu-state st [pending-align n]))]
       [else
        (values (list (ast-directive 'align #f (list n) (loc source line))) st)])]
    ["asmp.function"
     (define parts (parse-token-list-after-directive rest))
     (when (null? parts)
       (error 'gnu-parser ".asmp.function needs a name"))
     (define name (parse-managed-symbol-token (car parts) "function"))
     (define attrs0 (parse-asmp-attrs (cdr parts)))
     (define attrs (if (gnu-state-pending-align st)
                       (hash-set attrs0 'align (gnu-state-pending-align st))
                       attrs0))
     (define close (if (gnu-state-in-function? st)
                       (list (ast-directive 'end-function #f '() (loc source line)))
                       '()))
     (values (append close (list (ast-directive 'function name attrs (loc source line))))
             (struct-copy gnu-state st
                          [in-function? #t]
                          [current-function name]
                          [pending-align #f]))]
    ["function"
     (parse-function-start rest source line st)]
    ["inline-function"
     (parse-inline-function-start rest source line st)]
    [(or "asmp.end_function" "asmp.end-function")
     (if (gnu-state-in-function? st)
         (values (list (ast-directive 'end-function #f '() (loc source line)))
                 (struct-copy gnu-state st [in-function? #f] [current-function #f]))
         (values '() st))]
    ["end"
     (cond
       [(gnu-state-pending-inline-function st)
        (error 'gnu-parser ".end before closing .inline-function signature")]
       [(gnu-state-in-function? st)
        (values (list (ast-directive 'end-function #f '() (loc source line)))
                (struct-copy gnu-state st [in-function? #f] [current-function #f]))]
       [else (values '() st)])]
    [(or "inline" "asmp.inline")
     (define-values (target bindings) (parse-inline-call rest source line))
     (values (list (ast-directive 'inline
                                   target
                                   bindings
                                   (loc source line)))
             st)]
    ["call"
     (parse-call-start rest source line st)]
    ["context"
     (values (list (parse-context-directive rest source line)) st)]
    ["return"
     (values (list (ast-ins 'ret #f '() (loc source line))) st)]
    ["clobber"
     ;; 语法预留：尚无语义。显式告警，避免"写了以为生效"
     (eprintf "gnu-parser: 警告: ~a:~a: .clobber 未实现，已忽略\n" source line)
     (values '() st)]
    [(or "frame" "asmp.frame")
     ;; .frame [N]  —— 建立 x29 为真帧指针 (在 .save 前导保存 x29/x30 之后发射
     ;; `add x29, sp, #0`), 并可选保留 N 字节 FP-relative 本地槽 (在 callee-saved
     ;; 区之上)。须与 .save 搭配; 由 save-load 管线在前导展开点消费。
     (values (list (parse-frame-directive rest source line)) st)]
    [(or "alloca" "asmp.alloca")
     ;; .alloca xN [, k]  —— 变长栈分配, 发射 `sub sp, sp, xN, lsl #k` (k 默认 0)。
     ;; 须先有 .frame (由 fp 在 epilogue 前 `mov sp, x29` 复原 sp)。
     (values (list (parse-alloca-directive rest source line)) st)]
    ["asmp.extern"
     (define parts (parse-token-list-after-directive rest))
     (when (null? parts)
       (error 'gnu-parser ".asmp.extern needs a name"))
     (define name (parse-symbol-token (car parts)))
     (define attrs (parse-asmp-attrs (cdr parts)))
     (values (list (ast-directive 'extern name (asmp-extern-args attrs) (loc source line))) st)]
    [(or "save" "asmp.save")
     (values (list (parse-save-load-directive 'save! rest source line)) st)]
    [(or "load" "restore" "asmp.load" "asmp.restore")
     (values (list (parse-save-load-directive 'load! rest source line)) st)]
    ["ascii"
     (values (list (ast-directive 'ascii #f (parse-string-list rest) (loc source line))) st)]
    ["asciz"
     (values (list (ast-directive 'asciz #f (parse-string-list rest) (loc source line))) st)]
    ["byte"
     (values (list (ast-directive 'byte #f (parse-data-values 'byte rest source line) (loc source line))) st)]
    [_
     (define data-kind (canonical-data-directive directive))
     (if data-kind
         (values (list (ast-directive data-kind #f (parse-data-values data-kind rest source line) (loc source line))) st)
         (values '() st))]))

;; .frame [N]  -> (ast-directive 'frame #f (list local-bytes) loc)
;;   local-bytes: 保留的 FP-relative 本地槽字节数 (无参数则 0)
(define (parse-frame-directive rest source line)
  (define trimmed (string-trim rest))
  (define local-bytes
    (cond
      [(string=? trimmed "") 0]
      [(parse-number-token trimmed) => values]
      [else (error 'gnu-parser "~a:~a: .frame 参数须为字节数, 得: ~a"
                   source line trimmed)]))
  (when (negative? local-bytes)
    (error 'gnu-parser "~a:~a: .frame 本地字节数不能为负: ~a" source line local-bytes))
  (ast-directive 'frame #f (list local-bytes) (loc source line)))

;; .alloca xN [, k]  -> (ast-directive 'alloca #f (list reg shift) loc)
;;   发射 `sub sp, sp, xN, lsl #k`; shift k 默认 0
(define (parse-alloca-directive rest source line)
  (define parts (filter (lambda (s) (not (string=? s "")))
                        (regexp-split #rx"[ \t,]+" (string-trim rest))))
  (when (null? parts)
    (error 'gnu-parser "~a:~a: .alloca 需要一个寄存器操作数" source line))
  (define reg (parse-reg (car parts) source line))
  (unless (and (memq (ast-reg-kind reg) '(x w)) (number? (ast-reg-id reg)))
    (error 'gnu-parser "~a:~a: .alloca 操作数须为物理 GPR, 得: ~a" source line (car parts)))
  (define shift
    (cond
      [(null? (cdr parts)) 0]
      [(parse-number-token (cadr parts)) => values]
      [else (error 'gnu-parser "~a:~a: .alloca 移位量须为整数, 得: ~a"
                   source line (cadr parts))]))
  (unless (<= 0 shift 4)
    (error 'gnu-parser "~a:~a: .alloca lsl 移位量须在 [0,4]: ~a" source line shift))
  (ast-directive 'alloca #f (list reg shift) (loc source line)))

(define (parse-save-load-directive kind rest source line)
  (define parts (regexp-split #rx"[ \t,]+" (string-trim rest)))
  (cond
    [(equal? parts '("all"))
     (ast-directive kind #f (list 'all (list 'auto)) (loc source line))]
    [else
     (define regs (map (lambda (p) (parse-reg p source line)) parts))
     (ast-directive kind #f (list regs (list 'unlimited)) (loc source line))]))

(define (parse-label-prefix text source line st)
  (let loop ([remaining (string-trim text)] [items '()] [state st])
    (define m (regexp-match #rx"^([A-Za-z_.$][A-Za-z0-9_.$]*):(.*)$" remaining))
    (if (not m)
        (values (reverse items) remaining state)
        (let* ([label (string->symbol (cadr m))]
               [rest (string-trim (caddr m))])
          (define-values (new-items new-state)
            (if (function-start-label? label state)
                (start-function-items label state source line)
                (values (list (ast-directive 'label label '() (loc source line))) state)))
          (loop rest (append (reverse new-items) items) new-state)))))

(define (parse-gnu-line/state line-text source line-number state)
  ;; 尾注释记入侧表（--keep-comments 时 emit 阶段重新附着到指令）
  (let-values ([(_code comment) (split-comment line-text)])
    (when comment
      (record-source-comment! source line-number comment)))
  (if (blank-or-comment? line-text)
      (values '() state)
      (let* ([without-comment (strip-comment line-text)]
             [text (string-trim without-comment)])
        (if (gnu-state-pending-call state)
            (continue-call text source line-number state)
            (if (gnu-state-pending-function state)
                (continue-function-signature text source line-number state)
                (if (gnu-state-pending-inline-function state)
                    (continue-inline-function-signature text source line-number state)
            (let ()
              (define-values (label-items rest state-after-labels)
                (parse-label-prefix text source line-number state))
              (cond
                [(string=? rest "")
                 (values label-items state-after-labels)]
                [(string-prefix? rest ".")
                 (define-values (directive-items state-after-directive)
                   (parse-directive rest source line-number state-after-labels))
                 (values (append label-items directive-items) state-after-directive)]
                [else
                 (values (append label-items
                                 (list (parse-instruction-line rest source line-number)))
                         state-after-labels)]))))))))

(define (finish-gnu-state state source line-number)
  (cond
    [(gnu-state-pending-call state)
     (error 'gnu-parser "unterminated .call arguments")]
    [(gnu-state-pending-function state)
     (error 'gnu-parser "unterminated .function signature")]
    [(gnu-state-pending-inline-function state)
     (error 'gnu-parser "unterminated .inline-function signature")]
    [(gnu-state-in-function? state)
     (list (ast-directive 'end-function #f '() (loc source line-number)))]
    [else '()]))
