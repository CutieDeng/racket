#lang racket/base
;; x86-64 instruction specification backed by the XED-derived table
;; (data/xed-x86.rktd, produced by xed-convert.rkt). Provides form lookup,
;; operand matching for Intel-syntax operand lists, and use/def extraction
;; (explicit operands, implicit operands, EFLAGS).
(require racket/list racket/string racket/runtime-path racket/match)
(provide load-spec spec-forms match-form form-isa-set form-flags form-operands
         (struct-out operand-shape) classify-lookup instr-use-def
         reg-name->class reg-name-info gpr64-names)

(define-runtime-path data-dir "data")

;; ---------------------------------------------------------------- table
(define the-table #f)
(define (load-spec [path (build-path data-dir "xed-x86.rktd")])
  (unless the-table
    (define l (call-with-input-file path read))
    (define h (make-hasheq))
    (for ([e l]) (hash-set! h (car e) (cdr e)))
    (set! the-table h))
  the-table)
;; Intel-syntax mnemonics whose XED class name differs
(define iclass-aliases '((ret . RET_NEAR) (call . CALL_NEAR) (retf . RET_FAR)))
(define (spec-forms mnemonic)
  (define ic (cond [(assq mnemonic iclass-aliases) => cdr]
                   [else (string->symbol (string-upcase (symbol->string mnemonic)))]))
  (define e (hash-ref (load-spec) ic #f))
  (if e (hash-ref e 'forms) '()))
;; form = (isa-set extension flags attrs operands pattern)
(define (form-isa-set f) (list-ref f 0))
(define (form-flags f) (list-ref f 2))
(define (form-operands f) (list-ref f 4))

;; ---------------------------------------------------------------- registers
;; name -> (class width number)   class: gpr xmm ymm zmm k seg rip
(define gpr64-names '(rax rcx rdx rbx rsp rbp rsi rdi r8 r9 r10 r11 r12 r13 r14 r15))
(define gpr32-names '(eax ecx edx ebx esp ebp esi edi r8d r9d r10d r11d r12d r13d r14d r15d))
(define gpr16-names '(ax cx dx bx sp bp si di r8w r9w r10w r11w r12w r13w r14w r15w))
(define gpr8-names  '(al cl dl bl spl bpl sil dil r8b r9b r10b r11b r12b r13b r14b r15b))
(define gpr8h-names '(ah ch dh bh))
(define reg-table
  (let ([h (make-hasheq)])
    (for ([names (list gpr64-names gpr32-names gpr16-names gpr8-names)]
          [w '(64 32 16 8)])
      (for ([n names] [i (in-naturals)]) (hash-set! h n (list 'gpr w i))))
    (for ([n gpr8h-names] [i (in-naturals)]) (hash-set! h n (list 'gpr 8 (+ 4 i))))
    (for ([i 32])
      (hash-set! h (string->symbol (format "xmm~a" i)) (list 'xmm 128 i))
      (hash-set! h (string->symbol (format "ymm~a" i)) (list 'ymm 256 i))
      (hash-set! h (string->symbol (format "zmm~a" i)) (list 'zmm 512 i)))
    (for ([i 8]) (hash-set! h (string->symbol (format "k~a" i)) (list 'k 64 i)))
    (hash-set! h 'rip (list 'rip 64 0))
    h))
(define (reg-name-info n) (hash-ref reg-table n #f))
(define (reg-name->class n) (let ([i (reg-name-info n)]) (and i (car i))))

;; ---------------------------------------------------------------- operand shapes
;; What a form's explicit operand accepts: kind reg/mem/imm/rel, class, width
(struct operand-shape (kind class width fixed) #:transparent)
;; lookup names from XED: GPR64_R, GPRv_B, XMM_N3, ZMM_R, MASK_R, VGPR32_N, GPR8_R, GPRy_B, GPRz_R,
;; XED_REG_XMM0 (fixed), XED_REG_RDX ...
(define (classify-lookup lk width)
  (define s (and lk (symbol->string lk)))
  (cond
    [(not s) (operand-shape 'reg 'any #f #f)]
    [(regexp-match #rx"^XED_REG_(.+)$" s)
     => (lambda (m) (define n (string->symbol (string-downcase (cadr m))))
          (define i (reg-name-info n))
          (operand-shape 'reg (if i (car i) 'other) (and i (cadr i)) n))]
    [(regexp-match #rx"^V?GPR(64|32|16|8)" s) => (lambda (m) (operand-shape 'reg 'gpr (string->number (cadr m)) #f))]
    [(regexp-match #rx"^V?GPR(v|y|z|a)" s) (operand-shape 'reg 'gpr 'v #f)]
    [(regexp-match #rx"^XMM" s) (operand-shape 'reg 'xmm 128 #f)]
    [(regexp-match #rx"^YMM" s) (operand-shape 'reg 'ymm 256 #f)]
    [(regexp-match #rx"^ZMM" s) (operand-shape 'reg 'zmm 512 #f)]
    [(regexp-match #rx"^MASK" s) (operand-shape 'reg 'k 64 #f)]
    [(regexp-match #rx"^MMX" s) (operand-shape 'reg 'mmx 64 #f)]
    [(regexp-match #rx"^(SEG|CR|DR|X87|BND|TMM)" s) (operand-shape 'reg 'other #f #f)]
    [else (operand-shape 'reg 'other #f #f)]))
(define (width-code->bits w)
  (case w
    [(b) 8] [(w) 16] [(d) 32] [(q) 64] [(dq) 128] [(qq) 256]
    [(v vv y z) 'v]
    [else (cond [(and w (regexp-match #rx"^z" (symbol->string w))) 512]
                [(and w (regexp-match #rx"^(mskw|dq)" (symbol->string w))) 128]
                [else #f])]))
;; syntactic operands of a form: implicit (SUPP) operands, the EVEX writemask (MASK1, written as a
;; {k}{z} decorator in Intel syntax) and pseudo operands (EMX_BROADCAST_*) are not operands
(define (form-explicit-operands f)
  (for/list ([op (form-operands f)]
             #:unless (or (list-ref op 5)
                          (eq? (list-ref op 1) 'MASK1)
                          (not (regexp-match? #rx"^(REG|MEM|IMM|RELBR|AGEN|PTR)" (symbol->string (car op))))))
    op))
(define (form-accepts-mask? f)
  (for/or ([op (form-operands f)]) (eq? (list-ref op 1) 'MASK1)))
;; explicit operand shapes of a form, in syntax order
(define (form-shapes f)
  (for/list ([op (form-explicit-operands f)])
    (match-define (list role lookup action width xtype implicit?) op)
    (define rs (symbol->string role))
    (cond
      [(regexp-match #rx"^MEM" rs) (operand-shape 'mem #f (width-code->bits width) #f)]
      [(regexp-match #rx"^IMM" rs) (operand-shape 'imm #f (width-code->bits width) #f)]
      [(regexp-match #rx"^RELBR" rs) (operand-shape 'rel #f #f #f)]
      [(regexp-match #rx"^(REG|BASE|INDEX)" rs) (classify-lookup lookup width)]
      [(regexp-match #rx"^(AGEN|PTR)" rs) (operand-shape 'mem #f #f #f)]
      [else (operand-shape 'other #f #f #f)])))

;; user operand (from the parser): (reg name) | (vreg class name) | (mem size ...) | (imm n) | (label name)
(define (operand-matches? shape u)
  (match* ((operand-shape-kind shape) u)
    [('reg (list* 'reg n _))
     (define i (reg-name-info n))
     (and i
          (if (operand-shape-fixed shape)
              (eq? n (operand-shape-fixed shape))
              (let ([cls (operand-shape-class shape)] [w (operand-shape-width shape)])
                (and (or (eq? cls 'any) (eq? cls (car i)))
                     (or (not w) (eq? w 'v) (equal? w (cadr i))
                         ;; `v` gpr operand sizes: 16/32/64
                         (and (eq? cls 'gpr) (eq? w 'v) (memv (cadr i) '(16 32 64))))))))]
    [('reg (list* 'vreg cls _ view _))
     (define c (operand-shape-class shape))
     (define w (operand-shape-width shape))
     (define vw (case view [(q) 64] [(d) 32] [(w) 16] [(b) 8] [(xmm) 128] [(ymm) 256] [(zmm) 512] [(k) 64]))
     (and (not (operand-shape-fixed shape))
          (or (eq? c 'any) (eq? c cls))
          (or (not w) (equal? w vw) (and (eq? w 'v) (memv vw '(16 32 64)))))]
    [('mem (cons 'mem _)) #t]
    [('imm (list 'imm _)) #t]
    [('rel (list 'label _)) #t]
    [(_ _) #f]))

;; Prefer legacy/VEX forms over EVEX/APX unless the operands need them.
(define (form-rank f u-ops)
  (define isa (symbol->string (form-isa-set f)))
  (define needs-evex?
    (for/or ([u u-ops])
      (match u
        [(list 'reg n) (let ([i (reg-name-info n)]) (and i (or (eq? (car i) 'zmm) (eq? (car i) 'k) (and (memq (car i) '(xmm ymm)) (>= (caddr i) 16)))))]
        [(list* 'vreg cls _) (memq cls '(zmm k))]
        [_ #f])))
  (+ (if (regexp-match? #rx"APX" isa) 100 0)
     (if (and (not needs-evex?) (regexp-match? #rx"AVX512|AVX10" isa)) 10 0)
     (if (and needs-evex? (not (regexp-match? #rx"AVX512|AVX10" isa))) 10 0)))

;; Returns the best matching form for mnemonic + user operands, or #f.
(define (operand-decors u)
  (match u
    [(list 'reg _ d) d] [(list 'vreg _ _ _ d) d] [(list 'mem _ _ _ _ _ _ d) d] [_ '()]))
(define (masked? u) (for/or ([d (operand-decors u)]) (eq? (car d) 'mask)))
(define (match-form mnemonic u-ops)
  (define needs-mask? (ormap masked? u-ops))
  (define cands
    (for/list ([f (spec-forms mnemonic)]
               #:when (let ([shapes (form-shapes f)])
                        (and (= (length shapes) (length u-ops))
                             (andmap operand-matches? shapes u-ops)
                             (or (not needs-mask?) (form-accepts-mask? f)))))
      f))
  (and (pair? cands) (argmin (lambda (f) (form-rank f u-ops)) cands)))

;; ---------------------------------------------------------------- use/def
;; -> (values uses defs flags-read flags-written) where uses/defs are user operands or
;;    (reg fixed-name) for implicit registers; flags are lists of symbols (cf of zf sf pf af).
(define (instr-use-def form u-ops)
  (define uses '()) (define defs '())
  (define explicit (form-explicit-operands form))
  (for ([op explicit] [u u-ops])
    (define action (list-ref op 2))
    (define (use!) (set! uses (cons u uses)))
    (define (def!) (set! defs (cons u defs)))
    (define decors (operand-decors u))
    ;; a mask decorator reads the mask register; merge-masking (no {z}) also reads the destination
    (for ([d decors] #:when (eq? (car d) 'mask)) (set! uses (cons (cadr d) uses)))
    (define merge? (and (masked? u) (not (assq 'z decors))))
    (case action
      [(r cr) (use!)]
      [(w cw) (when merge? (use!)) (def!)]
      [(rw crw rcw) (use!) (def!)]
      [else (void)])
    ;; memory operands read their address registers
    (when (and (pair? u) (eq? (car u) 'mem))
      (for ([r (cdr u)] #:when (and (pair? r) (memq (car r) '(reg vreg)))) (set! uses (cons r uses)))))
  (for ([op (form-operands form)] #:when (list-ref op 5))
    (define lk (list-ref op 1)) (define action (list-ref op 2))
    (define sh (classify-lookup lk #f))
    (when (operand-shape-fixed sh)
      (define u (list 'reg (operand-shape-fixed sh)))
      (case action
        [(r cr) (set! uses (cons u uses))]
        [(w cw) (set! defs (cons u defs))]
        [(rw crw rcw) (set! uses (cons u uses)) (set! defs (cons u defs))]
        [else (void)])))
  (define fl (form-flags form))
  (define toks (if fl (string-split (symbol->string fl)) '()))
  (define (flag-of tok) (string->symbol (car (string-split tok "-"))))
  (define fr (for/list ([t toks] #:when (regexp-match? #rx"-tst$" t)) (flag-of t)))
  (define fw (for/list ([t toks] #:when (regexp-match? #rx"-(mod|u|0|1|pop|ah)$" t)) (flag-of t)))
  (values (reverse uses) (reverse defs) (remove-duplicates fr) (remove-duplicates fw)))
