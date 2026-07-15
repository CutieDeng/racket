/* Argon2id password hashing, per RFC 9106.

   From-scratch public-domain-style implementation, validated by the
   RFC 9106 test vector. Memory-hard: the caller-chosen memory cost
   dominates. Built on the existing BLAKE2b core; the compression
   function G uses the Argon2 permutation P (distinct from BLAKE2b's
   round). This is the data-independent/dependent hybrid (Argon2id):
   the first half of the first pass addresses data-independently, the
   rest data-dependently. */

#include "rktcrypto.h"
#include "rktcrypto_digest.h"
#include <string.h>
#include <stdlib.h>

#define ARGON2_BLOCK_SIZE 1024
#define ARGON2_QWORDS_IN_BLOCK 128
#define ARGON2_VERSION 0x13
#define ARGON2_TYPE_ID 2

static void store32(unsigned char *p, uint32_t v)
{
  p[0] = (unsigned char)v; p[1] = (unsigned char)(v >> 8);
  p[2] = (unsigned char)(v >> 16); p[3] = (unsigned char)(v >> 24);
}
static void store64(unsigned char *p, uint64_t v)
{
  int i;
  for (i = 0; i < 8; i++) p[i] = (unsigned char)(v >> (8 * i));
}
static uint64_t load64(const unsigned char *p)
{
  uint64_t r = 0; int i;
  for (i = 0; i < 8; i++) r |= (uint64_t)p[i] << (8 * i);
  return r;
}

/* Variable-length hash H' (RFC 9106 3.2), output `outlen` bytes. */
static void blake2b_long(unsigned char *out, uint32_t outlen,
                         const unsigned char *in, size_t inlen)
{
  unsigned char lenbuf[4];
  store32(lenbuf, outlen);

  if (outlen <= 64) {
    rktcrypto_blake2b_ctx_t ctx;
    rktcrypto_blake2b_core_init(&ctx, outlen, 0, 0);
    rktcrypto_blake2b_core_update(&ctx, lenbuf, 4);
    rktcrypto_blake2b_core_update(&ctx, in, (intptr_t)inlen);
    rktcrypto_blake2b_core_final(&ctx, out, outlen);
  } else {
    unsigned char v[64];
    uint32_t remaining = outlen;
    unsigned char *pos = out;
    rktcrypto_blake2b_ctx_t ctx;

    rktcrypto_blake2b_core_init(&ctx, 64, 0, 0);
    rktcrypto_blake2b_core_update(&ctx, lenbuf, 4);
    rktcrypto_blake2b_core_update(&ctx, in, (intptr_t)inlen);
    rktcrypto_blake2b_core_final(&ctx, v, 64);
    memcpy(pos, v, 32);
    pos += 32; remaining -= 32;

    while (remaining > 64) {
      rktcrypto_blake2b_core_init(&ctx, 64, 0, 0);
      rktcrypto_blake2b_core_update(&ctx, v, 64);
      rktcrypto_blake2b_core_final(&ctx, v, 64);
      memcpy(pos, v, 32);
      pos += 32; remaining -= 32;
    }
    rktcrypto_blake2b_core_init(&ctx, remaining, 0, 0);
    rktcrypto_blake2b_core_update(&ctx, v, 64);
    rktcrypto_blake2b_core_final(&ctx, pos, remaining);
  }
}

#define ROTR64(x, n) (((x) >> (n)) | ((x) << (64 - (n))))

/* Argon2 mixing (RFC 9106 3.6): note the 2*trunc(a)*trunc(b) term. */
#define ARG_G(a, b, c, d)                                        \
  do {                                                           \
    a = a + b + 2 * (uint64_t)(uint32_t)a * (uint64_t)(uint32_t)b; \
    d = ROTR64(d ^ a, 32);                                       \
    c = c + d + 2 * (uint64_t)(uint32_t)c * (uint64_t)(uint32_t)d; \
    b = ROTR64(b ^ c, 24);                                       \
    a = a + b + 2 * (uint64_t)(uint32_t)a * (uint64_t)(uint32_t)b; \
    d = ROTR64(d ^ a, 16);                                       \
    c = c + d + 2 * (uint64_t)(uint32_t)c * (uint64_t)(uint32_t)d; \
    b = ROTR64(b ^ c, 63);                                       \
  } while (0)

/* Permutation P over 16 64-bit words (RFC 9106 3.6). */
static void permute(uint64_t *v)
{
  ARG_G(v[0], v[4], v[8],  v[12]);
  ARG_G(v[1], v[5], v[9],  v[13]);
  ARG_G(v[2], v[6], v[10], v[14]);
  ARG_G(v[3], v[7], v[11], v[15]);
  ARG_G(v[0], v[5], v[10], v[15]);
  ARG_G(v[1], v[6], v[11], v[12]);
  ARG_G(v[2], v[7], v[8],  v[13]);
  ARG_G(v[3], v[4], v[9],  v[14]);
}

/* Compression G: next = G(prev, ref), optionally XORed into `next`
   (with_xor for passes > 0). Blocks are 128 uint64. */
static void fill_block(const uint64_t *prev, const uint64_t *ref,
                       uint64_t *next, int with_xor)
{
  uint64_t R[128], Q[128];
  int i;

  for (i = 0; i < 128; i++) R[i] = prev[i] ^ ref[i];
  memcpy(Q, R, sizeof(R));

  /* Apply P row-wise: 8 rows of 16 words. */
  for (i = 0; i < 8; i++)
    permute(Q + 16 * i);

  /* Apply P column-wise: columns of the 8x16 layout as pairs; RFC uses
     16-word groups selected across rows. */
  {
    uint64_t col[16];
    int j;
    for (i = 0; i < 8; i++) {
      for (j = 0; j < 8; j++) {
        col[2*j]   = Q[16 * j + 2 * i];
        col[2*j+1] = Q[16 * j + 2 * i + 1];
      }
      permute(col);
      for (j = 0; j < 8; j++) {
        Q[16 * j + 2 * i]     = col[2*j];
        Q[16 * j + 2 * i + 1] = col[2*j+1];
      }
    }
  }

  for (i = 0; i < 128; i++) {
    uint64_t val = Q[i] ^ R[i];
    if (with_xor) next[i] ^= val;
    else next[i] = val;
  }
}

/* Computes the reference block index for Argon2 addressing. */
static uint32_t index_alpha(uint32_t pass, uint32_t lane, uint32_t slice,
                            uint32_t lanes, uint32_t seg_len, uint32_t lane_len,
                            uint32_t index, uint64_t rand, uint32_t ref_lane_same)
{
  uint32_t reference_area_size;
  uint64_t relative_position;
  uint32_t start_position, absolute_position;

  if (pass == 0) {
    if (slice == 0)
      reference_area_size = index - 1;
    else if (ref_lane_same)
      reference_area_size = slice * seg_len + index - 1;
    else
      reference_area_size = slice * seg_len + (index == 0 ? (uint32_t)-1 : 0);
  } else {
    if (ref_lane_same)
      reference_area_size = lane_len - seg_len + index - 1;
    else
      reference_area_size = lane_len - seg_len + (index == 0 ? (uint32_t)-1 : 0);
  }

  relative_position = rand;
  relative_position = (relative_position * relative_position) >> 32;
  relative_position = reference_area_size - 1 -
                      ((reference_area_size * relative_position) >> 32);

  start_position = 0;
  if (pass != 0)
    start_position = (slice == 3) ? 0 : (slice + 1) * seg_len;

  absolute_position = (uint32_t)((start_position + relative_position) % lane_len);
  (void)lanes;
  return absolute_position;
}

/* Full Argon2id. `secret` (K) and `ad` (X) may be NULL with length 0.
   Returns 1 on success, 0 on invalid parameters. Lengths are intptr_t
   for Racket-binding friendliness; they must fit in 32 bits. */
int rktcrypto_argon2id(const unsigned char *pwd, intptr_t pwdlen_,
                       const unsigned char *salt, intptr_t saltlen_,
                       const unsigned char *secret, intptr_t secretlen_,
                       const unsigned char *ad, intptr_t adlen_,
                       intptr_t t_cost_, intptr_t m_cost_, intptr_t parallelism_,
                       unsigned char *out, intptr_t outlen_)
{
  uint32_t pwdlen = (uint32_t)pwdlen_, saltlen = (uint32_t)saltlen_;
  uint32_t secretlen = (uint32_t)secretlen_, adlen = (uint32_t)adlen_;
  uint32_t t_cost = (uint32_t)t_cost_, m_cost = (uint32_t)m_cost_;
  uint32_t parallelism = (uint32_t)parallelism_, outlen = (uint32_t)outlen_;
  uint32_t memory_blocks, segment_length, lane_length;
  uint64_t *memory;
  unsigned char h0[72]; /* 64-byte BLAKE2b + two 4-byte fields */
  uint32_t lane, slice, pass, i;

  if (parallelism < 1 || t_cost < 1 || outlen < 4) return 0;
  if (m_cost < 8 * parallelism) m_cost = 8 * parallelism;

  memory_blocks = m_cost;
  segment_length = memory_blocks / (parallelism * 4);
  memory_blocks = segment_length * parallelism * 4;
  lane_length = segment_length * 4;

  memory = (uint64_t *)malloc((size_t)memory_blocks * ARGON2_BLOCK_SIZE);
  if (!memory) return 0;

  /* H0 = BLAKE2b-512(p || tau || m || t || v || y || len(P) || P
                       || len(S) || S || len(K)=0 || len(X)=0) */
  {
    rktcrypto_blake2b_ctx_t ctx;
    unsigned char buf[4];
    rktcrypto_blake2b_core_init(&ctx, 64, 0, 0);
    store32(buf, parallelism); rktcrypto_blake2b_core_update(&ctx, buf, 4);
    store32(buf, outlen);      rktcrypto_blake2b_core_update(&ctx, buf, 4);
    store32(buf, m_cost);      rktcrypto_blake2b_core_update(&ctx, buf, 4);
    store32(buf, t_cost);      rktcrypto_blake2b_core_update(&ctx, buf, 4);
    store32(buf, ARGON2_VERSION); rktcrypto_blake2b_core_update(&ctx, buf, 4);
    store32(buf, ARGON2_TYPE_ID); rktcrypto_blake2b_core_update(&ctx, buf, 4);
    store32(buf, pwdlen);      rktcrypto_blake2b_core_update(&ctx, buf, 4);
    rktcrypto_blake2b_core_update(&ctx, pwd, (intptr_t)pwdlen);
    store32(buf, saltlen);     rktcrypto_blake2b_core_update(&ctx, buf, 4);
    rktcrypto_blake2b_core_update(&ctx, salt, (intptr_t)saltlen);
    store32(buf, secretlen);   rktcrypto_blake2b_core_update(&ctx, buf, 4);
    if (secretlen) rktcrypto_blake2b_core_update(&ctx, secret, (intptr_t)secretlen);
    store32(buf, adlen);       rktcrypto_blake2b_core_update(&ctx, buf, 4);
    if (adlen) rktcrypto_blake2b_core_update(&ctx, ad, (intptr_t)adlen);
    rktcrypto_blake2b_core_final(&ctx, h0, 64);
  }

  /* First two blocks of each lane. */
  for (lane = 0; lane < parallelism; lane++) {
    unsigned char blockhash[ARGON2_BLOCK_SIZE];
    store32(h0 + 64, 0); store32(h0 + 68, lane);
    blake2b_long(blockhash, ARGON2_BLOCK_SIZE, h0, 72);
    for (i = 0; i < ARGON2_QWORDS_IN_BLOCK; i++)
      memory[(lane * lane_length + 0) * ARGON2_QWORDS_IN_BLOCK + i] = load64(blockhash + 8 * i);
    store32(h0 + 64, 1);
    blake2b_long(blockhash, ARGON2_BLOCK_SIZE, h0, 72);
    for (i = 0; i < ARGON2_QWORDS_IN_BLOCK; i++)
      memory[(lane * lane_length + 1) * ARGON2_QWORDS_IN_BLOCK + i] = load64(blockhash + 8 * i);
  }

  /* Fill the rest, pass by pass, slice by slice, lane by lane. */
  for (pass = 0; pass < t_cost; pass++) {
    for (slice = 0; slice < 4; slice++) {
      for (lane = 0; lane < parallelism; lane++) {
        uint32_t start_index, idx;
        int data_independent =
          (pass == 0 && slice < 2); /* Argon2id: first half of first pass */
        uint64_t addr_input[128], addr_block[128], addr_zero[128];
        uint32_t addr_counter = 0;

        memset(addr_input, 0, sizeof(addr_input));
        memset(addr_zero, 0, sizeof(addr_zero));
        if (data_independent) {
          addr_input[0] = pass;
          addr_input[1] = lane;
          addr_input[2] = slice;
          addr_input[3] = memory_blocks;
          addr_input[4] = t_cost;
          addr_input[5] = ARGON2_TYPE_ID;
        }

        start_index = 0;
        if (pass == 0 && slice == 0) start_index = 2;

        for (idx = start_index; idx < segment_length; idx++) {
          uint32_t cur_offset = lane * lane_length + slice * segment_length + idx;
          uint32_t prev_offset = (idx == 0 && slice == 0)
            ? lane * lane_length + lane_length - 1
            : cur_offset - 1;
          uint64_t pseudo_rand;
          uint32_t ref_lane, ref_index, ref_offset;

          if (data_independent) {
            if ((addr_counter % ARGON2_QWORDS_IN_BLOCK) == 0) {
              addr_input[6]++;
              fill_block(addr_zero, addr_input, addr_block, 0);
              fill_block(addr_zero, addr_block, addr_block, 0);
            }
            pseudo_rand = addr_block[addr_counter % ARGON2_QWORDS_IN_BLOCK];
            addr_counter++;
          } else {
            pseudo_rand = memory[prev_offset * ARGON2_QWORDS_IN_BLOCK + 0];
          }

          ref_lane = (uint32_t)((pseudo_rand >> 32) % parallelism);
          if (pass == 0 && slice == 0) ref_lane = lane;

          ref_index = index_alpha(pass, lane, slice, parallelism,
                                  segment_length, lane_length, idx,
                                  pseudo_rand & 0xFFFFFFFF,
                                  ref_lane == lane);
          ref_offset = ref_lane * lane_length + ref_index;

          fill_block(memory + prev_offset * ARGON2_QWORDS_IN_BLOCK,
                     memory + ref_offset * ARGON2_QWORDS_IN_BLOCK,
                     memory + cur_offset * ARGON2_QWORDS_IN_BLOCK,
                     pass != 0);
        }
      }
    }
  }

  /* Final block = XOR of last block of every lane; tag = H'(final). */
  {
    uint64_t final_block[128];
    unsigned char final_bytes[ARGON2_BLOCK_SIZE];
    memcpy(final_block,
           memory + (lane_length - 1) * ARGON2_QWORDS_IN_BLOCK,
           sizeof(final_block));
    for (lane = 1; lane < parallelism; lane++) {
      uint64_t *last = memory + (lane * lane_length + lane_length - 1) * ARGON2_QWORDS_IN_BLOCK;
      for (i = 0; i < 128; i++) final_block[i] ^= last[i];
    }
    for (i = 0; i < 128; i++) store64(final_bytes + 8 * i, final_block[i]);
    blake2b_long(out, outlen, final_bytes, ARGON2_BLOCK_SIZE);
  }

  rktcrypto_secure_clear((unsigned char *)memory, 0, (intptr_t)memory_blocks * ARGON2_BLOCK_SIZE);
  free(memory);
  return 1;
}
