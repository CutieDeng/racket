#lang racket

(require json
         racket/cmdline
         racket/match)

(provide main)

;; ============================================================
;; JSON Reader
;; ============================================================

(define (read-instructions-json path)
  (call-with-input-file path read-json))

(define (extract-a64-instruction-set json-data)
  (match (hash-ref json-data 'instructions #f)
    [(list a64 _ ...) a64]
    [#f (error 'extract-a64-instruction-set "missing 'instructions' key")]
    ['() (error 'extract-a64-instruction-set "empty instructions array")]))

;; ============================================================
;; Walker
;; ============================================================

(struct instruction-info (name path encoding condition) #:transparent)

(define (walk-instruction-set iset)
  (walk-node iset '()))

(define (walk-node node path)
  (match (hash-ref node '_type #f)
    ["Instruction.InstructionSet"
     (walk-children node path)]
    ["Instruction.InstructionGroup"
     (define name (hash-ref node 'name
                            (lambda () (error 'walk-node "InstructionGroup missing 'name'"))))
     (walk-children node (append path (list name)))]
    ["Instruction.Instruction"
     (collect-instruction node path)]
    [other
     (error 'walk-node "unknown node type: ~a" other)]))

(define (walk-children node path)
  (match (hash-ref node 'children #f)
    [(? list? children)
     (append-map (lambda (child) (walk-node child path)) children)]
    [#f (error 'walk-children "node missing 'children' key: ~a" node)]
    [other (error 'walk-children "invalid children value: ~a" other)]))

(define (collect-instruction node path)
  (match* ((hash-ref node 'name #f)
           (hash-ref node 'encoding #f))
    [(#f _)
     (error 'collect-instruction "instruction missing 'name'")]
    [(_ #f)
     (error 'collect-instruction "instruction ~a missing 'encoding'"
            (hash-ref node 'name))]
    [(name encoding)
     (list (instruction-info name path encoding (hash-ref node 'condition #f)))]))

;; ============================================================
;; Converter
;; ============================================================

(struct encoding-field (name len) #:transparent)

(define (convert-encoding encoding)
  (match* ((hash-ref encoding 'width #f)
           (hash-ref encoding 'values #f))
    [(#f _) (error 'convert-encoding "encoding missing 'width'")]
    [(_ #f) (error 'convert-encoding "encoding missing 'values'")]
    [(width values)
     (define sorted-values (sort-by-bit-position values))
     (define raw-fields (map convert-value sorted-values))
     (define merged-fields (merge-unnamed-fields raw-fields))
     (define total-bits (for/sum ([f (in-list merged-fields)]) (encoding-field-len f)))
     (unless (= total-bits width)
       (error 'convert-encoding "total bits ~a != expected width ~a" total-bits width))
     merged-fields]))

(define (sort-by-bit-position values)
  (sort values > #:key get-bit-end))

(define (get-bit-end v)
  (match (hash-ref v 'range #f)
    [(hash-table ('start start) ('width width) _ ...)
     (+ start width)]
    [#f (error 'get-bit-end "value missing 'range': ~a" v)]
    [other (error 'get-bit-end "invalid range: ~a" other)]))

(define (convert-value v)
  (match* ((hash-ref v '_type #f)
           (hash-ref v 'range #f))
    [(#f _)
     (error 'convert-value "value missing '_type': ~a" v)]
    [(_ #f)
     (error 'convert-value "value missing 'range': ~a" v)]
    [("Instruction.Encodeset.Field" range)
     (match (hash-ref v 'name #f)
       [#f (error 'convert-value "Field missing 'name': ~a" v)]
       [name (encoding-field name (hash-ref range 'width))])]
    [("Instruction.Encodeset.Bits" range)
     (encoding-field #f (hash-ref range 'width))]
    [(other _)
     (error 'convert-value "unknown value type: ~a" other)]))

(define (merge-unnamed-fields fields)
  (let loop ([fields fields] [acc '()] [unnamed-len 0])
    (match fields
      ['()
       (reverse (if (> unnamed-len 0)
                    (cons (encoding-field #f unnamed-len) acc)
                    acc))]
      [(cons (encoding-field #f len) rest)
       (loop rest acc (+ unnamed-len len))]
      [(cons (encoding-field name len) rest)
       (define acc* (if (> unnamed-len 0)
                        (cons (encoding-field #f unnamed-len) acc)
                        acc))
       (loop rest (cons (encoding-field name len) acc*) 0)])))

;; ============================================================
;; Classifier
;; ============================================================

(define (classify-instruction path condition)
  (define condition-str (format "~a" (or condition "")))
  (define (path-has? s) (ormap (lambda (p) (string-contains? p s)) path))

  (match #t
    [(? (lambda (_) (or (path-has? "sve") (string-contains? condition-str "FEAT_SVE"))))
     'sve]
    [(? (lambda (_) (or (path-has? "sme") (string-contains? condition-str "FEAT_SME"))))
     'sme]
    [(? (lambda (_) (path-has? "reserved")))
     'reserved]
    [(? (lambda (_) (path-has? "dpimm")))
     'data-processing-immediate]
    [(? (lambda (_) (path-has? "dpreg")))
     'data-processing-register]
    [(? (lambda (_) (path-has? "ldst")))
     'loads-stores]
    [(? (lambda (_) (path-has? "control")))
     'branches-exception-generating-system-instructions]
    [(? (lambda (_) (or (path-has? "simd") (path-has? "float")
                        (path-has? "crypto") (path-has? "simd_dp"))))
     'data-processing-floating-point]
    [_
     (error 'classify-instruction "cannot classify path: ~a" path)]))

(define (get-output-filename category)
  (match category
    ['sve "sve.rktd"]
    ['sme "sme.rktd"]
    ['reserved "reserved.rktd"]
    ['data-processing-immediate "data-processing-immediate.rktd"]
    ['data-processing-register "data-processing-register.rktd"]
    ['loads-stores "loads-stores.rktd"]
    ['branches-exception-generating-system-instructions
     "branches-exception-generating-system-instructions.rktd"]
    ['data-processing-floating-point "data-processing-floating-point.rktd"]
    [other (error 'get-output-filename "unknown category: ~a" other)]))

;; ============================================================
;; Writer
;; ============================================================

(define (write-encode out name tags fields)
  (fprintf out "(~s ~s\n  ~s)\n" name tags (fields->sexpr fields)))

(define (fields->sexpr fields)
  (for/list ([f (in-list fields)])
    (match f
      [(encoding-field #f len) (list '_ len)]
      [(encoding-field name len) (list (string->symbol name) len)])))

;; ============================================================
;; Main
;; ============================================================

(define (path->tags path)
  (define seen (make-hash))
  (for/list ([p (in-list path)]
             #:when (not (string=? p ""))
             #:unless (hash-ref seen p #f)
             #:do [(hash-set! seen p #t)])
    (string-replace p "_" " ")))

(define (main)
  (define input-path (make-parameter #f))
  (define output-dir (make-parameter "encode/config-generated"))

  (command-line
   #:program "gen-config"
   #:once-each
   [("-i" "--input") path "Path to Instructions.json" (input-path path)]
   [("-o" "--output") dir "Output directory for .rktd files" (output-dir dir)]
   #:args ()
   (unless (input-path)
     (error 'main "missing required -i/--input"))
   (run-conversion (input-path) (output-dir))))

(define (run-conversion input-path output-dir)
  (printf "Reading ~a...\n" input-path)
  (define json-data (read-instructions-json input-path))

  (printf "Extracting A64 instruction set...\n")
  (define a64 (extract-a64-instruction-set json-data))

  (printf "Walking instruction tree...\n")
  (define instructions (walk-instruction-set a64))
  (printf "Found ~a instructions\n" (length instructions))

  (define categories (make-hash))
  (for ([instr (in-list instructions)])
    (match-define (instruction-info _ path _ condition) instr)
    (define category (classify-instruction path condition))
    (hash-update! categories category (lambda (lst) (cons instr lst)) '()))

  (unless (directory-exists? output-dir)
    (make-directory* output-dir))

  (for ([(category instrs) (in-hash categories)])
    (define filepath (build-path output-dir (get-output-filename category)))
    (printf "Writing ~a (~a instructions)...\n" filepath (length instrs))

    (call-with-output-file filepath
      #:exists 'replace
      (lambda (out)
        (for ([instr (in-list (reverse instrs))])
          (match-define (instruction-info name path encoding _) instr)
          (define fields (convert-encoding encoding))
          (write-encode out name (path->tags path) fields)))))

  (printf "Done!\n"))

(module+ main
  (main))
