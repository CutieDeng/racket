#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#include "asmp_deflate.h"

typedef uint64_t (*bound_fn)(uint64_t);
typedef uint64_t (*scratch_size_fn)(void);
typedef int (*compress_fn)(uint8_t *,
                           uint64_t,
                           uint64_t *,
                           const uint8_t *,
                           uint64_t,
                           void *,
                           uint64_t);

static const char *status_name(int status) {
  switch (status) {
  case ASMP_DEFLATE_OK:
    return "ASMP_DEFLATE_OK";
  case ASMP_DEFLATE_DST_TOO_SMALL:
    return "ASMP_DEFLATE_DST_TOO_SMALL";
  case ASMP_DEFLATE_SCRATCH_TOO_SMALL:
    return "ASMP_DEFLATE_SCRATCH_TOO_SMALL";
  case ASMP_DEFLATE_BAD_ARGUMENT:
    return "ASMP_DEFLATE_BAD_ARGUMENT";
  default:
    return "ASMP_DEFLATE_UNKNOWN";
  }
}

static int inflate_check(const char *label,
                         const uint8_t *compressed,
                         uint64_t compressed_len,
                         const uint8_t *src,
                         size_t src_len) {
  uint8_t *decoded = calloc(src_len + 64, 1);
  if (!decoded) {
    fprintf(stderr, "%s: allocation failed\n", label);
    return 1;
  }

  z_stream zs;
  memset(&zs, 0, sizeof(zs));
  int zr = inflateInit2(&zs, -MAX_WBITS);
  if (zr != Z_OK) {
    fprintf(stderr, "%s: inflateInit2 failed: %d\n", label, zr);
    free(decoded);
    return 1;
  }

  zs.next_in = (Bytef *)compressed;
  zs.avail_in = (uInt)compressed_len;
  zs.next_out = decoded;
  zs.avail_out = (uInt)(src_len + 64);
  zr = inflate(&zs, Z_FINISH);
  int failed = 0;
  if (zr != Z_STREAM_END) {
    fprintf(stderr, "%s: inflate failed: %d\n", label, zr);
    failed = 1;
  } else if (zs.total_out != src_len || memcmp(decoded, src, src_len) != 0) {
    fprintf(stderr, "%s: decoded bytes differ\n", label);
    failed = 1;
  }

  inflateEnd(&zs);
  free(decoded);
  return failed;
}

static int run_codec(const char *label,
                     const uint8_t *src,
                     size_t src_len,
                     bound_fn bound,
                     scratch_size_fn scratch_size,
                     compress_fn compress) {
  uint64_t dst_cap = bound((uint64_t)src_len);
  uint64_t scratch_len = scratch_size();
  uint8_t *dst = calloc((size_t)dst_cap, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!dst || !scratch) {
    fprintf(stderr, "%s: allocation failed\n", label);
    free(dst);
    free(scratch);
    return 1;
  }

  uint64_t dst_len = 0;
  int status = compress(dst,
                        dst_cap,
                        &dst_len,
                        src,
                        (uint64_t)src_len,
                        scratch,
                        scratch_len);
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: compression failed: %s\n", label, status_name(status));
    free(dst);
    free(scratch);
    return 1;
  }
  if (dst_len > dst_cap) {
    fprintf(stderr, "%s: output length exceeds bound\n", label);
    free(dst);
    free(scratch);
    return 1;
  }

  int failed = inflate_check(label, dst, dst_len, src, src_len);
  if (!failed) {
    printf("%s: %zu -> %llu bytes\n",
           label, src_len, (unsigned long long)dst_len);
  }

  free(dst);
  free(scratch);
  return failed;
}

int main(void) {
  static const uint8_t small[] = "hello hello hello hello\n";
  static uint8_t repeated[70000];
  static const char pattern[] = "asmp-deflate-library-client-";

  for (size_t i = 0; i < sizeof(repeated); i++) {
    repeated[i] = (uint8_t)pattern[i % (sizeof(pattern) - 1)];
  }

  int failed = 0;
  failed |= run_codec("stable-auto/small",
                      small,
                      sizeof(small) - 1,
                      asmp_deflate_raw_bound,
                      asmp_deflate_raw_scratch_size,
                      asmp_deflate_raw_auto);
  failed |= run_codec("blocked-dynamic/repeated",
                      repeated,
                      sizeof(repeated),
                      asmp_deflate_raw_blocked_dynamic_auto_bound,
                      asmp_deflate_raw_blocked_dynamic_auto_scratch_size,
                      asmp_deflate_raw_blocked_dynamic_auto);
  return failed ? 1 : 0;
}
