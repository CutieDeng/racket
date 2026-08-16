#!/usr/bin/env racket
#lang racket

(require racket/cmdline
         racket/list
         racket/runtime-path
         racket/string)

(define-runtime-path bench-source "bench-native.rkt")
(define-runtime-path default-baseline "quality-baseline.csv")

(define (capture-command exe . args)
  (define-values (proc out in err) (apply subprocess #f #f #f exe args))
  (close-output-port in)
  (define stdout (port->string out))
  (define stderr (port->string err))
  (subprocess-wait proc)
  (define status (subprocess-status proc))
  (unless (zero? status)
    (display stdout)
    (display stderr (current-error-port))
    (error 'check-native-quality "command failed with status ~a: ~a ~a"
           status exe args))
  (values stdout stderr))

(define (non-empty-lines text)
  (filter (lambda (line)
            (not (equal? "" (string-trim line))))
          (string-split text "\n")))

(define (csv-line->fields line)
  (map string-trim (string-split line ",")))

(define (csv-text->rows text #:allow-prefix? [allow-prefix? #f])
  (define all-lines (non-empty-lines text))
  (define lines
    (if allow-prefix?
        (dropf all-lines (lambda (line) (not (string-prefix? line "codec,case,"))))
        all-lines))
  (cond
    [(empty? lines) '()]
    [else
     (define header (csv-line->fields (first lines)))
     (for/list ([line (in-list (rest lines))]
                #:unless (string-prefix? (string-trim line) "#"))
       (define fields (csv-line->fields line))
       (unless (= (length fields) (length header))
         (error 'check-native-quality "bad CSV row: ~a" line))
       (for/hash ([name (in-list header)]
                  [value (in-list fields)])
         (values name value)))]))

(define (row-ref row field)
  (hash-ref row field
            (lambda () (error 'check-native-quality "missing CSV field: ~a" field))))

(define (row-number row field)
  (define value (string->number (row-ref row field)))
  (unless value
    (error 'check-native-quality "bad numeric field ~a=~a" field (row-ref row field)))
  value)

(define (row-key row)
  (cons (row-ref row "codec") (row-ref row "case")))

(define (format-key key)
  (format "~a/~a" (car key) (cdr key)))

(define (check-quality baseline-path iterations)
  (define racket-exe (find-system-path (quote exec-file)))
  (unless racket-exe
    (error 'check-native-quality "racket executable not found"))
  (define-values (stdout stderr)
    (capture-command racket-exe
                     bench-source
                     "--iterations"
                     (number->string iterations)))
  (unless (equal? "" stderr)
    (display stderr (current-error-port)))
  (define rows (csv-text->rows stdout #:allow-prefix? #t))
  (cond
    [(empty? rows)
     (printf "native quality check skipped; benchmark did not emit CSV:\n~a" stdout)
     (void)]
    [else
     (define baselines (csv-text->rows (file->string baseline-path)))
     (define by-key
       (for/hash ([row (in-list rows)])
         (values (row-key row) row)))
     (define failures '())
     (define (record! fmt . args)
       (set! failures (cons (apply format fmt args) failures)))

     (for ([row (in-list rows)])
       (unless (equal? "ok" (row-ref row "status"))
         (record! "~a reported status ~a"
                  (format-key (row-key row))
                  (row-ref row "status"))))

     (for ([baseline (in-list baselines)])
       (define key (row-key baseline))
       (define current (hash-ref by-key key #f))
       (cond
         [(not current)
          (record! "missing benchmark row for ~a" (format-key key))]
         [else
          (define expected-input (row-number baseline "input_bytes"))
          (define actual-input (row-number current "input_bytes"))
          (unless (= actual-input expected-input)
            (record! "~a input size changed: got ~a expected ~a"
                     (format-key key) actual-input expected-input))
          (define actual-size (row-number current "compressed_bytes"))
          (define max-size (row-number baseline "max_compressed_bytes"))
          (when (> actual-size max-size)
            (record! "~a compressed size regressed: got ~a max ~a"
                     (format-key key) actual-size max-size))]))

     (cond
       [(empty? failures)
        (printf "native quality baseline ok: ~a benchmark rows, ~a guarded rows\n"
                (length rows)
                (length baselines))]
       [else
        (for ([failure (in-list (reverse failures))])
          (fprintf (current-error-port) "~a\n" failure))
        (exit 1)])]))

(module+ main
  (define iterations 3)
  (define baseline-path default-baseline)
  (command-line
   #:program "check-native-quality.rkt"
   #:once-each
   [("--iterations") n "Number of encode iterations to pass to bench-native.rkt"
                     (set! iterations (string->number n))]
   [("--baseline") path "CSV file with codec/case/input/max_compressed_bytes rows"
                 (set! baseline-path path)]
   #:args ()
   (unless (and (integer? iterations) (positive? iterations))
     (error 'check-native-quality "iterations must be a positive integer"))
   (check-quality baseline-path iterations)))
