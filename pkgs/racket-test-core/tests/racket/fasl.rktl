
(load-relative "loadtest.rktl")

(Section 'fasl)

(require racket/fasl
         (only-in racket/linklet
                  correlated?
                  correlated-e
                  datum->correlated
                  correlated-property)
         (only-in racket/fixnum fxvector)
         (only-in racket/flonum flvector)
         (only-in racket/pvector
                  pvector pvector? pvector-ref pvector-length list->pvector
                  pvector-cons-right pvector-cons-left pvector-append
                  pvector-take pvector-drop)
         (only-in racket/private/pvector-runtime-adapter
                  pvector-shape-stats))

(define immutables
  ;; If you update this list, then also update `immutable-regression-bstr`:
  `(0 #t #f ,(void) ,eof
      1 #\2 three "four" #"five" #:six #&7 #(8 9 10) (11 . 12) (13 14 . fifteen)
      ;; Use only hash tables where the keys sort
      #hash((sixteen . 17) (nineteen . 18))
      #hasheq((20 . "twenty-one") (22 . "twenty-three"))
      #hasheqv((24 . 25) (26 . 27))
      #s(twenty-eight 29 30 "31")
      -32
      -275
      3300
      34000
      350000
      3600000
      370000000
      -370000001
      38000000000
      390000000000000
      4000000000000000000
      15511210043330985984000000
      -15511210043330985984000000
      41.0
      4.2
      43/100
      44+100i
      45.0+100.0i
      ;; 46f0 <- test separately, because RacketCS doesn't support single-precision
      ,(srcloc "x" 1 2 3 4)
      ,(prefab-key->struct-type 'record 5)))

;; The fasl format is meant to be forward-compatible:
(define immutables-regression-bstr
  #"racket/fasl:\0\200A\1\34'n\4\3\6\ao\r2\16\5three\23\4four\25\4five\21\3six\"u \3vwx\36yz\35\2{|\16\afifteen%\1\2\16\bnineteen\200\16\asixteen\177%\0\2\202\23\ntwenty-one\204\23\ftwenty-three%\2\2\206\207\210\211#\16\ftwenty-eight\3\213\214\23\00231\b\340\b\200\355\376\b\200\344\f\b\201\320\204\0\0\b\2010W\5\0\b\201\200\3566\0\b\201\200\300\r\26\b\201\177?\362\351\b\202\0\374\371\330\b\0\0\0\b\202\0`v\363\263b\1\0\b\202\0\0\220\235\316\332\2027\b\203\25cd4a0619fb0907bc00000\b\203\26-cd4a0619fb0907bc00000\t\0\0\0\0\0\200D@\t\315\314\314\314\314\314\20@\v\231\322\f\232\322\f\t\0\0\0\0\0\200F@\t\0\0\0\0\0\0Y@&\23\1xopqr*\16\6records")

(for ([i (in-list immutables)])
  (test i fasl->s-exp (s-exp->fasl i)))

(when (single-flonum-available?)
  (let ([n46f0 (real->single-flonum 46.0)])
    (test n46f0 fasl->s-exp (s-exp->fasl n46f0))
    (test (vector #t n46f0) fasl->s-exp (s-exp->fasl (vector #t n46f0))))
  (let ([nan (real->single-flonum +nan.0)])
    (test #t eqv? nan (fasl->s-exp (s-exp->fasl nan)))))

(test "4.5t0" format "~a" (fasl->s-exp (s-exp->fasl 4.5t0)))

(test immutables fasl->s-exp (s-exp->fasl immutables))
(test (list immutables immutables) fasl->s-exp (s-exp->fasl (list immutables immutables)))

(test immutables-regression-bstr s-exp->fasl immutables)

(let* ([g (gensym)])
  (define s-exp (fasl->s-exp (s-exp->fasl (list g g g))))
  (test #f eq? g (car s-exp))
  (test #t eq? (car s-exp) (cadr s-exp))
  (test #t eq? (car s-exp) (caddr s-exp)))

(let* ([u (string->unreadable-symbol "unread")])
  (define s-exp (fasl->s-exp (s-exp->fasl (list u u))))
  (test #t eq? u (car s-exp))
  (test #t eq? u (cadr s-exp)))

(let* ([u (string->uninterned-symbol "unread")])
  (define vs-exp (vector-ref (fasl->s-exp (s-exp->fasl (vector (cons u u)))) 0))
  ;; these are not `eq?` to the original symbol, but are `eq? to each other
  (test #t eq? (car vs-exp) (cdr vs-exp))
  (define hs-exp (hash-ref (fasl->s-exp (s-exp->fasl (hasheq 0 (cons u u)))) 0))
  (test #t eq? (car hs-exp) (cdr hs-exp)))

(let ()
  ;; Check that a prefab struct key is not duplicated in fasled form
  (define s (s-exp->fasl (list #s(look-for-this-prefab-key 1)
                               #s(look-for-this-prefab-key 2))))
  (test #f regexp-match? #rx"look-for-this-prefab-key.*look-for-this-prefab-key" s))

;; check uses datum-intern-literal:
(test #t eq? "hello" (fasl->s-exp (s-exp->fasl "hello")))
(test #t eq? #"hello" (fasl->s-exp (s-exp->fasl #"hello")))

(test #f eq? "hello" (fasl->s-exp (s-exp->fasl "hello") #:datum-intern? #f))
(test #f eq? #"hello" (fasl->s-exp (s-exp->fasl #"hello") #:datum-intern? #f))
(test #f eq? #rx"hello" (fasl->s-exp (s-exp->fasl #rx"hello") #:datum-intern? #f))
(test #f eq? #px"hello" (fasl->s-exp (s-exp->fasl #px"hello") #:datum-intern? #f))
(test #f eq? #rx#"hello" (fasl->s-exp (s-exp->fasl #rx#"hello") #:datum-intern? #f))
(test #f eq? #px#"hello" (fasl->s-exp (s-exp->fasl #px#"hello") #:datum-intern? #f))
(test #f eq? #px#"hello" (fasl->s-exp (s-exp->fasl #px#"hello") #:datum-intern? #f))

(test #t equal? (fxvector 1 2 3) (fasl->s-exp (s-exp->fasl (fxvector 1 2 3))))
(test #t equal? (fxvector) (fasl->s-exp (s-exp->fasl (fxvector))))
(test #t equal? (flvector 1. 2. 3.) (fasl->s-exp (s-exp->fasl (flvector 1. 2. 3.))))
(test #t equal? (flvector) (fasl->s-exp (s-exp->fasl (flvector))))

;; pvectors: every representation size, nested, and as a container
;; of shared and lifted values
(let ([pv (pvector 1 2 3)])
  (define rt (fasl->s-exp (s-exp->fasl pv)))
  (test #t pvector? rt)
  (test pv values rt)
  ;; the encoding is part of the forward-compatible format: tag 45,
  ;; length 3, a shape byte for a one-element prefix and a two-element
  ;; suffix with no middle, then the elements
  (test #"racket/fasl:\0\6-\3\1opq" s-exp->fasl pv))
;; the encoding is structural: every shape round-trips to the same shape
(define (check-pvector-shape-round-trip pv)
  (define rt (fasl->s-exp (s-exp->fasl pv)))
  (test pv values rt)
  (test (pvector-shape-stats pv) pvector-shape-stats rt))
(for ([n (in-list '(2 5 17 100 5000))])
  (check-pvector-shape-round-trip (list->pvector (build-list n values)))
  (check-pvector-shape-round-trip (for/fold ([pv (pvector)]) ([i (in-range n)])
                                    (pvector-cons-right pv i)))
  (check-pvector-shape-round-trip (for/fold ([pv (pvector)]) ([i (in-range n)])
                                    (pvector-cons-left pv i)))
  (check-pvector-shape-round-trip (pvector-append (list->pvector (build-list n values))
                                                  (for/fold ([pv (pvector)]) ([i (in-range n)])
                                                    (pvector-cons-right pv i)))))
;; shared subtrees are written once: slices and self-appends add only
;; their spines to the encoding
(let* ([big (list->pvector (build-list 20000 values))]
       [one (bytes-length (s-exp->fasl big))]
       [with-slices (bytes-length (s-exp->fasl (list big
                                                     (pvector-take big 10000)
                                                     (pvector-drop big 10000)
                                                     (pvector-take big 19000))))]
       [self-append (bytes-length (s-exp->fasl (pvector-append big big)))])
  (test #t < with-slices (+ one 2000))
  (test #t < self-append (+ one 2000))
  (test (list big (pvector-take big 10000) (pvector-drop big 10000) (pvector-take big 19000))
        fasl->s-exp
        (s-exp->fasl (list big (pvector-take big 10000) (pvector-drop big 10000) (pvector-take big 19000))))
  (test (pvector-append big big) fasl->s-exp (s-exp->fasl (pvector-append big big)))
  (test (pvector-shape-stats (pvector-append big big))
        pvector-shape-stats
        (fasl->s-exp (s-exp->fasl (pvector-append big big)))))
;; a node is accepted only inside a pvector: a stream whose top-level
;; value is a leaf node (tag 46, kind 6, two small integers) is rejected
(let ([bad (bytes-append #"racket/fasl:\0\4" (bytes 46 6 101 102))])
  (err/rt-test (fasl->s-exp bad) exn:fail? #rx"outside a pvector"))
;; shared nodes can form a DAG whose measure doubles at each level:
;; definition k is a link node whose children are definition k-1 and a
;; reference to it; a chain that overflows the maximum length is
;; rejected by the link constructor rather than wrapping the measure
(let ()
  (define (fasl-int n)
    (if (< n 128)
        (bytes n)
        (bytes 128 (bitwise-and n 255) (arithmetic-shift n -8))))
  (define (chain k)
    (if (zero? k)
        (bytes-append (bytes 1) (fasl-int 0) (bytes 46 6 111 111))
        (bytes-append (bytes 1) (fasl-int k) (bytes 46 2)
                      (chain (sub1 k))
                      (bytes 2) (fasl-int (sub1 k)))))
  (define (stream k len)
    ;; tag 45, length, shape byte 16 = one-element digits with a middle,
    ;; prefix element 1, the middle chain, suffix element 1
    (define data (bytes-append (bytes 45) (fasl-int len) (bytes 16 111) (chain k) (bytes 111)))
    (bytes-append #"racket/fasl:" (fasl-int (add1 k)) (fasl-int (bytes-length data)) data))
  (define ok (fasl->s-exp (stream 10 (+ 2 (expt 2 11)))))
  (test #t pvector? ok)
  (test (+ 2 (expt 2 11)) pvector-length ok)
  (test 1 pvector-ref ok 1000)
  (err/rt-test (fasl->s-exp (stream 57 2)) exn:fail? #rx"too large"))
(for ([n (in-list '(0 1 2 3 4 5 6 17 100 5000))])
  (define pv (list->pvector (build-list n (lambda (i) (- i 20)))))
  (define rt (fasl->s-exp (s-exp->fasl pv)))
  (test #t pvector? rt)
  (test n pvector-length rt)
  (test pv values rt)
  (test (list pv (vector pv) (box pv) (hasheq 'k pv) #s(wrap pv))
        fasl->s-exp (s-exp->fasl (list pv (vector pv) (box pv) (hasheq 'k pv) #s(wrap pv)))))
(let ([pv (pvector (pvector) (pvector "one" 'two #"three" 4.0) (list (pvector 5)))])
  (test pv fasl->s-exp (s-exp->fasl pv)))
(let ([pv (pvector "look-for-this-string" 'look-for-this-symbol
                   "look-for-this-string" 'look-for-this-symbol)])
  (define s (s-exp->fasl pv))
  (test pv fasl->s-exp s)
  ;; sharing detection reaches into pvector elements:
  (test #f regexp-match? #rx"look-for-this-string.*look-for-this-string" s)
  (test #f regexp-match? #rx"look-for-this-symbol.*look-for-this-symbol" s))
(let* ([u (string->uninterned-symbol "unread")]
       [rt (fasl->s-exp (s-exp->fasl (pvector u (list u))))])
  (test #t eq? (pvector-ref rt 0) (car (pvector-ref rt 1))))
(let ([lifts '()]
      [data (pvector 'a (pvector 'b 1) (list 'c))])
  (let ([bstr (s-exp->fasl data
                           #:external-lift? (lambda (v)
                                              (cond
                                                [(memq v '(a b c))
                                                 (set! lifts (cons v lifts))
                                                 #t]
                                                [else #f])))])
    (test '(c b a) values lifts)
    (test data fasl->s-exp bstr #:external-lifts (list->vector (reverse lifts)))))
(test (pvector 1 2 3) fasl->s-exp (s-exp->fasl (pvector 1 2 3) #:skip-prefix? #t) #:skip-prefix? #t)
(test (pvector 1 2 3) fasl->s-exp (s-exp->fasl (pvector 1 2 3)) #:datum-intern? #f)

(let* ([r1 #rx"[/\u5C][. ]+ap"]
       [r2 #px"[/\u5C][. ]+ap"]
       [r3 #px#"[\\][. ]+ap*"])
  (test #t equal? r1 (fasl->s-exp (s-exp->fasl r1) #:datum-intern? #f))
  (test #t equal? r2 (fasl->s-exp (s-exp->fasl r2) #:datum-intern? #f))
  (test #t equal? r3 (fasl->s-exp (s-exp->fasl r3) #:datum-intern? #f)))

(let* ([s (gensym)]
       [c (datum->correlated (list s s)
                             (vector s 1 2 3 4))]
       [c (correlated-property c 'key s)])
  (define c2 (fasl->s-exp (s-exp->fasl c)))
  (test #t correlated? c2)
  (define e (correlated-e c2))
  (test #t pair? e)
  (test #t eq? (car e) (cadr e))
  (test #t eq? (car e) (correlated-property c2 'key)))

(define (check-hash make-hash hash)
  (let ([mut (make-hash)]
        [immut (hash 'one 2 'three 4)])
    (for ([(k v) (in-hash immut)])
      (hash-set! mut k v))
    (test immut fasl->s-exp (s-exp->fasl immut))
    (test #t equal? immut (fasl->s-exp (s-exp->fasl mut)))
    (test #f equal? mut (fasl->s-exp (s-exp->fasl mut)))
    (test #t equal? mut (fasl->s-exp (s-exp->fasl mut #:keep-mutable? #t)))))

(check-hash make-hash hash)
(check-hash make-hasheq hasheq)
(check-hash make-hasheqv hasheqv)
(check-hash make-hashalw hashalw)

(define (check-mutable make-x)
  (test #t immutable? (fasl->s-exp (s-exp->fasl (make-x 3))))
  (test #f immutable? (fasl->s-exp (s-exp->fasl (make-x 3) #:keep-mutable? #t))))
(check-mutable make-vector)
(check-mutable make-string)
(check-mutable make-bytes)

(test (current-directory) fasl->s-exp (s-exp->fasl (current-directory)))
(parameterize ([current-write-relative-directory #f])
  (let ([unix-path (bytes->path #"here" 'unix)]
        [windows-path (bytes->path #"there" 'windows)])
    (test unix-path fasl->s-exp (s-exp->fasl unix-path))
    (test windows-path fasl->s-exp (s-exp->fasl windows-path))
    (if (eq? (system-path-convention-type) 'unix)
        (test (srcloc "here" 1 2 3 4) fasl->s-exp (s-exp->fasl (srcloc unix-path 1 2 3 4)))
        (test (srcloc "there" 1 2 3 4) fasl->s-exp (s-exp->fasl (srcloc windows-path 1 2 3 4))))
    (let ([root (car (filesystem-root-list))])
      (test (srcloc (path->string root) 1 2 3 4) fasl->s-exp (s-exp->fasl (srcloc root 1 2 3 4)))
      (test (srcloc (path->string (build-path root "x")) 1 2 3 4) fasl->s-exp (s-exp->fasl (srcloc (build-path root "x") 1 2 3 4)))
      (test (srcloc (path->string (build-path root 'up)) 1 2 3 4) fasl->s-exp (s-exp->fasl (srcloc (build-path root 'up) 1 2 3 4)))
      (test (srcloc (path->string (build-path root 'same)) 1 2 3 4) fasl->s-exp (s-exp->fasl (srcloc (build-path root 'same) 1 2 3 4))))
    (test (srcloc ".../a/b" 1 2 3 4) fasl->s-exp (s-exp->fasl (srcloc (build-path (current-directory) "a" "b") 1 2 3 4)))))

(let* ([file-p (build-path "data.rktd")]
       [dir-p (build-path "nested")]
       [rel-p (build-path dir-p file-p)]
       [p (build-path (current-directory) rel-p)]
       [unnested-p (build-path (current-directory) file-p)])
  (define-values (bstr srcloc-bstr)
    (parameterize ([current-write-relative-directory (current-directory)])
      (values
       (s-exp->fasl p)
       (s-exp->fasl (srcloc p 10 20 30 40)))))
  (parameterize ([current-load-relative-directory #f])
    (test p fasl->s-exp bstr)
    (test (srcloc p 10 20 30 40) fasl->s-exp srcloc-bstr))
  (parameterize ([current-load-relative-directory (current-directory)])
    (test p fasl->s-exp bstr)
    (test (srcloc p 10 20 30 40) fasl->s-exp srcloc-bstr))

  ;; Try a pair for `current-write-relative-directory`
  (let* ([alt-rel-p (build-path "alternate" "bytes.rktd")]
         [alt-p (build-path (current-directory) alt-rel-p)])
    (define-values (bstr srcloc-bstr bstr2 srcloc-bstr2)
      (parameterize ([current-write-relative-directory (cons (build-path (current-directory) dir-p)
                                                             (current-directory))])
        (values
         (s-exp->fasl p)
         (s-exp->fasl (srcloc p 10 20 30 40))
         (s-exp->fasl alt-p)
         (s-exp->fasl (srcloc alt-p 10 20 30 40)))))
    (parameterize ([current-load-relative-directory #f])
      (test unnested-p fasl->s-exp bstr)
      (test (srcloc unnested-p 10 20 30 40) fasl->s-exp srcloc-bstr)
      (test (build-path (current-directory) 'up alt-rel-p) fasl->s-exp bstr2)
      (test (srcloc (build-path (current-directory) 'up alt-rel-p) 10 20 30 40) fasl->s-exp srcloc-bstr2))
    (parameterize ([current-load-relative-directory (build-path (current-directory) dir-p)])
      (test p fasl->s-exp bstr)
      (test (srcloc p 10 20 30 40) fasl->s-exp srcloc-bstr)
      (let ([up-alt-p (build-path (current-directory) dir-p 'up alt-rel-p)])
        (test up-alt-p fasl->s-exp bstr2)
        (test (srcloc up-alt-p 10 20 30 40) fasl->s-exp srcloc-bstr2)))))

(test (srcloc ".../a" 1 2 3 4) fasl->s-exp (s-exp->fasl (srcloc (build-path 'up "a") 1 2 3 4)))
(test (srcloc ".../a" 1 2 3 4) fasl->s-exp (s-exp->fasl (srcloc (build-path 'same "a") 1 2 3 4)))
(test (srcloc ".../a/.." 1 2 3 4) fasl->s-exp (s-exp->fasl (srcloc (build-path "a" 'up) 1 2 3 4)))
(test (srcloc ".../a/." 1 2 3 4) fasl->s-exp (s-exp->fasl (srcloc (build-path "a" 'same) 1 2 3 4)))

(let ([root (car (filesystem-root-list))])
  (test
   root
   'longer-relative
   (parameterize ([current-write-relative-directory (build-path root "a")])
     (fasl->s-exp (s-exp->fasl root))))

  (test
   (build-path (current-directory) 'same)
   'this-dir-path
   (parameterize ([current-write-relative-directory root]
                  [current-load-relative-directory #f])
     (fasl->s-exp (s-exp->fasl (build-path root 'same))))))

(test (list (dynamic-require 'racket/unsafe/undefined 'unsafe-undefined))
      fasl->s-exp (s-exp->fasl (list (dynamic-require 'racket/unsafe/undefined 'unsafe-undefined))))

;; Check external-lift support:
(let ([lifts '()]
      [data '(a #(b) #s(posn c d a a) #&c)])
  (let ([bstr (s-exp->fasl data
                           #:external-lift? (lambda (v)
                                              (cond
                                                [(memq v '(a b c d))
                                                 (set! lifts (cons v lifts))
                                                 #t]
                                                [else #f])))])
    (test data fasl->s-exp bstr #:external-lifts (list->vector (reverse lifts)))))

(report-errs)
