#lang racket/base

(provide
 transform-template-prefixes
 transform-template-prefixes/positions
 find-racket-string-end
 find-template-source-end
 find-template-literal-end
 find-template-literal-content
 find-interpolation-source-end
 template-prefix-at?
) ; end provide

(struct template-literal
  (kind prefix-start quote-start content-start content-end end)
  #:transparent)

(define (transform-template-prefixes source)
  (define length (string-length source))
  (define out (open-output-string))
  (let loop ((index 0))
    (cond
      ((= index length)
       (get-output-string out)
      ) ; end end of source
      (else
       (define ch (string-ref source index))
       (cond
         ((char=? ch #\")
          (define next-index (copy-racket-string source index out))
          (loop next-index)
         ) ; end ordinary string
         ((char=? ch #\;)
          (define next-index (copy-line-comment source index out))
          (loop next-index)
         ) ; end line comment
         ((and (char=? ch #\#)
               (< (add1 index) length)
               (char=? (string-ref source (add1 index)) #\|)
          ) ; end and
          (define next-index (copy-block-comment source index out))
          (loop next-index)
         ) ; end block comment
         ((template-prefix-at? source index)
          (define next-index (copy-template-form source index out))
          (loop next-index)
         ) ; end template prefix
         (else
          (write-char ch out)
          (loop (add1 index))
         ) ; end ordinary character
       ) ; end cond char dispatch
      ) ; end more source
    ) ; end cond
  ) ; end let loop
) ; end define transform-template-prefixes

(define (transform-template-prefixes/positions source)
  (define length (string-length source))
  (define out (open-output-string))
  (define positions-rev '(0))
  (define (record-position! text source-count)
    (define byte-count (bytes-length (string->bytes/utf-8 text)))
    (for ((_index (in-range byte-count)))
      (set! positions-rev (cons source-count positions-rev))
    ) ; end for
  ) ; end define record-position!
  (define (emit-generated-string text source-count)
    (write-string text out)
    (record-position! text source-count)
  ) ; end define emit-generated-string
  (define (emit-source-char index)
    (define ch (string-ref source index))
    (write-char ch out)
    (record-position! (string ch) (add1 index))
  ) ; end define emit-source-char
  (define (emit-source-range start-index end-index)
    (let loop ((index start-index))
      (unless (= index end-index)
        (emit-source-char index)
        (loop (add1 index))
      ) ; end unless end
    ) ; end let loop
  ) ; end define emit-source-range
  (let loop ((index 0))
    (cond
      ((= index length)
       (values (get-output-string out)
               (list->vector (reverse positions-rev))
       ) ; end values
      ) ; end end of source
      (else
       (define ch (string-ref source index))
       (cond
         ((char=? ch #\")
          (define next-index (find-racket-string-end source index))
          (emit-source-range index next-index)
          (loop next-index)
         ) ; end ordinary string
         ((char=? ch #\;)
          (define next-index (find-line-comment-end source index))
          (emit-source-range index next-index)
          (loop next-index)
         ) ; end line comment
         ((and (char=? ch #\#)
               (< (add1 index) length)
               (char=? (string-ref source (add1 index)) #\|)
          ) ; end and
          (define next-index (find-block-comment-end source index))
          (emit-source-range index next-index)
          (loop next-index)
         ) ; end block comment
         ((template-prefix-at? source index)
          (define next-index
            (emit-template-form/positions source index emit-generated-string)
          ) ; end define next-index
          (loop next-index)
         ) ; end template prefix
         (else
          (emit-source-char index)
          (loop (add1 index))
         ) ; end ordinary character
       ) ; end cond char dispatch
      ) ; end more source
    ) ; end cond
  ) ; end let loop
) ; end define transform-template-prefixes/positions

(define (template-prefix-at? source index)
  (and (read-template-literal source index) #t)
) ; end define template-prefix-at?

(define (find-template-literal-end source index)
  (define literal (read-template-literal source index))
  (unless literal
    (raise-arguments-error 'racket-tstring-reader
                           "expected template string literal"
                           "index"
                           index
    ) ; end raise-arguments-error
  ) ; end unless literal
  (template-literal-end literal)
) ; end define find-template-literal-end

(define (find-template-literal-content source index)
  (define literal (read-template-literal source index))
  (unless literal
    (raise-arguments-error 'racket-tstring-reader
                           "expected template string literal"
                           "index"
                           index
    ) ; end raise-arguments-error
  ) ; end unless literal
  (values (substring source
                     (template-literal-content-start literal)
                     (template-literal-content-end literal)
          ) ; end substring
          (template-literal-end literal)
  ) ; end values
) ; end define find-template-literal-content

(define (read-template-literal source index)
  (and (template-prefix-start? source index)
       (let ((prefix (read-template-prefix source index)))
         (and prefix
              (let* ((kind (list-ref prefix 0))
                     (quote-start (list-ref prefix 1))
                     (quote-length (template-quote-length source quote-start))
                ) ; end let* bindings
                (and quote-length
                     (let ((end (find-template-source-end source quote-start)))
                       (template-literal kind
                                         index
                                         quote-start
                                         (+ quote-start quote-length)
                                         (- end quote-length)
                                         end
                       ) ; end template-literal
                     ) ; end let end
                ) ; end and quote
              ) ; end let*
         ) ; end and prefix
       ) ; end let
  ) ; end and
) ; end define read-template-literal

(define (read-template-prefix source index)
  (define length (string-length source))
  (define (char-at offset)
    (and (< (+ index offset) length)
         (string-ref source (+ index offset))
    ) ; end and
  ) ; end define char-at
  (define first (char-at 0))
  (define second (char-at 1))
  (cond
    ((not first) #f)
    ((lower-template-kind-char? first)
     (cond
       ((and second (char=? second #\"))
        (when (triple-quote-at? source (add1 index))
          (unsupported-template-prefix-error
           "triple-quoted template strings are not supported; use Racket double-quoted string syntax"
           index
          ) ; end unsupported-template-prefix-error
        ) ; end when triple quote
        (list first (add1 index))
       ) ; end f"..."
       ((and second (char=? second #\'))
        (unsupported-template-prefix-error
         "single-quoted template strings are not supported; use Racket double-quoted string syntax"
         index
        ) ; end and
       ) ; end f'...'
       ((and (raw-prefix-char? second)
             (quote-char? (char-at 2))
        ) ; end and
        (unsupported-template-prefix-error
         "raw template prefixes are not supported; use Racket string escaping"
         index
        ) ; end unsupported-template-prefix-error
       ) ; end fr"..."
       (else #f)
     ) ; end cond kind first
    ) ; end kind first
    ((and (upper-template-kind-char? first)
          (quote-char? second)
     ) ; end and
     (unsupported-template-prefix-error
      "uppercase template prefixes are not supported; use f or t"
      index
     ) ; end unsupported-template-prefix-error
    ) ; end F"..."
    ((and (raw-prefix-char? first)
          (or (lower-template-kind-char? second)
              (upper-template-kind-char? second)
          ) ; end or
          (quote-char? (char-at 2))
     ) ; end and
     (unsupported-template-prefix-error
      "raw template prefixes are not supported; use Racket string escaping"
      index
     ) ; end unsupported-template-prefix-error
    ) ; end rf"..."
    (else #f)
  ) ; end cond
) ; end define read-template-prefix

(define (lower-template-kind-char? ch)
  (and ch (memv ch '(#\f #\t)))
) ; end define lower-template-kind-char?

(define (upper-template-kind-char? ch)
  (and ch (memv ch '(#\F #\T)))
) ; end define upper-template-kind-char?

(define (raw-prefix-char? ch)
  (and ch (char=? (char-downcase ch) #\r))
) ; end define raw-prefix-char?

(define (quote-char? ch)
  (and ch (memv ch '(#\" #\')))
) ; end define quote-char?

(define (triple-quote-at? source quote-index)
  (and (< (+ quote-index 2) (string-length source))
       (char=? (string-ref source quote-index) #\")
       (char=? (string-ref source (add1 quote-index)) #\")
       (char=? (string-ref source (+ quote-index 2)) #\")
  ) ; end and
) ; end define triple-quote-at?

(define (unsupported-template-prefix-error message index)
  (raise-arguments-error 'racket-tstring-reader
                         message
                         "index"
                         index
  ) ; end raise-arguments-error
) ; end define unsupported-template-prefix-error

(define (template-quote-length source quote-index)
  (define length (string-length source))
  (and (< quote-index length)
       (char=? (string-ref source quote-index) #\")
       1
  ) ; end and
) ; end define template-quote-length

(define (template-prefix-start? source index)
  (or (= index 0)
      (delimiter? (string-ref source (sub1 index)))
  ) ; end or
) ; end define template-prefix-start?

(define (delimiter? ch)
  (or (char-whitespace? ch)
      (memv ch '(#\( #\) #\[ #\] #\{ #\} #\' #\` #\,))
  ) ; end or
) ; end define delimiter?

(define (copy-template-form source index out)
  (define literal (read-template-literal source index))
  (write-string
   (if (char=? (template-literal-kind literal) #\f)
       "(#%tstring-fpl "
       "(#%tstring-tpl "
   ) ; end if
   out
  ) ; end write-string
  (write-string
   (template-content->string-literal-source
    (substring source
               (template-literal-content-start literal)
               (template-literal-content-end literal)
    ) ; end substring
   ) ; end template-content->string-literal-source
   out
  ) ; end write-string
  (write-string ")" out)
  (template-literal-end literal)
) ; end define copy-template-form

(define (emit-template-form/positions source index emit-generated-string)
  (define literal (read-template-literal source index))
  (define literal-end (template-literal-end literal))
  (emit-generated-string
   (if (char=? (template-literal-kind literal) #\f)
       "(#%tstring-fpl "
       "(#%tstring-tpl "
   ) ; end if
   literal-end
  ) ; end emit-generated-string
  (emit-generated-string
   (template-content->string-literal-source
    (substring source
               (template-literal-content-start literal)
               (template-literal-content-end literal)
    ) ; end substring
   ) ; end template-content->string-literal-source
   literal-end
  ) ; end emit-generated-string
  (emit-generated-string ")" literal-end)
  literal-end
) ; end define emit-template-form/positions

(define (template-content->string-literal-source content)
  (define out (open-output-string))
  (write-char #\" out)
  (let loop ((index 0))
    (cond
      ((= index (string-length content))
       (write-char #\" out)
       (get-output-string out)
      ) ; end end of content
      (else
       (define ch (string-ref content index))
       (cond
         ((char=? ch #\\)
          (cond
            ((< (add1 index) (string-length content))
             (define next (string-ref content (add1 index)))
             (cond
               ((char=? next #\')
                (write-char next out)
               ) ; end single quote escape
               ((char=? next #\")
                (write-string "\\\"" out)
               ) ; end double quote escape
               (else
                (write-char ch out)
                (write-char next out)
               ) ; end ordinary escape
             ) ; end cond next
             (loop (+ index 2))
            ) ; end escaped character
            (else
             (write-char ch out)
             (loop (add1 index))
            ) ; end trailing backslash
          ) ; end cond escape
         ) ; end escape
         ((char=? ch #\")
          (write-string "\\\"" out)
          (loop (add1 index))
         ) ; end quote
         (else
          (write-char ch out)
          (loop (add1 index))
         ) ; end ordinary character
       ) ; end cond char dispatch
      ) ; end more content
    ) ; end cond
  ) ; end let loop
) ; end define template-content->string-literal-source

(define (copy-racket-string source index out)
  (define next-index (find-racket-string-end source index))
  (write-string (substring source index next-index) out)
  next-index
) ; end define copy-racket-string

(define (find-racket-string-end source start-index)
  (define length (string-length source))
  (let loop ((index (add1 start-index)))
    (cond
      ((= index length)
       (raise-arguments-error 'racket-tstring-reader
                              "unclosed string literal"
                              "index"
                              start-index
       ) ; end raise-arguments-error
      ) ; end end of source
      (else
       (define ch (string-ref source index))
       (cond
         ((char=? ch #\\)
          (loop (if (< (add1 index) length)
                    (+ index 2)
                    (add1 index)
                ) ; end if
          ) ; end loop
         ) ; end escape
         ((char=? ch #\")
          (add1 index)
         ) ; end close quote
         (else
          (loop (add1 index))
         ) ; end ordinary string character
       ) ; end cond char dispatch
      ) ; end more source
    ) ; end cond
  ) ; end let loop
) ; end define find-racket-string-end

(define (find-template-source-end source quote-index)
  (define length (string-length source))
  (define quote-length (template-quote-length source quote-index))
  (unless quote-length
    (raise-arguments-error 'racket-tstring-reader
                           "expected template string quote"
                           "index"
                           quote-index
    ) ; end raise-arguments-error
  ) ; end unless quote
  (define quote-char (string-ref source quote-index))
  (let loop ((index (+ quote-index quote-length)))
    (cond
      ((= index length)
       (raise-arguments-error 'racket-tstring-reader
                              "unclosed template string literal"
                              "index"
                              quote-index
       ) ; end raise-arguments-error
      ) ; end end of source
      (else
       (define ch (string-ref source index))
       (cond
         ((char=? ch #\\)
          (loop (if (< (add1 index) length)
                    (+ index 2)
                    (add1 index)
                ) ; end if
          ) ; end loop
         ) ; end escape
         ((closing-template-quote-at? source index quote-char quote-length)
          (+ index quote-length)
         ) ; end close template quote
         ((and (char=? ch #\{)
               (< (add1 index) length)
               (char=? (string-ref source (add1 index)) #\{)
          ) ; end and
          (loop (+ index 2))
         ) ; end literal left brace
         ((and (char=? ch #\})
               (< (add1 index) length)
               (char=? (string-ref source (add1 index)) #\})
          ) ; end and
          (loop (+ index 2))
         ) ; end literal right brace
         ((char=? ch #\{)
          (loop (find-interpolation-source-end source (add1 index)))
         ) ; end interpolation
         (else
          (loop (add1 index))
         ) ; end text character
       ) ; end cond char dispatch
      ) ; end more source
    ) ; end cond
  ) ; end let loop
) ; end define find-template-source-end

(define (closing-template-quote-at? source index quote-char quote-length)
  (define length (string-length source))
  (and (<= (+ index quote-length) length)
       (let loop ((offset 0))
         (cond
           ((= offset quote-length) #t)
           ((char=? (string-ref source (+ index offset)) quote-char)
            (loop (add1 offset))
           ) ; end matching quote
           (else #f)
         ) ; end cond
       ) ; end let loop
  ) ; end and
) ; end define closing-template-quote-at?

(define (find-interpolation-source-end source start-index)
  (define length (string-length source))
  (let loop ((index start-index)
             (brace-depth 0)
        ) ; end loop bindings
    (cond
      ((= index length)
       (raise-arguments-error 'racket-tstring-reader
                              "unclosed interpolation in template string"
                              "index"
                              start-index
       ) ; end raise-arguments-error
      ) ; end end of source
      (else
       (define ch (string-ref source index))
       (cond
         ((char=? ch #\")
          (loop (find-racket-string-end source index)
                brace-depth
          ) ; end loop
         ) ; end racket string
         ((template-prefix-at? source index)
          (loop (find-template-literal-end source index)
                brace-depth
          ) ; end loop
         ) ; end nested template
         ((char=? ch #\|)
          (loop (find-bar-symbol-end source index)
                brace-depth
          ) ; end loop
         ) ; end escaped symbol
         ((char-literal-at? source index)
          (loop (find-char-literal-end source index)
                brace-depth
          ) ; end loop
         ) ; end character literal
         ((datum-comment-at? source index)
          (loop (find-datum-comment-end source index)
                brace-depth
          ) ; end loop
         ) ; end datum comment
         ((char=? ch #\;)
          (loop (find-line-comment-end source index)
                brace-depth
          ) ; end loop
         ) ; end line comment
         ((and (char=? ch #\#)
               (< (add1 index) length)
               (char=? (string-ref source (add1 index)) #\|)
          ) ; end and
          (loop (find-block-comment-end source index)
                brace-depth
          ) ; end loop
         ) ; end block comment
         ((char=? ch #\{)
          (loop (add1 index)
                (add1 brace-depth)
          ) ; end loop
         ) ; end nested brace
         ((char=? ch #\})
          (if (zero? brace-depth)
              (add1 index)
              (loop (add1 index)
                    (sub1 brace-depth)
              ) ; end loop
          ) ; end if
         ) ; end right brace
         (else
          (loop (add1 index)
                brace-depth
          ) ; end loop
         ) ; end expression character
       ) ; end cond char dispatch
      ) ; end more source
    ) ; end cond
  ) ; end let loop
) ; end define find-interpolation-source-end

(define (char-literal-at? source index)
  (and (< (+ index 2) (string-length source))
       (char=? (string-ref source index) #\#)
       (char=? (string-ref source (add1 index)) #\\)
  ) ; end and
) ; end define char-literal-at?

(define (find-char-literal-end source index)
  (define length (string-length source))
  (define char-start (+ index 2))
  (cond
    ((>= char-start length)
     length
    ) ; end incomplete character literal
    (else
     (let loop ((index (add1 char-start)))
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
    ) ; end character literal
  ) ; end cond
) ; end define find-char-literal-end

(define (find-bar-symbol-end source index)
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
) ; end define find-bar-symbol-end

(define (datum-comment-at? source index)
  (and (< (add1 index) (string-length source))
       (char=? (string-ref source index) #\#)
       (char=? (string-ref source (add1 index)) #\;)
  ) ; end and
) ; end define datum-comment-at?

(define (find-datum-comment-end source index)
  (define length (string-length source))
  (define comment-source (substring source (+ index 2)))
  (define port (open-input-string comment-source))
  (with-handlers ((exn:fail?
                   (lambda (_exn)
                     length
                   ) ; end lambda
                  ) ; end exn:fail?
                 ) ; end handlers
    (define commented-stx (read-syntax 'template-interpolation port))
    (if (eof-object? commented-stx)
        length
        (+ index 2 (file-position port))
    ) ; end if
  ) ; end with-handlers
) ; end define find-datum-comment-end

(define (racket-token-delimiter? ch)
  (or (char-whitespace? ch)
      (memv ch '(#\( #\) #\[ #\] #\{ #\} #\" #\' #\` #\, #\;))
  ) ; end or
) ; end define racket-token-delimiter?

(define (find-line-comment-end source index)
  (define length (string-length source))
  (let loop ((index index))
    (cond
      ((= index length)
       index
      ) ; end end of source
      ((char=? (string-ref source index) #\newline)
       (add1 index)
      ) ; end newline
      (else
       (loop (add1 index))
      ) ; end more comment
    ) ; end cond
  ) ; end let loop
) ; end define find-line-comment-end

(define (find-block-comment-end source index)
  (define length (string-length source))
  (let loop ((index index)
             (depth 0)
        ) ; end loop bindings
    (cond
      ((= index length)
       index
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
       ) ; end ordinary comment character
      ) ; end ordinary comment character
    ) ; end cond
  ) ; end let loop
) ; end define find-block-comment-end

(define (copy-line-comment source index out)
  (define length (string-length source))
  (let loop ((index index))
    (cond
      ((= index length)
       index
      ) ; end end of source
      (else
       (define ch (string-ref source index))
       (write-char ch out)
       (if (char=? ch #\newline)
           (add1 index)
           (loop (add1 index))
       ) ; end if
      ) ; end more source
    ) ; end cond
  ) ; end let loop
) ; end define copy-line-comment

(define (copy-block-comment source index out)
  (define length (string-length source))
  (let loop ((index index)
             (depth 0)
        ) ; end loop bindings
    (cond
      ((= index length)
       index
      ) ; end end of source
      ((and (< (add1 index) length)
            (char=? (string-ref source index) #\#)
            (char=? (string-ref source (add1 index)) #\|)
       ) ; end and
       (write-string "#|" out)
       (loop (+ index 2)
             (add1 depth)
       ) ; end loop
      ) ; end nested open comment
      ((and (< (add1 index) length)
            (char=? (string-ref source index) #\|)
            (char=? (string-ref source (add1 index)) #\#)
       ) ; end and
       (write-string "|#" out)
       (define next-depth (sub1 depth))
       (if (zero? next-depth)
           (+ index 2)
           (loop (+ index 2)
                 next-depth
           ) ; end loop
       ) ; end if
      ) ; end close comment
      (else
       (write-char (string-ref source index) out)
       (loop (add1 index)
             depth
       ) ; end ordinary comment character
      ) ; end ordinary comment character
    ) ; end cond
  ) ; end let loop
) ; end define copy-block-comment
