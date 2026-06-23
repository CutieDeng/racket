#lang racket/base

(require
 racket/string
 syntax/readerr
 (only-in racket-tstring/private/source-transform
          find-racket-string-end
          find-template-literal-content
          find-template-literal-end
          template-prefix-at?)
) ; end require

(provide
 rhombus-runtime-import-source
 transform-rhombus-template-prefixes
) ; end provide

(define rhombus-runtime-import-source
  "import lib(\"tstring/rhombus-runtime.rkt\") open\n"
) ; end define rhombus-runtime-import-source

(define (transform-rhombus-template-prefixes source port)
  (with-handlers ((exn:fail?
                   (lambda (exn)
                     (raise-read-error (exn-message exn)
                                       (object-name port)
                                       #f
                                       #f
                                       #f
                                       #f
                     ) ; end raise-read-error
                   ) ; end lambda
                  ) ; end exn:fail?
                 ) ; end handlers
    (define length (string-length source))
    (define out (open-output-string))
    (let loop ((index 0))
      (cond
        ((= index length)
         (get-output-string out)
        ) ; end of source
        (else
         (define ch (string-ref source index))
         (cond
           ((char=? ch #\")
            (define next-index (find-racket-string-end source index))
            (write-string (substring source index next-index) out)
            (loop next-index)
           ) ; end ordinary string
           ((rhombus-line-comment-at? source index)
            (define next-index (find-rhombus-line-comment-end source index))
            (write-string (substring source index next-index) out)
            (loop next-index)
           ) ; end line comment
           ((rhombus-block-comment-at? source index)
            (define next-index (find-rhombus-block-comment-end source index))
            (write-string (substring source index next-index) out)
            (loop next-index)
           ) ; end block comment
           ((template-prefix-at? source index)
            (define-values (content next-index)
              (find-template-literal-content source index)
            ) ; end define-values
            (write-string (rhombus-template-content->source
                           (string-ref source index)
                           content)
                          out
            ) ; end write-string
            (loop next-index)
           ) ; end template prefix
           (else
            (write-char ch out)
            (loop (add1 index))
           ) ; end ordinary character
         ) ; end cond char dispatch
        ) ; end more source
      ) ; end cond
    ) ; end loop
  ) ; end with-handlers
) ; end define transform-rhombus-template-prefixes

(define (rhombus-template-content->source kind content)
  (define-values (strings expression-sources)
    (parse-rhombus-template-string content)
  ) ; end define-values
  (cond
    ((char=? kind #\f)
     (rhombus-fstring-source strings expression-sources)
    ) ; end f-string
    ((char=? kind #\t)
     (rhombus-template-source strings expression-sources)
    ) ; end t-string
    (else
     (error 'tstring-rhombus "unsupported template kind: ~a" kind)
    ) ; end unsupported
  ) ; end cond
) ; end define rhombus-template-content->source

(define (rhombus-fstring-source strings expression-sources)
  (cond
    ((null? expression-sources)
     (rhombus-string-literal-source (car strings))
    ) ; end static string
    (else
     (rhombus-call-source
      "rhombus_tstring_concat"
      (rhombus-interleaved-parts strings
                                 expression-sources
                                 rhombus-format-interpolation-source
      ) ; end rhombus-interleaved-parts
     ) ; end rhombus call
    ) ; end dynamic string
  ) ; end cond
) ; end define rhombus-fstring-source

(define (rhombus-template-source strings expression-sources)
  (rhombus-call-source
   "rhombus_tstring_template"
   (list (rhombus-list-source (map rhombus-string-literal-source strings))
         (rhombus-list-source
          (map rhombus-template-interpolation-source expression-sources)
         ) ; end rhombus-list-source
   ) ; end list
  ) ; end rhombus-call-source
) ; end define rhombus-template-source

(define (rhombus-interleaved-parts strings expression-sources expression->source)
  (let loop ((strings strings)
             (expression-sources expression-sources)
        ) ; end loop bindings
    (cond
      ((null? expression-sources)
       (list (rhombus-string-literal-source (car strings)))
      ) ; end last static part
      (else
       (cons (rhombus-string-literal-source (car strings))
             (cons (expression->source (car expression-sources))
                   (loop (cdr strings)
                         (cdr expression-sources)
                   ) ; end loop
             ) ; end cons interpolation
       ) ; end cons string
      ) ; end more
    ) ; end cond
  ) ; end let loop
) ; end define rhombus-interleaved-parts

(define (rhombus-format-interpolation-source source)
  (define-values (expression-source suffix-source)
    (split-rhombus-interpolation-source source)
  ) ; end define-values
  (define-values (conversion format-spec)
    (parse-rhombus-interpolation-suffix suffix-source)
  ) ; end define-values
  (rhombus-call-source
   "rhombus_tstring_format"
   (list (rhombus-parenthesized-expression-source expression-source)
         (rhombus-format-spec-source format-spec)
         (rhombus-string-literal-source conversion)
   ) ; end list
  ) ; end rhombus-call-source
) ; end define rhombus-format-interpolation-source

(define (rhombus-template-interpolation-source source)
  (define-values (expression-source suffix-source)
    (split-rhombus-interpolation-source source)
  ) ; end define-values
  (define-values (conversion format-spec)
    (parse-rhombus-interpolation-suffix suffix-source)
  ) ; end define-values
  (rhombus-call-source
   "rhombus_tstring_interpolation"
   (list (rhombus-parenthesized-expression-source expression-source)
         (rhombus-interpolation-syntax-source expression-source)
         (rhombus-format-spec-source format-spec)
         (rhombus-string-literal-source conversion)
         (rhombus-string-literal-source expression-source)
   ) ; end list
  ) ; end rhombus-call-source
) ; end define rhombus-template-interpolation-source

(define (rhombus-interpolation-syntax-source expression-source)
  (define text (string-trim expression-source))
  (if (regexp-match? #px"^[A-Za-z_][A-Za-z0-9_]*$" text)
      (string-append "#'" text)
      "#false"
  ) ; end if
) ; end define rhombus-interpolation-syntax-source

(define (parse-rhombus-template-string input)
  (define length (string-length input))
  (let loop ((index 0)
             (strings '())
             (expressions '())
             (static-out (open-output-string))
        ) ; end loop bindings
    (cond
      ((= index length)
       (values (reverse (cons (get-output-string static-out) strings))
               (reverse expressions)
       ) ; end values
      ) ; end end of input
      (else
       (define ch (string-ref input index))
       (cond
         ((char=? ch #\{)
          (cond
            ((and (< (add1 index) length)
                  (char=? (string-ref input (add1 index)) #\{)
             ) ; end and
             (write-char #\{ static-out)
             (loop (+ index 2)
                   strings
                   expressions
                   static-out
             ) ; end loop
            ) ; end escaped left brace
            (else
             (define-values (expression next-index)
               (read-rhombus-interpolation input (add1 index))
             ) ; end define-values
             (loop next-index
                   (cons (get-output-string static-out) strings)
                   (cons expression expressions)
                   (open-output-string)
             ) ; end loop
            ) ; end interpolation
          ) ; end cond left brace
         ) ; end left brace case
         ((char=? ch #\})
          (cond
            ((and (< (add1 index) length)
                  (char=? (string-ref input (add1 index)) #\})
             ) ; end and
             (write-char #\} static-out)
             (loop (+ index 2)
                   strings
                   expressions
                   static-out
             ) ; end loop
            ) ; end escaped right brace
            (else
             (raise-arguments-error 'parse-rhombus-template-string
                                    "unmatched } in template string; use }} for a literal }"
                                    "input"
                                    input
                                    "index"
                                    index
             ) ; end raise-arguments-error
            ) ; end unmatched right brace
          ) ; end cond right brace
         ) ; end right brace case
         (else
          (write-char ch static-out)
          (loop (add1 index)
                strings
                expressions
                static-out
          ) ; end loop
         ) ; end ordinary character
       ) ; end cond char dispatch
      ) ; end more input
    ) ; end cond
  ) ; end let loop
) ; end define parse-rhombus-template-string

(define (read-rhombus-interpolation input start-index)
  (define next-index
    (with-handlers ((exn:fail?
                     (lambda (exn)
                       (raise-arguments-error 'parse-rhombus-template-string
                                              (exn-message exn)
                                              "input"
                                              input
                                              "index"
                                              start-index
                       ) ; end raise-arguments-error
                     ) ; end lambda
                    ) ; end exn:fail?
                   ) ; end handlers
      (find-rhombus-interpolation-source-end input start-index)
    ) ; end with-handlers
  ) ; end define next-index
  (define expression (substring input start-index (sub1 next-index)))
  (when (string-blank? expression)
    (raise-arguments-error 'parse-rhombus-template-string
                           "empty interpolation is not allowed"
                           "input"
                           input
                           "index"
                           start-index
    ) ; end raise-arguments-error
  ) ; end when empty expression
  (values expression next-index)
) ; end define read-rhombus-interpolation

(define (find-rhombus-interpolation-source-end source start-index)
  (define length (string-length source))
  (let loop ((index start-index)
             (brace-depth 0)
        ) ; end loop bindings
    (cond
      ((= index length)
       (raise-arguments-error 'tstring-rhombus
                              "unclosed interpolation in template string"
                              "index"
                              start-index
       ) ; end raise-arguments-error
      ) ; end end of source
      (else
       (define ch (string-ref source index))
       (cond
         ((char=? ch #\")
          (loop (find-racket-string-end source index) brace-depth)
         ) ; end string
         ((template-prefix-at? source index)
          (loop (find-template-literal-end source index) brace-depth)
         ) ; end nested template
         ((rhombus-line-comment-at? source index)
          (loop (find-rhombus-line-comment-end source index) brace-depth)
         ) ; end line comment
         ((rhombus-block-comment-at? source index)
          (loop (find-rhombus-block-comment-end source index) brace-depth)
         ) ; end block comment
         ((char=? ch #\{)
          (loop (add1 index) (add1 brace-depth))
         ) ; end nested brace
         ((char=? ch #\})
          (if (zero? brace-depth)
              (add1 index)
              (loop (add1 index) (sub1 brace-depth))
          ) ; end if
         ) ; end right brace
         (else
          (loop (add1 index) brace-depth)
         ) ; end ordinary character
       ) ; end cond char dispatch
      ) ; end more source
    ) ; end cond
  ) ; end let loop
) ; end define find-rhombus-interpolation-source-end

(define (rhombus-format-spec-source format-spec)
  (cond
    ((not format-spec)
     "#false"
    ) ; end no format spec
    (else
     (define-values (strings expression-sources)
       (parse-rhombus-template-string format-spec)
     ) ; end define-values
     (cond
       ((null? expression-sources)
        (rhombus-string-literal-source (car strings))
       ) ; end static format spec
       (else
        (rhombus-call-source
         "rhombus_tstring_concat"
         (rhombus-interleaved-parts strings
                                    expression-sources
                                    rhombus-format-interpolation-source
         ) ; end rhombus-interleaved-parts
        ) ; end rhombus call
       ) ; end dynamic format spec
     ) ; end cond
    ) ; end format spec
  ) ; end cond
) ; end define rhombus-format-spec-source

(define (rhombus-parenthesized-expression-source source)
  (string-append "(" source ")")
) ; end define rhombus-parenthesized-expression-source

(define (rhombus-call-source name arg-sources)
  (string-append name
                 "("
                 (string-join arg-sources ", ")
                 ")"
  ) ; end string-append
) ; end define rhombus-call-source

(define (rhombus-list-source item-sources)
  (string-append "["
                 (string-join item-sources ", ")
                 "]"
  ) ; end string-append
) ; end define rhombus-list-source

(define (rhombus-string-literal-source value)
  (format "~s" value)
) ; end define rhombus-string-literal-source

(define (split-rhombus-interpolation-source source)
  (define suffix-index (find-rhombus-suffix-index source))
  (if suffix-index
      (values (substring source 0 suffix-index)
              (substring source suffix-index)
      ) ; end values
      (values source "")
  ) ; end if
) ; end define split-rhombus-interpolation-source

(define (find-rhombus-suffix-index source)
  (define length (string-length source))
  (let loop ((index 0)
             (depth 0)
        ) ; end loop bindings
    (cond
      ((= index length)
       #f
      ) ; end end
      (else
       (define ch (string-ref source index))
       (cond
         ((char=? ch #\")
          (loop (find-racket-string-end source index) depth)
         ) ; end string
         ((template-prefix-at? source index)
          (loop (find-template-literal-end source index) depth)
         ) ; end nested template
         ((rhombus-line-comment-at? source index)
          (loop (find-rhombus-line-comment-end source index) depth)
         ) ; end line comment
         ((rhombus-block-comment-at? source index)
          (loop (find-rhombus-block-comment-end source index) depth)
         ) ; end block comment
         ((memv ch '(#\( #\[ #\{))
          (loop (add1 index) (add1 depth))
         ) ; end open delimiter
         ((memv ch '(#\) #\] #\}))
          (loop (add1 index) (max 0 (sub1 depth)))
         ) ; end close delimiter
         ((and (zero? depth)
               (rhombus-explicit-suffix-at? source index)
               (not (string-blank? (substring source 0 index)))
          ) ; end and
          index
         ) ; end suffix
         (else
          (loop (add1 index) depth)
         ) ; end ordinary
       ) ; end cond
      ) ; end more
    ) ; end cond
  ) ; end let loop
) ; end define find-rhombus-suffix-index

(define (rhombus-explicit-suffix-at? source index)
  (define ch (string-ref source index))
  (cond
    ((char=? ch #\!)
     (and (< (add1 index) (string-length source))
          (memv (string-ref source (add1 index)) '(#\s #\r #\a))
     ) ; end and
    ) ; end conversion
    ((char=? ch #\:)
     (and (not (and (positive? index)
                    (char=? (string-ref source (sub1 index)) #\:)))
          (not (and (< (add1 index) (string-length source))
                    (char=? (string-ref source (add1 index)) #\:)))
          (rhombus-format-suffix-at? source index)
     ) ; end and
    ) ; end format
    (else #f)
  ) ; end cond
) ; end define rhombus-explicit-suffix-at?

(define (rhombus-format-suffix-at? source index)
  (define length (string-length source))
  (cond
    ((= (add1 index) length)
     #t
    ) ; end empty spec
    (else
     (define first (string-ref source (add1 index)))
     (or (rhombus-format-start-char? first)
         (and (< (+ index 2) length)
              (rhombus-alignment-char? (string-ref source (+ index 2)))
         ) ; end fill and align
     ) ; end or
    ) ; end non-empty
  ) ; end cond
) ; end define rhombus-format-suffix-at?

(define (rhombus-format-start-char? ch)
  (or (char-numeric? ch)
      (memv ch '(#\. #\< #\> #\^ #\= #\+ #\- #\space
                 #\# #\{ #\s #\d #\b #\o #\x #\X
                 #\f #\F #\e #\E #\g #\G #\%))
  ) ; end or
) ; end define rhombus-format-start-char?

(define (rhombus-alignment-char? ch)
  (memv ch '(#\< #\> #\^ #\=))
) ; end define rhombus-alignment-char?

(define (parse-rhombus-interpolation-suffix suffix)
  (define text (string-trim suffix))
  (cond
    ((equal? text "")
     (values "" #f)
    ) ; end no suffix
    (else
     (define conversion "")
     (define rest text)
     (when (char=? (string-ref rest 0) #\!)
       (define conversion-char
         (and (< 1 (string-length rest))
              (string-ref rest 1)
         ) ; end and
       ) ; end define conversion-char
       (unless (memv conversion-char '(#\s #\r #\a))
         (raise-arguments-error 'tstring-rhombus
                                "unsupported conversion; expected !s, !r, or !a"
                                "suffix"
                                suffix
         ) ; end raise-arguments-error
       ) ; end unless
       (set! conversion (string conversion-char))
       (set! rest (string-trim (substring rest 2)))
     ) ; end when
     (define format-spec #f)
     (cond
       ((equal? rest "")
        (void)
       ) ; end no format
       ((char=? (string-ref rest 0) #\:)
        (set! format-spec (substring rest 1))
       ) ; end format
       (else
        (raise-arguments-error 'tstring-rhombus
                               "extra text after interpolation expression; use ! for conversions or : for format specs"
                               "suffix"
                               suffix
        ) ; end raise-arguments-error
       ) ; end invalid
     ) ; end cond
     (values conversion format-spec)
    ) ; end suffix
  ) ; end cond
) ; end define parse-rhombus-interpolation-suffix

(define (string-blank? text)
  (for/and ((ch (in-string text)))
    (char-whitespace? ch)
  ) ; end for/and
) ; end define string-blank?

(define (rhombus-line-comment-at? source index)
  (and (< (add1 index) (string-length source))
       (char=? (string-ref source index) #\/)
       (char=? (string-ref source (add1 index)) #\/)
  ) ; end and
) ; end define rhombus-line-comment-at?

(define (find-rhombus-line-comment-end source index)
  (define length (string-length source))
  (let loop ((index index))
    (cond
      ((= index length) length)
      ((char=? (string-ref source index) #\newline) (add1 index))
      (else (loop (add1 index)))
    ) ; end cond
  ) ; end let loop
) ; end define find-rhombus-line-comment-end

(define (rhombus-block-comment-at? source index)
  (and (< (add1 index) (string-length source))
       (char=? (string-ref source index) #\/)
       (char=? (string-ref source (add1 index)) #\*)
  ) ; end and
) ; end define rhombus-block-comment-at?

(define (find-rhombus-block-comment-end source index)
  (define length (string-length source))
  (let loop ((index (+ index 2))
             (depth 1)
        ) ; end loop bindings
    (cond
      ((= index length) length)
      ((and (< (add1 index) length)
            (char=? (string-ref source index) #\/)
            (char=? (string-ref source (add1 index)) #\*)
       ) ; end and
       (loop (+ index 2) (add1 depth))
      ) ; end nested open
      ((and (< (add1 index) length)
            (char=? (string-ref source index) #\*)
            (char=? (string-ref source (add1 index)) #\/)
       ) ; end and
       (define next-depth (sub1 depth))
       (if (zero? next-depth)
           (+ index 2)
           (loop (+ index 2) next-depth)
       ) ; end if
      ) ; end close
      (else
       (loop (add1 index) depth)
      ) ; end other
    ) ; end cond
  ) ; end let loop
) ; end define find-rhombus-block-comment-end
