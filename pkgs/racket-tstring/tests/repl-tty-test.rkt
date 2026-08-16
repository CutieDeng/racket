#lang racket/base

;; End-to-end REPL alignment tests: drive `racket` on a real pty (via
;; script(1)) and check that the interactive REPL behaves like the
;; stock expeditor-based Racket REPL even though the tstring reader
;; replaces `current-read-interaction`:
;;  - errors and breaks are colored and not prefixed with ";"
;;  - eof (ctl-D) exits silently, without echoing "^D"
;;  - an empty entry does not emit an extra prompt line
;;  - tstring templates still read, including multi-line continuation
;;
;; Raw pty output is normalized through a small terminal renderer so
;; assertions compare the final screen text, not escape-sequence noise.

(require
 rackunit
 racket/string
 racket/list
 racket/file
) ; end require

(define session-deadline-seconds 20)

(define script-path (find-executable-path "script"))

(define (start-repl-session)
  (define racket-path (find-system-path 'exec-file))
  (define addon-dir (make-temporary-addon-dir))
  (parameterize ((current-environment-variables
                  (environment-variables-copy (current-environment-variables))
                 )
                ) ; end parameterize bindings
    (environment-variables-set! (current-environment-variables)
                                #"TERM"
                                #"xterm-256color"
    ) ; end environment-variables-set! TERM
    (environment-variables-set! (current-environment-variables)
                                #"PLTADDONDIR"
                                (path->bytes addon-dir)
    ) ; end environment-variables-set! PLTADDONDIR
    (case (system-type 'os*)
      ((linux)
       (subprocess #f #f #f
                   script-path
                   "-qefc"
                   (format "~a" racket-path)
                   "/dev/null"
       ) ; end subprocess
      ) ; end linux (util-linux script)
      (else
       (subprocess #f #f #f
                   script-path
                   "-q"
                   "/dev/null"
                   racket-path
       ) ; end subprocess
      ) ; end macosx (BSD script)
    ) ; end case
  ) ; end parameterize
) ; end define start-repl-session

(define (make-temporary-addon-dir)
  (define dir
    (build-path (find-system-path 'temp-dir)
                (format "tstring-repl-test-~a" (current-milliseconds))
    ) ; end build-path
  ) ; end define dir
  (make-directory* dir)
  dir
) ; end define make-temporary-addon-dir

(define (make-output-collector port)
  (define lock (make-semaphore 1))
  (define collected (open-output-bytes))
  (thread
   (lambda ()
     (define chunk (make-bytes 4096))
     (let loop ()
       (define n (read-bytes-avail! chunk port))
       (unless (eof-object? n)
         (call-with-semaphore lock
                              (lambda ()
                                (write-bytes chunk collected 0 n)
                              ) ; end lambda
         ) ; end call-with-semaphore
         (loop)
       ) ; end unless
     ) ; end let loop
   ) ; end lambda
  ) ; end thread
  (lambda ()
    (call-with-semaphore lock
                         (lambda ()
                           (get-output-bytes collected)
                         ) ; end lambda
    ) ; end call-with-semaphore
  ) ; end lambda
) ; end define make-output-collector

;; Run one scripted session: `steps` is a list of
;;   (list 'wait regexp)  -- poll output until the regexp matches
;;   (list 'send bytes)   -- write bytes to the pty
;;   (list 'sleep secs)   -- unconditional pause
;; Returns the raw output bytes; fails the current check on timeout.
(define (run-repl-session steps)
  (define-values (proc out in err) (start-repl-session))
  (define get-raw (make-output-collector out))
  (define deadline
    (+ (current-inexact-milliseconds)
       (* 1000 session-deadline-seconds)
    ) ; end +
  ) ; end define deadline
  (define (fail-session what)
    (subprocess-kill proc #t)
    (with-check-info (('raw-output (get-raw)))
      (fail-check (format "repl session timed out: ~a" what))
    ) ; end with-check-info
  ) ; end define fail-session
  (define (wait-until ready?)
    (let loop ()
      (cond
        ((ready?) (void))
        (((current-inexact-milliseconds) . > . deadline) #f)
        (else
         (sleep 0.05)
         (loop)
        ) ; end keep polling
      ) ; end cond
    ) ; end let loop
  ) ; end define wait-until
  (for ((step (in-list steps)))
    (case (car step)
      ((wait)
       (define rx (cadr step))
       (unless (wait-until (lambda () (regexp-match? rx (get-raw))))
         (fail-session (format "waiting for ~s" rx))
       ) ; end unless
      ) ; end wait
      ((send)
       (write-bytes (cadr step) in)
       (flush-output in)
      ) ; end send
      ((sleep)
       (sleep (cadr step))
      ) ; end sleep
    ) ; end case
  ) ; end for
  (unless (sync/timeout session-deadline-seconds proc)
    (fail-session "waiting for process exit")
  ) ; end unless
  (close-output-port in)
  (sleep 0.1)
  (define raw (get-raw))
  (close-input-port out)
  (close-input-port err)
  raw
) ; end define run-repl-session

;; ---------------------------------------------------------------------
;; Dumb terminal renderer: interpret carriage returns, backspaces, and
;; the CSI sequences expeditor emits (cursor moves, erase, colors) and
;; return the final screen as a list of right-trimmed lines.

(define (render-screen-lines raw)
  (define text (bytes->string/utf-8 raw #\?))
  (define length (string-length text))
  (define rows (make-hash))
  (define (row-cells row)
    (hash-ref! rows row (lambda () (make-hash)))
  ) ; end define row-cells
  (let loop ((index 0)
             (row 0)
             (col 0)
             (max-row 0)
        ) ; end loop bindings
    (cond
      ((= index length)
       (screen-lines rows max-row)
      ) ; end end of output
      (else
       (define ch (string-ref text index))
       (cond
         ((char=? ch #\u1B)
          (define-values (next-index next-row next-col)
            (apply-escape text (add1 index) rows row col)
          ) ; end define-values
          (loop next-index next-row next-col (max max-row next-row))
         ) ; end escape sequence
         ((char=? ch #\return)
          (loop (add1 index) row 0 max-row)
         ) ; end carriage return
         ((char=? ch #\newline)
          (loop (add1 index) (add1 row) col (max max-row (add1 row)))
         ) ; end line feed
         ((char=? ch #\backspace)
          (loop (add1 index) row (max 0 (sub1 col)) max-row)
         ) ; end backspace
         ((char=? ch #\u07)
          (loop (add1 index) row col max-row)
         ) ; end bell
         (else
          (hash-set! (row-cells row) col ch)
          (loop (add1 index) row (add1 col) max-row)
         ) ; end printable character
       ) ; end cond char dispatch
      ) ; end more output
    ) ; end cond
  ) ; end let loop
) ; end define render-screen-lines

(define (apply-escape text index rows row col)
  (cond
    ((and (< index (string-length text))
          (char=? (string-ref text index) #\[)
     ) ; end and
     (let loop ((scan (add1 index))
                (params '())
                (current 0)
                (any-digit? #f)
           ) ; end loop bindings
       (cond
         ((= scan (string-length text))
          (values scan row col)
         ) ; end truncated sequence
         (else
          (define ch (string-ref text scan))
          (cond
            ((char-numeric? ch)
             (loop (add1 scan)
                   params
                   (+ (* current 10) (- (char->integer ch) 48))
                   #t
             ) ; end loop
            ) ; end digit
            ((char=? ch #\;)
             (loop (add1 scan) (cons current params) 0 #f)
            ) ; end parameter separator
            (else
             (define n (if any-digit? current 1))
             (define-values (next-row next-col)
               (apply-csi-command ch rows row col n)
             ) ; end define-values
             (values (add1 scan) next-row next-col)
            ) ; end final byte
          ) ; end cond
         ) ; end scanning
       ) ; end cond
     ) ; end let loop
    ) ; end CSI sequence
    (else
     (values (add1 index) row col)
    ) ; end other escape: skip one byte
  ) ; end cond
) ; end define apply-escape

(define (apply-csi-command command rows row col n)
  (case command
    ((#\C) (values row (+ col n)))
    ((#\D) (values row (max 0 (- col n))))
    ((#\A) (values (max 0 (- row n)) col))
    ((#\B) (values (+ row n) col))
    ((#\G) (values row (max 0 (sub1 n))))
    ((#\K)
     (define cells (hash-ref rows row (lambda () #f)))
     (when cells
       (for ((cell-col (in-list (hash-keys cells))))
         (when (cell-col . >= . col)
           (hash-remove! cells cell-col)
         ) ; end when
       ) ; end for
     ) ; end when
     (values row col)
    ) ; end erase to end of line
    ((#\J)
     (for ((cells (in-hash-values rows)))
       (hash-clear! cells)
     ) ; end for
     (values row col)
    ) ; end erase display (treated as clear-all)
    (else (values row col))
  ) ; end case
) ; end define apply-csi-command

(define (screen-lines rows max-row)
  (for/list ((row (in-range (add1 max-row))))
    (define cells (hash-ref rows row (lambda () (make-hash))))
    (define cols (sort (hash-keys cells) <))
    (define width (if (null? cols) 0 (add1 (last cols))))
    (define line (make-string width #\space))
    (for ((col (in-list cols)))
      (string-set! line col (hash-ref cells col))
    ) ; end for
    (string-trim line #:left? #f)
  ) ; end for/list
) ; end define screen-lines

(define (screen-text raw)
  (string-join (render-screen-lines raw) "\n")
) ; end define screen-text

;; Screen without the version banner and without trailing blank lines,
;; for whole-transcript comparisons.
(define (screen-body raw)
  (define lines (render-screen-lines raw))
  (define body (if (null? lines) lines (cdr lines)))
  (let loop ((rev (reverse body)))
    (cond
      ((and (pair? rev)
            (string=? (car rev) "")
       ) ; end and
       (loop (cdr rev))
      ) ; end drop trailing blank line
      (else (reverse rev))
    ) ; end cond
  ) ; end let loop
) ; end define screen-body

;; ---------------------------------------------------------------------
;; Scenarios

(define ctl-C #"\3")
(define ctl-D #"\4")
(define prompt-rx #rx#"> ")

(cond
  ((not script-path)
   (displayln "repl-tty-test: script(1) not found; skipping tty tests")
  ) ; end skip without a pty driver
  (else

   (test-case
    "error display is colored and not \";\"-prefixed"
    (define raw
      (run-repl-session
       (list (list 'wait prompt-rx)
             (list 'send #"(car 1)\r")
             (list 'wait #rx#"contract violation")
             (list 'sleep 0.2)
             (list 'send ctl-D)
       ) ; end list
      ) ; end run-repl-session
    ) ; end define raw
    (define screen (screen-text raw))
    (with-check-info (('screen screen))
      (check regexp-match? #rx#"\\[91m" raw
             "expected bright-red SGR around the error message")
      (check-false (regexp-match? #rx"(?m:^; )" screen)
                   "error lines must not carry the \"; \" prefix")
      (check regexp-match? #rx"(?m:^car: contract violation$)" screen)
      (check regexp-match? #rx"\\[,bt for context\\]" screen)
    ) ; end with-check-info
   ) ; end test-case error display

   (test-case
    "break at the prompt is colored and not \";\"-prefixed"
    (define raw
      (run-repl-session
       (list (list 'wait prompt-rx)
             (list 'sleep 0.3)
             (list 'send ctl-C)
             (list 'wait #rx#"user break")
             (list 'sleep 0.2)
             (list 'send #"(+ 3 4)\r")
             (list 'wait #rx#"\n7\r")
             (list 'sleep 0.2)
             (list 'send ctl-D)
       ) ; end list
      ) ; end run-repl-session
    ) ; end define raw
    (define screen (screen-text raw))
    (with-check-info (('screen screen))
      (check regexp-match? #rx#"\\[91muser break" raw
             "expected bright-red SGR immediately before \"user break\"")
      (check-false (regexp-match? #rx"; user break" screen)
                   "break message must not carry the \"; \" prefix")
      (check regexp-match? #rx"(?m:^7$)" screen)
    ) ; end with-check-info
   ) ; end test-case break

   (test-case
    "empty entries add no output; eof exits silently"
    (define raw
      (run-repl-session
       (list (list 'wait prompt-rx)
             (list 'send #"(+ 1 2)\r")
             (list 'wait #rx#"\n3\r")
             (list 'sleep 0.3)
             (list 'send #"\r")
             (list 'sleep 0.2)
             (list 'send #"\r")
             (list 'sleep 0.2)
             (list 'send #"(+ 3 4)\r")
             (list 'wait #rx#"\n7\r")
             (list 'sleep 0.2)
             (list 'send ctl-D)
       ) ; end list
      ) ; end run-repl-session
    ) ; end define raw
    (define body (screen-body raw))
    (with-check-info (('screen (string-join body "\n")))
      (check-equal? body
                    (list "> (+ 1 2)"
                          "3"
                          "> (+ 3 4)"
                          "7"
                          ">"
                    ) ; end list
      ) ; end check-equal?
      (check-false (regexp-match? #rx"\\^D" (string-join body "\n"))
                   "eof must not be echoed as ^D")
    ) ; end with-check-info
   ) ; end test-case empty entries

   (test-case
    "tstring templates still read in the interactive REPL"
    (define raw
      (run-repl-session
       (list (list 'wait prompt-rx)
             (list 'send #"f\"{(+ 1 2)}\"\r")
             (list 'wait #rx#"\"3\"")
             (list 'sleep 0.2)
             (list 'send ctl-D)
       ) ; end list
      ) ; end run-repl-session
    ) ; end define raw
    (define screen (screen-text raw))
    (with-check-info (('screen screen))
      (check regexp-match? #rx"(?m:^\"3\"$)" screen)
    ) ; end with-check-info
   ) ; end test-case tstring evaluation

   (test-case
    "unterminated template continues onto the next line"
    (define raw
      (run-repl-session
       (list (list 'wait prompt-rx)
             (list 'send #"f\"a")
             (list 'sleep 0.3)
             (list 'send #"\r")
             (list 'sleep 0.3)
             (list 'send #"b\"")
             (list 'sleep 0.3)
             (list 'send #"\r")
             (list 'wait #rx#"\"a\\\\nb\"")
             (list 'sleep 0.2)
             (list 'send ctl-D)
       ) ; end list
      ) ; end run-repl-session
    ) ; end define raw
    (define screen (screen-text raw))
    (with-check-info (('screen screen))
      (check regexp-match? #rx"\"a\\\\nb\"" screen)
      (check-false (regexp-match? #rx"read-syntax" screen)
                   "continuation must not surface a reader error")
    ) ; end with-check-info
   ) ; end test-case template continuation

  ) ; end else run scenarios
) ; end cond
