#lang racket/base

;; Signature verification for TLS: the CertificateVerify handshake message,
;; the X.509 certificate-chain path validation, and RFC 6125 hostname
;; matching. All the arithmetic (RSA, ECDSA, Ed25519) runs in the rktcrypto
;; C library; this module dispatches on the TLS SignatureScheme / X.509
;; signature OID and enforces the policy checks around it.

(require "rktcrypto-ffi.rkt"
         "rktcrypto-x509.rkt"
         racket/string)

(provide verify-certificate-verify
         verify-signature-over
         verify-chain-and-host
         verify-chain
         check-hostname
         (struct-out exn:tls:verify))

(struct exn:tls:verify exn:fail () #:transparent)
(define (verify-error fmt . args)
  (raise (exn:tls:verify (apply format fmt args) (current-continuation-marks))))

(define (be->int bs [s 0] [e (bytes-length bs)])
  (let loop ([i s] [a 0]) (if (= i e) a (loop (add1 i) (+ (* a 256) (bytes-ref bs i))))))

;; ---- SignatureScheme -> verify a signature over `content` with `pub` ----
;; pub is a `pubkey` struct from rktcrypto-x509.
(define (verify-signature-over scheme pub content sig)
  (case scheme
    ;; RSASSA-PKCS1-v1_5
    [(#x0401) (rsa-verify pub 0 SHA256 content sig)]
    [(#x0501) (rsa-verify pub 0 SHA384 content sig)]
    [(#x0601) (rsa-verify pub 0 SHA512 content sig)]
    ;; RSASSA-PSS
    [(#x0804) (rsa-verify pub 1 SHA256 content sig)]
    [(#x0805) (rsa-verify pub 1 SHA384 content sig)]
    [(#x0806) (rsa-verify pub 1 SHA512 content sig)]
    ;; ECDSA (message hashed internally by the C verifier)
    [(#x0403) (ec-verify pub 'p256 content sig SHA256)]
    [(#x0503) (ec-verify pub 'p384 content sig SHA384)]
    [(#x0603) (ec-verify pub 'p521 content sig SHA512)]
    ;; EdDSA
    [(#x0807) (ed25519-verify* pub content sig)]
    [else (verify-error "unsupported signature scheme 0x~x" scheme)]))

(define (rsa-verify pub pss alg content sig)
  (unless (eq? (pubkey-type pub) 'rsa) (verify-error "RSA scheme with non-RSA key"))
  (define n (pubkey-rsa-n pub))
  (define e (pubkey-rsa-e pub))
  (eqv? 1 (rktcrypto_rsa_verify_msg pss alg n (bytes-length n) e (bytes-length e)
                                    content (bytes-length content) sig (bytes-length sig))))

;; ECDSA signature in TLS/X.509 is DER SEQUENCE{ r, s }; convert to raw r||s.
(define (ecdsa-der->raw sig fb)
  (define (rd pos)
    (unless (= #x02 (bytes-ref sig pos)) (verify-error "bad ECDSA sig"))
    (define len (bytes-ref sig (add1 pos)))
    (define start (+ pos 2))
    (values (subbytes sig start (+ start len)) (+ start len)))
  (unless (= #x30 (bytes-ref sig 0)) (verify-error "bad ECDSA sig (seq)"))
  (define-values (r p1) (rd 2))
  (define-values (s p2) (rd p1))
  (define (fix v) (let ([v (if (and (> (bytes-length v) 1) (zero? (bytes-ref v 0))) (subbytes v 1) v)])
                    (if (< (bytes-length v) fb) (bytes-append (make-bytes (- fb (bytes-length v)) 0) v) v)))
  (bytes-append (fix r) (fix s)))

(define (ec-verify pub curve content sig alg)
  (unless (eq? (pubkey-type pub) 'ec) (verify-error "ECDSA scheme with non-EC key"))
  (define point (pubkey-ec-point pub))
  (define fb (case curve [(p256) 32] [(p384) 48] [(p521) 66]))
  (define raw (ecdsa-der->raw sig fb))
  ;; use the digest that matches the scheme, independent of key curve
  (case curve
    [(p256) (eqv? 1 (rktcrypto_p256_ecdsa_verify raw content (bytes-length content) point))]
    [(p384) (eqv? 1 (rktcrypto_p384_ecdsa_verify raw content (bytes-length content) point))]
    [(p521) (eqv? 1 (rktcrypto_p521_ecdsa_verify raw content (bytes-length content) point))]))

(define (ed25519-verify* pub content sig)
  (unless (eq? (pubkey-type pub) 'ed25519) (verify-error "Ed25519 scheme with non-Ed key"))
  (eqv? 1 (rktcrypto_ed25519_verify (pubkey-ec-point pub) content (bytes-length content) sig)))

;; ---- CertificateVerify ----
;; msg is the full handshake message; certs the peer chain (leaf first);
;; transcript-hash the Transcript-Hash over messages up to Certificate.
(define (verify-certificate-verify msg certs transcript-hash [side 'server])
  (when (null? certs) (verify-error "no certificate for CertificateVerify"))
  (define scheme (be->int msg 4 6))
  (define sig-len (be->int msg 6 8))
  (define sig (subbytes msg 8 (+ 8 sig-len)))
  (define context
    (bytes-append (make-bytes 64 #x20)
                  (if (eq? side 'server)
                      #"TLS 1.3, server CertificateVerify"
                      #"TLS 1.3, client CertificateVerify")
                  (bytes 0)
                  transcript-hash))
  (define pub (certificate-pub (parse-certificate (car certs))))
  (unless (verify-signature-over scheme pub context sig)
    (verify-error "CertificateVerify signature invalid"))
  #t)

;; ---- X.509 chain path validation ----
;; Verifies one issued-by link: `cert` signed by `issuer-pub`.
(define (verify-cert-signature cert issuer-pub)
  (define-values (tbs sig-alg sig-digest sig) (cert-signature-inputs cert))
  (case sig-alg
    [(rsa-pkcs1)
     (rsa-verify issuer-pub 0 (digest->alg sig-digest) tbs sig)]
    [(rsa-pss)
     (rsa-verify issuer-pub 1 (digest->alg sig-digest) tbs sig)]
    [(ecdsa)
     (ec-verify-cert issuer-pub tbs sig sig-digest)]
    [(ed25519)
     (ed25519-verify* issuer-pub tbs sig)]
    [else (verify-error "unsupported certificate signature algorithm ~a" sig-alg)]))

(define (digest->alg d) (case d [(sha256) SHA256] [(sha384) SHA384] [(sha512) SHA512] [else SHA256]))

;; ECDSA over a certificate: digest may differ from the key's curve, so use
;; the precomputed-digest verify entry points.
(define (ec-verify-cert pub tbs sig sig-digest)
  (unless (eq? (pubkey-type pub) 'ec) (verify-error "ECDSA cert with non-EC issuer key"))
  (define curve (pubkey-ec-curve pub))
  (define point (pubkey-ec-point pub))
  (define fb (case curve [(p256) 32] [(p384) 48] [(p521) 66] [else (verify-error "bad curve")]))
  (define raw (ecdsa-der->raw sig fb))
  (define halg (digest->alg sig-digest))
  (define h (digest halg tbs))
  (case curve
    [(p256) (eqv? 1 (rktcrypto_p256_ecdsa_verify_h raw h (bytes-length h) point))]
    [(p384) (eqv? 1 (rktcrypto_p384_ecdsa_verify_h raw h (bytes-length h) point))]
    [(p521) (eqv? 1 (rktcrypto_p521_ecdsa_verify_h raw h (bytes-length h) point))]))

;; ---- validity time ----
(define (time->int t)
  ;; UTCTime YYMMDDHHMMSSZ or GeneralizedTime YYYYMMDDHHMMSSZ -> integer
  (define digits (regexp-replace* #rx"[^0-9]" t ""))
  (cond
    [(>= (string-length digits) 14) (string->number (substring digits 0 14))]
    [(>= (string-length digits) 12)
     (define yy (string->number (substring digits 0 2)))
     (string->number (string-append (if (< yy 50) "20" "19") (substring digits 0 12)))]
    [else 0]))

(define (now->int)
  (define d (seconds->date (current-seconds) #f))   ; UTC
  (+ (* (date-year d) 10000000000)
     (* (date-month d) 100000000)
     (* (date-day d) 1000000)
     (* (date-hour d) 10000)
     (* (date-minute d) 100)
     (date-second d)))
(require racket/date)

(define (check-validity cert)
  (define nb (time->int (certificate-not-before cert)))
  (define na (time->int (certificate-not-after cert)))
  (define now (now->int))
  (when (< now nb) (verify-error "certificate not yet valid"))
  (when (> now na) (verify-error "certificate expired")))

;; Builds and validates a path from the leaf to a trust anchor.
;; peer-ders: list of DER byte strings (leaf first).
;; anchors: list of DER byte strings (trusted roots).
(define (verify-chain peer-ders anchors)
  (when (null? peer-ders) (verify-error "empty certificate chain"))
  (define chain (map parse-certificate peer-ders))
  (define anchor-certs (map parse-certificate anchors))
  ;; index anchors by subject DN string
  (define (dn c) (name->string (certificate-subject c)))
  (define anchor-by-subject (make-hash))
  (for ([a (in-list anchor-certs)]) (hash-set! anchor-by-subject (dn a) a))
  ;; walk the presented chain, each signed by the next
  (let loop ([certs chain])
    (define c (car certs))
    (check-validity c)
    (define issuer-dn (name->string (certificate-issuer c)))
    (cond
      [(pair? (cdr certs))
       (define issuer (cadr certs))
       (unless (string=? (name->string (certificate-subject issuer)) issuer-dn)
         (verify-error "chain issuer/subject mismatch"))
       (unless (certificate-is-ca issuer) (verify-error "intermediate is not a CA"))
       (unless (verify-cert-signature c (certificate-pub issuer))
         (verify-error "certificate signature invalid in chain"))
       (loop (cdr certs))]
      [else
       ;; top of presented chain: must be signed by a trust anchor
       (define anchor (hash-ref anchor-by-subject issuer-dn #f))
       (unless anchor (verify-error "no trusted anchor for issuer ~a" issuer-dn))
       (check-validity anchor)
       (unless (verify-cert-signature c (certificate-pub anchor))
         (verify-error "top certificate not signed by trusted anchor"))]))
  #t)

;; RFC 6125 hostname check against the leaf's SAN dNSNames (falling back to
;; CN only when no SAN is present).
(define (check-hostname cert host)
  (define names
    (let ([san (certificate-san-dns cert)])
      (if (pair? san) san
          (let ([cn (assoc "2.5.4.3" (certificate-subject cert))])
            (if cn (list (bytes->string/latin-1 (cdr cn))) '())))))
  (define h (string-downcase host))
  (unless (for/or ([n (in-list names)]) (host-matches? (string-downcase n) h))
    (verify-error "hostname ~a does not match certificate (~a)" host names)))

(define (host-matches? pattern host)
  (cond
    [(string=? pattern host) #t]
    [(and (> (string-length pattern) 2)
          (char=? (string-ref pattern 0) #\*)
          (char=? (string-ref pattern 1) #\.))
     ;; wildcard: match exactly one leftmost label
     (define suffix (substring pattern 1))       ; ".example.com"
     (define dot (let loop ([i 0]) (cond [(>= i (string-length host)) #f]
                                         [(char=? (string-ref host i) #\.) i]
                                         [else (loop (add1 i))])))
     (and dot (string=? (substring host dot) suffix)
          (positive? dot))]
    [else #f]))

;; Convenience wrapper used by the client handshake.
(define (verify-chain-and-host peer-ders host anchors)
  (verify-chain peer-ders anchors)
  (when host (check-hostname (parse-certificate (car peer-ders)) host)))
