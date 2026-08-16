#lang racket/base

;; OCSP response verification (RFC 6960) for stapled responses — no network.
;; verify-ocsp-staple checks that a BasicOCSPResponse: (1) is signed by a trusted
;; responder (the certificate's issuer directly, or a delegated responder cert
;; that the issuer signed and that carries the id-kp-OCSPSigning EKU); (2) covers
;; the leaf via a matching CertID (issuerNameHash, issuerKeyHash, serialNumber);
;; (3) is fresh (thisUpdate <= now <= nextUpdate); and returns the certStatus.
;; The signature arithmetic runs in librktcrypto via rktcrypto-verify.

(require "rktcrypto-der.rkt"
         "rktcrypto-x509.rkt"
         "rktcrypto-ffi.rkt"
         "rktcrypto-verify.rkt"
         racket/date)

(provide verify-ocsp-staple)   ; ocsp-der leaf-der issuer-der now -> 'good/'revoked/'unknown ; raises on failure

(struct exn:ocsp exn:fail () #:transparent)
(define (ocsp-error fmt . args) (raise (exn:ocsp (apply format fmt args) (current-continuation-marks))))

(define SHA1-ID 14)

;; --- OIDs (content bytes, i.e. der-content of the OID TLV) ---
(define oid-ocsp-basic   #"\x2b\x06\x01\x05\x05\x07\x30\x01\x01") ; 1.3.6.1.5.5.7.48.1.1
(define oid-ocsp-signing #"\x2b\x06\x01\x05\x05\x07\x03\x09")     ; 1.3.6.1.5.5.7.3.9
(define oid-sha1         #"\x2b\x0e\x03\x02\x1a")                 ; 1.3.14.3.2.26
(define oid-sha256       #"\x60\x86\x48\x01\x65\x03\x04\x02\x01") ; 2.16.840.1.101.3.4.2.1
(define oid-sha384       #"\x60\x86\x48\x01\x65\x03\x04\x02\x02")
(define oid-sha512       #"\x60\x86\x48\x01\x65\x03\x04\x02\x03")

;; signatureAlgorithm OID -> TLS SignatureScheme code understood by
;; verify-signature-over (RSA-PKCS1 / ECDSA over SHA-256/384/512).
(define (algid->scheme algid)
  (define oid (car (der-children algid)))
  (cond
    [(der-oid=? oid #"\x2a\x86\x48\x86\xf7\x0d\x01\x01\x0b") #x0401] ; sha256WithRSA
    [(der-oid=? oid #"\x2a\x86\x48\x86\xf7\x0d\x01\x01\x0c") #x0501] ; sha384WithRSA
    [(der-oid=? oid #"\x2a\x86\x48\x86\xf7\x0d\x01\x01\x0d") #x0601] ; sha512WithRSA
    [(der-oid=? oid #"\x2a\x86\x48\xce\x3d\x04\x03\x02")     #x0403] ; ecdsa-with-SHA256
    [(der-oid=? oid #"\x2a\x86\x48\xce\x3d\x04\x03\x03")     #x0503] ; ecdsa-with-SHA384
    [(der-oid=? oid #"\x2a\x86\x48\xce\x3d\x04\x03\x04")     #x0603] ; ecdsa-with-SHA512
    [else (ocsp-error "unsupported OCSP signature algorithm")]))

(define (hashalgid->id algid)
  (define oid (car (der-children algid)))
  (cond [(der-oid=? oid oid-sha1)   SHA1-ID]
        [(der-oid=? oid oid-sha256) SHA256]
        [(der-oid=? oid oid-sha384) SHA384]
        [(der-oid=? oid oid-sha512) SHA512]
        [else (ocsp-error "unsupported OCSP CertID hash")]))

;; Reconstruct a value's full TLV bytes from its content bounds (DER minimal len).
(define (raw-tlv d)
  (define vlen (- (der-end d) (der-start d)))
  (define hlen (cond [(< vlen 128) 2] [(< vlen 256) 3] [(< vlen 65536) 4]
                     [(< vlen 16777216) 5] [else 6]))
  (subbytes (der-bytes d) (- (der-start d) hlen) (der-end d)))

;; BIT STRING content minus the leading unused-bits octet (signatures, keys).
(define (bitstring-bytes d) (subbytes (der-content d) 1))

;; --- certificate field access via raw DER (avoids widening the cert struct) ---
(define (tbs-fields cert-der)
  (define tbs (car (der-children (der-read cert-der))))
  (define ch (der-children tbs))
  (if (and (pair? ch) (= #xA0 (der-tag (car ch)))) (cdr ch) ch)) ; drop [0] version
(define (leaf-serial-int cert-der) (der-uint (list-ref (tbs-fields cert-der) 0)))
(define (leaf-issuer-tlv cert-der) (raw-tlv (list-ref (tbs-fields cert-der) 2)))
(define (issuer-spki-key cert-der)
  (define spki (list-ref (tbs-fields cert-der) 5))
  (bitstring-bytes (cadr (der-children spki))))

;; RFC 5280 GeneralizedTime "YYYYMMDDHHMMSSZ" -> UTC seconds.
(define (gentime->seconds d)
  (define s (der-content d))
  (define (n a b) (string->number (bytes->string/latin-1 (subbytes s a b))))
  (find-seconds (n 12 14) (n 10 12) (n 8 10) (n 6 8) (n 4 6) (n 0 4) #f))

;; --- OCSP response ---
(define (parse-basic-response ocsp-der)
  ;; OCSPResponse ::= SEQ { responseStatus ENUMERATED, responseBytes [0] EXPLICIT ResponseBytes OPTIONAL }
  (define top (der-children (der-read ocsp-der)))
  (define status (der-uint (car top)))
  (unless (= status 0) (ocsp-error "OCSP responseStatus ~a (not successful)" status))
  (when (null? (cdr top)) (ocsp-error "OCSP response has no responseBytes"))
  (define rb (der-explicit (cadr top)))                 ; ResponseBytes SEQ
  (define rbc (der-children rb))
  (unless (der-oid=? (car rbc) oid-ocsp-basic) (ocsp-error "OCSP responseType not id-pkix-ocsp-basic"))
  (der-read (der-content (cadr rbc))))                  ; response OCTET STRING -> BasicOCSPResponse

;; -> (values tbs-data-der tbs-tlv scheme signature certs-der-or-#f)
(define (parse-basic basic)
  (define ch (der-children basic))
  (define tbs (car ch))                                 ; tbsResponseData (ResponseData)
  (define scheme (algid->scheme (cadr ch)))
  (define sig (bitstring-bytes (caddr ch)))
  (define certs
    (and (>= (length ch) 4)
         (let ([c (list-ref ch 3)])
           (and (der-tag-context? c) (= 0 (der-tag-number c))
                (der-children (der-explicit c))))))
  (values tbs (raw-tlv tbs) scheme sig certs))

(define (ocsp-signing-eku? cert-der)
  (define c (parse-certificate cert-der))
  (define eku (certificate-eku c))
  (and eku (member "1.3.6.1.5.5.7.3.9" eku) #t))

;; Verify BasicOCSPResponse signature by a trusted responder (issuer direct, or a
;; delegated responder cert the issuer signed with the OCSPSigning EKU).
(define (verify-responder tbs-tlv scheme sig certs issuer-der)
  (define issuer-pub (certificate-pub (parse-certificate issuer-der)))
  (cond
    [(verify-signature-over scheme issuer-pub tbs-tlv sig) #t]  ; issuer signed directly
    [(and certs (pair? certs))
     (define rc-der (raw-tlv (car certs)))                      ; responder cert
     (define rc (parse-certificate rc-der))
     ;; responder cert must be issued by the issuer and be an OCSP signer
     (define-values (rtbs rsalg rdig rsig) (cert-signature-inputs rc))
     (define rc-scheme (sigalg->scheme rsalg rdig))
     (unless (verify-signature-over rc-scheme issuer-pub rtbs rsig)
       (ocsp-error "OCSP responder cert not issued by the certificate issuer"))
     (unless (ocsp-signing-eku? rc-der)
       (ocsp-error "OCSP responder cert lacks id-kp-OCSPSigning EKU"))
     (unless (verify-signature-over scheme (certificate-pub rc) tbs-tlv sig)
       (ocsp-error "OCSP response signature invalid (delegated responder)"))
     #t]
    [else (ocsp-error "OCSP response signature not from a trusted responder")]))

;; cert-signature-inputs gives (tbs, sig-alg symbol, sig-digest symbol, sig);
;; map to the SignatureScheme code verify-signature-over expects.
(define (sigalg->scheme sig-alg sig-digest)
  (case sig-alg
    [(rsa-pkcs1) (case sig-digest [(sha256) #x0401] [(sha384) #x0501] [(sha512) #x0601] [else #x0401])]
    [(rsa-pss)   (case sig-digest [(sha256) #x0804] [(sha384) #x0805] [(sha512) #x0806] [else #x0804])]
    [(ecdsa)     (case sig-digest [(sha256) #x0403] [(sha384) #x0503] [(sha512) #x0603] [else #x0403])]
    [(ed25519)   #x0807]
    [else (ocsp-error "unsupported responder cert signature algorithm")]))

;; Find the SingleResponse whose CertID matches the leaf, return its status +
;; freshness fields. responses live in ResponseData.
(define (match-single tbs leaf-der issuer-der)
  (define fields (der-children tbs))
  ;; ResponseData ::= { version[0]?, responderID, producedAt, responses SEQ OF, ... }
  ;; responses is the first SEQUENCE (tag 0x30) after producedAt; scan for it.
  (define responses-seq
    (let loop ([fs fields])
      (cond [(null? fs) (ocsp-error "OCSP ResponseData has no responses")]
            [(and (= #x30 (der-tag (car fs)))
                  ;; the responses SEQ OF; its first child is a SingleResponse SEQ
                  (let ([kids (der-children (car fs))])
                    (and (pair? kids) (= #x30 (der-tag (car kids)))
                         (let ([g (der-children (car kids))])
                           (and (pair? g) (= #x30 (der-tag (car g))))))))  ; CertID SEQ
             (car fs)]
            [else (loop (cdr fs))])))
  (define want-serial (leaf-serial-int leaf-der))
  (define want-iname  (leaf-issuer-tlv leaf-der))
  (define want-ikey   (issuer-spki-key issuer-der))
  (let loop ([srs (der-children responses-seq)])
    (when (null? srs) (ocsp-error "no OCSP SingleResponse matches this certificate"))
    (define sr (der-children (car srs)))
    (define certid (der-children (car sr)))       ; { hashAlg, issuerNameHash, issuerKeyHash, serial }
    (define halg (hashalgid->id (car certid)))
    (define inh (der-content (list-ref certid 1)))
    (define ikh (der-content (list-ref certid 2)))
    (define serial (der-uint (list-ref certid 3)))
    (if (and (= serial want-serial)
             (equal? inh (digest halg want-iname))
             (equal? ikh (digest halg want-ikey)))
        (values (cadr sr) (caddr sr) (and (>= (length sr) 4) (list-ref sr 3)))
        (loop (cdr srs)))))

;; certStatus CHOICE: good [0] IMPLICIT NULL / revoked [1] / unknown [2].
(define (cert-status->symbol cs)
  (case (der-tag-number cs) [(0) 'good] [(1) 'revoked] [(2) 'unknown]
        [else (ocsp-error "malformed OCSP certStatus")]))

(define (verify-ocsp-staple ocsp-der leaf-der issuer-der now)
  (define basic (parse-basic-response ocsp-der))
  (define-values (tbs tbs-tlv scheme sig certs) (parse-basic basic))
  (verify-responder tbs-tlv scheme sig certs issuer-der)
  (define-values (cs this-upd next-upd) (match-single tbs leaf-der issuer-der))
  ;; freshness (thisUpdate GeneralizedTime, nextUpdate [0] EXPLICIT GeneralizedTime OPTIONAL)
  (define t0 (gentime->seconds this-upd))
  (when (> t0 (+ now 300)) (ocsp-error "OCSP thisUpdate is in the future"))
  (when next-upd
    (define t1 (gentime->seconds (der-explicit next-upd)))
    (when (< t1 (- now 300)) (ocsp-error "OCSP response is stale (past nextUpdate)")))
  (cert-status->symbol cs))
