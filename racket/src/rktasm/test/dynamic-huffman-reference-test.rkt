#lang racket

(require rackunit
         rackunit/text-ui
         racket/file
         racket/list
         racket/runtime-path
         "../research/deflate-optimization/dynamic-huffman-reference.rkt")

(define-runtime-path cli-source "../cli/as.rkt")
(define-runtime-path dynamic-litonly-source "../example/020-deflate-dynamic-litonly.asm")
(define-runtime-path dynamic-litfreq-source "../example/021-deflate-dynamic-litfreq.asm")
(define-runtime-path dynamic-litlen-source "../example/022-deflate-dynamic-litlen-balanced.asm")
(define-runtime-path dynamic-canonical-source "../example/028-deflate-dynamic-canonical-codes.asm")
(define-runtime-path dynamic-reverse-source "../example/029-deflate-dynamic-reverse-codes.asm")
(define-runtime-path dynamic-balanced-source "../example/030-deflate-dynamic-balanced-litonly.asm")
(define-runtime-path dynamic-rle-source "../example/031-deflate-dynamic-code-length-rle.asm")
(define-runtime-path dynamic-blfreq-source "../example/032-deflate-dynamic-blfreq.asm")
(define-runtime-path dynamic-bllen-source "../example/033-deflate-dynamic-bllen-balanced.asm")
(define-runtime-path dynamic-blcodes-source "../example/034-deflate-dynamic-blcodes-count.asm")
(define-runtime-path dynamic-compact-header-source "../example/035-deflate-dynamic-compact-header.asm")
(define-runtime-path dynamic-compact-balanced-source "../example/036-deflate-dynamic-compact-balanced-litonly.asm")
(define-runtime-path dynamic-code-counts-source "../example/037-deflate-dynamic-code-counts.asm")
(define-runtime-path dynamic-compact-trimmed-source "../example/038-deflate-dynamic-compact-trimmed-litonly.asm")
(define-runtime-path dynamic-litlen-huffman-source "../example/039-deflate-dynamic-litlen-huffman.asm")
(define-runtime-path dynamic-compact-huffman-source "../example/040-deflate-dynamic-compact-huffman-litonly.asm")
(define-runtime-path dynamic-bllen-huffman-source "../example/041-deflate-dynamic-bllen-huffman.asm")
(define-runtime-path dynamic-compact-dual-huffman-source "../example/042-deflate-dynamic-compact-dual-huffman-litonly.asm")
(define-runtime-path dynamic-lz77-freq-source "../example/043-deflate-dynamic-lz77-freq.asm")
(define-runtime-path dynamic-distlen-huffman-source "../example/044-deflate-dynamic-distlen-huffman.asm")
(define-runtime-path dynamic-lz77-huffman-source "../example/045-deflate-dynamic-lz77-huffman.asm")

(define deflate-code-length-order
  '(16 17 18 0 8 7 9 6 10 5 11 4 12 3 13 2 14 1 15))

(define (byte->c-hex byte)
  (define hex (string-upcase (number->string byte 16)))
  (format "0x~a" (if (= (string-length hex) 1)
                     (string-append "0" hex)
                     hex)))

(define (bytes->c-initializer data)
  (if (zero? (bytes-length data))
      "0"
      (string-join
       (for/list ([byte (in-bytes data)])
         (byte->c-hex byte))
       ", ")))

(define (u8-list->c-initializer values)
  (if (null? values)
      "0"
      (string-join
       (for/list ([value (in-list values)])
         (byte->c-hex value))
       ", ")))

(define (u32-list->c-initializer values)
  (if (null? values)
      "0"
      (string-join
       (for/list ([value (in-list values)])
         (number->string value))
       ", ")))

(define (u16-list->c-initializer values)
  (if (null? values)
      "0"
      (string-join
       (for/list ([value (in-list values)])
         (number->string value))
       ", ")))

(define (rle-event-bytes events)
  (apply
   append
   (for/list ([event (in-list events)])
     (list (cl-event-symbol event)
           (cl-event-extra event)
           (cl-event-extra-bits event)
           0))))

(define (bl-frequencies events)
  (define freqs (make-vector 19 0))
  (for ([event (in-list events)])
    (define symbol (cl-event-symbol event))
    (vector-set! freqs symbol (add1 (vector-ref freqs symbol))))
  (vector->list freqs))

(define (balanced-bllen freqs)
  (define lengths (make-vector 19 0))
  (define active
    (for/list ([freq (in-list freqs)]
               [symbol (in-naturals)]
               #:when (positive? freq))
      symbol))
  (define active-count (length active))
  (cond
    [(zero? active-count)
     (void)]
    [(<= active-count 2)
     (for ([symbol (in-list active)])
       (vector-set! lengths symbol 1))
     (when (= active-count 1)
       (define dummy (if (positive? (list-ref freqs 0)) 1 0))
       (vector-set! lengths dummy 1))]
    [else
     (define-values (pow2 long-len)
       (let loop ([pow2 1] [bits 0])
         (if (>= pow2 active-count)
             (values pow2 bits)
             (loop (* pow2 2) (add1 bits)))))
     (define short-len (sub1 long-len))
     (define short-count (- pow2 active-count))
     (for ([symbol (in-list active)]
           [i (in-naturals)])
       (vector-set! lengths
                    symbol
                    (if (< i short-count) short-len long-len)))])
  (vector->list lengths))

(define (blcodes-count lengths)
  (max 4
       (add1
        (or (for/fold ([last #f])
                       ([symbol (in-list deflate-code-length-order)]
                        [index (in-naturals)])
              (if (positive? (list-ref lengths symbol)) index last))
            0))))

(define (bit-reverse-width value width)
  (for/fold ([result 0])
            ([i (in-range width)])
    (bitwise-ior (arithmetic-shift result 1)
                 (bitwise-and (arithmetic-shift value (- i)) 1))))

(define (bit-code-table lengths)
  (define codes (canonical-codes lengths))
  (for/list ([len (in-list lengths)]
             [symbol (in-naturals)])
    (if (zero? len)
        0
        (bit-reverse-width (car (vector-ref codes symbol)) len))))

(define (finish-bits bits)
  (define ordered (list->vector (reverse bits)))
  (define byte-count (quotient (+ (vector-length ordered) 7) 8))
  (define out (make-bytes byte-count 0))
  (for ([i (in-range (vector-length ordered))])
    (when (= (vector-ref ordered i) 1)
      (define byte-index (quotient i 8))
      (define bit-index (remainder i 8))
      (bytes-set! out byte-index
                  (bitwise-ior (bytes-ref out byte-index)
                               (arithmetic-shift 1 bit-index)))))
  out)

(define (compact-header-bytes lcodes dcodes bl-lengths bl-bit-codes events)
  (define bits '())
  (define (write-bits value width)
    (for ([i (in-range width)])
      (set! bits
            (cons (bitwise-and (arithmetic-shift value (- i)) 1)
                  bits))))
  (define blcodes (blcodes-count bl-lengths))
  (write-bits #b101 3)
  (write-bits (- lcodes 257) 5)
  (write-bits (- dcodes 1) 5)
  (write-bits (- blcodes 4) 4)
  (for ([symbol (in-list (take deflate-code-length-order blcodes))])
    (write-bits (list-ref bl-lengths symbol) 3))
  (for ([event (in-list events)])
    (define symbol (cl-event-symbol event))
    (write-bits (list-ref bl-bit-codes symbol)
                (list-ref bl-lengths symbol))
    (when (positive? (cl-event-extra-bits event))
      (write-bits (cl-event-extra event)
                  (cl-event-extra-bits event))))
  (finish-bits bits))

(define (dynamic-compact-balanced-literal-raw-deflate input)
  (unless (bytes? input)
    (raise-argument-error 'dynamic-compact-balanced-literal-raw-deflate "bytes?" input))
  (define ll-lengths (balanced-literal-lengths input))
  (define combined-lengths (append ll-lengths '(0)))
  (define events (code-length-rle-events combined-lengths))
  (define bl-freqs (bl-frequencies events))
  (define bl-lengths (balanced-bllen bl-freqs))
  (define bl-bit-codes (bit-code-table bl-lengths))
  (define ll-bit-codes (bit-code-table ll-lengths))
  (define bits '())
  (define (write-bits value width)
    (for ([i (in-range width)])
      (set! bits
            (cons (bitwise-and (arithmetic-shift value (- i)) 1)
                  bits))))
  (define blcodes (blcodes-count bl-lengths))
  (write-bits #b101 3)
  (write-bits 29 5)
  (write-bits 0 5)
  (write-bits (- blcodes 4) 4)
  (for ([symbol (in-list (take deflate-code-length-order blcodes))])
    (write-bits (list-ref bl-lengths symbol) 3))
  (for ([event (in-list events)])
    (define symbol (cl-event-symbol event))
    (write-bits (list-ref bl-bit-codes symbol)
                (list-ref bl-lengths symbol))
    (when (positive? (cl-event-extra-bits event))
      (write-bits (cl-event-extra event)
                  (cl-event-extra-bits event))))
  (for ([byte (in-bytes input)])
    (write-bits (list-ref ll-bit-codes byte)
                (list-ref ll-lengths byte)))
  (write-bits (list-ref ll-bit-codes 256)
              (list-ref ll-lengths 256))
  (finish-bits bits))

(define (trimmed-code-count lengths min-count)
  (max min-count
       (add1
        (or (for/fold ([last #f])
                       ([len (in-list lengths)]
                        [index (in-naturals)])
              (if (positive? len) index last))
            0))))

(define (dynamic-compact-balanced-trimmed-literal-raw-deflate input)
  (unless (bytes? input)
    (raise-argument-error 'dynamic-compact-balanced-trimmed-literal-raw-deflate "bytes?" input))
  (define ll-lengths (balanced-literal-lengths input))
  (define dist-lengths '(0))
  (define lcodes (trimmed-code-count ll-lengths 257))
  (define dcodes 1)
  (define combined-lengths
    (append (take ll-lengths lcodes)
            (take dist-lengths dcodes)))
  (define events (code-length-rle-events combined-lengths))
  (define bl-freqs (bl-frequencies events))
  (define bl-lengths (balanced-bllen bl-freqs))
  (define bl-bit-codes (bit-code-table bl-lengths))
  (define ll-bit-codes (bit-code-table ll-lengths))
  (define bits '())
  (define (write-bits value width)
    (for ([i (in-range width)])
      (set! bits
            (cons (bitwise-and (arithmetic-shift value (- i)) 1)
                  bits))))
  (define blcodes (blcodes-count bl-lengths))
  (write-bits #b101 3)
  (write-bits (- lcodes 257) 5)
  (write-bits (- dcodes 1) 5)
  (write-bits (- blcodes 4) 4)
  (for ([symbol (in-list (take deflate-code-length-order blcodes))])
    (write-bits (list-ref bl-lengths symbol) 3))
  (for ([event (in-list events)])
    (define symbol (cl-event-symbol event))
    (write-bits (list-ref bl-bit-codes symbol)
                (list-ref bl-lengths symbol))
    (when (positive? (cl-event-extra-bits event))
      (write-bits (cl-event-extra event)
                  (cl-event-extra-bits event))))
  (for ([byte (in-bytes input)])
    (write-bits (list-ref ll-bit-codes byte)
                (list-ref ll-lengths byte)))
  (write-bits (list-ref ll-bit-codes 256)
              (list-ref ll-lengths 256))
  (finish-bits bits))

(define (dynamic-compact-huffman-trimmed-literal-raw-deflate input)
  (unless (bytes? input)
    (raise-argument-error 'dynamic-compact-huffman-trimmed-literal-raw-deflate "bytes?" input))
  (define ll-lengths (literal-frequency-lengths input))
  (define dist-lengths '(0))
  (define lcodes (trimmed-code-count ll-lengths 257))
  (define dcodes 1)
  (define combined-lengths
    (append (take ll-lengths lcodes)
            (take dist-lengths dcodes)))
  (define events (code-length-rle-events combined-lengths))
  (define bl-freqs (bl-frequencies events))
  (define bl-lengths (balanced-bllen bl-freqs))
  (define bl-bit-codes (bit-code-table bl-lengths))
  (define ll-bit-codes (bit-code-table ll-lengths))
  (define bits '())
  (define (write-bits value width)
    (for ([i (in-range width)])
      (set! bits
            (cons (bitwise-and (arithmetic-shift value (- i)) 1)
                  bits))))
  (define blcodes (blcodes-count bl-lengths))
  (write-bits #b101 3)
  (write-bits (- lcodes 257) 5)
  (write-bits (- dcodes 1) 5)
  (write-bits (- blcodes 4) 4)
  (for ([symbol (in-list (take deflate-code-length-order blcodes))])
    (write-bits (list-ref bl-lengths symbol) 3))
  (for ([event (in-list events)])
    (define symbol (cl-event-symbol event))
    (write-bits (list-ref bl-bit-codes symbol)
                (list-ref bl-lengths symbol))
    (when (positive? (cl-event-extra-bits event))
      (write-bits (cl-event-extra event)
                  (cl-event-extra-bits event))))
  (for ([byte (in-bytes input)])
    (write-bits (list-ref ll-bit-codes byte)
                (list-ref ll-lengths byte)))
  (write-bits (list-ref ll-bit-codes 256)
              (list-ref ll-lengths 256))
  (finish-bits bits))

(define (dynamic-compact-dual-huffman-trimmed-literal-raw-deflate input)
  (dynamic-literal-frequency-raw-deflate input))

(define (harness-source compressed expected)
  (format
   #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

static const uint8_t compressed[] = { ~a };
static const size_t compressed_len = ~a;
static const uint8_t expected[] = { ~a };
static const size_t expected_len = ~a;

int main(void) {
  size_t decoded_cap = expected_len + 64;
  uint8_t *decoded = calloc(decoded_cap == 0 ? 1 : decoded_cap, 1);
  if (!decoded) {
    return 1;
  }

  z_stream zs;
  memset(&zs, 0, sizeof(zs));
  int zr = inflateInit2(&zs, -MAX_WBITS);
  if (zr != Z_OK) {
    fprintf(stderr, "inflateInit2 failed: %d\n", zr);
    return 1;
  }

  zs.next_in = (Bytef *)compressed;
  zs.avail_in = (uInt)compressed_len;
  zs.next_out = decoded;
  zs.avail_out = (uInt)decoded_cap;
  zr = inflate(&zs, Z_FINISH);
  if (zr != Z_STREAM_END) {
    fprintf(stderr, "inflate failed: %d total_out=%lu total_in=%lu\n",
            zr, (unsigned long)zs.total_out, (unsigned long)zs.total_in);
    inflateEnd(&zs);
    return 1;
  }
  inflateEnd(&zs);

  if (zs.total_out != expected_len ||
      (expected_len != 0 && memcmp(decoded, expected, expected_len) != 0)) {
    fprintf(stderr, "decoded mismatch total_out=%lu expected=%zu\n",
            (unsigned long)zs.total_out, expected_len);
    return 1;
  }
  free(decoded);
  return 0;
}
C
   (bytes->c-initializer compressed)
   (bytes-length compressed)
   (bytes->c-initializer expected)
   (bytes-length expected)))

(define (asmp-harness-source input expected-compressed)
  (format
   #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#include "asmp_dynamic_litonly.h"

enum {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_DST_TOO_SMALL = 1,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};

static const uint8_t input[] = { ~a };
static const size_t input_len = ~a;
static const uint8_t expected_compressed[] = { ~a };
static const size_t expected_compressed_len = ~a;

static int verify_inflate(const uint8_t *compressed, uint64_t compressed_len) {
  size_t decoded_cap = input_len + 64;
  uint8_t *decoded = calloc(decoded_cap == 0 ? 1 : decoded_cap, 1);
  if (!decoded) {
    return 1;
  }

  z_stream zs;
  memset(&zs, 0, sizeof(zs));
  int zr = inflateInit2(&zs, -MAX_WBITS);
  if (zr != Z_OK) {
    fprintf(stderr, "inflateInit2 failed: %d\n", zr);
    return 1;
  }

  zs.next_in = (Bytef *)compressed;
  zs.avail_in = (uInt)compressed_len;
  zs.next_out = decoded;
  zs.avail_out = (uInt)decoded_cap;
  zr = inflate(&zs, Z_FINISH);
  if (zr != Z_STREAM_END) {
    fprintf(stderr, "inflate failed: %d total_out=%lu total_in=%lu\n",
            zr, (unsigned long)zs.total_out, (unsigned long)zs.total_in);
    inflateEnd(&zs);
    return 1;
  }
  inflateEnd(&zs);

  if (zs.total_out != input_len ||
      (input_len != 0 && memcmp(decoded, input, input_len) != 0)) {
    fprintf(stderr, "decoded mismatch total_out=%lu expected=%zu\n",
            (unsigned long)zs.total_out, input_len);
    return 1;
  }
  free(decoded);
  return 0;
}

int main(void) {
  uint64_t bound = asmp_deflate_raw_dynamic_litonly_bound((uint64_t)input_len);
  uint8_t *compressed = calloc((size_t)bound, 1);
  if (!compressed) {
    return 1;
  }

  uint64_t compressed_len = 0;
  int status = asmp_deflate_raw_dynamic_litonly(compressed,
                                               bound,
                                               &compressed_len,
                                               input,
                                               (uint64_t)input_len);
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "asmp wrapper failed status=%d len=%llu\n",
            status, (unsigned long long)compressed_len);
    return 1;
  }
  if (compressed_len != expected_compressed_len ||
      memcmp(compressed, expected_compressed, expected_compressed_len) != 0) {
    fprintf(stderr, "compressed mismatch got=%llu expected=%zu\n",
            (unsigned long long)compressed_len, expected_compressed_len);
    return 1;
  }
  return verify_inflate(compressed, compressed_len);
}
C
   (bytes->c-initializer input)
   (bytes-length input)
   (bytes->c-initializer expected-compressed)
   (bytes-length expected-compressed)))

(define (asmp-balanced-harness-source input expected-compressed)
  (format
   #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

extern uint64_t asmp_deflate_raw_dynamic_balanced_bound(uint64_t src_len);
extern uint64_t asmp_deflate_raw_dynamic_balanced_scratch_size(void);
extern uint64_t asmp_deflate_raw_dynamic_balanced_scratch_align(void);
extern int asmp_deflate_raw_dynamic_balanced(uint8_t *dst,
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

static const uint8_t input[] = { ~a };
static const size_t input_len = ~a;
static const uint8_t expected_compressed[] = { ~a };
static const size_t expected_compressed_len = ~a;

static int verify_inflate(const uint8_t *compressed, uint64_t compressed_len) {
  size_t decoded_cap = input_len + 64;
  uint8_t *decoded = calloc(decoded_cap == 0 ? 1 : decoded_cap, 1);
  if (!decoded) {
    return 1;
  }

  z_stream zs;
  memset(&zs, 0, sizeof(zs));
  int zr = inflateInit2(&zs, -MAX_WBITS);
  if (zr != Z_OK) {
    fprintf(stderr, "inflateInit2 failed: %d\n", zr);
    return 1;
  }

  zs.next_in = (Bytef *)compressed;
  zs.avail_in = (uInt)compressed_len;
  zs.next_out = decoded;
  zs.avail_out = (uInt)decoded_cap;
  zr = inflate(&zs, Z_FINISH);
  if (zr != Z_STREAM_END) {
    fprintf(stderr, "inflate failed: %d total_out=%lu total_in=%lu\n",
            zr, (unsigned long)zs.total_out, (unsigned long)zs.total_in);
    inflateEnd(&zs);
    return 1;
  }
  inflateEnd(&zs);

  if (zs.total_out != input_len ||
      (input_len != 0 && memcmp(decoded, input, input_len) != 0)) {
    fprintf(stderr, "decoded mismatch total_out=%lu expected=%zu\n",
            (unsigned long)zs.total_out, input_len);
    return 1;
  }
  free(decoded);
  return 0;
}

static int expect_status(const char *name, int got, int expected) {
  if (got != expected) {
    fprintf(stderr, "%s: status=%d expected=%d\n", name, got, expected);
    return 1;
  }
  return 0;
}

static int status_checks(uint8_t *compressed,
                         uint64_t bound,
                         void *scratch,
                         uint64_t scratch_size) {
  uint64_t compressed_len = 123;
  int failed = 0;

  failed |= expect_status(
      "bad-dst",
      asmp_deflate_raw_dynamic_balanced(NULL, bound, &compressed_len,
                                        input, (uint64_t)input_len,
                                        scratch, scratch_size),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-dst-len",
      asmp_deflate_raw_dynamic_balanced(compressed, bound, NULL,
                                        input, (uint64_t)input_len,
                                        scratch, scratch_size),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-scratch",
      asmp_deflate_raw_dynamic_balanced(compressed, bound, &compressed_len,
                                        input, (uint64_t)input_len,
                                        NULL, scratch_size),
      ASMP_DEFLATE_BAD_ARGUMENT);
  if (input_len != 0) {
    failed |= expect_status(
        "bad-src",
        asmp_deflate_raw_dynamic_balanced(compressed, bound, &compressed_len,
                                          NULL, (uint64_t)input_len,
                                          scratch, scratch_size),
        ASMP_DEFLATE_BAD_ARGUMENT);
  }
  failed |= expect_status(
      "small-dst",
      asmp_deflate_raw_dynamic_balanced(compressed, expected_compressed_len - 1,
                                        &compressed_len,
                                        input, (uint64_t)input_len,
                                        scratch, scratch_size),
      ASMP_DEFLATE_DST_TOO_SMALL);
  failed |= expect_status(
      "small-scratch",
      asmp_deflate_raw_dynamic_balanced(compressed, bound, &compressed_len,
                                        input, (uint64_t)input_len,
                                        scratch, scratch_size - 1),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  return failed;
}

int main(void) {
  uint64_t bound = asmp_deflate_raw_dynamic_balanced_bound((uint64_t)input_len);
  uint64_t scratch_size = asmp_deflate_raw_dynamic_balanced_scratch_size();
  uint64_t scratch_align = asmp_deflate_raw_dynamic_balanced_scratch_align();
  if (scratch_size < 2704 || scratch_align < 16) {
    fprintf(stderr, "bad scratch contract size=%llu align=%llu\n",
            (unsigned long long)scratch_size,
            (unsigned long long)scratch_align);
    return 1;
  }

  uint8_t *compressed = calloc((size_t)bound, 1);
  void *scratch = calloc((size_t)scratch_size, 1);
  if (!compressed || !scratch) {
    return 1;
  }

  uint64_t compressed_len = 0;
  int status = asmp_deflate_raw_dynamic_balanced(compressed,
                                                 bound,
                                                 &compressed_len,
                                                 input,
                                                 (uint64_t)input_len,
                                                 scratch,
                                                 scratch_size);
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "asmp balanced wrapper failed status=%d len=%llu\n",
            status, (unsigned long long)compressed_len);
    return 1;
  }
  if (compressed_len != expected_compressed_len ||
      memcmp(compressed, expected_compressed, expected_compressed_len) != 0) {
    fprintf(stderr, "balanced compressed mismatch got=%llu expected=%zu\n",
            (unsigned long long)compressed_len, expected_compressed_len);
    return 1;
  }
  if (verify_inflate(compressed, compressed_len) != 0) {
    return 1;
  }
  return status_checks(compressed, bound, scratch, scratch_size);
}
C
   (bytes->c-initializer input)
   (bytes-length input)
   (bytes->c-initializer expected-compressed)
   (bytes-length expected-compressed)))

(define (asmp-compact-balanced-harness-source input expected-compressed)
  (regexp-replace*
   #rx"2704"
   (regexp-replace*
    #rx"asmp_deflate_raw_dynamic_balanced"
    (asmp-balanced-harness-source input expected-compressed)
    "asmp_deflate_raw_dynamic_compact_balanced")
   "4320"))

(define (asmp-compact-balanced-trimmed-harness-source input expected-compressed)
  (regexp-replace*
   #rx"2704"
   (regexp-replace*
    #rx"asmp_deflate_raw_dynamic_balanced"
    (asmp-balanced-harness-source input expected-compressed)
    "asmp_deflate_raw_dynamic_compact_balanced_trimmed")
   "4512"))

(define (asmp-compact-huffman-trimmed-harness-source input expected-compressed)
  (regexp-replace*
   #rx"2704"
   (regexp-replace*
    #rx"asmp_deflate_raw_dynamic_balanced"
    (asmp-balanced-harness-source input expected-compressed)
    "asmp_deflate_raw_dynamic_compact_huffman_trimmed")
   "11376"))

(define (asmp-compact-dual-huffman-trimmed-harness-source input expected-compressed)
  (regexp-replace*
   #rx"2704"
   (regexp-replace*
    #rx"asmp_deflate_raw_dynamic_balanced"
    (asmp-balanced-harness-source input expected-compressed)
    "asmp_deflate_raw_dynamic_compact_dual_huffman_trimmed")
   "11832"))

(define (asmp-lz77-huffman-harness-source input expected-compressed)
  (regexp-replace*
   #rx"2704"
   (regexp-replace*
    #rx"asmp_deflate_raw_dynamic_balanced"
    (asmp-balanced-harness-source input expected-compressed)
    "asmp_deflate_raw_dynamic_lz77_huffman")
   "282528"))

(define (rle-case-source name lengths)
  (define events (code-length-rle-events lengths))
  (define event-bytes (rle-event-bytes events))
  (format
   #<<C
static const uint8_t ~a_lengths[] = { ~a };
static const uint8_t ~a_expected[] = { ~a };
C
   name
   (u8-list->c-initializer lengths)
   name
   (u8-list->c-initializer event-bytes)))

(define (rle-case-call name lengths)
  (define events (code-length-rle-events lengths))
  (format
   "  failed |= check_case(\"~a\", ~a_lengths, ~a, ~a_expected, ~a);\n"
   name
   name
   (length lengths)
   name
   (length events)))

(define rle-test-cases
  (list
   (cons "empty" '())
   (cons "literal_mix" '(1 2 3 4 5))
   (cons "zero20" (make-list 20 0))
   (cons "mixed" (append (make-list 20 0)
                         (make-list 5 7)
                         (make-list 4 0)))
   (cons "zero150" (make-list 150 0))
   (cons "nonzero13" (make-list 13 9))))

(define (rle-cases-definitions)
  (apply string-append
         (for/list ([case (in-list rle-test-cases)])
           (rle-case-source (car case) (cdr case)))))

(define (rle-cases-calls)
  (apply string-append
         (for/list ([case (in-list rle-test-cases)])
           (rle-case-call (car case) (cdr case)))))

(define (asmp-code-length-rle-harness-source)
  (format
   #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int asmp_deflate_dynamic_code_length_rle(const uint8_t *len_ptr,
                                                uint64_t count,
                                                void *event_ptr,
                                                uint64_t event_cap,
                                                uint64_t *event_count_ptr);

enum {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_DST_TOO_SMALL = 1,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};

~a
static int expect_status(const char *name, int got, int expected) {
  if (got != expected) {
    fprintf(stderr, "%s: status=%d expected=%d\n", name, got, expected);
    return 1;
  }
  return 0;
}

static int check_case(const char *name,
                      const uint8_t *lengths,
                      uint64_t length_count,
                      const uint8_t *expected,
                      uint64_t expected_count) {
  uint8_t events[1024];
  uint64_t event_count = UINT64_MAX;
  memset(events, 0xcc, sizeof(events));

  int status = asmp_deflate_dynamic_code_length_rle(lengths,
                                                    length_count,
                                                    events,
                                                    expected_count,
                                                    &event_count);
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: wrapper failed status=%d\n", name, status);
    return 1;
  }
  if (event_count != expected_count) {
    fprintf(stderr, "%s: event_count=%llu expected=%llu\n",
            name,
            (unsigned long long)event_count,
            (unsigned long long)expected_count);
    return 1;
  }
  if (expected_count != 0 &&
      memcmp(events, expected, (size_t)expected_count * 4) != 0) {
    fprintf(stderr, "%s: event bytes mismatch\n", name);
    for (uint64_t i = 0; i < expected_count; i++) {
      fprintf(stderr,
              "  [%llu] got={%u,%u,%u,%u} expected={%u,%u,%u,%u}\n",
              (unsigned long long)i,
              events[i * 4],
              events[i * 4 + 1],
              events[i * 4 + 2],
              events[i * 4 + 3],
              expected[i * 4],
              expected[i * 4 + 1],
              expected[i * 4 + 2],
              expected[i * 4 + 3]);
    }
    return 1;
  }
  if (expected_count != 0) {
    event_count = UINT64_MAX;
    status = asmp_deflate_dynamic_code_length_rle(lengths,
                                                  length_count,
                                                  events,
                                                  expected_count - 1,
                                                  &event_count);
    if (expect_status("small-cap", status, ASMP_DEFLATE_DST_TOO_SMALL)) {
      return 1;
    }
    if (event_count != 0) {
      fprintf(stderr, "%s: small-cap event_count=%llu expected=0\n",
              name, (unsigned long long)event_count);
      return 1;
    }
  }
  return 0;
}

static int status_checks(void) {
  static const uint8_t lengths[] = {1, 2, 3};
  static const uint8_t bad_length[] = {1, 16, 2};
  uint8_t events[16];
  uint64_t event_count = 123;
  int failed = 0;

  failed |= expect_status(
      "bad-len",
      asmp_deflate_dynamic_code_length_rle(NULL, 3, events, 3, &event_count),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-events",
      asmp_deflate_dynamic_code_length_rle(lengths, 3, NULL, 3, &event_count),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-count-ptr",
      asmp_deflate_dynamic_code_length_rle(lengths, 3, events, 3, NULL),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-length-value",
      asmp_deflate_dynamic_code_length_rle(bad_length, 3, events, 3, &event_count),
      ASMP_DEFLATE_BAD_ARGUMENT);
  return failed;
}

int main(void) {
  int failed = 0;
~a
  failed |= status_checks();
  return failed ? 1 : 0;
}
C
   (rle-cases-definitions)
   (rle-cases-calls)))

(define (blfreq-case-source name lengths)
  (define events (code-length-rle-events lengths))
  (define event-bytes (rle-event-bytes events))
  (define freqs (bl-frequencies events))
  (format
   #<<C
static const uint8_t ~a_events[] = { ~a };
static const uint32_t ~a_expected_freq[] = { ~a };
C
   name
   (u8-list->c-initializer event-bytes)
   name
   (u8-list->c-initializer freqs)))

(define (blfreq-case-call name lengths)
  (define events (code-length-rle-events lengths))
  (format
   "  failed |= check_case(\"~a\", ~a_events, ~a, ~a_expected_freq);\n"
   name
   name
   (length events)
   name))

(define (blfreq-cases-definitions)
  (apply string-append
         (for/list ([case (in-list rle-test-cases)])
           (blfreq-case-source (car case) (cdr case)))))

(define (blfreq-cases-calls)
  (apply string-append
         (for/list ([case (in-list rle-test-cases)])
           (blfreq-case-call (car case) (cdr case)))))

(define (asmp-blfreq-harness-source)
  (format
   #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int asmp_deflate_dynamic_blfreq_count(const void *event_ptr,
                                             uint64_t event_count,
                                             void *freq_ptr,
                                             uint64_t freq_len);

enum {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_SCRATCH_TOO_SMALL = 2,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};

~a
static int expect_status(const char *name, int got, int expected) {
  if (got != expected) {
    fprintf(stderr, "%s: status=%d expected=%d\n", name, got, expected);
    return 1;
  }
  return 0;
}

static int check_case(const char *name,
                      const uint8_t *events,
                      uint64_t event_count,
                      const uint32_t *expected_freq) {
  uint32_t freq[19];
  memset(freq, 0xcc, sizeof(freq));
  int status = asmp_deflate_dynamic_blfreq_count(events,
                                                 event_count,
                                                 freq,
                                                 sizeof(freq));
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: wrapper failed status=%d\n", name, status);
    return 1;
  }
  for (size_t i = 0; i < 19; i++) {
    if (freq[i] != expected_freq[i]) {
      fprintf(stderr, "%s: freq[%zu]=%u expected=%u\n",
              name, i, freq[i], expected_freq[i]);
      return 1;
    }
  }
  return 0;
}

static int status_checks(void) {
  static const uint8_t events[] = {1, 0, 0, 0};
  static const uint8_t bad_symbol[] = {19, 0, 0, 0};
  uint32_t freq[19];
  int failed = 0;

  failed |= expect_status(
      "bad-events",
      asmp_deflate_dynamic_blfreq_count(NULL, 1, freq, sizeof(freq)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-freq",
      asmp_deflate_dynamic_blfreq_count(events, 1, NULL, sizeof(freq)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "small-freq",
      asmp_deflate_dynamic_blfreq_count(events, 1, freq, sizeof(freq) - 1),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  failed |= expect_status(
      "bad-symbol",
      asmp_deflate_dynamic_blfreq_count(bad_symbol, 1, freq, sizeof(freq)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  return failed;
}

int main(void) {
  int failed = 0;
~a
  failed |= status_checks();
  return failed ? 1 : 0;
}
C
   (blfreq-cases-definitions)
   (blfreq-cases-calls)))

(define bllen-test-cases
  (list
   (cons "empty" (make-list 19 0))
   (cons "single0" (append '(7) (make-list 18 0)))
   (cons "single18" (append (make-list 18 0) '(3)))
   (cons "two_symbols" '(0 0 0 0 0 4 0 0 0 0 0 0 0 0 0 0 0 2 0))
   (cons "rle_mixed"
         (bl-frequencies
          (code-length-rle-events
           (append (make-list 20 0)
                   (make-list 5 7)
                   (make-list 4 0)))))
   (cons "all_symbols" (for/list ([i (in-range 19)]) (add1 i)))))

(define (bllen-case-source name freqs)
  (define lengths (balanced-bllen freqs))
  (format
   #<<C
static const uint32_t ~a_freq[] = { ~a };
static const uint8_t ~a_expected_len[] = { ~a };
C
   name
   (u32-list->c-initializer freqs)
   name
   (u8-list->c-initializer lengths)))

(define (bllen-case-call name _freqs)
  (format
   "  failed |= check_case(\"~a\", ~a_freq, ~a_expected_len);\n"
   name
   name
   name))

(define (bllen-cases-definitions)
  (apply string-append
         (for/list ([case (in-list bllen-test-cases)])
           (bllen-case-source (car case) (cdr case)))))

(define (bllen-cases-calls)
  (apply string-append
         (for/list ([case (in-list bllen-test-cases)])
           (bllen-case-call (car case) (cdr case)))))

(define (asmp-bllen-harness-source)
  (format
   #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int asmp_deflate_dynamic_bllen_balanced(void *freq_ptr,
                                               uint64_t freq_len,
                                               void *len_ptr,
                                               uint64_t len_len);

enum {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_SCRATCH_TOO_SMALL = 2,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};

~a
static int expect_status(const char *name, int got, int expected) {
  if (got != expected) {
    fprintf(stderr, "%s: status=%d expected=%d\n", name, got, expected);
    return 1;
  }
  return 0;
}

static int check_case(const char *name,
                      const uint32_t *freq,
                      const uint8_t *expected_len) {
  uint8_t lengths[19];
  memset(lengths, 0xcc, sizeof(lengths));

  int status = asmp_deflate_dynamic_bllen_balanced((void *)freq,
                                                   19 * sizeof(freq[0]),
                                                   lengths,
                                                   sizeof(lengths));
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: wrapper failed status=%d\n", name, status);
    return 1;
  }
  for (size_t i = 0; i < 19; i++) {
    if (lengths[i] != expected_len[i]) {
      fprintf(stderr, "%s: len[%zu]=%u expected=%u freq=%u\n",
              name, i, lengths[i], expected_len[i], freq[i]);
      return 1;
    }
    if (lengths[i] > 7) {
      fprintf(stderr, "%s: len[%zu]=%u exceeds deflate BL limit\n",
              name, i, lengths[i]);
      return 1;
    }
  }
  return 0;
}

static int status_checks(void) {
  uint32_t freq[19] = {0};
  uint8_t lengths[19];
  int failed = 0;

  failed |= expect_status(
      "bad-freq",
      asmp_deflate_dynamic_bllen_balanced(NULL, sizeof(freq), lengths, sizeof(lengths)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-len",
      asmp_deflate_dynamic_bllen_balanced(freq, sizeof(freq), NULL, sizeof(lengths)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "small-freq",
      asmp_deflate_dynamic_bllen_balanced(freq, sizeof(freq) - 1, lengths, sizeof(lengths)),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  failed |= expect_status(
      "small-len",
      asmp_deflate_dynamic_bllen_balanced(freq, sizeof(freq), lengths, sizeof(lengths) - 1),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  return failed;
}

int main(void) {
  int failed = 0;
~a
  failed |= status_checks();
  return failed ? 1 : 0;
}
C
   (bllen-cases-definitions)
   (bllen-cases-calls)))

(define (fibonacci-frequencies count)
  (define freqs (make-vector count 0))
  (let loop ([a 1] [b 1] [index 0])
    (when (< index count)
      (vector-set! freqs index a)
      (loop b (+ a b) (add1 index))))
  (vector->list freqs))

(define bllen-huffman-test-cases
  (append
   (filter (lambda (case) (not (equal? (car case) "empty")))
           bllen-test-cases)
   (list (cons "fibonacci_overflow" (fibonacci-frequencies 19)))))

(define (bllen-huffman-expected freqs)
  (vector->list (huffman-code-lengths (list->vector freqs) 7 #:min-codes 2)))

(define (bllen-huffman-case-source name freqs)
  (define lengths (bllen-huffman-expected freqs))
  (format
   #<<C
static const uint32_t ~a_huff_freq[] = { ~a };
static const uint8_t ~a_huff_expected_len[] = { ~a };
C
   name
   (u32-list->c-initializer freqs)
   name
   (u8-list->c-initializer lengths)))

(define (bllen-huffman-case-call name _freqs)
  (format
   "  failed |= check_case(\"~a\", ~a_huff_freq, ~a_huff_expected_len);\n"
   name
   name
   name))

(define (bllen-huffman-cases-definitions)
  (apply string-append
         (for/list ([case (in-list bllen-huffman-test-cases)])
           (bllen-huffman-case-source (car case) (cdr case)))))

(define (bllen-huffman-cases-calls)
  (apply string-append
         (for/list ([case (in-list bllen-huffman-test-cases)])
           (bllen-huffman-case-call (car case) (cdr case)))))

(define (asmp-bllen-huffman-harness-source)
  (format
   #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int asmp_deflate_dynamic_bllen_huffman(void *freq_ptr,
                                              uint64_t freq_len,
                                              void *len_ptr,
                                              uint64_t len_len,
                                              void *scratch_ptr,
                                              uint64_t scratch_len);

enum {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_SCRATCH_TOO_SMALL = 2,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};

~a
static int expect_status(const char *name, int got, int expected) {
  if (got != expected) {
    fprintf(stderr, "%s: status=%d expected=%d\n", name, got, expected);
    return 1;
  }
  return 0;
}

static int check_case(const char *name,
                      const uint32_t *freq,
                      const uint8_t *expected_len) {
  uint8_t lengths[19];
  uint8_t scratch[456] __attribute__((aligned(16)));
  memset(lengths, 0xcc, sizeof(lengths));
  memset(scratch, 0xa5, sizeof(scratch));

  int status = asmp_deflate_dynamic_bllen_huffman((void *)freq,
                                                  19 * sizeof(freq[0]),
                                                  lengths,
                                                  sizeof(lengths),
                                                  scratch,
                                                  sizeof(scratch));
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: wrapper failed status=%d\n", name, status);
    return 1;
  }
  for (size_t i = 0; i < 19; i++) {
    if (lengths[i] != expected_len[i]) {
      fprintf(stderr, "%s: len[%zu]=%u expected=%u freq=%u\n",
              name, i, lengths[i], expected_len[i], freq[i]);
      return 1;
    }
    if (lengths[i] > 7) {
      fprintf(stderr, "%s: len[%zu]=%u exceeds deflate BL limit\n",
              name, i, lengths[i]);
      return 1;
    }
  }
  return 0;
}

static int status_checks(void) {
  uint32_t freq[19] = {0};
  uint8_t lengths[19];
  uint8_t scratch[456] __attribute__((aligned(16)));
  int failed = 0;

  freq[0] = 1;
  failed |= expect_status(
      "bad-freq",
      asmp_deflate_dynamic_bllen_huffman(NULL, sizeof(freq), lengths, sizeof(lengths), scratch, sizeof(scratch)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-len",
      asmp_deflate_dynamic_bllen_huffman(freq, sizeof(freq), NULL, sizeof(lengths), scratch, sizeof(scratch)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-scratch",
      asmp_deflate_dynamic_bllen_huffman(freq, sizeof(freq), lengths, sizeof(lengths), NULL, sizeof(scratch)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "small-freq",
      asmp_deflate_dynamic_bllen_huffman(freq, sizeof(freq) - 1, lengths, sizeof(lengths), scratch, sizeof(scratch)),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  failed |= expect_status(
      "small-len",
      asmp_deflate_dynamic_bllen_huffman(freq, sizeof(freq), lengths, sizeof(lengths) - 1, scratch, sizeof(scratch)),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  failed |= expect_status(
      "small-scratch",
      asmp_deflate_dynamic_bllen_huffman(freq, sizeof(freq), lengths, sizeof(lengths), scratch, sizeof(scratch) - 1),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);

  memset(freq, 0, sizeof(freq));
  failed |= expect_status(
      "all-zero",
      asmp_deflate_dynamic_bllen_huffman(freq, sizeof(freq), lengths, sizeof(lengths), scratch, sizeof(scratch)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  return failed;
}

int main(void) {
  int failed = 0;
~a
  failed |= status_checks();
  return failed ? 1 : 0;
}
C
   (bllen-huffman-cases-definitions)
   (bllen-huffman-cases-calls)))

(define blcodes-test-cases
  (append
   (for/list ([case (in-list bllen-test-cases)])
     (cons (string-append (car case) "_bllen")
           (balanced-bllen (cdr case))))
   (list
    (cons "all_zero_len" (make-list 19 0))
    (cons "early_only" (list 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 1 0))
    (cons "last_symbol" (append (make-list 15 0) '(1) (make-list 3 0))))))

(define (blcodes-case-source name lengths)
  (define count (blcodes-count lengths))
  (format
   #<<C
static const uint8_t ~a_len[] = { ~a };
static const uint64_t ~a_expected_blcodes = ~a;
C
   name
   (u8-list->c-initializer lengths)
   name
   count))

(define (blcodes-case-call name _lengths)
  (format
   "  failed |= check_case(\"~a\", ~a_len, ~a_expected_blcodes);\n"
   name
   name
   name))

(define (blcodes-cases-definitions)
  (apply string-append
         (for/list ([case (in-list blcodes-test-cases)])
           (blcodes-case-source (car case) (cdr case)))))

(define (blcodes-cases-calls)
  (apply string-append
         (for/list ([case (in-list blcodes-test-cases)])
           (blcodes-case-call (car case) (cdr case)))))

(define (asmp-blcodes-harness-source)
  (format
   #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int asmp_deflate_dynamic_blcodes_count(const uint8_t *len_ptr,
                                              uint64_t len_len,
                                              uint64_t *blcodes_ptr);

enum {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_SCRATCH_TOO_SMALL = 2,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};

~a
static int expect_status(const char *name, int got, int expected) {
  if (got != expected) {
    fprintf(stderr, "%s: status=%d expected=%d\n", name, got, expected);
    return 1;
  }
  return 0;
}

static int check_case(const char *name,
                      const uint8_t *lengths,
                      uint64_t expected_blcodes) {
  uint64_t blcodes = UINT64_MAX;
  int status = asmp_deflate_dynamic_blcodes_count(lengths,
                                                  19,
                                                  &blcodes);
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: wrapper failed status=%d\n", name, status);
    return 1;
  }
  if (blcodes != expected_blcodes) {
    fprintf(stderr, "%s: blcodes=%llu expected=%llu\n",
            name,
            (unsigned long long)blcodes,
            (unsigned long long)expected_blcodes);
    return 1;
  }
  if (blcodes < 4 || blcodes > 19) {
    fprintf(stderr, "%s: blcodes out of range: %llu\n",
            name, (unsigned long long)blcodes);
    return 1;
  }
  return 0;
}

static int status_checks(void) {
  uint8_t lengths[19] = {0};
  uint8_t bad_lengths[19] = {0};
  uint64_t blcodes = 123;
  int failed = 0;

  bad_lengths[0] = 8;
  failed |= expect_status(
      "bad-len",
      asmp_deflate_dynamic_blcodes_count(NULL, sizeof(lengths), &blcodes),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-out",
      asmp_deflate_dynamic_blcodes_count(lengths, sizeof(lengths), NULL),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "small-len",
      asmp_deflate_dynamic_blcodes_count(lengths, sizeof(lengths) - 1, &blcodes),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  failed |= expect_status(
      "bad-length-value",
      asmp_deflate_dynamic_blcodes_count(bad_lengths, sizeof(bad_lengths), &blcodes),
      ASMP_DEFLATE_BAD_ARGUMENT);
  if (blcodes != 0) {
    fprintf(stderr, "bad-length-value: blcodes=%llu expected=0\n",
            (unsigned long long)blcodes);
    failed = 1;
  }
  return failed;
}

int main(void) {
  int failed = 0;
~a
  failed |= status_checks();
  return failed ? 1 : 0;
}
C
   (blcodes-cases-definitions)
   (blcodes-cases-calls)))

(define (length-table count entries)
  (define values (make-vector count 0))
  (for ([entry (in-list entries)])
    (vector-set! values (car entry) (cdr entry)))
  (vector->list values))

(define code-counts-test-cases
  (list
   (list "eob_only"
         (length-table 286 '((256 . 1)))
         (make-list 30 0)
         257
         1)
   (list "low_literals_trimmed"
         (length-table 286 '((0 . 1) (97 . 2) (256 . 2)))
         (make-list 30 0)
         257
         1)
   (list "last_ll_symbol"
         (length-table 286 '((0 . 2) (256 . 3) (285 . 7)))
         (make-list 30 0)
         286
         1)
   (list "mid_distance"
         (length-table 286 '((1 . 2) (256 . 2)))
         (length-table 30 '((5 . 4)))
         257
         6)
   (list "last_distance"
         (length-table 286 '((255 . 2) (256 . 2)))
         (length-table 30 '((0 . 1) (29 . 5)))
         257
         30)))

(define (code-counts-case-source case)
  (match-define (list name ll-lengths dist-lengths lcodes dcodes) case)
  (format
   #<<C
static const uint8_t ~a_ll_len[] = { ~a };
static const uint8_t ~a_dist_len[] = { ~a };
static const uint64_t ~a_expected_lcodes = ~a;
static const uint64_t ~a_expected_dcodes = ~a;
C
   name
   (u8-list->c-initializer ll-lengths)
   name
   (u8-list->c-initializer dist-lengths)
   name
   lcodes
   name
   dcodes))

(define (code-counts-case-call case)
  (match-define (list name _ll-lengths _dist-lengths _lcodes _dcodes) case)
  (format
   "  failed |= check_case(\"~a\", ~a_ll_len, ~a_dist_len, ~a_expected_lcodes, ~a_expected_dcodes);\n"
   name
   name
   name
   name
   name))

(define (code-counts-cases-definitions)
  (apply string-append
         (for/list ([case (in-list code-counts-test-cases)])
           (code-counts-case-source case))))

(define (code-counts-cases-calls)
  (apply string-append
         (for/list ([case (in-list code-counts-test-cases)])
           (code-counts-case-call case))))

(define (asmp-code-counts-harness-source)
  (format
   #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int asmp_deflate_dynamic_code_counts(const uint8_t *ll_len_ptr,
                                            uint64_t ll_len_len,
                                            const uint8_t *dist_len_ptr,
                                            uint64_t dist_len_len,
                                            uint64_t *lcodes_ptr,
                                            uint64_t *dcodes_ptr);

enum {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_SCRATCH_TOO_SMALL = 2,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};

~a
static int expect_status(const char *name, int got, int expected) {
  if (got != expected) {
    fprintf(stderr, "%s: status=%d expected=%d\n", name, got, expected);
    return 1;
  }
  return 0;
}

static int check_case(const char *name,
                      const uint8_t *ll_len,
                      const uint8_t *dist_len,
                      uint64_t expected_lcodes,
                      uint64_t expected_dcodes) {
  uint64_t lcodes = UINT64_MAX;
  uint64_t dcodes = UINT64_MAX;
  int status = asmp_deflate_dynamic_code_counts(ll_len,
                                                286,
                                                dist_len,
                                                30,
                                                &lcodes,
                                                &dcodes);
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: wrapper failed status=%d\n", name, status);
    return 1;
  }
  if (lcodes != expected_lcodes || dcodes != expected_dcodes) {
    fprintf(stderr, "%s: lcodes=%llu dcodes=%llu expected=%llu/%llu\n",
            name,
            (unsigned long long)lcodes,
            (unsigned long long)dcodes,
            (unsigned long long)expected_lcodes,
            (unsigned long long)expected_dcodes);
    return 1;
  }
  if (lcodes < 257 || lcodes > 286 || dcodes < 1 || dcodes > 30) {
    fprintf(stderr, "%s: counts out of range: %llu/%llu\n",
            name,
            (unsigned long long)lcodes,
            (unsigned long long)dcodes);
    return 1;
  }
  return 0;
}

static int status_checks(void) {
  uint8_t ll_len[286] = {0};
  uint8_t dist_len[30] = {0};
  uint8_t bad_ll_len[286] = {0};
  uint8_t bad_dist_len[30] = {0};
  uint8_t missing_eob[286] = {0};
  uint64_t lcodes = 123;
  uint64_t dcodes = 456;
  int failed = 0;

  ll_len[256] = 1;
  bad_ll_len[256] = 1;
  bad_ll_len[0] = 16;
  bad_dist_len[0] = 16;

  failed |= expect_status(
      "bad-ll",
      asmp_deflate_dynamic_code_counts(NULL, sizeof(ll_len), dist_len, sizeof(dist_len), &lcodes, &dcodes),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-dist",
      asmp_deflate_dynamic_code_counts(ll_len, sizeof(ll_len), NULL, sizeof(dist_len), &lcodes, &dcodes),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-lcodes-out",
      asmp_deflate_dynamic_code_counts(ll_len, sizeof(ll_len), dist_len, sizeof(dist_len), NULL, &dcodes),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-dcodes-out",
      asmp_deflate_dynamic_code_counts(ll_len, sizeof(ll_len), dist_len, sizeof(dist_len), &lcodes, NULL),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "small-ll",
      asmp_deflate_dynamic_code_counts(ll_len, sizeof(ll_len) - 1, dist_len, sizeof(dist_len), &lcodes, &dcodes),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  failed |= expect_status(
      "small-dist",
      asmp_deflate_dynamic_code_counts(ll_len, sizeof(ll_len), dist_len, sizeof(dist_len) - 1, &lcodes, &dcodes),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  failed |= expect_status(
      "missing-eob",
      asmp_deflate_dynamic_code_counts(missing_eob, sizeof(missing_eob), dist_len, sizeof(dist_len), &lcodes, &dcodes),
      ASMP_DEFLATE_BAD_ARGUMENT);
  if (lcodes != 0 || dcodes != 0) {
    fprintf(stderr, "missing-eob: counts=%llu/%llu expected=0/0\n",
            (unsigned long long)lcodes,
            (unsigned long long)dcodes);
    failed = 1;
  }
  failed |= expect_status(
      "bad-ll-len",
      asmp_deflate_dynamic_code_counts(bad_ll_len, sizeof(bad_ll_len), dist_len, sizeof(dist_len), &lcodes, &dcodes),
      ASMP_DEFLATE_BAD_ARGUMENT);
  if (lcodes != 0 || dcodes != 0) {
    fprintf(stderr, "bad-ll-len: counts=%llu/%llu expected=0/0\n",
            (unsigned long long)lcodes,
            (unsigned long long)dcodes);
    failed = 1;
  }
  failed |= expect_status(
      "bad-dist-len",
      asmp_deflate_dynamic_code_counts(ll_len, sizeof(ll_len), bad_dist_len, sizeof(bad_dist_len), &lcodes, &dcodes),
      ASMP_DEFLATE_BAD_ARGUMENT);
  if (lcodes != 0 || dcodes != 0) {
    fprintf(stderr, "bad-dist-len: counts=%llu/%llu expected=0/0\n",
            (unsigned long long)lcodes,
            (unsigned long long)dcodes);
    failed = 1;
  }
  return failed;
}

int main(void) {
  int failed = 0;
~a
  failed |= status_checks();
  return failed ? 1 : 0;
}
C
   (code-counts-cases-definitions)
   (code-counts-cases-calls)))

(define (pad-to-compact-count lengths)
  (unless (<= (length lengths) 258)
    (error 'pad-to-compact-count "too many lengths: ~a" (length lengths)))
  (append lengths (make-list (- 258 (length lengths)) 0)))

(define compact-header-length-cases
  (list
   (cons "sparse_eob"
         (append (list 1) (make-list 255 0) (list 1 0)))
   (cons "long_zero_run"
         (pad-to-compact-count (append (make-list 20 0)
                                       (make-list 5 7)
                                       (make-list 4 0))))
   (cons "nonzero_repeat"
         (pad-to-compact-count (append (make-list 8 6)
                                       (make-list 12 0)
                                       (make-list 4 6))))
   (cons "many_lengths"
	         (pad-to-compact-count
	          (append '(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15)
	                  (make-list 6 15)
	                  (make-list 12 0))))))

(define (compact-header-case-data lengths)
  (define events (code-length-rle-events lengths))
  (define event-bytes (rle-event-bytes events))
  (define bl-freqs (bl-frequencies events))
  (define bl-lengths (balanced-bllen bl-freqs))
  (define bl-bit-codes (bit-code-table bl-lengths))
  (define expected (compact-header-bytes 257 1 bl-lengths bl-bit-codes events))
  (values events event-bytes bl-lengths bl-bit-codes expected))

(define (compact-header-case-source name lengths)
  (define-values (events event-bytes bl-lengths bl-bit-codes expected)
    (compact-header-case-data lengths))
  (format
   #<<C
static const uint8_t ~a_bl_len[] = { ~a };
static const uint16_t ~a_bl_bit_code[] = { ~a };
static const uint8_t ~a_events[] = { ~a };
static const uint8_t ~a_expected[] = { ~a };
C
   name
   (u8-list->c-initializer bl-lengths)
   name
   (u16-list->c-initializer bl-bit-codes)
   name
   (u8-list->c-initializer event-bytes)
   name
   (bytes->c-initializer expected)))

(define (compact-header-case-call name lengths)
  (define-values (events _event-bytes _bl-lengths _bl-bit-codes expected)
    (compact-header-case-data lengths))
  (format
   "  failed |= check_case(\"~a\", ~a_bl_len, ~a_bl_bit_code, ~a_events, ~a, ~a_expected, ~a);\n"
   name
   name
   name
   name
   (length events)
   name
   (bytes-length expected)))

(define (compact-header-cases-definitions)
  (apply string-append
         (for/list ([case (in-list compact-header-length-cases)])
           (compact-header-case-source (car case) (cdr case)))))

(define (compact-header-cases-calls)
  (apply string-append
         (for/list ([case (in-list compact-header-length-cases)])
           (compact-header-case-call (car case) (cdr case)))))

(define (asmp-compact-header-harness-source)
  (format
   #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int asmp_deflate_dynamic_compact_header(uint8_t *dst,
                                               uint64_t dst_cap,
                                               uint64_t *dst_len,
                                               const void *params);

struct compact_header_params {
  const uint8_t *bl_len_ptr;
  const uint16_t *bl_bit_code_ptr;
  const uint8_t *event_ptr;
  uint64_t event_count;
  uint64_t lcodes;
  uint64_t dcodes;
};

enum {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_DST_TOO_SMALL = 1,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};

~a
static int expect_status(const char *name, int got, int expected) {
  if (got != expected) {
    fprintf(stderr, "%s: status=%d expected=%d\n", name, got, expected);
    return 1;
  }
  return 0;
}

static int check_case(const char *name,
                      const uint8_t *bl_len,
                      const uint16_t *bl_bit_code,
                      const uint8_t *events,
                      uint64_t event_count,
                      const uint8_t *expected,
                      uint64_t expected_len) {
  uint8_t dst[512];
  uint64_t dst_len = UINT64_MAX;
  struct compact_header_params params = {
    bl_len,
    bl_bit_code,
    events,
    event_count,
    257,
    1
  };

  memset(dst, 0xcc, sizeof(dst));
  int status = asmp_deflate_dynamic_compact_header(dst,
                                                   sizeof(dst),
                                                   &dst_len,
                                                   &params);
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: wrapper failed status=%d\n", name, status);
    return 1;
  }
  if (dst_len != expected_len) {
    fprintf(stderr, "%s: dst_len=%llu expected=%llu\n",
            name,
            (unsigned long long)dst_len,
            (unsigned long long)expected_len);
    return 1;
  }
  if (expected_len != 0 && memcmp(dst, expected, (size_t)expected_len) != 0) {
    fprintf(stderr, "%s: compact header mismatch\n", name);
    for (uint64_t i = 0; i < expected_len; i++) {
      fprintf(stderr, "  byte[%llu]=%u expected=%u\n",
              (unsigned long long)i, dst[i], expected[i]);
    }
    return 1;
  }

  dst_len = UINT64_MAX;
  status = asmp_deflate_dynamic_compact_header(dst,
                                               expected_len - 1,
                                               &dst_len,
                                               &params);
  if (expect_status("small-cap", status, ASMP_DEFLATE_DST_TOO_SMALL)) {
    return 1;
  }
  if (dst_len != 0) {
    fprintf(stderr, "%s: small-cap dst_len=%llu expected=0\n",
            name, (unsigned long long)dst_len);
    return 1;
  }
  return 0;
}

static int status_checks(void) {
  static const uint8_t good_bl_len[19] = {1, 1};
  static const uint16_t good_bl_bit_code[19] = {0, 1};
  static const uint8_t good_events[] = {0, 0, 0, 0};
  static const uint8_t bad_symbol[] = {19, 0, 0, 0};
  static const uint8_t bad_zero_code[] = {18, 0, 0, 0};
  static const uint8_t bad_extra_bits[] = {0, 0, 8, 0};
  static const uint8_t bad_bl_len[19] = {8};
  struct compact_header_params params = {
    good_bl_len,
    good_bl_bit_code,
    good_events,
    1,
    257,
    1
  };
  uint8_t dst[64];
  uint64_t dst_len = 123;
  int failed = 0;

  failed |= expect_status(
      "bad-dst",
      asmp_deflate_dynamic_compact_header(NULL, sizeof(dst), &dst_len, &params),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-len",
      asmp_deflate_dynamic_compact_header(dst, sizeof(dst), NULL, &params),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-params",
      asmp_deflate_dynamic_compact_header(dst, sizeof(dst), &dst_len, NULL),
      ASMP_DEFLATE_BAD_ARGUMENT);

  params.bl_len_ptr = NULL;
  failed |= expect_status(
      "bad-bl-len",
      asmp_deflate_dynamic_compact_header(dst, sizeof(dst), &dst_len, &params),
      ASMP_DEFLATE_BAD_ARGUMENT);
  params.bl_len_ptr = good_bl_len;

  params.bl_bit_code_ptr = NULL;
  failed |= expect_status(
      "bad-bl-bit-code",
      asmp_deflate_dynamic_compact_header(dst, sizeof(dst), &dst_len, &params),
      ASMP_DEFLATE_BAD_ARGUMENT);
  params.bl_bit_code_ptr = good_bl_bit_code;

  params.event_ptr = NULL;
  failed |= expect_status(
      "bad-events",
      asmp_deflate_dynamic_compact_header(dst, sizeof(dst), &dst_len, &params),
      ASMP_DEFLATE_BAD_ARGUMENT);
  params.event_ptr = good_events;

  params.lcodes = 256;
  failed |= expect_status(
      "bad-lcodes-low",
      asmp_deflate_dynamic_compact_header(dst, sizeof(dst), &dst_len, &params),
      ASMP_DEFLATE_BAD_ARGUMENT);
  params.lcodes = 287;
  failed |= expect_status(
      "bad-lcodes-high",
      asmp_deflate_dynamic_compact_header(dst, sizeof(dst), &dst_len, &params),
      ASMP_DEFLATE_BAD_ARGUMENT);
  params.lcodes = 257;

  params.dcodes = 0;
  failed |= expect_status(
      "bad-dcodes-low",
      asmp_deflate_dynamic_compact_header(dst, sizeof(dst), &dst_len, &params),
      ASMP_DEFLATE_BAD_ARGUMENT);
  params.dcodes = 31;
  failed |= expect_status(
      "bad-dcodes-high",
      asmp_deflate_dynamic_compact_header(dst, sizeof(dst), &dst_len, &params),
      ASMP_DEFLATE_BAD_ARGUMENT);
  params.dcodes = 1;

  params.event_ptr = bad_symbol;
  failed |= expect_status(
      "bad-symbol",
      asmp_deflate_dynamic_compact_header(dst, sizeof(dst), &dst_len, &params),
      ASMP_DEFLATE_BAD_ARGUMENT);

  params.event_ptr = bad_zero_code;
  failed |= expect_status(
      "bad-zero-code",
      asmp_deflate_dynamic_compact_header(dst, sizeof(dst), &dst_len, &params),
      ASMP_DEFLATE_BAD_ARGUMENT);

  params.event_ptr = bad_extra_bits;
  failed |= expect_status(
      "bad-extra-bits",
      asmp_deflate_dynamic_compact_header(dst, sizeof(dst), &dst_len, &params),
      ASMP_DEFLATE_BAD_ARGUMENT);

  params.event_ptr = good_events;
  params.bl_len_ptr = bad_bl_len;
  failed |= expect_status(
      "bad-bl-length-value",
      asmp_deflate_dynamic_compact_header(dst, sizeof(dst), &dst_len, &params),
      ASMP_DEFLATE_BAD_ARGUMENT);
  return failed;
}

int main(void) {
  int failed = 0;
~a
  failed |= status_checks();
  return failed ? 1 : 0;
}
C
   (compact-header-cases-definitions)
   (compact-header-cases-calls)))

(define litfreq-harness-source
  #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "asmp_litfreq.h"

enum {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_SCRATCH_TOO_SMALL = 2,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};

static int expect_status(const char *name, int got, int expected) {
  if (got != expected) {
    fprintf(stderr, "%s: status=%d expected=%d\n", name, got, expected);
    return 1;
  }
  return 0;
}

static int check_case(const char *name, const uint8_t *data, size_t len) {
  uint32_t freq[286];
  uint32_t expected[286];
  for (size_t i = 0; i < 286; i++) {
    freq[i] = 0xccccccccu;
    expected[i] = 0;
  }
  for (size_t i = 0; i < len; i++) {
    expected[data[i]]++;
  }
  expected[256] = 1;

  int status = asmp_deflate_dynamic_litfreq_count(data,
                                                  (uint64_t)len,
                                                  freq,
                                                  sizeof(freq));
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: wrapper failed status=%d\n", name, status);
    return 1;
  }
  for (size_t i = 0; i < 286; i++) {
    if (freq[i] != expected[i]) {
      fprintf(stderr, "%s: freq[%zu]=%u expected=%u\n",
              name, i, freq[i], expected[i]);
      return 1;
    }
  }
  return 0;
}

static int status_checks(void) {
  static const uint8_t data[] = "status";
  uint32_t freq[286];
  int failed = 0;

  failed |= expect_status(
      "bad-src",
      asmp_deflate_dynamic_litfreq_count(NULL, 1, freq, sizeof(freq)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-freq",
      asmp_deflate_dynamic_litfreq_count(data, sizeof(data) - 1, NULL, sizeof(freq)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "small-freq",
      asmp_deflate_dynamic_litfreq_count(data, sizeof(data) - 1, freq, 4),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  failed |= check_case("empty-null-src", NULL, 0);
  return failed;
}

int main(void) {
  static const uint8_t text[] = "hello hello dynamic huffman\n";
  static uint8_t high_literals[112];
  for (size_t i = 0; i < sizeof(high_literals); i++) {
    high_literals[i] = (uint8_t)(144u + i);
  }
  static uint8_t binary[2048];
  for (size_t i = 0; i < sizeof(binary); i++) {
    binary[i] = (uint8_t)((i * 37u + (i >> 3)) & 0xffu);
  }

  int failed = 0;
  failed |= check_case("empty", (const uint8_t *)"", 0);
  failed |= check_case("text", text, sizeof(text) - 1);
  failed |= check_case("high-literals", high_literals, sizeof(high_literals));
  failed |= check_case("binary", binary, sizeof(binary));
  failed |= status_checks();
  return failed ? 1 : 0;
}
C
  )

(define lz77-freq-test-cases
  (list
   (cons "empty" #"")
   (cons "short" #"abc")
   (cons "text" #"hello hello dynamic huffman\n")
   (cons "repeated" (make-bytes 1024 (char->integer #\a)))
   (cons "periodic"
         (apply bytes
                (for/list ([i (in-range 2048)])
                  (+ (char->integer #\A) (remainder i 7)))))
   (cons "binary"
         (apply bytes
                (for/list ([i (in-range 512)])
                  (bitwise-and (+ (* i 37) (arithmetic-shift i -3)) #xff))))))

(define (lz77-freq-case-source name input)
  (define-values (ll-freq dist-freq) (dynamic-lz77-frequency-counts input))
  (format
   #<<C
static const uint8_t ~a_input[] = { ~a };
static const uint32_t ~a_expected_ll[] = { ~a };
static const uint32_t ~a_expected_dist[] = { ~a };
C
   name
   (bytes->c-initializer input)
   name
   (u32-list->c-initializer ll-freq)
   name
   (u32-list->c-initializer dist-freq)))

(define (lz77-freq-case-call name input)
  (format
   "  failed |= check_case(\"~a\", ~a_input, ~a, ~a_expected_ll, ~a_expected_dist);\n"
   name
   name
   (bytes-length input)
   name
   name))

(define (lz77-freq-cases-definitions)
  (apply string-append
         (for/list ([case (in-list lz77-freq-test-cases)])
           (lz77-freq-case-source (car case) (cdr case)))))

(define (lz77-freq-cases-calls)
  (apply string-append
         (for/list ([case (in-list lz77-freq-test-cases)])
           (lz77-freq-case-call (car case) (cdr case)))))

(define (asmp-lz77-freq-harness-source)
  (format
   #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern uint64_t asmp_deflate_dynamic_lz77_freq_scratch_size(void);
extern uint64_t asmp_deflate_dynamic_lz77_freq_scratch_align(void);
extern int asmp_deflate_dynamic_lz77_freq_count(const uint8_t *src,
                                                uint64_t src_len,
                                                void *ll_freq_ptr,
                                                uint64_t ll_freq_len,
                                                void *dist_freq_ptr,
                                                uint64_t dist_freq_len,
                                                void *scratch_ptr,
                                                uint64_t scratch_len);

enum {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_SCRATCH_TOO_SMALL = 2,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};

~a
static int expect_status(const char *name, int got, int expected) {
  if (got != expected) {
    fprintf(stderr, "%s: status=%d expected=%d\n", name, got, expected);
    return 1;
  }
  return 0;
}

static int check_case(const char *name,
                      const uint8_t *data,
                      size_t len,
                      const uint32_t *expected_ll,
                      const uint32_t *expected_dist) {
  uint32_t ll_freq[286];
  uint32_t dist_freq[30];
  static uint8_t scratch[262144] __attribute__((aligned(16)));
  memset(ll_freq, 0xcc, sizeof(ll_freq));
  memset(dist_freq, 0xcc, sizeof(dist_freq));
  memset(scratch, 0xcc, sizeof(scratch));

  int status = asmp_deflate_dynamic_lz77_freq_count(data,
                                                    (uint64_t)len,
                                                    ll_freq,
                                                    sizeof(ll_freq),
                                                    dist_freq,
                                                    sizeof(dist_freq),
                                                    scratch,
                                                    sizeof(scratch));
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: wrapper failed status=%d\n", name, status);
    return 1;
  }
  for (size_t i = 0; i < 286; i++) {
    if (ll_freq[i] != expected_ll[i]) {
      fprintf(stderr, "%s: ll_freq[%zu]=%u expected=%u\n",
              name, i, ll_freq[i], expected_ll[i]);
      return 1;
    }
  }
  for (size_t i = 0; i < 30; i++) {
    if (dist_freq[i] != expected_dist[i]) {
      fprintf(stderr, "%s: dist_freq[%zu]=%u expected=%u\n",
              name, i, dist_freq[i], expected_dist[i]);
      return 1;
    }
  }
  return 0;
}

static int status_checks(void) {
  static const uint8_t data[] = "status status status";
  uint32_t ll_freq[286];
  uint32_t dist_freq[30];
  static uint8_t scratch[262144] __attribute__((aligned(16)));
  int failed = 0;

  if (asmp_deflate_dynamic_lz77_freq_scratch_size() != sizeof(scratch)) {
    fprintf(stderr, "scratch_size mismatch\n");
    failed = 1;
  }
  if (asmp_deflate_dynamic_lz77_freq_scratch_align() != 16) {
    fprintf(stderr, "scratch_align mismatch\n");
    failed = 1;
  }
  failed |= expect_status(
      "bad-src",
      asmp_deflate_dynamic_lz77_freq_count(NULL, 1, ll_freq, sizeof(ll_freq),
                                           dist_freq, sizeof(dist_freq),
                                           scratch, sizeof(scratch)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-ll",
      asmp_deflate_dynamic_lz77_freq_count(data, sizeof(data) - 1, NULL, sizeof(ll_freq),
                                           dist_freq, sizeof(dist_freq),
                                           scratch, sizeof(scratch)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-dist",
      asmp_deflate_dynamic_lz77_freq_count(data, sizeof(data) - 1, ll_freq, sizeof(ll_freq),
                                           NULL, sizeof(dist_freq),
                                           scratch, sizeof(scratch)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-scratch",
      asmp_deflate_dynamic_lz77_freq_count(data, sizeof(data) - 1, ll_freq, sizeof(ll_freq),
                                           dist_freq, sizeof(dist_freq),
                                           NULL, sizeof(scratch)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "small-ll",
      asmp_deflate_dynamic_lz77_freq_count(data, sizeof(data) - 1, ll_freq, sizeof(ll_freq) - 1,
                                           dist_freq, sizeof(dist_freq),
                                           scratch, sizeof(scratch)),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  failed |= expect_status(
      "small-dist",
      asmp_deflate_dynamic_lz77_freq_count(data, sizeof(data) - 1, ll_freq, sizeof(ll_freq),
                                           dist_freq, sizeof(dist_freq) - 1,
                                           scratch, sizeof(scratch)),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  failed |= expect_status(
      "small-scratch",
      asmp_deflate_dynamic_lz77_freq_count(data, sizeof(data) - 1, ll_freq, sizeof(ll_freq),
                                           dist_freq, sizeof(dist_freq),
                                           scratch, sizeof(scratch) - 1),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  failed |= expect_status(
      "empty-null-src",
      asmp_deflate_dynamic_lz77_freq_count(NULL, 0, ll_freq, sizeof(ll_freq),
                                           dist_freq, sizeof(dist_freq),
                                           scratch, sizeof(scratch)),
      ASMP_DEFLATE_OK);
  return failed;
}

int main(void) {
  int failed = 0;
~a
  failed |= status_checks();
  return failed ? 1 : 0;
}
C
   (lz77-freq-cases-definitions)
   (lz77-freq-cases-calls)))

(define (literal-freq-list input)
  (define freqs (make-vector 286 0))
  (for ([byte (in-bytes input)])
    (vector-set! freqs byte (add1 (vector-ref freqs byte))))
  (vector-set! freqs 256 (add1 (vector-ref freqs 256)))
  (vector->list freqs))

(define litlen-huffman-test-cases
  (list
   (cons "eob_only" (literal-freq-list #""))
   (cons "skewed" (literal-freq-list #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabz"))
   (cons "text" (literal-freq-list #"hello hello dynamic huffman\n"))
   (cons "high_literals"
         (literal-freq-list
          (apply bytes (for/list ([i (in-range 112)]) (+ 144 i)))))
   (cons "fibonacci_overflow"
         (let ([freqs (make-vector 286 0)]
               [symbols (append (range 31) '(256))])
           (let loop ([a 1] [b 1] [remaining symbols])
             (unless (null? remaining)
               (vector-set! freqs (car remaining) a)
               (loop b (+ a b) (cdr remaining))))
           (vector->list freqs)))))

(define (litlen-huffman-expected freqs)
  (vector->list (huffman-code-lengths (list->vector freqs) 15 #:min-codes 2)))

(define (litlen-huffman-case-source name freqs)
  (define expected (litlen-huffman-expected freqs))
  (format
   #<<C
static const uint32_t ~a_freq[] = { ~a };
static const uint8_t ~a_expected[] = { ~a };
C
   name
   (u32-list->c-initializer freqs)
   name
   (u8-list->c-initializer expected)))

(define (litlen-huffman-case-call name _freqs)
  (format
   "  failed |= check_case(\"~a\", ~a_freq, ~a_expected);\n"
   name
   name
   name))

(define (litlen-huffman-cases-definitions)
  (apply string-append
         (for/list ([case (in-list litlen-huffman-test-cases)])
           (litlen-huffman-case-source (car case) (cdr case)))))

(define (litlen-huffman-cases-calls)
  (apply string-append
         (for/list ([case (in-list litlen-huffman-test-cases)])
           (litlen-huffman-case-call (car case) (cdr case)))))

(define (litlen-huffman-harness-source)
  (format
   #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int asmp_deflate_dynamic_litlen_huffman(void *freq_ptr,
                                               uint64_t freq_len,
                                               void *len_ptr,
                                               uint64_t len_len,
                                               void *scratch_ptr,
                                               uint64_t scratch_len);

enum {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_SCRATCH_TOO_SMALL = 2,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};

~a
static int expect_status(const char *name, int got, int expected) {
  if (got != expected) {
    fprintf(stderr, "%s: status=%d expected=%d\n", name, got, expected);
    return 1;
  }
  return 0;
}

static int check_case(const char *name,
                      const uint32_t *freq,
                      const uint8_t *expected) {
  uint8_t lengths[286];
  uint8_t scratch[6864] __attribute__((aligned(16)));
  memset(lengths, 0xcc, sizeof(lengths));
  memset(scratch, 0xa5, sizeof(scratch));

  int status = asmp_deflate_dynamic_litlen_huffman((void *)freq,
                                                   286 * sizeof(freq[0]),
                                                   lengths,
                                                   sizeof(lengths),
                                                   scratch,
                                                   sizeof(scratch));
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: litlen huffman status=%d\n", name, status);
    return 1;
  }
  for (size_t i = 0; i < 286; i++) {
    if (lengths[i] != expected[i]) {
      fprintf(stderr, "%s: len[%zu]=%u expected=%u freq=%u\n",
              name, i, lengths[i], expected[i], freq[i]);
      return 1;
    }
    if (lengths[i] > 15) {
      fprintf(stderr, "%s: len[%zu]=%u exceeds deflate limit\n",
              name, i, lengths[i]);
      return 1;
    }
  }
  return 0;
}

static int status_checks(void) {
  uint32_t freq[286] = {0};
  uint8_t lengths[286];
  uint8_t scratch[6864] __attribute__((aligned(16)));
  int failed = 0;

  freq[256] = 1;
  failed |= expect_status(
      "bad-freq",
      asmp_deflate_dynamic_litlen_huffman(NULL, sizeof(freq), lengths, sizeof(lengths), scratch, sizeof(scratch)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-len",
      asmp_deflate_dynamic_litlen_huffman(freq, sizeof(freq), NULL, sizeof(lengths), scratch, sizeof(scratch)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-scratch",
      asmp_deflate_dynamic_litlen_huffman(freq, sizeof(freq), lengths, sizeof(lengths), NULL, sizeof(scratch)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "small-freq",
      asmp_deflate_dynamic_litlen_huffman(freq, sizeof(freq) - 1, lengths, sizeof(lengths), scratch, sizeof(scratch)),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  failed |= expect_status(
      "small-len",
      asmp_deflate_dynamic_litlen_huffman(freq, sizeof(freq), lengths, sizeof(lengths) - 1, scratch, sizeof(scratch)),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  failed |= expect_status(
      "small-scratch",
      asmp_deflate_dynamic_litlen_huffman(freq, sizeof(freq), lengths, sizeof(lengths), scratch, sizeof(scratch) - 1),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);

  memset(freq, 0, sizeof(freq));
  failed |= expect_status(
      "all-zero",
      asmp_deflate_dynamic_litlen_huffman(freq, sizeof(freq), lengths, sizeof(lengths), scratch, sizeof(scratch)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  return failed;
}

int main(void) {
  int failed = 0;
~a
  failed |= status_checks();
  return failed ? 1 : 0;
}
C
   (litlen-huffman-cases-definitions)
   (litlen-huffman-cases-calls)))

(define (dist-freq-list input)
  (define-values (_ll-freq dist-freq) (dynamic-lz77-frequency-counts input))
  dist-freq)

(define (single-dist-freq symbol)
  (define freqs (make-vector 30 0))
  (vector-set! freqs symbol 1)
  (vector->list freqs))

(define distlen-huffman-test-cases
  (list
   (cons "all_zero" (make-list 30 0))
   (cons "single_zero" (single-dist-freq 0))
   (cons "single_last" (single-dist-freq 29))
   (cons "repeated" (dist-freq-list (make-bytes 1024 (char->integer #\a))))
   (cons "periodic"
         (dist-freq-list
          (apply bytes
                 (for/list ([i (in-range 2048)])
                   (+ (char->integer #\A) (remainder i 7))))))
   (cons "fibonacci_overflow" (fibonacci-frequencies 30))))

(define (distlen-huffman-expected freqs)
  (if (andmap zero? freqs)
      (make-list 30 0)
      (vector->list (huffman-code-lengths (list->vector freqs) 15 #:min-codes 2))))

(define (distlen-huffman-case-source name freqs)
  (define expected (distlen-huffman-expected freqs))
  (format
   #<<C
static const uint32_t ~a_freq[] = { ~a };
static const uint8_t ~a_expected[] = { ~a };
C
   name
   (u32-list->c-initializer freqs)
   name
   (u8-list->c-initializer expected)))

(define (distlen-huffman-case-call name _freqs)
  (format
   "  failed |= check_case(\"~a\", ~a_freq, ~a_expected);\n"
   name
   name
   name))

(define (distlen-huffman-cases-definitions)
  (apply string-append
         (for/list ([case (in-list distlen-huffman-test-cases)])
           (distlen-huffman-case-source (car case) (cdr case)))))

(define (distlen-huffman-cases-calls)
  (apply string-append
         (for/list ([case (in-list distlen-huffman-test-cases)])
           (distlen-huffman-case-call (car case) (cdr case)))))

(define (distlen-huffman-harness-source)
  (format
   #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int asmp_deflate_dynamic_distlen_huffman(void *freq_ptr,
                                                uint64_t freq_len,
                                                void *len_ptr,
                                                uint64_t len_len,
                                                void *scratch_ptr,
                                                uint64_t scratch_len);

enum {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_SCRATCH_TOO_SMALL = 2,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};

~a
static int expect_status(const char *name, int got, int expected) {
  if (got != expected) {
    fprintf(stderr, "%s: status=%d expected=%d\n", name, got, expected);
    return 1;
  }
  return 0;
}

static int check_case(const char *name,
                      const uint32_t *freq,
                      const uint8_t *expected) {
  uint8_t lengths[30];
  uint8_t scratch[8304] __attribute__((aligned(16)));
  memset(lengths, 0xcc, sizeof(lengths));
  memset(scratch, 0xa5, sizeof(scratch));

  int status = asmp_deflate_dynamic_distlen_huffman((void *)freq,
                                                    30 * sizeof(freq[0]),
                                                    lengths,
                                                    sizeof(lengths),
                                                    scratch,
                                                    sizeof(scratch));
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: distlen huffman status=%d\n", name, status);
    return 1;
  }
  for (size_t i = 0; i < 30; i++) {
    if (lengths[i] != expected[i]) {
      fprintf(stderr, "%s: len[%zu]=%u expected=%u freq=%u\n",
              name, i, lengths[i], expected[i], freq[i]);
      return 1;
    }
    if (lengths[i] > 15) {
      fprintf(stderr, "%s: len[%zu]=%u exceeds deflate limit\n",
              name, i, lengths[i]);
      return 1;
    }
  }
  return 0;
}

static int status_checks(void) {
  uint32_t freq[30] = {0};
  uint8_t lengths[30];
  uint8_t scratch[8304] __attribute__((aligned(16)));
  int failed = 0;

  freq[0] = 1;
  failed |= expect_status(
      "bad-freq",
      asmp_deflate_dynamic_distlen_huffman(NULL, sizeof(freq), lengths, sizeof(lengths), scratch, sizeof(scratch)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-len",
      asmp_deflate_dynamic_distlen_huffman(freq, sizeof(freq), NULL, sizeof(lengths), scratch, sizeof(scratch)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-scratch",
      asmp_deflate_dynamic_distlen_huffman(freq, sizeof(freq), lengths, sizeof(lengths), NULL, sizeof(scratch)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "small-freq",
      asmp_deflate_dynamic_distlen_huffman(freq, sizeof(freq) - 1, lengths, sizeof(lengths), scratch, sizeof(scratch)),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  failed |= expect_status(
      "small-len",
      asmp_deflate_dynamic_distlen_huffman(freq, sizeof(freq), lengths, sizeof(lengths) - 1, scratch, sizeof(scratch)),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  failed |= expect_status(
      "small-scratch",
      asmp_deflate_dynamic_distlen_huffman(freq, sizeof(freq), lengths, sizeof(lengths), scratch, sizeof(scratch) - 1),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  return failed;
}

int main(void) {
  int failed = 0;
~a
  failed |= status_checks();
  return failed ? 1 : 0;
}
C
   (distlen-huffman-cases-definitions)
   (distlen-huffman-cases-calls)))

(define litlen-harness-source
  #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int asmp_deflate_dynamic_litfreq_count(const uint8_t *src,
                                              uint64_t src_len,
                                              void *freq_ptr,
                                              uint64_t freq_len);
extern int asmp_deflate_dynamic_litlen_balanced(void *freq_ptr,
                                                uint64_t freq_len,
                                                void *len_ptr,
                                                uint64_t len_len);

enum {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_SCRATCH_TOO_SMALL = 2,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};

static int expect_status(const char *name, int got, int expected) {
  if (got != expected) {
    fprintf(stderr, "%s: status=%d expected=%d\n", name, got, expected);
    return 1;
  }
  return 0;
}

static void expected_balanced_lengths(const uint32_t *freq, uint8_t *expected) {
  memset(expected, 0, 286);
  uint64_t active = 0;
  for (size_t i = 0; i < 286; i++) {
    if (freq[i] != 0) {
      active++;
    }
  }
  if (active == 0) {
    return;
  }
  if (active <= 2) {
    for (size_t i = 0; i < 286; i++) {
      if (freq[i] != 0) {
        expected[i] = 1;
      }
    }
    if (active == 1) {
      expected[freq[0] == 0 ? 0 : 1] = 1;
    }
    return;
  }

  uint64_t pow2 = 1;
  uint8_t long_len = 0;
  while (pow2 < active) {
    pow2 += pow2;
    long_len++;
  }
  uint8_t short_len = (uint8_t)(long_len - 1);
  uint64_t short_remaining = pow2 - active;
  for (size_t i = 0; i < 286; i++) {
    if (freq[i] == 0) {
      continue;
    }
    if (short_remaining != 0) {
      expected[i] = short_len;
      short_remaining--;
    } else {
      expected[i] = long_len;
    }
  }
}

static int check_case(const char *name, const uint8_t *data, size_t len) {
  uint32_t freq[286];
  uint8_t lengths[286];
  uint8_t expected[286];

  int status = asmp_deflate_dynamic_litfreq_count(data,
                                                  (uint64_t)len,
                                                  freq,
                                                  sizeof(freq));
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: litfreq status=%d\n", name, status);
    return 1;
  }

  memset(lengths, 0xcc, sizeof(lengths));
  status = asmp_deflate_dynamic_litlen_balanced(freq,
                                                sizeof(freq),
                                                lengths,
                                                sizeof(lengths));
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: litlen status=%d\n", name, status);
    return 1;
  }

  expected_balanced_lengths(freq, expected);
  for (size_t i = 0; i < 286; i++) {
    if (lengths[i] != expected[i]) {
      fprintf(stderr, "%s: len[%zu]=%u expected=%u freq=%u\n",
              name, i, lengths[i], expected[i], freq[i]);
      return 1;
    }
  }
  return 0;
}

static int status_checks(void) {
  uint32_t freq[286] = {0};
  uint8_t lengths[286];
  int failed = 0;

  failed |= expect_status(
      "bad-freq",
      asmp_deflate_dynamic_litlen_balanced(NULL, sizeof(freq), lengths, sizeof(lengths)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-len",
      asmp_deflate_dynamic_litlen_balanced(freq, sizeof(freq), NULL, sizeof(lengths)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "small-freq",
      asmp_deflate_dynamic_litlen_balanced(freq, 4, lengths, sizeof(lengths)),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  failed |= expect_status(
      "small-len",
      asmp_deflate_dynamic_litlen_balanced(freq, sizeof(freq), lengths, 4),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  return failed;
}

int main(void) {
  static const uint8_t text[] = "hello hello dynamic huffman\n";
  static uint8_t high_literals[112];
  for (size_t i = 0; i < sizeof(high_literals); i++) {
    high_literals[i] = (uint8_t)(144u + i);
  }
  static uint8_t binary[2048];
  for (size_t i = 0; i < sizeof(binary); i++) {
    binary[i] = (uint8_t)((i * 37u + (i >> 3)) & 0xffu);
  }

  int failed = 0;
  failed |= check_case("empty", (const uint8_t *)"", 0);
  failed |= check_case("text", text, sizeof(text) - 1);
  failed |= check_case("high-literals", high_literals, sizeof(high_literals));
  failed |= check_case("binary", binary, sizeof(binary));
  failed |= status_checks();
  return failed ? 1 : 0;
}
C
  )

(define canonical-harness-source
  #<<C
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int asmp_deflate_dynamic_litfreq_count(const uint8_t *src,
                                              uint64_t src_len,
                                              void *freq_ptr,
                                              uint64_t freq_len);
extern int asmp_deflate_dynamic_litlen_balanced(void *freq_ptr,
                                                uint64_t freq_len,
                                                void *len_ptr,
                                                uint64_t len_len);
extern int asmp_deflate_dynamic_canonical_codes(void *len_ptr,
                                                uint64_t count,
                                                void *code_ptr,
                                                uint64_t code_len,
                                                void *scratch_ptr,
                                                uint64_t scratch_len);
extern int asmp_deflate_dynamic_reverse_codes(void *len_ptr,
                                              uint64_t count,
                                              void *code_ptr,
                                              uint64_t code_len,
                                              void *bit_code_ptr,
                                              uint64_t bit_code_len);

enum {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_SCRATCH_TOO_SMALL = 2,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};

static int expect_status(const char *name, int got, int expected) {
  if (got != expected) {
    fprintf(stderr, "%s: status=%d expected=%d\n", name, got, expected);
    return 1;
  }
  return 0;
}

static int expected_canonical_codes(const uint8_t *lengths,
                                    size_t count,
                                    uint16_t *expected) {
  uint32_t bl_count[16] = {0};
  uint32_t next_code[16] = {0};
  memset(expected, 0, count * sizeof(expected[0]));

  for (size_t i = 0; i < count; i++) {
    uint8_t len = lengths[i];
    if (len > 15) {
      return ASMP_DEFLATE_BAD_ARGUMENT;
    }
    if (len != 0) {
      bl_count[len]++;
    }
  }

  uint32_t code = 0;
  for (uint32_t bits = 1; bits <= 15; bits++) {
    code = (code + bl_count[bits - 1]) << 1;
    next_code[bits] = code;
  }

  for (size_t symbol = 0; symbol < count; symbol++) {
    uint8_t len = lengths[symbol];
    if (len != 0) {
      expected[symbol] = (uint16_t)next_code[len];
      next_code[len]++;
    }
  }
  return ASMP_DEFLATE_OK;
}

static uint16_t bit_reverse_width(uint16_t value, uint8_t width) {
  uint16_t result = 0;
  for (uint8_t i = 0; i < width; i++) {
    result = (uint16_t)((result << 1) | ((value >> i) & 1u));
  }
  return result;
}

static int check_case(const char *name, const uint8_t *data, size_t len) {
  uint32_t freq[286];
  uint8_t lengths[286];
  uint16_t codes[286];
  uint16_t bit_codes[286];
  uint16_t expected[286];
  uint8_t scratch[128];

  int status = asmp_deflate_dynamic_litfreq_count(data,
                                                  (uint64_t)len,
                                                  freq,
                                                  sizeof(freq));
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: litfreq status=%d\n", name, status);
    return 1;
  }
  status = asmp_deflate_dynamic_litlen_balanced(freq,
                                                sizeof(freq),
                                                lengths,
                                                sizeof(lengths));
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: litlen status=%d\n", name, status);
    return 1;
  }

  memset(codes, 0xcc, sizeof(codes));
  memset(scratch, 0xcc, sizeof(scratch));
  status = asmp_deflate_dynamic_canonical_codes(lengths,
                                                286,
                                                codes,
                                                sizeof(codes),
                                                scratch,
                                                sizeof(scratch));
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: canonical status=%d\n", name, status);
    return 1;
  }

  status = expected_canonical_codes(lengths, 286, expected);
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: expected canonical status=%d\n", name, status);
    return 1;
  }

  for (size_t i = 0; i < 286; i++) {
    if (codes[i] != expected[i]) {
      fprintf(stderr, "%s: code[%zu]=%u expected=%u len=%u\n",
              name, i, codes[i], expected[i], lengths[i]);
      return 1;
    }
  }

  memset(bit_codes, 0xcc, sizeof(bit_codes));
  status = asmp_deflate_dynamic_reverse_codes(lengths,
                                              286,
                                              codes,
                                              sizeof(codes),
                                              bit_codes,
                                              sizeof(bit_codes));
  if (status != ASMP_DEFLATE_OK) {
    fprintf(stderr, "%s: reverse status=%d\n", name, status);
    return 1;
  }

  for (size_t i = 0; i < 286; i++) {
    uint16_t want = lengths[i] == 0 ? 0 : bit_reverse_width(expected[i], lengths[i]);
    if (bit_codes[i] != want) {
      fprintf(stderr, "%s: bit_code[%zu]=%u expected=%u len=%u code=%u\n",
              name, i, bit_codes[i], want, lengths[i], expected[i]);
      return 1;
    }
  }
  return 0;
}

static int status_checks(void) {
  uint8_t lengths[8] = {2, 2, 3, 0, 3, 0, 0, 0};
  uint16_t codes[8];
  uint16_t bit_codes[8];
  uint8_t scratch[128];
  int failed = 0;

  failed |= expect_status(
      "bad-len",
      asmp_deflate_dynamic_canonical_codes(NULL, 8, codes, sizeof(codes),
                                           scratch, sizeof(scratch)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-code",
      asmp_deflate_dynamic_canonical_codes(lengths, 8, NULL, sizeof(codes),
                                           scratch, sizeof(scratch)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "bad-scratch",
      asmp_deflate_dynamic_canonical_codes(lengths, 8, codes, sizeof(codes),
                                           NULL, sizeof(scratch)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "small-code",
      asmp_deflate_dynamic_canonical_codes(lengths, 8, codes, 4,
                                           scratch, sizeof(scratch)),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  failed |= expect_status(
      "small-scratch",
      asmp_deflate_dynamic_canonical_codes(lengths, 8, codes, sizeof(codes),
                                           scratch, 16),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);

  lengths[0] = 16;
  failed |= expect_status(
      "bad-length-value",
      asmp_deflate_dynamic_canonical_codes(lengths, 8, codes, sizeof(codes),
                                           scratch, sizeof(scratch)),
      ASMP_DEFLATE_BAD_ARGUMENT);

  lengths[0] = 2;
  failed |= expect_status(
      "reverse-bad-len",
      asmp_deflate_dynamic_reverse_codes(NULL, 8, codes, sizeof(codes),
                                         bit_codes, sizeof(bit_codes)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "reverse-bad-code",
      asmp_deflate_dynamic_reverse_codes(lengths, 8, NULL, sizeof(codes),
                                         bit_codes, sizeof(bit_codes)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "reverse-bad-bit-code",
      asmp_deflate_dynamic_reverse_codes(lengths, 8, codes, sizeof(codes),
                                         NULL, sizeof(bit_codes)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  failed |= expect_status(
      "reverse-small-code",
      asmp_deflate_dynamic_reverse_codes(lengths, 8, codes, 4,
                                         bit_codes, sizeof(bit_codes)),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);
  failed |= expect_status(
      "reverse-small-bit-code",
      asmp_deflate_dynamic_reverse_codes(lengths, 8, codes, sizeof(codes),
                                         bit_codes, 4),
      ASMP_DEFLATE_SCRATCH_TOO_SMALL);

  lengths[0] = 16;
  failed |= expect_status(
      "reverse-bad-length-value",
      asmp_deflate_dynamic_reverse_codes(lengths, 8, codes, sizeof(codes),
                                         bit_codes, sizeof(bit_codes)),
      ASMP_DEFLATE_BAD_ARGUMENT);
  return failed;
}

int main(void) {
  static const uint8_t text[] = "hello hello dynamic huffman\n";
  static uint8_t high_literals[112];
  for (size_t i = 0; i < sizeof(high_literals); i++) {
    high_literals[i] = (uint8_t)(144u + i);
  }
  static uint8_t binary[2048];
  for (size_t i = 0; i < sizeof(binary); i++) {
    binary[i] = (uint8_t)((i * 37u + (i >> 3)) & 0xffu);
  }

  int failed = 0;
  failed |= check_case("empty", (const uint8_t *)"", 0);
  failed |= check_case("text", text, sizeof(text) - 1);
  failed |= check_case("high-literals", high_literals, sizeof(high_literals));
  failed |= check_case("binary", binary, sizeof(binary));
  failed |= status_checks();
  return failed ? 1 : 0;
}
C
  )

(define (run-command exe . args)
  (define ok? (apply system* exe args))
  (unless ok?
    (error 'dynamic-huffman-reference-test "command failed: ~a ~a" exe args)))

(define (call-with-temp-dir proc)
  (define dir (make-temporary-file "asmp-dynamic-huffman-reference-~a" 'directory))
  (dynamic-wind
    void
    (lambda () (proc dir))
    (lambda () (delete-directory/files dir))))

(define (check-zlib-roundtrip name input [encoder dynamic-litonly-raw-deflate])
  (define clang (find-executable-path "clang"))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman reference ~a: clang not found\n" name)
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define compressed (encoder input))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out) (display (harness-source compressed input) out)))
        (run-command clang harness-path "-lz" "-o" exe-path)
        (run-command exe-path)
        (check-true (> (bytes-length compressed) 0))))]))

(define (check-asmp-roundtrip name input)
  (define clang (find-executable-path "clang"))
  (define racket-exe (find-system-path (quote exec-file)))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman asmp ~a: clang not found\n" name)
     (check-true #t)]
    [(not racket-exe)
     (printf "skip dynamic Huffman asmp ~a: racket not found\n" name)
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define asm-path (build-path dir "dynamic-litonly.s"))
        (define header-path (build-path dir "asmp_dynamic_litonly.h"))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (define compressed (dynamic-litonly-raw-deflate input))
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "--public-c-header"
                     header-path
                     "-o"
                     asm-path
                     dynamic-litonly-source)
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out) (display (asmp-harness-source input compressed) out)))
        (run-command clang harness-path asm-path "-I" dir "-lz" "-o" exe-path)
        (run-command exe-path)
        (check-true (> (bytes-length compressed) 0))))]))

(define (check-asmp-litfreq)
  (define clang (find-executable-path "clang"))
  (define racket-exe (find-system-path (quote exec-file)))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman litfreq helper: clang not found\n")
     (check-true #t)]
    [(not racket-exe)
     (printf "skip dynamic Huffman litfreq helper: racket not found\n")
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define asm-path (build-path dir "litfreq.s"))
        (define header-path (build-path dir "asmp_litfreq.h"))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "--public-c-header"
                     header-path
                     "-o"
                     asm-path
                     dynamic-litfreq-source)
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out) (display litfreq-harness-source out)))
        (run-command clang harness-path asm-path "-I" dir "-o" exe-path)
        (run-command exe-path)
        (check-true #t)))]))

(define (check-asmp-lz77-freq)
  (define clang (find-executable-path "clang"))
  (define racket-exe (find-system-path (quote exec-file)))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman LZ77 frequency helper: clang not found\n")
     (check-true #t)]
    [(not racket-exe)
     (printf "skip dynamic Huffman LZ77 frequency helper: racket not found\n")
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define asm-path (build-path dir "lz77-freq.s"))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     asm-path
                     dynamic-lz77-freq-source)
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out) (display (asmp-lz77-freq-harness-source) out)))
        (run-command clang harness-path asm-path "-o" exe-path)
        (run-command exe-path)
        (check-true #t)))]))

(define (check-asmp-litlen)
  (define clang (find-executable-path "clang"))
  (define racket-exe (find-system-path (quote exec-file)))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman litlen helper: clang not found\n")
     (check-true #t)]
    [(not racket-exe)
     (printf "skip dynamic Huffman litlen helper: racket not found\n")
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define litfreq-asm-path (build-path dir "litfreq.s"))
        (define litlen-asm-path (build-path dir "litlen.s"))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     litfreq-asm-path
                     dynamic-litfreq-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     litlen-asm-path
                     dynamic-litlen-source)
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out) (display litlen-harness-source out)))
        (run-command clang harness-path litfreq-asm-path litlen-asm-path "-o" exe-path)
        (run-command exe-path)
        (check-true #t)))]))

(define (check-asmp-litlen-huffman)
  (define clang (find-executable-path "clang"))
  (define racket-exe (find-system-path (quote exec-file)))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman litlen huffman helper: clang not found\n")
     (check-true #t)]
    [(not racket-exe)
     (printf "skip dynamic Huffman litlen huffman helper: racket not found\n")
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define litlen-huffman-asm-path (build-path dir "litlen-huffman.s"))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     litlen-huffman-asm-path
                     dynamic-litlen-huffman-source)
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out) (display (litlen-huffman-harness-source) out)))
        (run-command clang harness-path litlen-huffman-asm-path "-o" exe-path)
        (run-command exe-path)
        (check-true #t)))]))

(define (check-asmp-distlen-huffman)
  (define clang (find-executable-path "clang"))
  (define racket-exe (find-system-path (quote exec-file)))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman distlen huffman helper: clang not found\n")
     (check-true #t)]
    [(not racket-exe)
     (printf "skip dynamic Huffman distlen huffman helper: racket not found\n")
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define litlen-huffman-asm-path (build-path dir "litlen-huffman.s"))
        (define distlen-huffman-asm-path (build-path dir "distlen-huffman.s"))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     litlen-huffman-asm-path
                     dynamic-litlen-huffman-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     distlen-huffman-asm-path
                     dynamic-distlen-huffman-source)
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out) (display (distlen-huffman-harness-source) out)))
        (run-command clang
                     harness-path
                     litlen-huffman-asm-path
                     distlen-huffman-asm-path
                     "-o"
                     exe-path)
        (run-command exe-path)
        (check-true #t)))]))

(define (check-asmp-canonical)
  (define clang (find-executable-path "clang"))
  (define racket-exe (find-system-path (quote exec-file)))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman canonical helper: clang not found\n")
     (check-true #t)]
    [(not racket-exe)
     (printf "skip dynamic Huffman canonical helper: racket not found\n")
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define litfreq-asm-path (build-path dir "litfreq.s"))
        (define litlen-asm-path (build-path dir "litlen.s"))
        (define canonical-asm-path (build-path dir "canonical.s"))
        (define reverse-asm-path (build-path dir "reverse.s"))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     litfreq-asm-path
                     dynamic-litfreq-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     litlen-asm-path
                     dynamic-litlen-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     canonical-asm-path
                     dynamic-canonical-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     reverse-asm-path
                     dynamic-reverse-source)
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out) (display canonical-harness-source out)))
        (run-command clang
                     harness-path
                     litfreq-asm-path
                     litlen-asm-path
                     canonical-asm-path
                     reverse-asm-path
                     "-o"
                     exe-path)
        (run-command exe-path)
        (check-true #t)))]))

(define (check-asmp-balanced name input)
  (define clang (find-executable-path "clang"))
  (define racket-exe (find-system-path (quote exec-file)))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman balanced helper ~a: clang not found\n" name)
     (check-true #t)]
    [(not racket-exe)
     (printf "skip dynamic Huffman balanced helper ~a: racket not found\n" name)
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define litfreq-asm-path (build-path dir "litfreq.s"))
        (define litlen-asm-path (build-path dir "litlen.s"))
        (define canonical-asm-path (build-path dir "canonical.s"))
        (define reverse-asm-path (build-path dir "reverse.s"))
        (define balanced-asm-path (build-path dir "balanced.s"))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (define compressed (dynamic-balanced-literal-raw-deflate input))
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     litfreq-asm-path
                     dynamic-litfreq-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     litlen-asm-path
                     dynamic-litlen-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     canonical-asm-path
                     dynamic-canonical-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     reverse-asm-path
                     dynamic-reverse-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     balanced-asm-path
                     dynamic-balanced-source)
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out) (display (asmp-balanced-harness-source input compressed) out)))
        (run-command clang
                     harness-path
                     litfreq-asm-path
                     litlen-asm-path
                     canonical-asm-path
                     reverse-asm-path
                     balanced-asm-path
                     "-lz"
                     "-o"
                     exe-path)
        (run-command exe-path)
        (check-true (> (bytes-length compressed) 0))))]))

(define (check-asmp-compact-balanced name input)
  (define clang (find-executable-path "clang"))
  (define racket-exe (find-system-path (quote exec-file)))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman compact balanced helper ~a: clang not found\n" name)
     (check-true #t)]
    [(not racket-exe)
     (printf "skip dynamic Huffman compact balanced helper ~a: racket not found\n" name)
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define litfreq-asm-path (build-path dir "litfreq.s"))
        (define litlen-asm-path (build-path dir "litlen.s"))
        (define canonical-asm-path (build-path dir "canonical.s"))
        (define reverse-asm-path (build-path dir "reverse.s"))
        (define rle-asm-path (build-path dir "code-length-rle.s"))
        (define blfreq-asm-path (build-path dir "blfreq.s"))
        (define bllen-asm-path (build-path dir "bllen.s"))
        (define compact-asm-path (build-path dir "compact-balanced.s"))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (define compressed (dynamic-compact-balanced-literal-raw-deflate input))
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     litfreq-asm-path
                     dynamic-litfreq-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     litlen-asm-path
                     dynamic-litlen-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     canonical-asm-path
                     dynamic-canonical-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     reverse-asm-path
                     dynamic-reverse-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     rle-asm-path
                     dynamic-rle-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     blfreq-asm-path
                     dynamic-blfreq-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     bllen-asm-path
                     dynamic-bllen-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     compact-asm-path
                     dynamic-compact-balanced-source)
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out)
            (display (asmp-compact-balanced-harness-source input compressed) out)))
        (run-command clang
                     harness-path
                     litfreq-asm-path
                     litlen-asm-path
                     canonical-asm-path
                     reverse-asm-path
                     rle-asm-path
                     blfreq-asm-path
                     bllen-asm-path
                     compact-asm-path
                     "-lz"
                     "-o"
                     exe-path)
        (run-command exe-path)
        (check-true (> (bytes-length compressed) 0))))]))

(define (check-asmp-compact-balanced-trimmed name input)
  (define clang (find-executable-path "clang"))
  (define racket-exe (find-system-path (quote exec-file)))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman compact trimmed helper ~a: clang not found\n" name)
     (check-true #t)]
    [(not racket-exe)
     (printf "skip dynamic Huffman compact trimmed helper ~a: racket not found\n" name)
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define litfreq-asm-path (build-path dir "litfreq.s"))
        (define litlen-asm-path (build-path dir "litlen.s"))
        (define canonical-asm-path (build-path dir "canonical.s"))
        (define reverse-asm-path (build-path dir "reverse.s"))
        (define rle-asm-path (build-path dir "code-length-rle.s"))
        (define blfreq-asm-path (build-path dir "blfreq.s"))
        (define bllen-asm-path (build-path dir "bllen.s"))
        (define code-counts-asm-path (build-path dir "code-counts.s"))
        (define compact-asm-path (build-path dir "compact-trimmed.s"))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (define compressed (dynamic-compact-balanced-trimmed-literal-raw-deflate input))
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     litfreq-asm-path
                     dynamic-litfreq-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     litlen-asm-path
                     dynamic-litlen-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     canonical-asm-path
                     dynamic-canonical-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     reverse-asm-path
                     dynamic-reverse-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     rle-asm-path
                     dynamic-rle-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     blfreq-asm-path
                     dynamic-blfreq-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     bllen-asm-path
                     dynamic-bllen-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     code-counts-asm-path
                     dynamic-code-counts-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     compact-asm-path
                     dynamic-compact-trimmed-source)
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out)
            (display (asmp-compact-balanced-trimmed-harness-source input compressed) out)))
        (run-command clang
                     harness-path
                     litfreq-asm-path
                     litlen-asm-path
                     canonical-asm-path
                     reverse-asm-path
                     rle-asm-path
                     blfreq-asm-path
                     bllen-asm-path
                     code-counts-asm-path
                     compact-asm-path
                     "-lz"
                     "-o"
                     exe-path)
        (run-command exe-path)
        (check-true (> (bytes-length compressed) 0))))]))

(define (check-asmp-compact-huffman-trimmed name input)
  (define clang (find-executable-path "clang"))
  (define racket-exe (find-system-path (quote exec-file)))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman compact huffman helper ~a: clang not found\n" name)
     (check-true #t)]
    [(not racket-exe)
     (printf "skip dynamic Huffman compact huffman helper ~a: racket not found\n" name)
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define litfreq-asm-path (build-path dir "litfreq.s"))
        (define litlen-huffman-asm-path (build-path dir "litlen-huffman.s"))
        (define canonical-asm-path (build-path dir "canonical.s"))
        (define reverse-asm-path (build-path dir "reverse.s"))
        (define rle-asm-path (build-path dir "code-length-rle.s"))
        (define blfreq-asm-path (build-path dir "blfreq.s"))
        (define bllen-asm-path (build-path dir "bllen.s"))
        (define code-counts-asm-path (build-path dir "code-counts.s"))
        (define compact-asm-path (build-path dir "compact-huffman.s"))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (define compressed (dynamic-compact-huffman-trimmed-literal-raw-deflate input))
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     litfreq-asm-path
                     dynamic-litfreq-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     litlen-huffman-asm-path
                     dynamic-litlen-huffman-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     canonical-asm-path
                     dynamic-canonical-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     reverse-asm-path
                     dynamic-reverse-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     rle-asm-path
                     dynamic-rle-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     blfreq-asm-path
                     dynamic-blfreq-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     bllen-asm-path
                     dynamic-bllen-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     code-counts-asm-path
                     dynamic-code-counts-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     compact-asm-path
                     dynamic-compact-huffman-source)
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out)
            (display (asmp-compact-huffman-trimmed-harness-source input compressed) out)))
        (run-command clang
                     harness-path
                     litfreq-asm-path
                     litlen-huffman-asm-path
                     canonical-asm-path
                     reverse-asm-path
                     rle-asm-path
                     blfreq-asm-path
                     bllen-asm-path
                     code-counts-asm-path
                     compact-asm-path
                     "-lz"
                     "-o"
                     exe-path)
        (run-command exe-path)
        (check-true (> (bytes-length compressed) 0))))]))

(define (check-asmp-compact-dual-huffman-trimmed name input)
  (define clang (find-executable-path "clang"))
  (define racket-exe (find-system-path (quote exec-file)))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman compact dual huffman helper ~a: clang not found\n" name)
     (check-true #t)]
    [(not racket-exe)
     (printf "skip dynamic Huffman compact dual huffman helper ~a: racket not found\n" name)
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define litfreq-asm-path (build-path dir "litfreq.s"))
        (define litlen-huffman-asm-path (build-path dir "litlen-huffman.s"))
        (define canonical-asm-path (build-path dir "canonical.s"))
        (define reverse-asm-path (build-path dir "reverse.s"))
        (define rle-asm-path (build-path dir "code-length-rle.s"))
        (define blfreq-asm-path (build-path dir "blfreq.s"))
        (define bllen-huffman-asm-path (build-path dir "bllen-huffman.s"))
        (define code-counts-asm-path (build-path dir "code-counts.s"))
        (define compact-asm-path (build-path dir "compact-dual-huffman.s"))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (define compressed (dynamic-compact-dual-huffman-trimmed-literal-raw-deflate input))
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     litfreq-asm-path
                     dynamic-litfreq-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     litlen-huffman-asm-path
                     dynamic-litlen-huffman-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     canonical-asm-path
                     dynamic-canonical-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     reverse-asm-path
                     dynamic-reverse-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     rle-asm-path
                     dynamic-rle-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     blfreq-asm-path
                     dynamic-blfreq-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     bllen-huffman-asm-path
                     dynamic-bllen-huffman-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     code-counts-asm-path
                     dynamic-code-counts-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     compact-asm-path
                     dynamic-compact-dual-huffman-source)
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out)
            (display (asmp-compact-dual-huffman-trimmed-harness-source input compressed) out)))
        (run-command clang
                     harness-path
                     litfreq-asm-path
                     litlen-huffman-asm-path
                     canonical-asm-path
                     reverse-asm-path
                     rle-asm-path
                     blfreq-asm-path
                     bllen-huffman-asm-path
                     code-counts-asm-path
                     compact-asm-path
                     "-lz"
                     "-o"
                     exe-path)
        (run-command exe-path)
        (check-true (> (bytes-length compressed) 0))))]))

(define (check-asmp-lz77-huffman name input)
  (define clang (find-executable-path "clang"))
  (define racket-exe (find-system-path (quote exec-file)))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman LZ77 huffman helper ~a: clang not found\n" name)
     (check-true #t)]
    [(not racket-exe)
     (printf "skip dynamic Huffman LZ77 huffman helper ~a: racket not found\n" name)
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define lz77-freq-asm-path (build-path dir "lz77-freq.s"))
        (define litlen-huffman-asm-path (build-path dir "litlen-huffman.s"))
        (define distlen-huffman-asm-path (build-path dir "distlen-huffman.s"))
        (define canonical-asm-path (build-path dir "canonical.s"))
        (define reverse-asm-path (build-path dir "reverse.s"))
        (define rle-asm-path (build-path dir "code-length-rle.s"))
        (define blfreq-asm-path (build-path dir "blfreq.s"))
        (define bllen-huffman-asm-path (build-path dir "bllen-huffman.s"))
        (define code-counts-asm-path (build-path dir "code-counts.s"))
        (define dynamic-asm-path (build-path dir "dynamic-lz77-huffman.s"))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (define compressed (dynamic-lz77-raw-deflate input))
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     lz77-freq-asm-path
                     dynamic-lz77-freq-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     litlen-huffman-asm-path
                     dynamic-litlen-huffman-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     distlen-huffman-asm-path
                     dynamic-distlen-huffman-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     canonical-asm-path
                     dynamic-canonical-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     reverse-asm-path
                     dynamic-reverse-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     rle-asm-path
                     dynamic-rle-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     blfreq-asm-path
                     dynamic-blfreq-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     bllen-huffman-asm-path
                     dynamic-bllen-huffman-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     code-counts-asm-path
                     dynamic-code-counts-source)
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     dynamic-asm-path
                     dynamic-lz77-huffman-source)
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out)
            (display (asmp-lz77-huffman-harness-source input compressed) out)))
        (run-command clang
                     harness-path
                     lz77-freq-asm-path
                     litlen-huffman-asm-path
                     distlen-huffman-asm-path
                     canonical-asm-path
                     reverse-asm-path
                     rle-asm-path
                     blfreq-asm-path
                     bllen-huffman-asm-path
                     code-counts-asm-path
                     dynamic-asm-path
                     "-lz"
                     "-o"
                     exe-path)
        (run-command exe-path)
        (check-true (> (bytes-length compressed) 0))))]))

(define (check-asmp-code-length-rle)
  (define clang (find-executable-path "clang"))
  (define racket-exe (find-system-path (quote exec-file)))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman code-length RLE helper: clang not found\n")
     (check-true #t)]
    [(not racket-exe)
     (printf "skip dynamic Huffman code-length RLE helper: racket not found\n")
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define rle-asm-path (build-path dir "code-length-rle.s"))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     rle-asm-path
                     dynamic-rle-source)
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out) (display (asmp-code-length-rle-harness-source) out)))
        (run-command clang harness-path rle-asm-path "-o" exe-path)
        (run-command exe-path)
        (check-true #t)))]))

(define (check-asmp-blfreq)
  (define clang (find-executable-path "clang"))
  (define racket-exe (find-system-path (quote exec-file)))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman bit-length frequency helper: clang not found\n")
     (check-true #t)]
    [(not racket-exe)
     (printf "skip dynamic Huffman bit-length frequency helper: racket not found\n")
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define blfreq-asm-path (build-path dir "blfreq.s"))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     blfreq-asm-path
                     dynamic-blfreq-source)
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out) (display (asmp-blfreq-harness-source) out)))
        (run-command clang harness-path blfreq-asm-path "-o" exe-path)
        (run-command exe-path)
        (check-true #t)))]))

(define (check-asmp-bllen)
  (define clang (find-executable-path "clang"))
  (define racket-exe (find-system-path (quote exec-file)))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman bit-length length helper: clang not found\n")
     (check-true #t)]
    [(not racket-exe)
     (printf "skip dynamic Huffman bit-length length helper: racket not found\n")
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define bllen-asm-path (build-path dir "bllen.s"))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     bllen-asm-path
                     dynamic-bllen-source)
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out) (display (asmp-bllen-harness-source) out)))
        (run-command clang harness-path bllen-asm-path "-o" exe-path)
        (run-command exe-path)
        (check-true #t)))]))

(define (check-asmp-bllen-huffman)
  (define clang (find-executable-path "clang"))
  (define racket-exe (find-system-path (quote exec-file)))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman bit-length Huffman helper: clang not found\n")
     (check-true #t)]
    [(not racket-exe)
     (printf "skip dynamic Huffman bit-length Huffman helper: racket not found\n")
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define bllen-huffman-asm-path (build-path dir "bllen-huffman.s"))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     bllen-huffman-asm-path
                     dynamic-bllen-huffman-source)
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out) (display (asmp-bllen-huffman-harness-source) out)))
        (run-command clang harness-path bllen-huffman-asm-path "-o" exe-path)
        (run-command exe-path)
        (check-true #t)))]))

(define (check-asmp-blcodes)
  (define clang (find-executable-path "clang"))
  (define racket-exe (find-system-path (quote exec-file)))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman bit-length code count helper: clang not found\n")
     (check-true #t)]
    [(not racket-exe)
     (printf "skip dynamic Huffman bit-length code count helper: racket not found\n")
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define blcodes-asm-path (build-path dir "blcodes.s"))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     blcodes-asm-path
                     dynamic-blcodes-source)
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out) (display (asmp-blcodes-harness-source) out)))
        (run-command clang harness-path blcodes-asm-path "-o" exe-path)
        (run-command exe-path)
        (check-true #t)))]))

(define (check-asmp-code-counts)
  (define clang (find-executable-path "clang"))
  (define racket-exe (find-system-path (quote exec-file)))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman HLIT/HDIST count helper: clang not found\n")
     (check-true #t)]
    [(not racket-exe)
     (printf "skip dynamic Huffman HLIT/HDIST count helper: racket not found\n")
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define code-counts-asm-path (build-path dir "code-counts.s"))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     code-counts-asm-path
                     dynamic-code-counts-source)
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out) (display (asmp-code-counts-harness-source) out)))
        (run-command clang harness-path code-counts-asm-path "-o" exe-path)
        (run-command exe-path)
        (check-true #t)))]))

(define (check-asmp-compact-header)
  (define clang (find-executable-path "clang"))
  (define racket-exe (find-system-path (quote exec-file)))
  (cond
    [(not clang)
     (printf "skip dynamic Huffman compact header helper: clang not found\n")
     (check-true #t)]
    [(not racket-exe)
     (printf "skip dynamic Huffman compact header helper: racket not found\n")
     (check-true #t)]
    [else
     (call-with-temp-dir
      (lambda (dir)
        (define header-asm-path (build-path dir "compact-header.s"))
        (define harness-path (build-path dir "harness.c"))
        (define exe-path (build-path dir "harness"))
        (run-command racket-exe
                     cli-source
                     "--gnu-input"
                     "--apple"
                     "--elim"
                     "-o"
                     header-asm-path
                     dynamic-compact-header-source)
        (call-with-output-file harness-path
          #:exists 'truncate/replace
          (lambda (out) (display (asmp-compact-header-harness-source) out)))
        (run-command clang harness-path header-asm-path "-o" exe-path)
        (run-command exe-path)
        (check-true #t)))]))

(define dynamic-huffman-reference-tests
  (test-suite
   "dynamic Huffman reference encoder"

   (test-case "canonical codes are assigned in symbol order within each length"
     (define codes (canonical-codes '(2 2 3 0 3)))
     (check-equal? (vector-ref codes 0) (cons 0 2))
     (check-equal? (vector-ref codes 1) (cons 1 2))
     (check-equal? (vector-ref codes 2) (cons 4 3))
     (check-false (vector-ref codes 3))
     (check-equal? (vector-ref codes 4) (cons 5 3)))

   (test-case "literal-only dynamic block roundtrips through zlib"
     (check-zlib-roundtrip "empty" #"")
     (check-zlib-roundtrip "text" #"hello hello hello\n")
     (check-zlib-roundtrip
      "high-literals"
      (apply bytes (for/list ([i (in-range 112)]) (+ 144 i)))))

   (test-case "frequency-driven literal-only dynamic block roundtrips through zlib"
     (check-zlib-roundtrip
      "empty/frequency"
      #""
      dynamic-literal-frequency-raw-deflate)
     (check-zlib-roundtrip
      "skewed/frequency"
      #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabz"
      dynamic-literal-frequency-raw-deflate)
     (check-zlib-roundtrip
      "high-literals/frequency"
      (apply bytes (for/list ([i (in-range 112)]) (+ 144 i)))
     dynamic-literal-frequency-raw-deflate))

   (test-case "balanced literal-only dynamic block roundtrips through zlib"
     (check-zlib-roundtrip
      "empty/balanced"
      #""
      dynamic-balanced-literal-raw-deflate)
     (check-zlib-roundtrip
      "text/balanced"
      #"hello hello dynamic huffman\n"
      dynamic-balanced-literal-raw-deflate)
     (check-zlib-roundtrip
      "high-literals/balanced"
      (apply bytes (for/list ([i (in-range 112)]) (+ 144 i)))
      dynamic-balanced-literal-raw-deflate))

   (test-case "compact balanced literal-only dynamic block roundtrips through zlib"
     (check-zlib-roundtrip
      "empty/compact-balanced"
      #""
      dynamic-compact-balanced-literal-raw-deflate)
     (check-zlib-roundtrip
      "text/compact-balanced"
      #"hello hello dynamic huffman\n"
      dynamic-compact-balanced-literal-raw-deflate)
     (check-zlib-roundtrip
      "high-literals/compact-balanced"
      (apply bytes (for/list ([i (in-range 112)]) (+ 144 i)))
      dynamic-compact-balanced-literal-raw-deflate))

   (test-case "compact trimmed literal-only dynamic block roundtrips through zlib"
     (check-zlib-roundtrip
      "empty/compact-trimmed"
      #""
      dynamic-compact-balanced-trimmed-literal-raw-deflate)
     (check-zlib-roundtrip
      "text/compact-trimmed"
      #"hello hello dynamic huffman\n"
      dynamic-compact-balanced-trimmed-literal-raw-deflate)
     (check-zlib-roundtrip
      "high-literals/compact-trimmed"
      (apply bytes (for/list ([i (in-range 112)]) (+ 144 i)))
      dynamic-compact-balanced-trimmed-literal-raw-deflate))

   (test-case "compact Huffman literal-only dynamic block roundtrips through zlib"
     (check-zlib-roundtrip
      "empty/compact-huffman"
      #""
      dynamic-compact-huffman-trimmed-literal-raw-deflate)
     (check-zlib-roundtrip
      "text/compact-huffman"
      #"hello hello dynamic huffman\n"
      dynamic-compact-huffman-trimmed-literal-raw-deflate)
     (check-zlib-roundtrip
      "high-literals/compact-huffman"
      (apply bytes (for/list ([i (in-range 112)]) (+ 144 i)))
      dynamic-compact-huffman-trimmed-literal-raw-deflate))

   (test-case "compact dual-Huffman literal-only dynamic block roundtrips through zlib"
     (check-zlib-roundtrip
      "empty/compact-dual-huffman"
      #""
      dynamic-compact-dual-huffman-trimmed-literal-raw-deflate)
     (check-zlib-roundtrip
      "text/compact-dual-huffman"
      #"hello hello dynamic huffman\n"
      dynamic-compact-dual-huffman-trimmed-literal-raw-deflate)
     (check-zlib-roundtrip
      "high-literals/compact-dual-huffman"
      (apply bytes (for/list ([i (in-range 112)]) (+ 144 i)))
      dynamic-compact-dual-huffman-trimmed-literal-raw-deflate))

   (test-case "LZ77 dynamic-Huffman block roundtrips through zlib"
     (check-zlib-roundtrip
      "empty/lz77-huffman"
      #""
      dynamic-lz77-raw-deflate)
     (check-zlib-roundtrip
      "text/lz77-huffman"
      #"hello hello dynamic huffman\n"
      dynamic-lz77-raw-deflate)
     (check-zlib-roundtrip
      "repeated/lz77-huffman"
      (make-bytes 1024 (char->integer #\a))
      dynamic-lz77-raw-deflate)
     (check-zlib-roundtrip
      "periodic/lz77-huffman"
      (apply bytes
             (for/list ([i (in-range 2048)])
               (+ (char->integer #\A) (remainder i 7))))
      dynamic-lz77-raw-deflate))

   (test-case "frequency-driven lengths favor common literals"
     (define compressed (dynamic-literal-frequency-raw-deflate
                         #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabz"))
     (check-true (> (bytes-length compressed) 0))
     (define ll-lengths
       (literal-frequency-lengths #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabz"))
     (check-true (<= (list-ref ll-lengths (char->integer #\a))
                     (list-ref ll-lengths (char->integer #\b))))
     (check-true (<= (list-ref ll-lengths (char->integer #\a))
                     (list-ref ll-lengths (char->integer #\z)))))

   (test-case "code-length RLE uses deflate repeat symbols"
     (define events
       (code-length-rle-events
        (append (make-list 20 0)
                (make-list 5 7)
                (make-list 4 0))))
     (check-true
      (for/or ([event (in-list events)])
        (= (cl-event-symbol event) 18)))
     (check-true
      (for/or ([event (in-list events)])
        (= (cl-event-symbol event) 16)))
     (check-true
      (for/or ([event (in-list events)])
        (= (cl-event-symbol event) 17))))

   (test-case "asmp literal-only dynamic block matches the reference stream"
     (check-asmp-roundtrip "empty" #"")
     (check-asmp-roundtrip "text" #"hello hello hello\n")
     (check-asmp-roundtrip
      "high-literals"
      (apply bytes (for/list ([i (in-range 112)]) (+ 144 i)))))

   (test-case "asmp literal-frequency helper fills ll_freq"
     (check-asmp-litfreq))

   (test-case "asmp LZ77 frequency helper fills LL and distance frequencies"
     (check-asmp-lz77-freq))

   (test-case "asmp balanced literal-length helper fills ll_len"
     (check-asmp-litlen))

   (test-case "asmp Huffman literal-length helper fills frequency-driven ll_len"
     (check-asmp-litlen-huffman))

   (test-case "asmp Huffman distance-length helper fills frequency-driven dist_len"
     (check-asmp-distlen-huffman))

   (test-case "asmp canonical-code and bit-order helpers fill code tables"
     (check-asmp-canonical))

   (test-case "asmp code-length RLE helper matches the reference events"
     (check-asmp-code-length-rle))

   (test-case "asmp bit-length frequency helper counts RLE event symbols"
     (check-asmp-blfreq))

   (test-case "asmp balanced bit-length helper fills bl_len"
     (check-asmp-bllen))

   (test-case "asmp Huffman bit-length helper fills frequency-driven bl_len"
     (check-asmp-bllen-huffman))

   (test-case "asmp bit-length code count helper computes HCLEN count"
     (check-asmp-blcodes))

   (test-case "asmp dynamic code count helper computes HLIT and HDIST counts"
     (check-asmp-code-counts))

   (test-case "asmp compact dynamic header helper matches the reference bytes"
     (check-asmp-compact-header))

   (test-case "asmp balanced dynamic literal-only block matches the reference stream"
     (check-asmp-balanced "empty" #"")
     (check-asmp-balanced "text" #"hello hello dynamic huffman\n")
     (check-asmp-balanced
      "high-literals"
      (apply bytes (for/list ([i (in-range 112)]) (+ 144 i)))))

   (test-case "asmp compact balanced dynamic literal-only block matches the reference stream"
     (check-asmp-compact-balanced "empty" #"")
     (check-asmp-compact-balanced "text" #"hello hello dynamic huffman\n")
     (check-asmp-compact-balanced
      "high-literals"
      (apply bytes (for/list ([i (in-range 112)]) (+ 144 i)))))

   (test-case "asmp compact trimmed dynamic literal-only block matches the reference stream"
     (check-asmp-compact-balanced-trimmed "empty" #"")
     (check-asmp-compact-balanced-trimmed "text" #"hello hello dynamic huffman\n")
     (check-asmp-compact-balanced-trimmed
      "high-literals"
      (apply bytes (for/list ([i (in-range 112)]) (+ 144 i)))))

   (test-case "asmp compact Huffman dynamic literal-only block matches the reference stream"
     (check-asmp-compact-huffman-trimmed "empty" #"")
     (check-asmp-compact-huffman-trimmed "text" #"hello hello dynamic huffman\n")
     (check-asmp-compact-huffman-trimmed
      "high-literals"
      (apply bytes (for/list ([i (in-range 112)]) (+ 144 i)))))

   (test-case "asmp compact dual-Huffman dynamic literal-only block matches the reference stream"
     (check-asmp-compact-dual-huffman-trimmed "empty" #"")
     (check-asmp-compact-dual-huffman-trimmed "text" #"hello hello dynamic huffman\n")
     (check-asmp-compact-dual-huffman-trimmed
      "high-literals"
      (apply bytes (for/list ([i (in-range 112)]) (+ 144 i)))))

   (test-case "asmp LZ77 dynamic-Huffman block matches the reference stream"
     (check-asmp-lz77-huffman "empty" #"")
     (check-asmp-lz77-huffman "text" #"hello hello dynamic huffman\n")
     (check-asmp-lz77-huffman "repeated" (make-bytes 1024 (char->integer #\a)))
     (check-asmp-lz77-huffman
      "periodic"
      (apply bytes
             (for/list ([i (in-range 2048)])
               (+ (char->integer #\A) (remainder i 7))))))))

(module+ main
  (void (run-tests dynamic-huffman-reference-tests)))

(module+ test
  (void (run-tests dynamic-huffman-reference-tests)))
