/* BLAKE3, per the official specification.

   From-scratch public-domain-style implementation of the portable,
   single-threaded hasher, validated by the official test vectors in
   rktcrypto_selftest.c and the test suite. Supports arbitrary-length
   (XOF) output. Keyed and derive-key modes are not exposed yet.

   The tree is built with a CV stack: each finished 1024-byte chunk
   produces a chaining value; the number of trailing zero bits of the
   completed-chunk count says how many pending CVs to merge, exactly
   like carrying in binary addition. */

#include "rktcrypto_digest.h"
#include <string.h>

#define ROTR32(x, n) (((x) >> (n)) | ((x) << (32 - (n))))

#define BLAKE3_CHUNK_START         (1u << 0)
#define BLAKE3_CHUNK_END           (1u << 1)
#define BLAKE3_PARENT              (1u << 2)
#define BLAKE3_ROOT                (1u << 3)
/* KEYED_HASH / DERIVE_KEY flags are unused in this build. */

static const uint32_t BLAKE3_IV[8] = {
  0x6A09E667u, 0xBB67AE85u, 0x3C6EF372u, 0xA54FF53Au,
  0x510E527Fu, 0x9B05688Cu, 0x1F83D9ABu, 0x5BE0CD19u
};

static const uint8_t MSG_PERMUTATION[16] = {
  2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8
};

static void g(uint32_t *s, int a, int b, int c, int d, uint32_t mx, uint32_t my)
{
  s[a] = s[a] + s[b] + mx;
  s[d] = ROTR32(s[d] ^ s[a], 16);
  s[c] = s[c] + s[d];
  s[b] = ROTR32(s[b] ^ s[c], 12);
  s[a] = s[a] + s[b] + my;
  s[d] = ROTR32(s[d] ^ s[a], 8);
  s[c] = s[c] + s[d];
  s[b] = ROTR32(s[b] ^ s[c], 7);
}

static void round_fn(uint32_t *s, const uint32_t *m)
{
  g(s, 0, 4,  8, 12, m[0],  m[1]);
  g(s, 1, 5,  9, 13, m[2],  m[3]);
  g(s, 2, 6, 10, 14, m[4],  m[5]);
  g(s, 3, 7, 11, 15, m[6],  m[7]);
  g(s, 0, 5, 10, 15, m[8],  m[9]);
  g(s, 1, 6, 11, 12, m[10], m[11]);
  g(s, 2, 7,  8, 13, m[12], m[13]);
  g(s, 3, 4,  9, 14, m[14], m[15]);
}

/* Full compression; writes all 16 output words (the XOF uses the high
   8, the chaining path uses the low 8). */
static void compress(const uint32_t cv[8], const unsigned char block[64],
                     uint32_t block_len, uint64_t counter, uint32_t flags,
                     uint32_t out[16])
{
  uint32_t m[16], s[16];
  int i, r;

  for (i = 0; i < 16; i++)
    m[i] = ((uint32_t)block[4*i]) | ((uint32_t)block[4*i+1] << 8)
         | ((uint32_t)block[4*i+2] << 16) | ((uint32_t)block[4*i+3] << 24);

  for (i = 0; i < 8; i++) s[i] = cv[i];
  s[8]  = BLAKE3_IV[0]; s[9]  = BLAKE3_IV[1]; s[10] = BLAKE3_IV[2]; s[11] = BLAKE3_IV[3];
  s[12] = (uint32_t)counter;
  s[13] = (uint32_t)(counter >> 32);
  s[14] = block_len;
  s[15] = flags;

  for (r = 0; r < 7; r++) {
    round_fn(s, m);
    if (r < 6) {
      uint32_t pm[16];
      for (i = 0; i < 16; i++) pm[i] = m[MSG_PERMUTATION[i]];
      memcpy(m, pm, sizeof(m));
    }
  }

  for (i = 0; i < 8; i++) {
    out[i]   = s[i] ^ s[i+8];
    out[i+8] = s[i+8] ^ cv[i];
  }
}

static void chunk_reset(rktcrypto_blake3_ctx_t *ctx, uint64_t chunk_counter)
{
  memcpy(ctx->cv, ctx->key, 8 * sizeof(uint32_t));
  ctx->block_len = 0;
  ctx->blocks_compressed = 0;
  ctx->chunk_counter = chunk_counter;
  memset(ctx->block, 0, 64);
}

void rktcrypto_blake3_core_init(rktcrypto_blake3_ctx_t *ctx)
{
  memcpy(ctx->key, BLAKE3_IV, 8 * sizeof(uint32_t));
  ctx->cv_stack_len = 0;
  chunk_reset(ctx, 0);
}

static uint32_t chunk_start_flag(const rktcrypto_blake3_ctx_t *ctx)
{
  return (ctx->blocks_compressed == 0) ? BLAKE3_CHUNK_START : 0;
}

static intptr_t chunk_len(const rktcrypto_blake3_ctx_t *ctx)
{
  return (intptr_t)ctx->blocks_compressed * 64 + ctx->block_len;
}

/* Compress the current full 64-byte block into the chunk's chaining
   value with no CHUNK_END; the chunk's final block is not compressed
   here but retained for the output step. */
static void chunk_compress_full_block(rktcrypto_blake3_ctx_t *ctx)
{
  uint32_t out[16];
  compress(ctx->cv, ctx->block, 64, ctx->chunk_counter,
           chunk_start_flag(ctx), out);
  memcpy(ctx->cv, out, 8 * sizeof(uint32_t));
  ctx->blocks_compressed++;
  ctx->block_len = 0;
  memset(ctx->block, 0, 64);
}

/* Compress the retained block with CHUNK_END to produce this chunk's
   chaining value, without disturbing ctx. */
static void chunk_output_cv(const rktcrypto_blake3_ctx_t *ctx, uint32_t cv_out[8])
{
  uint32_t out[16];
  uint32_t start = (ctx->blocks_compressed == 0) ? BLAKE3_CHUNK_START : 0;
  int i;
  compress(ctx->cv, ctx->block, ctx->block_len, ctx->chunk_counter,
           start | BLAKE3_CHUNK_END, out);
  for (i = 0; i < 8; i++) cv_out[i] = out[i];
}

/* Feed up to a chunk's worth of data, compressing only full,
   non-final blocks. */
static void chunk_state_update(rktcrypto_blake3_ctx_t *ctx,
                               const unsigned char *data, intptr_t len)
{
  while (len > 0) {
    if (ctx->block_len == 64) {
      chunk_compress_full_block(ctx);
    }
    {
      intptr_t want = 64 - ctx->block_len;
      intptr_t n = (want < len) ? want : len;
      memcpy(ctx->block + ctx->block_len, data, n);
      ctx->block_len = (uint8_t)(ctx->block_len + n);
      data += n;
      len -= n;
    }
  }
}

/* Merge the top two CVs on the stack into one parent CV. */
static void parent_cv(const uint32_t *left_right /* 16 words */,
                      const uint32_t key[8], uint32_t out[8])
{
  unsigned char block[64];
  uint32_t full[16];
  int i;
  for (i = 0; i < 8; i++) {
    uint32_t l = left_right[i], r = left_right[i+8];
    block[4*i]   = (unsigned char)l;         block[4*i+1] = (unsigned char)(l >> 8);
    block[4*i+2] = (unsigned char)(l >> 16); block[4*i+3] = (unsigned char)(l >> 24);
    block[4*i+32]   = (unsigned char)r;         block[4*i+33] = (unsigned char)(r >> 8);
    block[4*i+34] = (unsigned char)(r >> 16); block[4*i+35] = (unsigned char)(r >> 24);
  }
  compress(key, block, 64, 0, BLAKE3_PARENT, full);
  for (i = 0; i < 8; i++) out[i] = full[i];
}

static void push_cv(rktcrypto_blake3_ctx_t *ctx, const uint32_t cv[8], uint64_t total_chunks)
{
  /* Merge as many pending CVs as there are trailing zero bits in the
     completed-chunk count. */
  uint32_t merged[8];
  memcpy(merged, cv, 8 * sizeof(uint32_t));
  while ((total_chunks & 1) == 0) {
    uint32_t lr[16];
    memcpy(lr, &ctx->cv_stack[(ctx->cv_stack_len - 1) * 8], 8 * sizeof(uint32_t));
    memcpy(lr + 8, merged, 8 * sizeof(uint32_t));
    ctx->cv_stack_len--;
    parent_cv(lr, ctx->key, merged);
    total_chunks >>= 1;
  }
  memcpy(&ctx->cv_stack[ctx->cv_stack_len * 8], merged, 8 * sizeof(uint32_t));
  ctx->cv_stack_len++;
}

void rktcrypto_blake3_core_update(rktcrypto_blake3_ctx_t *ctx,
                                  const unsigned char *data, intptr_t len)
{
  while (len > 0) {
    /* If the current chunk is full (1024 bytes) and more data follows,
       finish it to a CV and start the next chunk. */
    if (chunk_len(ctx) == 1024) {
      uint32_t cv[8];
      chunk_output_cv(ctx, cv);
      push_cv(ctx, cv, ctx->chunk_counter + 1);
      chunk_reset(ctx, ctx->chunk_counter + 1);
    }
    {
      intptr_t room = 1024 - chunk_len(ctx);
      intptr_t take = (room < len) ? room : len;
      chunk_state_update(ctx, data, take);
      data += take;
      len -= take;
    }
  }
}

void rktcrypto_blake3_core_final(rktcrypto_blake3_ctx_t *ctx,
                                 unsigned char *out, intptr_t out_len)
{
  /* Determine the root compression inputs. If the whole input fit in
     one chunk (no CVs pushed), the root is that chunk's last block.
     Otherwise, fold the CV stack with the current chunk's CV to reach
     the root parent node. */
  uint32_t root_cv[8];
  unsigned char root_block[64];
  uint32_t root_block_len, root_flags;
  uint64_t root_counter = 0;
  int i;

  if (ctx->cv_stack_len == 0) {
    /* Single chunk: root is the final block of this chunk. */
    memcpy(root_cv, ctx->cv, 8 * sizeof(uint32_t));
    memcpy(root_block, ctx->block, 64);
    root_block_len = ctx->block_len;
    root_flags = chunk_start_flag(ctx) | BLAKE3_CHUNK_END;
  } else {
    /* Finish the current chunk to a CV, then merge down the stack. */
    uint32_t cur[8];
    uint32_t out16[16];
    compress(ctx->cv, ctx->block, ctx->block_len, ctx->chunk_counter,
             chunk_start_flag(ctx) | BLAKE3_CHUNK_END, out16);
    memcpy(cur, out16, 8 * sizeof(uint32_t));

    /* Fold all but the last parent merge, which becomes the root. */
    {
      int sp = ctx->cv_stack_len;
      while (sp > 1) {
        uint32_t lr[16];
        memcpy(lr, &ctx->cv_stack[(sp - 1) * 8], 8 * sizeof(uint32_t));
        memcpy(lr + 8, cur, 8 * sizeof(uint32_t));
        parent_cv(lr, ctx->key, cur);
        sp--;
      }
      /* Last merge is the root: left = cv_stack[0], right = cur. */
      {
        for (i = 0; i < 8; i++) {
          uint32_t l = ctx->cv_stack[i], r = cur[i];
          root_block[4*i]    = (unsigned char)l;         root_block[4*i+1]  = (unsigned char)(l >> 8);
          root_block[4*i+2]  = (unsigned char)(l >> 16); root_block[4*i+3]  = (unsigned char)(l >> 24);
          root_block[4*i+32] = (unsigned char)r;         root_block[4*i+33] = (unsigned char)(r >> 8);
          root_block[4*i+34] = (unsigned char)(r >> 16); root_block[4*i+35] = (unsigned char)(r >> 24);
        }
      }
      memcpy(root_cv, ctx->key, 8 * sizeof(uint32_t));
      root_block_len = 64;
      root_flags = BLAKE3_PARENT;
    }
  }

  /* Root output: XOF by incrementing the output-block counter. */
  {
    intptr_t pos = 0;
    uint64_t obc = 0;
    while (pos < out_len) {
      uint32_t words[16];
      unsigned char blk[64];
      intptr_t n;
      int j;
      compress(root_cv, root_block, root_block_len, root_counter + obc,
               root_flags | BLAKE3_ROOT, words);
      for (j = 0; j < 16; j++) {
        blk[4*j]   = (unsigned char)words[j];
        blk[4*j+1] = (unsigned char)(words[j] >> 8);
        blk[4*j+2] = (unsigned char)(words[j] >> 16);
        blk[4*j+3] = (unsigned char)(words[j] >> 24);
      }
      n = out_len - pos;
      if (n > 64) n = 64;
      memcpy(out + pos, blk, n);
      pos += n;
      obc++;
    }
  }
}
