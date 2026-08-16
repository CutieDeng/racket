#lang racket

(require
 "encode.rkt"
 (only-in racket/pvector
          pvector-empty
          pvector-cons-right)
 racket/match)

(provide
 syntax->encode-field
 enforce-32b?
 enforce-unique-encode-name?
 port->encode
 file->encode
 file->encodes)

(define (raise-or-error who msg v stx enc-stx)
  (define msg*
    (if stx
        (format "~a; sub: ~s" msg (syntax->datum stx))
        msg))
  (if enc-stx
      (raise-syntax-error who msg* enc-stx)
      (if stx
          (raise-syntax-error who msg* stx)
          (error who msg* v))))

(define (tags->ordered-map tags [stx #f] [enc-stx #f])
  (cond
    [(list? tags)
     (define seen (make-hash))
     (for/fold ([m (hash)]) ([tag (in-list tags)])
       (unless (string? tag)
         (raise-or-error 'file->encode "invalid tag" tag stx enc-stx))
       (when (hash-ref seen tag #f)
         (raise-or-error 'file->encode "duplicate tag" tag stx enc-stx))
       (hash-set! seen tag #t)
       (hash-set m tag #t))]
    [else (raise-or-error 'file->encode "invalid tags" tags stx enc-stx)]))

(define (assert-field-name! v [stx #f] [enc-stx #f])
  (cond
    [(string? v) v]
    [(eq? v #f) #f]
    [(symbol? v)
     (if (eq? v '_) #f (symbol->string v))]
    [else (raise-or-error 'syntax->encode-field "invalid field name" v stx enc-stx)]))

(define (unwrap-quote v)
  (if (and (pair? v) (eq? (car v) 'quote)
           (pair? (cdr v)) (null? (cddr v)))
      (cadr v)
      v))

(define (syntax->encode-field stx [hi #f] [enc-stx #f])
  (define v (syntax->datum stx))
  (match v
    [(list name len lo hi*)
      (unless (= len (- hi* lo))
        (raise-or-error 'syntax->encode-field "len must equal hi - lo" v stx enc-stx))
      (encode-field (assert-field-name! name stx enc-stx) len lo hi*)]
    [(list name len)
      (unless hi
        (raise-or-error 'syntax->encode-field "missing hi for field" v stx enc-stx))
      (define lo (- hi len))
      (encode-field (assert-field-name! name stx enc-stx) len lo hi)]
    [(cons name len)
      (unless hi
        (raise-or-error 'syntax->encode-field "missing hi for field" v stx enc-stx))
      (define lo (- hi len))
      (encode-field (assert-field-name! name stx enc-stx) len lo hi)]
    [_ (raise-or-error 'syntax->encode-field "invalid field" v stx enc-stx)]))

(define (field-len v [stx #f] [enc-stx #f])
  (match v
    [(list _ len lo hi)
       (unless (= len (- hi lo))
        (raise-or-error 'file->encode "len must equal hi - lo" v stx enc-stx))
     len]
    [(list _ len) len]
    [(cons _ len) len]
    [_ (raise-or-error 'file->encode "invalid field" v stx enc-stx)]))

(define enforce-32b? (make-parameter #t))
(define enforce-unique-encode-name? (make-parameter #t))

(define (fields->pvector fields [fields-stx #f] [enc-stx #f])
  (define fields-stx-list
    (and (syntax? fields-stx) (syntax->list fields-stx)))
  (unless (list? fields)
    (raise-or-error 'file->encode "invalid fields" fields fields-stx enc-stx))
  (define seen (make-hash))
  (define total-bits
    (for/sum ([e (in-list fields)])
      (field-len e fields-stx enc-stx)))
  (when (and (enforce-32b?) (not (= total-bits 32)))
    (raise-or-error 'file->encode "instruction length must be 32 bits" total-bits fields-stx enc-stx))
  (define use-stx-list?
    (and fields-stx-list (= (length fields-stx-list) (length fields))))
  (define-values (pv _)
    (if use-stx-list?
        (for/fold ([acc (pvector-empty)] [hi total-bits])
                  ([e (in-list fields)]
                   [e-stx (in-list fields-stx-list)])
          (define field (syntax->encode-field e-stx hi enc-stx))
          (define name (encode-field-name field))
          (when (and name (hash-ref seen name #f))
            (raise-or-error 'file->encode "duplicate field" name e-stx enc-stx))
          (when name (hash-set! seen name #t))
          (values (pvector-cons-right acc field) (encode-field-lo field)))
        (for/fold ([acc (pvector-empty)] [hi total-bits])
                  ([e (in-list fields)])
          (define e-stx (datum->syntax fields-stx e))
          (define field (syntax->encode-field e-stx hi enc-stx))
          (define name (encode-field-name field))
          (when (and name (hash-ref seen name #f))
            (raise-or-error 'file->encode "duplicate field" name e-stx enc-stx))
          (when name (hash-set! seen name #t))
          (values (pvector-cons-right acc field) (encode-field-lo field)))))
  pv)

(define (syntax->encode form-stx)
  (define stx-items (syntax->list form-stx))
  (define stx
    (if (and stx-items (= (length stx-items) 1))
        (car stx-items)
        form-stx))
  (syntax-case stx ()
    [(name tags fields)
     (begin
       (define name-v (syntax->datum #'name))
       (unless (string? name-v)
         (raise-syntax-error 'port->encode "name must be a string" #'name))
       (define tags-v (unwrap-quote (syntax->datum #'tags)))
       (define fields-v (unwrap-quote (syntax->datum #'fields)))
       (encode name-v
               (tags->ordered-map tags-v #'tags stx)
               (fields->pvector fields-v #'fields stx)))]
    [_ (raise-syntax-error 'port->encode "expected (name tags fields)" stx)]))

(define (port->encode in [source (or (object-name in) 'port)])
  (define stx (read-syntax source in))
  (when (eof-object? stx)
    (error 'port->encode "unexpected EOF"))
  (syntax->encode stx))

(define (file->encode path)
  (call-with-input-file path
    (lambda (in) (port->encode in path))))

(define (file->encodes path [seen #f])
  (call-with-input-file path
    (lambda (in)
      (define enforce-unique-name? (enforce-unique-encode-name?))
      (define seen* (and enforce-unique-name?
                         (or seen (make-hash))))
      (let loop ([acc (pvector-empty)])
        (define stx (read-syntax path in))
        (if (eof-object? stx)
            acc
            (let ([enc (syntax->encode stx)])
              (define name (encode-name enc))
              (when (and enforce-unique-name? (hash-ref seen* name #f))
                (raise-syntax-error
                 'file->encodes
                 (format "duplicate encode name: ~a" name)
                 stx))
              (when enforce-unique-name?
                (hash-set! seen* name #t))
              (loop (pvector-cons-right acc enc))))))))
