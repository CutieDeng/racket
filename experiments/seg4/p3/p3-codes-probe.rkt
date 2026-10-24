;; ===== locate rumble's eq-hash-code `codes` table via collect-request-handler =====
(module p3-codes-probe '#%kernel
  (#%require '#%linklet)
  (define-values (SP)
    "/private/tmp/claude-501/-Users-cutiedeng-Y2026-M07-D16-racket-feat-swisstable/d5d1ca89-29ba-48e9-9226-2d4a258a56cd/scratchpad")
  (define-values (P3) (string-append SP "/p3"))
  (define-values (chez-eval) (primitive-lookup 'eval))
  (define-values (sysw) (primitive-lookup 'call-with-system-wind))
  (define-values (ceval) (lambda (s) (sysw (lambda () (chez-eval s)))))
  (ceval (list 'load (string-append P3 "/p3.2-boot.chez.ss")))
  (ceval (list 'begin
               (list 'p32-load-into (string-append P3 "/p3.2-head.chez.ss"))))
  (ceval '(p32-in
           '(let ()
              (define (o . xs) (for-each display xs) (newline))
              (define crh (collect-request-handler))
              ;; BFS closure free vars looking for weak eq-hashtables
              (define seen (make-eq-hashtable))
              (define found '())
              (define (weak-eq-ht? x)
                (and (hashtable? x) (eq-hashtable? x)
                     (try (lambda () (hashtable-weak? x)) #f)))
              (o "collect-request-handler: " crh)
              (let bfs ([q (list crh)] [n 0])
                (unless (or (null? q) (fx> n 60000))
                  (let ([x (car q)])
                    (cond
                      [(eq-hashtable-ref seen x #f) (bfs (cdr q) (fx+ n 1))]
                      [else
                       (eq-hashtable-set! seen x #t)
                       (when (weak-eq-ht? x)
                         ;; sample values: all fixnums?
                         (let-values ([(ks vs) (hashtable-entries x)])
                           (let ([m (vector-length vs)])
                             (let ([allfx (let lp ([i 0] [ok #t])
                                            (if (or (not ok) (fx>= i (fxmin m 30)))
                                                ok
                                                (lp (fx+ i 1) (fixnum? (vector-ref vs i)))))])
                               (when (and (fx> m 0) allfx)
                                 (set! found (cons (cons x m) found))
                                 (o "  CANDIDATE weak-eq-ht size=" m
                                    " sample-vals=" (let lp ([i 0] [acc '()])
                                                      (if (or (fx>= i (fxmin m 6)))
                                                          (reverse acc)
                                                          (lp (fx+ i 1) (cons (vector-ref vs i) acc))))))))))
                       (let ([kids
                              (cond
                                [(and (procedure? x) (not ($cont? x)) (safe-clen x))
                                 => (lambda (len)
                                      (let lp ([i 0] [acc '()])
                                        (if (fx>= i len) acc
                                            (lp (fx+ i 1) (cons ($cref x i) acc)))))]
                                [(pair? x) (list (car x) (cdr x))]
                                [(vector? x) (vector->list x)]
                                [(box? x) (list (unbox x))]
                                [else '()])])
                         (bfs (append kids (cdr q)) (fx+ n 1)))]))))
              (o "candidates: " (length found))))))
