#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zstd.h>

#include "asmp_zstd.h"

static int decode_check(const char *name,
                        const uint8_t *compressed,
                        uint64_t compressed_len,
                        const uint8_t *src,
                        size_t src_len) {
  size_t out_cap = src_len + 64;
  uint8_t *decoded = calloc(out_cap ? out_cap : 1, 1);
  if (!decoded) {
    fprintf(stderr, "%s: allocation failed\n", name);
    return 1;
  }

  size_t decoded_len =
      ZSTD_decompress(decoded, out_cap, compressed, (size_t)compressed_len);
  if (ZSTD_isError(decoded_len)) {
    fprintf(stderr, "%s: ZSTD_decompress failed: %s\n",
            name, ZSTD_getErrorName(decoded_len));
    free(decoded);
    return 1;
  }
  if (decoded_len != src_len ||
      (src_len != 0 && memcmp(decoded, src, src_len) != 0)) {
    fprintf(stderr, "%s: decoded mismatch, got %zu expected %zu\n",
            name, decoded_len, src_len);
    free(decoded);
    return 1;
  }

  free(decoded);
  return 0;
}

typedef uint64_t (*asmp_zstd_bound_fn)(uint64_t);
typedef int (*asmp_zstd_compress_fn)(uint8_t *,
                                     uint64_t,
                                     uint64_t *,
                                     const uint8_t *,
                                     uint64_t,
                                     void *,
                                     uint64_t);

static int roundtrip_codec(const char *codec,
                           const char *name,
                           const uint8_t *src,
                           size_t src_len,
                           asmp_zstd_bound_fn bound_fn,
                           asmp_zstd_compress_fn compress_fn) {
  uint64_t cap = bound_fn((uint64_t)src_len);
  uint8_t *compressed = calloc((size_t)cap ? (size_t)cap : 1, 1);
  if (!compressed) {
    fprintf(stderr, "%s/%s: allocation failed\n", codec, name);
    return 1;
  }

  uint64_t compressed_len = 0;
  int status = compress_fn(compressed, cap, &compressed_len,
                           src, (uint64_t)src_len, NULL, 0);
  if (status != ASMP_ZSTD_OK || compressed_len > cap) {
    fprintf(stderr, "%s/%s: status=%d compressed_len=%llu cap=%llu\n",
            codec, name, status,
            (unsigned long long)compressed_len,
            (unsigned long long)cap);
    free(compressed);
    return 1;
  }
  if (decode_check(name, compressed, compressed_len, src, src_len)) {
    free(compressed);
    return 1;
  }

  printf("%s/%s: %zu -> %llu bytes\n",
         codec, name, src_len, (unsigned long long)compressed_len);
  free(compressed);
  return 0;
}

static int expect_status(const char *name, int got, int expected) {
  if (got != expected) {
    fprintf(stderr, "%s: status=%d expected=%d\n", name, got, expected);
    return 1;
  }
  return 0;
}

static int status_checks(void) {
  static const uint8_t src[] = "status checks";
  uint64_t cap = asmp_zstd_compress_bound(sizeof(src) - 1);
  uint8_t *dst = calloc((size_t)cap, 1);
  if (!dst) {
    return 1;
  }

  int failed = 0;
  uint64_t out_len = 1234;
  failed |= expect_status("null-dst",
                          asmp_zstd_compress_default(NULL, cap, &out_len,
                                                     src, sizeof(src) - 1,
                                                     NULL, 0),
                          ASMP_ZSTD_BAD_ARGUMENT);
  failed |= expect_status("null-dst-len",
                          asmp_zstd_compress_default(dst, cap, NULL,
                                                     src, sizeof(src) - 1,
                                                     NULL, 0),
                          ASMP_ZSTD_BAD_ARGUMENT);
  failed |= expect_status("null-src-nonempty",
                          asmp_zstd_compress_default(dst, cap, &out_len,
                                                     NULL, sizeof(src) - 1,
                                                     NULL, 0),
                          ASMP_ZSTD_BAD_ARGUMENT);

  out_len = 1234;
  failed |= expect_status("small-dst",
                          asmp_zstd_compress_default(dst, cap - 1, &out_len,
                                                     src, sizeof(src) - 1,
                                                     NULL, 0),
                          ASMP_ZSTD_DST_TOO_SMALL);
  if (out_len != 0) {
    fprintf(stderr, "small-dst: dst_len=%llu expected 0\n",
            (unsigned long long)out_len);
    failed = 1;
  }

  out_len = 0;
  failed |= expect_status("empty-null-src",
                          asmp_zstd_compress_default(dst, cap, &out_len,
                                                     NULL, 0, NULL, 0),
                          ASMP_ZSTD_OK);
  failed |= decode_check("empty-null-src", dst, out_len, NULL, 0);

  free(dst);
  return failed;
}

int main(void) {
  static const uint8_t text[] =
      "asmp zstd01 writes standard frames before it tries to be clever";

  uint8_t repeated[70000];
  memset(repeated, 'A', sizeof(repeated));

  uint8_t small_repeat[16];
  memset(small_repeat, 'B', sizeof(small_repeat));

  uint8_t repeat36[36];
  memset(repeat36, 'C', sizeof(repeat36));

  uint8_t repeat200[200];
  memset(repeat200, 'D', sizeof(repeat200));

  uint8_t repeat260[260];
  memset(repeat260, 'E', sizeof(repeat260));

  uint8_t repeat_max[131072];
  memset(repeat_max, 'F', sizeof(repeat_max));

  static const uint8_t prefix_repeat[] =
      "abcdddddddddddddddddddddddddddddddddddddddddddddddddddd";

  static const uint8_t short_prefix_repeat[] = "abcddddddddddddddddd";

  static const uint8_t multi_runs[] = "AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHH";

  static const uint8_t multi_tokens[] = "abbbbcddddqrrrr";

  static const uint8_t token_tail[] = "abbbbcddddTAIL";

  static const uint8_t predef_seqstore[] = "aaaabcccc";

  uint8_t boundary[131073];
  for (size_t i = 0; i < sizeof(boundary); ++i) {
    boundary[i] = (uint8_t)(i * 131u + 17u);
  }

  uint8_t randomish[200000];
  uint32_t seed = 0x12345678u;
  for (size_t i = 0; i < sizeof(randomish); ++i) {
    seed = seed * 1664525u + 1013904223u;
    randomish[i] = (uint8_t)(seed >> 24);
  }

  int failed = 0;
  failed |= status_checks();
  failed |= roundtrip_codec("default", "empty", NULL, 0,
                            asmp_zstd_compress_bound,
                            asmp_zstd_compress_default);
  failed |= roundtrip_codec("default", "text", text, sizeof(text) - 1,
                            asmp_zstd_compress_bound,
                            asmp_zstd_compress_default);
  failed |= roundtrip_codec("default", "rle-70000", repeated,
                            sizeof(repeated),
                            asmp_zstd_compress_bound,
                            asmp_zstd_compress_default);
  failed |= roundtrip_codec("default", "boundary-131073", boundary,
                            sizeof(boundary),
                            asmp_zstd_compress_bound,
                            asmp_zstd_compress_default);
  failed |= roundtrip_codec("default", "randomish-200000", randomish,
                            sizeof(randomish),
                            asmp_zstd_compress_bound,
                            asmp_zstd_compress_default);

  failed |= roundtrip_codec("litonly", "empty", NULL, 0,
                            asmp_zstd_compress_litonly_bound,
                            asmp_zstd_compress_litonly);
  failed |= roundtrip_codec("litonly", "text", text, sizeof(text) - 1,
                            asmp_zstd_compress_litonly_bound,
                            asmp_zstd_compress_litonly);
  failed |= roundtrip_codec("litonly", "rle-70000", repeated,
                            sizeof(repeated),
                            asmp_zstd_compress_litonly_bound,
                            asmp_zstd_compress_litonly);
  failed |= roundtrip_codec("litonly", "boundary-131073", boundary,
                            sizeof(boundary),
                            asmp_zstd_compress_litonly_bound,
                            asmp_zstd_compress_litonly);
  failed |= roundtrip_codec("litonly", "randomish-200000", randomish,
                            sizeof(randomish),
                            asmp_zstd_compress_litonly_bound,
                            asmp_zstd_compress_litonly);

  failed |= roundtrip_codec("seqrle", "small-rle-16", small_repeat,
                            sizeof(small_repeat),
                            asmp_zstd_compress_seqrle_bound,
                            asmp_zstd_compress_seqrle);
  failed |= roundtrip_codec("seqrle", "text", text, sizeof(text) - 1,
                            asmp_zstd_compress_seqrle_bound,
                            asmp_zstd_compress_seqrle);
  failed |= roundtrip_codec("seqrle", "randomish-200000", randomish,
                            sizeof(randomish),
                            asmp_zstd_compress_seqrle_bound,
                            asmp_zstd_compress_seqrle);

  failed |= roundtrip_codec("seqrle-wide", "small-rle-16", small_repeat,
                            sizeof(small_repeat),
                            asmp_zstd_compress_seqrle_wide_bound,
                            asmp_zstd_compress_seqrle_wide);
  failed |= roundtrip_codec("seqrle-wide", "repeat-36", repeat36,
                            sizeof(repeat36),
                            asmp_zstd_compress_seqrle_wide_bound,
                            asmp_zstd_compress_seqrle_wide);
  failed |= roundtrip_codec("seqrle-wide", "repeat-200", repeat200,
                            sizeof(repeat200),
                            asmp_zstd_compress_seqrle_wide_bound,
                            asmp_zstd_compress_seqrle_wide);
  failed |= roundtrip_codec("seqrle-wide", "text", text, sizeof(text) - 1,
                            asmp_zstd_compress_seqrle_wide_bound,
                            asmp_zstd_compress_seqrle_wide);

  failed |= roundtrip_codec("seqrle-full", "small-rle-16", small_repeat,
                            sizeof(small_repeat),
                            asmp_zstd_compress_seqrle_full_bound,
                            asmp_zstd_compress_seqrle_full);
  failed |= roundtrip_codec("seqrle-full", "repeat-260", repeat260,
                            sizeof(repeat260),
                            asmp_zstd_compress_seqrle_full_bound,
                            asmp_zstd_compress_seqrle_full);
  failed |= roundtrip_codec("seqrle-full", "rle-70000", repeated,
                            sizeof(repeated),
                            asmp_zstd_compress_seqrle_full_bound,
                            asmp_zstd_compress_seqrle_full);
  failed |= roundtrip_codec("seqrle-full", "repeat-max-131072", repeat_max,
                            sizeof(repeat_max),
                            asmp_zstd_compress_seqrle_full_bound,
                            asmp_zstd_compress_seqrle_full);
  failed |= roundtrip_codec("seqrle-full", "text", text, sizeof(text) - 1,
                            asmp_zstd_compress_seqrle_full_bound,
                            asmp_zstd_compress_seqrle_full);
  failed |= roundtrip_codec("singlematch", "prefix-4-repeat",
                            prefix_repeat, sizeof(prefix_repeat) - 1,
                            asmp_zstd_compress_singlematch_bound,
                            asmp_zstd_compress_singlematch);
  failed |= roundtrip_codec("singlematch", "repeat-max-131072", repeat_max,
                            sizeof(repeat_max),
                            asmp_zstd_compress_singlematch_bound,
                            asmp_zstd_compress_singlematch);
  failed |= roundtrip_codec("singlematch", "text", text, sizeof(text) - 1,
                            asmp_zstd_compress_singlematch_bound,
                            asmp_zstd_compress_singlematch);
  failed |= roundtrip_codec("predef-singlematch", "short-prefix-4-repeat",
                            short_prefix_repeat,
                            sizeof(short_prefix_repeat) - 1,
                            asmp_zstd_compress_predef_singlematch_bound,
                            asmp_zstd_compress_predef_singlematch);
  failed |= roundtrip_codec("predef-singlematch", "repeat-max-131072",
                            repeat_max, sizeof(repeat_max),
                            asmp_zstd_compress_predef_singlematch_bound,
                            asmp_zstd_compress_predef_singlematch);
  failed |= roundtrip_codec("predef-singlematch", "text", text,
                            sizeof(text) - 1,
                            asmp_zstd_compress_predef_singlematch_bound,
                            asmp_zstd_compress_predef_singlematch);
  failed |= roundtrip_codec("multirle", "eight-runs", multi_runs,
                            sizeof(multi_runs) - 1,
                            asmp_zstd_compress_multirle_bound,
                            asmp_zstd_compress_multirle);
  failed |= roundtrip_codec("multirle", "short-prefix-4-repeat",
                            short_prefix_repeat,
                            sizeof(short_prefix_repeat) - 1,
                            asmp_zstd_compress_multirle_bound,
                            asmp_zstd_compress_multirle);
  failed |= roundtrip_codec("multirle", "text", text, sizeof(text) - 1,
                            asmp_zstd_compress_multirle_bound,
                            asmp_zstd_compress_multirle);
  failed |= roundtrip_codec("multitoken", "three-tokens", multi_tokens,
                            sizeof(multi_tokens) - 1,
                            asmp_zstd_compress_multitoken_bound,
                            asmp_zstd_compress_multitoken);
  failed |= roundtrip_codec("multitoken", "eight-runs", multi_runs,
                            sizeof(multi_runs) - 1,
                            asmp_zstd_compress_multitoken_bound,
                            asmp_zstd_compress_multitoken);
  failed |= roundtrip_codec("multitoken", "text", text, sizeof(text) - 1,
                            asmp_zstd_compress_multitoken_bound,
                            asmp_zstd_compress_multitoken);
  failed |= roundtrip_codec("multitoken-tail", "two-tokens-tail",
                            token_tail, sizeof(token_tail) - 1,
                            asmp_zstd_compress_multitoken_tail_bound,
                            asmp_zstd_compress_multitoken_tail);
  failed |= roundtrip_codec("multitoken-tail", "three-tokens", multi_tokens,
                            sizeof(multi_tokens) - 1,
                            asmp_zstd_compress_multitoken_tail_bound,
                            asmp_zstd_compress_multitoken_tail);
  failed |= roundtrip_codec("multitoken-tail", "text", text, sizeof(text) - 1,
                            asmp_zstd_compress_multitoken_tail_bound,
                            asmp_zstd_compress_multitoken_tail);
  failed |= roundtrip_codec("predef-seqstore", "two-seq-ll-1-2",
                            predef_seqstore,
                            sizeof(predef_seqstore) - 1,
                            asmp_zstd_compress_predef_seqstore_bound,
                            asmp_zstd_compress_predef_seqstore);
  failed |= roundtrip_codec("predef-seqstore", "two-tokens-tail",
                            token_tail, sizeof(token_tail) - 1,
                            asmp_zstd_compress_predef_seqstore_bound,
                            asmp_zstd_compress_predef_seqstore);
  failed |= roundtrip_codec("predef-seqstore", "text", text, sizeof(text) - 1,
                            asmp_zstd_compress_predef_seqstore_bound,
                            asmp_zstd_compress_predef_seqstore);
  return failed ? 1 : 0;
}
