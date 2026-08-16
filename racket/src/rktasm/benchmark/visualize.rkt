#lang racket

;; visualize.rkt - SHA1 benchmark visualization
;; 读取 JSON 结果，输出文本图表

(require json)

;; ============================================================
;; Data loading
;; ============================================================

(define (load-results path)
  (with-input-from-file path
    (lambda () (read-json))))

;; ============================================================
;; ASCII bar chart
;; ============================================================

(define bar-width 50)

(define (make-bar value max-value)
  (define len (exact-floor (* bar-width (/ value max-value))))
  (string-append (make-string len #\█)
                 (make-string (- bar-width len) #\░)))

(define (format-size bytes)
  (cond
    [(>= bytes 1048576) (format "~aM" (quotient bytes 1048576))]
    [(>= bytes 1024) (format "~aK" (quotient bytes 1024))]
    [else (format "~aB" bytes)]))

;; ============================================================
;; Output
;; ============================================================

(define (print-header)
  (displayln "")
  (displayln "╔══════════════════════════════════════════════════════════════════════════════╗")
  (displayln "║                         SHA1 Benchmark Results                               ║")
  (displayln "╚══════════════════════════════════════════════════════════════════════════════╝")
  (displayln ""))

(define (print-size-section data-obj)
  (define data-size (hash-ref data-obj 'data_size))
  (define results (hash-ref data-obj 'results))
  (define max-mbps (apply max (map (lambda (r) (hash-ref r 'mbps)) results)))
  (define baseline-mbps (hash-ref (first results) 'mbps))

  (printf "┌─ Data Size: ~a ─────────────────────────────────────────────────────────────┐\n"
          (format-size data-size))
  (displayln "│")

  (for ([r (in-list results)])
    (define name (hash-ref r 'name))
    (define mbps (hash-ref r 'mbps))
    (define relative (/ mbps baseline-mbps))
    (define bar (make-bar mbps max-mbps))

    (printf "│ ~a~a │ ~a │ ~a MB/s (~ax)\n"
            name
            (make-string (- 15 (string-length name)) #\space)
            bar
            (~r mbps #:precision '(= 1) #:min-width 8)
            (~r relative #:precision '(= 2))))

  (displayln "│")
  (displayln "└──────────────────────────────────────────────────────────────────────────────┘")
  (displayln ""))

(define (print-summary all-data)
  (displayln "╔══════════════════════════════════════════════════════════════════════════════╗")
  (displayln "║                              Summary                                         ║")
  (displayln "╚══════════════════════════════════════════════════════════════════════════════╝")
  (displayln "")

  ;; Collect all implementation names
  (define first-results (hash-ref (first all-data) 'results))
  (define impl-names (map (lambda (r) (hash-ref r 'name)) first-results))

  ;; Calculate average speedup for each implementation
  (printf "Average throughput (MB/s) by data size:\n\n")
  (printf "~a" (make-string 12 #\space))
  (for ([name (in-list impl-names)])
    (printf "~a~a" name (make-string (max 1 (- 14 (string-length name))) #\space)))
  (displayln "")
  (printf "~a" (make-string 12 #\-))
  (for ([_ (in-list impl-names)])
    (printf "~a" (make-string 14 #\-)))
  (displayln "")

  (for ([data-obj (in-list all-data)])
    (define size (hash-ref data-obj 'data_size))
    (define results (hash-ref data-obj 'results))
    (printf "~a~a"
            (format-size size)
            (make-string (- 12 (string-length (format-size size))) #\space))
    (for ([r (in-list results)])
      (define mbps (hash-ref r 'mbps))
      (printf "~a~a"
              (~r mbps #:precision '(= 1) #:min-width 10)
              (make-string 4 #\space)))
    (displayln ""))

  (displayln "")

  ;; Calculate overall speedup
  (define (avg-speedup impl-idx)
    (define speedups
      (for/list ([data-obj (in-list all-data)])
        (define results (hash-ref data-obj 'results))
        (define baseline (hash-ref (list-ref results 0) 'mbps))
        (define current (hash-ref (list-ref results impl-idx) 'mbps))
        (/ current baseline)))
    (/ (apply + speedups) (length speedups)))

  (displayln "Average speedup vs C-reference:")
  (for ([name (in-list impl-names)]
        [i (in-naturals)])
    (when (> i 0)
      (printf "  ~a: ~ax\n" name (~r (avg-speedup i) #:precision '(= 2)))))
  (displayln ""))

;; ============================================================
;; Main
;; ============================================================

(define (main args)
  (when (null? args)
    (displayln "Usage: racket visualize.rkt <results.json>")
    (exit 1))

  (define path (first args))
  (unless (file-exists? path)
    (printf "File not found: ~a\n" path)
    (exit 1))

  (define all-data (load-results path))

  (print-header)
  (for ([data-obj (in-list all-data)])
    (print-size-section data-obj))
  (print-summary all-data))

(main (vector->list (current-command-line-arguments)))
