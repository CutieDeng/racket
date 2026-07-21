#lang racket/base

;; FFI bindings to the in-tree rktcrypto library for the TLS backend.
;;
;; librktcrypto is a static library linked into the Racket executable
;; (alongside rktio), and its symbols are exported from the running
;; process, so `(ffi-lib #f)` resolves them with no dynamic library to
;; load -- this is what makes the TLS backend work on a machine with no
;; OpenSSL installed. All heavy cryptography (key schedule, AEAD record
;; protection, signatures, big numbers) happens in C behind these
;; bindings; the Racket side is the protocol state machine.

(require ffi/unsafe
         ffi/unsafe/define)

(provide (protect-out (all-defined-out)))

(define-ffi-definer define-rkt (ffi-lib #f)
  #:default-make-fail make-not-available)

;; Whether librktcrypto is actually part of this build; Windows builds
;; run without it, and every binding below raises when called there.
(define rktcrypto-available?
  (and (get-ffi-obj 'rktcrypto_system_random (ffi-lib #f) _fpointer (lambda () #f)) #t))

;; ---- digest algorithm ids (rktcrypto.h) ----
(define SHA256 2)
(define SHA384 3)
(define SHA512 4)

;; ---- AEAD ids ----
(define AEAD-CHACHA20-POLY1305 1)
(define AEAD-AES256-GCM 3)
(define AEAD-AES128-GCM 4)

(define-rkt rktcrypto_digest_size (_fun _int -> _intptr))
(define-rkt rktcrypto_digest_oneshot
  (_fun _int _bytes _intptr _intptr _bytes _intptr _intptr -> _int))

(define-rkt rktcrypto_hmac
  (_fun _int _bytes _intptr _bytes _intptr _bytes -> _void))

(define-rkt rktcrypto_hkdf_extract
  (_fun _int _bytes _intptr _bytes _intptr _bytes -> _void))
(define-rkt rktcrypto_hkdf_expand
  (_fun _int _bytes _intptr _bytes _intptr _bytes _intptr -> _int))

(define-rkt rktcrypto_tls13_expand_label
  (_fun _int _bytes _intptr _bytes _intptr _bytes _intptr _bytes _intptr -> _int))
(define-rkt rktcrypto_tls13_extract
  (_fun _int _bytes _intptr _bytes _intptr _bytes -> _void))
(define-rkt rktcrypto_tls13_derive_secret
  (_fun _int _bytes _bytes _intptr _bytes _bytes -> _int))
(define-rkt rktcrypto_tls13_traffic_keys
  (_fun _int _bytes _bytes _intptr _bytes _intptr -> _int))
(define-rkt rktcrypto_tls13_finished_key
  (_fun _int _bytes _bytes -> _int))
(define-rkt rktcrypto_tls13_verify_data
  (_fun _int _bytes _bytes _bytes -> _void))
(define-rkt rktcrypto_tls13_record_seal
  (_fun _int _bytes _intptr _bytes _intptr _uint64 _bytes _intptr _bytes -> _intptr))
(define-rkt rktcrypto_tls13_record_open
  (_fun _int _bytes _intptr _bytes _intptr _uint64 _bytes _intptr _bytes -> _intptr))

(define-rkt rktcrypto_aead_key_size (_fun _int -> _intptr))
(define-rkt rktcrypto_aead_nonce_size (_fun _int -> _intptr))
(define-rkt rktcrypto_aead_tag_size (_fun _int -> _intptr))
(define-rkt rktcrypto_aead_seal
  (_fun _int _bytes _intptr _bytes _intptr
        _bytes _intptr _intptr _bytes _intptr _intptr _bytes _intptr -> _int))
(define-rkt rktcrypto_aead_open
  (_fun _int _bytes _intptr _bytes _intptr
        _bytes _intptr _intptr _bytes _intptr _intptr _bytes _intptr -> _int))

;; ---- key exchange ----
(define-rkt rktcrypto_x25519 (_fun _bytes _bytes _bytes -> _int))
(define-rkt rktcrypto_p256_pubkey (_fun _bytes _bytes -> _int))
(define-rkt rktcrypto_p256_ecdh (_fun _bytes _bytes _bytes -> _int))
(define-rkt rktcrypto_p384_pubkey (_fun _bytes _bytes -> _int))
(define-rkt rktcrypto_p384_ecdh (_fun _bytes _bytes _bytes -> _int))

;; ---- signatures ----
(define-rkt rktcrypto_p256_ecdsa_sign (_fun _bytes _bytes _intptr _bytes -> _int))
(define-rkt rktcrypto_p256_ecdsa_verify (_fun _bytes _bytes _intptr _bytes -> _int))
(define-rkt rktcrypto_p384_ecdsa_sign (_fun _bytes _bytes _intptr _bytes -> _int))
(define-rkt rktcrypto_p384_ecdsa_verify (_fun _bytes _bytes _intptr _bytes -> _int))
(define-rkt rktcrypto_p521_ecdsa_sign (_fun _bytes _bytes _intptr _bytes -> _int))
(define-rkt rktcrypto_p521_ecdsa_verify (_fun _bytes _bytes _intptr _bytes -> _int))
(define-rkt rktcrypto_p256_ecdsa_verify_h (_fun _bytes _bytes _intptr _bytes -> _int))
(define-rkt rktcrypto_p384_ecdsa_verify_h (_fun _bytes _bytes _intptr _bytes -> _int))
(define-rkt rktcrypto_p521_ecdsa_verify_h (_fun _bytes _bytes _intptr _bytes -> _int))
(define-rkt rktcrypto_ed25519_pubkey (_fun _bytes _bytes -> _int))
(define-rkt rktcrypto_ed25519_sign (_fun _bytes _bytes _intptr _bytes -> _int))
(define-rkt rktcrypto_ed25519_verify (_fun _bytes _bytes _intptr _bytes -> _int))

(define-rkt rktcrypto_rsa_verify_msg
  (_fun _int _int _bytes _intptr _bytes _intptr _bytes _intptr _bytes _intptr -> _int))
(define-rkt rktcrypto_rsa_sign_msg
  (_fun _int _int _bytes _intptr _bytes _intptr _bytes -> _intptr))

;; ---- PEM / base64 ----
(define-rkt rktcrypto_base64_decode (_fun _bytes _intptr _bytes -> _intptr))

(define-rkt rktcrypto_random_bytes (_fun _bytes _intptr _intptr -> _int))
(define-rkt rktcrypto_ct_bytes_equal (_fun _bytes _intptr _bytes _intptr _intptr -> _int))
(define-rkt rktcrypto_tls13_selftest (_fun -> _int))

;; ---- convenience wrappers ----

(define (digest-size alg) (rktcrypto_digest_size alg))

(define (digest alg data)
  (define out (make-bytes (digest-size alg)))
  (rktcrypto_digest_oneshot alg data 0 (bytes-length data) out 0 (bytes-length out))
  out)

(define (hmac alg key data)
  (define out (make-bytes (digest-size alg)))
  (rktcrypto_hmac alg key (bytes-length key) data (bytes-length data) out)
  out)

(define (random-bytes n)
  (define out (make-bytes n))
  (unless (eqv? 1 (rktcrypto_random_bytes out 0 n))
    (error 'random-bytes "entropy failure"))
  out)

(define (ct-equal? a b)
  (and (= (bytes-length a) (bytes-length b))
       (eqv? 1 (rktcrypto_ct_bytes_equal a 0 b 0 (bytes-length a)))))

;; HKDF-Expand-Label with a bytes label/context; returns a fresh byte string.
(define (expand-label alg secret label context outlen)
  (define out (make-bytes outlen))
  (unless (eqv? 1 (rktcrypto_tls13_expand_label
                   alg secret (bytes-length secret)
                   label (bytes-length label)
                   context (if context (bytes-length context) 0)
                   out outlen))
    (error 'expand-label "failed"))
  out)

;; HKDF-Extract with TLS argument order (salt, ikm); #f means zeros.
(define (tls13-extract alg salt ikm)
  (define out (make-bytes (digest-size alg)))
  (rktcrypto_tls13_extract alg salt (if salt (bytes-length salt) 0)
                           ikm (if ikm (bytes-length ikm) 0) out)
  out)

(define (derive-secret alg secret label transcript-hash)
  (define out (make-bytes (digest-size alg)))
  (unless (eqv? 1 (rktcrypto_tls13_derive_secret alg secret label (bytes-length label)
                                                 transcript-hash out))
    (error 'derive-secret "failed"))
  out)

(define (traffic-keys alg secret key-len iv-len)
  (define key (make-bytes key-len))
  (define iv (make-bytes iv-len))
  (unless (eqv? 1 (rktcrypto_tls13_traffic_keys alg secret key key-len iv iv-len))
    (error 'traffic-keys "failed"))
  (values key iv))

(define (finished-verify-data alg base-key transcript-hash)
  (define fk (make-bytes (digest-size alg)))
  (unless (eqv? 1 (rktcrypto_tls13_finished_key alg base-key fk))
    (error 'finished-key "failed"))
  (define out (make-bytes (digest-size alg)))
  (rktcrypto_tls13_verify_data alg fk transcript-hash out)
  out)

;; Seals one TLS 1.3 record; inner = content || content-type byte.
;; Returns the full record (header + ciphertext + tag).
(define (tls13-seal aead key iv seq inner)
  (define tag (rktcrypto_aead_tag_size aead))
  (define out (make-bytes (+ 5 (bytes-length inner) tag)))
  (define n (rktcrypto_tls13_record_seal aead key (bytes-length key)
                                         iv (bytes-length iv) seq
                                         inner (bytes-length inner) out))
  (if (= n (bytes-length out)) out (error 'tls13-seal "failed")))

;; Opens one TLS 1.3 record (full record bytes); returns the inner
;; plaintext (content || content-type || padding) or #f.
(define (tls13-open aead key iv seq rec)
  (define tag (rktcrypto_aead_tag_size aead))
  (define n (- (bytes-length rec) 5 tag))
  (and (>= n 0)
       (let* ([out (make-bytes (max n 1))]
              [got (rktcrypto_tls13_record_open aead key (bytes-length key)
                                                iv (bytes-length iv) seq
                                                rec (bytes-length rec) out)])
         (and (= got n) (subbytes out 0 n)))))

;; Raw AEAD for the TLS 1.2 record layer (explicit-nonce GCM etc.).
(define (aead-seal aead key nonce aad pt)
  (define tag (rktcrypto_aead_tag_size aead))
  (define out (make-bytes (+ (bytes-length pt) tag)))
  (and (eqv? 1 (rktcrypto_aead_seal aead key (bytes-length key)
                                    nonce (bytes-length nonce)
                                    aad 0 (bytes-length aad)
                                    pt 0 (bytes-length pt)
                                    out 0))
       out))

(define (aead-open aead key nonce aad ct+tag)
  (define tag (rktcrypto_aead_tag_size aead))
  (define n (- (bytes-length ct+tag) tag))
  (and (>= n 0)
       (let ([out (make-bytes (max n 1))])
         (and (eqv? 1 (rktcrypto_aead_open aead key (bytes-length key)
                                           nonce (bytes-length nonce)
                                           aad 0 (bytes-length aad)
                                           ct+tag 0 (bytes-length ct+tag)
                                           out 0))
              (subbytes out 0 n)))))

(define (base64-decode bs)
  (define out (make-bytes (bytes-length bs)))
  (define n (rktcrypto_base64_decode bs (bytes-length bs) out))
  (and (>= n 0) (subbytes out 0 n)))
