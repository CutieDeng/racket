#lang racket

;; ============================================================
;; semantic/function-identity.rkt - logical function/version identity
;; ============================================================
;;
;; asm-function-name is the concrete linkage symbol emitted for one function
;; body. function-version records the stable logical function identity that
;; survives compiler-created clones.

(provide
 (struct-out function-version)
 make-canonical-function-version
 make-clone-function-version
 default-clone-linkage-symbol
 function-version-clone?
 function-version-display-name)

(struct function-version
  (logical-name        ; symbol - user/source-level function identity
   version-id          ; symbol - canonical, cc1, hot0, ...
   version-kind        ; symbol - canonical | clone | callconv | specialized | ...
   origin-version-id   ; symbol | #f - source version this one derives from
   clone-reason        ; symbol | #f - managed-callconv, hot-caller, ...
   specialization-key  ; any/c - caller/cost/profile key for this version
   debug-origin        ; srcloc | #f - source/debug attribution anchor
   linkage-symbol      ; symbol - concrete emitted/private symbol
   canonical?)         ; boolean
  #:transparent)

(define (default-clone-linkage-symbol logical-name version-id)
  (string->symbol
   (format "~a$asmp.~a"
           logical-name
           version-id)))

(define (make-canonical-function-version logical-name
                                         #:debug-origin [debug-origin #f]
                                         #:linkage-symbol [linkage-symbol logical-name])
  (function-version logical-name
                    'canonical
                    'canonical
                    #f
                    #f
                    #f
                    debug-origin
                    linkage-symbol
                    #t))

(define (make-clone-function-version base-version
                                     #:version-id version-id
                                     #:version-kind [version-kind 'clone]
                                     #:clone-reason [clone-reason 'unspecified]
                                     #:specialization-key [specialization-key #f]
                                     #:debug-origin [debug-origin
                                                     (function-version-debug-origin base-version)]
                                     #:linkage-symbol [linkage-symbol
                                                       (default-clone-linkage-symbol
                                                        (function-version-logical-name base-version)
                                                        version-id)])
  (function-version (function-version-logical-name base-version)
                    version-id
                    version-kind
                    (function-version-version-id base-version)
                    clone-reason
                    specialization-key
                    debug-origin
                    linkage-symbol
                    #f))

(define (function-version-clone? v)
  (and (function-version? v)
       (not (function-version-canonical? v))))

(define (function-version-display-name v)
  (define logical (symbol->string (function-version-logical-name v)))
  (if (function-version-canonical? v)
      logical
      (format "~a [clone ~a, reason=~a]"
              logical
              (function-version-version-id v)
              (or (function-version-clone-reason v) 'unspecified))))

