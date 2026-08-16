#lang racket

(require rackunit
         rackunit/text-ui
         "../encode/loader.rkt"
         "../encode/encode.rkt"
         (only-in racket/pvector
                  pvector?
                  pvector-length))

;; ============================================================
;; 路径配置
;; ============================================================

(define here (path-only (syntax-source #'here)))
(define root (simplify-path (build-path here "..")))
(define config-dir (build-path root "encode" "config-generated"))

(define (rktd? p)
  (regexp-match? #rx"\\.rktd$" (path->string p)))

(define (config-paths)
  (for/list ([p (in-list (directory-list config-dir))]
             #:when (rktd? p))
    (build-path config-dir p)))

;; ============================================================
;; 测试套件
;; ============================================================

(define encode-loader-tests
  (test-suite
   "Encode Loader 测试"

   (test-case "加载所有配置文件"
     (define seen (make-hash))
     (for ([p (in-list (config-paths))])
       (define encs (file->encodes p seen))
       ;; 允许空文件（如 sve.rktd 占位符）
       (check-true (pvector? encs))))))

;; ============================================================
;; 执行
;; ============================================================

(module+ main
  (void (run-tests encode-loader-tests)))

(module+ test
  (void (run-tests encode-loader-tests)))
