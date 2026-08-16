#lang racket/base

;; Historically this bound OpenSSL's libcrypto MD5_* routines (with a
;; pure-Racket fallback). It now uses Racket's built-in MD5 from
;; `racket/crypto` when the librktcrypto subsystem is in the build, and
;; the pure-Racket `file/md5` otherwise (Windows builds). The interface
;; is unchanged. (MD5 is cryptographically broken; use it only for
;; legacy compatibility and non-security checksums.)

(require (only-in racket/crypto/digest digest-bytes)
         (only-in racket/private/crypto-core crypto-primitives-available?)
         (only-in file/md5 [md5 file-md5])
         (only-in file/sha1 bytes->hex-string))

(provide md5
         md5-bytes)

(define (md5-bytes in)
  (unless (input-port? in) (raise-argument-error 'md5-bytes "input-port?" in))
  (if (crypto-primitives-available?)
      (digest-bytes 'md5 in)
      (file-md5 in #f)))

(define (md5 in)
  (unless (input-port? in) (raise-argument-error 'md5 "input-port?" in))
  (bytes->hex-string (md5-bytes in)))
