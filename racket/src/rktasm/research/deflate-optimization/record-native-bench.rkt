#!/usr/bin/env racket
#lang racket

(require racket/cmdline
         racket/file
         racket/list
         racket/runtime-path
         racket/string)

(define-runtime-path root-dir "../..")
(define-runtime-path bench-source "bench-native.rkt")
(define-runtime-path default-output-dir "runs")

(struct bench-run (index timestamp header rows) #:transparent)

(define (capture-command exe . args)
  (define-values (proc out in err) (apply subprocess #f #f #f exe args))
  (close-output-port in)
  (define stdout (port->string out))
  (define stderr (port->string err))
  (subprocess-wait proc)
  (values (subprocess-status proc) stdout stderr))

(define (must-capture-command exe . args)
  (define-values (status stdout stderr) (apply capture-command exe args))
  (unless (zero? status)
    (display stdout)
    (display stderr (current-error-port))
    (error 'record-native-bench "command failed with status ~a: ~a ~a"
           status exe args))
  (values stdout stderr))

(define (git-output fallback . args)
  (define git-exe (find-executable-path "git"))
  (cond
    [(not git-exe) fallback]
    [else
     (define-values (status stdout _stderr)
       (apply capture-command git-exe "-C" root-dir args))
     (if (zero? status)
         (string-trim stdout)
         fallback)]))

(define (git-dirty-state)
  (define status (git-output "unknown" "status" "--porcelain"))
  (cond
    [(equal? status "unknown") "unknown"]
    [(equal? status "") "clean"]
    [else "dirty"]))

(define (pad2 n)
  (if (< n 10)
      (format "0~a" n)
      (number->string n)))

(define (timestamp-string)
  (define d (seconds->date (current-seconds)))
  (format "~a-~a-~aT~a:~a:~a"
          (date-year d)
          (pad2 (date-month d))
          (pad2 (date-day d))
          (pad2 (date-hour d))
          (pad2 (date-minute d))
          (pad2 (date-second d))))

(define (filename-timestamp timestamp)
  (regexp-replace* #px"[:-]" timestamp ""))

(define (sanitize-label label)
  (define cleaned (regexp-replace* #px"[^A-Za-z0-9_.-]+" label "_"))
  (if (equal? cleaned "") "run" cleaned))

(define (non-empty-lines text)
  (filter (lambda (line)
            (not (equal? "" (string-trim line))))
          (string-split text "\n")))

(define (csv-lines text)
  (define lines
    (dropf (non-empty-lines text)
           (lambda (line) (not (string-prefix? line "codec,case,")))))
  (and (pair? lines) lines))

(define (run-benchmark-once index iterations)
  (define racket-exe (find-system-path (quote exec-file)))
  (unless racket-exe
    (error 'record-native-bench "racket executable not found"))
  (define-values (stdout stderr)
    (must-capture-command racket-exe
                          bench-source
                          "--iterations"
                          (number->string iterations)))
  (unless (equal? "" stderr)
    (display stderr (current-error-port)))
  (define lines (csv-lines stdout))
  (cond
    [(not lines)
     (printf "native benchmark skipped; no CSV emitted:\n~a" stdout)
     #f]
    [else
     (bench-run index
                (timestamp-string)
                (first lines)
                (rest lines))]))

(define (write-recorded-runs output-path runs label iterations)
  (define first-run (first runs))
  (define bench-header (bench-run-header first-run))
  (define git-head (git-output "unknown" "rev-parse" "--short" "HEAD"))
  (define dirty-state (git-dirty-state))
  (define meta-header
    "run_index,timestamp,label,host_os,host_arch,git_head,git_dirty,iterations")
  (call-with-output-file output-path
    #:exists 'error
    (lambda (out)
      (fprintf out "~a,~a\n" meta-header bench-header)
      (for ([run (in-list runs)])
        (unless (equal? bench-header (bench-run-header run))
          (error 'record-native-bench "benchmark CSV header changed between runs"))
        (for ([row (in-list (bench-run-rows run))])
          (fprintf out "~a,~a,~a,~a,~a,~a,~a,~a,~a\n"
                   (bench-run-index run)
                   (bench-run-timestamp run)
                   label
                   (system-type 'os)
                   (system-type 'arch)
                   git-head
                   dirty-state
                   iterations
                   row))))))

(define (fresh-output-path output-dir stem)
  (let loop ([suffix 0])
    (define filename
      (if (zero? suffix)
          (format "~a.csv" stem)
          (format "~a-~a.csv" stem suffix)))
    (define path (build-path output-dir filename))
    (if (file-exists? path)
        (loop (add1 suffix))
        path)))

(define (record-native-benchmark output-dir iterations run-count label)
  (make-directory* output-dir)
  (define clean-label (sanitize-label label))
  (define started-at (timestamp-string))
  (define runs
    (filter values
            (for/list ([index (in-range 1 (add1 run-count))])
              (printf "native benchmark run ~a/~a\n" index run-count)
              (run-benchmark-once index iterations))))
  (cond
    [(empty? runs) (void)]
    [else
     (define output-stem
       (format "~a-~a-i~a-r~a"
               (filename-timestamp started-at)
               clean-label
               iterations
               run-count))
     (define output-path (fresh-output-path output-dir output-stem))
     (write-recorded-runs output-path runs clean-label iterations)
     (printf "recorded native benchmark: ~a\n" output-path)]))

(module+ main
  (define iterations 20)
  (define run-count 3)
  (define output-dir default-output-dir)
  (define label "manual")
  (command-line
   #:program "record-native-bench.rkt"
   #:once-each
   [("--iterations") n "Number of encode iterations per benchmark run"
                     (set! iterations (string->number n))]
   [("--runs") n "Number of benchmark runs to record"
               (set! run-count (string->number n))]
   [("--out-dir") path "Directory for recorded CSV files"
                 (set! output-dir path)]
   [("--label") value "Short label embedded in the CSV and output filename"
                (set! label value)]
   #:args ()
   (unless (and (integer? iterations) (positive? iterations))
     (error 'record-native-bench "iterations must be a positive integer"))
   (unless (and (integer? run-count) (positive? run-count))
     (error 'record-native-bench "runs must be a positive integer"))
   (record-native-benchmark output-dir iterations run-count label)))
