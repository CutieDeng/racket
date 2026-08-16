#!/usr/bin/env racket
#lang racket

(require racket/cmdline
         racket/file
         racket/runtime-path)

(define-runtime-path root-dir "../../..")
(define-runtime-path deflate-root "..")

(define cli-source (build-path root-dir "cli" "as.rkt"))
(define deflate-source (build-path deflate-root "src" "019-deflate-fixed-chain.asm"))
(define deflate-word-extend-source
  (build-path deflate-root "src" "023-deflate-fixed-chain-word-extend.asm"))
(define deflate-neon-extend-source
  (build-path deflate-root "src" "024-deflate-fixed-chain-neon-extend.asm"))
(define deflate-runtime-dispatch-source
  (build-path deflate-root "src" "027-deflate-runtime-dispatch.asm"))
(define dynamic-canonical-source
  (build-path deflate-root "src" "028-deflate-dynamic-canonical-codes.asm"))
(define dynamic-reverse-source
  (build-path deflate-root "src" "029-deflate-dynamic-reverse-codes.asm"))
(define dynamic-rle-source
  (build-path deflate-root "src" "031-deflate-dynamic-code-length-rle.asm"))
(define dynamic-blfreq-source
  (build-path deflate-root "src" "032-deflate-dynamic-blfreq.asm"))
(define dynamic-code-counts-source
  (build-path deflate-root "src" "037-deflate-dynamic-code-counts.asm"))
(define dynamic-litlen-huffman-source
  (build-path deflate-root "src" "039-deflate-dynamic-litlen-huffman.asm"))
(define dynamic-bllen-huffman-source
  (build-path deflate-root "src" "041-deflate-dynamic-bllen-huffman.asm"))
(define dynamic-lz77-freq-source
  (build-path deflate-root "src" "043-deflate-dynamic-lz77-freq.asm"))
(define dynamic-distlen-huffman-source
  (build-path deflate-root "src" "044-deflate-dynamic-distlen-huffman.asm"))
(define dynamic-lz77-huffman-source
  (build-path deflate-root "src" "045-deflate-dynamic-lz77-huffman.asm"))
(define dynamic-auto-probe-source
  (build-path deflate-root "src" "046-deflate-auto-dynamic-probe.asm"))
(define dynamic-auto-cost-probe-source
  (build-path deflate-root "src" "047-deflate-auto-cost-probe.asm"))
(define dynamic-auto-size-probe-source
  (build-path deflate-root "src" "048-deflate-auto-size-probe.asm"))
(define dynamic-auto-prepared-size-probe-source
  (build-path deflate-root "src" "049-deflate-auto-prepared-size-probe.asm"))
(define dynamic-auto-cheap-prepared-size-probe-source
  (build-path deflate-root "src" "050-deflate-auto-cheap-prepared-size-probe.asm"))
(define blocked-fixed-source
  (build-path deflate-root "src" "051-deflate-blocked-fixed.asm"))
(define blocked-auto-source
  (build-path deflate-root "src" "052-deflate-blocked-auto.asm"))
(define blocked-dynamic-auto-source
  (build-path deflate-root "src" "053-deflate-blocked-dynamic-auto.asm"))

(define harness-source
  #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <zlib.h>

#include "asmp_deflate.h"

uint64_t asmp_deflate_word_extend_raw_bound(uint64_t src_len);
uint64_t asmp_deflate_word_extend_raw_scratch_size(void);
int asmp_deflate_raw_fixed_word_extend(uint8_t *dst,
                                       uint64_t dst_cap,
                                       uint64_t *dst_len,
                                       const uint8_t *src,
                                       uint64_t src_len,
                                       void *scratch,
                                       uint64_t scratch_len);

uint64_t asmp_deflate_neon_extend_raw_bound(uint64_t src_len);
uint64_t asmp_deflate_neon_extend_raw_scratch_size(void);
int asmp_deflate_raw_fixed_neon_extend(uint8_t *dst,
                                       uint64_t dst_cap,
                                       uint64_t *dst_len,
                                       const uint8_t *src,
                                       uint64_t src_len,
                                       void *scratch,
                                       uint64_t scratch_len);

uint64_t asmp_deflate_raw_dynamic_lz77_huffman_bound(uint64_t src_len);
uint64_t asmp_deflate_raw_dynamic_lz77_huffman_scratch_size(void);
int asmp_deflate_raw_dynamic_lz77_huffman(uint8_t *dst,
                                          uint64_t dst_cap,
                                          uint64_t *dst_len,
                                          const uint8_t *src,
                                          uint64_t src_len,
                                          void *scratch,
                                          uint64_t scratch_len);

uint64_t asmp_deflate_raw_auto_dynamic_probe_bound(uint64_t src_len);
uint64_t asmp_deflate_raw_auto_dynamic_probe_scratch_size(void);
int asmp_deflate_raw_auto_dynamic_probe(uint8_t *dst,
                                        uint64_t dst_cap,
                                        uint64_t *dst_len,
                                        const uint8_t *src,
                                        uint64_t src_len,
                                        void *scratch,
                                        uint64_t scratch_len);

uint64_t asmp_deflate_raw_auto_dynamic_cost_probe_bound(uint64_t src_len);
uint64_t asmp_deflate_raw_auto_dynamic_cost_probe_scratch_size(void);
int asmp_deflate_raw_auto_dynamic_cost_probe(uint8_t *dst,
                                             uint64_t dst_cap,
                                             uint64_t *dst_len,
                                             const uint8_t *src,
                                             uint64_t src_len,
                                             void *scratch,
                                             uint64_t scratch_len);

uint64_t asmp_deflate_raw_auto_dynamic_size_probe_bound(uint64_t src_len);
uint64_t asmp_deflate_raw_auto_dynamic_size_probe_scratch_size(void);
int asmp_deflate_raw_auto_dynamic_size_probe(uint8_t *dst,
                                             uint64_t dst_cap,
                                             uint64_t *dst_len,
                                             const uint8_t *src,
                                             uint64_t src_len,
                                             void *scratch,
                                             uint64_t scratch_len);

uint64_t asmp_deflate_raw_auto_dynamic_prepared_size_probe_bound(uint64_t src_len);
uint64_t asmp_deflate_raw_auto_dynamic_prepared_size_probe_scratch_size(void);
int asmp_deflate_raw_auto_dynamic_prepared_size_probe(uint8_t *dst,
                                                      uint64_t dst_cap,
                                                      uint64_t *dst_len,
                                                      const uint8_t *src,
                                                      uint64_t src_len,
                                                      void *scratch,
                                                      uint64_t scratch_len);

uint64_t asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_bound(uint64_t src_len);
uint64_t asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_scratch_size(void);
int asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe(uint8_t *dst,
                                                            uint64_t dst_cap,
                                                            uint64_t *dst_len,
                                                            const uint8_t *src,
                                                            uint64_t src_len,
                                                            void *scratch,
                                                            uint64_t scratch_len);

uint64_t asmp_deflate_raw_blocked_fixed_bound(uint64_t src_len);
uint64_t asmp_deflate_raw_blocked_fixed_scratch_size(void);
int asmp_deflate_raw_blocked_fixed(uint8_t *dst,
                                   uint64_t dst_cap,
                                   uint64_t *dst_len,
                                   const uint8_t *src,
                                   uint64_t src_len,
                                   void *scratch,
                                   uint64_t scratch_len);

uint64_t asmp_deflate_raw_blocked_auto_bound(uint64_t src_len);
uint64_t asmp_deflate_raw_blocked_auto_scratch_size(void);
int asmp_deflate_raw_blocked_auto(uint8_t *dst,
                                  uint64_t dst_cap,
                                  uint64_t *dst_len,
                                  const uint8_t *src,
                                  uint64_t src_len,
                                  void *scratch,
                                  uint64_t scratch_len);

uint64_t asmp_deflate_raw_blocked_dynamic_auto_bound(uint64_t src_len);
uint64_t asmp_deflate_raw_blocked_dynamic_auto_scratch_size(void);
int asmp_deflate_raw_blocked_dynamic_auto(uint8_t *dst,
                                          uint64_t dst_cap,
                                          uint64_t *dst_len,
                                          const uint8_t *src,
                                          uint64_t src_len,
                                          void *scratch,
                                          uint64_t scratch_len);

enum {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_DST_TOO_SMALL = 1,
  ASMP_DEFLATE_SCRATCH_TOO_SMALL = 2,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};

typedef struct {
  const char *name;
  const uint8_t *data;
  size_t len;
} case_info;

static uint64_t now_ns(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}

static double mib_per_second(size_t input_len, double ns_per_iter) {
  if (input_len == 0 || ns_per_iter <= 0.0) {
    return 0.0;
  }
  return ((double)input_len * 1000000000.0) / (ns_per_iter * 1048576.0);
}

static uint64_t sample_checksum(uint64_t checksum,
                                const uint8_t *compressed,
                                uint64_t clen,
                                int iter) {
  uint64_t first = clen == 0 ? 0 : compressed[0];
  uint64_t last = clen == 0 ? 0 : compressed[clen - 1];
  checksum ^= 0x9e3779b97f4a7c15ull + (checksum << 6) + (checksum >> 2);
  return checksum + clen + (first << 8) + (last << 32) + (uint64_t)iter;
}

static int verify_raw_deflate(const char *codec,
                              const char *case_name,
                              const uint8_t *compressed,
                              uint64_t clen,
                              const uint8_t *src,
                              size_t len,
                              uint8_t *decoded,
                              size_t dec_cap) {
  z_stream zs;
  memset(&zs, 0, sizeof(zs));
  int zr = inflateInit2(&zs, -MAX_WBITS);
  if (zr != Z_OK) {
    fprintf(stderr, "%s/%s: inflateInit2 failed: %d\n", codec, case_name, zr);
    return 1;
  }

  zs.next_in = (Bytef *)compressed;
  zs.avail_in = (uInt)clen;
  zs.next_out = decoded;
  zs.avail_out = (uInt)dec_cap;
  zr = inflate(&zs, Z_FINISH);
  if (zr != Z_STREAM_END) {
    fprintf(stderr,
            "%s/%s: inflate failed: %d total_out=%lu total_in=%lu clen=%llu\n",
            codec,
            case_name,
            zr,
            (unsigned long)zs.total_out,
            (unsigned long)zs.total_in,
            (unsigned long long)clen);
    inflateEnd(&zs);
    return 1;
  }
  inflateEnd(&zs);

  if (zs.total_out != len || memcmp(decoded, src, len) != 0) {
    fprintf(stderr,
            "%s/%s: mismatch total_out=%lu expected=%zu clen=%llu\n",
            codec,
            case_name,
            (unsigned long)zs.total_out,
            len,
            (unsigned long long)clen);
    return 1;
  }
  return 0;
}

static void print_result(const char *codec,
                         const char *case_name,
                         const char *status,
                         size_t input_len,
                         uint64_t clen,
                         uint64_t elapsed,
                         int iterations,
                         uint64_t checksum) {
  double ratio = input_len == 0 ? 0.0 : (double)clen / (double)input_len;
  double ns_per_iter = (double)elapsed / (double)iterations;
  printf("%s,%s,%s,%zu,%llu,%.6f,%.1f,%.3f,%llu\n",
         codec,
         case_name,
         status,
         input_len,
         (unsigned long long)clen,
         ratio,
         ns_per_iter,
         mib_per_second(input_len, ns_per_iter),
         (unsigned long long)checksum);
  fflush(stdout);
}

static int run_asmp_case(const case_info *case_data, int iterations) {
  uint64_t out_cap = asmp_deflate_raw_bound((uint64_t)case_data->len);
  uint64_t scratch_len = asmp_deflate_raw_scratch_size();
  size_t dec_cap = case_data->len + 64;
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  uint8_t *decoded = calloc(dec_cap, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !decoded || !scratch) {
    fprintf(stderr, "asmp/%s: allocation failed\n", case_data->name);
    return 1;
  }

  uint64_t clen = 0;
  uint64_t checksum = 0;
  uint64_t start = now_ns();
  for (int i = 0; i < iterations; i++) {
    clen = 0;
    int status = asmp_deflate_raw_fixed(compressed,
                                        out_cap,
                                        &clen,
                                        case_data->data,
                                        (uint64_t)case_data->len,
                                        scratch,
                                        scratch_len);
    if (status != ASMP_DEFLATE_OK || clen == 0 || clen > out_cap) {
      uint64_t elapsed = now_ns() - start;
      print_result("asmp-019-public",
                   case_data->name,
                   "fail",
                   case_data->len,
                   clen,
                   elapsed,
                   i + 1,
                   checksum);
      free(compressed);
      free(decoded);
      free(scratch);
      return 1;
    }
    checksum = sample_checksum(checksum, compressed, clen, i);
  }
  uint64_t elapsed = now_ns() - start;

  int failed = verify_raw_deflate("asmp-019-public",
                                  case_data->name,
                                  compressed,
                                  clen,
                                  case_data->data,
                                  case_data->len,
                                  decoded,
                                  dec_cap);
  print_result("asmp-019-public",
               case_data->name,
               failed ? "fail" : "ok",
               case_data->len,
               clen,
               elapsed,
               iterations,
               checksum);

  free(compressed);
  free(decoded);
  free(scratch);
  return failed;
}

static int run_wordextend_case(const case_info *case_data, int iterations) {
  uint64_t out_cap = asmp_deflate_word_extend_raw_bound((uint64_t)case_data->len);
  uint64_t scratch_len = asmp_deflate_word_extend_raw_scratch_size();
  size_t dec_cap = case_data->len + 64;
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  uint8_t *decoded = calloc(dec_cap, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !decoded || !scratch) {
    fprintf(stderr, "asmp-wordextend/%s: allocation failed\n", case_data->name);
    return 1;
  }

  uint64_t clen = 0;
  uint64_t checksum = 0;
  uint64_t start = now_ns();
  for (int i = 0; i < iterations; i++) {
    clen = 0;
    int status = asmp_deflate_raw_fixed_word_extend(compressed,
                                                    out_cap,
                                                    &clen,
                                                    case_data->data,
                                                    (uint64_t)case_data->len,
                                                    scratch,
                                                    scratch_len);
    if (status != ASMP_DEFLATE_OK || clen == 0 || clen > out_cap) {
      uint64_t elapsed = now_ns() - start;
      print_result("asmp-023-wordextend-public",
                   case_data->name,
                   "fail",
                   case_data->len,
                   clen,
                   elapsed,
                   i + 1,
                   checksum);
      free(compressed);
      free(decoded);
      free(scratch);
      return 1;
    }
    checksum = sample_checksum(checksum, compressed, clen, i);
  }
  uint64_t elapsed = now_ns() - start;

  int failed = verify_raw_deflate("asmp-023-wordextend-public",
                                  case_data->name,
                                  compressed,
                                  clen,
                                  case_data->data,
                                  case_data->len,
                                  decoded,
                                  dec_cap);
  print_result("asmp-023-wordextend-public",
               case_data->name,
               failed ? "fail" : "ok",
               case_data->len,
               clen,
               elapsed,
               iterations,
               checksum);

  free(compressed);
  free(decoded);
  free(scratch);
  return failed;
}

static int run_neonextend_case(const case_info *case_data, int iterations) {
  uint64_t out_cap = asmp_deflate_neon_extend_raw_bound((uint64_t)case_data->len);
  uint64_t scratch_len = asmp_deflate_neon_extend_raw_scratch_size();
  size_t dec_cap = case_data->len + 64;
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  uint8_t *decoded = calloc(dec_cap, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !decoded || !scratch) {
    fprintf(stderr, "asmp-neonextend/%s: allocation failed\n", case_data->name);
    return 1;
  }

  uint64_t clen = 0;
  uint64_t checksum = 0;
  uint64_t start = now_ns();
  for (int i = 0; i < iterations; i++) {
    clen = 0;
    int status = asmp_deflate_raw_fixed_neon_extend(compressed,
                                                    out_cap,
                                                    &clen,
                                                    case_data->data,
                                                    (uint64_t)case_data->len,
                                                    scratch,
                                                    scratch_len);
    if (status != ASMP_DEFLATE_OK || clen == 0 || clen > out_cap) {
      uint64_t elapsed = now_ns() - start;
      print_result("asmp-024-neonextend-public",
                   case_data->name,
                   "fail",
                   case_data->len,
                   clen,
                   elapsed,
                   i + 1,
                   checksum);
      free(compressed);
      free(decoded);
      free(scratch);
      return 1;
    }
    checksum = sample_checksum(checksum, compressed, clen, i);
  }
  uint64_t elapsed = now_ns() - start;

  int failed = verify_raw_deflate("asmp-024-neonextend-public",
                                  case_data->name,
                                  compressed,
                                  clen,
                                  case_data->data,
                                  case_data->len,
                                  decoded,
                                  dec_cap);
  print_result("asmp-024-neonextend-public",
               case_data->name,
               failed ? "fail" : "ok",
               case_data->len,
               clen,
               elapsed,
               iterations,
               checksum);

  free(compressed);
  free(decoded);
  free(scratch);
  return failed;
}

static int run_dynamic_lz77_huffman_case(const case_info *case_data,
                                         int iterations) {
  uint64_t out_cap =
      asmp_deflate_raw_dynamic_lz77_huffman_bound((uint64_t)case_data->len);
  uint64_t scratch_len = asmp_deflate_raw_dynamic_lz77_huffman_scratch_size();
  size_t dec_cap = case_data->len + 64;
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  uint8_t *decoded = calloc(dec_cap, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !decoded || !scratch) {
    fprintf(stderr, "asmp-dynamic-lz77-huffman/%s: allocation failed\n",
            case_data->name);
    return 1;
  }

  uint64_t clen = 0;
  uint64_t checksum = 0;
  uint64_t start = now_ns();
  for (int i = 0; i < iterations; i++) {
    clen = 0;
    int status = asmp_deflate_raw_dynamic_lz77_huffman(
        compressed,
        out_cap,
        &clen,
        case_data->data,
        (uint64_t)case_data->len,
        scratch,
        scratch_len);
    if (status != ASMP_DEFLATE_OK || clen == 0 || clen > out_cap) {
      uint64_t elapsed = now_ns() - start;
      print_result("asmp-045-dynamic-lz77-huffman",
                   case_data->name,
                   "fail",
                   case_data->len,
                   clen,
                   elapsed,
                   i + 1,
                   checksum);
      free(compressed);
      free(decoded);
      free(scratch);
      return 1;
    }
    checksum = sample_checksum(checksum, compressed, clen, i);
  }
  uint64_t elapsed = now_ns() - start;

  int failed = verify_raw_deflate("asmp-045-dynamic-lz77-huffman",
                                  case_data->name,
                                  compressed,
                                  clen,
                                  case_data->data,
                                  case_data->len,
                                  decoded,
                                  dec_cap);
  print_result("asmp-045-dynamic-lz77-huffman",
               case_data->name,
               failed ? "fail" : "ok",
               case_data->len,
               clen,
               elapsed,
               iterations,
               checksum);

  free(compressed);
  free(decoded);
  free(scratch);
  return failed;
}

static int run_auto_dynamic_probe_case(const case_info *case_data,
                                       int iterations) {
  uint64_t out_cap =
      asmp_deflate_raw_auto_dynamic_probe_bound((uint64_t)case_data->len);
  uint64_t scratch_len = asmp_deflate_raw_auto_dynamic_probe_scratch_size();
  size_t dec_cap = case_data->len + 64;
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  uint8_t *decoded = calloc(dec_cap, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !decoded || !scratch) {
    fprintf(stderr, "asmp-auto-dynamic-probe/%s: allocation failed\n",
            case_data->name);
    return 1;
  }

  uint64_t clen = 0;
  uint64_t checksum = 0;
  uint64_t start = now_ns();
  for (int i = 0; i < iterations; i++) {
    clen = 0;
    int status = asmp_deflate_raw_auto_dynamic_probe(
        compressed,
        out_cap,
        &clen,
        case_data->data,
        (uint64_t)case_data->len,
        scratch,
        scratch_len);
    if (status != ASMP_DEFLATE_OK || clen == 0 || clen > out_cap) {
      uint64_t elapsed = now_ns() - start;
      print_result("asmp-046-auto-dynamic-probe",
                   case_data->name,
                   "fail",
                   case_data->len,
                   clen,
                   elapsed,
                   i + 1,
                   checksum);
      free(compressed);
      free(decoded);
      free(scratch);
      return 1;
    }
    checksum = sample_checksum(checksum, compressed, clen, i);
  }
  uint64_t elapsed = now_ns() - start;

  int failed = verify_raw_deflate("asmp-046-auto-dynamic-probe",
                                  case_data->name,
                                  compressed,
                                  clen,
                                  case_data->data,
                                  case_data->len,
                                  decoded,
                                  dec_cap);
  print_result("asmp-046-auto-dynamic-probe",
               case_data->name,
               failed ? "fail" : "ok",
               case_data->len,
               clen,
               elapsed,
               iterations,
               checksum);

  free(compressed);
  free(decoded);
  free(scratch);
  return failed;
}

static int run_auto_dynamic_cost_probe_case(const case_info *case_data,
                                            int iterations) {
  uint64_t out_cap =
      asmp_deflate_raw_auto_dynamic_cost_probe_bound((uint64_t)case_data->len);
  uint64_t scratch_len =
      asmp_deflate_raw_auto_dynamic_cost_probe_scratch_size();
  size_t dec_cap = case_data->len + 64;
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  uint8_t *decoded = calloc(dec_cap, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !decoded || !scratch) {
    fprintf(stderr, "asmp-auto-dynamic-cost-probe/%s: allocation failed\n",
            case_data->name);
    return 1;
  }

  uint64_t clen = 0;
  uint64_t checksum = 0;
  uint64_t start = now_ns();
  for (int i = 0; i < iterations; i++) {
    clen = 0;
    int status = asmp_deflate_raw_auto_dynamic_cost_probe(
        compressed,
        out_cap,
        &clen,
        case_data->data,
        (uint64_t)case_data->len,
        scratch,
        scratch_len);
    if (status != ASMP_DEFLATE_OK || clen == 0 || clen > out_cap) {
      uint64_t elapsed = now_ns() - start;
      print_result("asmp-047-auto-dynamic-cost-probe",
                   case_data->name,
                   "fail",
                   case_data->len,
                   clen,
                   elapsed,
                   i + 1,
                   checksum);
      free(compressed);
      free(decoded);
      free(scratch);
      return 1;
    }
    checksum = sample_checksum(checksum, compressed, clen, i);
  }
  uint64_t elapsed = now_ns() - start;

  int failed = verify_raw_deflate("asmp-047-auto-dynamic-cost-probe",
                                  case_data->name,
                                  compressed,
                                  clen,
                                  case_data->data,
                                  case_data->len,
                                  decoded,
                                  dec_cap);
  print_result("asmp-047-auto-dynamic-cost-probe",
               case_data->name,
               failed ? "fail" : "ok",
               case_data->len,
               clen,
               elapsed,
               iterations,
               checksum);

  free(compressed);
  free(decoded);
  free(scratch);
  return failed;
}

static int run_auto_dynamic_size_probe_case(const case_info *case_data,
                                            int iterations) {
  uint64_t out_cap =
      asmp_deflate_raw_auto_dynamic_size_probe_bound((uint64_t)case_data->len);
  uint64_t scratch_len =
      asmp_deflate_raw_auto_dynamic_size_probe_scratch_size();
  size_t dec_cap = case_data->len + 64;
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  uint8_t *decoded = calloc(dec_cap, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !decoded || !scratch) {
    fprintf(stderr, "asmp-auto-dynamic-size-probe/%s: allocation failed\n",
            case_data->name);
    return 1;
  }

  uint64_t clen = 0;
  uint64_t checksum = 0;
  uint64_t start = now_ns();
  for (int i = 0; i < iterations; i++) {
    clen = 0;
    int status = asmp_deflate_raw_auto_dynamic_size_probe(
        compressed,
        out_cap,
        &clen,
        case_data->data,
        (uint64_t)case_data->len,
        scratch,
        scratch_len);
    if (status != ASMP_DEFLATE_OK || clen == 0 || clen > out_cap) {
      uint64_t elapsed = now_ns() - start;
      print_result("asmp-048-auto-dynamic-size-probe",
                   case_data->name,
                   "fail",
                   case_data->len,
                   clen,
                   elapsed,
                   i + 1,
                   checksum);
      free(compressed);
      free(decoded);
      free(scratch);
      return 1;
    }
    checksum = sample_checksum(checksum, compressed, clen, i);
  }
  uint64_t elapsed = now_ns() - start;

  int failed = verify_raw_deflate("asmp-048-auto-dynamic-size-probe",
                                  case_data->name,
                                  compressed,
                                  clen,
                                  case_data->data,
                                  case_data->len,
                                  decoded,
                                  dec_cap);
  print_result("asmp-048-auto-dynamic-size-probe",
               case_data->name,
               failed ? "fail" : "ok",
               case_data->len,
               clen,
               elapsed,
               iterations,
               checksum);

  free(compressed);
  free(decoded);
  free(scratch);
  return failed;
}

static int run_auto_dynamic_prepared_size_probe_case(const case_info *case_data,
                                                     int iterations) {
  uint64_t out_cap =
      asmp_deflate_raw_auto_dynamic_prepared_size_probe_bound((uint64_t)case_data->len);
  uint64_t scratch_len =
      asmp_deflate_raw_auto_dynamic_prepared_size_probe_scratch_size();
  size_t dec_cap = case_data->len + 64;
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  uint8_t *decoded = calloc(dec_cap, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !decoded || !scratch) {
    fprintf(stderr, "asmp-auto-dynamic-prepared-size-probe/%s: allocation failed\n",
            case_data->name);
    return 1;
  }

  uint64_t clen = 0;
  uint64_t checksum = 0;
  uint64_t start = now_ns();
  for (int i = 0; i < iterations; i++) {
    clen = 0;
    int status = asmp_deflate_raw_auto_dynamic_prepared_size_probe(
        compressed,
        out_cap,
        &clen,
        case_data->data,
        (uint64_t)case_data->len,
        scratch,
        scratch_len);
    if (status != ASMP_DEFLATE_OK || clen == 0 || clen > out_cap) {
      uint64_t elapsed = now_ns() - start;
      print_result("asmp-049-auto-dynamic-prepared-size-probe",
                   case_data->name,
                   "fail",
                   case_data->len,
                   clen,
                   elapsed,
                   i + 1,
                   checksum);
      free(compressed);
      free(decoded);
      free(scratch);
      return 1;
    }
    checksum = sample_checksum(checksum, compressed, clen, i);
  }
  uint64_t elapsed = now_ns() - start;

  int failed = verify_raw_deflate("asmp-049-auto-dynamic-prepared-size-probe",
                                  case_data->name,
                                  compressed,
                                  clen,
                                  case_data->data,
                                  case_data->len,
                                  decoded,
                                  dec_cap);
  print_result("asmp-049-auto-dynamic-prepared-size-probe",
               case_data->name,
               failed ? "fail" : "ok",
               case_data->len,
               clen,
               elapsed,
               iterations,
               checksum);

  free(compressed);
  free(decoded);
  free(scratch);
  return failed;
}

static int run_auto_dynamic_cheap_prepared_size_probe_case(const case_info *case_data,
                                                           int iterations) {
  uint64_t out_cap =
      asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_bound((uint64_t)case_data->len);
  uint64_t scratch_len =
      asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_scratch_size();
  size_t dec_cap = case_data->len + 64;
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  uint8_t *decoded = calloc(dec_cap, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !decoded || !scratch) {
    fprintf(stderr, "asmp-auto-dynamic-cheap-prepared-size-probe/%s: allocation failed\n",
            case_data->name);
    return 1;
  }

  uint64_t clen = 0;
  uint64_t checksum = 0;
  uint64_t start = now_ns();
  for (int i = 0; i < iterations; i++) {
    clen = 0;
    int status = asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe(
        compressed,
        out_cap,
        &clen,
        case_data->data,
        (uint64_t)case_data->len,
        scratch,
        scratch_len);
    if (status != ASMP_DEFLATE_OK || clen == 0 || clen > out_cap) {
      uint64_t elapsed = now_ns() - start;
      print_result("asmp-050-auto-dynamic-cheap-prepared-size-probe",
                   case_data->name,
                   "fail",
                   case_data->len,
                   clen,
                   elapsed,
                   i + 1,
                   checksum);
      free(compressed);
      free(decoded);
      free(scratch);
      return 1;
    }
    checksum = sample_checksum(checksum, compressed, clen, i);
  }
  uint64_t elapsed = now_ns() - start;

  int failed = verify_raw_deflate("asmp-050-auto-dynamic-cheap-prepared-size-probe",
                                  case_data->name,
                                  compressed,
                                  clen,
                                  case_data->data,
                                  case_data->len,
                                  decoded,
                                  dec_cap);
  print_result("asmp-050-auto-dynamic-cheap-prepared-size-probe",
               case_data->name,
               failed ? "fail" : "ok",
               case_data->len,
               clen,
               elapsed,
               iterations,
               checksum);

  free(compressed);
  free(decoded);
  free(scratch);
  return failed;
}

static int run_blocked_fixed_case(const case_info *case_data, int iterations) {
  uint64_t out_cap = asmp_deflate_raw_blocked_fixed_bound((uint64_t)case_data->len);
  uint64_t scratch_len = asmp_deflate_raw_blocked_fixed_scratch_size();
  size_t dec_cap = case_data->len + 64;
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  uint8_t *decoded = calloc(dec_cap, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !decoded || !scratch) {
    fprintf(stderr, "asmp-blocked-fixed/%s: allocation failed\n", case_data->name);
    return 1;
  }

  uint64_t clen = 0;
  uint64_t checksum = 0;
  uint64_t start = now_ns();
  for (int i = 0; i < iterations; i++) {
    clen = 0;
    int status = asmp_deflate_raw_blocked_fixed(compressed,
                                                out_cap,
                                                &clen,
                                                case_data->data,
                                                (uint64_t)case_data->len,
                                                scratch,
                                                scratch_len);
    if (status != ASMP_DEFLATE_OK || clen == 0 || clen > out_cap) {
      uint64_t elapsed = now_ns() - start;
      print_result("asmp-051-blocked-fixed",
                   case_data->name,
                   "fail",
                   case_data->len,
                   clen,
                   elapsed,
                   i + 1,
                   checksum);
      free(compressed);
      free(decoded);
      free(scratch);
      return 1;
    }
    checksum = sample_checksum(checksum, compressed, clen, i);
  }
  uint64_t elapsed = now_ns() - start;

  int failed = verify_raw_deflate("asmp-051-blocked-fixed",
                                  case_data->name,
                                  compressed,
                                  clen,
                                  case_data->data,
                                  case_data->len,
                                  decoded,
                                  dec_cap);
  print_result("asmp-051-blocked-fixed",
               case_data->name,
               failed ? "fail" : "ok",
               case_data->len,
               clen,
               elapsed,
               iterations,
               checksum);

  free(compressed);
  free(decoded);
  free(scratch);
  return failed;
}

static int run_blocked_auto_case(const case_info *case_data, int iterations) {
  uint64_t out_cap = asmp_deflate_raw_blocked_auto_bound((uint64_t)case_data->len);
  uint64_t scratch_len = asmp_deflate_raw_blocked_auto_scratch_size();
  size_t dec_cap = case_data->len + 64;
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  uint8_t *decoded = calloc(dec_cap, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !decoded || !scratch) {
    fprintf(stderr, "asmp-blocked-auto/%s: allocation failed\n", case_data->name);
    return 1;
  }

  uint64_t clen = 0;
  uint64_t checksum = 0;
  uint64_t start = now_ns();
  for (int i = 0; i < iterations; i++) {
    clen = 0;
    int status = asmp_deflate_raw_blocked_auto(compressed,
                                               out_cap,
                                               &clen,
                                               case_data->data,
                                               (uint64_t)case_data->len,
                                               scratch,
                                               scratch_len);
    if (status != ASMP_DEFLATE_OK || clen == 0 || clen > out_cap) {
      uint64_t elapsed = now_ns() - start;
      print_result("asmp-052-blocked-auto",
                   case_data->name,
                   "fail",
                   case_data->len,
                   clen,
                   elapsed,
                   i + 1,
                   checksum);
      free(compressed);
      free(decoded);
      free(scratch);
      return 1;
    }
    checksum = sample_checksum(checksum, compressed, clen, i);
  }
  uint64_t elapsed = now_ns() - start;

  int failed = verify_raw_deflate("asmp-052-blocked-auto",
                                  case_data->name,
                                  compressed,
                                  clen,
                                  case_data->data,
                                  case_data->len,
                                  decoded,
                                  dec_cap);
  print_result("asmp-052-blocked-auto",
               case_data->name,
               failed ? "fail" : "ok",
               case_data->len,
               clen,
               elapsed,
               iterations,
               checksum);

  free(compressed);
  free(decoded);
  free(scratch);
  return failed;
}

static int run_blocked_dynamic_auto_case(const case_info *case_data,
                                         int iterations) {
  uint64_t out_cap =
      asmp_deflate_raw_blocked_dynamic_auto_bound((uint64_t)case_data->len);
  uint64_t scratch_len =
      asmp_deflate_raw_blocked_dynamic_auto_scratch_size();
  size_t dec_cap = case_data->len + 64;
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  uint8_t *decoded = calloc(dec_cap, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !decoded || !scratch) {
    fprintf(stderr, "asmp-blocked-dynamic-auto/%s: allocation failed\n",
            case_data->name);
    return 1;
  }

  uint64_t clen = 0;
  uint64_t checksum = 0;
  uint64_t start = now_ns();
  for (int i = 0; i < iterations; i++) {
    clen = 0;
    int status = asmp_deflate_raw_blocked_dynamic_auto(
        compressed,
        out_cap,
        &clen,
        case_data->data,
        (uint64_t)case_data->len,
        scratch,
        scratch_len);
    if (status != ASMP_DEFLATE_OK || clen == 0 || clen > out_cap) {
      uint64_t elapsed = now_ns() - start;
      print_result("asmp-053-blocked-dynamic-auto",
                   case_data->name,
                   "fail",
                   case_data->len,
                   clen,
                   elapsed,
                   i + 1,
                   checksum);
      free(compressed);
      free(decoded);
      free(scratch);
      return 1;
    }
    checksum = sample_checksum(checksum, compressed, clen, i);
  }
  uint64_t elapsed = now_ns() - start;

  int failed = verify_raw_deflate("asmp-053-blocked-dynamic-auto",
                                  case_data->name,
                                  compressed,
                                  clen,
                                  case_data->data,
                                  case_data->len,
                                  decoded,
                                  dec_cap);
  print_result("asmp-053-blocked-dynamic-auto",
               case_data->name,
               failed ? "fail" : "ok",
               case_data->len,
               clen,
               elapsed,
               iterations,
               checksum);

  free(compressed);
  free(decoded);
  free(scratch);
  return failed;
}

static int run_stored_case(const case_info *case_data, int iterations) {
  uint64_t out_cap = asmp_deflate_raw_bound((uint64_t)case_data->len);
  size_t dec_cap = case_data->len + 64;
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  uint8_t *decoded = calloc(dec_cap, 1);
  if (!compressed || !decoded) {
    fprintf(stderr, "asmp-stored/%s: allocation failed\n", case_data->name);
    return 1;
  }

  uint64_t clen = 0;
  uint64_t checksum = 0;
  uint64_t start = now_ns();
  for (int i = 0; i < iterations; i++) {
    clen = 0;
    int status = asmp_deflate_raw_stored(compressed,
                                         out_cap,
                                         &clen,
                                         case_data->data,
                                         (uint64_t)case_data->len);
    if (status != ASMP_DEFLATE_OK || clen == 0 || clen > out_cap) {
      uint64_t elapsed = now_ns() - start;
      print_result("asmp-stored-public",
                   case_data->name,
                   "fail",
                   case_data->len,
                   clen,
                   elapsed,
                   i + 1,
                   checksum);
      free(compressed);
      free(decoded);
      return 1;
    }
    checksum = sample_checksum(checksum, compressed, clen, i);
  }
  uint64_t elapsed = now_ns() - start;

  int failed = verify_raw_deflate("asmp-stored-public",
                                  case_data->name,
                                  compressed,
                                  clen,
                                  case_data->data,
                                  case_data->len,
                                  decoded,
                                  dec_cap);
  print_result("asmp-stored-public",
               case_data->name,
               failed ? "fail" : "ok",
               case_data->len,
               clen,
               elapsed,
               iterations,
               checksum);

  free(compressed);
  free(decoded);
  return failed;
}

static int run_auto_case(const case_info *case_data, int iterations) {
  uint64_t out_cap = asmp_deflate_raw_bound((uint64_t)case_data->len);
  uint64_t scratch_len = asmp_deflate_raw_scratch_size();
  size_t dec_cap = case_data->len + 64;
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  uint8_t *decoded = calloc(dec_cap, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !decoded || !scratch) {
    fprintf(stderr, "asmp-auto/%s: allocation failed\n", case_data->name);
    return 1;
  }

  uint64_t clen = 0;
  uint64_t checksum = 0;
  uint64_t start = now_ns();
  for (int i = 0; i < iterations; i++) {
    clen = 0;
    int status = asmp_deflate_raw_auto(compressed,
                                       out_cap,
                                       &clen,
                                       case_data->data,
                                       (uint64_t)case_data->len,
                                       scratch,
                                       scratch_len);
    if (status != ASMP_DEFLATE_OK || clen == 0 || clen > out_cap) {
      uint64_t elapsed = now_ns() - start;
      print_result("asmp-auto-public",
                   case_data->name,
                   "fail",
                   case_data->len,
                   clen,
                   elapsed,
                   i + 1,
                   checksum);
      free(compressed);
      free(decoded);
      free(scratch);
      return 1;
    }
    checksum = sample_checksum(checksum, compressed, clen, i);
  }
  uint64_t elapsed = now_ns() - start;

  int failed = verify_raw_deflate("asmp-auto-public",
                                  case_data->name,
                                  compressed,
                                  clen,
                                  case_data->data,
                                  case_data->len,
                                  decoded,
                                  dec_cap);
  print_result("asmp-auto-public",
               case_data->name,
               failed ? "fail" : "ok",
               case_data->len,
               clen,
               elapsed,
               iterations,
               checksum);

  free(compressed);
  free(decoded);
  free(scratch);
  return failed;
}

static int zlib_fixed_once(uint8_t *compressed,
                           uint64_t out_cap,
                           uint64_t *clen,
                           const uint8_t *src,
                           size_t len) {
  z_stream zs;
  memset(&zs, 0, sizeof(zs));
  int zr = deflateInit2(&zs, 1, Z_DEFLATED, -MAX_WBITS, 8, Z_FIXED);
  if (zr != Z_OK) {
    return zr;
  }

  zs.next_in = (Bytef *)src;
  zs.avail_in = (uInt)len;
  zs.next_out = compressed;
  zs.avail_out = (uInt)out_cap;
  zr = deflate(&zs, Z_FINISH);
  if (zr == Z_STREAM_END) {
    *clen = zs.total_out;
    zr = Z_OK;
  }
  deflateEnd(&zs);
  return zr;
}

static int run_zlib_case(const case_info *case_data, int iterations) {
  uint64_t out_cap = (uint64_t)case_data->len * 2ull + 4096ull;
  size_t dec_cap = case_data->len + 64;
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  uint8_t *decoded = calloc(dec_cap, 1);
  if (!compressed || !decoded) {
    fprintf(stderr, "zlib/%s: allocation failed\n", case_data->name);
    return 1;
  }

  uint64_t clen = 0;
  uint64_t checksum = 0;
  uint64_t start = now_ns();
  for (int i = 0; i < iterations; i++) {
    int status = zlib_fixed_once(compressed,
                                 out_cap,
                                 &clen,
                                 case_data->data,
                                 case_data->len);
    if (status != Z_OK || clen == 0 || clen > out_cap) {
      uint64_t elapsed = now_ns() - start;
      print_result("zlib-fixed-l1",
                   case_data->name,
                   "fail",
                   case_data->len,
                   clen,
                   elapsed,
                   i + 1,
                   checksum);
      free(compressed);
      free(decoded);
      return 1;
    }
    checksum = sample_checksum(checksum, compressed, clen, i);
  }
  uint64_t elapsed = now_ns() - start;

  int failed = verify_raw_deflate("zlib-fixed-l1",
                                  case_data->name,
                                  compressed,
                                  clen,
                                  case_data->data,
                                  case_data->len,
                                  decoded,
                                  dec_cap);
  print_result("zlib-fixed-l1",
               case_data->name,
               failed ? "fail" : "ok",
               case_data->len,
               clen,
               elapsed,
               iterations,
               checksum);

  free(compressed);
  free(decoded);
  return failed;
}

int main(int argc, char **argv) {
  int iterations = 20;
  if (argc > 1) {
    iterations = atoi(argv[1]);
    if (iterations <= 0) {
      iterations = 1;
    }
  }

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

  static uint8_t randomish[8192];
  uint32_t rng = 0x12345678u;
  for (size_t i = 0; i < sizeof(randomish); i++) {
    rng ^= rng << 13;
    rng ^= rng >> 17;
    rng ^= rng << 5;
    randomish[i] = (uint8_t)(rng >> 24);
  }

  const case_info cases[] = {
      {"empty", empty, 0},
      {"small", small, sizeof(small) - 1},
      {"text", text, sizeof(text) - 1},
      {"repeated", repeated, sizeof(repeated)},
      {"period257", period257, sizeof(period257)},
      {"binary", binary, sizeof(binary)},
      {"long-repeat", long_repeat, sizeof(long_repeat)},
      {"high-literals", high_literals, sizeof(high_literals)},
      {"randomish", randomish, sizeof(randomish)},
  };

  printf("codec,case,status,input_bytes,compressed_bytes,ratio,ns_per_iter,mib_per_s,sample_checksum\n");
  for (size_t ci = 0; ci < sizeof(cases) / sizeof(cases[0]); ci++) {
    if (run_asmp_case(&cases[ci], iterations)) {
      return 1;
    }
    if (run_blocked_fixed_case(&cases[ci], iterations)) {
      return 1;
    }
    if (run_blocked_auto_case(&cases[ci], iterations)) {
      return 1;
    }
    if (run_blocked_dynamic_auto_case(&cases[ci], iterations)) {
      return 1;
    }
    if (run_wordextend_case(&cases[ci], iterations)) {
      return 1;
    }
    if (run_neonextend_case(&cases[ci], iterations)) {
      return 1;
    }
    if (run_stored_case(&cases[ci], iterations)) {
      return 1;
    }
    if (run_auto_case(&cases[ci], iterations)) {
      return 1;
    }
    if (run_dynamic_lz77_huffman_case(&cases[ci], iterations)) {
      return 1;
    }
    if (run_auto_dynamic_probe_case(&cases[ci], iterations)) {
      return 1;
    }
    if (run_auto_dynamic_cost_probe_case(&cases[ci], iterations)) {
      return 1;
    }
    if (run_auto_dynamic_size_probe_case(&cases[ci], iterations)) {
      return 1;
    }
    if (run_auto_dynamic_prepared_size_probe_case(&cases[ci], iterations)) {
      return 1;
    }
    if (run_auto_dynamic_cheap_prepared_size_probe_case(&cases[ci], iterations)) {
      return 1;
    }
    if (run_zlib_case(&cases[ci], iterations)) {
      return 1;
    }
  }
  return 0;
}
C
  )

(define runtime-harness-source
  #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <zlib.h>

#include "asmp_runtime_dispatch.h"

extern void asmp_deflate_runtime_set_features(uint64_t features);

enum {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_DST_TOO_SMALL = 1,
  ASMP_DEFLATE_SCRATCH_TOO_SMALL = 2,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};

typedef struct {
  const char *name;
  const uint8_t *data;
  size_t len;
} case_info;

static uint64_t now_ns(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}

static double mib_per_second(size_t input_len, double ns_per_iter) {
  if (input_len == 0 || ns_per_iter <= 0.0) {
    return 0.0;
  }
  return ((double)input_len * 1000000000.0) / (ns_per_iter * 1048576.0);
}

static uint64_t sample_checksum(uint64_t checksum,
                                const uint8_t *compressed,
                                uint64_t clen,
                                int iter) {
  uint64_t first = clen == 0 ? 0 : compressed[0];
  uint64_t last = clen == 0 ? 0 : compressed[clen - 1];
  checksum ^= 0x9e3779b97f4a7c15ull + (checksum << 6) + (checksum >> 2);
  return checksum + clen + (first << 8) + (last << 32) + (uint64_t)iter;
}

static int verify_raw_deflate(const char *codec,
                              const char *case_name,
                              const uint8_t *compressed,
                              uint64_t clen,
                              const uint8_t *src,
                              size_t len,
                              uint8_t *decoded,
                              size_t dec_cap) {
  z_stream zs;
  memset(&zs, 0, sizeof(zs));
  int zr = inflateInit2(&zs, -MAX_WBITS);
  if (zr != Z_OK) {
    fprintf(stderr, "%s/%s: inflateInit2 failed: %d\n", codec, case_name, zr);
    return 1;
  }

  zs.next_in = (Bytef *)compressed;
  zs.avail_in = (uInt)clen;
  zs.next_out = decoded;
  zs.avail_out = (uInt)dec_cap;
  zr = inflate(&zs, Z_FINISH);
  if (zr != Z_STREAM_END) {
    fprintf(stderr,
            "%s/%s: inflate failed: %d total_out=%lu total_in=%lu clen=%llu\n",
            codec,
            case_name,
            zr,
            (unsigned long)zs.total_out,
            (unsigned long)zs.total_in,
            (unsigned long long)clen);
    inflateEnd(&zs);
    return 1;
  }
  inflateEnd(&zs);

  if (zs.total_out != len || memcmp(decoded, src, len) != 0) {
    fprintf(stderr,
            "%s/%s: mismatch total_out=%lu expected=%zu clen=%llu\n",
            codec,
            case_name,
            (unsigned long)zs.total_out,
            len,
            (unsigned long long)clen);
    return 1;
  }
  return 0;
}

static void print_result(const char *codec,
                         const char *case_name,
                         const char *status,
                         size_t input_len,
                         uint64_t clen,
                         uint64_t elapsed,
                         int iterations,
                         uint64_t checksum) {
  double ratio = input_len == 0 ? 0.0 : (double)clen / (double)input_len;
  double ns_per_iter = (double)elapsed / (double)iterations;
  printf("%s,%s,%s,%zu,%llu,%.6f,%.1f,%.3f,%llu\n",
         codec,
         case_name,
         status,
         input_len,
         (unsigned long long)clen,
         ratio,
         ns_per_iter,
         mib_per_second(input_len, ns_per_iter),
         (unsigned long long)checksum);
  fflush(stdout);
}

static int run_runtime_fixed_case(const char *codec,
                                  uint64_t features,
                                  const case_info *case_data,
                                  int iterations) {
  asmp_deflate_runtime_set_features(features);

  uint64_t out_cap = asmp_deflate_raw_bound((uint64_t)case_data->len);
  uint64_t scratch_len = asmp_deflate_raw_scratch_size();
  size_t dec_cap = case_data->len + 64;
  uint8_t *compressed = calloc((size_t)out_cap, 1);
  uint8_t *decoded = calloc(dec_cap, 1);
  void *scratch = calloc((size_t)scratch_len, 1);
  if (!compressed || !decoded || !scratch) {
    fprintf(stderr, "%s/%s: allocation failed\n", codec, case_data->name);
    return 1;
  }

  uint64_t clen = 0;
  uint64_t checksum = 0;
  uint64_t start = now_ns();
  for (int i = 0; i < iterations; i++) {
    clen = 0;
    int status = asmp_deflate_raw_fixed(compressed,
                                        out_cap,
                                        &clen,
                                        case_data->data,
                                        (uint64_t)case_data->len,
                                        scratch,
                                        scratch_len);
    if (status != ASMP_DEFLATE_OK || clen == 0 || clen > out_cap) {
      uint64_t elapsed = now_ns() - start;
      print_result(codec,
                   case_data->name,
                   "fail",
                   case_data->len,
                   clen,
                   elapsed,
                   i + 1,
                   checksum);
      free(compressed);
      free(decoded);
      free(scratch);
      return 1;
    }
    checksum = sample_checksum(checksum, compressed, clen, i);
  }
  uint64_t elapsed = now_ns() - start;

  int failed = verify_raw_deflate(codec,
                                  case_data->name,
                                  compressed,
                                  clen,
                                  case_data->data,
                                  case_data->len,
                                  decoded,
                                  dec_cap);
  print_result(codec,
               case_data->name,
               failed ? "fail" : "ok",
               case_data->len,
               clen,
               elapsed,
               iterations,
               checksum);

  free(compressed);
  free(decoded);
  free(scratch);
  return failed;
}

int main(int argc, char **argv) {
  int iterations = 20;
  if (argc > 1) {
    iterations = atoi(argv[1]);
    if (iterations <= 0) {
      iterations = 1;
    }
  }

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

  static uint8_t randomish[8192];
  uint32_t rng = 0x12345678u;
  for (size_t i = 0; i < sizeof(randomish); i++) {
    rng ^= rng << 13;
    rng ^= rng >> 17;
    rng ^= rng << 5;
    randomish[i] = (uint8_t)(rng >> 24);
  }

  const case_info cases[] = {
      {"empty", empty, 0},
      {"small", small, sizeof(small) - 1},
      {"text", text, sizeof(text) - 1},
      {"repeated", repeated, sizeof(repeated)},
      {"period257", period257, sizeof(period257)},
      {"binary", binary, sizeof(binary)},
      {"long-repeat", long_repeat, sizeof(long_repeat)},
      {"high-literals", high_literals, sizeof(high_literals)},
      {"randomish", randomish, sizeof(randomish)},
  };

  for (size_t ci = 0; ci < sizeof(cases) / sizeof(cases[0]); ci++) {
    if (run_runtime_fixed_case("asmp-027-runtime-word-fixed", 0, &cases[ci], iterations)) {
      return 1;
    }
    if (run_runtime_fixed_case("asmp-027-runtime-neon-fixed", 1, &cases[ci], iterations)) {
      return 1;
    }
  }
  return 0;
}
C
  )

(define (native-macos-aarch64?)
  (and (eq? (system-type 'os) 'macosx)
       (eq? (system-type 'arch) 'aarch64)))

(define (run-command exe . args)
  (define-values (proc out in err) (apply subprocess #f #f #f exe args))
  (close-output-port in)
  (define stdout (port->string out))
  (define stderr (port->string err))
  (subprocess-wait proc)
  (define status (subprocess-status proc))
  (display stdout)
  (display stderr (current-error-port))
  (unless (zero? status)
    (error 'bench-native "command failed with status ~a: ~a ~a"
           status exe args)))

(define (call-with-temp-dir proc)
  (define dir (make-temporary-file "asmp-deflate-bench-~a" 'directory))
  (dynamic-wind
    void
    (lambda () (proc dir))
    (lambda () (delete-directory/files dir))))

(define (build-deflate-asm dir)
  (define asm-path (build-path dir "019-fixed-chain.s"))
  (define word-extend-asm-path (build-path dir "023-word-extend.s"))
  (define neon-extend-asm-path (build-path dir "024-neon-extend.s"))
  (define header-path (build-path dir "asmp_deflate.h"))
  (run-command (find-executable-path "racket")
               cli-source
               "--gnu-input"
               "--apple"
               "--elim"
               "--public-c-header"
               header-path
               "-o"
               asm-path
               deflate-source)
  (run-command (find-executable-path "racket")
               cli-source
               "--gnu-input"
               "--apple"
               "--elim"
               "-o"
               word-extend-asm-path
               deflate-word-extend-source)
  (run-command (find-executable-path "racket")
               cli-source
               "--gnu-input"
               "--apple"
               "--elim"
               "-o"
               neon-extend-asm-path
               deflate-neon-extend-source)
  (values asm-path word-extend-asm-path neon-extend-asm-path header-path))

(define (build-runtime-dispatch-asm dir)
  (define runtime-dispatch-asm-path (build-path dir "027-runtime-dispatch.s"))
  (define runtime-header-path (build-path dir "asmp_runtime_dispatch.h"))
  (run-command (find-executable-path "racket")
               cli-source
               "--gnu-input"
               "--apple"
               "--elim"
               "--public-c-header"
               runtime-header-path
               "-o"
               runtime-dispatch-asm-path
               deflate-runtime-dispatch-source)
  (values runtime-dispatch-asm-path runtime-header-path))

(define (build-dynamic-lz77-huffman-asm dir)
  (define sources
    `(("028-canonical.s" . ,dynamic-canonical-source)
      ("029-reverse.s" . ,dynamic-reverse-source)
      ("031-rle.s" . ,dynamic-rle-source)
      ("032-blfreq.s" . ,dynamic-blfreq-source)
      ("037-code-counts.s" . ,dynamic-code-counts-source)
      ("039-litlen-huffman.s" . ,dynamic-litlen-huffman-source)
      ("041-bllen-huffman.s" . ,dynamic-bllen-huffman-source)
      ("043-lz77-freq.s" . ,dynamic-lz77-freq-source)
      ("044-distlen-huffman.s" . ,dynamic-distlen-huffman-source)
      ("045-lz77-huffman.s" . ,dynamic-lz77-huffman-source)
      ("046-auto-dynamic-probe.s" . ,dynamic-auto-probe-source)
      ("047-auto-dynamic-cost-probe.s" . ,dynamic-auto-cost-probe-source)
      ("048-auto-dynamic-size-probe.s" . ,dynamic-auto-size-probe-source)
      ("049-auto-dynamic-prepared-size-probe.s" . ,dynamic-auto-prepared-size-probe-source)
      ("050-auto-dynamic-cheap-prepared-size-probe.s" . ,dynamic-auto-cheap-prepared-size-probe-source)
      ("051-blocked-fixed.s" . ,blocked-fixed-source)
      ("052-blocked-auto.s" . ,blocked-auto-source)
      ("053-blocked-dynamic-auto.s" . ,blocked-dynamic-auto-source)))
  (for/list ([source (in-list sources)])
    (define asm-path (build-path dir (car source)))
    (run-command (find-executable-path "racket")
                 cli-source
                 "--gnu-input"
                 "--apple"
                 "--elim"
                 "-o"
                 asm-path
                 (cdr source))
    asm-path))

(define (run-benchmark iterations)
  (unless (native-macos-aarch64?)
    (printf "native benchmark is currently macOS arm64 only; host is ~a/~a\n"
            (system-type 'os)
            (system-type 'arch))
    (exit 0))
  (unless (find-executable-path "clang")
    (printf "native benchmark skipped: clang not found\n")
    (exit 0))
  (call-with-temp-dir
   (lambda (dir)
     (define-values (asm-path word-extend-asm-path neon-extend-asm-path header-path)
       (build-deflate-asm dir))
     (define-values (runtime-dispatch-asm-path runtime-header-path)
       (build-runtime-dispatch-asm dir))
     (define dynamic-asm-paths (build-dynamic-lz77-huffman-asm dir))
     (define harness-path (build-path dir "bench.c"))
     (define runtime-harness-path (build-path dir "bench-runtime.c"))
     (define exe-path (build-path dir "bench"))
     (define runtime-exe-path (build-path dir "bench-runtime"))
     (call-with-output-file harness-path
       #:exists 'truncate/replace
       (lambda (out) (display harness-source out)))
     (call-with-output-file runtime-harness-path
       #:exists 'truncate/replace
       (lambda (out) (display runtime-harness-source out)))
     (apply run-command
            (find-executable-path "clang")
            "-O2"
            harness-path
            asm-path
            word-extend-asm-path
            neon-extend-asm-path
            (append dynamic-asm-paths
                    (list "-I"
                          dir
                          "-lz"
                          "-o"
                          exe-path)))
     (run-command exe-path (number->string iterations))
     (run-command (find-executable-path "clang")
                  "-O2"
                  runtime-harness-path
                  word-extend-asm-path
                  neon-extend-asm-path
                  runtime-dispatch-asm-path
                  "-I"
                  dir
                  "-lz"
                  "-o"
                  runtime-exe-path)
     (run-command runtime-exe-path (number->string iterations)))))

(module+ main
  (define iterations 20)
  (command-line
   #:program "bench-native.rkt"
   #:once-each
   [("--iterations") n "Number of encode iterations per codec/case"
                     (set! iterations (string->number n))]
   #:args ()
   (unless (and (integer? iterations) (positive? iterations))
     (error 'bench-native "iterations must be a positive integer"))
   (run-benchmark iterations)))
