#lang racket/base

;; Historically this bound OpenSSL's libcrypto SHA1_* routines (with a
;; pure-Racket fallback). It now uses Racket's built-in SHA-1 from
;; `racket/crypto`, so it no longer depends on any external library. The
;; interface is unchanged. (SHA-1 is cryptographically broken; use it
;; only for legacy compatibility, e.g. Git object ids.)

(require (only-in racket/crypto/digest digest-bytes)
         (only-in file/sha1
                  bytes->hex-string
                  hex-string->bytes))

(provide sha1
         sha1-bytes
         bytes->hex-string
         hex-string->bytes)

(define (sha1-bytes in)
  (unless (input-port? in) (raise-argument-error 'sha1-bytes "input-port?" in))
  (digest-bytes 'sha1 in))

(define (sha1 in)
  (unless (input-port? in) (raise-argument-error 'sha1 "input-port?" in))
  (bytes->hex-string (sha1-bytes in)))
