;; AES-CCM bulk inner loops (AArch64, NEON crypto AES), hand-scheduled in rktasm.
;; Each processes N whole 16-byte blocks of the CCM combined pass: per block it
;; runs two independent AES encryptions -- one for the CTR keystream, one for the
;; CBC-MAC chain -- and increments the counter big-endian over its trailing 64
;; bits (covers every CCM L in 2..8; no NEON lane ops needed). CCM always
;; authenticates the PLAINTEXT, so there are two variants:
;;   ccm_bulk_seal_asm : in = plaintext  -> out = ciphertext, MAC folds `in`
;;   ccm_bulk_open_asm : in = ciphertext -> out = plaintext,  MAC folds `out`
;; The C driver (rktcrypto_ccm.c) owns B0/AAD formatting, the S0 tag encryption,
;; and the final partial block; these kernels are the hot full-block path only.
;; Round keys rk = (Nr+1) contiguous 16-byte keys. Oracle: ccm_bulk_portable in
;; rktcrypto_ccm.c (bit-exact); gate: asm/tests/test_ccm.c.
;;
;; void ccm_bulk_{seal,open}_asm(const unsigned char *rk, intptr_t Nr,
;;        unsigned char X[16], unsigned char ctr[16],
;;        const unsigned char *in, unsigned char *out, intptr_t nblocks)

.function ccm_bulk_seal_asm export (
  in: x.rk, x.nr, x.xp, x.ctr, x.in, x.out, x.n
)
entry:
  .save all
  ld1 { v.x.16b }, [x.xp]           ; running CBC-MAC state
seal_loop:
  cbz x.n, seal_done
  ld1 { v.ctrb.16b }, [x.ctr]       ; counter block A_i
  ld1 { v.pt.16b }, [x.in], #16     ; plaintext block

  ;; CTR keystream: v.s = AES_enc(rk, ctr)
  mov v.s.16b, v.ctrb.16b
  mov x.rp, x.rk
  sub x.i, x.nr, #1
  ld1 { v.k.16b }, [x.rp], #16
seal_aes_s:
  aese v.s.16b, v.k.16b
  aesmc v.s.16b, v.s.16b
  ld1 { v.k.16b }, [x.rp], #16
  subs x.i, x.i, #1
  b.ne seal_aes_s
  aese v.s.16b, v.k.16b
  ld1 { v.k.16b }, [x.rp]
  eor v.s.16b, v.s.16b, v.k.16b
  eor v.ct.16b, v.pt.16b, v.s.16b   ; ciphertext = pt ^ keystream
  st1 { v.ct.16b }, [x.out], #16

  ;; counter += 1 (big-endian, trailing 64 bits, in memory)
  ldr x.tmp, [x.ctr, #8]
  rev x.tmp, x.tmp
  add x.tmp, x.tmp, #1
  rev x.tmp, x.tmp
  str x.tmp, [x.ctr, #8]

  ;; CBC-MAC over the plaintext: v.x = AES_enc(rk, X ^ pt)
  eor v.x.16b, v.x.16b, v.pt.16b
  mov x.rp, x.rk
  sub x.i, x.nr, #1
  ld1 { v.k.16b }, [x.rp], #16
seal_aes_x:
  aese v.x.16b, v.k.16b
  aesmc v.x.16b, v.x.16b
  ld1 { v.k.16b }, [x.rp], #16
  subs x.i, x.i, #1
  b.ne seal_aes_x
  aese v.x.16b, v.k.16b
  ld1 { v.k.16b }, [x.rp]
  eor v.x.16b, v.x.16b, v.k.16b

  sub x.n, x.n, #1
  b seal_loop
seal_done:
  st1 { v.x.16b }, [x.xp]
  .restore all
  ret
.end

.function ccm_bulk_open_asm export (
  in: x.rk, x.nr, x.xp, x.ctr, x.in, x.out, x.n
)
entry:
  .save all
  ld1 { v.x.16b }, [x.xp]
open_loop:
  cbz x.n, open_done
  ld1 { v.ctrb.16b }, [x.ctr]
  ld1 { v.ct.16b }, [x.in], #16     ; ciphertext block

  ;; CTR keystream: v.s = AES_enc(rk, ctr)
  mov v.s.16b, v.ctrb.16b
  mov x.rp, x.rk
  sub x.i, x.nr, #1
  ld1 { v.k.16b }, [x.rp], #16
open_aes_s:
  aese v.s.16b, v.k.16b
  aesmc v.s.16b, v.s.16b
  ld1 { v.k.16b }, [x.rp], #16
  subs x.i, x.i, #1
  b.ne open_aes_s
  aese v.s.16b, v.k.16b
  ld1 { v.k.16b }, [x.rp]
  eor v.s.16b, v.s.16b, v.k.16b
  eor v.pt.16b, v.ct.16b, v.s.16b   ; plaintext = ct ^ keystream
  st1 { v.pt.16b }, [x.out], #16

  ;; counter += 1
  ldr x.tmp, [x.ctr, #8]
  rev x.tmp, x.tmp
  add x.tmp, x.tmp, #1
  rev x.tmp, x.tmp
  str x.tmp, [x.ctr, #8]

  ;; CBC-MAC over the recovered plaintext: v.x = AES_enc(rk, X ^ pt)
  eor v.x.16b, v.x.16b, v.pt.16b
  mov x.rp, x.rk
  sub x.i, x.nr, #1
  ld1 { v.k.16b }, [x.rp], #16
open_aes_x:
  aese v.x.16b, v.k.16b
  aesmc v.x.16b, v.x.16b
  ld1 { v.k.16b }, [x.rp], #16
  subs x.i, x.i, #1
  b.ne open_aes_x
  aese v.x.16b, v.k.16b
  ld1 { v.k.16b }, [x.rp]
  eor v.x.16b, v.x.16b, v.k.16b

  sub x.n, x.n, #1
  b open_loop
open_done:
  st1 { v.x.16b }, [x.xp]
  .restore all
  ret
.end
