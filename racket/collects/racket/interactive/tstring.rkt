#lang racket/base

(require
 racket/port
) ; end require

(namespace-require '(lib "tstring/main.rkt"))
(namespace-require '(only (lib "racket-tstring/private/expand.rkt")
                          #%tstring-tpl
                          #%tstring-fpl
                    ) ; end only
) ; end namespace-require

(define need-more (gensym 'need-more))
(define no-interaction (gensym 'no-interaction))

(define (tstring-read-interaction source-name in)
  (flush-output)
  (let loop ((offset 0)
             (chars '())
        ) ; end loop bindings
    (define ch (peek-char in offset))
    (cond
      ((eof-object? ch)
       (cond
         ((null? chars) eof)
         (else
          (define source (list->string (reverse chars)))
          (define-values (status stx consumed)
            (with-handlers ((exn:fail?
                             (lambda (exn)
                               (consume-chars in offset)
                               (raise exn)
                             ) ; end lambda
                            )
                           ) ; end handlers
              (read-transformed-interaction source-name source #f)
            ) ; end with-handlers
          ) ; end define-values
          (consume-chars in
                         (if (eq? status no-interaction)
                             offset
                             consumed
                         ) ; end if
          ) ; end consume-chars
          (if (eq? status no-interaction)
              eof
              stx
          ) ; end if
         ) ; end buffered input
       ) ; end cond
      ) ; end eof
      (else
       (define next-offset (add1 offset))
       (define next-chars (cons ch chars))
       (define source (list->string (reverse next-chars)))
       (define-values (status stx consumed)
         (with-handlers ((exn:fail?
                          (lambda (exn)
                            (consume-chars in next-offset)
                            (raise exn)
                          ) ; end lambda
                         )
                        ) ; end handlers
           (read-transformed-interaction source-name source #t)
         ) ; end with-handlers
       ) ; end define-values
       (cond
         ((or (eq? status need-more)
              (eq? status no-interaction))
          (loop next-offset next-chars)
         ) ; end need more
         ((interaction-complete? source-name source consumed in next-offset)
          (consume-chars in consumed)
          stx
         ) ; end complete interaction
         (else
          (loop next-offset next-chars)
         ) ; end incomplete token
       ) ; end cond
      ) ; end char
    ) ; end cond
  ) ; end let loop
) ; end define tstring-read-interaction

(define (read-transformed-interaction source-name source catch-eof?)
  (define (read-it)
    (define transformed-source ((get-transform-template-prefixes) source))
    (define in (open-input-string transformed-source))
    (port-count-lines! in)
    (define stx (read-syntax source-name in))
    (if (eof-object? stx)
        (values no-interaction eof 0)
        (values stx
                stx
                (transformed-position->source-count source (file-position in))
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

(define (interaction-complete? source-name source consumed original-in next-offset)
  (or (interaction-complete-with-suffix? source-name source consumed #\x)
      (let ((ch (peek-char original-in next-offset)))
        (or (eof-object? ch)
            (interaction-complete-with-suffix? source-name source consumed ch)
        ) ; end or
      ) ; end let
  ) ; end or
) ; end define interaction-complete?

(define (interaction-complete-with-suffix? source-name source consumed ch)
  (with-handlers ((exn:fail?
                   (lambda (exn) #f)
                  )
                 ) ; end handlers
    (define-values (status stx with-suffix-consumed)
      (read-transformed-interaction source-name
                                    (string-append source (string ch))
                                    #t
      ) ; end read-transformed-interaction
    ) ; end define-values
    (and (not (eq? status need-more))
         (not (eq? status no-interaction))
         (= consumed with-suffix-consumed)
    ) ; end and
  ) ; end with-handlers
) ; end define interaction-complete-with-suffix?

(define (transformed-position->source-count source position)
  (let loop ((count 0))
    (define prefix (substring source 0 count))
    (define transformed-length
      (with-handlers ((exn:fail?
                       (lambda (exn) #f)
                      )
                     ) ; end handlers
        (bytes-length
         (string->bytes/utf-8 ((get-transform-template-prefixes) prefix))
        ) ; end bytes-length
      ) ; end with-handlers
    ) ; end define transformed-length
    (cond
      ((and transformed-length
            (>= transformed-length position)
       ) ; end and
       count
      ) ; end found count
      ((= count (string-length source))
       count
      ) ; end fallback
      (else
       (loop (add1 count))
      ) ; end keep looking
    ) ; end cond
  ) ; end let loop
) ; end define transformed-position->source-count

(define (transform-incomplete? source)
  (with-handlers ((exn:fail?
                   (lambda (exn) #t)
                  )
                 ) ; end handlers
    ((get-transform-template-prefixes) source)
    #f
  ) ; end with-handlers
) ; end define transform-incomplete?

(define (consume-chars in count)
  (for ((index (in-range count)))
    (read-char in)
  ) ; end for
) ; end define consume-chars

(define transform-template-prefixes-proc #f)

(define (get-transform-template-prefixes)
  (unless transform-template-prefixes-proc
    (set! transform-template-prefixes-proc
          (dynamic-require '(lib "racket-tstring/private/source-transform.rkt")
                           'transform-template-prefixes
          ) ; end dynamic-require
    ) ; end set!
  ) ; end unless cached
  transform-template-prefixes-proc
) ; end define get-transform-template-prefixes

(when (collection-file-path "main.rkt" "xrepl"
                            #:fail (lambda _ #f)
      ) ; end collection-file-path
  (dynamic-require 'xrepl #f)
  (define toplevel-prefix (dynamic-require 'xrepl/xrepl 'toplevel-prefix))
  (toplevel-prefix "")
) ; end when xrepl

(let ((init-file (cleanse-path (find-system-path 'init-file))))
  (when (file-exists? init-file)
    (load init-file)
  ) ; end when init file
) ; end let init-file

(current-read-interaction tstring-read-interaction)
