
(define (eval-all i)
  (let loop ()
    (define expr ((current-read-interaction) (object-name i) i))
    (unless (eof-object? expr)
      (call-with-values (lambda ()
                          (call-with-continuation-prompt
                           (lambda ()
                             (let ([w (cons '|#%top-interaction| expr)])
                               (eval (if (syntax? expr)
                                         (namespace-syntax-introduce
                                          (datum->syntax #f w expr))
                                         w))))
                           (default-continuation-prompt-tag)
                           (lambda (proc)
                             ;; continue escape to set error status:
                             (abort-current-continuation (default-continuation-prompt-tag) proc))))
        (lambda vals
          (for-each (lambda (v)
                      (|#%app| (current-print) v)
                      (flush-output))
                    vals)))
      (loop))))
