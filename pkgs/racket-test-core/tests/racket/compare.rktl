(load-relative "loadtest.rktl"
) ; end load-relative

(Section 'compare
) ; end Section

(require racket/compare
) ; end require

;; 谓词
(test #t comparison? '<
) ; end test
(test #t comparison? '=
) ; end test
(test #f comparison? 'lt
) ; end test

;; 叶子比较器
(test '< fx-compare 1 2
) ; end test
(test '> fx-compare 2 1
) ; end test
(test '= fx-compare 3 3
) ; end test
(test '< integer-compare -1 (expt 2 100
                            ) ; end expt
) ; end test
(test '< real-compare 1.5 2.5
) ; end test
(test '< char-compare #\a #\b
) ; end test
(test '< string-compare "abc" "abd"
) ; end test
(test '< string-compare "ab" "abc"
) ; end test
(test '> string-compare "abc" "ab"
) ; end test
(test '= string-compare "" ""
) ; end test
(test '= symbol-compare 'foo 'foo
) ; end test
(test '< symbol-compare 'bar 'foo
) ; end test
(test '> bytes-compare #"ab" #"aa"
) ; end test
(test '= bytes-compare #"" #""
) ; end test

;; 派生糖
(test #t (compare->lt string-compare) "a" "b"
) ; end test
(test #f (compare->lt string-compare) "b" "b"
) ; end test
(test #t (compare->eq fx-compare) 4 4
) ; end test
(test '= (lt->compare <) 5 5
) ; end test
(test '> (lt->compare <) 6 5
) ; end test

;; 组合子
(test '> (compare-reverse fx-compare) 1 2
) ; end test
(test '< (compare-on car fx-compare) '(1 . x) '(2 . y)
) ; end test
(test '> (compare-lexico (compare-on car fx-compare)
                         (compare-on cdr fx-compare)
         ) ; end compare-lexico
      '(1 . 9) '(1 . 3)
) ; end test
(test '= (compare-lexico
          ) ; end compare-lexico
      'anything 'else
) ; end test

(report-errs
) ; end report-errs
