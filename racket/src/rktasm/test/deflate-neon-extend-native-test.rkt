#lang racket

(require rackunit
         rackunit/text-ui
         racket/file
         racket/runtime-path)

(require (only-in "../cli/as.rkt" assemble))   ; in-process 汇编
(define-runtime-path neon-extend-source "../example/024-deflate-fixed-chain-neon-extend.asm")
(define-runtime-path neon-dispatch-source "../example/025-deflate-default-neon-dispatch.asm")

(define harness-source
  #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#include "asmp_neonextend.h"

enum {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_DST_TOO_SMALL = 1,
  ASMP_DEFLATE_SCRATCH_TOO_SMALL = 2,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};

static int roundtrip(const char *name,
                     const uint8_t *src,
                     size_t len,
                     uint64_t expected_len) {
  uint64_t out_cap = asmp_deflate_raw_bound((uint64_t)len);
  uint64_t scratch_len = asmp_deflate_raw_scratch_size();
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  uint8_t *decoded = calloc(len + 64, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !decoded || !scratch) {
    fprintf(stderr, "%s: allocation failed\n", name);
    return 1;
  }

  uint64_t clen = 0;
  int status = asmp_deflate_raw_fixed(compressed,
                                      out_cap,
                                      &clen,
                                      src,
                                      (uint64_t)len,
                                      scratch,
                                      scratch_len);
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: status=%d clen=%llu\n", name, status,
            (unsigned long long)clen);
    return 1;
  }
  if (clen != expected_len) {
    fprintf(stderr, "%s: clen=%llu expected=%llu\n", name,
            (unsigned long long)clen, (unsigned long long)expected_len);
    return 1;
  }

  z_stream zs;
  memset(&zs, 0, sizeof(zs));
  int zr = inflateInit2(&zs, -MAX_WBITS);
  if (zr != Z_OK) {
    return 1;
  }
  zs.next_in = compressed;
  zs.avail_in = (uInt)clen;
  zs.next_out = decoded;
  zs.avail_out = (uInt)(len + 64);
  zr = inflate(&zs, Z_FINISH);
  if (zr != Z_STREAM_END) {
    fprintf(stderr, "%s: inflate=%d total_out=%lu clen=%llu\n", name, zr,
            (unsigned long)zs.total_out, (unsigned long long)clen);
    inflateEnd(&zs);
    return 1;
  }
  inflateEnd(&zs);

  if (zs.total_out != len || memcmp(decoded, src, len) != 0) {
    fprintf(stderr, "%s: decoded mismatch\n", name);
    return 1;
  }

  printf("%s/neon-extend: %zu -> %llu bytes\n", name, len,
         (unsigned long long)clen);
  free(compressed);
  free(decoded);
  free(scratch);
  return 0;
}

static uint64_t stored_expected_len(size_t len) {
  uint64_t blocks = 1;
  if (len > 0) {
    blocks = ((uint64_t)len + 65534u) / 65535u;
  }
  return (uint64_t)len + blocks * 5u;
}

static int auto_roundtrip(const char *name,
                          const uint8_t *src,
                          size_t len,
                          uint64_t expected_len) {
  uint64_t out_cap = asmp_deflate_raw_bound((uint64_t)len);
  uint64_t scratch_len = asmp_deflate_raw_scratch_size();
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  uint8_t *decoded = calloc(len + 64, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !decoded || !scratch) {
    fprintf(stderr, "%s/auto: allocation failed\n", name);
    return 1;
  }

  uint64_t clen = 0;
  int status = asmp_deflate_raw_auto(compressed,
                                     out_cap,
                                     &clen,
                                     src,
                                     (uint64_t)len,
                                     scratch,
                                     scratch_len);
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s/auto: status=%d clen=%llu\n", name, status,
            (unsigned long long)clen);
    return 1;
  }
  if (clen != expected_len) {
    fprintf(stderr, "%s/auto: clen=%llu expected=%llu\n", name,
            (unsigned long long)clen, (unsigned long long)expected_len);
    return 1;
  }

  z_stream zs;
  memset(&zs, 0, sizeof(zs));
  int zr = inflateInit2(&zs, -MAX_WBITS);
  if (zr != Z_OK) {
    return 1;
  }
  zs.next_in = compressed;
  zs.avail_in = (uInt)clen;
  zs.next_out = decoded;
  zs.avail_out = (uInt)(len + 64);
  zr = inflate(&zs, Z_FINISH);
  if (zr != Z_STREAM_END) {
    fprintf(stderr, "%s/auto: inflate=%d total_out=%lu clen=%llu\n", name, zr,
            (unsigned long)zs.total_out, (unsigned long long)clen);
    inflateEnd(&zs);
    return 1;
  }
  inflateEnd(&zs);

  if (zs.total_out != len || memcmp(decoded, src, len) != 0) {
    fprintf(stderr, "%s/auto: decoded mismatch\n", name);
    return 1;
  }

  printf("%s/auto-default: %zu -> %llu bytes\n", name, len,
         (unsigned long long)clen);
  free(compressed);
  free(decoded);
  free(scratch);
  return 0;
}

static int status_checks(void) {
  static const uint8_t src[] = "status-check-input";
  uint64_t src_len = sizeof(src) - 1;
  uint64_t bound = asmp_deflate_raw_bound(src_len);
  uint64_t scratch_len = asmp_deflate_raw_scratch_size();
  uint8_t *dst = calloc((size_t)bound, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  uint64_t out_len = 99;
  int failed = 0;

  int status = asmp_deflate_raw_fixed(NULL, bound, &out_len, src,
                                      src_len, scratch, scratch_len);
  failed |= status != ASMP_DEFLATE_BAD_ARGUMENT;

  out_len = 99;
  status = asmp_deflate_raw_fixed(dst, 1, &out_len, src, src_len,
                                  scratch, scratch_len);
  failed |= status != ASMP_DEFLATE_DST_TOO_SMALL || out_len != 0;

  out_len = 99;
  status = asmp_deflate_raw_fixed(dst, bound, &out_len, src, src_len,
                                  scratch, 16);
  failed |= status != ASMP_DEFLATE_SCRATCH_TOO_SMALL || out_len != 0;

  out_len = 99;
  status = asmp_deflate_raw_fixed(dst, bound, &out_len, NULL, 0,
                                  scratch, scratch_len);
  failed |= status != ASMP_DEFLATE_OK || out_len != 2;

  free(dst);
  free(scratch);
  return failed;
}

int main(void) {
  static const uint8_t empty[] = "";
  static const uint8_t small[] = "hello hello hello hello\n";

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
  failed |= roundtrip("empty", empty, 0, 2);
  failed |= roundtrip("small", small, sizeof(small) - 1, 10);
  failed |= roundtrip("repeated", repeated, sizeof(repeated), 53);
  failed |= roundtrip("period257", period257, sizeof(period257), 908);
  failed |= roundtrip("binary", binary, sizeof(binary), 1196);
  failed |= roundtrip("long-repeat", long_repeat, sizeof(long_repeat), 571);
  failed |= auto_roundtrip("high-literals",
                           high_literals,
                           sizeof(high_literals),
                           stored_expected_len(sizeof(high_literals)));
  failed |= status_checks();
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
    (error 'deflate-neon-extend-native-test "command failed: ~a ~a" exe args)))

(define (check-logical-fixed-call-lowered asm-path)
  (define asm (file->string asm-path))
  (check-true
   (regexp-match? #rx"bl[ \t]+_?deflate_fixed_chain_neon_extend_aarch64_asm" asm)
   "logical feature/variant .call should lower to the concrete NEON core")
  (check-true
   (regexp-match? #rx"bl[ \t]+_?asmp_deflate_raw_fixed_neon_extend" asm)
   "stable fixed public entry should call the selected NEON-extend wrapper")
  (check-true
   (regexp-match? #rx"bl[ \t]+_?asmp_deflate_raw_auto_neon_extend" asm)
   "stable auto public entry should call the selected NEON-extend wrapper")
  (check-false
   (regexp-match? #rx"bl[ \t]+_?deflate_fixed_chain_word_extend_aarch64_asm" asm)
   "logical source-variant target should not remain as an emitted branch"))

(define (check-strong-neon-dispatch asm-path)
  (define asm (file->string asm-path))
  (check-true
   (regexp-match? #rx"\\.globl[ \t]+_?asmp_deflate_raw_fixed" asm)
   "strong dispatcher should export the stable fixed entry")
  (check-false
   (regexp-match? #rx"\\.weak(?:_definition)?[ \t]+_?asmp_deflate_raw_fixed" asm)
   "strong dispatcher must not emit a weak stable fixed entry")
  (check-true
   (regexp-match? #rx"b[ \t]+_?asmp_deflate_raw_fixed_neon_extend" asm)
   "stable fixed entry should tail-branch to the NEON-extend wrapper")
  (check-true
   (regexp-match? #rx"b[ \t]+_?asmp_deflate_raw_auto_neon_extend" asm)
   "stable auto entry should tail-branch to the NEON-extend wrapper"))

(define (call-with-temp-dir proc)
  (define dir (make-temporary-file "asmp-deflate-neon-extend-native-~a" 'directory))
  (dynamic-wind
    void
    (lambda () (proc dir))
    (lambda () (delete-directory/files dir))))

(define neon-extend-native-tests
  (test-suite
   "native deflate neon-extend roundtrip"

   (test-case "neon-extend hash-chain deflate roundtrips through zlib on macOS arm64"
     (cond
       [(not (native-macos-aarch64?))
        (printf "skip native neon-extend deflate roundtrip on ~a/~a\n"
                (system-type 'os)
                (system-type 'arch))
        (check-true #t)]
       [(not (find-executable-path "clang"))
        (printf "skip native neon-extend deflate roundtrip: clang not found\n")
        (check-true #t)]
       [else
        (call-with-temp-dir
         (lambda (dir)
           (define asm-path (build-path dir "neonextend.s"))
           (define dispatch-asm-path (build-path dir "neon-dispatch.s"))
           (define header-path (build-path dir "asmp_neonextend.h"))
           (define harness-path (build-path dir "harness.c"))
           (define exe-path (build-path dir "harness"))
           (define dispatch-exe-path (build-path dir "harness-dispatch"))
           (call-with-output-file harness-path
             #:exists 'truncate/replace
             (lambda (out) (display harness-source out)))
           (let ([code (assemble neon-extend-source
                                 #:input-syntax    'gnu #:asm-syntax 'apple #:elim? #t
                                 #:public-c-header header-path #:output asm-path)])
             (unless (zero? code) (error 'neon-extend "assemble failed: ~a" code)))
           (check-logical-fixed-call-lowered asm-path)
           (let ([code (assemble neon-dispatch-source
                                 #:input-syntax 'gnu #:asm-syntax 'apple #:elim? #t
                                 #:output dispatch-asm-path)])
             (unless (zero? code) (error 'neon-extend "assemble failed: ~a" code)))
           (check-strong-neon-dispatch dispatch-asm-path)
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
           (run-command (find-executable-path "clang")
                        "-O2"
                        harness-path
                        asm-path
                        dispatch-asm-path
                        "-I"
                        dir
                        "-lz"
                        "-o"
                        dispatch-exe-path)
           (run-command dispatch-exe-path)
           (check-true #t)))]))))

(module+ main
  (void (run-tests neon-extend-native-tests)))

(module+ test
  (void (run-tests neon-extend-native-tests)))
