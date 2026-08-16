;; Extracted from rktio.h by rktio/parse.rkt
(begin
(define-constant RKTRANDOM_XOSHIRO256PP 1)
(define-constant RKTRANDOM_XOSHIRO256SS 2)
(define-constant RKTRANDOM_XOROSHIRO128PP 3)
(define-constant RKTRANDOM_SFC64 4)
(define-constant RKTRANDOM_PCG64DXSM 5)
(define-constant RKTRANDOM_PHILOX4X64 6)
(define-constant RKTRANDOM_GEN_FIRST 1)
(define-constant RKTRANDOM_GEN_LAST 6)
(define-constant RKTRANDOM_STATE_SIZE 128)
(define-function () int rktrandom_state_size ((int gen)))
(define-function
 ()
 int
 rktrandom_init
 ((int gen)
  ((*ref unsigned-8) state)
  ((*ref unsigned-8) seed)
  (intptr_t seed_start)
  (intptr_t seq)))
(define-function
 ()
 int
 rktrandom_init_int
 ((int gen) ((*ref unsigned-8) state) (intptr_t seed) (intptr_t seq)))
(define-function
 ()
 int
 rktrandom_fill
 ((int gen)
  ((*ref unsigned-8) state)
  ((*ref unsigned-8) buf)
  (intptr_t start)
  (intptr_t end)))
(define-function () int rktrandom_jump ((int gen) ((*ref unsigned-8) state)))
(define-function
 ()
 int
 rktrandom_long_jump
 ((int gen) ((*ref unsigned-8) state)))
(define-function
 ()
 int
 rktrandom_fill_f64
 ((int gen)
  ((*ref unsigned-8) state)
  ((*ref unsigned-8) buf)
  (intptr_t start)
  (intptr_t end)))
(define-function
 ()
 int
 rktrandom_fill_normal
 ((int gen)
  ((*ref unsigned-8) state)
  ((*ref unsigned-8) buf)
  (intptr_t start)
  (intptr_t end)))
(define-function
 ()
 int
 rktrandom_fill_exp
 ((int gen)
  ((*ref unsigned-8) state)
  ((*ref unsigned-8) buf)
  (intptr_t start)
  (intptr_t end)))
(define-function
 ()
 int
 rktrandom_fill_bounded
 ((int gen)
  ((*ref unsigned-8) state)
  ((*ref unsigned-8) buf)
  (intptr_t start)
  (intptr_t end)
  (intptr_t bound)))
(define-function () int rktrandom_selftest ())
)
