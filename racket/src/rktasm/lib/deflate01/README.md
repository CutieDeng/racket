# asmp deflate01

This library subproject tracks the first asmp-generated AArch64 deflate product
line. It keeps the historical implementation versions under `src/` so they
remain available for reading, regression testing, and performance comparison,
while the installable C surface is generated from `manifest.rktd`.

## Scope

The current line of work targets raw deflate streams:

- fixed-Huffman compressed blocks;
- explicit stored-block output for uncompressed fallback experiments;
- a simple public fixed-vs-stored selector;
- an experimental dynamic-Huffman LZ77 block implementation;
- experimental dynamic selector probes;
- no zlib/gzip wrapper;
- no checksum;
- no parser-driven compressed block splitting or public dynamic selector.

That is deliberate. The goal is to make the match parser, bit writer, register
allocation pressure, and assembler frontend behavior easy to inspect before
adding table-heavy or multi-block compression.

For the planned public C library interface and its interaction with IPA
calling-convention/regalloc work, see `API-DESIGN.md` and
`IPA-REGALLOC-ROADMAP.md`. For the dynamic-Huffman implementation route, see
`DYNAMIC-HUFFMAN.md`. For the scalar-to-SIMD LZ77 plan, see
`VECTORIZED-LZ77-ROADMAP.md`.

## Current Capability

The current implementation is usable as a native AArch64 raw-deflate MVP, not
as a complete deflate/zlib/gzip library.

| Area | Current status |
|------|----------------|
| Stream format | Raw deflate only. Stable fixed-Huffman output is one final compressed block; stored output uses standard stored blocks split at 65535 bytes when needed. `051` adds an experimental fixed-Huffman split-block stream with shared bit-buffer state across 32 KiB blocks; `052` adds per-block fixed/stored selection; `053` adds per-block fixed/stored/dynamic selection. |
| Public API | `asmp_deflate_raw_fixed`, `asmp_deflate_raw_stored`, `asmp_deflate_raw_auto`, `asmp_deflate_raw_bound`, scratch size/alignment helpers. |
| LZ77 parser | 32 KiB window, 15-bit hash, `head[32768] + prev[32768]`, bounded 32-node chain search, skipped-byte reinsertion, one-byte lazy lookahead. |
| Match coding | Deflate length range 3..258 and distance range 1..32768. |
| Compression level | One fixed low-level strategy, roughly a level-1 style parser, plus explicit stored and auto fixed-vs-stored paths. There is no selectable level API yet. |
| Huffman | Fixed Huffman encoder plus native dynamic-Huffman integration baselines. The dynamic path now has LZ77 token frequency counting, LL/DIST/BL tree construction, canonical/bit-order tables, compact code-length RLE headers, trimmed `HLIT/HDIST` counts, and LZ77 dynamic payload wrappers. It is selected by the experimental `053` block policy but not by the stable public auto wrapper. |
| Block policy | `asmp_deflate_raw_auto` emits fixed output first, compares it with exact stored length, and rewrites as stored if stored is no larger. `asmp_deflate_raw_auto_dynamic_probe` is a threshold selector, `asmp_deflate_raw_auto_dynamic_cost_probe` is a match-token selector, `asmp_deflate_raw_auto_dynamic_size_probe` estimates fixed/stored/dynamic byte size, `asmp_deflate_raw_auto_dynamic_prepared_size_probe` reuses prepared dynamic metadata when dynamic wins, and `asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe` cheap-gates large low-match input before full preparation. `asmp_deflate_raw_blocked_fixed` is a split-block fixed-Huffman framing MVP, `asmp_deflate_raw_blocked_auto` adds per-block fixed/stored fallback, and `asmp_deflate_raw_blocked_dynamic_auto` adds per-block prepared dynamic emission. There is no stable block-level fixed/stored/dynamic selector yet. |
| Wrapper formats | No zlib wrapper, gzip wrapper, Adler-32, or CRC-32. |
| Validation | Native macOS arm64 roundtrip through zlib raw inflate, status/error checks, compressed-size quality baseline, and benchmark CSV comparison against zlib fixed-Huffman level 1. The benchmark also includes the 045 dynamic-Huffman LZ77 experiment, the 046/047/048/049/050 auto-dynamic probes, and the 051/052/053 split-block streams as explicit non-default codecs. |

In short: LZ77 is real but intentionally simple; deflate emission is complete
for the fixed-Huffman single-block subset, raw stored blocks, whole-stream
fixed-vs-stored selection, and a preserved dynamic-Huffman LZ77 MVP. Dynamic
Huffman is not yet a production/default encoder because it still needs
selector tuning, a tighter cost model, and performance work.
A small Racket reference encoder and `020-deflate-dynamic-litonly.asm` now emit
a literal-only dynamic block and verify the dynamic header/canonical-code
mechanics through zlib. The Racket reference also has a frequency-driven
literal-only path with code-length RLE; the assembly path is being moved toward
that in smaller preserved steps. `021-deflate-dynamic-litfreq.asm` started the
port by validating the native literal/length frequency histogram.
`022-deflate-dynamic-litlen-balanced.asm` now adds a native balanced
literal/length length-table scaffold, still short of frequency-optimal Huffman
tree construction. `028-deflate-dynamic-canonical-codes.asm` and
`029-deflate-dynamic-reverse-codes.asm` fill canonical and deflate bit-order
code tables, and `030-deflate-dynamic-balanced-litonly.asm` now wires those
helpers into a public literal-only dynamic wrapper with native zlib
roundtrip/reference-byte validation. `031-deflate-dynamic-code-length-rle.asm`
adds the native RLE event table for the next compact dynamic-header step, and
`032-deflate-dynamic-blfreq.asm` counts the bit-length alphabet frequencies
from those events. `033-deflate-dynamic-bllen-balanced.asm` fills a balanced
`bl_len[19]` table from those frequencies, keeping the compact-header path
valid, and `034-deflate-dynamic-blcodes-count.asm` computes the dynamic
header's `HCLEN + 4` count. `035-deflate-dynamic-compact-header.asm` now emits
the compact dynamic-header bits byte-for-byte against the Racket oracle. This
is now integrated into `036-deflate-dynamic-compact-balanced-litonly.asm`, which
emits complete literal-only dynamic streams with compact RLE headers.
`037-deflate-dynamic-code-counts.asm` computes trimmed `HLIT/HDIST` counts from
LL/DIST length tables, and `038-deflate-dynamic-compact-trimmed-litonly.asm`
uses those counts so compact literal-only streams no longer declare the full
286+1 code sequence unnecessarily. `039-deflate-dynamic-litlen-huffman.asm`
adds a native frequency-driven literal/length tree builder with Deflate 15-bit
overflow repair, matching the Racket Huffman oracle in native tests.
`040-deflate-dynamic-compact-huffman-litonly.asm` wires that LL builder into
the compact trimmed literal-only stream. `041-deflate-dynamic-bllen-huffman.asm`
adds the corresponding frequency-driven bit-length tree builder, and
`042-deflate-dynamic-compact-dual-huffman-litonly.asm` validates the whole
literal-only byte stream with both LL and BL Huffman trees against the Racket
oracle plus zlib raw inflate. `043-deflate-dynamic-lz77-freq.asm` now reuses
the 019 parser policy to fill LL and distance frequency tables from LZ77
tokens. `044-deflate-dynamic-distlen-huffman.asm` turns distance frequencies
into Deflate-compatible distance lengths by reusing the 039 15-bit Huffman
builder. `045-deflate-dynamic-lz77-huffman.asm` wires those pieces into a
complete dynamic-Huffman block with LZ77 payload, byte-matching the Racket
oracle and roundtripping through zlib raw inflate. The dynamic path is now in
the native benchmark as an explicit experimental codec, but it is still short
of a stable measured block-level selector. `046-deflate-auto-dynamic-probe.asm`
is the first versioned selector probe: it keeps inputs below 96 bytes on the
stable fixed/stored auto path and routes larger inputs to 045.
`047-deflate-auto-cost-probe.asm` keeps that API shape but first runs the 043
frequency pass and only selects 045 when the distance frequencies show enough
LZ77 match tokens.
`048-deflate-auto-size-probe.asm` keeps the same versioned-selector boundary
but estimates fixed, stored, and dynamic byte size from the generated LL/DIST/BL
length tables before choosing. It selects dynamic for cases such as
`high-literals` where 045 is smaller than stored, and falls back to the stable
auto path for deterministic `randomish` input.
`049-deflate-auto-prepared-size-probe.asm` preserves 045 and 048, but tests the
next implementation shape: prepare dynamic metadata once, use it for the size
decision, and when dynamic wins reuse the prepared tables for emission instead
of tail-calling 045 and rebuilding the same Huffman trees.
`050-deflate-auto-cheap-prepared-size-probe.asm` adds a cheap front gate to
049. Inputs below 512 bytes still enter the full size model so high-literal
dynamic wins are preserved, but larger inputs first run the 043 match-token
gate and low-match cases such as deterministic `randomish` fall back to stable
auto without building LL/DIST/BL Huffman trees.
`051-deflate-blocked-fixed.asm` is the first split-block framing experiment. It
keeps 019's fixed-Huffman LZ77 parser per 32 KiB chunk, but hoists the bit
writer state to the public wrapper so adjacent compressed blocks share one raw
deflate bitstream. The library E2E test covers empty input, a 32769-byte block
boundary, a 70000-byte long repeat, and a 70000-byte deterministic random case.
`052-deflate-blocked-auto.asm` builds on that framing and adds per-block
fixed/stored selection. It speculatively emits each fixed block, compares the
byte cost with a stored block from the saved entry bit state, and rewinds to
stored for high-literal or random data.

`053-deflate-blocked-dynamic-auto.asm` adds the prepared dynamic path to that
same 32 KiB loop. Each block runs the cheap match gate, prepares dynamic
metadata once when useful, emits dynamic from the prepared tables when the size
model wins, and otherwise rewinds to the 052 fixed/stored fallback.

## Library Readiness

The remaining work depends on which library shape is meant:

| Target | Readiness | Remaining gap |
|--------|-----------|---------------|
| Raw-deflate research library | close | Public fixed/stored/auto wrappers, native tests, benchmark, and quality gate exist. 045 dynamic, 046/047/048/049/050 selector probes, and 051/052/053 split-block framing probes are callable but still experimental. |
| Practical one-shot raw-deflate compressor | medium | Needs stored/fixed/dynamic selector tuning, tighter output bounds, larger corpus tests, fuzz-style roundtrips, and a stable installed header/build story. |
| zlib/gzip-compatible library | early | Needs zlib/gzip wrappers, Adler-32/CRC-32, wrapper-level API, checksum tests, and probably streaming or chunked operation. |
| High-performance compressor | early to medium | Needs parser/chain policy tuning, dynamic tree cost reduction, NEON/SVE match-extension variants for the chosen parser, and IPA/regalloc improvements for helper-heavy code. |

The current biggest functional gap is not "can it emit deflate"; it can. The
gap is tuning and hardening the 053 block-level selector strongly enough to
become a stable library boundary.

## Version Rule

Do not overwrite an existing deflate implementation when trying a new idea.
Add a new source file under `lib/deflate01/src/` with a new number and symbol:

```text
lib/deflate01/src/020-deflate-<idea>.asm
deflate_<idea>_aarch64_asm
```

Then update:

- `lib/deflate01/docs/VERSIONS.md`
- `lib/deflate01/bench/bench-native.rkt`
- `test/deflate-native-test.rkt` if the version should become a correctness
  regression target
- `lib/deflate01/README.md` if the version is useful for users to read

## Current Finding

`019-deflate-fixed-chain.asm` is now the first native integration baseline. It
roundtrips on macOS arm64 through the public `asmp_deflate_raw_fixed`,
`asmp_deflate_raw_stored`, and `asmp_deflate_raw_auto` wrappers, generated
`asmp_deflate.h`, clang, and zlib raw-deflate decoding.

`023-deflate-fixed-chain-word-extend.asm` keeps the same parser policy and
compressed sizes as 019, but accelerates LZ77 match extension with 8-byte
chunk compares and `rbit`/`clz` mismatch location. It is included in the native
compare runner as `asmp-023-wordextend-public`.

`024-deflate-fixed-chain-neon-extend.asm` keeps the 023 compressed output, but
uses hand-written NEON to skip equal 16-byte chunks before falling back to the
scalar 8-byte mismatch locator. It is included in the native compare runner as
`asmp-024-neonextend-public`.

The parser is still intentionally simple, but no longer literal-heavy on
repetitive input:

- bounded hash chains;
- skipped match bytes are reinserted into the chains;
- one-byte lazy-match lookahead;
- fixed Huffman only for the parsed compressed path; the auto wrapper can
  choose whole-stream stored output, but not per-block stored/dynamic output;
- byte-by-byte match extension in 019, with 023 providing a word-at-a-time
  extension baseline and 024 providing a first NEON extension variant.

Complex integration and performance E2E work can start now as a manual or
nightly activity. Keep machine-dependent timing out of the default correctness
gate until the benchmark corpus, baseline recording, and allowed variance are
more stable.

Run the current native baseline with:

```bash
racket lib/deflate01/bench/bench-native.rkt --iterations 20
```

The runner emits CSV for the public asmp fixed, word-extend, NEON-extend,
stored, auto, the 045 dynamic-Huffman LZ77 experiment, the 046/047/048/049/050 auto-dynamic
probes, the 051/052/053 split-block streams, and 027 runtime-dispatch fixed wrappers plus zlib fixed-Huffman level 1.
Runtime-dispatch rows are produced by a second executable that links 023+024+027
without the 019 strong stable symbols. The runner intentionally includes only
versions that are safe to call from a C harness and pass raw-deflate roundtrip;
older preserved versions remain in `VERSIONS.md` even when they are not
executed by the runner. The corpus includes small text, repeated data,
periodic-window data, long repeats, high-literal stored-fallback data, and a
deterministic `randomish` case that guards selector behavior on long low-match
input.

For a lightweight integration quality gate, run:

```bash
racket lib/deflate01/bench/check-native-quality.rkt --iterations 3
```

That command invokes the native benchmark, requires every reported codec/case to
roundtrip successfully, and checks the public asmp wrapper against
`quality-baseline.csv`. The baseline guards compressed size only; throughput is
reported by `bench-native.rkt` but remains advisory until variance tracking is
available.

## Native Library Build

The first static-library build path is available on macOS arm64:

```bash
racket lib/deflate01/build.rkt --out-dir /tmp/asmp-deflate-lib
```

For a repo-local install layout, use:

```bash
racket lib/deflate01/build.rkt --install
```

The default install prefix is `lib/deflate01/build/install`, so it does not
write into `/usr`, `/usr/local`, or any other system directory. A custom staging
prefix can be provided explicitly:

```bash
racket lib/deflate01/build.rkt --prefix /tmp/asmp-deflate --install
```

The build consumes `manifest.rktd`, which is the current single
manifest for the library name, assembly source list, and stable-vs-experimental
export grouping. The installed header is generated from that manifest plus the
public ABI metadata in each listed `.asm` source, so the C surface is checked
against the actual exported functions instead of being copied from a separate
handwritten template.

It emits:

```text
/tmp/asmp-deflate-lib/libasmp_deflate.a
/tmp/asmp-deflate-lib/include/asmp_deflate.h
```

With `--install`, it emits:

```text
lib/deflate01/build/install/include/asmp_deflate.h
lib/deflate01/build/install/lib/libasmp_deflate.a
lib/deflate01/build/install/lib/pkgconfig/asmp-deflate.pc
```

External C clients can link the raw-deflate API with:

```bash
clang client.c /tmp/asmp-deflate-lib/libasmp_deflate.a -I /tmp/asmp-deflate-lib/include -lz -o client
```

A small standalone C client is available at
`lib/deflate01/c-examples/raw-roundtrip.c`. It calls the
stable raw auto API and the experimental blocked dynamic auto API through the
installed header, then verifies both raw deflate streams with zlib:

```bash
clang lib/deflate01/c-examples/raw-roundtrip.c \
  /tmp/asmp-deflate-lib/libasmp_deflate.a \
  -I /tmp/asmp-deflate-lib/include -lz -o /tmp/asmp-raw-roundtrip
/tmp/asmp-raw-roundtrip
```

The installed header exposes the stable raw fixed/stored/auto API plus the
experimental 045 dynamic-Huffman LZ77 and 046/047/048/049/050 auto-dynamic probe
entries, along with the 051/052/053 split-block experiments.
The stable `asmp_deflate_raw_auto` name remains fixed-vs-stored until the
selector policy is mature enough to promote.

To refresh the checked-in header snapshot without building the library:

```bash
racket lib/deflate01/render-header.rkt
```

To check that the snapshot is current:

```bash
racket lib/deflate01/render-header.rkt --check
```

To keep local performance history, run:

```bash
racket lib/deflate01/bench/record-native-bench.rkt --iterations 20 --runs 5 --label 019-baseline
```

The recorder writes an ignored CSV under `lib/deflate01/bench/runs/`.
Each row includes run number, timestamp, host OS/arch, git head, dirty state,
iteration count, and the original benchmark columns. Use this before and after
parser or IPA/regalloc changes when the question is performance trend rather
than pass/fail correctness.

## Experiment Backlog

1. Parser policy
   - Extend the one-byte lazy lookahead into a small level-1/level-3 policy.
   - Measure whether reinserting every skipped position is worth the extra
     store/load traffic.
   - Preserve `019` and add a new numbered file for the next policy.

2. Match extension
   - Keep 023 as the scalar word-at-a-time extension baseline.
   - Measure chain-depth, lazy-policy, and block-policy changes against that
     baseline before introducing a SIMD version.
   - Keep 024 as the first NEON extension baseline; hash-chain traversal stays
     scalar until measurements justify a deeper redesign.

3. Register pressure
   - Compare `.inline` helpers against `.call` helpers with ABI hints.
   - Split the parser into smaller managed helper functions only if it reduces
     spill cost without hiding the algorithm.
   - Avoid physical register pinning until there is a clear measured reason.

4. Block policy
   - Replace the whole-stream auto selector with block-level fixed-vs-stored
     selection.
   - Use the `020` dynamic-Huffman literal-only baseline and the
     `021`/`022`/`028`/`029`/`030`/`031`/`032`/`033`/`034`/`035`/`036` native histogram, length,
     canonical-code, bit-order, literal-only integration, code-length RLE,
     bit-length frequency, bit-length length, `HCLEN` count, and compact-header
     full-stream baselines while adding the real frequency-based tree builder.

5. Vectorization
   - Compare 024 against 023 over larger corpora and longer timing runs.
   - Preserve the first SVE match-extension experiment as
     `025-deflate-fixed-chain-sve-extend.asm`.
   - Keep public C-profile entrypoints stable; select scalar, NEON, or SVE
     private variants behind the wrapper.

## Validation Levels

Use these levels when discussing a version:

- Parse: GNU frontend accepts the source.
- Pipeline: CFG, inline lowering, register allocation, and emission succeed.
- Assemble: host toolchain can assemble/link generated output.
- Roundtrip: generated raw deflate inflates back to the input bytes.
- Compare: native benchmark reports size and timing for public asmp entrypoints
  and external references such as zlib fixed-Huffman level 1.

At the moment, native roundtrip and compare are available on macOS arm64 through
clang and zlib.
