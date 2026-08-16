#lang racket

(require rackunit
         rackunit/text-ui
         racket/file
         racket/runtime-path)

(require (only-in "../cli/as.rkt" assemble))   ; in-process 汇编
(define-runtime-path word-extend-source "../example/023-deflate-fixed-chain-word-extend.asm")
(define-runtime-path neon-extend-source "../example/024-deflate-fixed-chain-neon-extend.asm")
(define-runtime-path runtime-dispatch-source "../example/027-deflate-runtime-dispatch.asm")

(define harness-source
  #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#include "asmp_runtime_dispatch.h"

extern void asmp_deflate_runtime_set_features(uint64_t features);
extern void asmp_deflate_runtime_init(void);
extern uint64_t asmp_deflate_runtime_detect_features(void);
extern uint64_t asmp_deflate_runtime_features;

enum {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_DST_TOO_SMALL = 1,
  ASMP_DEFLATE_SCRATCH_TOO_SMALL = 2,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};

static uint64_t stored_expected_len(size_t len) {
  uint64_t blocks = 1;
  if (len > 0) {
    blocks = ((uint64_t)len + 65534u) / 65535u;
  }
  return (uint64_t)len + blocks * 5u;
}

static int inflate_check(const char *mode,
                         const char *name,
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
    return 1;
  }
  zs.next_in = (Bytef *)compressed;
  zs.avail_in = (uInt)clen;
  zs.next_out = decoded;
  zs.avail_out = (uInt)(len + 64);
  zr = inflate(&zs, Z_FINISH);
  if (zr != Z_STREAM_END) {
    fprintf(stderr, "%s/%s: inflate=%d total_out=%lu clen=%llu\n", mode, name,
            zr, (unsigned long)zs.total_out, (unsigned long long)clen);
    inflateEnd(&zs);
    return 1;
  }
  inflateEnd(&zs);

  if (zs.total_out != len || memcmp(decoded, src, len) != 0) {
    fprintf(stderr, "%s/%s: decoded mismatch\n", mode, name);
    return 1;
  }
  free(decoded);
  return 0;
}

static int roundtrip_fixed(const char *mode,
                           const char *name,
                           const uint8_t *src,
                           size_t len,
                           uint64_t expected_len) {
  uint64_t out_cap = asmp_deflate_raw_bound((uint64_t)len);
  uint64_t scratch_len = asmp_deflate_raw_scratch_size();
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !scratch) {
    fprintf(stderr, "%s/%s: allocation failed\n", mode, name);
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
  if (status != ASMP_DEFLATE_OK || clen != expected_len) {
    fprintf(stderr, "%s/%s: status=%d clen=%llu expected=%llu\n", mode, name,
            status, (unsigned long long)clen,
            (unsigned long long)expected_len);
    return 1;
  }

  int failed = inflate_check(mode, name, compressed, clen, src, len);
  printf("%s/%s/fixed: %zu -> %llu bytes\n", mode, name, len,
         (unsigned long long)clen);
  free(compressed);
  free(scratch);
  return failed;
}

static int roundtrip_auto_stored(const char *mode,
                                 const uint8_t *src,
                                 size_t len) {
  uint64_t out_cap = asmp_deflate_raw_bound((uint64_t)len);
  uint64_t scratch_len = asmp_deflate_raw_scratch_size();
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !scratch) {
    fprintf(stderr, "%s/high-literals: allocation failed\n", mode);
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
  uint64_t expected_len = stored_expected_len(len);
  if (status != ASMP_DEFLATE_OK || clen != expected_len) {
    fprintf(stderr, "%s/high-literals: status=%d clen=%llu expected=%llu\n",
            mode, status, (unsigned long long)clen,
            (unsigned long long)expected_len);
    return 1;
  }

  int failed = inflate_check(mode, "high-literals", compressed, clen, src, len);
  printf("%s/high-literals/auto: %zu -> %llu bytes\n", mode, len,
         (unsigned long long)clen);
  free(compressed);
  free(scratch);
  return failed;
}

static int run_mode(const char *mode, uint64_t features) {
  asmp_deflate_runtime_set_features(features);

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

  static uint8_t high_literals[112];
  for (size_t i = 0; i < sizeof(high_literals); i++) {
    high_literals[i] = (uint8_t)(144u + i);
  }

  int failed = 0;
  failed |= roundtrip_fixed(mode, "empty", empty, 0, 2);
  failed |= roundtrip_fixed(mode, "small", small, sizeof(small) - 1, 10);
  failed |= roundtrip_fixed(mode, "repeated", repeated, sizeof(repeated), 53);
  failed |= roundtrip_fixed(mode, "period257", period257, sizeof(period257),
                            908);
  failed |= roundtrip_auto_stored(mode, high_literals, sizeof(high_literals));
  return failed;
}

static int run_init_default(void) {
  asmp_deflate_runtime_set_features(0);
  if (asmp_deflate_runtime_features != 0) {
    fprintf(stderr, "runtime init test: feature word did not switch to word\n");
    return 1;
  }

  if (asmp_deflate_runtime_detect_features() != 1) {
    fprintf(stderr, "runtime init test: detector did not report baseline NEON\n");
    return 1;
  }

  asmp_deflate_runtime_init();
  if (asmp_deflate_runtime_features != 1) {
    fprintf(stderr, "runtime init test: feature word did not switch to NEON\n");
    return 1;
  }

  static const uint8_t small[] = "hello hello hello hello\n";
  return roundtrip_fixed("init-runtime", "small", small, sizeof(small) - 1, 10);
}

int main(void) {
  int failed = 0;
  failed |= run_init_default();
  failed |= run_mode("word-runtime", 0);
  failed |= run_mode("neon-runtime", 1);
  return failed ? 1 : 0;
}
C
  )

(define override-harness-source
  #<<C
#include <stdint.h>
#include <stdio.h>

#include "asmp_runtime_dispatch.h"

extern void asmp_deflate_runtime_init(void);
extern uint64_t asmp_deflate_runtime_features;

uint64_t asmp_deflate_runtime_detect_features(void) {
  return 0;
}

int main(void) {
  asmp_deflate_runtime_init();
  if (asmp_deflate_runtime_features != 0) {
    fprintf(stderr, "runtime detector override did not select word path\n");
    return 1;
  }
  return 0;
}
C
  )

(define (native-macos-aarch64?)
  (and (eq? (system-type 'os) 'macosx)
       (eq? (system-type 'arch) 'aarch64)))

(define (run-command exe . args)
  (define ok? (apply system* exe args))
  (unless ok?
    (error 'deflate-runtime-dispatch-native-test
           "command failed: ~a ~a"
           exe
           args)))

(define (check-runtime-dispatch-asm asm-path)
  (define asm (file->string asm-path))
  (check-true
   (regexp-match? #rx"\\.globl[ \t]+_?asmp_deflate_raw_fixed" asm)
   "runtime dispatcher should export the stable fixed entry")
  (check-true
   (regexp-match? #rx"\\.private_extern[ \t]+_?asmp_deflate_runtime_init" asm)
   "runtime init should be hidden from external linkage")
  (check-true
   (regexp-match? #rx"\\.private_extern[ \t]+_?asmp_deflate_runtime_detect_features" asm)
   "runtime feature detector should be hidden from external linkage")
  (check-true
   (regexp-match? #rx"\\.weak(?:_definition)?[ \t]+_?asmp_deflate_runtime_detect_features" asm)
   "runtime feature detector should be a weak default hook")
  (check-true
   (regexp-match? #rx"bl[ \t]+_?asmp_deflate_runtime_detect_features" asm)
   "runtime init should call the feature detector")
  (check-true
   (regexp-match? #rx"b[ \t]+_?asmp_deflate_runtime_set_features" asm)
   "runtime init should tail-dispatch through the setter")
  (check-true
   (regexp-match? #rx"tbnz[ \t]+w0, #0" asm)
   "runtime setter should branch on feature bit 0")
  (check-true
   (regexp-match? #rx"br[ \t]+x16" asm)
   "runtime stable entries should tail-dispatch through cached pointers")
  (check-true
   (regexp-match? #rx"_?asmp_deflate_runtime_selected_fixed:" asm)
   "runtime dispatcher should emit a cached fixed-entry pointer slot")
  (check-true
   (regexp-match? #rx"\\.8byte[ \t]+_?asmp_deflate_raw_fixed_neon_extend" asm)
   "runtime fixed pointer slot should default to the NEON implementation")
  (check-true
   (regexp-match? #rx"_?asmp_deflate_raw_fixed_word_extend" asm)
   "runtime word target table should contain the word fixed target")
  (check-true
   (regexp-match? #rx"_?asmp_deflate_runtime_word_slots:" asm)
   "runtime dispatcher should emit a word target table")
  (check-true
   (regexp-match? #rx"_?asmp_deflate_runtime_neon_slots:" asm)
   "runtime dispatcher should emit a NEON target table")
  (check-true
   (regexp-match? #rx"ldr[ \t]+x9, \\[x17\\], #8" asm)
   "runtime setter should copy selected target slots from a table")
  (check-true
   (regexp-match? #rx"str[ \t]+x9, \\[x16\\], #8" asm)
   "runtime setter should update selected target slots with a compact loop")
  (check-true
   (regexp-match? #rx"\\.section __DATA,__data" asm)
   "runtime feature word should live in the Apple data section")
  (check-true
   (regexp-match? #rx"_asmp_deflate_runtime_features:" asm)
   "runtime feature word should be emitted as a symbol")
  (check-true
   (regexp-match? #rx"\\.8byte 1" asm)
   "runtime feature word should default to NEON")
  (check-false
   (regexp-match? #rx"tbnz[ \t]+w16, #0" asm)
   "stable entries should not re-test the feature bit on every call"))

(define (check-runtime-dispatch-header header-path)
  (define header (file->string header-path))
  (check-false
   (regexp-match? #rx"asmp_deflate_runtime_set_features" header)
   "runtime setter should not be exposed in the public C header")
  (check-false
   (regexp-match? #rx"asmp_deflate_runtime_init" header)
   "runtime init should not be exposed in the public C header")
  (check-false
   (regexp-match? #rx"asmp_deflate_runtime_detect_features" header)
   "runtime feature detector should not be exposed in the public C header"))

(define (call-with-temp-dir proc)
  (define dir (make-temporary-file "asmp-deflate-runtime-dispatch-native-~a" 'directory))
  (dynamic-wind
    void
    (lambda () (proc dir))
    (lambda () (delete-directory/files dir))))

(define deflate-runtime-dispatch-native-tests
  (test-suite
   "native deflate runtime dispatch"

   (test-case "runtime selector switches stable raw-deflate API between word and NEON implementations"
     (cond
       [(not (native-macos-aarch64?))
        (printf "skip native deflate runtime dispatch on ~a/~a\n"
                (system-type 'os)
                (system-type 'arch))
        (check-true #t)]
       [(not (find-executable-path "clang"))
        (printf "skip native deflate runtime dispatch: clang not found\n")
        (check-true #t)]
       [else
        (call-with-temp-dir
         (lambda (dir)
           (define word-asm-path (build-path dir "word.s"))
           (define neon-asm-path (build-path dir "neon.s"))
           (define runtime-asm-path (build-path dir "runtime.s"))
           (define header-path (build-path dir "asmp_runtime_dispatch.h"))
           (define harness-path (build-path dir "harness.c"))
           (define override-harness-path (build-path dir "override-harness.c"))
           (define exe-path (build-path dir "harness"))
           (define override-exe-path (build-path dir "override-harness"))
           (call-with-output-file harness-path
             #:exists 'truncate/replace
             (lambda (out) (display harness-source out)))
           (call-with-output-file override-harness-path
             #:exists 'truncate/replace
             (lambda (out) (display override-harness-source out)))
           (let ([code (assemble word-extend-source
                                 #:input-syntax 'gnu #:asm-syntax 'apple #:elim? #t
                                 #:output word-asm-path)])
             (unless (zero? code) (error 'runtime-dispatch "assemble failed: ~a" code)))
           (let ([code (assemble neon-extend-source
                                 #:input-syntax 'gnu #:asm-syntax 'apple #:elim? #t
                                 #:output neon-asm-path)])
             (unless (zero? code) (error 'runtime-dispatch "assemble failed: ~a" code)))
           (let ([code (assemble runtime-dispatch-source
                                 #:input-syntax 'gnu #:asm-syntax 'apple #:elim? #t
                                 #:public-c-header header-path #:output runtime-asm-path)])
             (unless (zero? code) (error 'runtime-dispatch "assemble failed: ~a" code)))
           (check-runtime-dispatch-asm runtime-asm-path)
           (check-runtime-dispatch-header header-path)
           (run-command (find-executable-path "clang")
                        "-O2"
                        harness-path
                        word-asm-path
                        neon-asm-path
                        runtime-asm-path
                        "-I"
                        dir
                        "-lz"
                        "-o"
                        exe-path)
           (run-command exe-path)
           (run-command (find-executable-path "clang")
                        "-O2"
                        override-harness-path
                        word-asm-path
                        neon-asm-path
                        runtime-asm-path
                        "-I"
                        dir
                        "-o"
                        override-exe-path)
           (run-command override-exe-path)
           (check-true #t)))]))))

(module+ main
  (void (run-tests deflate-runtime-dispatch-native-tests)))

(module+ test
  (void (run-tests deflate-runtime-dispatch-native-tests)))
