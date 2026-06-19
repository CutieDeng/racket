#lang racket/base

(require
 racket/format
 "template.rkt"
 "render.rkt"
 (for-syntax
  racket/base
  racket/port
  racket/string
  "parse.rkt"
  "source-transform.rkt"
 ) ; end for-syntax
) ; end require

(provide
 tpl
 fpl
 (rename-out (tpl #%tstring-tpl)
             (fpl #%tstring-fpl)
 ) ; end rename-out
) ; end provide

(define-syntax (tpl stx)
  (syntax-case stx ()
    ((_ input)
     (string? (syntax-e #'input))
     (expand-template 'tpl stx #'input)
    ) ; end literal string case
    (_
     (raise-syntax-error 'tpl "expected a string literal" stx)
    ) ; end invalid syntax
  ) ; end syntax-case
) ; end define-syntax tpl

(define-syntax (fpl stx)
  (syntax-case stx ()
    ((_ input)
     (string? (syntax-e #'input))
     (expand-fstring 'fpl stx #'input)
    ) ; end literal string case
    (_
     (raise-syntax-error 'fpl "expected a string literal" stx)
    ) ; end invalid syntax
  ) ; end syntax-case
) ; end define-syntax fpl

(define-for-syntax (expand-template who context-stx input-stx)
  (define-values (strings expression-infos)
    (parse-template-parts who context-stx input-stx)
  ) ; end define-values
  #`(template (list #,@(map datum->syntax-literal strings))
              (list #,@(map interpolation-syntax expression-infos))
    ) ; end template
) ; end define-for-syntax expand-template

(define-for-syntax (expand-fstring who context-stx input-stx)
  (define-values (strings expression-infos)
    (parse-template-parts who context-stx input-stx)
  ) ; end define-values
  (cond
    ((null? expression-infos)
     (datum->syntax-literal (car strings))
    ) ; end static f-string
    (else
     #`(string-append #,@(fstring-append-parts strings expression-infos))
    ) ; end dynamic f-string
  ) ; end cond
) ; end define-for-syntax expand-fstring

(define-for-syntax (parse-template-parts who context-stx input-stx)
  (with-handlers ((exn:fail:syntax?
                   (lambda (exn)
                     (raise exn)
                   ) ; end lambda
                  ) ; end exn:fail:syntax?
                  (exn:fail?
                   (lambda (exn)
                     (raise-syntax-error who
                                         (exn-message exn)
                                         context-stx
                     ) ; end raise-syntax-error
                   ) ; end lambda
                  ) ; end exn:fail?
                 ) ; end handlers
    (define-values (strings expression-sources)
      (parse-template-string (syntax-e input-stx))
    ) ; end define-values
    (values strings
            (map (lambda (source)
                   (source-string->expression-info who context-stx source)
                 ) ; end lambda
                 expression-sources
            ) ; end map
    ) ; end values
  ) ; end with-handlers
) ; end define-for-syntax parse-template-parts

(define-for-syntax (source-string->expression-info who context-stx source)
  (define transformed-source (transform-template-prefixes source))
  (define-values (expression-source suffix-source)
    (split-interpolation-source transformed-source)
  ) ; end define-values
  (define port (open-input-string expression-source))
  (define expression-stx (read-syntax 'template-interpolation port))
  (when (eof-object? expression-stx)
    (raise-syntax-error who "empty interpolation is not allowed" context-stx)
  ) ; end when eof
  (define extra-stx (read-syntax 'template-interpolation port))
  (unless (eof-object? extra-stx)
    (raise-syntax-error
     who
     "interpolation must contain exactly one expression; use ! for conversions or : for format specs"
     context-stx
    ) ; end raise-syntax-error
  ) ; end unless eof
  (define-values (conversion format-spec)
    (parse-interpolation-suffix suffix-source)
  ) ; end define-values
  (list (datum->syntax context-stx
                       (syntax->datum expression-stx)
                       context-stx
                       context-stx
        ) ; end datum->syntax
        format-spec
        conversion
  ) ; end list
) ; end define-for-syntax source-string->expression-info

(define-for-syntax (split-interpolation-source source)
  (define suffix-index (find-explicit-suffix-index source))
  (cond
    (suffix-index
     (values (substring source 0 suffix-index)
             (substring source suffix-index)
     ) ; end values
    ) ; end suffix found
    (else
     (values source "")
    ) ; end no suffix
  ) ; end cond
) ; end define-for-syntax split-interpolation-source

(define-for-syntax (find-explicit-suffix-index source)
  (define length (string-length source))
  (let loop ((index 0)
             (depth 0)
        ) ; end loop bindings
    (cond
      ((= index length)
       #f
      ) ; end end of source
      (else
       (define ch (string-ref source index))
       (cond
         ((char=? ch #\")
          (loop (find-racket-string-end source index)
                depth
          ) ; end loop
         ) ; end string literal
         ((char=? ch #\|)
          (loop (find-bar-symbol-end source index)
                depth
          ) ; end loop
         ) ; end escaped symbol
         ((char-literal-at? source index)
          (loop (find-char-literal-end source index)
                depth
          ) ; end loop
         ) ; end character literal
         ((line-comment-at? source index)
          (loop (find-line-comment-end source index)
                depth
          ) ; end loop
         ) ; end line comment
         ((block-comment-at? source index)
          (loop (find-block-comment-end source index)
                depth
          ) ; end loop
         ) ; end block comment
         ((memv ch '(#\( #\[ #\{))
          (loop (add1 index)
                (add1 depth)
          ) ; end loop
         ) ; end open delimiter
         ((memv ch '(#\) #\] #\}))
          (loop (add1 index)
                (max 0 (sub1 depth))
          ) ; end loop
         ) ; end close delimiter
         ((and (zero? depth)
               (explicit-suffix-at? source index)
               (complete-expression-prefix? source index)
          ) ; end and
          index
         ) ; end explicit suffix
         (else
          (loop (add1 index)
                depth
          ) ; end loop
         ) ; end ordinary character
       ) ; end cond char dispatch
      ) ; end more source
    ) ; end cond
  ) ; end let loop
) ; end define-for-syntax find-explicit-suffix-index

(define-for-syntax (explicit-suffix-at? source index)
  (define ch (string-ref source index))
  (cond
    ((char=? ch #\!)
     (conversion-suffix-at? source index)
    ) ; end conversion suffix
    ((char=? ch #\:)
     (format-suffix-at? source index)
    ) ; end format suffix
    (else
     #f
    ) ; end ordinary character
  ) ; end cond
) ; end define-for-syntax explicit-suffix-at?

(define-for-syntax (conversion-suffix-at? source index)
  (and (< (add1 index) (string-length source))
       (memv (string-ref source (add1 index)) '(#\s #\r #\a))
  ) ; end and
) ; end define-for-syntax conversion-suffix-at?

(define-for-syntax (format-suffix-at? source index)
  (define length (string-length source))
  (cond
    ((= (add1 index) length)
     #t
    ) ; end empty format suffix, rejected later
    (else
     (define first (string-ref source (add1 index)))
     (or (format-start-char? first)
         (and (< (+ index 2) length)
              (alignment-char? (string-ref source (+ index 2)))
         ) ; end fill and align
     ) ; end or
    ) ; end non-empty suffix
  ) ; end cond
) ; end define-for-syntax format-suffix-at?

(define-for-syntax (format-start-char? ch)
  (or (char-numeric? ch)
      (memv ch '(#\. #\< #\> #\^ #\= #\+ #\- #\space
                 #\# #\s #\d #\b #\o #\x #\X #\f #\F #\e #\E #\g #\G #\%))
  ) ; end or
) ; end define-for-syntax format-start-char?

(define-for-syntax (alignment-char? ch)
  (memv ch '(#\< #\> #\^ #\=))
) ; end define-for-syntax alignment-char?

(define-for-syntax (complete-expression-prefix? source index)
  (define prefix (string-trim (substring source 0 index)))
  (and (not (equal? prefix ""))
       (with-handlers ((exn:fail? (lambda (_exn) #f)))
         (define port (open-input-string prefix))
         (define expression-stx (read-syntax 'template-interpolation port))
         (and (not (eof-object? expression-stx))
              (eof-object? (read-syntax 'template-interpolation port))
         ) ; end and
       ) ; end with-handlers
  ) ; end and
) ; end define-for-syntax complete-expression-prefix?

(define-for-syntax (char-literal-at? source index)
  (and (< (+ index 2) (string-length source))
       (char=? (string-ref source index) #\#)
       (char=? (string-ref source (add1 index)) #\\)
  ) ; end and
) ; end define-for-syntax char-literal-at?

(define-for-syntax (find-char-literal-end source index)
  (define length (string-length source))
  (let loop ((index (+ index 2)))
    (cond
      ((= index length)
       length
      ) ; end end of source
      ((racket-token-delimiter? (string-ref source index))
       index
      ) ; end token delimiter
      (else
       (loop (add1 index))
      ) ; end token character
    ) ; end cond
  ) ; end let loop
) ; end define-for-syntax find-char-literal-end

(define-for-syntax (find-bar-symbol-end source index)
  (define length (string-length source))
  (let loop ((index (add1 index)))
    (cond
      ((= index length)
       length
      ) ; end end of source
      ((char=? (string-ref source index) #\\)
       (loop (min length (+ index 2)))
      ) ; end escaped character
      ((char=? (string-ref source index) #\|)
       (add1 index)
      ) ; end symbol close
      (else
       (loop (add1 index))
      ) ; end symbol character
    ) ; end cond
  ) ; end let loop
) ; end define-for-syntax find-bar-symbol-end

(define-for-syntax (line-comment-at? source index)
  (char=? (string-ref source index) #\;)
) ; end define-for-syntax line-comment-at?

(define-for-syntax (find-line-comment-end source index)
  (define length (string-length source))
  (let loop ((index index))
    (cond
      ((= index length)
       length
      ) ; end end of source
      ((char=? (string-ref source index) #\newline)
       (add1 index)
      ) ; end newline
      (else
       (loop (add1 index))
      ) ; end comment character
    ) ; end cond
  ) ; end let loop
) ; end define-for-syntax find-line-comment-end

(define-for-syntax (block-comment-at? source index)
  (and (< (add1 index) (string-length source))
       (char=? (string-ref source index) #\#)
       (char=? (string-ref source (add1 index)) #\|)
  ) ; end and
) ; end define-for-syntax block-comment-at?

(define-for-syntax (find-block-comment-end source index)
  (define length (string-length source))
  (let loop ((index (+ index 2))
             (depth 1)
        ) ; end loop bindings
    (cond
      ((= index length)
       length
      ) ; end end of source
      ((and (< (add1 index) length)
            (char=? (string-ref source index) #\#)
            (char=? (string-ref source (add1 index)) #\|)
       ) ; end and
       (loop (+ index 2)
             (add1 depth)
       ) ; end loop
      ) ; end nested open comment
      ((and (< (add1 index) length)
            (char=? (string-ref source index) #\|)
            (char=? (string-ref source (add1 index)) #\#)
       ) ; end and
       (define next-depth (sub1 depth))
       (if (zero? next-depth)
           (+ index 2)
           (loop (+ index 2)
                 next-depth
           ) ; end loop
       ) ; end if
      ) ; end close comment
      (else
       (loop (add1 index)
             depth
       ) ; end loop
      ) ; end comment character
    ) ; end cond
  ) ; end let loop
) ; end define-for-syntax find-block-comment-end

(define-for-syntax (racket-token-delimiter? ch)
  (or (char-whitespace? ch)
      (memv ch '(#\( #\) #\[ #\] #\{ #\} #\" #\' #\` #\, #\;))
  ) ; end or
) ; end define-for-syntax racket-token-delimiter?

(define-for-syntax (parse-interpolation-suffix suffix)
  (define text (string-trim suffix))
  (cond
    ((equal? text "")
     (values "" #f)
    ) ; end empty suffix
    (else
     (define conversion "")
     (define rest text)
     (when (char=? (string-ref rest 0) #\!)
       (when (= (string-length rest) 1)
         (raise-arguments-error 'parse-interpolation-suffix
                                "missing conversion after !"
                                "suffix"
                                suffix
         ) ; end raise-arguments-error
       ) ; end when missing conversion
       (define conversion-char (string-ref rest 1))
       (unless (memv conversion-char '(#\s #\r #\a))
         (raise-arguments-error 'parse-interpolation-suffix
                                "unsupported conversion; expected !s, !r, or !a"
                                "suffix"
                                suffix
         ) ; end raise-arguments-error
       ) ; end unless supported conversion
       (set! conversion (string conversion-char))
       (set! rest (string-trim (substring rest 2)))
     ) ; end when conversion
     (define format-spec #f)
     (cond
       ((equal? rest "")
        (void)
       ) ; end no format spec
       ((char=? (string-ref rest 0) #\:)
        (define parsed-format-spec (substring rest 1))
        (when (equal? parsed-format-spec "")
          (raise-arguments-error 'parse-interpolation-suffix
                                 "missing format spec after :"
                                 "suffix"
                                 suffix
          ) ; end raise-arguments-error
        ) ; end when missing format spec
        (set! format-spec parsed-format-spec)
        (set! rest "")
       ) ; end format spec
       (else
        (raise-arguments-error 'parse-interpolation-suffix
                               "extra text after interpolation expression; use ! for conversions or : for format specs"
                               "suffix"
                               suffix
        ) ; end raise-arguments-error
       ) ; end invalid suffix
     ) ; end cond
     (values conversion format-spec)
    ) ; end non-empty suffix
  ) ; end cond
) ; end define-for-syntax parse-interpolation-suffix

(define-for-syntax (datum->syntax-literal value)
  #`'#,value
) ; end define-for-syntax datum->syntax-literal

(define-for-syntax (source-string->syntax who context-stx source)
  (define transformed-source (transform-template-prefixes source))
  (define-values (expression-source _suffix-source)
    (split-interpolation-source transformed-source)
  ) ; end define-values
  (define port (open-input-string expression-source))
  (define read-stx (read-syntax 'template-interpolation port))
  (when (eof-object? read-stx)
    (raise-syntax-error who "empty interpolation is not allowed" context-stx)
  ) ; end when eof
  (define extra-stx (read-syntax 'template-interpolation port))
  (unless (eof-object? extra-stx)
    (raise-syntax-error who "interpolation must contain exactly one expression" context-stx)
  ) ; end unless eof
  (datum->syntax context-stx
                 (syntax->datum read-stx)
                 context-stx
                 context-stx
  ) ; end datum->syntax
) ; end define-for-syntax source-string->syntax

(define-for-syntax (fstring-append-parts strings expression-infos)
  (let loop ((strings strings)
             (expression-infos expression-infos)
        ) ; end loop bindings
    (cond
      ((null? expression-infos)
       (list (datum->syntax-literal (car strings)))
      ) ; end last static string
      (else
       (cons (datum->syntax-literal (car strings))
             (cons (fstring-interpolation-syntax (car expression-infos))
                   (loop (cdr strings)
                         (cdr expression-infos)
                   ) ; end loop
             ) ; end cons expression
       ) ; end cons string
      ) ; end more expressions
    ) ; end cond
  ) ; end let loop
) ; end define-for-syntax fstring-append-parts

(define-for-syntax (fstring-interpolation-syntax expression-info)
  (define expression-stx (list-ref expression-info 0))
  (define format-spec (list-ref expression-info 1))
  (define conversion (list-ref expression-info 2))
  #`(format-fstring-value #,expression-stx
                          '#,format-spec
                          '#,conversion
    ) ; end format-fstring-value
) ; end define-for-syntax fstring-interpolation-syntax

(define-for-syntax (interpolation-syntax expression-info)
  (define expression-stx (list-ref expression-info 0))
  (define format-spec (list-ref expression-info 1))
  (define conversion (list-ref expression-info 2))
  #`(interpolation #,expression-stx
                   (quote-syntax #,expression-stx)
                   '#,format-spec
                   '#,conversion
    ) ; end interpolation
) ; end define-for-syntax interpolation-syntax

(define-for-syntax (nested-template-var-usages source)
  (define length (string-length source))
  (let loop ((index 0)
             (vars '())
        ) ; end loop bindings
    (cond
      ((= index length)
       vars
      ) ; end end of source
      ((char=? (string-ref source index) #\")
       (loop (find-racket-string-end source index)
             vars
       ) ; end loop
      ) ; end ordinary string
      ((template-prefix-at? source index)
       (define end-index (find-template-source-end source (add1 index)))
       (define content (substring source (+ index 2) (sub1 end-index)))
       (define-values (_strings expression-sources)
         (parse-template-string content)
       ) ; end define-values
       (define nested-vars
         (foldl (lambda (expression-source acc)
                  (append-unique acc (source-string-var-usages expression-source))
                ) ; end lambda
                '()
                expression-sources
         ) ; end foldl
       ) ; end define nested-vars
       (loop end-index
             (append-unique vars nested-vars)
       ) ; end loop
      ) ; end nested template
      (else
       (loop (add1 index)
             vars
       ) ; end loop
      ) ; end source character
    ) ; end cond
  ) ; end let loop
) ; end define-for-syntax nested-template-var-usages

(define-for-syntax (source-string-var-usages source)
  (define expression-stx (source-string->syntax 'tpl #'here source))
  (append-unique (syntax-var-usages expression-stx)
                 (nested-template-var-usages source)
  ) ; end append-unique
) ; end define-for-syntax source-string-var-usages

(define-for-syntax (append-unique left right)
  (let loop ((items right)
             (result left)
        ) ; end loop bindings
    (cond
      ((null? items)
       result
      ) ; end no more items
      ((memq (car items) result)
       (loop (cdr items)
             result
       ) ; end loop
      ) ; end already present
      (else
       (loop (cdr items)
             (append result (list (car items)))
       ) ; end loop
      ) ; end new item
    ) ; end cond
  ) ; end let loop
) ; end define-for-syntax append-unique

(define-for-syntax (syntax-var-usages stx)
  (define seen '())
  (define ordered '())
  (define (add! sym)
    (unless (memq sym seen)
      (set! seen (cons sym seen))
      (set! ordered (cons sym ordered))
    ) ; end unless seen
  ) ; end define add!
  (define (walk datum quoted?)
    (cond
      ((symbol? datum)
       (unless quoted?
         (unless (memq datum '(tpl fpl #%tstring-tpl #%tstring-fpl))
           (add! datum)
         ) ; end unless tstring macro
       ) ; end unless quoted
      ) ; end symbol
      ((pair? datum)
       (define head (car datum))
       (define next-quoted?
         (or quoted?
             (and (symbol? head)
                  (memq head '(quote quote-syntax))
             ) ; end and
         ) ; end or
       ) ; end define next-quoted?
       (for ((item (in-list datum)))
         (walk item next-quoted?)
       ) ; end for
      ) ; end pair
      ((vector? datum)
       (for ((item (in-vector datum)))
         (walk item quoted?)
       ) ; end for
      ) ; end vector
      (else
       (void)
      ) ; end other datum
    ) ; end cond
  ) ; end define walk
  (walk (syntax->datum stx) #f)
  (reverse ordered)
) ; end define-for-syntax syntax-var-usages
