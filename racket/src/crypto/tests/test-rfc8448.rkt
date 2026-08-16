#lang racket
;; D2: RFC 8448 "TLS 1.3 Traces" — byte-exact validation of our TLS 1.3 key
;; schedule against the canonical reference (Section 3, Simple 1-RTT Handshake,
;; TLS_AES_128_GCM_SHA256). Every derived secret and traffic key must match the
;; RFC's published octets exactly, exercising tls13-extract / derive-secret /
;; traffic-keys with the RFC's inputs (ECDHE secret + transcript hashes).
(require (only-in "../../../collects/openssl/private/rktcrypto-ffi.rkt"
                  tls13-extract derive-secret traffic-keys digest SHA256))

(define (hx s) (list->bytes (for/list ([i (in-range 0 (string-length s) 2)])
                              (string->number (substring s i (+ i 2)) 16))))
(define fails 0)
(define (chk name got want)
  (define ok (equal? got (hx want)))
  (printf "  ~a ~a\n" (if ok "ok:" "FAIL:") name)
  (unless ok (set! fails (add1 fails))
    (printf "      got  ~a\n      want ~a\n" (bytes->hex got) want)))
(define (bytes->hex b) (apply string-append (for/list ([x (in-bytes b)])
                          (~a (number->string x 16) #:min-width 2 #:pad-string "0" #:align 'right))))

;; ---- RFC 8448 Section 3 published values ----
(define zeros32 (make-bytes 32 0))
(define ecdhe   (hx "8bd4054fb55b9d63fdfbacf9f04b9f0d35e6d63f537563efd46272900f89492d"))
(define th-hs   (hx "860c06edc07858ee8e78f0e7428c58edd6b43f2ca3e6e95f02ed063cf0e1cad8")) ; CH..SH
(define th-ap   (hx "9608102a0f1ccc6db6250b7b7e417b1a000eaada3daae4777a7686c9ff83df13")) ; ..server Finished
(define empty-h (digest SHA256 #""))

(printf "RFC 8448 §3 TLS 1.3 key schedule (byte-exact):\n")

;; early secret = HKDF-Extract(0, 0)
(define early (tls13-extract SHA256 #f #f))
(chk "early secret" early "33ad0a1c607ec03b09e6cd9893680ce210adf300aa1f2660e1b22e10f170f92a")

;; derived-for-handshake = Derive-Secret(early, "derived", "")
(define derived (derive-secret SHA256 early #"derived" empty-h))
(chk "derived (handshake)" derived "6f2615a108c702c5678f54fc9dbab69716c076189c48250cebeac3576c3611ba")

;; handshake secret = HKDF-Extract(derived, ECDHE)
(define hs (tls13-extract SHA256 derived ecdhe))
(chk "handshake secret" hs "1dc826e93606aa6fdc0aadc12f741b01046aa6b99f691ed221a9f0ca043fbeac")

;; client/server handshake traffic secrets = Derive-Secret(hs, label, Hash(CH..SH))
(define c-hs (derive-secret SHA256 hs #"c hs traffic" th-hs))
(chk "client hs traffic secret" c-hs "b3eddb126e067f35a780b3abf45e2d8f3b1a950738f52e9600746a0e27a55a21")
(define s-hs (derive-secret SHA256 hs #"s hs traffic" th-hs))
(chk "server hs traffic secret" s-hs "b67b7d690cc16c4e75e54213cb2d37b4e9c912bcded9105d42befd59d391ad38")

;; derived-for-master = Derive-Secret(hs, "derived", "")
(define derived2 (derive-secret SHA256 hs #"derived" empty-h))
(chk "derived (master)" derived2 "43de77e0c77713859a944db9db2590b53190a65b3ee2e4f12dd7a0bb7ce254b4")

;; master secret = HKDF-Extract(derived2, 0)
(define master (tls13-extract SHA256 derived2 #f))
(chk "master secret" master "18df06843d13a08bf2a449844c5f8a478001bc4d4c627984d5a41da8d0402919")

;; client/server application traffic secrets = Derive-Secret(master, label, Hash(..SF))
(define c-ap (derive-secret SHA256 master #"c ap traffic" th-ap))
(chk "client ap traffic secret" c-ap "9e40646ce79a7f9dc05af8889bce6552875afa0b06df0087f792ebb7c17504a5")
(define s-ap (derive-secret SHA256 master #"s ap traffic" th-ap))
(chk "server ap traffic secret" s-ap "a11af9f05531f856ad47116b45a950328204b4f44bfb6b3a4b4f1f3fcb631643")

;; server handshake write key + iv from the server hs traffic secret
(define-values (skey siv) (traffic-keys SHA256 s-hs 16 12))
(chk "server hs write key" skey "3fce516009c21727d0f2e4e86ee403bc")
(chk "server hs write iv"  siv  "5d313eb2671276ee13000b30")

(printf (if (zero? fails) "rfc8448: 0 failure(s)\n" (format "rfc8448: ~a FAILURE(S)\n" fails)))
(exit (if (zero? fails) 0 1))
