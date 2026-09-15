;; ===== P3.3 zo code table (loaded into p32-env after p3.3-enum.chez.ss) =====
;; Naming protocol: code external name = (event-index . seq), where event-index
;; counts intercepted/replayed zo bundle-load events in order, and seq is the
;; code's position in the deterministic enumeration of that event's bundle
;; (sorted linklet keys, structural DFS with reloc descent).

;; ---------- A side: code -> name ----------
(define zo-a-tab (make-eq-hashtable))   ; code -> (cons evt seq); first event wins
(define zo-a-events '())                ; reversed list of (vector path enc ncodes)
(define zo-a-codevecs '())              ; reversed, parallel to zo-a-events; for
                                        ; the (evt . seq) -> code roundtrip check
(define zo-a-nevents 0)
(define zo-a-fallbacks '())             ; (path . enc/why) not table-covered
(define zo-a-ncodes 0)

(define (zo-a-on-event! ev)
  (let ([path (vector-ref ev 0)] [enc (vector-ref ev 1)] [prs (vector-ref ev 2)])
    (cond
      [(eq? prs 'fallback)
       (set! zo-a-fallbacks (cons (cons path enc) zo-a-fallbacks))]
      [else
       (let ([idx zo-a-nevents]
             [codes (zo-enum-linklets prs)])
         (let lp ([j 0])
           (when (fx< j (vector-length codes))
             (let ([c (vector-ref codes j)])
               (unless (eq-hashtable-ref zo-a-tab c #f)
                 (eq-hashtable-set! zo-a-tab c (cons idx j))))
             (lp (fx+ j 1))))
         (set! zo-a-ncodes (fx+ zo-a-ncodes (vector-length codes)))
         (set! zo-a-events (cons (vector path enc (vector-length codes)) zo-a-events))
         (set! zo-a-codevecs (cons codes zo-a-codevecs))
         (set! zo-a-nevents (fx+ zo-a-nevents 1)))])))

(define (zo-a-lookup c) (eq-hashtable-ref zo-a-tab c #f))

(define (zo-a-ref evt seq)
  ;; name -> code on A itself (mirror of zo-b-lookup); the list is reversed,
  ;; so event evt sits at position (- nevents 1 evt) from the head
  (let ([v (let lp ([l zo-a-codevecs] [i (fx- zo-a-nevents 1)])
             (cond
               [(null? l) #f]
               [(fx= i evt) (car l)]
               [else (lp (cdr l) (fx- i 1))]))])
    (and v (fx< seq (vector-length v)) (vector-ref v seq))))

(define (zo-a-write-list! path)
  (p3-fasl-to-file! path (vector 'p3-zolist 1 (list->vector (reverse zo-a-events)))))

;; ---------- B side: name -> code ----------
(define zo-b-vecs #f)                   ; vector of per-event code vectors
(define zo-b-nmismatch 0)

(define (zo-b-build! zolist-path loader o)
  ;; loader : (path enc) -> list of (key-string . linklet) | 'none
  (let* ([m (p3-fasl-from-file zolist-path)]
         [evs (vector-ref m 2)]
         [n (vector-length evs)]
         [nbad 0] [ncodes 0])
    (set! zo-b-vecs (make-vector n '#()))
    (let lp ([i 0])
      (when (fx< i n)
        (let* ([ev (vector-ref evs i)]
               [prs (try (lambda () (loader (vector-ref ev 0) (vector-ref ev 1))) 'none)])
          (cond
            [(eq? prs 'none)
             (set! nbad (fx+ nbad 1))
             (o "  zo-load FAILED: " (vector-ref ev 0))]
            [else
             (let ([codes (zo-enum-linklets prs)])
               (vector-set! zo-b-vecs i codes)
               (set! ncodes (fx+ ncodes (vector-length codes)))
               (unless (fx= (vector-length codes) (vector-ref ev 2))
                 (set! zo-b-nmismatch (fx+ zo-b-nmismatch 1))
                 (o "  zo COUNT MISMATCH evt=" i " path=" (vector-ref ev 0)
                    " a-codes=" (vector-ref ev 2) " b-codes=" (vector-length codes))))]))
        (lp (fx+ i 1))))
    (o "zo table: events=" n "  load-failures=" nbad
       "  codes=" ncodes "  count-mismatch-events=" zo-b-nmismatch
       "  wrapped-forced=" zo-enum-stats-wc "  wc-force-fail=" zo-enum-stats-wcfail)
    n))

(define (zo-b-lookup evt seq)
  (and zo-b-vecs
       (fx< evt (vector-length zo-b-vecs))
       (let ([v (vector-ref zo-b-vecs evt)])
         (and (fx< seq (vector-length v)) (vector-ref v seq)))))

;; ---------- creation-probe supply (cpb) ----------
;; Both roles run the same creation probes at the mark point; the deterministic
;; walk below turns the probe results into an indexed code table.  This names
;; boot-static codes that only gain closures at init time (struct machinery
;; accessors/mutators/constructors, regexp matchers).
(define cpb-codes '#())
(define cpb-tab (make-eq-hashtable))    ; code -> idx

(define (cpb-build! probe-vec o)
  (let ([acc '()] [n 0] [seen-c (make-eq-hashtable)] [seen-o (make-eq-hashtable)])
    (define (grab! c)
      (when (and c ($code? c) (not (eq-hashtable-ref seen-c c #f)))
        (eq-hashtable-set! seen-c c #t)
        (set! acc (cons c acc))
        (set! n (fx+ n 1))))
    (define (walk x depth)
      (when (and (fx> depth 0)
                 (heapish? x)
                 (not (eq-hashtable-ref seen-o x #f)))
        (eq-hashtable-set! seen-o x #t)
        (cond
          [(procedure? x)
           (unless ($cont? x)
             (grab! (try (lambda () ($ccode x)) #f))
             (let ([cl (safe-clen x)])
               (when cl
                 (let lp ([i 0])
                   (when (fx< i cl)
                     (walk (try (lambda () ($cref x i)) 0) (fx- depth 1))
                     (lp (fx+ i 1)))))))]
          [(hashtable? x) (void)]
          [($rec? x)
           (let ([nf (rtd-total-fields ($rtd x))])
             (let lp ([i 0])
               (when (fx< i nf)
                 (walk (try (lambda () ($rref x i)) 0) (fx- depth 1))
                 (lp (fx+ i 1)))))]
          [(pair? x)
           (if (or (weak-pair? x) (ephemeron-pair? x))
               (void)
               (begin (walk (car x) (fx- depth 1))
                      (walk (cdr x) (fx- depth 1))))]
          [(vector? x)
           (let lp ([i 0])
             (when (fx< i (vector-length x))
               (walk (vector-ref x i) (fx- depth 1))
               (lp (fx+ i 1))))]
          [(box? x) (walk (unbox x) (fx- depth 1))]
          [else (void)])))
    (walk probe-vec 9)
    (set! cpb-codes (list->vector (reverse acc)))
    (let lp ([i 0])
      (when (fx< i (vector-length cpb-codes))
        (eq-hashtable-set! cpb-tab (vector-ref cpb-codes i) i)
        (lp (fx+ i 1))))
    (o "creation-probe supply (cpb): codes=" n)))

(define (cpb-lookup c) (eq-hashtable-ref cpb-tab c #f))
(define (cpb-ref i)
  (and (fx>= i 0) (fx< i (vector-length cpb-codes)) (vector-ref cpb-codes i)))
