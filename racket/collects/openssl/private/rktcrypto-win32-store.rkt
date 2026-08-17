#lang racket/base

;; Windows: read root-certificate DERs out of a system certificate store
;; through crypt32.dll (CryptoAPI). The rktcrypto TLS backend consumes raw
;; DER anchors, so each enumerated certificate's encoded bytes are copied
;; out as-is -- no X509 object round-trip. On other platforms `crypt32-lib`
;; is #f and the bindings raise if ever called.

(require ffi/unsafe
         ffi/unsafe/define
         ffi/winapi)

(provide win32-store-ders)

(define crypt32-lib
  (and (eq? 'windows (system-type))
       (ffi-lib "crypt32.dll")))

(define-ffi-definer define-crypt crypt32-lib
  #:default-make-fail make-not-available)

(define _DWORD _int32)
(define-cpointer-type _CERTSTORE)
(define-cstruct _sCERT_CONTEXT
  ([certEncodingType _int32]
   [certEncoded _pointer]
   [certEncodedLen _int32]
   [certInfo _pointer]
   [certStore _pointer]))
(define-cpointer-type _CERT_CONTEXT _sCERT_CONTEXT-pointer)

(define-syntax-rule (_wfun . parts) (_fun #:abi winapi . parts))

(define-crypt CertCloseStore
  (_wfun _CERTSTORE (_DWORD = 0) -> _int))
(define-crypt CertOpenSystemStoreW
  (_wfun (_pointer = #f) _string/utf-16 -> _CERTSTORE/null))
;; Enumerating frees the context passed as the cursor, and the last live
;; context is freed when enumeration returns NULL, so no explicit
;; CertFreeCertificateContext calls are needed along this loop.
(define-crypt CertEnumCertificatesInStore
  (_wfun _CERTSTORE _CERT_CONTEXT/null -> _CERT_CONTEXT/null))

;; -> (listof bytes): the DER certificates in `storename` ("ROOT", "CA", ...).
(define (win32-store-ders who storename)
  (define cstore (CertOpenSystemStoreW storename))
  (unless cstore
    (error who "failed to open certificate store: ~e" storename))
  (dynamic-wind
   void
   (lambda ()
     (let loop ([curr #f] [acc null])
       (define c (CertEnumCertificatesInStore cstore curr))
       (cond
         [c
          (define len (sCERT_CONTEXT-certEncodedLen c))
          (define buf (make-bytes len))
          (memcpy buf (sCERT_CONTEXT-certEncoded c) len)
          (loop c (cons buf acc))]
         [else (reverse acc)])))
   (lambda () (CertCloseStore cstore))))
