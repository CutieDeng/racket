#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre)
         racket/interaction-info
         racket/promise
         shrubbery/print
         shrubbery/property
         racket/lazy-require
         (only-in syntax/parse/report-config
                  current-report-configuration)
         (prefix-in rhombus: (submod "print.rkt" for-runtime))
         (submod "print.rkt" redirect)
         "rhombus-primitive.rkt"
         "normalize-syntax.rkt"
         "../version-case.rkt")

;; For `current-read-interaction` callback:
(lazy-require [shrubbery/parse (parse-all)])

(provide install-runtime-config!
         parameters)

(#%declare #:flatten-requires)

(meta-if-version-at-least
 "8.15.0.2"
 (void)
 (define error-syntax->name-handler (make-parameter (lambda (stx) #f))))

(meta-if-version-at-least
 "8.16.0.3"
 (void)
 (define error-module-path->string-handler (make-parameter (lambda (mp len) #f))))

(define need-more (gensym 'need-more))
(define no-interaction (gensym 'no-interaction))

(define rhombus-tstring-transformer
  (delay
    (with-handlers ([exn:fail? (lambda (_exn) #f)])
      (dynamic-require 'tstring/private/rhombus-source-transform
                       'transform-rhombus-template-prefixes/positions))))

(define (current-rhombus-tstring-transformer)
  (force rhombus-tstring-transformer))

(define (install-optional-rhombus-tstring-runtime!)
  (when (current-rhombus-tstring-transformer)
    (with-handlers ([exn:fail? void])
      (namespace-require '(lib "tstring/rhombus-runtime.rkt")))))

(define (empty-rhombus-interaction? stx)
  (and (syntax? stx)
       (let ([v (syntax-e stx)])
         (and (pair? v)
              (or (null? (cdr v))
                  (and (syntax? (cdr v))
                       (null? (syntax-e (cdr v)))))
              (eq? 'multi (syntax-e (car v)))))))

(define (read-rhombus-interaction src in)
  (define-values (line col pos) (port-next-location in))
  (define stx
    (parse-all in #:source src #:mode 'interactive
               #:start-column (or col 0)))
  (if (empty-rhombus-interaction? stx)
      eof
      stx))

(define (read-rhombus/tstring-interaction src in transform)
  (define-values (line col pos) (port-next-location in))
  (let loop ([byte-offset 0]
             [char-count 0]
             [chars '()])
    (define-values (next-byte-offset next-char-count next-chars eof?)
      (peek-source-line in byte-offset char-count chars))
    (cond
      [(and eof? (null? next-chars))
       eof]
      [else
       (define source (list->string (reverse next-chars)))
       (define error-consumed #f)
       (define-values (status stx consumed)
         (with-handlers ([exn:fail?
                          (lambda (exn)
                            (consume-chars in (or error-consumed next-char-count))
                            (raise exn))])
           (read-transformed-rhombus-interaction src
                                                 source
                                                 (not eof?)
                                                 (or col 0)
                                                 transform
                                                 in
                                                 (lambda (count)
                                                   (set! error-consumed count)))))
       (cond
         [(eq? status need-more)
          (loop next-byte-offset next-char-count next-chars)]
         [(and (eq? status no-interaction) (not eof?))
          (loop next-byte-offset next-char-count next-chars)]
         [else
          (consume-chars in
                         (if (eq? status no-interaction)
                             next-char-count
                             consumed))
          (if (eq? status no-interaction)
              eof
              stx)])])))

(define (read-transformed-rhombus-interaction src
                                              source
                                              catch-eof?
                                              start-column
                                              transform
                                              original-in
                                              [on-error-consumed void])
  (define (read-it)
    (define-values (transformed-source transformed-positions)
      (transform source original-in))
    (define transformed-in (open-input-string transformed-source))
    (port-count-lines! transformed-in)
    (define stx
      (with-handlers ([exn:fail?
                       (lambda (exn)
                         (on-error-consumed
                          (transformed-position->source-count
                           transformed-positions
                           (file-position transformed-in)))
                         (raise exn))])
        (parse-all transformed-in #:source src #:mode 'interactive
                   #:start-column start-column)))
    (if (empty-rhombus-interaction? stx)
        (values no-interaction eof 0)
        (values stx
                stx
                (transformed-position->source-count
                 transformed-positions
                 (file-position transformed-in)))))
  (if catch-eof?
      (with-handlers ([exn:fail:read:eof?
                       (lambda (_exn)
                         (values need-more #f 0))]
                      [exn:fail?
                       (lambda (exn)
                         (if (transform-incomplete? source transform original-in)
                             (values need-more #f 0)
                             (raise exn)))])
        (read-it))
      (read-it)))

(define (peek-source-line in byte-offset char-count chars)
  (let loop ([byte-offset byte-offset]
             [char-count char-count]
             [chars chars])
    (define ch (peek-char in byte-offset))
    (cond
      [(eof-object? ch)
       (values byte-offset char-count chars #t)]
      [else
       (define next-byte-offset (+ byte-offset (char-utf-8-length ch)))
       (define next-char-count (add1 char-count))
       (define next-chars (cons ch chars))
       (if (char=? ch #\newline)
           (values next-byte-offset next-char-count next-chars #f)
           (loop next-byte-offset next-char-count next-chars))])))

(define (char-utf-8-length ch)
  (bytes-length (string->bytes/utf-8 (string ch))))

(define (transformed-position->source-count transformed-positions position)
  (cond
    [(and (exact-nonnegative-integer? position)
          (< position (vector-length transformed-positions)))
     (vector-ref transformed-positions position)]
    [else
     (vector-ref transformed-positions
                 (sub1 (vector-length transformed-positions)))]))

(define (transform-incomplete? source transform original-in)
  (with-handlers ([exn:fail? (lambda (_exn) #t)])
    (transform source original-in)
    #f))

(define (consume-chars in count)
  (for ([_index (in-range count)])
    (read-char in)))

(define-syntax (define-install!+params stx)
  (syntax-parse stx
    #:literals (void)
    [(_ install! params
        (~and ((~or* void param) . _)
              form)
        ...)
     #'(begin
         (define (install!)
           form ...)
         (define params
           (list (~? param) ...)))]))

;; `parameters` is a list of all set parameters, needed in
;; "expand-config.rkt":
(define-install!+params install-runtime-config! parameters
  (current-interaction-info '#((submod rhombus reader)
                               get-interaction-info
                               #f))

  (current-read-interaction
   (lambda (src in)
     (when (terminal-port? in)
       (flush-output (current-output-port)))
     (define transform (current-rhombus-tstring-transformer))
     (if transform
         (begin
           (install-optional-rhombus-tstring-runtime!)
           (read-rhombus/tstring-interaction src in transform))
         (read-rhombus-interaction src in))))

  (print-boolean-long-form #t)

  (global-port-print-handler
   (let ([orig (global-port-print-handler)])
     (lambda (v op [mode 0])
       (if (racket-print-redirect? v)
           ;; As we print unwrapped, we still want to go through
           ;; the port's print handler, so parameterize instead
           ;; of calling `orig` directly:
           (parameterize ([global-port-print-handler orig])
             (print (racket-print-redirect-val v) op mode))
           (rhombus:print v op 'expr #t)))))

  (current-error-message-adjuster
   (lambda (mode)
     (case mode
       [(contract)
        (lambda (str realm)
          (case realm
            [(racket/primitive)
             (with-handlers ([exn:fail:read? (lambda (exn)
                                               (values str realm))])
               (define c (read (open-input-string str)))
               (cond
                 [(get-primitive-contract c)
                  => (lambda (new-str)
                       (values new-str 'rhombus/primitive))]
                 [else (values str realm)]))]
            [else (values str realm)]))]
       [(message)
        (lambda (who who-realm msg msg-realm)
          (define-values (new-who new-who-realm)
            (case who-realm
              [(racket/primitive)
               (cond
                 [(get-primitive-who who)
                  => (lambda (new-who)
                       (values new-who 'rhombus/primitive))]
                 [else (values who who-realm)])]
              [else (values who who-realm)]))
          (define-values (new-msg new-msg-realm)
            (case who-realm
              [(racket/primitive)
               (define (rhombus s) (values s 'rhombus/primitive))
               (cond
                 [(regexp-match-positions #rx"^contract violation\n  expected: (.*)\n  given: (.*)" msg)
                  => (lambda (m)
                       (define expected (cadr m))
                       (define value (caddr m))
                       (rhombus (string-append "value does not satisfy annotation\n"
                                               "  annotation: " (substring msg (car expected) (cdr expected)) "\n"
                                               "  value: " (substring msg (car value) (cdr value)))))]
                 [(regexp-match-positions #rx"^not a procedure;\n expected a procedure that can be applied to arguments" msg)
                  => (lambda (m)
                       (rhombus (string-append "not a function" (substring msg (cdar m)))))]
                 [(regexp-match-positions
                   #rx"^procedure does not (accept keyword arguments|expect an argument with given keyword)\n  procedure:"
                   msg)
                  => (lambda (m)
                       (rhombus (string-append "function does not " (substring msg (caadr m) (cdadr m)) "\n  function:" (substring msg (cdar m)))))]
                 [(regexp-match-positions #rx"^required keyword argument not supplied\n  procedure:" msg)
                  => (lambda (m)
                       (rhombus (string-append "required keyword argument not supplied\n  function:" (substring msg (cdar m)))))]
                 [(regexp-match-positions #rx"^index is out of range.*?vector:" msg)
                  => (lambda (m)
                       (rhombus (string-append (regexp-replace* #rx"vector" (substring msg (caar m) (cdar m)) "array")
                                               (substring msg (cdar m)))))]
                 [(regexp-match-positions #rx"^(?:starting |ending |)index is out of range.*?treelist:" msg)
                  => (lambda (m)
                       (rhombus (string-append (regexp-replace* #rx"treelist" (substring msg (caar m) (cdar m)) "list")
                                               (substring msg (cdar m)))))]
                 [else (values msg msg-realm)])]
              [(racket)
               (define (rhombus s) (values s 'rhombus/primitive))
               (cond
                 [(regexp-match-positions #rx"^arity mismatch;\n the expected number of arguments does not match the given number" msg)
                  => (lambda (m)
                       (rhombus (string-append "wrong number of arguments in function call"
                                               (substring msg (cdar m)))))]
                 [else (values msg msg-realm)])]
              [else (values msg msg-realm)]))
          (values new-who new-who-realm new-msg new-msg-realm))]
       [else #f])))

  ;; for expand-time configure or syntax errors in the REPL
  (error-syntax->string-handler
   (lambda (s len)
     (define stx (normalize-syntax s))
     (define str (shrubbery-syntax->string stx #:max-length len))
     (if (equal? str "")
         "[end of group]"
         str)))

  (error-syntax->name-handler
   (lambda (s)
     (let name-of ([s s])
       (if (identifier? s)
           (if (syntax-raw-property s)
               (string->symbol (shrubbery-syntax->string s))
               (syntax-e s))
           (syntax-case* s (multi group op) (lambda (a b) (eq? (syntax-e a) (syntax-e b)))
             [(group who . _) (name-of #'who)]
             [(multi (group who . _) . _) (name-of #'who)]
             [(op n) (name-of #'n)]
             [(head . _)
              ;; mainly intended to handle the not-a-shrubbery case:
              (and (identifier? #'head)
                   (name-of #'head))]
             [_ #f])))))

  (error-module-path->string-handler
   (lambda (mp len)
     (define (to-string v)
       (define op (open-output-bytes))
       (rhombus:print v op 'expr #t)
       (get-output-string op))
     (let loop ([mp mp])
       (cond
         [(and (pair? mp) (eq? (car mp) 'lib))
          (format "lib(~s)" (cadr mp))]
         [(and (pair? mp) (eq? (car mp) 'file))
          (format "file(~s)" (cadr mp))]
         [(and (pair? mp) (eq? (car mp) 'submod))
          (for/fold ([s (loop (cadr mp))]) ([p (in-list (cddr mp))])
            (format "~a!~a" s (substring (to-string p) 2)))]
         [else (to-string mp)]))))

  (current-report-configuration
   (hasheq 'literal-to-what (lambda (v)
                              '("identifier" "identifiers"))
           'literal-to-string (lambda (v)
                                (format "`~s`" (if (syntax? v)
                                                   (syntax-e v)
                                                   v)))
           'datum-to-what (lambda (v)
                            (cond
                              [(symbol? v) '("identifier" "identifiers")]
                              [(keyword? v) '("keyword" "keywords")]
                              ;; `null` shows up with optional sequences
                              [(null? v) '("empty" "empty")]
                              [else '("literal" "literals")]))
           'datum-to-string (lambda (v)
                              (cond
                                [(symbol? v) (format "`~a`" (substring (format "~v" v) 2))]
                                [(keyword? v) (substring (format "~v" v) 2)]
                                [(null? v) "sequence"]
                                [else (format "~v" v)])))))
