#lang racket/base
;; parser/unroll.rkt — compile-time loop unrolling for the GNU/.asm frontend.
;;
;; A pure line-level source-to-source pass that runs BEFORE gnu-parser, so the
;; parser / semantic / regalloc layers never see `.for`. It expands:
;;
;;   .for <var>, <lo>, <hi>        ; var = lo, lo+1, ..., hi-1  (half-open)
;;     <body>                      ; ${expr} -> compile-time integer value
;;   .endfor
;;
;; Substitution inside a body line (code portion; string literals are skipped):
;;   ${expr}  -> evaluate a compile-time integer expression over the loop vars
;;              and splice its decimal value. `${i}` is just the var; `${8*i}`,
;;              `${i+1}` do arithmetic. Grammar: literals (dec/0x), loop vars,
;;              arithmetic + - * / % << >> unary-, comparisons == != < > <= >=,
;;              logicals && || ! (short-circuit), and a Rust-style conditional
;;              `if cond { a } else { b }` (`else if` chains; `else` optional —
;;              a bare `if c { a }` is lazy, erroring only if evaluated with c
;;              false) — C precedence, integer division, booleans as 1/0. Concat
;;              (x.a${i}, L${i}:), immediates (#${16*i}, #${if i==n-1 {0} else
;;              {8}}), and inside register lists (ld1 { v${i}.4s }, ...) alike.
;;
;; `${...}` was chosen over a `\`-sigil because bare `{...}` is AArch64's SIMD
;; register-list syntax; a `$` prefix disambiguates so the two never collide.
;; A lone `$` (not followed by `{`) is passed through literally (e.g. label
;; separators like `Lf$entry`).
;;
;; Loops may nest; an inner body sees all enclosing vars. `.for` bounds are
;; themselves compile-time exprs (may use enclosing vars).
;;
;; Guarantee: a source containing no `.for` is returned byte-for-byte unchanged
;; (identity), and lines OUTSIDE any `.for` are never substituted — so this is a
;; no-op for every existing kernel.

(require racket/list (only-in racket/string string-join))
(provide expand-for-lines)

;; A "line" is (list text line-number prov). prov is #f for a normal line, or
;; (bindings-alist . template-text) for an expanded line — the loop bindings
;; ((i . 3) …) plus the ORIGINAL body template — carried purely to enrich
;; downstream diagnostics (a parse error on generated code can then show which
;; iteration produced it AND the `${…}` template it came from).
;; expand-for-lines : (listof line) sym -> (listof line)
(define (ln-text l) (car l))
(define (ln-no   l) (cadr l))
(define (mk-ln text no prov) (list text no prov))

(define (expand-for-lines lines source)
  (if (for-related? lines)
      (expand-lines lines (hash) source)
      lines))                                   ; fast-path true no-op

;; Trigger expansion when the source mentions `.for` OR `.endfor`, so a stray
;; `.endfor` reaches the "unmatched .endfor" error rather than silently passing
;; through. Existing kernels contain neither directive, so this stays a no-op.
(define (for-related? lines)
  (for/or ([ln (in-list lines)])
    (or (for-header? (ln-text ln)) (endfor-line? (ln-text ln)))))

;; loop bindings, sorted by var name for stable display
(define (env->binding-alist env)
  (sort (hash->list env) symbol<? #:key car))

(define (binds->str alist)
  (string-join (for/list ([b (in-list alist)]) (format "~a=~a" (car b) (cdr b))) ", "))

;; ---------------------------------------------------------------------------
;; .for / .endfor recognition
;; ---------------------------------------------------------------------------

;; Is the line a `.for` header? (word-boundary prefix match; no validation.)
(define (for-header? text)
  (define t (string-trim-left text))
  (or (prefix-word? t ".for") (prefix-word? t ".asmp.for")))

;; Parse a validated `.for` header into (list var lo-str hi-str). Errors (with
;; source:line) on a malformed header. Only called where the header is known.
(define (for-header-parts text source lineno)
  (define t (string-trim-left text))
  (define pfx (if (prefix-word? t ".for") ".for" ".asmp.for"))
  (define parts (map string-trim (split-top-commas (substring t (string-length pfx)))))
  (unless (= (length parts) 3)
    (error 'unroll "~a:~a: .for 需要 3 个逗号分隔参数 (var, lo, hi), 得: ~s" source lineno text))
  (unless (ident? (first parts))
    (error 'unroll "~a:~a: .for 循环变量须为标识符, 得: ~s" source lineno (first parts)))
  parts)

(define (endfor-line? text)
  (define t (string-trim-left text))
  (or (prefix-word? t ".endfor") (prefix-word? t ".asmp.endfor")))

;; word-boundary prefix: t starts with w and the next char (if any) is not an
;; identifier char (so ".format" is not matched by ".for").
(define (prefix-word? t w)
  (and (>= (string-length t) (string-length w))
       (string=? (substring t 0 (string-length w)) w)
       (or (= (string-length t) (string-length w))
           (not (ident-char? (string-ref t (string-length w)))))))

;; ---------------------------------------------------------------------------
;; recursive expansion
;; ---------------------------------------------------------------------------

(define (expand-lines lines env source)
  (let loop ([ls lines] [out '()])
    (cond
      [(null? ls) (reverse out)]
      [else
       (define text (ln-text (car ls)))
       (define lineno (ln-no (car ls)))
       (cond
         [(for-header? text)
          (define hdr (for-header-parts text source lineno))
          (define var (string->symbol (first hdr)))
          (define lo (eval-int (second hdr) env source lineno))
          (define hi (eval-int (third hdr) env source lineno))
          (define-values (body rest) (collect-body (cdr ls) source lineno))
          (define expanded
            (append*
             (for/list ([i (in-range lo hi)])
               (expand-lines body (hash-set env var i) source))))
          (loop rest (append (reverse expanded) out))]
         [(endfor-line? text)
          (error 'unroll "~a:~a: .endfor 无匹配的 .for" source lineno)]
         [else
          ;; leaf line: substitute only inside a loop body (env non-empty), so
          ;; top-level lines pass through untouched. Expanded lines carry the
          ;; loop bindings as provenance for diagnostics.
          (define in-loop? (positive? (hash-count env)))
          ;; substitute inside a loop body; an eval error (div0, unknown var, a
          ;; lazy if with no else taken false) is re-raised with the iteration
          ;; and the ${…} template so expansion-time failures are traceable too.
          (define out-text
            (if in-loop?
                (with-handlers
                  ([exn:fail?
                    (lambda (e)
                      (error (format "~a\n  (.for 展开自第 ~a 行, ~a; 模板: ~a)"
                                     (exn-message e) lineno
                                     (binds->str (env->binding-alist env))
                                     (string-trim text))))])
                  (subst text env source lineno))
                text))
          ;; prov = (bindings-alist . original-template-text) for diagnostics
          (define prov (and in-loop? (cons (env->binding-alist env) text)))
          (loop (cdr ls) (cons (mk-ln out-text lineno prov) out))])])))

;; Collect body lines up to the matching .endfor (respecting nesting).
;; Returns (values body-lines rest-after-endfor). `for-lineno` for error msgs.
(define (collect-body lines source for-lineno)
  (let loop ([ls lines] [depth 0] [body '()])
    (when (null? ls)
      (error 'unroll "~a:~a: .for 缺少匹配的 .endfor" source for-lineno))
    (define text (caar ls))
    (cond
      [(for-header? text) (loop (cdr ls) (add1 depth) (cons (car ls) body))]
      [(endfor-line? text)
       (if (zero? depth)
           (values (reverse body) (cdr ls))
           (loop (cdr ls) (sub1 depth) (cons (car ls) body)))]
      [else (loop (cdr ls) depth (cons (car ls) body))])))

;; ---------------------------------------------------------------------------
;; per-line substitution: ${expr}, skipping string literals
;; ---------------------------------------------------------------------------

(define (subst text env source lineno)
  (define n (string-length text))
  (define out (open-output-string))
  (let loop ([i 0] [mode 'code])   ; mode: 'code | 'string | 'comment
    (cond
      [(>= i n) (get-output-string out)]
      [else
       (define c (string-ref text i))
       (case mode
         [(string)
          (cond
            [(char=? c #\\)                          ; string escape: copy \ + next verbatim
             (write-char c out)
             (when (< (add1 i) n) (write-char (string-ref text (add1 i)) out))
             (loop (+ i 2) 'string)]
            [(char=? c #\") (write-char c out) (loop (add1 i) 'code)]
            [else (write-char c out) (loop (add1 i) 'string)])]
         [(comment)                                  ; comment: expand ${expr} leniently (leave literal on error)
          (cond
            [(dollar-brace? text i n)
             (define-values (rep next) (try-dollar-brace text i env source lineno #f))
             (write-string rep out) (loop next 'comment)]
            [else (write-char c out) (loop (add1 i) 'comment)])]
         [else ; 'code
          (cond
            [(char=? c #\") (write-char c out) (loop (add1 i) 'string)]
            [(char=? c #\;) (write-char c out) (loop (add1 i) 'comment)]
            [(and (char=? c #\/) (< (add1 i) n) (char=? (string-ref text (add1 i)) #\/))
             (write-char c out) (loop (add1 i) 'comment)]
            [(dollar-brace? text i n)
             (define-values (rep next) (try-dollar-brace text i env source lineno #t))
             (write-string rep out) (loop next 'code)]
            [else (write-char c out) (loop (add1 i) 'code)])])])))

;; Is there a "${" at position i? (A lone `$` is left literal — e.g. `Lf$entry`.)
(define (dollar-brace? text i n)
  (and (char=? (string-ref text i) #\$)
       (< (add1 i) n)
       (char=? (string-ref text (add1 i)) #\{)))

;; Handle a `${expr}` at position i (points at `$`, i+1 is `{`). strict? => any
;; error propagates; else (comment) leave the literal "${" and advance past it.
;; Returns (values replacement-string next-index).
(define (try-dollar-brace text i env source lineno strict?)
  (define (do-it)
    (define-values (expr end) (read-braces text (+ i 2) source lineno))
    (values (number->string (eval-int expr env source lineno)) end))
  (if strict?
      (do-it)
      (with-handlers ([exn:fail? (lambda (_) (values "${" (+ i 2)))])
        (do-it))))

;; read balanced { } starting at i (just past the "${"); returns (values inner end-past-close)
(define (read-braces text i source lineno)
  (define n (string-length text))
  (let loop ([k i] [depth 1])
    (cond
      [(>= k n) (error 'unroll "~a:~a: ${...} 大括号未闭合" source lineno)]
      [(char=? (string-ref text k) #\{) (loop (add1 k) (add1 depth))]
      [(char=? (string-ref text k) #\})
       (if (= depth 1) (values (substring text i k) (add1 k)) (loop (add1 k) (sub1 depth)))]
      [else (loop (add1 k) depth)])))

;; ---------------------------------------------------------------------------
;; compile-time integer expression evaluator (parse to AST, then eval)
;;   expr    := or
;;   or      := and   ( "||" and )*                 ; short-circuit
;;   and     := cmp   ( "&&" cmp )*                  ; short-circuit
;;   cmp     := shift ( ("=="|"!="|"<"|">"|"<="|">=") shift )?   ; non-chaining, 1/0
;;   shift   := add   (( "<<" | ">>" ) add)*
;;   add     := mul   (( "+" | "-" ) mul)*
;;   mul     := unary (( "*" | "/" | "%" ) unary)*
;;   unary   := ("-"|"!") unary | primary
;;   primary := int | ident | "(" expr ")" | if
;;   if      := "if" expr "{" expr "}" "else" ( "{" expr "}" | if )  ; Rust-style, else required
;; Parse-to-AST + eval so `if` and `&&`/`||` evaluate only the TAKEN branch —
;; the dead side of `if i==0 { 0 } else { 8/i }` is never evaluated (no div0).
;; Booleans are integers: comparisons/logicals yield 1/0; `if` tests nonzero.
;; ---------------------------------------------------------------------------

(define (eval-int str env source lineno)
  (define toks (tokenize-expr str source lineno))
  (define-values (ast rest) (parse-expr toks source lineno))
  (unless (null? rest)
    (error 'unroll "~a:~a: 表达式尾部多余记号: ~s (在 \"~a\")" source lineno rest str))
  (eval-ast ast env source lineno))

;; ---- tokenizer ----
(define LBRACE (string->symbol "{"))
(define RBRACE (string->symbol "}"))

(define (tokenize-expr str source lineno)
  (define n (string-length str))
  (define (nx i) (and (< (add1 i) n) (string-ref str (add1 i))))
  (let loop ([i 0] [acc '()])
    (cond
      [(>= i n) (reverse acc)]
      [else
       (define c (string-ref str i))
       (cond
         [(char-whitespace? c) (loop (add1 i) acc)]
         [(and (char=? c #\0) (memv (nx i) '(#\x #\X)))
          (define j (let s ([k (+ i 2)]) (if (and (< k n) (hex-digit? (string-ref str k))) (s (add1 k)) k)))
          (loop j (cons (cons 'int (string->number (substring str (+ i 2) j) 16)) acc))]
         [(char-numeric? c)
          (define j (let s ([k i]) (if (and (< k n) (char-numeric? (string-ref str k))) (s (add1 k)) k)))
          (loop j (cons (cons 'int (string->number (substring str i j))) acc))]
         [(ident-start? c)
          (define j (let s ([k i]) (if (and (< k n) (ident-char? (string-ref str k))) (s (add1 k)) k)))
          (loop j (cons (cons 'id (string->symbol (substring str i j))) acc))]
         ;; two-char operators (checked before single-char)
         [(and (char=? c #\<) (eqv? (nx i) #\<)) (loop (+ i 2) (cons '(op . <<) acc))]
         [(and (char=? c #\>) (eqv? (nx i) #\>)) (loop (+ i 2) (cons '(op . >>) acc))]
         [(and (char=? c #\<) (eqv? (nx i) #\=)) (loop (+ i 2) (cons '(op . <=) acc))]
         [(and (char=? c #\>) (eqv? (nx i) #\=)) (loop (+ i 2) (cons '(op . >=) acc))]
         [(and (char=? c #\=) (eqv? (nx i) #\=)) (loop (+ i 2) (cons '(op . ==) acc))]
         [(and (char=? c #\!) (eqv? (nx i) #\=)) (loop (+ i 2) (cons '(op . !=) acc))]
         [(and (char=? c #\&) (eqv? (nx i) #\&)) (loop (+ i 2) (cons '(op . &&) acc))]
         [(and (char=? c #\|) (eqv? (nx i) #\|)) (loop (+ i 2) (cons '(op . lor) acc))]
         ;; single-char operators
         [(memv c '(#\+ #\- #\* #\/ #\% #\( #\) #\< #\> #\!))
          (loop (add1 i) (cons (cons 'op (string->symbol (string c))) acc))]
         [(char=? c #\{) (loop (add1 i) (cons (cons 'op LBRACE) acc))]
         [(char=? c #\}) (loop (add1 i) (cons (cons 'op RBRACE) acc))]
         [else (error 'unroll "~a:~a: 表达式非法字符 ~s" source lineno c)])])))

(define (tk-op? t sym) (and (pair? t) (eq? (car t) 'op) (eq? (cdr t) sym)))
(define (tk-op-in? t syms) (and (pair? t) (eq? (car t) 'op) (memq (cdr t) syms)))
(define (tk-id? t sym) (and (pair? t) (eq? (car t) 'id) (eq? (cdr t) sym)))

;; ---- parser: tokens -> AST, (values ast rest) ----
;; AST := (int n) | (var sym) | (un op child) | (bin op l r) | (if c t e)
(define (parse-expr toks source lineno) (parse-or toks source lineno))

(define (parse-binl sub ops toks source lineno)
  (define-values (l0 rest0) (sub toks source lineno))
  (let loop ([l l0] [rest rest0])
    (cond
      [(and (pair? rest) (tk-op-in? (car rest) ops))
       (define op (cdar rest))
       (define-values (r rest2) (sub (cdr rest) source lineno))
       (loop (list 'bin op l r) rest2)]
      [else (values l rest)])))

(define (parse-or  toks source lineno) (parse-binl parse-and '(lor)  toks source lineno))
(define (parse-and toks source lineno) (parse-binl parse-cmp '(&&)   toks source lineno))

(define (parse-cmp toks source lineno)
  (define-values (l rest) (parse-shift toks source lineno))
  (cond
    [(and (pair? rest) (tk-op-in? (car rest) '(== != < > <= >=)))
     (define op (cdar rest))
     (define-values (r rest2) (parse-shift (cdr rest) source lineno))
     (values (list 'bin op l r) rest2)]
    [else (values l rest)]))

(define (parse-shift toks source lineno) (parse-binl parse-add   '(<< >>) toks source lineno))
(define (parse-add   toks source lineno) (parse-binl parse-mul   '(+ -)   toks source lineno))
(define (parse-mul   toks source lineno) (parse-binl parse-unary '(* / %) toks source lineno))

(define (parse-unary toks source lineno)
  (cond
    [(and (pair? toks) (tk-op? (car toks) '-))
     (define-values (a r) (parse-unary (cdr toks) source lineno)) (values (list 'un 'neg a) r)]
    [(and (pair? toks) (tk-op? (car toks) '!))
     (define-values (a r) (parse-unary (cdr toks) source lineno)) (values (list 'un 'lnot a) r)]
    [else (parse-primary toks source lineno)]))

(define (parse-primary toks source lineno)
  (when (null? toks) (error 'unroll "~a:~a: 表达式意外结束" source lineno))
  (define t (car toks))
  (cond
    [(eq? (car t) 'int) (values (list 'int (cdr t)) (cdr toks))]
    [(tk-id? t 'if) (parse-if toks source lineno)]
    [(eq? (car t) 'id) (values (list 'var (cdr t)) (cdr toks))]
    [(tk-op? t '\()
     (define-values (a r) (parse-expr (cdr toks) source lineno))
     (unless (and (pair? r) (tk-op? (car r) '\)))
       (error 'unroll "~a:~a: 表达式缺少右括号" source lineno))
     (values a (cdr r))]
    [else (error 'unroll "~a:~a: 表达式非法记号 ~s" source lineno t)]))

(define (expect toks op msg source lineno)
  (unless (and (pair? toks) (tk-op? (car toks) op)) (error 'unroll "~a:~a: ~a" source lineno msg))
  (cdr toks))

;; if := "if" expr "{" expr "}" [ "else" ( "{" expr "}" | if ) ]   ; car of toks is (id . if)
;; `else` is optional: a bare `if c { a }` parses fine; it only errors at EVAL,
;; and only if c is false (lazy — legal as long as the else-less path isn't hit).
(define (parse-if toks source lineno)
  (define-values (c r1) (parse-expr (cdr toks) source lineno))
  (define r2 (expect r1 LBRACE "if 条件后须接 {" source lineno))
  (define-values (thn r3) (parse-expr r2 source lineno))
  (define r4 (expect r3 RBRACE "if then 分支后须接 }" source lineno))
  (cond
    [(not (and (pair? r4) (tk-id? (car r4) 'else)))         ; no else -> (if c thn #f)
     (values (list 'if c thn #f) r4)]
    [else
     (define r5 (cdr r4))
     (cond
       [(and (pair? r5) (tk-id? (car r5) 'if))              ; else if ...
        (define-values (els r6) (parse-if r5 source lineno))
        (values (list 'if c thn els) r6)]
       [else                                                 ; else { ... }
        (define r6 (expect r5 LBRACE "else 后须接 { 或 if" source lineno))
        (define-values (els r7) (parse-expr r6 source lineno))
        (define r8 (expect r7 RBRACE "else 分支后须接 }" source lineno))
        (values (list 'if c thn els) r8)])]))

;; ---- evaluator: AST + env -> integer (only taken branches evaluated) ----
(define (eval-ast a env source lineno)
  (case (car a)
    [(int) (cadr a)]
    [(var)
     (define name (cadr a))
     (unless (hash-has-key? env name)
       (error 'unroll "~a:~a: 表达式引用未知循环变量 ~a" source lineno name))
     (hash-ref env name)]
    [(un)
     (define v (eval-ast (caddr a) env source lineno))
     (case (cadr a) [(neg) (- v)] [(lnot) (if (zero? v) 1 0)])]
    [(if)
     (cond
       [(not (zero? (eval-ast (cadr a) env source lineno)))
        (eval-ast (caddr a) env source lineno)]           ; then
       [(cadddr a) (eval-ast (cadddr a) env source lineno)] ; else (may be #f)
       [else (error 'unroll "~a:~a: if 条件为假但无 else 分支，此处无值可求" source lineno)])]
    [(bin) (eval-bin (cadr a) (caddr a) (cadddr a) env source lineno)]
    [else (error 'unroll "内部错误: 非法 AST ~s" a)]))

(define (eval-bin op la ra env source lineno)
  (define (L) (eval-ast la env source lineno))
  (define (R) (eval-ast ra env source lineno))
  (define (b x) (if x 1 0))
  (case op
    ;; short-circuit logicals: R evaluated only when needed
    [(lor) (if (not (zero? (L))) 1 (b (not (zero? (R)))))]
    [(&&)  (if (zero? (L)) 0 (b (not (zero? (R)))))]
    [(==) (b (= (L) (R)))] [(!=) (b (not (= (L) (R))))]
    [(<)  (b (< (L) (R)))] [(>)  (b (> (L) (R)))]
    [(<=) (b (<= (L) (R)))] [(>=) (b (>= (L) (R)))]
    [(<<) (arithmetic-shift (L) (R))] [(>>) (arithmetic-shift (L) (- (R)))]
    [(+) (+ (L) (R))] [(-) (- (L) (R))] [(*) (* (L) (R))]
    [(/) (let ([d (R)]) (when (zero? d) (error 'unroll "~a:~a: 表达式除以零" source lineno)) (quotient (L) d))]
    [(%) (let ([d (R)]) (when (zero? d) (error 'unroll "~a:~a: 表达式模零" source lineno)) (remainder (L) d))]
    [else (error 'unroll "内部错误: 未知算符 ~a" op)]))

;; ---------------------------------------------------------------------------
;; small helpers
;; ---------------------------------------------------------------------------

(define (ident-start? c) (or (char-alphabetic? c) (char=? c #\_)))
(define (ident-char? c) (or (char-alphabetic? c) (char-numeric? c) (char=? c #\_)))
(define (hex-digit? c) (or (char-numeric? c) (memv (char-downcase c) '(#\a #\b #\c #\d #\e #\f))))
(define (ident? s) (and (> (string-length s) 0) (ident-start? (string-ref s 0))
                        (for/and ([c (in-string s)]) (ident-char? c))))

(define (string-trim-left s)
  (define n (string-length s))
  (let loop ([i 0]) (if (and (< i n) (char-whitespace? (string-ref s i))) (loop (add1 i)) (substring s i))))

(define (string-trim s)
  (define t (string-trim-left s))
  (define n (string-length t))
  (let loop ([i n]) (if (and (> i 0) (char-whitespace? (string-ref t (sub1 i)))) (loop (sub1 i)) (substring t 0 i))))

;; split on top-level commas (no nesting inside .for headers, but be safe re parens)
(define (split-top-commas s)
  (define n (string-length s))
  (let loop ([i 0] [depth 0] [start 0] [acc '()])
    (cond
      [(>= i n) (reverse (cons (substring s start i) acc))]
      [else
       (define c (string-ref s i))
       (cond
         [(char=? c #\() (loop (add1 i) (add1 depth) start acc)]
         [(char=? c #\)) (loop (add1 i) (max 0 (sub1 depth)) start acc)]
         [(and (char=? c #\,) (zero? depth)) (loop (add1 i) depth (add1 i) (cons (substring s start i) acc))]
         [else (loop (add1 i) depth start acc)])])))
