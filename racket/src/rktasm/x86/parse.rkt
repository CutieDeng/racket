#lang racket/base
;; Parser for the x86-64 kernel DSL (Intel operand order, GAS Intel syntax).
;;
;;   ;; comment  // comment  # comment
;;   .function NAME [export] (          ; managed function with a signature
;;     in: rdi, rsi, rdx                ;   physical or virtual registers
;;   )
;;   label:
;;     mnemonic dst, src, ...           ; operands: rax / q.name / 12 / 0x1f / [rsi + rcx*8 + 16]
;;     .save all | .save none           ; callee-saved registers (default: all used)
;;   .end
;;   .rodata NAME [align=N]             ; constant block, raw data directives inside
;;     .long 1, 2, 3
;;   .end
;;
;; Virtual registers: q.name d.name w.name b.name (GPR views), xmm.name ymm.name zmm.name, k.name.
;; Memory: [base + index*scale + disp] with optional "size ptr" prefix, or [rip + sym + disp].
(require racket/string racket/list racket/match racket/path "spec.rkt" "../parser/unroll.rkt")
(provide parse-file parse-string
         (struct-out fn) (struct-out rodata) (struct-out instr) (struct-out label))

(struct fn (name export? ins outs inouts body save line) #:transparent #:mutable)
(struct rodata (name align lines line) #:transparent)
(struct instr (mnemonic ops text line) #:transparent)
(struct label (name line) #:transparent)

(define (strip-comment s)
  (define m (regexp-match-positions #rx";|//|#" s))
  (string-trim (if m (substring s 0 (caar m)) s)))

(define (parse-error line msg . args)
  (error 'x86-parse "line ~a: ~a" line (apply format msg args)))

;; ---- operands
(define (parse-reg-token t line)
  (define s (string-downcase t))
  (cond
    [(regexp-match #px"^(q|d|w|b|xmm|ymm|zmm|k)\\.([a-z_][a-z0-9_]*)$" s)
     => (lambda (m) (list 'vreg (case (cadr m) [("q" "d" "w" "b") 'gpr] [("xmm") 'xmm] [("ymm") 'ymm] [("zmm") 'zmm] [("k") 'k])
                          (string->symbol (caddr m)) (string->symbol (cadr m))))]
    [(reg-name-info (string->symbol s)) (list 'reg (string->symbol s))]
    [else #f]))
(define (parse-number s)
  (define t (string-downcase (string-trim s)))
  (cond
    [(regexp-match #px"^-?0x[0-9a-f]+$" t)
     (define neg (char=? (string-ref t 0) #\-))
     (define v (string->number (substring t (if neg 3 2)) 16))
     (if neg (- v) v)]
    [(regexp-match #px"^-?[0-9]+$" t) (string->number t)]
    [else #f]))
;; EVEX decorators: {k1} / {k.name} -> (mask reg), {z} -> (z), {1to16} -> (bcst 16), anything else -> (raw text)
(define (parse-decor s line)
  (define t (string-downcase (substring s 1 (sub1 (string-length s)))))
  (cond
    [(string=? t "z") '(z)]
    [(regexp-match #px"^1to([0-9]+)$" t) => (lambda (m) (list 'bcst (string->number (cadr m))))]
    [(parse-reg-token t line) => (lambda (r) (list 'mask r))]
    [else (list 'raw s)]))
(define (parse-decors t line) (map (lambda (d) (parse-decor d line)) (regexp-match* #rx"{[^}]*}" t)))
(define (parse-mem s line)
  ;; "[qword ptr]" already stripped by caller; s is the inside of [...]
  (define parts (map string-trim (regexp-split #rx"\\+" (regexp-replace* #rx"-" s "+-"))))
  (define base #f) (define index #f) (define scale 1) (define disp 0) (define sym #f)
  (for ([p parts] #:unless (string=? p ""))
    (cond
      [(regexp-match #px"^([a-z0-9.]+)\\*([1248])$" p)
       => (lambda (m) (set! index (or (parse-reg-token (cadr m) line) (parse-error line "bad index ~a" p)))
            (set! scale (string->number (caddr m))))]
      [(parse-number p) => (lambda (n) (set! disp (+ disp n)))]
      [(parse-reg-token p line) => (lambda (r) (if base (set! index r) (set! base r)))]
      [(regexp-match #px"^-?[A-Za-z_.][A-Za-z0-9_.]*$" p)
       (set! sym (string->symbol (regexp-replace #rx"^-" p "")))]
      [else (parse-error line "bad memory operand part ~s" p)]))
  (list 'mem base index scale disp sym))
(define (parse-operand s line)
  (define t (string-trim s))
  (cond
    [(regexp-match #px"^(?:(byte|word|dword|qword|xmmword|ymmword|zmmword|tbyte) ptr )?\\[(.*)\\](\\{[^}]*\\})*$" t)
     => (lambda (m) (define size (cadr m))
          (define decor (parse-decors t line))
          (define mem (parse-mem (caddr m) line))
          (append mem (list (and size (string->symbol size)) decor)))]
    [(parse-number t) => (lambda (n) (list 'imm n))]
    [(regexp-match #px"^([a-z0-9.]+)(\\{[^}]*\\})+$" (string-downcase t))
     => (lambda (m) (define r (parse-reg-token (cadr m) line))
          (if r (append r (list (parse-decors t line))) (parse-error line "bad operand ~s" t)))]
    [(parse-reg-token t line) => values]
    [(regexp-match #px"^[A-Za-z_.][A-Za-z0-9_.]*$" t) (list 'label (string->symbol t))]
    [else (parse-error line "bad operand ~s" t)]))
(define (split-operands s)
  ;; split on commas outside brackets/braces
  (define out '()) (define cur '()) (define depth 0)
  (for ([c s])
    (cond
      [(memv c '(#\[ #\{ #\()) (set! depth (add1 depth)) (set! cur (cons c cur))]
      [(memv c '(#\] #\} #\))) (set! depth (sub1 depth)) (set! cur (cons c cur))]
      [(and (char=? c #\,) (= depth 0)) (set! out (cons (list->string (reverse cur)) out)) (set! cur '())]
      [else (set! cur (cons c cur))]))
  (set! out (cons (list->string (reverse cur)) out))
  (filter (lambda (x) (not (string=? x ""))) (map string-trim (reverse out))))

;; ---- lines
(define (parse-string text [source 'x86-asm])
  ;; shared compile-time unrolling (.for var, lo, hi / ${expr}) from the AArch64 frontend
  (define lines (expand-for-lines (for/list ([l (regexp-split #rx"\r?\n" text)] [n (in-naturals 1)]) (list l n #f)) source))
  (define items '())
  (define cur #f)        ; fn being filled
  (define cur-ro #f)     ; rodata being filled
  (define sig-mode #f)   ; inside "( ... )" of .function
  (define (add-item! x) (set! items (cons x items)))
  (define (add-body! x)
    (cond [cur (set-fn-body! cur (cons x (fn-body cur)))]
          [else (parse-error (if (instr? x) (instr-line x) (label-line x)) "instruction outside .function")]))
  (for ([l lines])
    (define raw (car l)) (define ln (cadr l))
    (define s (strip-comment raw))
    (cond
      [(string=? s "") (void)]
      [sig-mode
       (cond
         [(string=? s ")") (set! sig-mode #f)]
         [(regexp-match #px"^(in|out|inout)\\s*:\\s*(.*)$" s)
          => (lambda (m)
               (define regs (for/list ([t (split-operands (caddr m))]) (or (parse-reg-token t ln) (parse-error ln "bad signature register ~s" t))))
               (case (cadr m)
                 [("in") (set-fn-ins! cur (append (fn-ins cur) regs))]
                 [("out") (set-fn-outs! cur (append (fn-outs cur) regs))]
                 [("inout") (set-fn-inouts! cur (append (fn-inouts cur) regs))]))]
         [else (parse-error ln "bad signature line ~s" s)])]
      [cur-ro
       (if (string=? s ".end")
           (begin (add-item! (rodata (rodata-name cur-ro) (rodata-align cur-ro) (reverse (rodata-lines cur-ro)) (rodata-line cur-ro)))
                  (set! cur-ro #f))
           (set! cur-ro (rodata (rodata-name cur-ro) (rodata-align cur-ro) (cons s (rodata-lines cur-ro)) (rodata-line cur-ro))))]
      [(regexp-match #px"^\\.function\\s+([A-Za-z_][A-Za-z0-9_.-]*)\\s*(export)?\\s*\\(\\s*(\\))?$" s)
       => (lambda (m)
            (when cur (parse-error ln ".function inside .function"))
            (set! cur (fn (string->symbol (cadr m)) (and (caddr m) #t) '() '() '() '() 'all ln))
            (set! sig-mode (not (cadddr m))))]
      [(regexp-match #px"^\\.rodata\\s+([A-Za-z_][A-Za-z0-9_]*)(?:\\s+align=([0-9]+))?$" s)
       => (lambda (m) (set! cur-ro (rodata (string->symbol (cadr m)) (if (caddr m) (string->number (caddr m)) 64) '() ln)))]
      [(string=? s ".end")
       (unless cur (parse-error ln ".end without .function"))
       (set-fn-body! cur (reverse (fn-body cur)))
       (add-item! cur) (set! cur #f)]
      [(regexp-match #px"^\\.save\\s+(all|none)$" s)
       => (lambda (m) (unless cur (parse-error ln ".save outside .function")) (set-fn-save! cur (string->symbol (cadr m))))]
      [(regexp-match #px"^([A-Za-z_.][A-Za-z0-9_.]*):$" s)
       => (lambda (m) (add-body! (label (string->symbol (cadr m)) ln)))]
      [(regexp-match #px"^\\.(p2align|align)\\s+[0-9]+$" s) (add-body! (instr '.directive '() s ln))]
      [(regexp-match #px"^([A-Za-z][A-Za-z0-9.]*)\\s*(.*)$" s)
       => (lambda (m)
            (define mn (string->symbol (string-downcase (cadr m))))
            (define ops (for/list ([t (split-operands (caddr m))]) (parse-operand t ln)))
            (add-body! (instr mn ops s ln)))]
      [else (parse-error ln "cannot parse ~s" s)]))
  (when cur (parse-error (fn-line cur) ".function without .end"))
  (reverse items))

(define (parse-file path) (parse-string (call-with-input-file path (lambda (p) (let loop ([acc '()]) (define l (read-line p)) (if (eof-object? l) (string-join (reverse acc) "\n") (loop (cons l acc)))))) (string->symbol (path->string (file-name-from-path path)))))
