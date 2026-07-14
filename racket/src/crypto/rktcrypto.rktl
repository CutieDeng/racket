;; Extracted from rktio.h by rktio/parse.rkt
(begin
(define-constant RKTCRYPTO_SHA224 1)
(define-constant RKTCRYPTO_SHA256 2)
(define-constant RKTCRYPTO_SHA384 3)
(define-constant RKTCRYPTO_SHA512 4)
(define-constant RKTCRYPTO_SHA512_256 5)
(define-constant RKTCRYPTO_SHA3_224 6)
(define-constant RKTCRYPTO_SHA3_256 7)
(define-constant RKTCRYPTO_SHA3_384 8)
(define-constant RKTCRYPTO_SHA3_512 9)
(define-constant RKTCRYPTO_SHAKE128 10)
(define-constant RKTCRYPTO_SHAKE256 11)
(define-constant RKTCRYPTO_BLAKE2B 12)
(define-constant RKTCRYPTO_DIGEST_CTX_MAXSIZE 512)
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
(define-function () intptr_t rktcrypto_digest_ctx_size ((int alg)))
(define-function () intptr_t rktcrypto_digest_size ((int alg)))
(define-function () intptr_t rktcrypto_digest_block_size ((int alg)))
(define-function () int rktcrypto_digest_is_xof ((int alg)))
(define-function
 ()
 int
 rktcrypto_digest_init
 ((int alg) ((*ref unsigned-8) ctx) (intptr_t ctx_len) (intptr_t outlen)))
(define-function
 ()
 int
 rktcrypto_digest_update
 ((int alg)
  ((*ref unsigned-8) ctx)
  (intptr_t ctx_len)
  ((*ref unsigned-8) data)
  (intptr_t start)
  (intptr_t end)))
(define-function
 ()
 int
 rktcrypto_digest_final
 ((int alg)
  ((*ref unsigned-8) ctx)
  (intptr_t ctx_len)
  ((*ref unsigned-8) out)
  (intptr_t out_start)
  (intptr_t out_len)))
(define-function
 ()
 int
 rktcrypto_digest_oneshot
 ((int alg)
  ((*ref unsigned-8) data)
  (intptr_t start)
  (intptr_t end)
  ((*ref unsigned-8) out)
  (intptr_t out_start)
  (intptr_t out_len)))
(define-function () int rktcrypto_selftest_core ())
)
