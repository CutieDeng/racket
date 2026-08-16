(load-relative "loadtest.rktl"
) ; end load-relative

(Section 'omap
) ; end Section

(require racket/omap racket/compare
) ; end require

;; 三值主形式实例
(define-omap iom #:key-compare fx-compare
) ; end define-omap

(test #t iom-empty? iom-empty
) ; end test
(test 0 iom-count iom-empty
) ; end test

(define m3 (iom-set (iom-set (iom-set iom-empty 2 'b) 1 'a) 3 'c)
) ; end define
(test 3 iom-count m3
) ; end test
(test 'b iom-ref m3 2
) ; end test
(test 'none iom-ref m3 9 'none
) ; end test
(test #t iom-has-key? m3 1
) ; end test
(test #f iom-has-key? m3 9
) ; end test
(test '((1 . a) (2 . b) (3 . c)) iom->pairs m3
) ; end test
(test '(1 . a) iom-min m3
) ; end test
(test '((1 . a) (3 . c)) iom->pairs (iom-delete m3 2)
) ; end test
(test '((1 . a) (2 . b) (3 . c)) iom->pairs (iom-delete m3 9)
) ; end test

;; #:key<? 糖形式
(define-omap som #:key<? string<?
) ; end define-omap
(test '(("a" . 1) ("b" . 2))
      som->pairs (som-set (som-set som-empty "b" 2) "a" 1)
) ; end test

;; 确定性差分: 4096 次 set/delete 对拍排序 assoc (LCG 自产伪随机)
(define (lcg x
        ) ; end lcg
  (modulo (+ (* x 1103515245) 12345) 65536
  ) ; end modulo
) ; end define
(define-values (final-om final-al
               ) ; end values
  (let loop ([i 0] [seed 7] [om iom-empty] [al '()
                                           ] ; end al
            ) ; end bindings
    (if (= i 4096
        ) ; end =
        (values om al
        ) ; end values
        (let* ([seed2 (lcg seed
                      ) ; end lcg
               ] ; end seed2
               [k (modulo seed2 64
                  ) ; end modulo
               ] ; end k
              ) ; end bindings
          (if (even? (quotient seed2 64
                     ) ; end quotient
              ) ; end even?
              (loop (add1 i) seed2 (iom-set om k i)
                    (cons (cons k i)
                          (filter (lambda (p) (not (= (car p) k))) al
                          ) ; end filter
                    ) ; end cons
              ) ; end loop
              (loop (add1 i) seed2 (iom-delete om k)
                    (filter (lambda (p) (not (= (car p) k))) al
                    ) ; end filter
              ) ; end loop
          ) ; end if
        ) ; end let*
    ) ; end if
  ) ; end let
) ; end define-values
(test #t 'omap-differential
      (equal? (iom->pairs final-om)
              (sort final-al < #:key car
              ) ; end sort
      ) ; end equal?
) ; end test
(test #t 'omap-count-differential
      (= (iom-count final-om) (length final-al)
      ) ; end =
) ; end test

(report-errs
) ; end report-errs
