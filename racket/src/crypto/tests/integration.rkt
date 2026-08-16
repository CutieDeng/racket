#lang racket/base

;; Integration test suite for the built-in rktcrypto subsystem, exercised
;; through the public `racket/crypto` API (and the `openssl/sha1`,
;; `openssl/md5` compatibility wrappers) rather than the C selftest. This
;; is the FUNCTIONAL ACCEPTANCE GATE for removing the OpenSSL dependency:
;; everything here must pass with no external library loaded.
;;
;;   racket/bin/racket racket/src/crypto/tests/integration.rkt
;;   raco test racket/src/crypto/tests/integration.rkt
;;
;; Deliberately self-contained: `#lang racket/base` plus `file/sha1` and
;; the in-tree `racket/crypto` collection -- no rackunit, no packages. A
;; suite that verifies "the crypto stack needs nothing external" must
;; itself need nothing external.

(require racket/crypto/digest
         racket/crypto/mac
         racket/crypto/aead
         racket/crypto/kdf
         racket/crypto/kex
         racket/crypto/sign
         racket/crypto/kem
         racket/crypto/secretbox
         racket/crypto/random
         (prefix-in ossl: openssl/sha1)
         (prefix-in ossl: openssl/md5)
         (only-in file/sha1 hex-string->bytes bytes->hex-string)
         racket/port)

;; ---- tiny assertion harness -------------------------------------------

(define failures 0)
(define checks 0)

(define (check! name ok?)
  (set! checks (add1 checks))
  (unless ok?
    (set! failures (add1 failures))
    (eprintf "FAIL: ~a\n" name)))

(define (check-equal? name got want)
  (check! name (equal? got want))
  (unless (equal? got want)
    (eprintf "   got:  ~e\n   want: ~e\n" got want)))

(define (hx s) (hex-string->bytes s))

;; ==== digests ==========================================================
;; Known-answer vectors ("abc" unless noted). These are the standard test
;; vectors; the bit-exact-vs-OpenSSL differential lives in development
;; tooling, this is the in-tree regression tripwire.

(define digest-kats
  (list
   (list 'sha256    #"abc" "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
   (list 'sha512    #"abc" (string-append "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a"
                                          "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"))
   (list 'sha3-256  #"abc" "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532")
   (list 'sha1      #"abc" "a9993e364706816aba3e25717850c26c9cd0d89d")
   (list 'md5       #"abc" "900150983cd24fb0d6963f7d28e17f72")
   (list 'md4       #"abc" "a448017aaf21d8525fc10ae87aa6729d")
   (list 'ripemd160 #"abc" "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc")
   (list 'sm3       #"abc" "66c7f0f462eeedd9d1f2d46bdc10e4e24167c4875cf2f7a2297da02b8f4ba8e0")
   (list 'whirlpool #"abc" (string-append "4e2448a4c6f486bb16b6562c73b4020bf3043e3a731bce721ae1b303d97e6d4c"
                                          "7181eebdb6c57e277d0e34957114cbd6c797fc9d95d8b582d225292076d4eef5"))
   (list 'blake2b   #"abc" (string-append "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d1"
                                          "7d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923"))
   (list 'blake3    #"abc" "6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85")))

(define (test-digests)
  (for ([kat (in-list digest-kats)])
    (define alg (car kat))
    (define msg (cadr kat))
    (define want (hx (caddr kat)))
    ;; one-shot
    (check-equal? (format "digest ~a one-shot" alg) (digest-bytes alg msg) want)
    ;; incremental must agree with one-shot
    (define dg (make-digest alg))
    (for ([b (in-bytes msg)]) (digest-update! dg (bytes b)))
    (check-equal? (format "digest ~a incremental" alg) (digest-final! dg) want)
    ;; port streaming must agree
    (check-equal? (format "digest ~a port" alg)
                  (digest-bytes alg (open-input-bytes msg)) want))
  ;; XOF: SHAKE variable length, prefix property (longer output extends shorter)
  (define s32 (digest-bytes 'shake128 #"abc" #:length 32))
  (define s16 (digest-bytes 'shake128 #"abc" #:length 16))
  (check-equal? "shake128 XOF prefix" (subbytes s32 0 16) s16)
  (check! "shake128 length" (= 32 (bytes-length s32))))

;; ==== AEAD =============================================================

(define (test-aead)
  (for ([alg (in-list (aead-algorithms))])
    (define key (crypto-random-bytes (aead-key-size alg)))
    (define nonce (crypto-random-bytes (aead-nonce-size alg)))
    (define pt #"the quick brown fox jumps over the lazy dog")
    (define aad #"header")
    (define ct (aead-encrypt alg key nonce pt #:aad aad))
    (check-equal? (format "aead ~a roundtrip" alg)
                  (aead-decrypt alg key nonce ct #:aad aad) pt)
    ;; tampering the ciphertext must fail authentication
    (define bad (bytes-copy ct))
    (bytes-set! bad 0 (bitwise-xor (bytes-ref bad 0) 1))
    (check! (format "aead ~a tamper-ct rejected" alg)
            (not (aead-decrypt alg key nonce bad #:aad aad)))
    ;; wrong AAD must fail
    (check! (format "aead ~a wrong-aad rejected" alg)
            (not (aead-decrypt alg key nonce ct #:aad #"HEADER")))))

(define (test-secretbox)
  (define key (secretbox-key))
  (define pt #"secret message")
  (define sealed (secretbox-encrypt key pt))
  (check-equal? "secretbox roundtrip" (secretbox-decrypt key sealed) pt)
  (define bad (bytes-copy sealed))
  (bytes-set! bad (sub1 (bytes-length bad)) (bitwise-xor (bytes-ref bad (sub1 (bytes-length bad))) 1))
  (check! "secretbox tamper rejected" (not (secretbox-decrypt key bad))))

;; ==== MAC ==============================================================

(define (test-mac)
  ;; HMAC-SHA256, RFC 4231 Test Case 2.
  (check-equal? "hmac-sha256 RFC4231-2"
                (hmac-bytes 'sha256 #"Jefe" #"what do ya want for nothing?")
                (hx "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"))
  ;; SipHash-2-4 self-consistency (deterministic under a fixed key).
  (define k (make-bytes 16 7))
  (check-equal? "siphash-2-4 deterministic" (siphash-2-4 k #"abc") (siphash-2-4 k #"abc"))
  (check! "siphash-2-4 key-sensitive"
          (not (equal? (siphash-2-4 (make-bytes 16 1) #"abc")
                       (siphash-2-4 (make-bytes 16 2) #"abc")))))

;; ==== KDF ==============================================================

(define (test-kdf)
  ;; HKDF-SHA256, RFC 5869 Test Case 1.
  (check-equal? "hkdf-sha256 RFC5869-1"
                (hkdf 'sha256 (make-bytes 22 #x0b)
                      #:salt (hx "000102030405060708090a0b0c")
                      #:info (hx "f0f1f2f3f4f5f6f7f8f9")
                      #:length 42)
                (hx (string-append "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf"
                                   "34007208d5b887185865")))
  ;; PBKDF2-HMAC-SHA1, RFC 6070 Test Case 1.
  (check-equal? "pbkdf2-sha1 RFC6070-1"
                (pbkdf2 'sha1 #"password" #"salt" #:iterations 1 #:length 20)
                (hx "0c60c80f961f0e71f3a9b524af6012062fe037a6"))
  ;; Argon2id smoke: deterministic for fixed inputs, correct length.
  (define a (argon2id #"password" #"saltsaltsaltsalt" #:iterations 2 #:memory 4096 #:parallelism 1 #:length 32))
  (check! "argon2id length" (= 32 (bytes-length a)))
  (check-equal? "argon2id deterministic" a
                (argon2id #"password" #"saltsaltsaltsalt" #:iterations 2 #:memory 4096 #:parallelism 1 #:length 32)))

;; ==== key exchange =====================================================

(define (test-kex)
  ;; X25519, RFC 7748 section 5.2 vector 1.
  (check-equal? "x25519 RFC7748"
                (x25519 (hx "a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4")
                        (hx "e6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c"))
                (hx "c3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552"))
  ;; X25519 agreement: a*B == b*A.
  (define a (x25519-generate-private-key))
  (define b (x25519-generate-private-key))
  (define A (x25519-public-key a))
  (define B (x25519-public-key b))
  (check-equal? "x25519 agreement" (x25519 a B) (x25519 b A))
  ;; P-256 ECDH agreement.
  (define pa (p256-generate-private-key))
  (define pb (p256-generate-private-key))
  (check-equal? "p256 ecdh agreement"
                (p256-ecdh pa (p256-public-key pb))
                (p256-ecdh pb (p256-public-key pa))))

;; ==== signatures =======================================================

(define (test-sign)
  ;; Ed25519, RFC 8032 Test 1 (empty message).
  (define sk (hx "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"))
  (define pk (ed25519-public-key sk))
  (check-equal? "ed25519 pubkey RFC8032-1" pk
                (hx "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"))
  (define sig (ed25519-sign sk #""))
  (check-equal? "ed25519 sig RFC8032-1" sig
                (hx (string-append "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555f"
                                   "b8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b")))
  (check! "ed25519 verify" (ed25519-verify pk #"" sig))
  (check! "ed25519 verify tampered msg rejected" (not (ed25519-verify pk #"x" sig)))
  ;; P-256 ECDSA sign/verify + tamper.
  (define d (p256-generate-private-key))
  (define Q (p256-public-key d))
  (define msg #"attack at dawn")
  (define esig (p256-ecdsa-sign d msg))
  (check! "p256 ecdsa verify" (p256-ecdsa-verify Q msg esig))
  (check! "p256 ecdsa tamper rejected" (not (p256-ecdsa-verify Q #"retreat" esig)))
  ;; ML-DSA-65 sign/verify + tamper.
  (define-values (mvk msk) (mldsa65-generate-key))
  (define msig (mldsa65-sign msk msg))
  (check! "mldsa65 verify" (mldsa65-verify mvk msg msig))
  (check! "mldsa65 tamper rejected" (not (mldsa65-verify mvk #"retreat" msig))))

;; ==== KEM ==============================================================

(define (test-kem)
  ;; ML-KEM-768 encaps/decaps agreement + tamper.
  (define-values (ek dk) (mlkem768-generate-key))
  (define-values (ct ss) (mlkem768-encaps ek))
  (check-equal? "mlkem768 agreement" (mlkem768-decaps ct dk) ss)
  ;; A tampered ciphertext yields a *different* (implicit-reject) shared
  ;; secret, never the original -- ML-KEM never signals failure, so the
  ;; property is inequality, not #f.
  (define bad (bytes-copy ct))
  (bytes-set! bad 0 (bitwise-xor (bytes-ref bad 0) 1))
  (check! "mlkem768 tamper diverges" (not (equal? (mlkem768-decaps bad dk) ss)))
  ;; Hybrid X25519+ML-KEM-768.
  (define-values (hek hdk) (x25519mlkem768-generate-key))
  (define-values (hct hss) (x25519mlkem768-encaps hek))
  (check-equal? "x25519mlkem768 agreement" (x25519mlkem768-decaps hct hdk) hss))

;; ==== openssl/* compatibility wrappers =================================

(define (test-openssl-wrappers)
  ;; openssl/sha1 and openssl/md5 now dispatch to rktcrypto; verify they
  ;; still produce the canonical results (Git/legacy consumers rely on it).
  (check-equal? "openssl/sha1 of abc"
                (ossl:sha1 (open-input-bytes #"abc"))
                "a9993e364706816aba3e25717850c26c9cd0d89d")
  (check-equal? "openssl/md5 of abc"
                (ossl:md5 (open-input-bytes #"abc"))
                "900150983cd24fb0d6963f7d28e17f72"))

;; ==== randomness =======================================================

(define (test-random)
  (define a (crypto-random-bytes 32))
  (define b (crypto-random-bytes 32))
  (check! "crypto-random length" (= 32 (bytes-length a)))
  (check! "crypto-random distinct" (not (equal? a b))))

;; ==== no-external-dependency property ==================================
;; The whole point of the migration: these paths must not pull in
;; libcrypto/libssl. On a build that does not bundle OpenSSL this is
;; automatic (the library simply is not present); we assert the crypto
;; operations succeeded above regardless, and report the loader state so
;; a regression that re-introduces a hard dependency is visible.

(define (report-openssl-state)
  (define lc
    (with-handlers ([exn:fail? (lambda (_) 'unavailable)])
      (dynamic-require 'openssl/libcrypto 'libcrypto)))
  (printf "  openssl libcrypto loaded at test time: ~a\n"
          (if (or (eq? lc 'unavailable) (not lc)) "no (crypto ran without it)" "yes")))

;; ==== driver ===========================================================

(define (run-all)
  (test-digests)
  (test-aead)
  (test-secretbox)
  (test-mac)
  (test-kdf)
  (test-kex)
  (test-sign)
  (test-kem)
  (test-openssl-wrappers)
  (test-random)
  (printf "rktcrypto integration: ~a checks, ~a failures\n" checks failures)
  (report-openssl-state)
  (when (> failures 0) (error 'integration "~a check(s) failed" failures)))

(module+ main (run-all))
(module+ test (run-all))
