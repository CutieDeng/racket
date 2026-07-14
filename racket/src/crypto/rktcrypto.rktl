;; Extracted from rktio.h by rktio/parse.rkt
(begin
(define-function
 ()
 int
 rktcrypto_system_random
 (((*ref unsigned-8) buf) (intptr_t start) (intptr_t end)))
(define-function
 ()
 int
 rktcrypto_ct_bytes_equal
 (((*ref unsigned-8) a)
  (intptr_t a_start)
  ((*ref unsigned-8) b)
  (intptr_t b_start)
  (intptr_t len)))
(define-function
 ()
 void
 rktcrypto_secure_clear
 (((*ref unsigned-8) buf) (intptr_t start) (intptr_t end)))
(define-function () int rktcrypto_selftest_core ())
)
