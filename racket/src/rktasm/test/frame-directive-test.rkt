#lang racket

;; ============================================================
;; test/frame-directive-test.rkt — M3 `.frame` + 变长 `.alloca`
;; ============================================================
;;
;; 覆盖 asmp M3:
;;   .frame [N]     —— 在 .save 前导保存 x29/x30 之后发射 `add x29, sp, #0`,
;;                     建立 x29 为真帧指针, 并保留 N 字节 FP-relative 本地槽。
;;   .alloca xN[,k] —— 变长栈分配 `sub sp, sp, xN, lsl #k`; epilogue 前由
;;                     `mov sp, x29` 从帧指针复原 sp。
;;
;; 本文件为文本级测试: 汇编 .asm 源、校验发射的指令序列。运行期 ABI 正确性
;; (帧链有效、sp 复原、callee-saved 保全、返回值正确) 由容器冒烟测试
;;   test/m3/{main.c,frame_a.asm,alloca_a.asm,run.sh}
;; 在 aarch64-linux (gcc 13 / GNU ld 2.42) 头对头验证, 见该目录。

(require rackunit
         rackunit/text-ui
         racket/runtime-path
         racket/file)

(require (only-in "../cli/as.rkt" assemble))   ; in-process 汇编
(define-runtime-path rktasm-root "..")

;; 汇编一段 GNU 语法源, 返回发射的汇编文本。
;; as.rkt 从 cwd 解析 config/abi.rktd, 故在 rktasm 根目录调用。
(define (assemble-gnu src)
  (define dir (make-temporary-file "asmp-m3-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define in-path (build-path dir "in.asm"))
      (define out-path (build-path dir "out.S"))
      (call-with-output-file in-path #:exists 'truncate/replace
        (lambda (o) (display src o)))
      (define code
        (parameterize ([current-directory rktasm-root])
          (assemble (path->string in-path)
                    #:input-syntax 'gnu #:default-abi 'aapcs64
                    #:output (path->string out-path))))
      (unless (zero? code) (error 'assemble-gnu "汇编失败"))
      (file->string out-path))
    (lambda () (delete-directory/files dir))))

;; 断言 needle 作为子串出现在 hay
(define-check (check-contains hay needle)
  (unless (regexp-match? (regexp (regexp-quote needle)) hay)
    (fail-check (format "期望包含: ~s\n实际输出:\n~a" needle hay))))

(define frame-src
  (string-append
   ".function frame_local export ()\n"
   "entry:\n"
   "  .save all\n"
   "  .frame 16\n"
   "  str x0, [x29, #16]\n"
   "  mov x0, #0\n"
   "  ldr x1, [x29, #16]\n"
   "  add x0, x1, #100\n"
   "  .restore all\n"
   "  ret\n"))

(define alloca-src
  (string-append
   ".function alloca_scratch export ()\n"
   "entry:\n"
   "  .save all\n"
   "  .frame\n"
   "  .alloca x0, 4\n"
   "  mov x4, sp\n"
   "  str x0, [x4]\n"
   "  ldr x0, [x4]\n"
   "  .restore all\n"
   "  ret\n"))

;; .frame 但 shift 默认为 0
(define alloca-shift0-src
  (string-append
   ".function alloca_bytes export ()\n"
   "entry:\n"
   "  .save all\n"
   "  .frame\n"
   "  .alloca x0\n"
   "  mov x4, sp\n"
   "  str xzr, [x4]\n"
   "  mov x0, xzr\n"
   "  .restore all\n"
   "  ret\n"))

(define m3-tests
  (test-suite
   "M3 .frame / .alloca"

   (test-case ".frame establishes x29 as frame pointer + FP-relative local"
     (define asm (assemble-gnu frame-src))
     ;; 前导: 折叠栈分配的 pre-index stp (16 callee-saved + align16(16) 本地 = 32)
     (check-contains asm "stp x29, x30, [sp, #-32]!")
     ;; 帧指针建立
     (check-contains asm "add x29, sp, #0")
     ;; FP-relative 本地槽读写保持原样
     (check-contains asm "str x0, [x29, #16]")
     (check-contains asm "ldr x1, [x29, #16]")
     ;; epilogue: 后索引释放同额栈 (无 alloca, 故无 mov sp,x29)
     (check-contains asm "ldp x29, x30, [sp], #32")
     (check-false (regexp-match? #rx"mov sp, x29" asm)))

   (test-case ".alloca emits runtime-sized sub sp and fp-based sp restore"
     (define asm (assemble-gnu alloca-src))
     (check-contains asm "add x29, sp, #0")
     ;; 变长栈分配: sub sp, sp, xN, lsl #k
     (check-contains asm "sub sp, sp, x0, LSL #4")
     ;; epilogue 前从帧指针复原 sp
     (check-contains asm "mov sp, x29")
     ;; 复原后后索引释放固定 callee-saved 帧 (16)
     (check-contains asm "ldp x29, x30, [sp], #16"))

   (test-case ".alloca shift defaults to 0"
     (define asm (assemble-gnu alloca-shift0-src))
     (check-contains asm "sub sp, sp, x0, LSL #0")
     (check-contains asm "mov sp, x29"))))

(module+ main
  (void (run-tests m3-tests)))

(module+ test
  (require rackunit/text-ui)
  (void (run-tests m3-tests)))
