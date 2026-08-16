#lang racket

;; ============================================================
;; semantic/public-abi.rkt - public ABI profile checks
;; ============================================================
;;
;; Public profiles describe what external callers observe. Internal ABI names
;; can still be used on private functions and IPA clones, but an explicitly
;; profiled public root should not directly claim a private managed ABI.

(require "control-flow.rkt"
         "../parser/ast.rkt"
         racket/intmap)

(provide
 (struct-out public-abi-error)
 (struct-out public-abi-profile-spec)
 public-abi-profile-specs
 public-abi-profile-spec-ref
 public-abi-manifest
 write-public-abi-manifest
 public-c-header
 write-public-c-header
 check-public-abi-profiles
 format-public-abi-error)

(struct public-abi-error
  (function-name profile abi-name location reason)
  #:transparent)

(struct public-abi-profile-spec
  (name allowed-entry-abis requires-explicit-abi? description)
  #:transparent)

(define ordinary-entry-abis '(aapcs64 arm64 leaf naked))

(define public-abi-profile-specs
  (list
   (public-abi-profile-spec
    'c-aapcs64
    ordinary-entry-abis
    #f
    "portable C/AAPCS64 function entry")
   (public-abi-profile-spec
    'apple-c-arm64
    ordinary-entry-abis
    #f
    "Apple arm64 C function entry")
   (public-abi-profile-spec
    'linux-syscall
    ordinary-entry-abis
    #f
    "freestanding Linux syscall-style entry")
   (public-abi-profile-spec
    'kernel-aarch64
    ordinary-entry-abis
    #f
    "kernel or firmware entry")
   (public-abi-profile-spec
    'jit-private
    #f
    #t
    "runtime-generated code entry with an explicit project ABI")
   (public-abi-profile-spec
    'project-abi
    #f
    #t
    "application-specific public ABI entry")))

(define (public-abi-profile-spec-ref profile)
  (for/first ([spec (in-list public-abi-profile-specs)]
              #:when (eq? profile (public-abi-profile-spec-name spec)))
    spec))

(define (entry-abi-allowed? spec abi-name)
  (define allowed (public-abi-profile-spec-allowed-entry-abis spec))
  (or (not allowed)
      (not abi-name)
      (if (memq abi-name allowed) #t #f)))

(define (explicit-public-profile? fn)
  (fn-get-info fn 'public-abi-profile-explicit? #f))

(define (check-public-function fn)
  (define profile (fn-public-abi-profile fn))
  (define abi-name (fn-get-info fn 'abi #f))
  (define spec (and profile (public-abi-profile-spec-ref profile)))
  (cond
    [(not (fn-public-abi-root? fn)) #f]
    [(not (explicit-public-profile? fn)) #f]
    [(and spec
          (public-abi-profile-spec-requires-explicit-abi? spec)
          (not abi-name))
     (public-abi-error
      (asm-function-name fn)
      profile
      abi-name
      (fn-get-info fn 'function-loc #f)
      (format "profile ~a requires an explicit function abi=<name> to define its external calling contract"
              profile))]
    [(and spec
          (not (entry-abi-allowed? spec abi-name)))
     (public-abi-error
      (asm-function-name fn)
      profile
      abi-name
      (fn-get-info fn 'function-loc #f)
      (format "profile ~a expects an ordinary entry ABI (~a); put private ABIs on internal functions or IPA clones"
              profile
              (string-join
               (map symbol->string
                    (public-abi-profile-spec-allowed-entry-abis spec))
               ", ")))]
    [else #f]))

(define (check-public-abi-profiles cfg)
  (reverse
   (for/fold ([errors '()])
             ([kv (in-intmap-pairs (control-flow-graph-functions cfg))])
     (define err (check-public-function (cdr kv)))
     (if err (cons err errors) errors))))

(define (srcloc->datum loc)
  (and (srcloc? loc)
       (hash 'source (source->datum (srcloc-source loc))
             'line (srcloc-line loc)
             'column (srcloc-column loc)
             'position (srcloc-position loc)
             'span (srcloc-span loc))))

(define (source->datum source)
  (cond
    [(path? source) (path->string source)]
    [(or (symbol? source) (string? source) (not source)) source]
    [else (format "~a" source)]))

(define (function-params->datum fn)
  (define params (fn-get-info fn 'function-params #f))
  (and params
       (for/list ([param (in-list params)])
         (match param
           [(list mode (? ast-reg? reg))
            (hash 'mode mode
                  'kind (ast-reg-kind reg)
                  'name (ast-reg-id reg)
                  'element (ast-reg-element reg))]
           [_
            (hash 'mode #f
                  'kind #f
                  'name #f
                  'element #f)]))))

(define (public-function->manifest-entry fn)
  (hash 'name (asm-function-name fn)
        'logical-name (fn-logical-name fn)
        'linkage-symbol (fn-linkage-symbol fn)
        'visibility (fn-get-info fn 'visibility 'public)
        'binding (fn-get-info fn 'binding 'strong)
        'header? (fn-get-info fn 'public-header? #t)
        'profile (fn-public-abi-profile fn)
        'profile-explicit? (fn-public-abi-profile-explicit? fn)
        'abi (fn-get-info fn 'abi #f)
        'params (function-params->datum fn)
        'location (srcloc->datum (fn-get-info fn 'function-loc #f))))

(define (public-abi-manifest cfg)
  (hash 'format 'asmp-public-abi
        'version 1
        'source (source->datum (control-flow-graph-source cfg))
        'exports
        (for/list ([kv (in-intmap-pairs (control-flow-graph-functions cfg))]
                   #:when (fn-public-abi-root? (cdr kv)))
          (public-function->manifest-entry (cdr kv)))))

(define (write-public-abi-manifest manifest path)
  (call-with-output-file path
    (lambda (out)
      (write manifest out)
      (newline out))
    #:exists 'truncate/replace))

(define c-header-profiles '(c-aapcs64 apple-c-arm64))

(define (c-header-profile? profile)
  (if (memq profile c-header-profiles) #t #f))

(define (param-name param)
  (hash-ref param 'name #f))

(define (param-name-string param)
  (define name (param-name param))
  (and name (if (symbol? name) (symbol->string name) (format "~a" name))))

(define (param-name-in? param names)
  (define name (param-name param))
  (and name (if (memq name names) #t #f)))

(define (param-name-suffix? param suffix)
  (define name (param-name-string param))
  (and name (string-suffix? name suffix)))

(define (c-type-for-param param)
  (define kind (hash-ref param 'kind #f))
  (define mode (hash-ref param 'mode #f))
  (cond
    [(and (eq? kind 'w)
          (eq? mode 'out)
          (param-name-in? param '(status)))
     "int"]
    [(and (eq? kind 'x)
          (param-name-in? param '(dst output out_buf)))
     "uint8_t *"]
    [(and (eq? kind 'x)
          (param-name-in? param '(src input in_buf)))
     "const uint8_t *"]
    [(and (eq? kind 'x)
          (param-name-in? param '(dst_len dst_len_ptr out_len out_len_ptr)))
     "uint64_t *"]
    [(and (eq? kind 'x)
          (param-name-in? param '(scratch scratch_ptr)))
     "void *"]
    [(and (eq? kind 'x)
          (param-name-suffix? param "_ptr"))
     "void *"]
    [else
     (case kind
       [(x) "uint64_t"]
       [(w) "uint32_t"]
       [(d) "double"]
       [(s) "float"]
       [else #f])]))

(define (c-ident s)
  (define raw (if (symbol? s) (symbol->string s) (format "~a" s)))
  (define replaced (regexp-replace* #rx"[^A-Za-z0-9_]" raw "_"))
  (cond
    [(string=? replaced "") "asmp_symbol"]
    [(regexp-match? #rx"^[A-Za-z_]" replaced) replaced]
    [else (string-append "_" replaced)]))

(define (c-string s)
  (format "~s" (if (symbol? s) (symbol->string s) (format "~a" s))))

(define (entry-c-name entry)
  (c-ident (hash-ref entry 'name)))

(define (entry-asm-label entry)
  (hash-ref entry 'linkage-symbol (hash-ref entry 'name)))

(define (entry-symbol-attr entry)
  (define cname (entry-c-name entry))
  (define label (entry-asm-label entry))
  (if (string=? cname (symbol->string label))
      ""
      (format " ASMP_PUBLIC_SYM(~a)" (c-string label))))

(define (param->c-argument param)
  (define c-type (c-type-for-param param))
  (and c-type
       (format "~a ~a"
               c-type
               (c-ident (hash-ref param 'name 'arg)))))

(define (prototype-params params)
  (define args
    (for/list ([param (in-list params)]
               #:when (memq (hash-ref param 'mode #f) '(in inout)))
      param))
  (define c-args (map param->c-argument args))
  (and (andmap values c-args)
       (if (null? c-args)
           "void"
           (string-join c-args ", "))))

(define (prototype-return-type outputs)
  (cond
    [(null? outputs) "void"]
    [(null? (cdr outputs)) (c-type-for-param (car outputs))]
    [else #f]))

(define (entry->c-prototype entry)
  (define profile (hash-ref entry 'profile #f))
  (define params (hash-ref entry 'params #f))
  (cond
    [(not (c-header-profile? profile))
     (values #f (format "profile ~a is not a C header profile" profile))]
    [(known-c-prototype entry)
     => (lambda (prototype) (values prototype #f))]
    [(not (pair? params))
     (values #f "missing non-empty managed signature")]
    [else
     (define outputs
       (for/list ([param (in-list params)]
                  #:when (memq (hash-ref param 'mode #f) '(out inout)))
         param))
     (define return-type (prototype-return-type outputs))
     (define args (prototype-params params))
     (cond
       [(not return-type)
        (values #f "multiple or unsupported output values")]
       [(not args)
        (values #f "unsupported parameter class")]
       [else
        (values
         (format "extern ~a ~a(~a)~a;"
                 return-type
                 (entry-c-name entry)
                 args
                 (entry-symbol-attr entry))
         #f)])]))

(define (known-c-prototype entry)
  (case (hash-ref entry 'name #f)
    [(asmp_deflate_raw_bound)
     "extern uint64_t asmp_deflate_raw_bound(uint64_t src_len);"]
    [(asmp_deflate_raw_scratch_size)
     "extern uint64_t asmp_deflate_raw_scratch_size(void);"]
    [(asmp_deflate_raw_scratch_align)
     "extern uint64_t asmp_deflate_raw_scratch_align(void);"]
    [(asmp_deflate_raw_fixed asmp_deflate_raw_auto)
     (format "extern int ~a(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);"
             (entry-c-name entry))]
    [(asmp_deflate_raw_stored)
     "extern int asmp_deflate_raw_stored(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len);"]
    [else #f]))

(define (header-entry-lines entries)
  (for/fold ([prototypes '()]
             [skips '()]
             #:result (values (reverse prototypes) (reverse skips)))
            ([entry (in-list entries)]
             #:when (hash-ref entry 'header? #t))
    (define-values (prototype reason) (entry->c-prototype entry))
    (if prototype
        (values (cons prototype prototypes) skips)
        (values prototypes
                (cons (format "/* skipped ~a: ~a */"
                              (hash-ref entry 'name '<unknown>)
                              reason)
                      skips)))))

(define (append-header-lines prototypes skips)
  (string-append
   (if (null? prototypes)
       ""
       (string-append (string-join prototypes "\n") "\n"))
   (if (or (null? prototypes) (null? skips)) "" "\n")
   (if (null? skips)
       ""
       (string-append (string-join skips "\n") "\n"))))

(define (entry-group-comment group-name)
  (case group-name
    [(stable) "Stable API."]
    [(experimental)
     "Experimental API. These symbols may change before promotion."]
    [else
     (format "~a API." group-name)]))

(define (header-entry-group->string group)
  (define name (car group))
  (define entries (cdr group))
  (define-values (prototypes skips) (header-entry-lines entries))
  (define body (append-header-lines prototypes skips))
  (if (string=? body "")
      ""
      (string-append
       "/* " (entry-group-comment name) " */\n"
       body)))

(define (public-c-header manifest
                         #:guard [guard "ASMP_PUBLIC_ABI_H"]
                         #:body-prefix [body-prefix ""]
                         #:entry-groups [entry-groups #f])
  (define exports (hash-ref manifest 'exports '()))
  (define body
    (if entry-groups
        (string-join
         (filter
          (lambda (text) (not (string=? text "")))
          (map header-entry-group->string entry-groups))
         "\n")
        (let-values ([(prototypes skips) (header-entry-lines exports)])
          (append-header-lines prototypes skips))))
  (string-append
   (format "#ifndef ~a\n#define ~a\n\n" guard guard)
   "#include <stdint.h>\n\n"
   "#if defined(__GNUC__) || defined(__clang__)\n"
   "#define ASMP_PUBLIC_SYM(name) __asm__(name)\n"
   "#else\n"
   "#define ASMP_PUBLIC_SYM(name)\n"
   "#endif\n\n"
   "#ifdef __cplusplus\nextern \"C\" {\n#endif\n\n"
   (if (string=? body-prefix "")
       ""
       (string-append body-prefix
                      (if (string-suffix? body-prefix "\n") "" "\n")
                      "\n"))
   body
   "\n#ifdef __cplusplus\n}\n#endif\n\n"
   "#undef ASMP_PUBLIC_SYM\n\n"
   (format "#endif /* ~a */\n" guard)))

(define (write-public-c-header manifest path
                               #:guard [guard "ASMP_PUBLIC_ABI_H"]
                               #:body-prefix [body-prefix ""])
  (call-with-output-file path
    (lambda (out)
      (display (public-c-header manifest
                                #:guard guard
                                #:body-prefix body-prefix)
               out))
    #:exists 'truncate/replace))

(define (format-srcloc* loc)
  (if (and loc (srcloc? loc))
      (format "~a:~a:~a"
              (or (srcloc-source loc) "<unknown>")
              (or (srcloc-line loc) 0)
              (or (srcloc-column loc) 0))
      "<unknown>"))

(define (format-public-abi-error err)
  (format "~a: function '~a' export profile=~a conflicts with function abi=~a: ~a"
          (format-srcloc* (public-abi-error-location err))
          (public-abi-error-function-name err)
          (public-abi-error-profile err)
          (public-abi-error-abi-name err)
          (public-abi-error-reason err)))
