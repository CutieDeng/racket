#lang racket/base
(require rackunit
         racket/port
         racket/runtime-path
         openssl/private/rktcrypto-verify
         openssl/private/rktcrypto-x509)

;; Certification-path policy (RFC 5280 section 6, as libssl's verifier
;; applies it for TLS peers): path length constraints, keyUsage of
;; issuers and end entities, extendedKeyUsage per purpose, name
;; constraints, unknown critical extensions; plus path building from an
;; unordered chain with an extra certificate, and IP-address SANs. The
;; certificates come from generate-policy-certs.sh.

(define-runtime-path policy-dir "policy")
(define (der name)
  (car (pem->der-list (call-with-input-file (build-path policy-dir name) port->bytes))))
(define root (der "root.crt"))

(define (verifies? chain #:purpose [purpose 'server] #:anchors [anchors (list root)])
  (with-handlers ([exn:fail? (lambda (e) (exn-message e))])
    (verify-chain chain anchors #:purpose purpose)
    #t))

(module+ test
  ;; a well-formed chain
  (check-true (verifies? (list (der "leaf-ip.crt") (der "inter-plain.crt"))))
  ;; the same chain presented out of order and with an unrelated extra certificate
  (check-true (verifies? (list (der "leaf-ip.crt") (der "inter-noku.crt") (der "inter-plain.crt"))))
  ;; the root included in the chain
  (check-true (verifies? (list (der "leaf-ip.crt") (der "inter-plain.crt") root)))
  ;; path length constraint violated (pathlen:0 CA with a CA below it)
  (check-regexp-match #rx"path length"
                      (verifies? (list (der "leaf-p0.crt") (der "inter-p0-sub.crt") (der "inter-p0.crt"))))
  ;; issuer whose keyUsage lacks keyCertSign
  (check-regexp-match #rx"keyUsage"
                      (verifies? (list (der "leaf-noku.crt") (der "inter-noku.crt"))))
  ;; extendedKeyUsage: clientAuth-only certificate as a server, fine as a client
  (check-regexp-match #rx"extendedKeyUsage" (verifies? (list (der "leaf-clientauth.crt")) #:purpose 'server))
  (check-true (verifies? (list (der "leaf-clientauth.crt")) #:purpose 'client))
  ;; name constraints
  (check-true (verifies? (list (der "leaf-nc-ok.crt") (der "inter-nc.crt"))))
  (check-regexp-match #rx"permitted names"
                      (verifies? (list (der "leaf-nc-bad.crt") (der "inter-nc.crt"))))
  ;; unknown critical extension
  (check-regexp-match #rx"critical extension" (verifies? (list (der "leaf-critical.crt"))))
  ;; untrusted: no anchor
  (check-regexp-match #rx"no trusted anchor" (verifies? (list (der "leaf-ip.crt")) #:anchors '()))
  ;; IP-address SANs
  (define leaf-ip (parse-certificate (der "leaf-ip.crt")))
  (check-not-exn (lambda () (check-hostname leaf-ip "127.0.0.1")))
  (check-not-exn (lambda () (check-hostname leaf-ip "::1")))
  (check-not-exn (lambda () (check-hostname leaf-ip "leaf-ip.example.test")))
  (check-exn exn:fail? (lambda () (check-hostname leaf-ip "127.0.0.2")))
  (check-exn exn:fail? (lambda () (check-hostname leaf-ip "other.example.test"))))
