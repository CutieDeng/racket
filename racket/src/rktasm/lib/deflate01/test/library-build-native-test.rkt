#lang racket

(require rackunit
         rackunit/text-ui
         racket/file
         racket/runtime-path
         racket/string
         racket/system)

(define-runtime-path build-source "../build.rkt")
(define-runtime-path raw-roundtrip-client-source
  "../c-examples/raw-roundtrip.c")

(define harness-source
  #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#include "asmp_deflate.h"

static int inflate_check(const char *name,
                         const uint8_t *compressed,
                         uint64_t clen,
                         const uint8_t *src,
                         size_t len) {
  uint8_t *decoded = calloc(len + 64, 1);
  if (!decoded) {
    return 1;
  }

  z_stream zs;
  memset(&zs, 0, sizeof(zs));
  int zr = inflateInit2(&zs, -MAX_WBITS);
  if (zr != Z_OK) {
    free(decoded);
    return 1;
  }
  zs.next_in = (Bytef *)compressed;
  zs.avail_in = (uInt)clen;
  zs.next_out = decoded;
  zs.avail_out = (uInt)(len + 64);
  zr = inflate(&zs, Z_FINISH);
  if (zr != Z_STREAM_END) {
    fprintf(stderr, "%s: inflate=%d total_out=%lu clen=%llu\n",
            name, zr, (unsigned long)zs.total_out,
            (unsigned long long)clen);
    inflateEnd(&zs);
    free(decoded);
    return 1;
  }
  inflateEnd(&zs);

  int failed = zs.total_out != len || memcmp(decoded, src, len) != 0;
  if (failed) {
    fprintf(stderr, "%s: decoded mismatch\n", name);
  }
  free(decoded);
  return failed;
}

typedef uint64_t (*asmp_bound_fn)(uint64_t);
typedef uint64_t (*asmp_scratch_size_fn)(void);
typedef int (*asmp_compress_fn)(uint8_t *,
                                uint64_t,
                                uint64_t *,
                                const uint8_t *,
                                uint64_t,
                                void *,
                                uint64_t);

static int roundtrip(const char *codec,
                     const char *name,
                     const uint8_t *src,
                     size_t len,
                     uint64_t expected_len,
                     asmp_bound_fn bound_fn,
                     asmp_scratch_size_fn scratch_size_fn,
                     asmp_compress_fn compress_fn) {
  uint64_t out_cap = bound_fn((uint64_t)len);
  uint64_t scratch_len = scratch_size_fn();
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !scratch) {
    fprintf(stderr, "%s/%s: allocation failed\n", codec, name);
    return 1;
  }

  uint64_t clen = 0;
  int status = compress_fn(compressed,
                           out_cap,
                           &clen,
                           src,
                           (uint64_t)len,
                           scratch,
                           scratch_len);
  if (status != ASMP_DEFLATE_OK || clen != expected_len) {
    fprintf(stderr, "%s/%s: status=%d clen=%llu expected=%llu\n",
            codec, name, status, (unsigned long long)clen,
            (unsigned long long)expected_len);
    free(compressed);
    free(scratch);
    return 1;
  }

  int failed = inflate_check(name, compressed, clen, src, len);
  printf("%s/%s: %zu -> %llu bytes\n",
         codec, name, len, (unsigned long long)clen);
  free(compressed);
  free(scratch);
  return failed;
}

static int roundtrip_any(const char *codec,
                         const char *name,
                         const uint8_t *src,
                         size_t len,
                         asmp_bound_fn bound_fn,
                         asmp_scratch_size_fn scratch_size_fn,
                         asmp_compress_fn compress_fn) {
  uint64_t out_cap = bound_fn((uint64_t)len);
  uint64_t scratch_len = scratch_size_fn();
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !scratch) {
    fprintf(stderr, "%s/%s: allocation failed\n", codec, name);
    return 1;
  }

  uint64_t clen = 0;
  int status = compress_fn(compressed,
                           out_cap,
                           &clen,
                           src,
                           (uint64_t)len,
                           scratch,
                           scratch_len);
  if (status != ASMP_DEFLATE_OK || clen > out_cap) {
    fprintf(stderr, "%s/%s: status=%d clen=%llu cap=%llu\n",
            codec, name, status, (unsigned long long)clen,
            (unsigned long long)out_cap);
    free(compressed);
    free(scratch);
    return 1;
  }

  int failed = inflate_check(name, compressed, clen, src, len);
  printf("%s/%s: %zu -> %llu bytes\n",
         codec, name, len, (unsigned long long)clen);
  free(compressed);
  free(scratch);
  return failed;
}

static int expect_status(const char *name, int got, int expected) {
  if (got != expected) {
    fprintf(stderr, "%s: status=%d expected=%d\n", name, got, expected);
    return 1;
  }
  return 0;
}

static int expect_u64(const char *name, uint64_t got, uint64_t expected) {
  if (got != expected) {
    fprintf(stderr, "%s: value=%llu expected=%llu\n",
            name, (unsigned long long)got, (unsigned long long)expected);
    return 1;
  }
  return 0;
}

static int blocked_dynamic_status_checks(void) {
  static const uint8_t src[] =
      "blocked dynamic status check blocked dynamic status check";
  static const uint8_t empty[] = "";
  uint64_t src_len = sizeof(src) - 1;
  uint64_t bound = asmp_deflate_raw_blocked_dynamic_auto_bound(src_len);
  uint64_t scratch_len = asmp_deflate_raw_blocked_dynamic_auto_scratch_size();
  uint8_t *dst = calloc((size_t)bound, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!dst || !scratch) {
    fprintf(stderr, "053-status: allocation failed\n");
    free(dst);
    free(scratch);
    return 1;
  }

  int failed = 0;
  uint64_t out_len = 1234;
  int status = asmp_deflate_raw_blocked_dynamic_auto(
      NULL, bound, &out_len, src, src_len, scratch, scratch_len);
  failed |= expect_status("053-status/null-dst",
                          status,
                          ASMP_DEFLATE_BAD_ARGUMENT);

  status = asmp_deflate_raw_blocked_dynamic_auto(
      dst, bound, NULL, src, src_len, scratch, scratch_len);
  failed |= expect_status("053-status/null-dst-len",
                          status,
                          ASMP_DEFLATE_BAD_ARGUMENT);

  out_len = 1234;
  status = asmp_deflate_raw_blocked_dynamic_auto(
      dst, bound, &out_len, NULL, src_len, scratch, scratch_len);
  failed |= expect_status("053-status/null-src-nonempty",
                          status,
                          ASMP_DEFLATE_BAD_ARGUMENT);

  out_len = 1234;
  status = asmp_deflate_raw_blocked_dynamic_auto(
      dst, bound, &out_len, src, src_len, NULL, scratch_len);
  failed |= expect_status("053-status/null-scratch",
                          status,
                          ASMP_DEFLATE_BAD_ARGUMENT);

  out_len = 1234;
  status = asmp_deflate_raw_blocked_dynamic_auto(
      dst, bound - 1, &out_len, src, src_len, scratch, scratch_len);
  failed |= expect_status("053-status/small-dst",
                          status,
                          ASMP_DEFLATE_DST_TOO_SMALL);
  failed |= expect_u64("053-status/small-dst-len", out_len, 0);

  out_len = 1234;
  status = asmp_deflate_raw_blocked_dynamic_auto(
      dst, bound, &out_len, src, src_len, scratch, scratch_len - 1);
  failed |= expect_status("053-status/small-scratch",
                          status,
                          ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  failed |= expect_u64("053-status/small-scratch-len", out_len, 0);

  memset(dst, 0, (size_t)bound);
  out_len = 1234;
  status = asmp_deflate_raw_blocked_dynamic_auto(
      dst, bound, &out_len, NULL, 0, scratch, scratch_len);
  failed |= expect_status("053-status/null-src-empty",
                          status,
                          ASMP_DEFLATE_OK);
  failed |= expect_u64("053-status/null-src-empty-len", out_len, 2);
  if (status == ASMP_DEFLATE_OK && out_len == 2) {
    failed |= inflate_check("053-status/null-src-empty", dst, out_len, empty, 0);
  }

  free(dst);
  free(scratch);
  return failed;
}

int main(void) {
  static const uint8_t empty[] = "";
  static const uint8_t small[] = "hello hello hello hello\n";
  static const uint8_t text[] =
      "asmp deflate hash chain test. asmp deflate hash chain test. "
      "fixed huffman, raw stream, bounded match finder.\n";

  static const uint8_t repeated_pattern[] = "abcabcabcXYZXYZXYZ0123456789";
  static uint8_t repeated[4096];
  for (size_t i = 0; i < sizeof(repeated); i++) {
    repeated[i] = repeated_pattern[i % (sizeof(repeated_pattern) - 1)];
  }

  static uint8_t long_repeat[70000];
  for (size_t i = 0; i < sizeof(long_repeat); i++) {
    long_repeat[i] = (uint8_t)("asmp-deflate-window-wrap-"[i % 25]);
  }

  static uint8_t high_literals[112];
  for (size_t i = 0; i < sizeof(high_literals); i++) {
    high_literals[i] = (uint8_t)(144u + i);
  }

  static uint8_t randomish[8192];
  uint32_t rng = 0x12345678u;
  for (size_t i = 0; i < sizeof(randomish); i++) {
    rng ^= rng << 13;
    rng ^= rng >> 17;
    rng ^= rng << 5;
    randomish[i] = (uint8_t)(rng >> 24);
  }

  static uint8_t random_long[70000];
  rng = 0x12345678u;
  for (size_t i = 0; i < sizeof(random_long); i++) {
    rng ^= rng << 13;
    rng ^= rng >> 17;
    rng ^= rng << 5;
    random_long[i] = (uint8_t)(rng >> 24);
  }

  int failed = 0;
  failed |= roundtrip("046", "small", small, sizeof(small) - 1, 10,
                      asmp_deflate_raw_auto_dynamic_probe_bound,
                      asmp_deflate_raw_auto_dynamic_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_probe);
  failed |= roundtrip("046", "text", text, sizeof(text) - 1, 74,
                      asmp_deflate_raw_auto_dynamic_probe_bound,
                      asmp_deflate_raw_auto_dynamic_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_probe);
  failed |= roundtrip("046", "repeated", repeated, sizeof(repeated), 48,
                      asmp_deflate_raw_auto_dynamic_probe_bound,
                      asmp_deflate_raw_auto_dynamic_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_probe);
  failed |= roundtrip("046", "high-literals",
                      high_literals, sizeof(high_literals), 114,
                      asmp_deflate_raw_auto_dynamic_probe_bound,
                      asmp_deflate_raw_auto_dynamic_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_probe);
  failed |= roundtrip("046", "randomish",
                      randomish, sizeof(randomish), 8225,
                      asmp_deflate_raw_auto_dynamic_probe_bound,
                      asmp_deflate_raw_auto_dynamic_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_probe);
  failed |= roundtrip("047", "small", small, sizeof(small) - 1, 10,
                      asmp_deflate_raw_auto_dynamic_cost_probe_bound,
                      asmp_deflate_raw_auto_dynamic_cost_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_cost_probe);
  failed |= roundtrip("047", "text", text, sizeof(text) - 1, 74,
                      asmp_deflate_raw_auto_dynamic_cost_probe_bound,
                      asmp_deflate_raw_auto_dynamic_cost_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_cost_probe);
  failed |= roundtrip("047", "repeated", repeated, sizeof(repeated), 48,
                      asmp_deflate_raw_auto_dynamic_cost_probe_bound,
                      asmp_deflate_raw_auto_dynamic_cost_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_cost_probe);
  failed |= roundtrip("047", "high-literals",
                      high_literals, sizeof(high_literals), 117,
                      asmp_deflate_raw_auto_dynamic_cost_probe_bound,
                      asmp_deflate_raw_auto_dynamic_cost_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_cost_probe);
  failed |= roundtrip("047", "randomish",
                      randomish, sizeof(randomish), 8197,
                      asmp_deflate_raw_auto_dynamic_cost_probe_bound,
                      asmp_deflate_raw_auto_dynamic_cost_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_cost_probe);
  failed |= roundtrip("048", "small", small, sizeof(small) - 1, 10,
                      asmp_deflate_raw_auto_dynamic_size_probe_bound,
                      asmp_deflate_raw_auto_dynamic_size_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_size_probe);
  failed |= roundtrip("048", "text", text, sizeof(text) - 1, 74,
                      asmp_deflate_raw_auto_dynamic_size_probe_bound,
                      asmp_deflate_raw_auto_dynamic_size_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_size_probe);
  failed |= roundtrip("048", "repeated", repeated, sizeof(repeated), 48,
                      asmp_deflate_raw_auto_dynamic_size_probe_bound,
                      asmp_deflate_raw_auto_dynamic_size_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_size_probe);
  failed |= roundtrip("048", "high-literals",
                      high_literals, sizeof(high_literals), 114,
                      asmp_deflate_raw_auto_dynamic_size_probe_bound,
                      asmp_deflate_raw_auto_dynamic_size_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_size_probe);
  failed |= roundtrip("048", "randomish",
                      randomish, sizeof(randomish), 8197,
                      asmp_deflate_raw_auto_dynamic_size_probe_bound,
                      asmp_deflate_raw_auto_dynamic_size_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_size_probe);
  failed |= roundtrip("049", "small", small, sizeof(small) - 1, 10,
                      asmp_deflate_raw_auto_dynamic_prepared_size_probe_bound,
                      asmp_deflate_raw_auto_dynamic_prepared_size_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_prepared_size_probe);
  failed |= roundtrip("049", "text", text, sizeof(text) - 1, 74,
                      asmp_deflate_raw_auto_dynamic_prepared_size_probe_bound,
                      asmp_deflate_raw_auto_dynamic_prepared_size_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_prepared_size_probe);
  failed |= roundtrip("049", "repeated", repeated, sizeof(repeated), 48,
                      asmp_deflate_raw_auto_dynamic_prepared_size_probe_bound,
                      asmp_deflate_raw_auto_dynamic_prepared_size_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_prepared_size_probe);
  failed |= roundtrip("049", "high-literals",
                      high_literals, sizeof(high_literals), 114,
                      asmp_deflate_raw_auto_dynamic_prepared_size_probe_bound,
                      asmp_deflate_raw_auto_dynamic_prepared_size_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_prepared_size_probe);
  failed |= roundtrip("049", "randomish",
                      randomish, sizeof(randomish), 8197,
                      asmp_deflate_raw_auto_dynamic_prepared_size_probe_bound,
                      asmp_deflate_raw_auto_dynamic_prepared_size_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_prepared_size_probe);
  failed |= roundtrip("050", "small", small, sizeof(small) - 1, 10,
                      asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_bound,
                      asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe);
  failed |= roundtrip("050", "text", text, sizeof(text) - 1, 74,
                      asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_bound,
                      asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe);
  failed |= roundtrip("050", "repeated", repeated, sizeof(repeated), 48,
                      asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_bound,
                      asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe);
  failed |= roundtrip("050", "high-literals",
                      high_literals, sizeof(high_literals), 114,
                      asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_bound,
                      asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe);
  failed |= roundtrip("050", "randomish",
                      randomish, sizeof(randomish), 8197,
                      asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_bound,
                      asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_scratch_size,
                      asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe);
  failed |= roundtrip("051", "empty", empty, 0, 2,
                      asmp_deflate_raw_blocked_fixed_bound,
                      asmp_deflate_raw_blocked_fixed_scratch_size,
                      asmp_deflate_raw_blocked_fixed);
  failed |= roundtrip("051", "small", small, sizeof(small) - 1, 10,
                      asmp_deflate_raw_blocked_fixed_bound,
                      asmp_deflate_raw_blocked_fixed_scratch_size,
                      asmp_deflate_raw_blocked_fixed);
  failed |= roundtrip("051", "repeated", repeated, sizeof(repeated), 53,
                      asmp_deflate_raw_blocked_fixed_bound,
                      asmp_deflate_raw_blocked_fixed_scratch_size,
                      asmp_deflate_raw_blocked_fixed);
  failed |= roundtrip("051", "boundary-32769",
                      long_repeat, 32769, 284,
                      asmp_deflate_raw_blocked_fixed_bound,
                      asmp_deflate_raw_blocked_fixed_scratch_size,
                      asmp_deflate_raw_blocked_fixed);
  failed |= roundtrip("051", "long-repeat",
                      long_repeat, sizeof(long_repeat), 625,
                      asmp_deflate_raw_blocked_fixed_bound,
                      asmp_deflate_raw_blocked_fixed_scratch_size,
                      asmp_deflate_raw_blocked_fixed);
  failed |= roundtrip("051", "random-long",
                      random_long, sizeof(random_long), 73855,
                      asmp_deflate_raw_blocked_fixed_bound,
                      asmp_deflate_raw_blocked_fixed_scratch_size,
                      asmp_deflate_raw_blocked_fixed);
  failed |= roundtrip("052", "empty", empty, 0, 2,
                      asmp_deflate_raw_blocked_auto_bound,
                      asmp_deflate_raw_blocked_auto_scratch_size,
                      asmp_deflate_raw_blocked_auto);
  failed |= roundtrip("052", "small", small, sizeof(small) - 1, 10,
                      asmp_deflate_raw_blocked_auto_bound,
                      asmp_deflate_raw_blocked_auto_scratch_size,
                      asmp_deflate_raw_blocked_auto);
  failed |= roundtrip("052", "high-literals",
                      high_literals, sizeof(high_literals), 117,
                      asmp_deflate_raw_blocked_auto_bound,
                      asmp_deflate_raw_blocked_auto_scratch_size,
                      asmp_deflate_raw_blocked_auto);
  failed |= roundtrip("052", "boundary-32769",
                      long_repeat, 32769, 284,
                      asmp_deflate_raw_blocked_auto_bound,
                      asmp_deflate_raw_blocked_auto_scratch_size,
                      asmp_deflate_raw_blocked_auto);
  failed |= roundtrip("052", "long-repeat",
                      long_repeat, sizeof(long_repeat), 625,
                      asmp_deflate_raw_blocked_auto_bound,
                      asmp_deflate_raw_blocked_auto_scratch_size,
                      asmp_deflate_raw_blocked_auto);
  failed |= roundtrip("052", "random-long",
                      random_long, sizeof(random_long), 70015,
                      asmp_deflate_raw_blocked_auto_bound,
                      asmp_deflate_raw_blocked_auto_scratch_size,
                      asmp_deflate_raw_blocked_auto);
  failed |= roundtrip("053", "empty", empty, 0, 2,
                      asmp_deflate_raw_blocked_dynamic_auto_bound,
                      asmp_deflate_raw_blocked_dynamic_auto_scratch_size,
                      asmp_deflate_raw_blocked_dynamic_auto);
  failed |= roundtrip("053", "small", small, sizeof(small) - 1, 10,
                      asmp_deflate_raw_blocked_dynamic_auto_bound,
                      asmp_deflate_raw_blocked_dynamic_auto_scratch_size,
                      asmp_deflate_raw_blocked_dynamic_auto);
  failed |= roundtrip("053", "high-literals",
                      high_literals, sizeof(high_literals), 114,
                      asmp_deflate_raw_blocked_dynamic_auto_bound,
                      asmp_deflate_raw_blocked_dynamic_auto_scratch_size,
                      asmp_deflate_raw_blocked_dynamic_auto);
  failed |= roundtrip("053", "boundary-32769",
                      long_repeat, 32769, 123,
                      asmp_deflate_raw_blocked_dynamic_auto_bound,
                      asmp_deflate_raw_blocked_dynamic_auto_scratch_size,
                      asmp_deflate_raw_blocked_dynamic_auto);
  failed |= roundtrip("053", "long-repeat",
                      long_repeat, sizeof(long_repeat), 295,
                      asmp_deflate_raw_blocked_dynamic_auto_bound,
                      asmp_deflate_raw_blocked_dynamic_auto_scratch_size,
                      asmp_deflate_raw_blocked_dynamic_auto);
  failed |= roundtrip("053", "random-long",
                      random_long, sizeof(random_long), 70015,
                      asmp_deflate_raw_blocked_dynamic_auto_bound,
                      asmp_deflate_raw_blocked_dynamic_auto_scratch_size,
                      asmp_deflate_raw_blocked_dynamic_auto);
  failed |= blocked_dynamic_status_checks();

  static uint8_t fuzz[100000];
  rng = 0x9e3779b9u;
  for (size_t i = 0; i < sizeof(fuzz); i++) {
    rng ^= rng << 13;
    rng ^= rng >> 17;
    rng ^= rng << 5;
    fuzz[i] = (i % 251u < 180u)
        ? (uint8_t)("blocked-dynamic-auto-"[i % 21u])
        : (uint8_t)(rng >> 24);
  }
  static const size_t fuzz_lens[] = {
      1, 3, 4, 95, 96, 511, 512, 32768, 32769, 65535, 65536, 100000
  };
  for (size_t i = 0; i < sizeof(fuzz_lens) / sizeof(fuzz_lens[0]); i++) {
    char name[32];
    snprintf(name, sizeof(name), "len-%zu", fuzz_lens[i]);
    failed |= roundtrip_any("053-fuzz",
                            name,
                            fuzz,
                            fuzz_lens[i],
                            asmp_deflate_raw_blocked_dynamic_auto_bound,
                            asmp_deflate_raw_blocked_dynamic_auto_scratch_size,
                            asmp_deflate_raw_blocked_dynamic_auto);
  }
  return failed ? 1 : 0;
}
C
  )

(define (native-macos-aarch64?)
  (and (eq? (system-type 'os) 'macosx)
       (eq? (system-type 'arch) 'aarch64)))

(define (run-command exe . args)
  (define ok? (apply system* exe args))
  (unless ok?
    (error 'deflate-library-build-native-test
           "command failed: ~a ~a"
           exe
           args)))

(define (capture-command/env env exe . args)
  (define-values (proc out in err)
    (parameterize ([current-environment-variables env])
      (apply subprocess #f #f #f exe args)))
  (close-output-port in)
  (define stdout (port->string out))
  (define stderr (port->string err))
  (subprocess-wait proc)
  (define status (subprocess-status proc))
  (unless (zero? status)
    (display stdout)
    (display stderr (current-error-port))
    (error 'deflate-library-build-native-test
           "command failed: ~a ~a"
           exe
           args))
  stdout)

(define (pkg-config-flags env . args)
  (filter (lambda (part) (not (string=? part "")))
          (string-split
           (string-trim
            (apply capture-command/env env
                   (find-executable-path "pkg-config")
                   args)))))

(define (tool-available? name)
  (and (find-executable-path name) #t))

(define deflate-library-build-native-tests
  (test-suite
   "native deflate static library build"
   (test-case "builds a static library and links a C raw-deflate client"
     (cond
       [(not (native-macos-aarch64?))
        (printf "skip native deflate library build: host is ~a/~a\n"
                (system-type 'os)
                (system-type 'arch))]
       [(not (and (tool-available? "racket")
                  (tool-available? "clang")
                  (tool-available? "ar")
                  (tool-available? "ranlib")))
        (printf "skip native deflate library build: missing build tool\n")]
       [else
        (define dir (make-temporary-file "asmp-deflate-library-~a" 'directory))
        (dynamic-wind
          void
          (lambda ()
            (define build-dir (build-path dir "build"))
            (define install-dir (build-path dir "install"))
            (run-command (find-executable-path "racket")
                         build-source
                         "--out-dir"
                         build-dir
                         "--prefix"
                         install-dir
                         "--install")
            (define harness-path (build-path dir "library-client.c"))
            (define exe-path (build-path dir "library-client"))
            (define include-dir (build-path install-dir "include"))
            (define library-path
              (build-path install-dir "lib" "libasmp_deflate.a"))
            (define pc-path
              (build-path install-dir "lib" "pkgconfig" "asmp-deflate.pc"))
            (check-true (file-exists? library-path))
            (check-true (file-exists? (build-path include-dir "asmp_deflate.h")))
            (check-true (file-exists? pc-path))
            (call-with-output-file harness-path
              #:exists 'truncate/replace
              (lambda (out) (display harness-source out)))
            (run-command (find-executable-path "clang")
                         harness-path
                         library-path
                         "-I"
                         include-dir
                         "-lz"
                         "-o"
                         exe-path)
            (run-command exe-path)
            (define sample-exe-path (build-path dir "raw-roundtrip-client"))
            (run-command (find-executable-path "clang")
                         raw-roundtrip-client-source
                         library-path
                         "-I"
                         include-dir
                         "-lz"
                         "-o"
                         sample-exe-path)
            (run-command sample-exe-path)
            (when (tool-available? "pkg-config")
              (define pkg-env
                (environment-variables-copy (current-environment-variables)))
              (environment-variables-set!
               pkg-env
               #"PKG_CONFIG_PATH"
               (string->bytes/utf-8
                (path->string (build-path install-dir "lib" "pkgconfig"))))
              (define pkg-exe-path (build-path dir "raw-roundtrip-pkg-client"))
              (apply run-command
                     (find-executable-path "clang")
                     (append
                      (list raw-roundtrip-client-source "-o" pkg-exe-path)
                      (pkg-config-flags pkg-env "--cflags" "asmp-deflate")
                      (pkg-config-flags pkg-env "--libs" "asmp-deflate")))
              (run-command pkg-exe-path)))
          (lambda () (delete-directory/files dir)))]))))

(module+ test
  (void (run-tests deflate-library-build-native-tests)))

(module+ main
  (void (run-tests deflate-library-build-native-tests)))
