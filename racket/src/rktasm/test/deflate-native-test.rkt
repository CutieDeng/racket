#lang racket

(require rackunit
         rackunit/text-ui
         racket/runtime-path
         racket/file
         "../cli/as.rkt")            ; in-process 汇编 (assemble)

(define-runtime-path deflate-chain-source "../example/019-deflate-fixed-chain.asm")

(define harness-source
  #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#include "asmp_deflate.h"

enum {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_DST_TOO_SMALL = 1,
  ASMP_DEFLATE_SCRATCH_TOO_SMALL = 2,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};

static int roundtrip(const char *name,
                     const uint8_t *src,
                     size_t len,
                     uint64_t max_expected_len) {
  size_t out_cap = (size_t)asmp_deflate_raw_bound((uint64_t)len);
  size_t dec_cap = len + 64;
  uint8_t *compressed = calloc(out_cap, 1);
  uint8_t *decoded = calloc(dec_cap, 1);
  uint64_t scratch_len = asmp_deflate_raw_scratch_size();
  void *scratch = calloc(1, (size_t)scratch_len);
  if (!compressed || !decoded || !scratch) {
    fprintf(stderr, "%s: allocation failed\n", name);
    return 1;
  }

  uint64_t clen = 0;
  int status = asmp_deflate_raw_fixed(compressed,
                                      (uint64_t)out_cap,
                                      &clen,
                                      src,
                                      (uint64_t)len,
                                      scratch,
                                      scratch_len);
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: wrapper failed status=%d clen=%llu\n", name, status,
            (unsigned long long)clen);
    return 1;
  }
  if (clen == 0 || clen > out_cap) {
    fprintf(stderr, "%s: suspicious compressed size %llu\n", name,
            (unsigned long long)clen);
    return 1;
  }
  if (max_expected_len != 0 && clen > max_expected_len) {
    fprintf(stderr, "%s: compressed size %llu exceeds expected ceiling %llu\n",
            name, (unsigned long long)clen,
            (unsigned long long)max_expected_len);
    return 1;
  }

  z_stream zs;
  memset(&zs, 0, sizeof(zs));
  int zr = inflateInit2(&zs, -MAX_WBITS);
  if (zr != Z_OK) {
    fprintf(stderr, "%s: inflateInit2 failed: %d\n", name, zr);
    return 1;
  }

  zs.next_in = compressed;
  zs.avail_in = (uInt)clen;
  zs.next_out = decoded;
  zs.avail_out = (uInt)dec_cap;
  zr = inflate(&zs, Z_FINISH);
  if (zr != Z_STREAM_END) {
    fprintf(stderr, "%s: inflate failed: %d total_out=%lu total_in=%lu clen=%llu\n",
            name, zr, (unsigned long)zs.total_out, (unsigned long)zs.total_in,
            (unsigned long long)clen);
    inflateEnd(&zs);
    return 1;
  }
  inflateEnd(&zs);

  if (zs.total_out != len || memcmp(decoded, src, len) != 0) {
    fprintf(stderr, "%s: mismatch total_out=%lu expected=%zu clen=%llu\n",
            name, (unsigned long)zs.total_out, len, (unsigned long long)clen);
    return 1;
  }

  printf("%s: %zu -> %llu bytes\n", name, len, (unsigned long long)clen);
  free(compressed);
  free(decoded);
  free(scratch);
  return 0;
}

static uint64_t stored_expected_len(size_t len) {
  uint64_t blocks = ((uint64_t)len + 65534ull) / 65535ull;
  if (blocks == 0) {
    blocks = 1;
  }
  return (uint64_t)len + blocks * 5ull;
}

static int stored_roundtrip(const char *name,
                            const uint8_t *src,
                            size_t len) {
  size_t out_cap = (size_t)asmp_deflate_raw_bound((uint64_t)len);
  size_t dec_cap = len + 64;
  uint8_t *compressed = calloc(out_cap, 1);
  uint8_t *decoded = calloc(dec_cap, 1);
  if (!compressed || !decoded) {
    fprintf(stderr, "%s/stored: allocation failed\n", name);
    return 1;
  }

  uint64_t clen = 0;
  int status = asmp_deflate_raw_stored(compressed,
                                       (uint64_t)out_cap,
                                       &clen,
                                       src,
                                       (uint64_t)len);
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s/stored: wrapper failed status=%d clen=%llu\n", name, status,
            (unsigned long long)clen);
    return 1;
  }

  uint64_t expected_len = stored_expected_len(len);
  if (clen != expected_len) {
    fprintf(stderr, "%s/stored: compressed size %llu expected %llu\n",
            name, (unsigned long long)clen, (unsigned long long)expected_len);
    return 1;
  }

  z_stream zs;
  memset(&zs, 0, sizeof(zs));
  int zr = inflateInit2(&zs, -MAX_WBITS);
  if (zr != Z_OK) {
    fprintf(stderr, "%s/stored: inflateInit2 failed: %d\n", name, zr);
    return 1;
  }

  zs.next_in = compressed;
  zs.avail_in = (uInt)clen;
  zs.next_out = decoded;
  zs.avail_out = (uInt)dec_cap;
  zr = inflate(&zs, Z_FINISH);
  if (zr != Z_STREAM_END) {
    fprintf(stderr, "%s/stored: inflate failed: %d total_out=%lu total_in=%lu clen=%llu\n",
            name, zr, (unsigned long)zs.total_out, (unsigned long)zs.total_in,
            (unsigned long long)clen);
    inflateEnd(&zs);
    return 1;
  }
  inflateEnd(&zs);

  if (zs.total_out != len || memcmp(decoded, src, len) != 0) {
    fprintf(stderr, "%s/stored: mismatch total_out=%lu expected=%zu clen=%llu\n",
            name, (unsigned long)zs.total_out, len, (unsigned long long)clen);
    return 1;
  }

  printf("%s/stored: %zu -> %llu bytes\n", name, len, (unsigned long long)clen);
  free(compressed);
  free(decoded);
  return 0;
}

static int auto_roundtrip(const char *name,
                          const uint8_t *src,
                          size_t len,
                          uint64_t expected_len) {
  size_t out_cap = (size_t)asmp_deflate_raw_bound((uint64_t)len);
  size_t dec_cap = len + 64;
  uint8_t *compressed = calloc(out_cap, 1);
  uint8_t *decoded = calloc(dec_cap, 1);
  uint64_t scratch_len = asmp_deflate_raw_scratch_size();
  void *scratch = calloc(1, (size_t)scratch_len);
  if (!compressed || !decoded || !scratch) {
    fprintf(stderr, "%s/auto: allocation failed\n", name);
    return 1;
  }

  uint64_t clen = 0;
  int status = asmp_deflate_raw_auto(compressed,
                                     (uint64_t)out_cap,
                                     &clen,
                                     src,
                                     (uint64_t)len,
                                     scratch,
                                     scratch_len);
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s/auto: wrapper failed status=%d clen=%llu\n", name, status,
            (unsigned long long)clen);
    return 1;
  }
  if (clen == 0 || clen > out_cap) {
    fprintf(stderr, "%s/auto: suspicious compressed size %llu\n", name,
            (unsigned long long)clen);
    return 1;
  }
  if (expected_len != 0 && clen != expected_len) {
    fprintf(stderr, "%s/auto: compressed size %llu expected %llu\n",
            name, (unsigned long long)clen, (unsigned long long)expected_len);
    return 1;
  }

  z_stream zs;
  memset(&zs, 0, sizeof(zs));
  int zr = inflateInit2(&zs, -MAX_WBITS);
  if (zr != Z_OK) {
    fprintf(stderr, "%s/auto: inflateInit2 failed: %d\n", name, zr);
    return 1;
  }

  zs.next_in = compressed;
  zs.avail_in = (uInt)clen;
  zs.next_out = decoded;
  zs.avail_out = (uInt)dec_cap;
  zr = inflate(&zs, Z_FINISH);
  if (zr != Z_STREAM_END) {
    fprintf(stderr, "%s/auto: inflate failed: %d total_out=%lu total_in=%lu clen=%llu\n",
            name, zr, (unsigned long)zs.total_out, (unsigned long)zs.total_in,
            (unsigned long long)clen);
    inflateEnd(&zs);
    return 1;
  }
  inflateEnd(&zs);

  if (zs.total_out != len || memcmp(decoded, src, len) != 0) {
    fprintf(stderr, "%s/auto: mismatch total_out=%lu expected=%zu clen=%llu\n",
            name, (unsigned long)zs.total_out, len, (unsigned long long)clen);
    return 1;
  }

  printf("%s/auto: %zu -> %llu bytes\n", name, len, (unsigned long long)clen);
  free(compressed);
  free(decoded);
  free(scratch);
  return 0;
}

static int expect_status(const char *name, int got, int expected, uint64_t got_len) {
  if (got != expected) {
    fprintf(stderr, "%s: status=%d expected=%d len=%llu\n",
            name, got, expected, (unsigned long long)got_len);
    return 1;
  }
  return 0;
}

static int status_checks(void) {
  static const uint8_t src[] = "status-check-input";
  uint64_t src_len = sizeof(src) - 1;
  uint64_t bound = asmp_deflate_raw_bound(src_len);
  uint64_t scratch_len = asmp_deflate_raw_scratch_size();
  uint8_t *dst = calloc((size_t)bound, 1);
  void *scratch = calloc(1, (size_t)scratch_len);
  if (!dst || !scratch) {
    fprintf(stderr, "status: allocation failed\n");
    return 1;
  }

  uint64_t out_len = 99;
  int failed = 0;
  int status = asmp_deflate_raw_fixed(NULL, bound, &out_len, src, src_len,
                                      scratch, scratch_len);
  failed |= expect_status("bad-dst", status, ASMP_DEFLATE_BAD_ARGUMENT, out_len);

  out_len = 99;
  status = asmp_deflate_raw_fixed(dst, 1, &out_len, src, src_len,
                                  scratch, scratch_len);
  failed |= expect_status("small-dst", status, ASMP_DEFLATE_DST_TOO_SMALL, out_len);
  if (out_len != 0) {
    fprintf(stderr, "small-dst: expected len reset to 0, got %llu\n",
            (unsigned long long)out_len);
    failed = 1;
  }

  out_len = 99;
  status = asmp_deflate_raw_fixed(dst, bound, &out_len, src, src_len,
                                  scratch, 16);
  failed |= expect_status("small-scratch", status,
                          ASMP_DEFLATE_SCRATCH_TOO_SMALL, out_len);
  if (out_len != 0) {
    fprintf(stderr, "small-scratch: expected len reset to 0, got %llu\n",
            (unsigned long long)out_len);
    failed = 1;
  }

  out_len = 99;
  status = asmp_deflate_raw_fixed(dst, bound, &out_len, NULL, src_len,
                                  scratch, scratch_len);
  failed |= expect_status("bad-src", status, ASMP_DEFLATE_BAD_ARGUMENT, out_len);

  out_len = 99;
  status = asmp_deflate_raw_fixed(dst, bound, &out_len, NULL, 0,
                                  scratch, scratch_len);
  failed |= expect_status("empty-null-src", status, ASMP_DEFLATE_OK, out_len);
  if (out_len != 2) {
    fprintf(stderr, "empty-null-src: expected len 2, got %llu\n",
            (unsigned long long)out_len);
    failed = 1;
  }

  free(dst);
  free(scratch);
  return failed;
}

static int stored_status_checks(void) {
  static const uint8_t src[] = "status-check-input";
  uint64_t src_len = sizeof(src) - 1;
  uint64_t bound = asmp_deflate_raw_bound(src_len);
  uint8_t *dst = calloc((size_t)bound, 1);
  if (!dst) {
    fprintf(stderr, "stored-status: allocation failed\n");
    return 1;
  }

  uint64_t out_len = 99;
  int failed = 0;
  int status = asmp_deflate_raw_stored(NULL, bound, &out_len, src, src_len);
  failed |= expect_status("stored-bad-dst", status, ASMP_DEFLATE_BAD_ARGUMENT, out_len);

  out_len = 99;
  status = asmp_deflate_raw_stored(dst, 1, &out_len, src, src_len);
  failed |= expect_status("stored-small-dst", status, ASMP_DEFLATE_DST_TOO_SMALL, out_len);
  if (out_len != 0) {
    fprintf(stderr, "stored-small-dst: expected len reset to 0, got %llu\n",
            (unsigned long long)out_len);
    failed = 1;
  }

  out_len = 99;
  status = asmp_deflate_raw_stored(dst, bound, &out_len, NULL, src_len);
  failed |= expect_status("stored-bad-src", status, ASMP_DEFLATE_BAD_ARGUMENT, out_len);

  out_len = 99;
  status = asmp_deflate_raw_stored(dst, bound, &out_len, NULL, 0);
  failed |= expect_status("stored-empty-null-src", status, ASMP_DEFLATE_OK, out_len);
  if (out_len != 5) {
    fprintf(stderr, "stored-empty-null-src: expected len 5, got %llu\n",
            (unsigned long long)out_len);
    failed = 1;
  }

  free(dst);
  return failed;
}

static int auto_status_checks(void) {
  static const uint8_t src[] = "status-check-input";
  uint64_t src_len = sizeof(src) - 1;
  uint64_t bound = asmp_deflate_raw_bound(src_len);
  uint64_t scratch_len = asmp_deflate_raw_scratch_size();
  uint8_t *dst = calloc((size_t)bound, 1);
  void *scratch = calloc(1, (size_t)scratch_len);
  if (!dst || !scratch) {
    fprintf(stderr, "auto-status: allocation failed\n");
    return 1;
  }

  uint64_t out_len = 99;
  int failed = 0;
  int status = asmp_deflate_raw_auto(NULL, bound, &out_len, src, src_len,
                                     scratch, scratch_len);
  failed |= expect_status("auto-bad-dst", status, ASMP_DEFLATE_BAD_ARGUMENT, out_len);

  out_len = 99;
  status = asmp_deflate_raw_auto(dst, 1, &out_len, src, src_len,
                                 scratch, scratch_len);
  failed |= expect_status("auto-small-dst", status, ASMP_DEFLATE_DST_TOO_SMALL, out_len);
  if (out_len != 0) {
    fprintf(stderr, "auto-small-dst: expected len reset to 0, got %llu\n",
            (unsigned long long)out_len);
    failed = 1;
  }

  out_len = 99;
  status = asmp_deflate_raw_auto(dst, bound, &out_len, src, src_len,
                                 scratch, 16);
  failed |= expect_status("auto-small-scratch", status,
                          ASMP_DEFLATE_SCRATCH_TOO_SMALL, out_len);
  if (out_len != 0) {
    fprintf(stderr, "auto-small-scratch: expected len reset to 0, got %llu\n",
            (unsigned long long)out_len);
    failed = 1;
  }

  out_len = 99;
  status = asmp_deflate_raw_auto(dst, bound, &out_len, NULL, src_len,
                                 scratch, scratch_len);
  failed |= expect_status("auto-bad-src", status, ASMP_DEFLATE_BAD_ARGUMENT, out_len);

  out_len = 99;
  status = asmp_deflate_raw_auto(dst, bound, &out_len, NULL, 0,
                                 scratch, scratch_len);
  failed |= expect_status("auto-empty-null-src", status, ASMP_DEFLATE_OK, out_len);
  if (out_len != 2) {
    fprintf(stderr, "auto-empty-null-src: expected len 2, got %llu\n",
            (unsigned long long)out_len);
    failed = 1;
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

  static uint8_t period257[65536];
  for (size_t i = 0; i < 257; i++) {
    period257[i] = (uint8_t)((i * 131u + 7u) & 0xffu);
  }
  for (size_t i = 257; i < sizeof(period257); i++) {
    period257[i] = period257[i - 257];
  }

  static uint8_t binary[2048];
  for (size_t i = 0; i < sizeof(binary); i++) {
    binary[i] = (uint8_t)((i * 37u + (i >> 3)) & 0xffu);
  }

  static uint8_t long_repeat[70000];
  for (size_t i = 0; i < sizeof(long_repeat); i++) {
    long_repeat[i] = (uint8_t)("asmp-deflate-window-wrap-"[i % 25]);
  }

  static uint8_t high_literals[112];
  for (size_t i = 0; i < sizeof(high_literals); i++) {
    high_literals[i] = (uint8_t)(144u + i);
  }

  int failed = 0;
  failed |= roundtrip("empty", empty, 0, 4);
  failed |= roundtrip("small", small, sizeof(small) - 1, 32);
  failed |= roundtrip("text", text, sizeof(text) - 1, 128);
  failed |= roundtrip("repeated", repeated, sizeof(repeated), 128);
  failed |= roundtrip("period257", period257, sizeof(period257), 1024);
  failed |= roundtrip("binary", binary, sizeof(binary), 1230);
  failed |= roundtrip("long-repeat", long_repeat, sizeof(long_repeat), 1024);
  failed |= stored_roundtrip("empty", empty, 0);
  failed |= stored_roundtrip("small", small, sizeof(small) - 1);
  failed |= stored_roundtrip("text", text, sizeof(text) - 1);
  failed |= stored_roundtrip("repeated", repeated, sizeof(repeated));
  failed |= stored_roundtrip("period257", period257, sizeof(period257));
  failed |= stored_roundtrip("binary", binary, sizeof(binary));
  failed |= stored_roundtrip("long-repeat", long_repeat, sizeof(long_repeat));
  failed |= auto_roundtrip("empty", empty, 0, 2);
  failed |= auto_roundtrip("small", small, sizeof(small) - 1, 10);
  failed |= auto_roundtrip("text", text, sizeof(text) - 1, 83);
  failed |= auto_roundtrip("repeated", repeated, sizeof(repeated), 53);
  failed |= auto_roundtrip("period257", period257, sizeof(period257), 908);
  failed |= auto_roundtrip("binary", binary, sizeof(binary), 1196);
  failed |= auto_roundtrip("long-repeat", long_repeat, sizeof(long_repeat), 571);
  failed |= auto_roundtrip("high-literals", high_literals, sizeof(high_literals),
                           stored_expected_len(sizeof(high_literals)));
  failed |= status_checks();
  failed |= stored_status_checks();
  failed |= auto_status_checks();
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
    (error 'deflate-native-test "command failed: ~a ~a" exe args)))

(define (call-with-temp-dir proc)
  (define dir (make-temporary-file "asmp-deflate-native-~a" 'directory))
  (dynamic-wind
    void
    (lambda () (proc dir))
    (lambda () (delete-directory/files dir))))

(define deflate-native-tests
  (test-suite
   "native deflate roundtrip"

   (test-case "fixed hash-chain deflate roundtrips through zlib on macOS arm64"
     (cond
       [(not (native-macos-aarch64?))
        (printf "skip native deflate roundtrip on ~a/~a\n"
                (system-type 'os)
                (system-type 'arch))
        (check-true #t)]
       [(not (find-executable-path "clang"))
        (printf "skip native deflate roundtrip: clang not found\n")
        (check-true #t)]
       [else
        (call-with-temp-dir
         (lambda (dir)
           (define asm-path (build-path dir "deflate-fixed-chain.s"))
           (define header-path (build-path dir "asmp_deflate.h"))
           (define harness-path (build-path dir "harness.c"))
           (define exe-path (build-path dir "harness"))
           (call-with-output-file harness-path
             #:exists 'truncate/replace
             (lambda (out) (display harness-source out)))
           (let ([code (assemble deflate-chain-source
                                 #:input-syntax    'gnu
                                 #:asm-syntax      'apple
                                 #:elim?           #t
                                 #:public-c-header header-path
                                 #:output          asm-path)])
             (unless (zero? code)
               (error 'deflate-native-test "assemble failed (~a): ~a" code deflate-chain-source)))
           (run-command (find-executable-path "clang")
                        "-O2"
                        harness-path
                        asm-path
                        "-I"
                        dir
                        "-lz"
                        "-o"
                        exe-path)
           (run-command exe-path)
           (check-true #t)))]))))

(module+ main
  (void (run-tests deflate-native-tests)))

(module+ test
  (void (run-tests deflate-native-tests)))
