#lang racket/base
;; x86/macro.rkt — parameterised text macros for the x86 kernel DSL, expanded before the
;; shared .for unrolling (so a macro body may contain .for, and a .for body may invoke a
;; macro with ${expr} arguments, which the unroll pass then evaluates).
;;
;;   .macro NAME p1, p2, ...        ; definition (nesting of definitions is not allowed)
;;     ... \p1 ... \p2 ... \@ ...   ; \param substitutes the argument text, \@ a per-expansion
;;   .endm                          ;   counter (for labels local to one expansion)
;;   NAME(arg1, arg2, ...)          ; invocation: an identifier directly followed by "(";
;;                                  ;   arguments split on top-level commas (brackets nest)
;; Invocations inside macro bodies expand recursively (depth limit 64). Lines keep their
;; original line numbers for diagnostics.
(require racket/string racket/list)
(provide expand-macros)

(define (split-top-commas s)
  (define out '()) (define cur '()) (define depth 0)
  (for ([c s])
    (cond
      [(memv c '(#\[ #\{ #\()) (set! depth (add1 depth)) (set! cur (cons c cur))]
      [(memv c '(#\] #\} #\))) (set! depth (sub1 depth)) (set! cur (cons c cur))]
      [(and (char=? c #\,) (= depth 0)) (set! out (cons (list->string (reverse cur)) out)) (set! cur '())]
      [else (set! cur (cons c cur))]))
  (set! out (cons (list->string (reverse cur)) out))
  (map string-trim (reverse out)))

(define (code-part text)   ; the line without its comment
  (define m (regexp-match-positions #rx";|//|#" text))
  (if m (substring text 0 (caar m)) text))

;; lines: (listof (list text lineno prov)); source: symbol for messages
(define (expand-macros lines source)
  (define macros (make-hash))   ; name -> (cons params body-lines)
  (define counter 0)
  ;; pass 1: collect definitions, drop them from the stream
  (define rest
    (let loop ([ls lines] [acc '()])
      (cond
        [(null? ls) (reverse acc)]
        [(regexp-match #px"^\\s*\\.macro\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*(.*)$" (code-part (car (car ls))))
         => (lambda (m)
              (define name (cadr m))
              (define params (filter (lambda (p) (not (string=? p ""))) (split-top-commas (caddr m))))
              (define-values (body after)
                (let scan ([b (cdr ls)] [body '()])
                  (cond
                    [(null? b) (error 'x86-macro "~a:~a: .macro ~a without .endm" source (cadr (car ls)) name)]
                    [(regexp-match? #px"^\\s*\\.endm\\s*$" (code-part (car (car b)))) (values (reverse body) (cdr b))]
                    [(regexp-match? #px"^\\s*\\.macro\\b" (code-part (car (car b))))
                     (error 'x86-macro "~a:~a: nested .macro definition" source (cadr (car b)))]
                    [else (scan (cdr b) (cons (car b) body))])))
              (hash-set! macros name (cons params body))
              (loop after acc))]
        [(regexp-match? #px"^\\s*\\.endm\\s*$" (code-part (car (car ls))))
         (error 'x86-macro "~a:~a: .endm without .macro" source (cadr (car ls)))]
        [else (loop (cdr ls) (cons (car ls) acc))])))
  ;; pass 2: expand invocations recursively
  (define (expand ls depth)
    (append*
     (for/list ([l ls])
       (define text (car l))
       (define m (regexp-match #px"^\\s*([A-Za-z_][A-Za-z0-9_]*)\\((.*)\\)\\s*$" (code-part text)))
       (cond
         [(and m (hash-ref macros (cadr m) #f))
          => (lambda (mac)
               (when (> depth 64) (error 'x86-macro "~a:~a: macro expansion too deep" source (cadr l)))
               (define params (car mac))
               (define args (let ([a (split-top-commas (caddr m))]) (if (equal? a '("")) '() a)))
               (unless (= (length params) (length args))
                 (error 'x86-macro "~a:~a: ~a expects ~a argument(s), got ~a" source (cadr l) (cadr m) (length params) (length args)))
               (set! counter (add1 counter))
               (define n counter)
               (define body
                 (for/list ([bl (cdr mac)])
                   (define t
                     (for/fold ([t (car bl)]) ([p params] [a args])
                       (regexp-replace* (pregexp (string-append "\\\\" (regexp-quote p) "\\b")) t (regexp-replace-quote a))))
                   (list (regexp-replace* #rx"\\\\@" t (number->string n)) (cadr l) (list 'macro (cadr m) (cadr bl)))))
               (expand body (add1 depth)))]
         [else (list l)]))))
  (if (zero? (hash-count macros)) rest (expand rest 0)))
