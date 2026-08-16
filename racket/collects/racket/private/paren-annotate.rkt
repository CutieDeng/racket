#lang racket/base
;; 把普通 Racket 源码重排为 intbits/swisstable 家族风格:
;; 每个非空复合形式的右括号单独换行, 对齐到开括号所在列, 附 "; end <形式头>"。
;; 保留注释、字符串、原有内容换行与缩进; 空表 () 不拆。
(require racket/string racket/port racket/list)

(define src (port->string (current-input-port)))
(define n (string-length src))

;; ---- 词法: 产出 token 列表 (type . text) ----
;; type ∈ open close atom str comment ws
(define (delim? c) (memv c '(#\( #\) #\[ #\] #\{ #\})))
(define (open-c? c) (memv c '(#\( #\[ #\{)))
(define (close-c? c) (memv c '(#\) #\] #\})))
(define (ws-c? c) (memv c '(#\space #\tab #\newline #\return)))

(define toks
  (let loop ([i 0] [acc '()])
    (if (>= i n) (reverse acc)
        (let ([c (string-ref src i)])
          (cond
            [(ws-c? c)
             (let scan ([j i]) (if (and (< j n) (ws-c? (string-ref src j))) (scan (add1 j))
                                   (loop j (cons (cons 'ws (substring src i j)) acc))))]
            [(char=? c #\;)
             (let scan ([j i]) (if (and (< j n) (not (char=? (string-ref src j) #\newline))) (scan (add1 j))
                                   (loop j (cons (cons 'comment (substring src i j)) acc))))]
            [(char=? c #\")
             (let scan ([j (add1 i)])
               (cond [(>= j n) (loop j (cons (cons 'str (substring src i j)) acc))]
                     [(char=? (string-ref src j) #\\) (scan (+ j 2))]
                     [(char=? (string-ref src j) #\") (loop (add1 j) (cons (cons 'str (substring src i (add1 j))) acc))]
                     [else (scan (add1 j))]))]
            [(and (char=? c #\#) (< (add1 i) n) (char=? (string-ref src (add1 i)) #\\))
             ;; 字符字面量 #\x (或命名), 至少吃 #\ 加一字符, 再吃字母
             (let scan ([j (+ i 3)]) (if (and (< j n) (char-alphabetic? (string-ref src j))) (scan (add1 j))
                                         (loop j (cons (cons 'atom (substring src i j)) acc))))]
            [(open-c? c) (loop (add1 i) (cons (cons 'open (string c)) acc))]
            [(close-c? c) (loop (add1 i) (cons (cons 'close (string c)) acc))]
            [else
             (let scan ([j i]) (if (and (< j n) (not (delim? (string-ref src j))) (not (ws-c? (string-ref src j)))
                                        (not (char=? (string-ref src j) #\;)) (not (char=? (string-ref src j) #\")))
                                   (scan (add1 j))
                                   (loop j (cons (cons 'atom (substring src i j)) acc))))])))))

;; ---- 渲染 ----
(define done '())           ; 完成的行 (逆序)
(define cur "")             ; 当前行
(define (col) (string-length cur))
(define (emit s) (set! cur (string-append cur s)))
(define (rtrim s) (string-trim s #:left? #f))
(define (flush!) (set! done (cons (rtrim cur) done)) (set! cur ""))

;; 帧: 可变
(struct frame (open-col [head #:mutable] [arg-col #:mutable] [content? #:mutable] [broke? #:mutable]))
(define stack '())

(define (close-str oc) (case oc [(#\() ")"] [(#\[) "]"] [(#\{) "}"] [else ")"]))
(define open->close (make-hash))
;; 记录每个 open 帧对应的开括号字符
(define (top) (and (pair? stack) (car stack)))

;; 消费父帧 broke: 换行并缩进到父的 arg-col
(define (consume-broke!)
  (define f (top))
  (when (and f (frame-broke? f))
    (set-frame-broke?! f #f)
    (when (> (string-length (rtrim cur)) 0) (flush!))
    (set! cur (make-string (or (frame-arg-col f) (+ (frame-open-col f) 2)) #\space))))

;; 记录内容 + head/arg-col
(define (note-content!)
  (define f (top))
  (when f
    (cond [(not (frame-head f)) (void)]      ; head 由 mark-head! 处理
          [(not (frame-arg-col f)) (set-frame-arg-col! f (col))])
    (set-frame-content?! f #t)))

(for ([t (in-list toks)] [idx (in-naturals)])
  (define ty (car t)) (define tx (cdr t))
  (case ty
    [(ws)
     (define nls (length (regexp-match* #rx"\n" tx)))
     (cond
       [(> nls 0)
        ;; 原换行取代父帧 broke; 保留内容行与空行数
        (when (top) (set-frame-broke?! (top) #f))
        (when (> (string-length (rtrim cur)) 0) (flush!))
        (for ([_ (in-range (sub1 nls))]) (set! done (cons "" done)))
        (set! cur (last (regexp-split #rx"\n" tx)))]
       [else (emit tx)])]
    [(open)
     (consume-broke!)
     (note-content!)
     (define oc (string-ref tx 0))
     (define f (frame (col) #f #f #f #f))
     (hash-set! open->close f (close-str oc))
     (emit tx)
     (set! stack (cons f stack))]
    [(close)
     (define f (top)) (set! stack (cdr stack))
     (define cs (hash-ref open->close f ")"))
     (cond
       [(not (frame-content? f))            ; 空表: 不拆
        (emit cs) (note-content!)]
       [else
        (when (> (string-length (rtrim cur)) 0) (flush!))
        (set! cur (string-append (make-string (frame-open-col f) #\space)
                                 cs " ; end " (or (frame-head f) "")))
        (flush!)
        (define p (top)) (when p (set-frame-broke?! p #t) (set-frame-content?! p #t))])]
    [(comment)
     (consume-broke!)
     (emit tx)]
    [else ; atom str
     (consume-broke!)
     (define f (top))
     (when f
       (cond [(not (frame-head f)) (set-frame-head! f tx) (set-frame-content?! f #t)]
             [else (when (not (frame-arg-col f)) (set-frame-arg-col! f (col)))
                   (set-frame-content?! f #t)]))
     (emit tx)]))
(flush!)

(display (string-join (reverse done) "\n"))
(newline)
