#lang racket
;; Public openssl/x509 read API: parse the mtls/ocsp vectors and check the
;; exposed fields + PEM/DER round-trip.
(require racket/runtime-path openssl/x509
         (only-in (file "../../../collects/openssl/private/rktcrypto-verify.rkt") verify-chain)
         (only-in (file "../../../collects/openssl/private/rktcrypto-ffi.rkt") rktcrypto_p256_ecdsa_verify)
         (only-in (file "../../../collects/openssl/private/rktcrypto-der.rkt")
                  der-read der-children der-content der-start der-end der-bytes)
         (only-in (file "../../../collects/openssl/private/rktcrypto-x509.rkt") pem->private-key))
(define-runtime-path mtls "mtls-vectors")
(define-runtime-path ocsp "ocsp-vectors")

(define failures 0)
(define (check! name ok?) (printf "  ~a: ~a\n" (if ok? "ok" "FAIL") name) (unless ok? (set! failures (add1 failures))))

(printf "openssl/x509 read API:\n")
(define leaf (read-certificate (build-path mtls "server.pem")))
(define ca (read-certificate (build-path mtls "ca.pem")))

(check! "subject CN" (equal? "leaf.example" (certificate-subject-common-name leaf)))
(check! "issuer CN"  (equal? "mTLS CA" (certificate-issuer-common-name leaf)))
(check! "SAN dNSName" (equal? '("leaf.example") (certificate-dns-names leaf)))
(check! "leaf not a CA" (not (certificate-ca? leaf)))
(check! "CA is a CA" (certificate-ca? ca))
(check! "public key type EC" (eq? 'ec (certificate-public-key-type leaf)))
(check! "serial is positive" (positive? (certificate-serial-number leaf)))
(check! "validity ordered + spans now"
        (let ([f (certificate-valid-from leaf)] [t (certificate-valid-to leaf)] [now (current-seconds)])
          (and (< f t) (<= f now) (<= now t))))
(check! "subject assoc has friendly label"
        (equal? "leaf.example" (cond [(assoc "CN" (certificate-subject leaf)) => cdr] [else #f])))
(check! "PEM->DER->PEM->DER round-trips"
        (let* ([der (certificate-der leaf)] [pem (der->pem der)])
          (equal? der (pem->der pem))))
;; parse a DER-form cert too (ocsp leaf.der)
(check! "reads DER directly"
        (let ([c (read-certificate (build-path ocsp "leaf.der"))])
          (and (certificate? c) (string? (certificate-not-before c)))))

;; --- B3 certificate construction: build a self-signed cert, read it back, verify ---
(define-values (cder cpriv) (create-self-signed-certificate #:common-name "built.example"
                                                            #:dns-names '("built.example") #:ca? #t))
(define built (read-certificate cder))
(check! "built cert: subject CN" (equal? "built.example" (certificate-subject-common-name built)))
(check! "built cert: SAN dNSName" (equal? '("built.example") (certificate-dns-names built)))
(check! "built cert: is a CA" (certificate-ca? built))
(check! "built cert: EC public key" (eq? 'ec (certificate-public-key-type built)))
(check! "built cert: private scalar 32 bytes" (= 32 (bytes-length cpriv)))
(check! "built cert: validity spans now"
        (let ([f (certificate-valid-from built)] [t (certificate-valid-to built)] [now (current-seconds)])
          (and (<= f now) (<= now t))))
(check! "built cert: self-signature verifies"
        (with-handlers ([exn:fail? (lambda (_) #f)]) (verify-chain (list cder) (list cder)) #t))
(check! "built cert: PEM round-trip" (equal? cder (pem->der (der->pem cder))))

;; --- B3 CSR (PKCS#10): build a CSR and verify its self-signature ---
(let ()
  (define-values (csr cpriv2) (create-certificate-request #:common-name "req.example"))
  (define (raw-tlv d)
    (define vlen (- (der-end d) (der-start d)))
    (define h (cond [(< vlen 128) 2] [(< vlen 256) 3] [(< vlen 65536) 4] [else 5]))
    (subbytes (der-bytes d) (- (der-start d) h) (der-end d)))
  (define (der-sig->raw s)
    (define ints (der-children (der-read s)))
    (define (fix v) (let ([v (if (and (> (bytes-length v) 32) (zero? (bytes-ref v 0))) (subbytes v 1) v)])
                      (bytes-append (make-bytes (- 32 (bytes-length v)) 0) v)))
    (bytes-append (fix (der-content (car ints))) (fix (der-content (cadr ints)))))
  (define kids (der-children (der-read csr)))
  (define cri (car kids))
  (define cri-tlv (raw-tlv cri))
  (define spki (list-ref (der-children cri) 2))
  (define pubpt (subbytes (der-content (cadr (der-children spki))) 1))   ; 04||x||y
  (define sig-der (subbytes (der-content (caddr kids)) 1))               ; BIT STRING content
  (check! "CSR has 3 top-level elements" (= 3 (length kids)))
  (check! "CSR version v1" (= 0 (bytes-ref (der-content (car (der-children cri))) 0)))
  (check! "CSR self-signature verifies"
          (= 1 (rktcrypto_p256_ecdsa_verify (der-sig->raw sig-der) cri-tlv (bytes-length cri-tlv) pubpt))))

;; --- B3 CA-issued certificate: a CA issues a leaf, chain verifies to the CA ---
(let ()
  (define-values (ca-der ca-key) (create-self-signed-certificate #:common-name "Build CA" #:ca? #t))
  (define-values (leaf-der leaf-key)
    (create-certificate #:ca-cert-der ca-der #:ca-key ca-key
                        #:common-name "leaf.built" #:dns-names '("leaf.built")))
  (define leaf (read-certificate leaf-der))
  (check! "issued leaf: subject CN" (equal? "leaf.built" (certificate-subject-common-name leaf)))
  (check! "issued leaf: issuer CN is the CA" (equal? "Build CA" (certificate-issuer-common-name leaf)))
  (check! "issued leaf: chain verifies to CA"
          (with-handlers ([exn:fail? (lambda (_) #f)]) (verify-chain (list leaf-der) (list ca-der)) #t))
  (check! "issued leaf: wrong anchor rejected"
          (with-handlers ([exn:fail? (lambda (_) #t)]) (verify-chain (list leaf-der) (list leaf-der)) #f)))

;; --- B3 key export formats: SEC1 and PKCS#8 PEM both parse back to the scalar ---
(let ()
  (define-values (_cd k) (create-self-signed-certificate #:common-name "keyfmt"))
  (check! "SEC1 EC key PEM round-trips"
          (equal? (cons 'p256 k) (pem->private-key (ec-private-key->pem k))))
  (check! "PKCS#8 EC key PEM round-trips"
          (equal? (cons 'p256 k) (pem->private-key (ec-private-key->pkcs8-pem k)))))

(printf "openssl/x509: ~a failure(s)\n" failures)
(when (> failures 0) (error 'test-x509-api "~a check(s) failed" failures))
