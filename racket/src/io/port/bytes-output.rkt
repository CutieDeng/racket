#lang racket/base
(require racket/fixnum
         "../common/check.rkt"
         "../common/class.rkt"
         "../host/thread.rkt"
         "port.rkt"
         "count.rkt"
         "output-port.rkt"
         "fd-port.rkt"
         "lock.rkt"
         "parameter.rkt"
         "write.rkt"
         "check.rkt")

(provide write-byte
         write-bytes
         write-bytes*
         write-bytes-avail
         write-bytes-avail*
         write-bytes-avail/enable-break
         write-bytes-avail-evt
         port-writes-atomic?

         unsafe-write-bytes)

(module+ internal
  (provide do-write-byte
           do-write-bytes))

(define/who (write-byte b [out (current-output-port)])
  (check who byte? b)
  (do-write-byte b (->core-output-port out who)))

;; `out` must be a core output port
(define (do-write-byte b out)
  (port-lock out)
  (define buffer (core-port-buffer out))
  (define pos (direct-pos buffer))
  (cond
    [(pos . fx< . (direct-end buffer))
     (bytes-set! (direct-bstr buffer) pos b)
     (set-direct-pos! buffer (fx+ pos 1))
     (when (core-port-count out)
       (port-count-byte! out b))
     (port-unlock out)]
    [else
     (port-unlock out)
     (write-some-bytes 'write-byte out (bytes b) 0 1 #:buffer-ok? #t #:copy-bstr? #f)])
  (void))

(define (do-write-bytes who out bstr start end)
  (let loop ([i start])
    (cond
      [(fx= i end) (fx- i start)]
      [else
       (define n (write-some-bytes who out bstr i end #:buffer-ok? #t))
       (loop (fx+ n i))])))

(define/who write-bytes
  (case-lambda
    [(bstr)
     (check who bytes? bstr)
     (let ([out (->core-output-port (current-output-port))])
       (do-write-bytes who out bstr 0 (bytes-length bstr)))]
    [(bstr out)
     (check who bytes? bstr)
     (let ([out (->core-output-port out who)])
       (do-write-bytes who out bstr 0 (bytes-length bstr)))]
    [(bstr out start-pos)
     (write-bytes bstr out start-pos (and (bytes? bstr) (bytes-length bstr)))]
    [(bstr out start-pos end-pos)
     (check who bytes? bstr)
     (let ([out (->core-output-port out who)])
       (check who exact-nonnegative-integer? start-pos)
       (check who exact-nonnegative-integer? end-pos)
       (check-range who start-pos end-pos (bytes-length bstr) bstr)
       (do-write-bytes who out bstr start-pos end-pos))]))

;; Adaptively write a list of byte strings, picking the fastest strategy for
;; the slice profile (blocking; returns the total bytes written = sum of the
;; slice lengths). Rationale from measurement (see
;; racket/src/rktio/RKTIO-WRITEV-DESIGN.md):
;;   - concat cost ~ O(total bytes): one allocation + copy of a big buffer
;;     (superlinear for very large buffers due to GC/large-object allocation).
;;   - zero-copy vectored (rktio_writev) cost ~ O(#slices) for pinning + one
;;     syscall: wins only when few slices carry a large payload, where it
;;     dodges the big allocation (measured 275x-1330x over concat for
;;     8x256KB / 4x2MB), but loses badly for many small slices (per-slice
;;     `lock-object` pinning dominates).
;; So: few large slices -> vectored; small total -> concat; otherwise
;; write each slice directly (no big allocation, no per-slice pinning). The
;; dispatch reads only `#slices` and `total`, both O(#slices) and already
;; needed for the result. For any non-fd port, just write sequentially.
(define writev-max-slices 16)              ; above this, pinning overhead dominates
(define writev-min-total (* 64 1024))      ; below this, concat's allocation is cheap
;; In the non-vectored case concat almost always wins: its single allocation
;; beats N per-slice dispatches for many slices, and is cheap for a small
;; total. Only a *huge* total makes the single big allocation worse than
;; writing each slice directly, so keep this cap high (16MB) as a safety
;; valve rather than a routine threshold (measured: concat still beats
;; N-write at 300KB by ~3.5x).
(define concat-max-total (* 16 1024 1024))

(define/who (write-bytes* bstrs [out (current-output-port)])
  (check who (lambda (v) (and (list? v) (andmap bytes? v))) #:contract "(listof bytes?)" bstrs)
  (define o (->core-output-port out who))
  (define total (for/sum ([b (in-list bstrs)]) (bytes-length b)))
  (cond
    [(not (fd-output-port? o))
     (for ([b (in-list bstrs)]) (do-write-bytes who o b 0 (bytes-length b)))]
    [(and (fx<= (length bstrs) writev-max-slices)
          (>= total writev-min-total))
     ;; few large slices: zero-copy scatter/gather, dodging a big allocation
     (fd-output-port-write-bytes-list! o bstrs)]
    [(<= total concat-max-total)
     ;; small/medium total: one allocation + one write beats N dispatches
     (do-write-bytes who o (apply bytes-append bstrs) 0 total)]
    [else
     ;; many slices with a large total: avoid both a huge allocation and
     ;; per-slice pinning by writing each slice directly into the port buffer
     (for ([b (in-list bstrs)]) (do-write-bytes who o b 0 (bytes-length b)))])
  total)

;; `o` must be a core output port
(define (unsafe-write-bytes who bstr o)
  (do-write-bytes who o bstr 0 (bytes-length bstr)))

(define (do-write-bytes-avail who bstr out start-pos end-pos
                              #:zero-ok? [zero-ok? #f]
                              #:enable-break? [enable-break? #f])
  (check who bytes? bstr)
  (check who output-port? out)
  (check who exact-nonnegative-integer? start-pos)
  (check who exact-nonnegative-integer? end-pos)
  (check-range who start-pos end-pos (bytes-length bstr) bstr)
  (let ([out (->core-output-port out)])
    (write-some-bytes who out bstr start-pos end-pos #:zero-ok? zero-ok? #:enable-break? enable-break?)))

(define/who (write-bytes-avail bstr [out (current-output-port)] [start-pos 0] [end-pos (and (bytes? bstr)
                                                                                            (bytes-length bstr))])
  (do-write-bytes-avail who bstr out start-pos end-pos))

(define/who (write-bytes-avail* bstr [out (current-output-port)] [start-pos 0] [end-pos (and (bytes? bstr)
                                                                                             (bytes-length bstr))])
  (do-write-bytes-avail who bstr out start-pos end-pos #:zero-ok? #t))

(define/who (write-bytes-avail/enable-break bstr [out (current-output-port)] [start-pos 0] [end-pos (and (bytes? bstr)
                                                                                                         (bytes-length bstr))])
  (do-write-bytes-avail who bstr out start-pos end-pos #:enable-break? #t))

(define/who (write-bytes-avail-evt bstr [out (current-output-port)] [start-pos 0] [end-pos (and (bytes? bstr)
                                                                                                (bytes-length bstr))])
  (check who bytes? bstr)
  (check who output-port? out)
  (check who exact-nonnegative-integer? start-pos)
  (check who exact-nonnegative-integer? end-pos)
  (check-range who start-pos end-pos (bytes-length bstr) bstr)
  (let ([out (->core-output-port out)])
    (with-lock out
     (check-not-closed who out)
     (define get-write-evt (method core-output-port out get-write-evt))
     (unless get-write-evt
       (port-unlock out)
       (raise-arguments-error who
                              "port does not support output events"
                              "port" out))
     (get-write-evt out bstr start-pos end-pos))))

(define/who (port-writes-atomic? out)
  (check who output-port? out)
  (let ([out (->core-output-port out)])
    (and (with-lock out
           (method core-output-port out get-write-evt))
         #t)))
