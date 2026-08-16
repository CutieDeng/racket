#lang racket

(require rackunit
         rackunit/text-ui
         racket/file
         racket/runtime-path)

(require (only-in "../cli/as.rkt" assemble))   ; in-process 汇编
(define-runtime-path word-extend-source "../example/023-deflate-fixed-chain-word-extend.asm")
(define-runtime-path word-dispatch-source "../example/026-deflate-default-word-dispatch.asm")

(define harness-source
  #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#include "asmp_wordextend.h"

#ifdef USE_STABLE_API
uint64_t asmp_deflate_raw_bound(uint64_t src_len);
uint64_t asmp_deflate_raw_scratch_size(void);
int asmp_deflate_raw_fixed(uint8_t *dst,
                           uint64_t dst_cap,
                           uint64_t *dst_len,
                           const uint8_t *src,
                           uint64_t src_len,
                           void *scratch,
                           uint64_t scratch_len);
#define ASMP_WORD_BOUND asmp_deflate_raw_bound
#define ASMP_WORD_SCRATCH_SIZE asmp_deflate_raw_scratch_size
#define ASMP_WORD_FIXED asmp_deflate_raw_fixed
#define ASMP_WORD_LABEL "word-dispatch"
#else
#define ASMP_WORD_BOUND asmp_deflate_word_extend_raw_bound
#define ASMP_WORD_SCRATCH_SIZE asmp_deflate_word_extend_raw_scratch_size
#define ASMP_WORD_FIXED asmp_deflate_raw_fixed_word_extend
#define ASMP_WORD_LABEL "word-extend"
#endif

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
  uint64_t out_cap = ASMP_WORD_BOUND((uint64_t)len);
  uint64_t scratch_len = ASMP_WORD_SCRATCH_SIZE();
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  uint8_t *decoded = calloc(len + 64, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !decoded || !scratch) {
    fprintf(stderr, "%s: allocation failed\n", name);
    return 1;
  }

  uint64_t clen = 0;
  int status = ASMP_WORD_FIXED(compressed,
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

  printf("%s/%s: %zu -> %llu bytes\n", name, ASMP_WORD_LABEL, len,
         (unsigned long long)clen);
  free(compressed);
  free(decoded);
  free(scratch);
  return 0;
}

static int status_checks(void) {
  static const uint8_t src[] = "status-check-input";
  uint64_t src_len = sizeof(src) - 1;
  uint64_t bound = ASMP_WORD_BOUND(src_len);
  uint64_t scratch_len = ASMP_WORD_SCRATCH_SIZE();
  uint8_t *dst = calloc((size_t)bound, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  uint64_t out_len = 99;
  int failed = 0;

  int status = ASMP_WORD_FIXED(NULL, bound, &out_len, src,
                               src_len, scratch, scratch_len);
  failed |= status != ASMP_DEFLATE_BAD_ARGUMENT;

  out_len = 99;
  status = ASMP_WORD_FIXED(dst, 1, &out_len, src, src_len,
                           scratch, scratch_len);
  failed |= status != ASMP_DEFLATE_DST_TOO_SMALL || out_len != 0;

  out_len = 99;
  status = ASMP_WORD_FIXED(dst, bound, &out_len, src, src_len,
                           scratch, 16);
  failed |= status != ASMP_DEFLATE_SCRATCH_TOO_SMALL || out_len != 0;

  out_len = 99;
  status = ASMP_WORD_FIXED(dst, bound, &out_len, NULL, 0,
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

  int failed = 0;
  failed |= roundtrip("empty", empty, 0, 2);
  failed |= roundtrip("small", small, sizeof(small) - 1, 10);
  failed |= roundtrip("repeated", repeated, sizeof(repeated), 53);
  failed |= roundtrip("period257", period257, sizeof(period257), 908);
  failed |= roundtrip("binary", binary, sizeof(binary), 1196);
  failed |= roundtrip("long-repeat", long_repeat, sizeof(long_repeat), 571);
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
    (error 'deflate-word-extend-native-test "command failed: ~a ~a" exe args)))

(define (check-strong-word-dispatch asm-path)
  (define asm (file->string asm-path))
  (check-true
   (regexp-match? #rx"\\.globl[ \t]+_?asmp_deflate_raw_fixed" asm)
   "strong word dispatcher should export the stable fixed entry")
  (check-false
   (regexp-match? #rx"\\.weak(?:_definition)?[ \t]+_?asmp_deflate_raw_fixed" asm)
   "strong word dispatcher must not emit a weak stable fixed entry")
  (check-true
   (regexp-match? #rx"b[ \t]+_?asmp_deflate_raw_fixed_word_extend" asm)
   "stable fixed entry should tail-branch to the word-extend wrapper")
  (check-true
   (regexp-match? #rx"b[ \t]+_?asmp_deflate_raw_auto_word_extend" asm)
   "stable auto entry should tail-branch to the word-extend wrapper"))

(define (call-with-temp-dir proc)
  (define dir (make-temporary-file "asmp-deflate-word-extend-native-~a" 'directory))
  (dynamic-wind
    void
    (lambda () (proc dir))
    (lambda () (delete-directory/files dir))))

(define word-extend-native-tests
  (test-suite
   "native deflate word-extend roundtrip"

   (test-case "word-extend hash-chain deflate roundtrips through zlib on macOS arm64"
     (cond
       [(not (native-macos-aarch64?))
        (printf "skip native word-extend deflate roundtrip on ~a/~a\n"
                (system-type 'os)
                (system-type 'arch))
        (check-true #t)]
       [(not (find-executable-path "clang"))
        (printf "skip native word-extend deflate roundtrip: clang not found\n")
        (check-true #t)]
       [else
        (call-with-temp-dir
         (lambda (dir)
           (define asm-path (build-path dir "wordextend.s"))
           (define dispatch-asm-path (build-path dir "word-dispatch.s"))
           (define header-path (build-path dir "asmp_wordextend.h"))
           (define harness-path (build-path dir "harness.c"))
           (define exe-path (build-path dir "harness"))
           (define dispatch-exe-path (build-path dir "harness-dispatch"))
           (call-with-output-file harness-path
             #:exists 'truncate/replace
             (lambda (out) (display harness-source out)))
           (let ([code (assemble word-extend-source
                                 #:input-syntax 'gnu #:asm-syntax 'apple #:elim? #t
                                 #:public-c-header header-path #:output asm-path)])
             (unless (zero? code) (error 'word-extend "assemble failed: ~a" code)))
           (let ([code (assemble word-dispatch-source
                                 #:input-syntax 'gnu #:asm-syntax 'apple #:elim? #t
                                 #:output dispatch-asm-path)])
             (unless (zero? code) (error 'word-extend "assemble failed: ~a" code)))
           (check-strong-word-dispatch dispatch-asm-path)
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
                        "-DUSE_STABLE_API"
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
  (void (run-tests word-extend-native-tests)))

(module+ test
  (void (run-tests word-extend-native-tests)))
