#lang racket/base
;; XED ISA datafiles -> normalized x86 instruction table (.rktd); the x86 module's counterpart of
;; encode/tool/mrs-converter.rkt. Reads an Intel XED checkout (not vendored yet; see docs/x86-64-backend-plan.md §1).
;;   (iclass . #hash((category . C) (forms . (form ...))))
;;   form = (isa-set extension flags attributes operands pattern)
;;   operand = (role lookup action width xtype implicit?)   role: REG0/REG1/MEM0/IMM0/... ; lookup: GPRv_R / XMM_B3 / XED_REG_RDX ...
;; usage: racket xed-convert.rkt <xed-dir> <out.rktd>
(require racket/list racket/string racket/file racket/pretty)
(define xed (vector-ref (current-command-line-arguments) 0))
(define out (vector-ref (current-command-line-arguments) 1))
(define files (for/list ([f (in-directory (build-path xed "datafiles"))]
                         #:when (regexp-match? #rx"isa[^/]*[.]txt$" (path->string f))) f))
(define (parse-file f)
  (define blocks '()) (define cur #f)
  (for ([line (file->lines f)])
    (define l (string-trim (car (regexp-split #rx"#" (string-append line " ")))))
    (cond
      [(string=? l "{") (set! cur '())]
      [(string=? l "}") (when (and cur (assoc "ICLASS" cur)) (set! blocks (cons (reverse cur) blocks))) (set! cur #f)]
      [(and cur (regexp-match #px"^([A-Z_0-9]+)\\s*:\\s*(.*)$" l))
       => (lambda (m) (set! cur (cons (cons (cadr m) (string-trim (caddr m))) cur)))]
      [else (void)]))
  (reverse blocks))
(define (parse-operand tok)
  ;; NAME[=LOOKUP]:ACTION[:WIDTH[:XTYPE]][:...]   e.g. REG0=XMM_R():rw:dq:i32  MEM0:rw:v  REG2=XED_REG_XMM0:r:SUPP:dq:u8  IMM0:r:b
  (define parts (string-split tok ":"))
  (define head (car parts))
  (define role+lookup (string-split head "="))
  (define role (car role+lookup))
  (define lookup (and (pair? (cdr role+lookup)) (regexp-replace #rx"\\(\\)$" (cadr role+lookup) "")))
  (define rest (cdr parts))
  (define implicit? (and (member "SUPP" rest) #t))
  (define rest* (filter (lambda (s) (not (member s '("SUPP" "IMPL" "ECOND" "EXPL")))) rest))
  (list (string->symbol role) (and lookup (string->symbol lookup))
        (and (pair? rest*) (string->symbol (car rest*)))
        (and (> (length rest*) 1) (string->symbol (cadr rest*)))
        (and (> (length rest*) 2) (string->symbol (caddr rest*)))
        implicit?))
(define (block->forms b)
  (define (get k) (define p (assoc k b)) (and p (cdr p)))
  (define isa-set (or (get "ISA_SET") (get "EXTENSION")))
  (define flags (get "FLAGS")) (define attrs (get "ATTRIBUTES"))
  ;; pair consecutive PATTERN/OPERANDS entries in order
  (let loop ([l b] [pat #f] [acc '()])
    (cond
      [(null? l) (reverse acc)]
      [(equal? (caar l) "PATTERN") (loop (cdr l) (cdar l) acc)]
      [(equal? (caar l) "OPERANDS")
       (loop (cdr l) #f (cons (list (string->symbol isa-set) (string->symbol (or (get "EXTENSION") "?"))
                                    (and flags (string->symbol (regexp-replace* #rx"[ \\[\\]]+" (string-downcase flags) " ")))
                                    (and attrs (map string->symbol (string-split attrs)))
                                    (map parse-operand (string-split (cdar l)))
                                    pat)
                              acc))]
      [else (loop (cdr l) pat acc)])))
(define table (make-hash))
(for* ([f files] [b (parse-file f)])
  (define ic (string->symbol (cdr (assoc "ICLASS" b))))
  (define cat (let ([p (assoc "CATEGORY" b)]) (and p (string->symbol (cdr p)))))
  (define e (hash-ref! table ic (lambda () (make-hash (list (cons 'category cat) (cons 'forms '()))))))
  (hash-set! e 'forms (append (hash-ref e 'forms) (block->forms b))))
(with-output-to-file out #:exists 'truncate
  (lambda () (pretty-write (for/list ([k (sort (hash-keys table) symbol<?)]) (cons k (hash-ref table k))))))
(define nforms (for/sum ([(k v) table]) (length (hash-ref v 'forms))))
(printf "iclasses ~a, forms ~a, written ~a (~a KB)\n" (hash-count table) nforms out (quotient (file-size out) 1024))
;; coverage of non-APX forms for the first kernels, grouped by ISA set
(define want '(SHA256RNDS2 SHA256MSG1 SHA256MSG2 PSHUFD PSHUFB PALIGNR PADDD MOVDQU VMOVDQU VPSHUFB VPALIGNR VPADDD VPXOR
               MULX ADCX ADOX RORX VAESENC VAESENCLAST VPCLMULQDQ VPTERNLOGQ VPMADD52LUQ VPROLQ))
(for ([m want])
  (define forms (hash-ref (hash-ref table m) 'forms))
  (define sets (remove-duplicates (map car forms)))
  (printf "  ~a: ~a forms; isa-sets ~a\n" m (length forms) sets))
