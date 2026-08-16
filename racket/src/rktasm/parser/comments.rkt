#lang racket/base

(require racket/string)

;; ============================================================
;; parser/comments.rkt - 源注释侧表
;; ============================================================
;;
;; 记录源文件中每行的尾注释 ((source . line) -> text)，供 emit 阶段
;; 把注释重新附着到该行产生的指令上（--keep-comments）。
;;
;; 侧表以 srcloc 的 (source, line) 为键，因此注释天然跟随指令穿过
;; 调度重排、寄存器分配改写与 inline 展开（这些 pass 均保留 loc）：
;;   - 调度器重排后注释仍贴在原指令上；
;;   - inline 模板多次展开时注释随之复制（符合期望）；
;;   - spill/reload 合成指令沿用原指令 loc，会重复该行注释（已知
;;     的轻微冗余，crypto 内核以 .save all 避免溢出，实际罕见）。
;;
;; 参数为 #f（默认）时前端不记录、emit 不查询，行为与旧版逐字节一致。

(provide current-source-comments
         record-source-comment!
         source-comment-ref)

(define current-source-comments (make-parameter #f))

(define (record-source-comment! source line text)
  (define tbl (current-source-comments))
  (when (and tbl line text)
    (let ([t (string-trim text)])
      (unless (string=? t "")
        (hash-set! tbl (cons source line) t)))))

(define (source-comment-ref source line)
  (define tbl (current-source-comments))
  (and tbl line (hash-ref tbl (cons source line) #f)))
