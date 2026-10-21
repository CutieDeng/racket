#lang racket/base
;; Register allocation for the x86-64 kernel DSL: virtual registers
;; (q./d./w./b.name, xmm./ymm./zmm.name, k.name) -> physical registers.
;;
;; Instruction-level liveness over the function's control flow (labels and
;; jumps), an interference graph that includes the physical registers the body
;; names explicitly or implicitly (so a vreg never lands on xmm0 while xmm0
;; carries sha256rnds2's implicit operand), copy coalescing (Briggs / George),
;; Chaitin-Briggs simplify-select with spilling: when select finds no colour, the
;; longest-lived, least-used value at the pressure point goes to a frame slot (loads
;; before each use into a short-lived temporary, stores after each definition) and
;; the allocation is redone; the emitter sizes the frame for the spill area.
;;
;; Precoloring: `in:` vregs take the SysV argument registers by position
;; (rdi rsi rdx rcx r8 r9), `out:` the first takes rax, `inout:` like `in:`
;; continuing the argument positions. A vreg keeps one physical register for
;; the whole function (no live-range splitting).
;;
;; Deterministic by construction: node order is first appearance in the body,
;; never hash iteration order, so regeneration is byte-stable.
(require racket/list racket/match racket/string "parse.rkt" "spec.rkt")
(provide allocate-fn (struct-out alloc-result))
(require racket/function)

(struct alloc-result (fn mapping [spills #:auto]) #:transparent #:mutable)   ; mapping: (listof (cons name phys-base))
(struct spill-request (name cls) #:transparent)   ; raised by the colouring when a value must go to memory
(struct precolor-request (name kind phys) #:transparent)   ; an argument/result that cannot stay in its ABI register

;; ---------------------------------------------------------------- pools
(define gpr-pool '(rax rcx rdx rsi rdi r8 r9 r10 r11 rbx r12 r13 r14 r15 rbp))
(define vec-pool (for/list ([i 16]) (string->symbol (format "xmm~a" i))))
(define vec-pool-avx512 (for/list ([i 32]) (string->symbol (format "xmm~a" i))))   ; xmm16-31 only under pressure
(define k-pool '(k1 k2 k3 k4 k5 k6 k7))
(define sysv-gpr-args '(rdi rsi rdx rcx r8 r9))
(define caller-saved-gprs '(rax rcx rdx rsi rdi r8 r9 r10 r11))
(define call-clobbers
  (append caller-saved-gprs (for/list ([i 32]) (string->symbol (format "xmm~a" i))) '(k0 k1 k2 k3 k4 k5 k6 k7)))
(define current-vec-pool (make-parameter vec-pool))
(define (pool-of cls) (case cls [(gpr) gpr-pool] [(vec) (current-vec-pool)] [(k) k-pool]))

;; ---------------------------------------------------------------- keys
;; A node is a symbol: physical base name (rax, xmm3, k2) or 'v:<name> for a vreg.
(define (vreg-key name) (string->symbol (format "v:~a" name)))
(define (vreg-key? k) (regexp-match? #rx"^v:" (symbol->string k)))
(define (vreg-key-name k) (string->symbol (substring (symbol->string k) 2)))
(define (phys-base n)
  ;; any view name -> allocation base: gpr64 name, xmmN, kN; #f for rsp/rip/other
  (define i (reg-name-info n))
  (and i
       (case (car i)
         [(gpr) (let ([b (list-ref gpr64-names (caddr i))]) (and (not (eq? b 'rsp)) b))]
         [(xmm ymm zmm) (string->symbol (format "xmm~a" (caddr i)))]
         [(k) n]
         [else #f])))
(define (vreg-class cls) (case cls [(gpr) 'gpr] [(xmm ymm zmm) 'vec] [(k) 'k]))
(define (operand-key u)
  (match u
    [(list* 'reg n _) (phys-base n)]
    [(list* 'vreg cls name _) (vreg-key name)]
    [_ #f]))

;; registers read through a memory operand's address
(define (mem-regs u)
  (match u
    [(list 'mem base index _ _ _ _ _) (filter values (map operand-key (filter values (list base index))))]
    [_ '()]))

;; ---------------------------------------------------------------- per-instruction use/def
(define jumps '(jmp jo jno jb jc jnae jae jnb jnc je jz jne jnz jbe jna ja jnbe js jns jp jpe jnp jpo jl jnge jge jnl jle jng jg jnle jrcxz jecxz))   ; a call falls through
(define copy-mnemonics '(mov movdqa movdqu movaps movups movapd movupd vmovdqa vmovdqu vmovdqa32 vmovdqa64 vmovdqu32 vmovdqu64 vmovaps vmovups vmovapd vmovupd kmovb kmovw kmovd kmovq))

;; -> (values uses defs copy?)   uses/defs: lists of node keys (deduplicated, in operand order)
(define (instr-uses/defs x)
  (define mn (instr-mnemonic x))
  (define ops (instr-ops x))
  (cond
    [(eq? mn '.directive) (values '() '() #f)]
    ;; .call: the argument registers were loaded by the moves inserted before it; the call reads
    ;; them and clobbers every caller-saved register (the result arrives in rax)
    [(and (eq? mn 'call) (pair? ops) (eq? (car (car ops)) 'label))
     (define nargs (let ([m (regexp-match #rx"^call ([0-9]+)$" (instr-text x))]) (if m (string->number (cadr m)) 0)))
     (values (take sysv-gpr-args nargs) call-clobbers #f)]
    [(and (memq mn jumps) (= 1 (length ops)) (eq? (car (car ops)) 'label)) (values '() '() #f)]
    [else
     (define f (or (match-form mn ops) (error 'x86-regalloc "line ~a: no form for ~a" (instr-line x) (instr-text x))))
     (define-values (u d fr fw) (instr-use-def f ops))
     (define (keys l) (remove-duplicates (filter values (append (map operand-key l) (append-map mem-regs l)))))
     ;; zeroing idioms (xor r, r / sub r, r / pxor x, x ...) define their register without reading it
     (define zeroing?
       (and (memq mn '(xor sub pxor xorps xorpd vpxor vpxord vpxorq vxorps vxorpd))
            (= 2 (length ops)) (operand-key (car ops))
            (equal? (operand-key (car ops)) (operand-key (cadr ops)))
            (not (and (pair? (car ops)) (eq? (car (car ops)) 'mem)))))
     (define zeroing3?   ; vpxorq d, s, s and friends
       (and (memq mn '(vpxor vpxord vpxorq vxorps vxorpd))
            (= 3 (length ops)) (operand-key (cadr ops))
            (equal? (operand-key (cadr ops)) (operand-key (caddr ops)))))
     ;; a memory operand that is "defined" only writes memory: its address registers are uses
     (define uses0 (remove-duplicates (append (keys u) (append-map mem-regs d))))
     (define uses (cond [zeroing? (remove (operand-key (car ops)) uses0)]
                        [zeroing3? (remove (operand-key (cadr ops)) uses0)]
                        [else uses0]))
     (define defs (remove-duplicates (filter values (map operand-key (filter (lambda (o) (not (and (pair? o) (eq? (car o) 'mem)))) d)))))
     (define copy? (and (memq mn copy-mnemonics) (= 2 (length ops))
                        (operand-key (car ops)) (operand-key (cadr ops))
                        (not (eq? (operand-key (car ops)) (operand-key (cadr ops))))
                        ;; same width on both sides (no zero/sign-extending copies)
                        (let ([w (lambda (o) (match o [(list* 'reg n _) (cadr (reg-name-info n))]
                                                         [(list* 'vreg cls _ view _) (case view [(q) 64] [(d) 32] [(w) 16] [(b) 8] [(xmm) 128] [(ymm) 256] [(zmm) 512] [(k) 64])]))])
                          (= (w (car ops)) (w (cadr ops))))))
     (values uses defs copy?)]))

;; ---------------------------------------------------------------- liveness
;; .call NAME(a, b, ...): materialise the arguments in the SysV registers right before the call
;; (a register argument is moved, a memory operand's address is taken with lea); the call
;; instruction itself keeps only the label so the emitter prints `call NAME@PLT`.
(define (expand-calls body)
  (append*
   (for/list ([x body])
     (cond
       [(and (instr? x) (eq? (instr-mnemonic x) 'call) (pair? (instr-ops x)) (eq? (car (car (instr-ops x))) 'label))
        (define args (cdr (instr-ops x)))
        (define tmps (for/list ([a args] [i (in-naturals)]) (list 'vreg 'gpr (string->symbol (format "~~ca~a_~a" (instr-line x) i)) 'q)))
        (append
         ;; every argument into a temporary first, so an argument that reads an ABI register
         ;; (an incoming parameter) is not clobbered by an earlier move
         (for/list ([a args] [t tmps])
           (if (and (pair? a) (eq? (car a) 'mem))
               (instr 'lea (list t (list 'mem (list-ref a 1) (list-ref a 2) (list-ref a 3) (list-ref a 4) (list-ref a 5) #f '())) "call argument" (instr-line x))
               (instr 'mov (list t a) "call argument" (instr-line x))))
         (for/list ([t tmps] [r sysv-gpr-args])
           (instr 'mov (list (list 'reg r) t) "call argument" (instr-line x)))
         (list (instr 'call (list (car (instr-ops x))) (format "call ~a" (length args)) (instr-line x))))]
       [else (list x)]))))

(define (allocate-fn f)
  (parameterize ([current-vec-pool (if (eq? (fn-simd f) 'avx512) vec-pool-avx512 vec-pool)])
    ;; spill loop: each round that fails to colour names one value to move to the frame
    (let loop ([body (vector->list (rename-webs (list->vector (expand-calls (fn-body f))) (fn-ins f) (fn-outs f) (fn-inouts f)))]
               [spilled '()] [bytes 0] [rounds 0] [moved '()])
      (define g (fn (fn-name f) (fn-export? f) (fn-ins f) (fn-outs f) (fn-inouts f) body (fn-save f) (fn-line f)))
      (set-fn-simd! g (fn-simd f))   ; #:auto fields are not constructor arguments
      (set-fn-frame! g (fn-frame f))
      (define r (with-handlers ([spill-request? values] [precolor-request? values]) (allocate-fn* g moved)))
      (cond
        [(alloc-result? r)
         (set-fn-spill! (alloc-result-fn r) bytes)
         (set-alloc-result-spills! r (reverse spilled))
         r]
        [(> rounds 100) (error 'x86-regalloc "~a: still out of registers after ~a spills" (fn-name f) rounds)]
        [(precolor-request? r)
         ;; the parameter (or result) lives across a redefinition of its ABI register (a .call, an
         ;; explicit use): copy it out at entry (or into the register before every ret) instead
         (define name (precolor-request-name r)) (define phys (precolor-request-phys r))
         (define body*
           (case (precolor-request-kind r)
             [(in) (cons (instr 'mov (list (list 'vreg 'gpr name 'q) (list 'reg phys)) "parameter copy" (fn-line f)) body)]
             [else (append*
                    (for/list ([x body])
                      (if (and (instr? x) (eq? (instr-mnemonic x) 'ret))
                          (list (instr 'mov (list (list 'reg phys) (list 'vreg 'gpr name 'q)) "result copy" (instr-line x)) x)
                          (list x))))]))
         (loop body* spilled bytes (add1 rounds) (cons name moved))]
        [else
         ;; vector width: the widest view the body gives the value (zmm under .simd avx512 regardless,
         ;; so the slot layout stays 64-byte); VEX moves once any v-prefixed instruction is present
         (define (view-width v) (case v [(xmm) 16] [(ymm) 32] [(zmm) 64] [else 0]))
         (define width
           (if (eq? (fn-simd f) 'avx512) 64
               (max 16 (for*/fold ([w 0]) ([x body] #:when (instr? x) [o (instr-ops x)])
                         (match o [(list* 'vreg _ nm v _) (if (eq? nm (spill-request-name r)) (max w (view-width v)) w)] [_ w])))))
         (define vex? (for/or ([x body]) (and (instr? x) (regexp-match? #rx"^v" (symbol->string (instr-mnemonic x))))))
         (define size (case (spill-request-cls r) [(gpr) 8] [(k) 8] [else width]))
         (define off (* size (quotient (+ bytes size -1) size)))   ; align the slot to its size
         (loop (spill-vreg body (spill-request-name r) (spill-request-cls r) off width vex?)
               (cons (cons (spill-request-name r) off) spilled) (+ off size) (add1 rounds) moved)]))))

;; ---------------------------------------------------------------- spill rewriting
;; Every instruction that mentions `name` gets a fresh temporary for it: a load from the slot
;; before (when it reads), a store after (when it writes). Loads and stores are plain moves,
;; which leave the flags alone, so adc/adox chains survive.
(define (spill-vreg body name cls off [width 64] [vex? #t])
  (define key (vreg-key name))
  (define counter 0)
  (define (mentions? u)
    (match u
      [(list* 'vreg _ n _) (eq? n name)]
      [(list 'mem base index _ _ _ _ decor) (or (and base (mentions? base)) (and index (mentions? index)) (ormap mentions? (map cdr (filter (lambda (d) (eq? (car d) 'mask)) decor))))]
      [(list 'reg _ decor) (ormap mentions? (map cdr (filter (lambda (d) (eq? (car d) 'mask)) decor)))]
      [_ #f]))
  (define (rename u tmp)
    (match u
      [(list 'vreg c n v) (if (eq? n name) (list 'vreg c tmp v) u)]
      [(list 'vreg c n v d) (list 'vreg c (if (eq? n name) tmp n) v (map (lambda (x) (rename-decor x tmp)) d))]
      [(list 'reg n d) (list 'reg n (map (lambda (x) (rename-decor x tmp)) d))]
      [(list 'mem base index scale disp sym size decor)
       (list 'mem (and base (rename base tmp)) (and index (rename index tmp)) scale disp sym size (map (lambda (x) (rename-decor x tmp)) decor))]
      [_ u]))
  (define (rename-decor d tmp) (match d [(list 'mask r) (list 'mask (rename r tmp))] [_ d]))
  (define slot (lambda (size) (list 'mem (list 'reg 'rsp) #f 1 off '__spill size '())))
  ;; a vector value is moved at the widest view the function gives it: 16 bytes with movdqu (vmovdqu
  ;; once the function is VEX/EVEX code), 32 with vmovdqu ymm, 64 with vmovdqu64 zmm
  (define-values (vmn vview vsize)
    (case width
      [(16) (values (if vex? 'vmovdqu 'movdqu) 'xmm 'xmmword)]
      [(32) (values 'vmovdqu 'ymm 'ymmword)]
      [else (values 'vmovdqu64 'zmm 'zmmword)]))
  (define (load-instr tmp line)
    (case cls
      [(gpr) (instr 'mov (list (list 'vreg 'gpr tmp 'q) (slot 'qword)) "spill load" line)]
      [(k) (instr 'kmovq (list (list 'vreg 'k tmp 'k) (slot 'qword)) "spill load" line)]
      [else (instr vmn (list (list 'vreg vview tmp vview) (slot vsize)) "spill load" line)]))
  (define (store-instr tmp line)
    (case cls
      [(gpr) (instr 'mov (list (slot 'qword) (list 'vreg 'gpr tmp 'q)) "spill store" line)]
      [(k) (instr 'kmovq (list (slot 'qword) (list 'vreg 'k tmp 'k)) "spill store" line)]
      [else (instr vmn (list (slot vsize) (list 'vreg vview tmp vview)) "spill store" line)]))
  (append*
   (for/list ([x body])
     (cond
       [(and (instr? x) (not (eq? (instr-mnemonic x) '.directive)) (ormap mentions? (instr-ops x)))
        (define-values (uses defs copy?) (instr-uses/defs x))
        (set! counter (add1 counter))
        (define tmp (string->symbol (format "~a~~sp~a" name counter)))
        (define y (instr (instr-mnemonic x) (map (lambda (u) (rename u tmp)) (instr-ops x)) (instr-text x) (instr-line x)))
        (append (if (memq key uses) (list (load-instr tmp (instr-line x))) '())
                (list y)
                (if (memq key defs) (list (store-instr tmp (instr-line x))) '()))]
       [else (list x)]))))
;; ---------------------------------------------------------------- def-use webs
;; A virtual register name reused for unrelated values (a scratch name in two phases of a loop
;; body) would otherwise be one allocation node interfering with the union of both phases' live
;; sets. Reaching definitions split each name into its def-use webs: definitions joined through a
;; shared use, and a read-modify-write instruction joining its own definition with the ones its
;; read sees. Every web but the first (the one holding the entry definition of a parameter, or a
;; result's web that reaches ret) gets a fresh name `name~wK`, and the webs are allocated
;; independently. Runs once, before the spill rounds.
(define (rename-webs body ins outs inouts)
  (define n (vector-length body))
  (define label-index (for/hasheq ([x (in-vector body)] [i (in-naturals)] #:when (label? x)) (values (label-name x) i)))
  (define (succs i)
    (define x (vector-ref body i))
    (cond
      [(label? x) (if (< (add1 i) n) (list (add1 i)) '())]
      [(eq? (instr-mnemonic x) 'ret) '()]
      [(and (memq (instr-mnemonic x) jumps) (= 1 (length (instr-ops x))) (eq? (car (car (instr-ops x))) 'label))
       (define t (hash-ref label-index (cadr (car (instr-ops x)))))
       (if (eq? (instr-mnemonic x) 'jmp) (list t) (append (if (< (add1 i) n) (list (add1 i)) '()) (list t)))]
      [else (if (< (add1 i) n) (list (add1 i)) '())]))
  (define uses (make-vector n '())) (define defs (make-vector n '()))
  (for ([i n])
    (define x (vector-ref body i))
    (when (and (instr? x) (not (eq? (instr-mnemonic x) '.directive)))
      (define-values (u d c) (instr-uses/defs x))
      (vector-set! uses i (filter vreg-key? u)) (vector-set! defs i (filter vreg-key? d))))
  (define in-keys (remove-duplicates (filter values (map operand-key (append ins inouts)))))
  (define out-keys (remove-duplicates (filter values (map operand-key (append outs inouts)))))
  ;; reaching definitions per key as a bit set of definition sites: bit 0 = the entry, bit s+1 = instruction s
  (define (site-bit s) (arithmetic-shift 1 (add1 s)))
  (define (sites-of mask) (for/list ([b (in-range (integer-length mask))] #:when (bitwise-bit-set? mask b)) (sub1 b)))
  (define entry (for/hasheq ([k in-keys]) (values k (site-bit -1))))
  (define (transfer i in) (for/fold ([h in]) ([d (vector-ref defs i)]) (hash-set h d (site-bit i))))
  (define preds (make-vector n '()))
  (for ([i n]) (for ([s (succs i)]) (vector-set! preds s (cons i (vector-ref preds s)))))
  (define rd-in (make-vector n (hasheq)))
  (let loop ()
    (define changed #f)
    (for ([i n])
      (define in
        (for/fold ([h (if (= i 0) entry (hasheq))]) ([p (vector-ref preds i)])
          (for/fold ([h h]) ([(k m) (in-hash (transfer p (vector-ref rd-in p)))])
            (hash-set h k (bitwise-ior m (hash-ref h k 0))))))
      (unless (equal? in (vector-ref rd-in i)) (set! changed #t) (vector-set! rd-in i in)))
    (when changed (loop)))
  (define (reaching i k) (sites-of (hash-ref (vector-ref rd-in i) k 0)))
  ;; union-find over (key . site)
  (define parent (make-hash))
  (define (find x) (define p (hash-ref parent x x)) (if (equal? p x) x (let ([r (find p)]) (hash-set! parent x r) r)))
  (define (union! a b) (define ra (find a)) (define rb (find b)) (unless (equal? ra rb) (hash-set! parent ra rb)))
  (define (join! k sites) (for ([s (cdr sites)]) (union! (cons k (car sites)) (cons k s))))
  (for ([i n])
    (define x (vector-ref body i))
    (define d (vector-ref defs i))
    (for ([k (vector-ref uses i)])
      (define sites (reaching i k))
      (when (pair? sites)
        (join! k sites)
        (when (memq k d) (union! (cons k i) (cons k (car sites)))))) ; read-modify-write: one web
    (when (and (instr? x) (eq? (instr-mnemonic x) 'ret))
      ;; results: everything that reaches any ret is one web (it ends in the ABI register either
      ;; way); an in/out parameter's entry web joins it
      (for ([k out-keys])
        (define sites (reaching i k))
        (when (pair? sites)
          (join! k sites)
          (union! (cons k 'ret) (cons k (car sites)))
          (when (memq k in-keys) (union! (cons k -1) (cons k (car sites))))))))
  ;; naming: the parameter's entry web and the result's ret web keep the plain name, so does the
  ;; first web met of any other name; later webs get name~wK
  (define web-name (make-hash))
  (define counter (make-hasheq))
  (define (name-of k site)
    (define root (find (cons k site)))
    (hash-ref! web-name root
               (lambda ()
                 (define c (hash-ref counter k 0))
                 (hash-set! counter k (add1 c))
                 (if (= c 0) (vreg-key-name k) (string->symbol (format "~a~~w~a" (vreg-key-name k) c))))))
  (for ([k in-keys]) (name-of k -1))
  (for ([k out-keys]) (unless (memq k in-keys) (name-of k 'ret)))
  ;; mask decorators ({k.m}) read their register: rename them as uses wherever they appear
  (define (rename-decors d i) (for/list ([x d]) (match x [(list 'mask r) (list 'mask (rename r i 'use))] [_ x])))
  (define (rename o i mode)   ; mode: 'def = this instruction's definition, 'use = the reaching web
    (match o
      [(list 'vreg cls name view decor)
       (define k (vreg-key name))
       (define site (if (eq? mode 'def) i (let ([s (reaching i k)]) (and (pair? s) (car s)))))
       (list 'vreg cls (if site (name-of k site) name) view (rename-decors decor i))]
      [(list 'vreg cls name view)
       (define k (vreg-key name))
       (define site (if (eq? mode 'def) i (let ([s (reaching i k)]) (and (pair? s) (car s)))))
       (if site (list 'vreg cls (name-of k site) view) o)]
      [(list 'reg n decor) (list 'reg n (rename-decors decor i))]
      [(list 'mem base index a b c d decor)
       (list 'mem (and base (rename base i 'use)) (and index (rename index i 'use)) a b c d (rename-decors decor i))]
      [_ o]))
  (for/vector ([x (in-vector body)] [i (in-naturals)])
    (if (and (instr? x) (not (eq? (instr-mnemonic x) '.directive)))
        (let ([d (vector-ref defs i)])
          (instr (instr-mnemonic x)
                 (for/list ([o (instr-ops x)])
                   (match o
                     [(list* 'vreg cls name rest) (rename o i (if (memq (vreg-key name) d) 'def 'use))]
                     [_ (rename o i 'use)]))
                 (instr-text x) (instr-line x)))
        x)))

(define (allocate-fn* f [moved '()])
  (define body (list->vector (fn-body f)))
  (define n (vector-length body))
  ;; vreg classes + first-appearance order; view consistency
  (define vclass (make-hasheq))
  (define order '())
  (define (note-vreg! cls name line)
    (define c (vreg-class cls))
    (define k (vreg-key name))
    (define prev (hash-ref vclass k #f))
    (when (and prev (not (eq? prev c)))
      (error 'x86-regalloc "line ~a: virtual register ~a used as both ~a and ~a" line name prev c))
    (unless prev (hash-set! vclass k c) (set! order (cons k order))))
  (for ([x (in-vector body)] #:when (instr? x))
    (let walk ([ops (instr-ops x)])
      (for ([u ops])
        (match u
          [(list* 'vreg cls name _) (note-vreg! cls name (instr-line x))]
          [(list 'mem base index _ _ _ _ _) (walk (filter values (list base index)))]
          [_ (void)]))))
  (for ([r (append (fn-ins f) (fn-outs f) (fn-inouts f))])
    (match r [(list* 'vreg cls name _) (note-vreg! cls name (fn-line f))] [_ (void)]))
  (set! order (reverse order))
  ;; precoloring from the signature
  (define precolor (make-hasheq))
  (define (precolor! r phys)
    (match r
      [(list* 'vreg cls name _)
       (define k (vreg-key name))
       (unless (eq? (hash-ref vclass k) (if (memq phys gpr-pool) 'gpr 'vec))
         (error 'x86-regalloc "signature register ~a cannot take ~a" name phys))
       (hash-set! precolor k phys)]
      [_ (void)]))
  (define (moved? r) (match r [(list* 'vreg _ name _) (memq name moved)] [_ #f]))
  (for ([r (append (fn-ins f) (fn-inouts f))] [p sysv-gpr-args]) (unless (moved? r) (precolor! r p)))
  (for ([r (fn-outs f)] [p '(rax)]) (unless (moved? r) (precolor! r p)))
  (when (> (length (append (fn-ins f) (fn-inouts f))) (length sysv-gpr-args))
    (error 'x86-regalloc "~a: more than ~a register arguments" (fn-name f) (length sysv-gpr-args)))
  ;; control flow
  (define label-index (for/hasheq ([x (in-vector body)] [i (in-naturals)] #:when (label? x)) (values (label-name x) i)))
  (define (succs i)
    (define x (vector-ref body i))
    (cond
      [(label? x) (if (< (add1 i) n) (list (add1 i)) '())]
      [(eq? (instr-mnemonic x) 'ret) '()]
      [(and (memq (instr-mnemonic x) jumps) (= 1 (length (instr-ops x))) (eq? (car (car (instr-ops x))) 'label))
       (define t (hash-ref label-index (cadr (car (instr-ops x)))))
       (if (eq? (instr-mnemonic x) 'jmp) (list t) (append (if (< (add1 i) n) (list (add1 i)) '()) (list t)))]
      [else (if (< (add1 i) n) (list (add1 i)) '())]))
  (define uses (make-vector n '())) (define defs (make-vector n '())) (define copies (make-vector n #f))
  (for ([i n])
    (define x (vector-ref body i))
    (when (instr? x)
      (define-values (u d c) (instr-uses/defs x))
      (vector-set! uses i u) (vector-set! defs i d) (vector-set! copies i c)
      ;; function exit: outputs are live
      (when (eq? (instr-mnemonic x) 'ret)
        (vector-set! uses i (remove-duplicates (append u (filter values (map operand-key (append (fn-outs f) (fn-inouts f))))))))))
  (define live-in (make-vector n '())) (define live-out (make-vector n '()))
  (define (set-union a b) (remove-duplicates (append a b)))
  (let loop ()
    (define changed #f)
    (for ([i (in-range (sub1 n) -1 -1)])
      (define out (for/fold ([acc '()]) ([s (succs i)]) (set-union acc (vector-ref live-in s))))
      (define in (set-union (vector-ref uses i) (filter (lambda (k) (not (memq k (vector-ref defs i)))) out)))
      (unless (and (= (length out) (length (vector-ref live-out i))) (= (length in) (length (vector-ref live-in i))))
        (set! changed #t))
      (vector-set! live-out i out) (vector-set! live-in i in))
    (when changed (loop)))
  ;; arguments live at entry must be precolored (physical in: regs are physical anyway)
  ;; interference graph
  (define adj (make-hasheq))   ; node -> list of neighbours (no duplicates)
  (define (add-edge! a b)
    (unless (eq? a b)
      (unless (memq b (hash-ref adj a '())) (hash-set! adj a (cons b (hash-ref adj a '()))))
      (unless (memq a (hash-ref adj b '())) (hash-set! adj b (cons a (hash-ref adj b '()))))))
  (define (node-class k) (if (vreg-key? k) (hash-ref vclass k) (cond [(memq k gpr-pool) 'gpr] [(memq k k-pool) 'k] [(eq? k 'k0) 'k] [else 'vec])))
  (define (same-class? a b) (eq? (node-class a) (node-class b)))
  (for ([i n])
    (define x (vector-ref body i))
    (when (instr? x)
      (define src (and (vector-ref copies i) (operand-key (cadr (instr-ops x)))))
      (for ([d (vector-ref defs i)])
        (for ([l (append (vector-ref live-out i) (vector-ref defs i))]
              #:when (and (not (eq? l d)) (same-class? l d) (not (eq? l src))))
          (add-edge! d l)))))
  ;; precolored vregs interfere like their physical register: merge them with it below
  ;; nodes to colour, in first-appearance order
  (define pressure-note
    (lambda (k)
      (define cls (hash-ref vclass k))
      (define worst (for/fold ([best #f]) ([i n])
        (define c (length (filter (lambda (l) (eq? (node-class l) cls)) (vector-ref live-out i))))
        (if (or (not best) (> c (cdr best))) (cons i c) best)))
      (format "~a ~a registers live after line ~a (pool ~a): ~a" (cdr worst) cls
              (let ([x (vector-ref body (car worst))]) (if (instr? x) (instr-line x) (label-line x)))
              (length (pool-of cls))
              (for/list ([l (vector-ref live-out (car worst))] #:when (eq? (node-class l) cls))
                (if (vreg-key? l) (vreg-key-name l) l)))))
  ;; ---- coalescing (union-find over vreg nodes; a vreg may be merged into a physical register)
  (define alias (make-hasheq))
  (define (find k) (let ([a (hash-ref alias k #f)]) (if a (find a) k)))
  (define (neighbours k) (remove-duplicates (map find (hash-ref adj k '()))))
  (define (degree k) (length (filter (lambda (m) (not (eq? m k))) (neighbours k))))
  (define (K k) (length (pool-of (node-class k))))
  (define (fixed? k) (or (not (vreg-key? k)) (hash-ref precolor k #f)))
  (define (fixed-color k) (if (vreg-key? k) (hash-ref precolor k #f) k))
  (define (merge! a b) ; b into a
    (hash-set! alias b a)
    (hash-set! adj a (remove-duplicates (append (hash-ref adj a '()) (hash-ref adj b '())))))
  ;; precolored vregs become their physical register
  (for ([k order] #:when (hash-ref precolor k #f))
    (define p (hash-ref precolor k))
    (when (memq p (neighbours k))
      (raise (precolor-request (vreg-key-name k) (if (memq (list 'vreg 'gpr (vreg-key-name k) 'q) (fn-outs f)) 'out 'in) p)))
    (merge! p k))
  (define (significant? k) (>= (degree k) (K k)))
  (define (try-coalesce!)
    (for ([i n])
      (when (vector-ref copies i)
        (define x (vector-ref body i))
        (define a (find (operand-key (car (instr-ops x)))))
        (define b (find (operand-key (cadr (instr-ops x)))))
        (when (and (not (eq? a b)) (same-class? a b) (not (memq b (neighbours a)))
                   (or (vreg-key? a) (vreg-key? b)))
          (define-values (keep drop) (if (vreg-key? b) (values a b) (values b a)))
          (define ok?
            (if (fixed? keep)
                ;; George: every neighbour t of drop is either already a neighbour of keep or insignificant
                (for/and ([t (neighbours drop)] #:unless (eq? t keep))
                  (or (memq t (neighbours keep)) (not (significant? t))))
                ;; Briggs: the merged node has fewer than K significant neighbours
                (< (length (filter significant? (remove-duplicates (append (neighbours keep) (neighbours drop)))))
                   (K keep))))
          (when ok? (merge! keep drop))))))
  (try-coalesce!)
  ;; ---- simplify / select over the remaining vreg representatives
  (define nodes (remove-duplicates (map find (filter (lambda (k) (not (fixed? (find k)))) order))))
  (define removed (make-hasheq))
  (define (live-degree k) (length (filter (lambda (m) (not (hash-ref removed m #f))) (neighbours k))))
  (define stack
    (let loop ([acc '()])
      (define left (filter (lambda (k) (not (hash-ref removed k #f))) nodes))
      (cond
        [(null? left) acc]
        [else
         (define pick (or (for/first ([k left] #:when (< (live-degree k) (K k))) k)
                          ;; optimistic: push the highest-degree node and hope select finds a colour
                          (argmax live-degree left)))
         (hash-set! removed pick #t)
         (loop (cons pick acc))])))
  (define color (make-hasheq))
  (define (color-of k) (or (fixed-color k) (hash-ref color k #f)))
  (for ([k stack])
    (define taken (filter values (map color-of (neighbours k))))
    (define c (for/first ([p (pool-of (node-class k))] #:unless (memq p taken)) p))
    (unless c
      ;; pick the value to spill: among k and its neighbours (not fixed, not already a spill
      ;; temporary), the one live across the most instructions per mention
      (define cands (filter (lambda (m) (and (vreg-key? m) (not (fixed? m))
                                             (not (regexp-match? #rx"~sp[0-9]+$" (symbol->string m)))))
                            (cons k (neighbours k))))
      (define (live-count m) (for/sum ([i n]) (if (memq m (vector-ref live-out i)) 1 0)))
      (define (mentions m) (for/sum ([i n]) (if (or (memq m (vector-ref uses i)) (memq m (vector-ref defs i))) 1 0)))
      (define victim
        (and (pair? cands)
             (argmax (lambda (m) (/ (add1 (live-count m)) (add1 (mentions m)))) cands)))
      (unless victim
        (error 'x86-regalloc "~a: out of ~a registers for ~a and nothing left to spill: ~a" (fn-name f) (node-class k) (vreg-key-name k) (pressure-note k)))
      (raise (spill-request (vreg-key-name victim) (node-class victim))))
    (hash-set! color k c))
  ;; ---- rewrite
  (define mapping (for/list ([k order]) (cons (vreg-key-name k) (color-of (find k)))))
  (define (phys-view base view)
    (define i (reg-name-info base))
    (case view
      [(q) base]
      [(d) (list-ref '(eax ecx edx ebx esp ebp esi edi r8d r9d r10d r11d r12d r13d r14d r15d) (caddr i))]
      [(w) (list-ref '(ax cx dx bx sp bp si di r8w r9w r10w r11w r12w r13w r14w r15w) (caddr i))]
      [(b) (list-ref '(al cl dl bl spl bpl sil dil r8b r9b r10b r11b r12b r13b r14b r15b) (caddr i))]
      [(xmm) base]
      [(ymm) (string->symbol (format "ymm~a" (caddr i)))]
      [(zmm) (string->symbol (format "zmm~a" (caddr i)))]
      [(k) base]))
  (define (rw-decor d) (match d [(list 'mask r) (list 'mask (rw r))] [_ d]))
  (define (rw u)
    (match u
      [(list 'vreg cls name view) (list 'reg (phys-view (color-of (find (vreg-key name))) view))]
      [(list 'vreg cls name view decor) (list 'reg (phys-view (color-of (find (vreg-key name))) view) (map rw-decor decor))]
      [(list 'reg n decor) (list 'reg n (map rw-decor decor))]
      [(list 'mem base index scale disp sym size decor) (list 'mem (and base (rw base)) (and index (rw index)) scale disp sym size (map rw-decor decor))]
      [_ u]))
  ;; coalesced copies (same physical register on both sides) disappear
  (define new-body
    (for/list ([x (in-vector body)] [i (in-naturals)]
               #:unless (and (instr? x) (vector-ref copies i)
                             (equal? (rw (car (instr-ops x))) (rw (cadr (instr-ops x))))))
      (if (instr? x) (instr (instr-mnemonic x) (map rw (instr-ops x)) (instr-text x) (instr-line x)) x)))
  (define out (fn (fn-name f) (fn-export? f) (map rw (fn-ins f)) (map rw (fn-outs f)) (map rw (fn-inouts f)) new-body (fn-save f) (fn-line f)))
  (set-fn-simd! out (fn-simd f))
  (set-fn-frame! out (fn-frame f))
  (set-fn-spill! out (fn-spill f))
  (alloc-result out mapping))
