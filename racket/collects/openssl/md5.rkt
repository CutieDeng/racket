#lang racket/base

;; Historically this bound OpenSSL's libcrypto MD5_* routines (with a
;; pure-Racket fallback). It now uses Racket's built-in MD5 from
;; `racket/crypto`, so it no longer depends on any external library. The
;; interface is unchanged. (MD5 is cryptographically broken; use it only
;; for legacy compatibility and non-security checksums.)

(require (only-in racket/crypto/digest digest-bytes)
         (only-in file/sha1 bytes->hex-string))

(provide md5
         md5-bytes)

(define (md5-bytes in)
  (unless (input-port? in) (raise-argument-error 'md5-bytes "input-port?" in))
  (digest-bytes 'md5 in))

(define (md5 in)
  (unless (input-port? in) (raise-argument-error 'md5 "input-port?" in))
  (bytes->hex-string (md5-bytes in)))
