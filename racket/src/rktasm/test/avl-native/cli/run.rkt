#!/usr/bin/env racket
#lang racket

;; ============================================================
;; test/avl-native/cli/run.rkt — AVL Forest 原生测试+基准 一键运行
;; ============================================================
;;
;; 用法:
;;   racket test/avl-native/cli/run.rkt                # 全部 (test + bench)
;;   racket test/avl-native/cli/run.rkt --test         # 仅正确性测试
;;   racket test/avl-native/cli/run.rkt --bench        # 仅性能基准
;;   racket test/avl-native/cli/run.rkt --help
;;
;; 流程:
;;   1. assemble  — 合并 .d 源, racket as.rkt → GNU .s
;;   2. fixup     — sed 修正 .D 元素宽度 (W→X)
;;   3. compile   — gcc 编译 test/bench + 链接 avl.o
;;   4. run       — 执行二进制, 输出报告
;;
;; 输出:
;;   bench-<host>-<date>.datum   — Racket datum 格式 (机器可读)
;;   bench-<host>-<date>.txt    — 文本报告 (人类可读)

(require racket/cmdline
         racket/system
         racket/string
         racket/file
         racket/path
         racket/format)

;; ---------- paths ----------

(define this-file (path->string (simplify-path (find-system-path 'run-file))))
(define cli-dir   (path->string (simplify-path (build-path this-file 'up))))
(define native-dir (path->string (simplify-path (build-path cli-dir 'up))))
(define root-dir  (path->string (simplify-path (build-path native-dir 'up 'up))))

;; ---------- helpers ----------

(define (banner msg)
  (printf "\n~a\n" (make-string 60 #\=))
  (printf "  ~a\n" msg)
  (printf "~a\n\n" (make-string 60 #\=)))

(define (step msg)
  (printf ">>> ~a\n" msg)
  (flush-output))

(define (run/check cmd #:dir [dir native-dir])
  (define ok (parameterize ([current-directory dir])
               (system cmd)))
  (unless ok
    (eprintf "\n!! FAILED: ~a\n" cmd)
    (exit 1)))

;; ---------- sed fixup patterns ----------
;; GNU as 要求 .D element size 使用 X 寄存器, 我们的汇编器总是发射 W

(define (fixup-sve-line line)
  (define l1
    (regexp-replace #rx"^;" line "//"))
  (define l2
    (regexp-replace* #rx"dup z([0-9]+)\\.D, w([0-9]+)" l1
                     "dup z\\1.D, x\\2"))
  (define l3
    (regexp-replace* #rx"whilelt p([0-9]+)\\.D, w([0-9]+), w([0-9]+)" l2
                     "whilelt p\\1.D, x\\2, x\\3"))
  (define l4
    (regexp-replace* #rx"lastb w([0-9]+), p([0-9]+), z([0-9]+)\\.D" l3
                     "lastb x\\1, p\\2, z\\3.D"))
  l4)

;; ---------- pipeline stages ----------

(define (stage-assemble!)
  (step "Assembling (racket → GNU asm)...")
  ;; 合并 scalar + SVE + batch 源文件
  (define avl-d    (build-path root-dir "lib" "avl-forest" "avl-forest.d"))
  (define sve-d    (build-path root-dir "lib" "avl-forest" "avl-forest-sve.d"))
  (define batch-d  (build-path root-dir "lib" "avl-batch" "avl-batch.d"))
  (define combined (build-path native-dir "avl-combined.d"))

  (call-with-output-file combined #:exists 'replace
    (lambda (out)
      (call-with-input-file avl-d   (lambda (in) (copy-port in out)))
      (call-with-input-file sve-d   (lambda (in) (copy-port in out)))
      (call-with-input-file batch-d (lambda (in) (copy-port in out)))))

  ;; 调用汇编器
  (define as-cmd
    (format "racket ~a --gnu -o ~a ~a"
            (build-path root-dir "cli" "as.rkt")
            (build-path native-dir "avl-gnu.s")
            combined))
  (run/check as-cmd #:dir root-dir)

  ;; SVE fixup: W → X for .D element size
  (step "Fixing .D register width (W → X)...")
  (define gnu-s  (build-path native-dir "avl-gnu.s"))
  (define fixed-s (build-path native-dir "avl.s"))
  (define lines (file->lines gnu-s))
  (define fixed (map fixup-sve-line lines))
  (call-with-output-file fixed-s #:exists 'replace
    (lambda (out)
      (for ([l (in-list fixed)])
        (displayln l out))
      ;; 确保文件以换行结尾
      (void)))

  (printf "    ~a lines assembled, ~a lines after fixup\n"
          (length lines) (length fixed)))

(define (stage-compile! do-test? do-bench?)
  (step "Compiling (gcc -march=armv8-a+sve)...")
  (run/check "gcc -march=armv8-a+sve -c avl.s -o avl.o")
  (when do-test?
    (run/check "gcc -O2 -Wall -march=armv8-a+sve -DTEST_SVE -c test_correctness.c -o test_correctness.o")
    (run/check "gcc test_correctness.o avl.o -o test_correctness.exe"))
  (when do-bench?
    (run/check "gcc -O2 -Wall -march=armv8-a+sve -c bench_avl.c -o bench_avl.o")
    (run/check "gcc bench_avl.o avl.o -o bench_avl.exe"))
  (printf "    OK\n"))

(define (stage-test!)
  (banner "Correctness Tests")
  (run/check "./test_correctness.exe"))

(define (stage-bench!)
  (banner "Performance Benchmark")
  (run/check "./bench_avl.exe"))

;; ---------- entry point ----------

(module+ main
  (define do-test?  #f)
  (define do-bench? #f)

  (command-line
   #:program "run.rkt"
   #:once-each
   [("--test" "-t")   "Run correctness tests only"
                       (set! do-test? #t)]
   [("--bench" "-b")  "Run performance benchmark only"
                       (set! do-bench? #t)]
   #:args ()

   ;; 默认: 全部
   (when (and (not do-test?) (not do-bench?))
     (set! do-test? #t)
     (set! do-bench? #t))

   (banner "AVL Forest — Native Test Suite")
   (printf "  root    : ~a\n" root-dir)
   (printf "  workdir : ~a\n" native-dir)
   (newline)

   (stage-assemble!)
   (stage-compile! do-test? do-bench?)

   (when do-test?  (stage-test!))
   (when do-bench? (stage-bench!))

   (banner "Done")
   (when do-bench?
     ;; 列出生成的报告文件
     (define report-files
       (for/list ([f (in-list (directory-list native-dir))]
                  #:when (regexp-match? #rx"^bench-.*\\.(datum|txt)$"
                                        (path->string f)))
         (path->string f)))
     (unless (null? report-files)
       (printf "  Report files:\n")
       (for ([f (in-list (sort report-files string<?))])
         (printf "    ~a\n" f))
       (newline)))))
