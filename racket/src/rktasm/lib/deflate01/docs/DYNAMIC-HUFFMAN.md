# Dynamic Huffman Implementation Notes

This note records the implementation route for dynamic-Huffman deflate in
asmp. It deliberately starts with a small verified reference encoder before the
tree builder is moved into assembly.

## References

- RFC 1951 is the bitstream authority. Section 3.2.7 defines dynamic blocks:
  `HLIT`, `HDIST`, `HCLEN`, the code-length alphabet order, repeat symbols
  `16..18`, and the combined literal/length plus distance length sequence.
  https://www.rfc-editor.org/rfc/rfc1951
- zlib `trees.c` is the engineering reference for compression-side tree
  construction: build literal/distance trees, scan them to build the bit-length
  tree, then send all trees before the data. The useful functions to mirror are
  `build_tree`, `gen_bitlen`, `gen_codes`, `build_bl_tree`, `scan_tree`,
  `send_tree`, and `send_all_trees`.
  https://www.ncbi.nlm.nih.gov/IEB/ToolBox/CPP_DOC/lxr/source/src/util/compress/zlib/trees.c
- zlib `contrib/puff/puff.c` is the readability reference for decode-side
  dynamic block structure and edge cases. Its comments are especially useful
  for incomplete trees, the single-distance-code case, and code-length repeat
  symbols.
  https://git.acem.ece.illinois.edu/lib/zlib-1.2.13/src/branch/main/contrib/puff/puff.c
- Huffman's original paper is the algorithmic root for optimal prefix codes:
  D. A. Huffman, "A Method for the Construction of Minimum-Redundancy Codes",
  Proceedings of the IRE, 1952.

## Why It Is More Complex Than Fixed Huffman

Fixed Huffman only needs fixed code tables and a bit writer. Dynamic Huffman
adds four extra jobs:

1. Count literal/length and distance symbol frequencies for a block.
2. Build length-limited canonical Huffman code lengths with deflate limits:
   literal/length and distance codes are at most 15 bits; code-length codes are
   at most 7 bits.
3. Encode those lengths using a second Huffman tree over symbols `0..18`,
   including repeat symbols `16`, `17`, and `18`.
4. Choose whether dynamic beats fixed or stored after header cost is counted.

The hard part is therefore not writing a Huffman tree once. It is producing a
valid, compact tree representation that a strict inflate implementation accepts
for every block shape.

## Current Reference Milestone

`dynamic-huffman-reference.rkt` contains two dynamic raw-deflate reference
paths. The first one, mirrored by `lib/deflate01/src/020-deflate-dynamic-litonly.asm`, is
a literal-only block that is intentionally not frequency-optimal. It uses a
complete literal/length tree:

```text
symbols 0..225   length 8
symbols 226..285 length 9
```

This satisfies the Kraft sum exactly:

```text
226 * 2^-8 + 60 * 2^-9 = 1
```

The single distance code has length zero because the reference block emits only
literals. The code-length alphabet is a simple complete four-bit table for
symbols `0..15`, with `16..18` unused. This is larger than a real encoder's
header, but it proves:

- dynamic block header layout;
- canonical code generation;
- deflate bit reversal for Huffman codes;
- the "no distance codes because there are no matches" case.

The second Racket reference path is frequency-driven for literal-only payloads:
it counts literal frequencies plus EOB, builds length-limited canonical
literal/length codes, compresses the combined code-length sequence with
deflate repeat symbols `16`, `17`, and `18`, and emits a dynamic header that
zlib accepts. The assembly implementation now mirrors this path in preserved
steps through `042` for literal-only payloads; `020` remains the deliberately
simple dynamic-header baseline.

`lib/deflate01/src/021-deflate-dynamic-litfreq.asm` is the first assembly helper for that
path. It fills `ll_freq[286]` for literal-only dynamic blocks and adds the EOB
count. It intentionally stops before tree construction so that frequency
histogram correctness is independently testable.

`lib/deflate01/src/022-deflate-dynamic-litlen-balanced.asm` consumes `ll_freq[286]` and
emits a complete balanced `ll_len[286]` table. This is a validity scaffold, not
the final frequency-optimal Huffman tree: it assigns lengths from active symbol
count in symbol order. The point is to test native length-table scratch layout
and deflate-compatible complete code lengths before porting the sorted tree
builder.

`lib/deflate01/src/028-deflate-dynamic-canonical-codes.asm` consumes a length table and
fills the matching canonical code table in symbol order. Its scratch is two
small 16-entry `uint32_t` arrays: `bl_count[16]` and `next_code[16]`. The codes
are stored in canonical, not bit-reversed, form; the bit writer remains
responsible for reversing the low `len` bits when it emits a symbol.

`lib/deflate01/src/029-deflate-dynamic-reverse-codes.asm` consumes the length table and
canonical code table and fills a second table in deflate emission bit order.
This keeps the eventual dynamic payload writer simple: it can load `bit_code`
and `len` directly instead of running `rbit` on every symbol emission.

`lib/deflate01/src/030-deflate-dynamic-balanced-litonly.asm` wires the native helper
chain together behind a public raw-deflate wrapper. It counts literal
frequencies, builds the balanced `ll_len` scaffold, fills canonical and
bit-order tables, emits a simple non-RLE dynamic header, and writes literal
symbols plus EOB. It validates the native dynamic pipeline end to end, but it
still has three intentional limits: no LZ77 matches, no distance tree beyond
the single unused distance-code case, and no compact code-length RLE in the
assembly header path.

`lib/deflate01/src/031-deflate-dynamic-code-length-rle.asm` ports the code-length RLE
step into assembly. It consumes a length sequence and emits four-byte events
`{symbol, extra, extra_bits, reserved}` for symbols `0..18`, including repeat
symbols `16`, `17`, and `18`. This is deliberately a table builder, not a bit
emitter: the next dynamic-header step can count event-symbol frequencies,
build the bit-length tree, and then write the compact header from this table.

`lib/deflate01/src/032-deflate-dynamic-blfreq.asm` consumes those RLE events and fills
`bl_freq[19]`, the frequency table for the code-length alphabet. This mirrors
the `scan_tree` counting step from zlib in a small native helper, leaving
length-limited bit-length tree construction as the next isolated problem.

`lib/deflate01/src/033-deflate-dynamic-bllen-balanced.asm` consumes `bl_freq[19]` and
fills a valid balanced `bl_len[19]` table. This is the code-length alphabet
counterpart to the 022 scaffold: it keeps the native compact-header path
moving while the real frequency-optimal, length-limited tree builder remains a
separate later replacement.

`lib/deflate01/src/034-deflate-dynamic-blcodes-count.asm` consumes `bl_len[19]` and
computes `blcodes`, the `HCLEN + 4` count written into the dynamic header. It
scans deflate's fixed code-length alphabet order, keeps the minimum count of
four, and validates the code-length alphabet limit of seven bits.

`lib/deflate01/src/035-deflate-dynamic-compact-header.asm` consumes `bl_len[19]`,
`bl_bit_code[19]`, and the 031 RLE event table, then emits the compact
dynamic-Huffman block header bits. Its public entry uses a small params struct
instead of a wide argument list, which avoids depending on stack-passed C
arguments while the managed public ABI lowering is still intentionally small.
The native test compares the emitted bytes directly against the Racket oracle.

`lib/deflate01/src/036-deflate-dynamic-compact-balanced-litonly.asm` wires the compact
header path into a full literal-only dynamic stream. It keeps one bit writer
alive across header and payload; this is required because a deflate dynamic
header is not byte-aligned before the payload. The wrapper still uses balanced
scaffold lengths, but the code-length sequence is now compressed through
031/032/033 and emitted through a compact RLE header. During this integration
we also fixed the allocator so virtual GPRs are never colored as `x30`: LR can
be saved and restored, but a `bl` overwrites it before the callee runs.

`lib/deflate01/src/037-deflate-dynamic-code-counts.asm` computes the dynamic header's
trimmed `HLIT/HDIST` declaration counts from literal/length and distance length
tables. It returns `lcodes = max(257, last_nonzero_ll + 1)` and
`dcodes = max(1, last_nonzero_dist + 1)`, rejects literal/length tables without
EOB, and validates the Deflate 15-bit length limit. This is deliberately a
small helper because the same logic is needed by both literal-only and future
LZ77 dynamic blocks.

`lib/deflate01/src/038-deflate-dynamic-compact-trimmed-litonly.asm` integrates 037 into
the full compact-header literal-only stream. The combined length sequence now
uses the trimmed `lcodes + dcodes` prefix before 031 RLE, so short literal-only
inputs no longer pay for declaring all 286 literal/length code slots. It is
still a balanced-scaffold stream; this step improves dynamic header shape, not
frequency-optimal coding.

`lib/deflate01/src/039-deflate-dynamic-litlen-huffman.asm` adds the first native
frequency-driven literal/length tree builder. It uses a deliberately simple
O(n^2) root-selection loop over `work_freq[572]`, `parent[572]`, and
`tie[572]`, then computes leaf depths by walking parent links. The tie-breaker
matches the Racket oracle by ordering equal frequencies by the smallest
original symbol under each node. Raw depths over 15 bits are now repaired with
the bit-length-count overflow strategy used by the Racket oracle: clamp
overlong leaves at 15, rebalance counts from the deepest available shorter
level, then assign the repaired lengths to active symbols sorted by
`frequency asc, symbol desc`. While building it, we hit the same important
codegen rule as 035: do not rely on source-order fallthrough between labels
after CFG layout. The merge and repair paths now branch explicitly to shared
blocks instead of relying on fallthrough.

`lib/deflate01/src/040-deflate-dynamic-compact-huffman-litonly.asm` wires 039 into the
full compact trimmed literal-only stream. Literal/length lengths are now
frequency-driven with 15-bit repair before canonical-code generation, while
the bit-length tree still uses the balanced 033 scaffold. The native test
compares the whole byte stream against the Racket oracle and roundtrips it
through zlib raw inflate. This is the first end-to-end asmp dynamic block whose
main LL tree is no longer balanced scaffolding.

`lib/deflate01/src/041-deflate-dynamic-bllen-huffman.asm` ports the same native tree
builder shape to the 19-symbol code-length alphabet. It uses a smaller scratch
layout, inserts a dummy second symbol when only one event symbol is active,
and repairs overflow against Deflate's seven-bit limit for bit-length codes.
The native test compares the produced `bl_len[19]` table against the Racket
Huffman oracle, including an overflow-shaped frequency set.

`lib/deflate01/src/042-deflate-dynamic-compact-dual-huffman-litonly.asm` wires both 039
and 041 into the compact trimmed literal-only stream. At this point the native
literal-only dynamic block has frequency-driven LL lengths, frequency-driven
BL lengths, compact code-length RLE, and trimmed `HLIT/HDIST` declarations.
The remaining dynamic-block gap is not tree construction for literals; it is
feeding LZ77 length/distance events into the dynamic payload and making a
block policy that chooses stored, fixed, or dynamic by measured cost.

`lib/deflate01/src/043-deflate-dynamic-lz77-freq.asm` starts that LZ77 bridge without
yet writing a dynamic payload. It reuses the 019 bounded hash-chain parser
policy and fills `ll_freq[286]` plus `dist_freq[30]` from the token stream:
literals increment their byte symbol, matches increment the Deflate length
symbol and distance symbol, and EOB is added at the end. The native test
compares both frequency tables against a Racket parser oracle over empty,
short, textual, repetitive, periodic, and binary inputs. One implementation
lesson from this step: helper blocks that may be inline-expanded must not rely
on return/fallthrough layout after CFG scheduling. The match length/distance
count helpers are intentionally called rather than inlined for this preserved
MVP; once the CFG layout issue has a focused regression, they can be inlined
again if this helper becomes performance-sensitive.

`lib/deflate01/src/044-deflate-dynamic-distlen-huffman.asm` turns `dist_freq[30]` into
`dist_len[30]`. It intentionally does not duplicate the 039 tree builder:
distance codes share the literal/length 15-bit Deflate limit, so 044 copies the
30 distance frequencies into a temporary 286-symbol table, calls 039, and
copies the first 30 lengths back. The all-zero distance case returns all-zero
lengths so literal-only dynamic blocks remain representable. Native tests
cover zero distances, single-symbol distance alphabets, LZ77-derived
frequencies, and overflow-shaped Fibonacci frequencies.

`lib/deflate01/src/045-deflate-dynamic-lz77-huffman.asm` wires those pieces into the
first complete native dynamic-Huffman block with an LZ77 payload. It runs the
019-style parser twice: the first pass, via 043, fills LL and distance
frequencies; then 039/044/041 build LL, distance, and BL lengths; the second
pass reruns the parser and emits literals, length symbols, distance symbols,
and their extra bits with dynamic code tables. Its native tests compare the
whole raw-deflate byte stream against the Racket oracle and also roundtrip
through zlib raw inflate over empty, text, repeated, and periodic inputs. This
is the dynamic-block integration MVP. It is now benchmarked as an explicit
non-default codec, but it is not yet the public block selector or production
path.

`lib/deflate01/src/046-deflate-auto-dynamic-probe.asm` is the first measured selector
probe on top of 045. It keeps inputs below 96 bytes on the stable 019
fixed-vs-stored `asmp_deflate_raw_auto` path, and tail-branches larger inputs
to `asmp_deflate_raw_dynamic_lz77_huffman`. The threshold is intentionally a
benchmark-derived MVP, not a final cost model; it exists to make selector
behavior visible in the native CSV and quality baseline before changing the
stable `asmp_deflate_raw_auto` symbol.

`lib/deflate01/src/047-deflate-auto-cost-probe.asm` is the next selector probe. It still
leaves `asmp_deflate_raw_auto` untouched, but replaces the pure length
threshold with a cheap LZ77 evidence pass: run 043 into the 045 scratch layout,
sum the distance frequencies as match-token count, and select 045 only when at
least `max(1, src_len >> 10)` matches are present. Inputs that are short,
missing dynamic scratch, or low-match fall back to the stable fixed/stored auto
wrapper. This is not a full bit-cost estimator yet, but it establishes the
trampoline shape needed for a measured selector.

`lib/deflate01/src/048-deflate-auto-size-probe.asm` is the first estimated-size selector.
It preserves the same versioned public boundary as 046/047, but moves the
policy from match-count evidence to byte-size modeling: 043 counts LZ77
frequencies, 039/044/041 build LL/DIST/BL lengths, 031/032 build compact
code-length RLE metadata, then 048 counts dynamic header bits, dynamic payload
bits, fixed-Huffman payload bits, and stored-block bytes. It tail-branches to
045 only when the modeled dynamic size is strictly smaller than the modeled
stable fixed/stored auto size. This makes `high-literals` choose dynamic while
keeping deterministic `randomish` input on the stable stored fallback. During
this step we hit another CFG layout lesson: blocks that matter after register
allocation should branch explicitly to their successor instead of depending on
source fallthrough after shared exits.

`lib/deflate01/src/049-deflate-auto-prepared-size-probe.asm` keeps 045 and 048 intact and
opens a new prepared-emission implementation. It runs the 048-style dynamic
metadata preparation once, uses that metadata for the same fixed/stored/dynamic
size decision, and if dynamic wins emits from the prepared scratch tables
instead of tail-calling 045. This removes the duplicate 043 frequency pass and
the duplicate LL/DIST/BL Huffman tree builds on dynamic-winning inputs. It does
not yet solve the randomish fallback cost: low-value inputs can still pay for
the full prepare before falling back to the stable fixed/stored auto path.

`lib/deflate01/src/050-deflate-auto-cheap-prepared-size-probe.asm` adds a cheap front
gate to 049. Inputs below 512 bytes still run the full size model so literal
distribution wins like `high-literals` are not filtered out by a match-count
rule. Larger inputs first run the 043 distance-frequency pass and require at
least `max(1, src_len >> 10)` match tokens before full preparation. If the gate
passes, 050 reuses those frequency tables during prepare instead of running 043
again; if it fails, it falls back to stable fixed/stored auto without building
LL/DIST/BL Huffman trees.

`lib/deflate01/src/051-deflate-blocked-fixed.asm` is the first block-framing probe for
the eventual dynamic selector. It does not build dynamic trees; instead it
keeps the fixed-Huffman bit writer live across 32 KiB blocks, sets BFINAL only
on the last block, and flushes pending bits once at stream end. This gives the
library an end-to-end test target for multi-block raw-deflate semantics before
dynamic prepared emission is split by block.

`lib/deflate01/src/052-deflate-blocked-auto.asm` keeps the 051 framing and adds per-block
fixed/stored selection. The wrapper saves the block entry bit state,
speculatively emits fixed-Huffman output, and rewinds to emit a stored block
when stored is smaller. This validates mixed compressed/stored block streams
before adding dynamic prepared blocks to the same loop.

`lib/deflate01/src/053-deflate-blocked-dynamic-auto.asm` adds prepared dynamic emission
to the same block loop. Each 32 KiB block runs the cheap match gate, prepares
dynamic metadata once when useful, emits from those prepared tables when the
size model selects dynamic, and otherwise rewinds to the 052 fixed/stored
fallback. This is the first block-level fixed/stored/dynamic selector MVP.

`test/dynamic-huffman-reference-test.rkt` compiles tiny C/zlib harnesses and
verifies that zlib raw inflate accepts both Racket reference paths. It also
checks that the `020` asmp assembly output matches the fixed literal-only
reference byte-for-byte.

## asmp Implementation Plan

1. Keep the Racket reference encoder as the oracle for early dynamic assembly
   work.
2. Use `020-deflate-dynamic-litonly.asm` as the preserved dynamic-header
   baseline. It exercises the dynamic header and canonical-code writer without
   mixing in LZ77 parser risk.
3. Use `021-deflate-dynamic-litfreq.asm` as the native histogram baseline for
   the frequency-driven path. Keep it separate from `020` so the fixed header
   baseline remains available for debugging.
4. Use `022-deflate-dynamic-litlen-balanced.asm` as the native length-table
   scaffold. Replace its balanced assignment with frequency-sorted Huffman
   lengths only after the downstream header emitter can consume `ll_len`.
5. Add frequency tables to scratch:
   - `ll_freq[286] : uint32_t`
   - `dist_freq[30] : uint32_t`
   - `ll_len[286] : uint8_t`
   - `dist_len[30] : uint8_t`
   - `bl_freq[19] : uint32_t`
   - `bl_len[19] : uint8_t`
   - heap/parent/work arrays for length-limited tree build
6. Use `028-deflate-dynamic-canonical-codes.asm` as the native canonical-code
   baseline: count lengths, compute `next_code`, then assign codes in symbol
   order.
7. Use `029-deflate-dynamic-reverse-codes.asm` as the native bit-order table
   baseline for the dynamic payload writer.
8. Use `030-deflate-dynamic-balanced-litonly.asm` as the native integration
   baseline for helper calls, scratch layout, dynamic header writing, payload
   symbol writing, C wrapper status handling, and zlib roundtrip.
9. Use `031-deflate-dynamic-code-length-rle.asm` as the native RLE baseline for
   the combined literal/length plus distance length sequence.
10. Use `032-deflate-dynamic-blfreq.asm` as the native bit-length frequency
   baseline for the 031 events.
11. Use `033-deflate-dynamic-bllen-balanced.asm` as the native bit-length
   length-table scaffold for `bl_freq[19]`.
12. Use `034-deflate-dynamic-blcodes-count.asm` to compute compact-header
   `HCLEN` width from `bl_len[19]`.
13. Use `035-deflate-dynamic-compact-header.asm` to emit the compact dynamic
   header from `bl_len`, `bl_bit_code`, and 031 events.
14. Use `036-deflate-dynamic-compact-balanced-litonly.asm` as the native
   compact-header full-stream baseline. Keep 030 as the simple non-RLE header
   baseline for debugging.
15. Use `037-deflate-dynamic-code-counts.asm` and
   `038-deflate-dynamic-compact-trimmed-litonly.asm` to trim `HLIT/HDIST`
   before code-length RLE. Keep 036 as the fixed-count compact baseline.
16. Use `039-deflate-dynamic-litlen-huffman.asm` as the first native
   frequency-driven LL tree builder, including Deflate 15-bit overflow repair.
17. Use `040-deflate-dynamic-compact-huffman-litonly.asm` to wire the repaired
   LL builder into the compact full-stream path.
18. Use `041-deflate-dynamic-bllen-huffman.asm` and
   `042-deflate-dynamic-compact-dual-huffman-litonly.asm` to repeat the same
   Huffman-builder move for the 19-symbol bit-length tree and wire it into the
   literal-only compact stream.
19. Use `043-deflate-dynamic-lz77-freq.asm` to feed the 019-style parser into
   dynamic frequency tables, including length and distance symbols, while
   keeping the literal-only path as a preserved debugging baseline.
20. Use `044-deflate-dynamic-distlen-huffman.asm` to build distance lengths
   from `dist_freq[30]` by reusing the 039 15-bit Huffman builder.
21. Use `045-deflate-dynamic-lz77-huffman.asm` to emit length/distance symbols
   plus extra bits with dynamic code tables and byte-match the Racket oracle.
22. Use `bench-native.rkt` to measure the new dynamic path as an explicit
   non-default codec, then tune it and extend the block policy to
   choose stored/fixed/dynamic by measured bit cost.
   Dynamic should not automatically win; small blocks often lose to header
   overhead.
23. Use `046-deflate-auto-dynamic-probe.asm` as the first selector probe:
   preserve tiny fixed/stored behavior, route larger cases to 045, then replace
   the fixed threshold with a real cost model only after more corpus data.
24. Use `047-deflate-auto-cost-probe.asm` to add a cheap LZ77 match-count
   selector before running the full dynamic encoder.
25. Use `048-deflate-auto-size-probe.asm` to model fixed, stored, and dynamic
   byte size before choosing the dynamic encoder.
26. Use `049-deflate-auto-prepared-size-probe.asm` to reuse the prepared
   dynamic metadata when the size model selects dynamic, while preserving 045
   and 048 as separate comparison points.
27. Use `050-deflate-auto-cheap-prepared-size-probe.asm` to add a large-input
   cheap gate in front of 049, cutting low-match fallback cost without losing
   small high-literal dynamic wins.
28. Use `051-deflate-blocked-fixed.asm` to validate split-block raw-deflate
   framing before moving 050-style dynamic selection inside a block loop.
29. Use `052-deflate-blocked-auto.asm` to validate mixed fixed/stored blocks
   in that loop before adding dynamic prepared block emission.
30. Use `053-deflate-blocked-dynamic-auto.asm` to validate prepared dynamic
   emission inside the split-block selector before tuning it as a stable policy.

## First Correctness Targets

- Empty input still chooses fixed or stored in the public auto wrapper.
- Literal-only dynamic reference roundtrips through zlib.
- The `020` dynamic assembly wrapper matches the reference bytes and roundtrips
  high-literal data and ordinary text.
- The frequency-driven literal-only Racket reference roundtrips through zlib
  and unit-tests repeat symbols `16`, `17`, and `18`.
- The `021` assembly helper fills `ll_freq[286]` correctly for empty, text,
  high-literal, and binary inputs.
- The `022` assembly helper fills balanced `ll_len[286]` correctly from the
  native frequency table for the same input set.
- The `028` assembly helper fills canonical `ll_code[286]` correctly from the
  native length table for the same input set.
- The `029` assembly helper fills deflate bit-order `ll_bit_code[286]`
  correctly from the native length and canonical code tables.
- The `030` assembly wrapper matches the balanced literal-only Racket reference
  bytes and roundtrips empty, text, and high-literal inputs through zlib.
- The `031` assembly helper fills code-length RLE events exactly like the
  Racket oracle, including long zero runs and nonzero repeat symbol `16`.
- The `032` assembly helper fills `bl_freq[19]` from those RLE events exactly
  like the Racket oracle.
- The `033` assembly helper fills balanced `bl_len[19]` from bit-length
  frequencies, including dummy-symbol insertion for the single-active-symbol
  case.
- The `034` assembly helper computes `blcodes` from `bl_len[19]`, preserving
  the minimum four-code dynamic-header requirement and rejecting lengths over
  the deflate limit of seven.
- The `035` assembly helper emits compact dynamic-Huffman header bytes that
  match the Racket bitstream oracle and rejects bad params, invalid event
  symbols, missing bit-length codes, and undersized output buffers.
- The `036` assembly wrapper emits complete compact-header literal-only
  dynamic streams that match the Racket oracle byte-for-byte and roundtrip
  through zlib.
- The `037` assembly helper computes trimmed dynamic `HLIT/HDIST` code counts
  and rejects missing EOB or over-15-bit lengths.
- The `038` assembly wrapper emits complete compact-header literal-only
  dynamic streams with trimmed code counts, matching the Racket oracle
  byte-for-byte and roundtripping through zlib.
- The `039` assembly helper builds frequency-driven literal/length code
  lengths, repairs raw depths over 15 bits, and matches the Racket Huffman
  oracle byte-for-byte over the native test cases.
- The `040` assembly wrapper emits complete compact-header literal-only
  dynamic streams using 039 for the LL tree, matching the Racket oracle
  byte-for-byte and roundtripping through zlib raw inflate.
- The `041` assembly helper builds frequency-driven bit-length alphabet code
  lengths, repairs raw depths over seven bits, and matches the Racket Huffman
  oracle byte-for-byte over the native test cases.
- The `042` assembly wrapper emits complete compact-header literal-only
  dynamic streams using 039 for the LL tree and 041 for the BL tree, matching
  the Racket oracle byte-for-byte and roundtripping through zlib raw inflate.
- The `043` assembly helper fills literal/length and distance frequency tables
  from the 019-style LZ77 token stream, matching the Racket parser oracle for
  lazy matches, repeated data, and no-match inputs.
- The `044` assembly helper builds frequency-driven distance code lengths from
  `dist_freq[30]`, including all-zero, single-symbol, LZ77-derived, and
  overflow-shaped inputs, matching the Racket Huffman oracle.
- The `045` assembly wrapper emits complete dynamic-Huffman LZ77 blocks that
  match the Racket byte-stream oracle and roundtrip through zlib raw inflate.
- The `046` selector probe preserves the fixed/stored result for tiny benchmark
  inputs and routes larger benchmark cases to the 045 dynamic path.
- The `047` selector probe avoids dynamic output on long low-match input by
  requiring enough distance-frequency evidence from the 043 pass.
- The `048` selector probe adds a real size model: it selects 045 for current
  compressible dynamic wins and falls back to stable auto for deterministic
  randomish input.
- The `049` selector probe preserves 048's output choices while removing the
  duplicate tree-building work for dynamic-winning inputs.
- The `050` selector probe preserves 049's output choices on the current corpus
  while avoiding full Huffman preparation for deterministic randomish fallback.
- The `051` blocked-fixed probe roundtrips empty input, a 32769-byte boundary
  case, long repeated input, and long deterministic random input through the
  static library E2E harness.
- The `052` blocked-auto probe keeps the 051 boundary cases valid while
  selecting stored for high-literal and deterministic random fallback cases.
- The `053` blocked-dynamic-auto probe keeps those fallback cases valid while
  selecting dynamic for compressible split blocks such as long repeats.
- The quality gate records dynamic rows through the benchmark harness while the
  stable public `asmp_deflate_raw_auto` selector remains fixed-vs-stored only.
