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
(define-constant RKTCRYPTO_BLAKE3 13)
(define-constant RKTCRYPTO_SHA1 14)
(define-constant RKTCRYPTO_MD5 15)
(define-constant RKTCRYPTO_DIGEST_CTX_MAXSIZE 2048)
(define-constant RKTCRYPTO_AEAD_CHACHA20_POLY1305 1)
(define-constant RKTCRYPTO_AEAD_XCHACHA20_POLY1305 2)
(define-constant RKTCRYPTO_AEAD_AES256_GCM 3)
(define-constant RKTCRYPTO_MLKEM768_PUBLICKEYBYTES 1184)
(define-constant RKTCRYPTO_MLKEM768_SECRETKEYBYTES 2400)
(define-constant RKTCRYPTO_MLKEM768_CIPHERTEXTBYTES 1088)
(define-constant RKTCRYPTO_MLKEM768_BYTES 32)
(define-constant RKTCRYPTO_MLDSA65_PUBLICKEYBYTES 1952)
(define-constant RKTCRYPTO_MLDSA65_SECRETKEYBYTES 4032)
(define-constant RKTCRYPTO_MLDSA65_SIGBYTES 3309)
(define-function
 ()
 int
 rktcrypto_system_random
 (((*ref unsigned-8) buf) (intptr_t start) (intptr_t end)))
(define-function
 ()
 int
 rktcrypto_random_bytes
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
(define-function () intptr_t rktcrypto_aead_key_size ((int alg)))
(define-function () intptr_t rktcrypto_aead_nonce_size ((int alg)))
(define-function () intptr_t rktcrypto_aead_tag_size ((int alg)))
(define-function
 ()
 int
 rktcrypto_aead_seal
 ((int alg)
  ((*ref unsigned-8) key)
  (intptr_t key_len)
  ((*ref unsigned-8) nonce)
  (intptr_t nonce_len)
  ((*ref unsigned-8) aad)
  (intptr_t aad_start)
  (intptr_t aad_end)
  ((*ref unsigned-8) pt)
  (intptr_t pt_start)
  (intptr_t pt_end)
  ((*ref unsigned-8) out)
  (intptr_t out_start)))
(define-function
 ()
 int
 rktcrypto_aead_open
 ((int alg)
  ((*ref unsigned-8) key)
  (intptr_t key_len)
  ((*ref unsigned-8) nonce)
  (intptr_t nonce_len)
  ((*ref unsigned-8) aad)
  (intptr_t aad_start)
  (intptr_t aad_end)
  ((*ref unsigned-8) ct)
  (intptr_t ct_start)
  (intptr_t ct_end)
  ((*ref unsigned-8) out)
  (intptr_t out_start)))
(define-function
 ()
 int
 rktcrypto_argon2id
 (((*ref unsigned-8) pwd)
  (intptr_t pwdlen)
  ((*ref unsigned-8) salt)
  (intptr_t saltlen)
  ((*ref unsigned-8) secret)
  (intptr_t secretlen)
  ((*ref unsigned-8) ad)
  (intptr_t adlen)
  (intptr_t t_cost)
  (intptr_t m_cost)
  (intptr_t parallelism)
  ((*ref unsigned-8) out)
  (intptr_t outlen)))
(define-function
 ()
 int
 rktcrypto_x25519
 (((*ref unsigned-8) out)
  ((*ref unsigned-8) scalar)
  ((*ref unsigned-8) point)))
(define-function
 ()
 int
 rktcrypto_ed25519_pubkey
 (((*ref unsigned-8) pk) ((*ref unsigned-8) seed)))
(define-function
 ()
 int
 rktcrypto_ed25519_sign
 (((*ref unsigned-8) sig)
  ((*ref unsigned-8) msg)
  (intptr_t msglen)
  ((*ref unsigned-8) seed)))
(define-function
 ()
 int
 rktcrypto_ed25519_verify
 (((*ref unsigned-8) sig)
  ((*ref unsigned-8) msg)
  (intptr_t msglen)
  ((*ref unsigned-8) pk)))
(define-function
 ()
 int
 rktcrypto_p256_pubkey
 (((*ref unsigned-8) out65) ((*ref unsigned-8) priv)))
(define-function
 ()
 int
 rktcrypto_p256_ecdh
 (((*ref unsigned-8) out)
  ((*ref unsigned-8) scalar)
  ((*ref unsigned-8) point65)))
(define-function
 ()
 int
 rktcrypto_p256_ecdsa_sign
 (((*ref unsigned-8) sig)
  ((*ref unsigned-8) msg)
  (intptr_t msglen)
  ((*ref unsigned-8) priv)))
(define-function
 ()
 int
 rktcrypto_p256_ecdsa_verify
 (((*ref unsigned-8) sig)
  ((*ref unsigned-8) msg)
  (intptr_t msglen)
  ((*ref unsigned-8) pub65)))
(define-function
 ()
 int
 rktcrypto_siphash
 (((*ref unsigned-8) key)
  (intptr_t key_len)
  (int crounds)
  (int drounds)
  ((*ref unsigned-8) data)
  (intptr_t start)
  (intptr_t end)
  ((*ref unsigned-8) out)
  (intptr_t out_start)))
(define-function
 ()
 int
 rktcrypto_mlkem768_keypair
 (((*ref unsigned-8) pk) ((*ref unsigned-8) sk)))
(define-function
 ()
 int
 rktcrypto_mlkem768_encaps
 (((*ref unsigned-8) ct) ((*ref unsigned-8) ss) ((*ref unsigned-8) pk)))
(define-function
 ()
 int
 rktcrypto_mlkem768_decaps
 (((*ref unsigned-8) ss) ((*ref unsigned-8) ct) ((*ref unsigned-8) sk)))
(define-function
 ()
 int
 rktcrypto_mlkem768_keypair_derand
 (((*ref unsigned-8) pk) ((*ref unsigned-8) sk) ((*ref unsigned-8) coins)))
(define-function
 ()
 int
 rktcrypto_mlkem768_enc_derand
 (((*ref unsigned-8) ct)
  ((*ref unsigned-8) ss)
  ((*ref unsigned-8) pk)
  ((*ref unsigned-8) m)))
(define-function
 ()
 int
 rktcrypto_mldsa65_keypair
 (((*ref unsigned-8) pk) ((*ref unsigned-8) sk)))
(define-function
 ()
 int
 rktcrypto_mldsa65_sign
 (((*ref unsigned-8) sig)
  ((*ref unsigned-8) m)
  (intptr_t mlen)
  ((*ref unsigned-8) sk)))
(define-function
 ()
 int
 rktcrypto_mldsa65_verify
 (((*ref unsigned-8) sig)
  ((*ref unsigned-8) m)
  (intptr_t mlen)
  ((*ref unsigned-8) pk)))
(define-function
 ()
 int
 rktcrypto_mldsa65_keypair_derand
 (((*ref unsigned-8) pk) ((*ref unsigned-8) sk) ((*ref unsigned-8) seed)))
(define-function
 ()
 int
 rktcrypto_mldsa65_sign_derand
 (((*ref unsigned-8) sig)
  ((*ref unsigned-8) m)
  (intptr_t mlen)
  ((*ref unsigned-8) sk)))
(define-function () int rktcrypto_selftest_core ())
)
