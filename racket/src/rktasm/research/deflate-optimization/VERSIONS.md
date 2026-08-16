# Deflate Version Registry

Each row is a preserved implementation. New optimization ideas should add a
new row instead of replacing an older source file.

| Version | Source | Symbol | Scratch ABI | Status | Notes |
|---------|--------|--------|-------------|--------|-------|
| v0 | `example/009-deflate-fixed-fast.d` | `deflate_fixed_fast_aarch64` | `head[32768]` | pipeline example | S-expression bootstrap version. |
| v1 | `example/013-deflate-fixed-fast.asm` | `deflate_fixed_fast_aarch64_asm` | `head[32768]` | compile/assemble baseline | GNU `.asm`, one candidate per hash bucket. It is preserved for reading and pipeline comparison, but is not the native correctness baseline. |
| v2 | `example/019-deflate-fixed-chain.asm` | `deflate_fixed_chain_aarch64_asm` | `head[32768]`, `prev[32768]` | native roundtrip and benchmark baseline | Bounded hash chain with skipped-byte reinsertion and one-byte lazy lookahead. |
| stored-v0 | `example/019-deflate-fixed-chain.asm` | `deflate_stored_aarch64_asm` | none | native roundtrip and benchmark baseline | Raw stored-block encoder, split into 65535-byte stored blocks as required by deflate. |
| public-v0 | `example/019-deflate-fixed-chain.asm` | `asmp_deflate_raw_fixed` | caller scratch, currently `head[32768] + prev[32768]` | managed-signature public C wrapper and benchmark baseline | Returns status, writes `dst_len`, checks `dst_cap` and scratch size, calls v2 internally, and is the entrypoint used by the native compare runner. |
| public-stored-v0 | `example/019-deflate-fixed-chain.asm` | `asmp_deflate_raw_stored` | none | managed-signature public C wrapper and benchmark baseline | Returns status, writes `dst_len`, checks `dst_cap`, and calls stored-v0 internally. |
| public-auto-v0 | `example/019-deflate-fixed-chain.asm` | `asmp_deflate_raw_auto` | caller scratch, currently `head[32768] + prev[32768]` | managed-signature public C wrapper and benchmark baseline | Emits fixed output, compares it with exact stored length, and rewrites as stored if stored is no larger. This is a whole-stream selector, not a block-level dynamic policy. |
| dynamic-litonly-v0 | `example/020-deflate-dynamic-litonly.asm` | `asmp_deflate_raw_dynamic_litonly` | none | native roundtrip and reference-byte match | Emits one literal-only dynamic block with a fixed complete dynamic tree. This proves dynamic header and canonical-code emission, not compression quality. |
| dynamic-litfreq-v0 | `example/021-deflate-dynamic-litfreq.asm` | `asmp_deflate_dynamic_litfreq_count` | caller-provided `ll_freq[286]` | native frequency-table validation | Fills literal/length frequencies and EOB count for the future dynamic tree builder. It does not emit a deflate stream. |
| dynamic-litlen-balanced-v0 | `example/022-deflate-dynamic-litlen-balanced.asm` | `asmp_deflate_dynamic_litlen_balanced` | caller-provided `ll_freq[286] + ll_len[286]` | native length-table validation | Produces a valid balanced literal/length code-length table from active symbols. This is not frequency-optimal Huffman yet; it is a native scaffold for later tree build. |
| dynamic-canonical-v0 | `example/028-deflate-dynamic-canonical-codes.asm` | `asmp_deflate_dynamic_canonical_codes` | caller-provided `ll_len[286] + ll_code[286] + scratch[128]` | native canonical-code validation | Counts bit lengths, builds `next_code[16]`, and fills symbol-order canonical codes. Codes are not bit-reversed here; the deflate bit writer reverses them when emitting bits. |
| dynamic-reverse-v0 | `example/029-deflate-dynamic-reverse-codes.asm` | `asmp_deflate_dynamic_reverse_codes` | caller-provided `ll_len[286] + ll_code[286] + ll_bit_code[286]` | native bit-order code validation | Converts canonical codes into deflate's least-significant-bit-first emission form using `rbit` and the symbol length. This is the table form a later dynamic bit writer can consume directly. |
| dynamic-balanced-litonly-v0 | `example/030-deflate-dynamic-balanced-litonly.asm` | `asmp_deflate_raw_dynamic_balanced` | caller-provided 2704-byte scratch (`ll_freq`, `ll_len`, `ll_code`, `ll_bit_code`, canonical scratch) | native roundtrip and reference-byte match | Wires 021/022/028/029 into a public raw-deflate wrapper. It emits literal-only dynamic blocks with balanced literal/length lengths and a deliberately simple non-RLE code-length header. This is a native integration baseline, not an optimal dynamic tree builder and not an LZ77 dynamic-block encoder. |
| dynamic-code-length-rle-v0 | `example/031-deflate-dynamic-code-length-rle.asm` | `asmp_deflate_dynamic_code_length_rle` | caller-provided event table, 4 bytes per event | native event-table validation | Converts a combined code-length sequence into deflate RLE events over symbols `0..18`, including repeat symbols `16`, `17`, and `18`. This is the native input to the future bit-length tree builder; it does not emit header bits by itself. |
| dynamic-blfreq-v0 | `example/032-deflate-dynamic-blfreq.asm` | `asmp_deflate_dynamic_blfreq_count` | caller-provided `bl_freq[19]` | native bit-length frequency validation | Counts code-length alphabet symbol frequencies from the 031 event table. This provides the native frequency input for the future bit-length tree builder. |
| dynamic-bllen-balanced-v0 | `example/033-deflate-dynamic-bllen-balanced.asm` | `asmp_deflate_dynamic_bllen_balanced` | caller-provided `bl_freq[19] + bl_len[19]` | native bit-length length validation | Produces a valid balanced code-length alphabet length table from `bl_freq[19]`. This is the small-tree counterpart to 022 and remains a scaffold before the frequency-optimal length-limited tree builder. |
| dynamic-blcodes-v0 | `example/034-deflate-dynamic-blcodes-count.asm` | `asmp_deflate_dynamic_blcodes_count` | caller-provided `bl_len[19]` | native HCLEN-count validation | Computes `blcodes`, the `HCLEN + 4` count for the dynamic header, in deflate's code-length alphabet order and validates that every `bl_len` entry is at most 7. |
| dynamic-compact-header-v0 | `example/035-deflate-dynamic-compact-header.asm` | `asmp_deflate_dynamic_compact_header` | params struct with `bl_len`, `bl_bit_code`, 031 event table, `lcodes`, `dcodes` | native byte-for-byte header validation | Emits the compact dynamic-Huffman block header bits, including `BFINAL/BTYPE`, `HLIT`, `HDIST`, `HCLEN`, permuted code-length alphabet lengths, and RLE events encoded through the bit-length tree. It validates bounds and event symbols but does not emit payload symbols. |
| dynamic-compact-balanced-litonly-v0 | `example/036-deflate-dynamic-compact-balanced-litonly.asm` | `asmp_deflate_raw_dynamic_compact_balanced` | caller-provided 4320-byte scratch (`ll_freq`, `ll_len`, LL code tables, combined lengths, RLE events, BL freq/len/code tables, canonical scratch) | native roundtrip and reference-byte match | Wires 021/022/028/029/031/032/033 plus a continuous bit writer into a full literal-only dynamic stream with a compact RLE header. It preserves 030 as the non-RLE baseline and still uses balanced scaffold lengths rather than frequency-optimal tree construction. |
| dynamic-code-counts-v0 | `example/037-deflate-dynamic-code-counts.asm` | `asmp_deflate_dynamic_code_counts` | caller-provided `ll_len[286] + dist_len[30]` and two output slots | native HLIT/HDIST-count validation | Computes trimmed dynamic-header declaration counts: `lcodes = max(257, last_nonzero_ll + 1)` and `dcodes = max(1, last_nonzero_dist + 1)`. It validates Deflate's 15-bit length limit and rejects a missing EOB code. |
| dynamic-compact-trimmed-litonly-v0 | `example/038-deflate-dynamic-compact-trimmed-litonly.asm` | `asmp_deflate_raw_dynamic_compact_balanced_trimmed` | caller-provided 4512-byte scratch (`ll_freq`, LL code tables, `dist_len[30]`, trimmed combined lengths, RLE events, BL tables, count slots) | native roundtrip and reference-byte match | Integrates 037 into the compact literal-only dynamic stream so the RLE header sequence is based on trimmed `HLIT/HDIST` counts instead of the fixed 286+1 sequence. It remains literal-only and still uses balanced scaffold lengths. |
| dynamic-litlen-huffman-v0 | `example/039-deflate-dynamic-litlen-huffman.asm` | `asmp_deflate_dynamic_litlen_huffman` | caller-provided `ll_freq[286] + ll_len[286] + 6864-byte scratch` | native length-table validation against Racket oracle | Builds frequency-driven literal/length Huffman lengths with a simple O(n^2) native tree builder, stable symbol tie-breaks, and bit-length-count overflow repair for Deflate's 15-bit limit. It is the LL tree builder used by the later compact Huffman literal-only streams. |
| dynamic-compact-huffman-litonly-v0 | `example/040-deflate-dynamic-compact-huffman-litonly.asm` | `asmp_deflate_raw_dynamic_compact_huffman_trimmed` | caller-provided 11376-byte scratch (`038` layout plus 039 LL-Huffman scratch) | native roundtrip and reference-byte match | Integrates 039 into the compact trimmed literal-only dynamic stream, so literal/length code lengths are frequency-driven with 15-bit repair. The bit-length tree still uses the balanced 033 scaffold, and the payload is still literal-only. |
| dynamic-bllen-huffman-v0 | `example/041-deflate-dynamic-bllen-huffman.asm` | `asmp_deflate_dynamic_bllen_huffman` | caller-provided `bl_freq[19] + bl_len[19] + 456-byte scratch` | native length-table validation against Racket oracle | Builds frequency-driven bit-length alphabet Huffman lengths with a simple O(n^2) native tree builder, stable symbol tie-breaks, minimum two-code insertion, and 7-bit overflow repair. |
| dynamic-compact-dual-huffman-litonly-v0 | `example/042-deflate-dynamic-compact-dual-huffman-litonly.asm` | `asmp_deflate_raw_dynamic_compact_dual_huffman_trimmed` | caller-provided 11832-byte scratch (`040` layout plus 041 BL-Huffman scratch) | native roundtrip and reference-byte match | Integrates 039 and 041 into the compact trimmed literal-only dynamic stream, so both literal/length and bit-length code lengths are frequency-driven. The payload remains literal-only; LZ77 length/distance events are still not encoded in dynamic blocks. |
| dynamic-lz77-freq-v0 | `example/043-deflate-dynamic-lz77-freq.asm` | `asmp_deflate_dynamic_lz77_freq_count` | caller-provided `ll_freq[286] + dist_freq[30] + 262144-byte scratch` (`head[32768] + prev[32768]`) | native frequency-table validation against Racket parser oracle | Reuses the 019 bounded hash-chain parser policy to count literal/length and distance frequencies, including lazy matches and skipped-byte reinsertion. It prepares dynamic LZ77 tree input but does not emit a deflate stream. |
| dynamic-distlen-huffman-v0 | `example/044-deflate-dynamic-distlen-huffman.asm` | `asmp_deflate_dynamic_distlen_huffman` | caller-provided `dist_freq[30] + dist_len[30] + 8304-byte scratch` | native length-table validation against Racket oracle | Builds frequency-driven distance Huffman lengths by mapping the 30-symbol distance alphabet into 039's 15-bit LL Huffman builder, then copying back the first 30 lengths. All-zero distance frequencies produce all-zero lengths for literal-only dynamic blocks. |
| dynamic-lz77-huffman-v0 | `example/045-deflate-dynamic-lz77-huffman.asm` | `asmp_deflate_raw_dynamic_lz77_huffman` | caller-provided 282528-byte scratch (`042` dynamic tables plus 043/044 parser/tree scratch) | native roundtrip, reference-byte match, and benchmark row | First complete native dynamic-Huffman block with LZ77 payload. It runs the 019-style parser twice: first for LL/DIST frequencies, then for payload emission using dynamic LL and distance code tables. It is an integration MVP and an explicit benchmark codec, not yet part of the public auto selector. |
| auto-dynamic-probe-v0 | `example/046-deflate-auto-dynamic-probe.asm` | `asmp_deflate_raw_auto_dynamic_probe` | caller scratch, currently 282528 bytes to cover the dynamic path | native roundtrip and benchmark row | First measured stored/fixed-vs-dynamic selector probe. Inputs shorter than 96 bytes tail-branch to the stable 019 `asmp_deflate_raw_auto`; larger inputs tail-branch to 045 dynamic-Huffman LZ77. It is deliberately versioned and does not replace the stable `asmp_deflate_raw_auto` symbol. |
| auto-dynamic-cost-probe-v0 | `example/047-deflate-auto-cost-probe.asm` | `asmp_deflate_raw_auto_dynamic_cost_probe` | caller scratch, currently 282528 bytes to cover the dynamic path and 043 probe | native roundtrip, library build, and benchmark row | First selector probe that inspects LZ77 evidence before choosing dynamic. It keeps short inputs and low-match inputs on the stable fixed/stored auto wrapper, and selects 045 only when the 043 distance-frequency pass reports enough match tokens. This preserves the 046 compressed sizes on the current compressible corpus while avoiding dynamic for high-literal and deterministic randomish low-match samples. |
| auto-dynamic-size-probe-v0 | `example/048-deflate-auto-size-probe.asm` | `asmp_deflate_raw_auto_dynamic_size_probe` | caller scratch, currently 282528 bytes to cover the dynamic path and size model | native roundtrip, library build, and benchmark row | Selector probe that estimates fixed, stored, and dynamic byte size before choosing. It reuses 043/039/044/031/032/041 to build frequency and code-length metadata, counts dynamic header/payload bits, estimates the stable fixed-vs-stored auto size, and selects 045 only when dynamic is strictly smaller. |
| auto-dynamic-prepared-size-probe-v0 | `example/049-deflate-auto-prepared-size-probe.asm` | `asmp_deflate_raw_auto_dynamic_prepared_size_probe` | caller scratch, currently 282528 bytes to cover the dynamic path and prepared metadata | native roundtrip, library build, and benchmark row | Prepared version of 048. It builds the dynamic metadata once, uses it for the same size decision, and when dynamic wins emits from the prepared scratch tables instead of tail-calling 045 and rebuilding LL/DIST/BL Huffman metadata. |
| auto-dynamic-cheap-prepared-size-probe-v0 | `example/050-deflate-auto-cheap-prepared-size-probe.asm` | `asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe` | caller scratch, currently 282528 bytes to cover the dynamic path and prepared metadata | native roundtrip, library build, and benchmark row | Cheap-gated version of 049. Inputs below 512 bytes still enter the full size model, but larger inputs first run the 043 distance-frequency gate; low-match inputs fall back to stable auto before building Huffman trees, while match-rich inputs reuse the gate frequency tables during prepare. |
| blocked-fixed-v0 | `example/051-deflate-blocked-fixed.asm` | `asmp_deflate_raw_blocked_fixed` | caller scratch, currently `head[32768] + prev[32768]` | native roundtrip, library build, benchmark row, and 32769-byte E2E boundary test | First split-block raw-deflate stream implementation. It emits 32 KiB fixed-Huffman LZ77 blocks, keeps `x.out/x.bitbuf/w.bit_count` live across block boundaries, sets BFINAL only on the final block, and flushes tail bits once at stream end. This is a block framing MVP, not yet the final dynamic/stored block selector. |
| blocked-auto-v0 | `example/052-deflate-blocked-auto.asm` | `asmp_deflate_raw_blocked_auto` | caller scratch, currently `head[32768] + prev[32768]` | native roundtrip, library build, benchmark row, stored-fallback E2E tests | Fixed/stored split-block selector built on 051. Each block speculatively emits fixed-Huffman output, compares it with the stored-block byte cost from the saved entry bit state, and rewinds to emit stored when stored is smaller. It validates mixed compressed/stored block framing before dynamic blocks are added to the block loop. |
| blocked-dynamic-auto-v0 | `example/053-deflate-blocked-dynamic-auto.asm` | `asmp_deflate_raw_blocked_dynamic_auto` | caller scratch, currently 282528 bytes shared by prepared dynamic metadata and fixed fallback tables | native roundtrip, library build, benchmark row, dynamic/fixed/stored E2E tests | Fixed/stored/dynamic split-block selector built on 052. Each 32 KiB block runs the cheap match gate, prepares dynamic metadata once when useful, emits dynamic from prepared tables when modeled smaller, and otherwise rewinds to the fixed/stored fallback. It is experimental and does not replace `asmp_deflate_raw_auto`. |
| word-extend-v0 | `example/023-deflate-fixed-chain-word-extend.asm` | `asmp_deflate_raw_fixed_word_extend` | caller scratch, currently `head[32768] + prev[32768]` | native roundtrip and benchmark baseline | Preserves the 019 parser policy and fixed-Huffman output but changes LZ77 match extension from byte-at-a-time to 8-byte chunk compare plus `rbit`/`clz` mismatch location. |
| neon-extend-v0 | `example/024-deflate-fixed-chain-neon-extend.asm` | `asmp_deflate_raw_fixed_neon_extend` | caller scratch, currently `head[32768] + prev[32768]` | native roundtrip and benchmark baseline | Preserves the 023 parser policy and compressed output, but skips equal 16-byte match chunks with NEON `ldr q` / `eor v.16b` / `umaxv` before falling back to the scalar 8-byte mismatch locator. The core implementation is a hand-written `source-variant` with `feature=neon`; versioned public wrappers select it through logical `.call` hints, and weak stable `asmp_deflate_raw_*` defaults forward to this build when no stronger default is linked. |
| default-neon-dispatch-v0 | `example/025-deflate-default-neon-dispatch.asm` | `asmp_deflate_raw_fixed` | same as selected implementation | native link/roundtrip validation with 024 | Strong stable raw-deflate entrypoints that tail-branch to the 024 NEON-extend wrappers. This is a build-time selector object, not a compressor implementation and not runtime CPU dispatch. |
| default-word-dispatch-v0 | `example/026-deflate-default-word-dispatch.asm` | `asmp_deflate_raw_fixed` | same as selected implementation | native link/roundtrip validation with 023 | Strong stable raw-deflate entrypoints that tail-branch to the 023 word-extend wrappers. This gives the build-time selector model a scalar-ish non-NEON option with the same stable C API. |
| runtime-dispatch-v0 | `example/027-deflate-runtime-dispatch.asm` | `asmp_deflate_raw_fixed` | same as selected implementation | native runtime feature toggle/init/override validation with 023+024 | Strong stable raw-deflate entrypoints that load cached target pointers and `br` to the selected implementation. The hidden no-header init entrypoint calls the weak hidden detector hook, which currently returns baseline NEON and can be replaced by a strong platform definition, then passes the feature word through the setter. The setter records `asmp_deflate_runtime_features`, chooses a target table, and copies it into the selected slots. Bit 0 clear selects word-extend, bit 0 set selects NEON-extend. |

## ABI Notes

All current versions return the number of compressed bytes in `x0`.

The public wrapper returns a status code in `w0` and writes the compressed size
through `dst_len`.

`013` C prototype:

```c
uint64_t deflate_fixed_fast_aarch64_asm(uint8_t *dst,
                                        const uint8_t *src,
                                        uint64_t len,
                                        uint32_t *head);
```

`019` C prototype:

```c
uint64_t deflate_fixed_chain_aarch64_asm(uint8_t *dst,
                                         const uint8_t *src,
                                         uint64_t len,
                                         uint32_t *head,
                                         uint32_t *prev);
```

Public wrapper C prototype:

```c
int asmp_deflate_raw_fixed(uint8_t *dst,
                           uint64_t dst_cap,
                           uint64_t *dst_len,
                           const uint8_t *src,
                           uint64_t src_len,
                           void *scratch,
                           uint64_t scratch_len);

int asmp_deflate_raw_stored(uint8_t *dst,
                            uint64_t dst_cap,
                            uint64_t *dst_len,
                            const uint8_t *src,
                            uint64_t src_len);

int asmp_deflate_raw_auto(uint8_t *dst,
                          uint64_t dst_cap,
                          uint64_t *dst_len,
                          const uint8_t *src,
                          uint64_t src_len,
                          void *scratch,
                          uint64_t scratch_len);

uint64_t asmp_deflate_raw_dynamic_litonly_bound(uint64_t src_len);

int asmp_deflate_raw_dynamic_litonly(uint8_t *dst,
                                     uint64_t dst_cap,
                                     uint64_t *dst_len,
                                     const uint8_t *src,
                                     uint64_t src_len);

int asmp_deflate_dynamic_litfreq_count(const uint8_t *src,
                                       uint64_t src_len,
                                       void *freq_ptr,
                                       uint64_t freq_len);

int asmp_deflate_dynamic_litlen_balanced(void *freq_ptr,
                                         uint64_t freq_len,
                                         void *len_ptr,
                                         uint64_t len_len);

int asmp_deflate_dynamic_canonical_codes(void *len_ptr,
                                         uint64_t count,
                                         void *code_ptr,
                                         uint64_t code_len,
                                         void *scratch_ptr,
                                         uint64_t scratch_len);

int asmp_deflate_dynamic_reverse_codes(void *len_ptr,
                                       uint64_t count,
                                       void *code_ptr,
                                       uint64_t code_len,
                                       void *bit_code_ptr,
                                       uint64_t bit_code_len);

uint64_t asmp_deflate_raw_dynamic_balanced_bound(uint64_t src_len);

uint64_t asmp_deflate_raw_dynamic_balanced_scratch_size(void);

uint64_t asmp_deflate_raw_dynamic_balanced_scratch_align(void);

int asmp_deflate_raw_dynamic_balanced(uint8_t *dst,
                                      uint64_t dst_cap,
                                      uint64_t *dst_len,
                                      const uint8_t *src,
                                      uint64_t src_len,
                                      void *scratch,
                                      uint64_t scratch_len);

int asmp_deflate_dynamic_code_length_rle(const uint8_t *len_ptr,
                                         uint64_t count,
                                         void *event_ptr,
                                         uint64_t event_cap,
                                         uint64_t *event_count_ptr);

int asmp_deflate_dynamic_blfreq_count(const void *event_ptr,
                                      uint64_t event_count,
                                      void *freq_ptr,
                                      uint64_t freq_len);

int asmp_deflate_dynamic_bllen_balanced(void *freq_ptr,
                                        uint64_t freq_len,
                                        void *len_ptr,
                                        uint64_t len_len);

int asmp_deflate_dynamic_blcodes_count(const uint8_t *len_ptr,
                                       uint64_t len_len,
                                       uint64_t *blcodes_ptr);

int asmp_deflate_dynamic_code_counts(const uint8_t *ll_len_ptr,
                                     uint64_t ll_len_len,
                                     const uint8_t *dist_len_ptr,
                                     uint64_t dist_len_len,
                                     uint64_t *lcodes_ptr,
                                     uint64_t *dcodes_ptr);

int asmp_deflate_dynamic_litlen_huffman(void *freq_ptr,
                                        uint64_t freq_len,
                                        void *len_ptr,
                                        uint64_t len_len,
                                        void *scratch_ptr,
                                        uint64_t scratch_len);

int asmp_deflate_dynamic_bllen_huffman(void *freq_ptr,
                                       uint64_t freq_len,
                                       void *len_ptr,
                                       uint64_t len_len,
                                       void *scratch_ptr,
                                       uint64_t scratch_len);

struct asmp_deflate_dynamic_compact_header_params {
  const uint8_t *bl_len_ptr;
  const uint16_t *bl_bit_code_ptr;
  const uint8_t *event_ptr;
  uint64_t event_count;
  uint64_t lcodes;
  uint64_t dcodes;
};

int asmp_deflate_dynamic_compact_header(uint8_t *dst,
                                        uint64_t dst_cap,
                                        uint64_t *dst_len,
                                        const struct asmp_deflate_dynamic_compact_header_params *params);

uint64_t asmp_deflate_raw_dynamic_compact_balanced_bound(uint64_t src_len);

uint64_t asmp_deflate_raw_dynamic_compact_balanced_scratch_size(void);

uint64_t asmp_deflate_raw_dynamic_compact_balanced_scratch_align(void);

int asmp_deflate_raw_dynamic_compact_balanced(uint8_t *dst,
                                              uint64_t dst_cap,
                                              uint64_t *dst_len,
                                              const uint8_t *src,
                                              uint64_t src_len,
                                              void *scratch,
                                              uint64_t scratch_len);

uint64_t asmp_deflate_raw_dynamic_compact_balanced_trimmed_bound(uint64_t src_len);

uint64_t asmp_deflate_raw_dynamic_compact_balanced_trimmed_scratch_size(void);

uint64_t asmp_deflate_raw_dynamic_compact_balanced_trimmed_scratch_align(void);

int asmp_deflate_raw_dynamic_compact_balanced_trimmed(uint8_t *dst,
                                                      uint64_t dst_cap,
                                                      uint64_t *dst_len,
                                                      const uint8_t *src,
                                                      uint64_t src_len,
                                                      void *scratch,
                                                      uint64_t scratch_len);

uint64_t asmp_deflate_raw_dynamic_compact_huffman_trimmed_bound(uint64_t src_len);

uint64_t asmp_deflate_raw_dynamic_compact_huffman_trimmed_scratch_size(void);

uint64_t asmp_deflate_raw_dynamic_compact_huffman_trimmed_scratch_align(void);

int asmp_deflate_raw_dynamic_compact_huffman_trimmed(uint8_t *dst,
                                                     uint64_t dst_cap,
                                                     uint64_t *dst_len,
                                                     const uint8_t *src,
                                                     uint64_t src_len,
                                                     void *scratch,
                                                     uint64_t scratch_len);

uint64_t asmp_deflate_raw_dynamic_compact_dual_huffman_trimmed_bound(uint64_t src_len);

uint64_t asmp_deflate_raw_dynamic_compact_dual_huffman_trimmed_scratch_size(void);

uint64_t asmp_deflate_raw_dynamic_compact_dual_huffman_trimmed_scratch_align(void);

int asmp_deflate_raw_dynamic_compact_dual_huffman_trimmed(uint8_t *dst,
                                                          uint64_t dst_cap,
                                                          uint64_t *dst_len,
                                                          const uint8_t *src,
                                                          uint64_t src_len,
                                                          void *scratch,
                                                          uint64_t scratch_len);

uint64_t asmp_deflate_dynamic_lz77_freq_scratch_size(void);

uint64_t asmp_deflate_dynamic_lz77_freq_scratch_align(void);

int asmp_deflate_dynamic_lz77_freq_count(const uint8_t *src,
                                         uint64_t src_len,
                                         void *ll_freq_ptr,
                                         uint64_t ll_freq_len,
                                         void *dist_freq_ptr,
                                         uint64_t dist_freq_len,
                                         void *scratch_ptr,
                                         uint64_t scratch_len);

int asmp_deflate_dynamic_distlen_huffman(void *freq_ptr,
                                         uint64_t freq_len,
                                         void *len_ptr,
                                         uint64_t len_len,
                                         void *scratch_ptr,
                                         uint64_t scratch_len);

uint64_t asmp_deflate_raw_dynamic_lz77_huffman_bound(uint64_t src_len);

uint64_t asmp_deflate_raw_dynamic_lz77_huffman_scratch_size(void);

uint64_t asmp_deflate_raw_dynamic_lz77_huffman_scratch_align(void);

int asmp_deflate_raw_dynamic_lz77_huffman(uint8_t *dst,
                                          uint64_t dst_cap,
                                          uint64_t *dst_len,
                                          const uint8_t *src,
                                          uint64_t src_len,
                                          void *scratch,
                                          uint64_t scratch_len);

uint64_t asmp_deflate_raw_auto_dynamic_probe_bound(uint64_t src_len);

uint64_t asmp_deflate_raw_auto_dynamic_probe_scratch_size(void);

uint64_t asmp_deflate_raw_auto_dynamic_probe_scratch_align(void);

int asmp_deflate_raw_auto_dynamic_probe(uint8_t *dst,
                                        uint64_t dst_cap,
                                        uint64_t *dst_len,
                                        const uint8_t *src,
                                        uint64_t src_len,
                                        void *scratch,
                                        uint64_t scratch_len);

uint64_t asmp_deflate_raw_auto_dynamic_cost_probe_bound(uint64_t src_len);

uint64_t asmp_deflate_raw_auto_dynamic_cost_probe_scratch_size(void);

uint64_t asmp_deflate_raw_auto_dynamic_cost_probe_scratch_align(void);

int asmp_deflate_raw_auto_dynamic_cost_probe(uint8_t *dst,
                                             uint64_t dst_cap,
                                             uint64_t *dst_len,
                                             const uint8_t *src,
                                             uint64_t src_len,
                                             void *scratch,
                                             uint64_t scratch_len);

uint64_t asmp_deflate_raw_auto_dynamic_size_probe_bound(uint64_t src_len);

uint64_t asmp_deflate_raw_auto_dynamic_size_probe_scratch_size(void);

uint64_t asmp_deflate_raw_auto_dynamic_size_probe_scratch_align(void);

int asmp_deflate_raw_auto_dynamic_size_probe(uint8_t *dst,
                                             uint64_t dst_cap,
                                             uint64_t *dst_len,
                                             const uint8_t *src,
                                             uint64_t src_len,
                                             void *scratch,
                                             uint64_t scratch_len);

uint64_t asmp_deflate_raw_auto_dynamic_prepared_size_probe_bound(uint64_t src_len);

uint64_t asmp_deflate_raw_auto_dynamic_prepared_size_probe_scratch_size(void);

uint64_t asmp_deflate_raw_auto_dynamic_prepared_size_probe_scratch_align(void);

int asmp_deflate_raw_auto_dynamic_prepared_size_probe(uint8_t *dst,
                                                      uint64_t dst_cap,
                                                      uint64_t *dst_len,
                                                      const uint8_t *src,
                                                      uint64_t src_len,
                                                      void *scratch,
                                                      uint64_t scratch_len);

uint64_t asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_bound(uint64_t src_len);

uint64_t asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_scratch_size(void);

uint64_t asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_scratch_align(void);

int asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe(uint8_t *dst,
                                                            uint64_t dst_cap,
                                                            uint64_t *dst_len,
                                                            const uint8_t *src,
                                                            uint64_t src_len,
                                                            void *scratch,
                                                            uint64_t scratch_len);

uint64_t asmp_deflate_raw_blocked_fixed_bound(uint64_t src_len);

uint64_t asmp_deflate_raw_blocked_fixed_scratch_size(void);

uint64_t asmp_deflate_raw_blocked_fixed_scratch_align(void);

int asmp_deflate_raw_blocked_fixed(uint8_t *dst,
                                   uint64_t dst_cap,
                                   uint64_t *dst_len,
                                   const uint8_t *src,
                                   uint64_t src_len,
                                   void *scratch,
                                   uint64_t scratch_len);

uint64_t asmp_deflate_raw_blocked_auto_bound(uint64_t src_len);

uint64_t asmp_deflate_raw_blocked_auto_scratch_size(void);

uint64_t asmp_deflate_raw_blocked_auto_scratch_align(void);

int asmp_deflate_raw_blocked_auto(uint8_t *dst,
                                  uint64_t dst_cap,
                                  uint64_t *dst_len,
                                  const uint8_t *src,
                                  uint64_t src_len,
                                  void *scratch,
                                  uint64_t scratch_len);

uint64_t asmp_deflate_raw_blocked_dynamic_auto_bound(uint64_t src_len);

uint64_t asmp_deflate_raw_blocked_dynamic_auto_scratch_size(void);

uint64_t asmp_deflate_raw_blocked_dynamic_auto_scratch_align(void);

int asmp_deflate_raw_blocked_dynamic_auto(uint8_t *dst,
                                          uint64_t dst_cap,
                                          uint64_t *dst_len,
                                          const uint8_t *src,
                                          uint64_t src_len,
                                          void *scratch,
                                          uint64_t scratch_len);

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
```

## Version Naming

Use numbered source files for algorithm versions:

```text
020-deflate-reinsert.asm
021-deflate-lazy.asm
022-deflate-word-extend.asm
```

Keep exported symbols unique. This lets benchmark harnesses link multiple
versions into one executable for side-by-side comparison.

## Native Benchmark Inclusion

`bench-native.rkt` should include only versions that are safe to call from a C
harness and pass raw-deflate roundtrip. Older preserved versions can remain in
this registry without being executed by the native benchmark.
