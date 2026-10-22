#lang racket/base
;; The TLS 1.3 client must require a CertificateVerify from a server
;; that authenticates with a certificate. The server's Finished only
;; proves knowledge of the (EC)DHE secret, so a server that sends a
;; Certificate and Finished but no CertificateVerify must be rejected,
;; even though the certificate itself is trusted and matches the host.
;;
;; The server below never loads a private key; `mode` selects whether
;; it omits CertificateVerify ("omit") or sends one with an invalid
;; signature ("bogus").
(require openssl rackunit
         openssl/private/rktcrypto-tls13
         openssl/private/rktcrypto-ffi
         openssl/private/rktcrypto-x509
         racket/tcp racket/port)

(define mode (make-parameter "omit"))
(define pem-path (collection-file-path "test.pem" "openssl"))
(define cert-der (car (pem->der-list (call-with-input-file pem-path port->bytes))))   ; public cert only

(define (empty-hash alg) (digest alg #""))

(define (evil-server in out)
  (define alg SHA256) (define aead AEAD-AES128-GCM)
  (define r (make-rl in out))
  (define hs (make-hsr r))
  (define-values (cht ch) (hsr-next hs))
  ;; parse ClientHello
  (define sid-len (bytes-ref ch 38))
  (define sid (subbytes ch 39 (+ 39 sid-len)))
  (define pos (+ 39 sid-len))
  (define cs-len (be->int ch pos (+ pos 2)))
  (define p2 (+ pos 2 cs-len))
  (define comp-len (bytes-ref ch p2))
  (define p3 (+ p2 1 comp-len))
  (define ext-len (be->int ch p3 (+ p3 2)))
  (define exts (parse-extensions (subbytes ch (+ p3 2) (+ p3 2 ext-len))))
  (define shares (parse-key-share-list (cdr (assoc #x0033 exts))))
  (define peer-pub (cdr (assoc #x001d shares)))
  ;; our x25519 share
  (define priv (random-bytes 32))
  (define pub (make-bytes 32))
  (rktcrypto_x25519 pub priv (bytes-append (bytes 9) (make-bytes 31 0)))
  (define ecdhe (make-bytes 32))
  (rktcrypto_x25519 ecdhe priv peer-pub)
  (define tr (make-transcript alg))
  (tr-add! tr ch)
  (define sh-body (bytes-append (u16 #x0303) (random-bytes 32) (vec 1 sid) (u16 #x1301) (u8 0)
                                (vec 2 (bytes-append (ext #x002b (u16 #x0304))
                                                     (ext #x0033 (bytes-append (u16 #x001d) (vec 2 pub)))))))
  (define sh (bytes-append (u8 2) (u24 (bytes-length sh-body)) sh-body))
  (tr-add! tr sh) (rl-write-record r 22 sh)
  ;; key schedule (RFC 8446 7.1), no PSK
  (define early (tls13-extract alg #f #f))
  (define hsec (tls13-extract alg (derive-secret alg early #"derived" (empty-hash alg)) ecdhe))
  (define th1 (tr-hash tr))
  (define c-hs (derive-secret alg hsec #"c hs traffic" th1))
  (define s-hs (derive-secret alg hsec #"s hs traffic" th1))
  (define-values (sk siv) (traffic-keys alg s-hs 16 12))
  (define-values (ck civ) (traffic-keys alg c-hs 16 12))
  (rl-set-write-key! r aead sk siv)
  (define (send-hs! type body)
    (define m (bytes-append (u8 type) (u24 (bytes-length body)) body))
    (tr-add! tr m) (rl-write-record r 22 m))
  (send-hs! 8 (vec 2 #""))                                            ; EncryptedExtensions
  (send-hs! 11 (bytes-append (vec 1 #"") (vec 3 (bytes-append (vec 3 cert-der) (vec 2 #""))))) ; Certificate
  (when (equal? (mode) "bogus")
    (send-hs! 15 (bytes-append (u16 #x0804) (vec 2 (make-bytes 256 7)))))  ; CertificateVerify w/ garbage sig
  ;; (mode "omit": no CertificateVerify at all)
  (send-hs! 20 (finished-verify-data alg s-hs (tr-hash tr)))          ; server Finished
  (define th-sfin (tr-hash tr))
  (define master (tls13-extract alg (derive-secret alg hsec #"derived" (empty-hash alg)) #f))
  (define c-ap (derive-secret alg master #"c ap traffic" th-sfin))
  (define s-ap (derive-secret alg master #"s ap traffic" th-sfin))
  (rl-set-read-key! r aead ck civ)
  (define-values (cft cfin) (hsr-next hs))
  (define-values (sak saiv) (traffic-keys alg s-ap 16 12))
  (define-values (cak caiv) (traffic-keys alg c-ap 16 12))
  (rl-set-write-key! r aead sak saiv)
  (rl-set-read-key! r aead cak caiv)
  (rl-write-record r 23 #"HELLO-FROM-IMPOSTOR (no private key used)\n")
  (rl-write-record r 21 (bytes 1 0)))

(define (handshake server-mode)
  (define l (tcp-listen 0 5 #t "127.0.0.1"))
  (define-values (_a port _b _c) (tcp-addresses l #t))
  (parameterize ([mode server-mode])
    (void (thread (lambda ()
                    (define-values (i o) (tcp-accept l))
                    (with-handlers ([exn:fail? void])
                      (evil-server i o))))))
  ;; client: verification and hostname check on, trusts test.pem's cert
  (define ctx (ssl-make-client-context 'auto))
  (ssl-load-verify-root-certificates! ctx pem-path)
  (ssl-set-verify! ctx #t)
  (ssl-set-verify-hostname! ctx #t)
  (define-values (ti to) (tcp-connect "127.0.0.1" port))
  (dynamic-wind
   void
   (lambda ()
     (define-values (i o) (ports->ssl-ports ti to #:mode 'connect #:context ctx #:hostname "lambda"
                                            #:close-original? #t))
     (read-line i))
   (lambda () (tcp-close l))))

(module+ test
  (check-exn #rx"unexpected handshake msg"
             (lambda () (handshake "omit")))
  (check-exn #rx"CertificateVerify signature invalid"
             (lambda () (handshake "bogus"))))
