#lang racket

(require "loader.rkt"
         "syntax-variant.rkt"
         "../../syntax/operand-type.rkt")

(provide build-signature-db-from-json
         save-signature-db
         generate-template-signatures)

;; ============================================================
;; Signature Extractor Tool
;; ============================================================
;;
;; 从 Instructions.json 提取模板类型签名数据
;; 生成 template-signature.rktd 文件

;; 从 JSON 构建签名数据库
;; 返回: hash[template -> signature]
(define (build-signature-db-from-json json-path)
  (define json-data (read-instructions-json json-path))
  (define rules (get-assembly-rules json-data))
  (define a64 (get-a64-instruction-set json-data))

  ;; 首先获取所有变体
  (define variant-db (build-syntax-variant-db rules a64))

  ;; 从变体提取模板并计算签名
  (generate-template-signatures variant-db))

;; 从变体数据库生成模板签名映射
(define (generate-template-signatures variant-db)
  (define signature-db (make-hash))

  (for* ([variants (in-hash-values variant-db)]
         [v (in-list variants)])
    (define template (extract-syntax-variant-template v))
    (unless (hash-has-key? signature-db template)
      (define signature (parse-template-signature template))
      (hash-set! signature-db template signature)))

  signature-db)

;; 保存签名数据库到文件
(define (save-signature-db signature-db output-path)
  (call-with-output-file output-path
    (lambda (out)
      (fprintf out ";; 模板 -> 类型签名\n")
      (fprintf out ";; (template (type1 type2 ...))\n\n")
      ;; 按模板排序以保持一致性
      (define sorted-templates
        (sort (hash-keys signature-db) string<?))
      (for ([template (in-list sorted-templates)])
        (define sig (hash-ref signature-db template))
        (fprintf out "~s\n" (list template sig))))
    #:exists 'replace)

  (printf "已保存签名数据库: ~a (~a 条记录)\n"
          output-path (hash-count signature-db)))

;; ============================================================
;; 主程序
;; ============================================================

(module+ main
  (require racket/cmdline)

  (define json-path
    (make-parameter "AARCHMRS_OPENSOURCE_A_profile_FAT-2025-12/Instructions.json"))
  (define output-dir
    (make-parameter "syntax/data"))

  (command-line
   #:program "signature-extractor"
   #:once-each
   [("-j" "--json") path
    "Path to Instructions.json"
    (json-path path)]
   [("-o" "--output") dir
    "Output directory for signature database"
    (output-dir dir)]
   #:args ()

   (printf "Loading JSON from ~a...\n" (json-path))
   (define signature-db (build-signature-db-from-json (json-path)))

   (define output-path (build-path (output-dir) "template-signature.rktd"))
   (save-signature-db signature-db output-path)

   (printf "\n示例签名:\n")
   (define examples
     (take (hash->list signature-db)
           (min 10 (hash-count signature-db))))
   (for ([example (in-list examples)])
     (match-define (cons template sig) example)
     (printf "  ~s\n    -> ~s\n" template sig))))
