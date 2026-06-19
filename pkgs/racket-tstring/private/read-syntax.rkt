#lang racket/base

(require
 racket/port
 "source-transform.rkt"
) ; end require

(provide
 read/tstring
 read-syntax/tstring
 read-interaction/tstring
) ; end provide

(define need-more (gensym 'need-more))
(define no-interaction (gensym 'no-interaction))

(define (read/tstring in)
  (define v (read-syntax/tstring #f in))
  (if (syntax? v)
      (syntax->datum v)
      v
  ) ; end if
) ; end define read/tstring

(define (read-interaction/tstring source-name in)
  (flush-output)
  (parameterize ((read-accept-reader #t)
                 (read-accept-lang #f)
                ) ; end parameterize bindings
    (read-syntax/tstring source-name in)
  ) ; end parameterize
) ; end define read-interaction/tstring

(define (read-syntax/tstring source-name in)
  (unless (input-port? in)
    (raise-argument-error 'read-syntax/tstring "input-port?" in)
  ) ; end unless input port
  (let loop ((byte-offset 0)
             (char-count 0)
             (chars '())
        ) ; end loop bindings
    (define-values (next-byte-offset next-char-count next-chars eof?)
      (peek-source-line in byte-offset char-count chars)
    ) ; end define-values
    (cond
      ((and eof?
            (null? next-chars)
       ) ; end and
       eof
      ) ; end eof before any buffered input
      (else
       (define source (list->string (reverse next-chars)))
       (define error-consumed #f)
       (define-values (status stx consumed)
         (with-handlers ((exn:fail?
                          (lambda (exn)
                            (consume-chars in (or error-consumed next-char-count))
                            (raise exn)
                          ) ; end lambda
                         )
                        ) ; end handlers
           (read-transformed-interaction source-name
                                         source
                                         (not eof?)
                                         (lambda (count)
                                           (set! error-consumed count)
                                         ) ; end lambda
           ) ; end read-transformed-interaction
         ) ; end with-handlers
       ) ; end define-values
       (cond
         ((eq? status need-more)
          (loop next-byte-offset next-char-count next-chars)
         ) ; end need more
         ((and (eq? status no-interaction)
               (not eof?)
          ) ; end and
          (loop next-byte-offset next-char-count next-chars)
         ) ; end no interaction yet
         (else
          (consume-chars in
                         (if (eq? status no-interaction)
                             next-char-count
                             consumed
                         ) ; end if
          ) ; end consume-chars
          (if (eq? status no-interaction)
              eof
              stx
          ) ; end if
         ) ; end buffered input
       ) ; end cond
      ) ; end char
    ) ; end cond
  ) ; end let loop
) ; end define read-syntax/tstring

(define (peek-source-line in byte-offset char-count chars)
  (let loop ((byte-offset byte-offset)
             (char-count char-count)
             (chars chars)
        ) ; end loop bindings
    (define ch (peek-char in byte-offset))
    (cond
      ((eof-object? ch)
       (values byte-offset char-count chars #t)
      ) ; end eof
      (else
       (define next-byte-offset (+ byte-offset (char-utf-8-length ch)))
       (define next-char-count (add1 char-count))
       (define next-chars (cons ch chars))
       (if (char=? ch #\newline)
           (values next-byte-offset next-char-count next-chars #f)
           (loop next-byte-offset next-char-count next-chars)
       ) ; end if
      ) ; end char
    ) ; end cond
  ) ; end let loop
) ; end define peek-source-line

(define (char-utf-8-length ch)
  (bytes-length (string->bytes/utf-8 (string ch)))
) ; end define char-utf-8-length

(define (read-transformed-interaction source-name
                                      source
                                      catch-eof?
                                      [on-error-consumed void]
       ) ; end arguments
  (define (read-it)
    (define-values (transformed-source transformed-positions)
      (transform-template-prefixes/positions source)
    ) ; end define-values
    (define in (open-input-string transformed-source))
    (port-count-lines! in)
    (define stx
      (with-handlers ((exn:fail?
                       (lambda (exn)
                         (on-error-consumed
                          (transformed-position->source-count transformed-positions
                                                              (file-position in)
                          ) ; end transformed-position->source-count
                         ) ; end on-error-consumed
                         (raise exn)
                       ) ; end lambda
                      )
                     ) ; end handlers
        (read-syntax source-name in)
      ) ; end with-handlers
    ) ; end define stx
    (if (eof-object? stx)
        (values no-interaction eof 0)
        (values stx
                stx
                (transformed-position->source-count transformed-positions
                                                    (file-position in)
                ) ; end transformed-position->source-count
        ) ; end values
    ) ; end if
  ) ; end define read-it
  (if catch-eof?
      (with-handlers ((exn:fail:read:eof?
                       (lambda (exn)
                         (values need-more #f 0)
                       ) ; end lambda
                      )
                      (exn:fail?
                       (lambda (exn)
                         (if (transform-incomplete? source)
                             (values need-more #f 0)
                             (raise exn)
                         ) ; end if
                       ) ; end lambda
                      )
                     ) ; end handlers
        (read-it)
      ) ; end with-handlers
      (read-it)
  ) ; end if
) ; end define read-transformed-interaction

(define (transformed-position->source-count transformed-positions position)
  (cond
    ((and (exact-nonnegative-integer? position)
          (< position (vector-length transformed-positions))
     ) ; end and
     (vector-ref transformed-positions position)
    ) ; end known position
    (else
     (vector-ref transformed-positions (sub1 (vector-length transformed-positions)))
    ) ; end fallback
  ) ; end cond
) ; end define transformed-position->source-count

(define (transform-incomplete? source)
  (with-handlers ((exn:fail?
                   (lambda (exn) #t)
                  )
                 ) ; end handlers
    (transform-template-prefixes source)
    #f
  ) ; end with-handlers
) ; end define transform-incomplete?

(define (consume-chars in count)
  (for ((index (in-range count)))
    (read-char in)
  ) ; end for
) ; end define consume-chars
