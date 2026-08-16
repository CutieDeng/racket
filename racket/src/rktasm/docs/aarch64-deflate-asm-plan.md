# AArch64 deflate assembly plan

## Current assembler capability

This repository already has enough machinery to host non-trivial AArch64
kernels:

- S-expression assembly syntax with AArch64 registers, memory modes, labels,
  conditional branches, NEON/SVE register forms, and reloc-style symbols.
- ARM MRS driven instruction validation across mnemonic, operand-shape,
  operand-type, encoding, and immediate-constraint layers.
- A control-flow pipeline, liveness, graph-coloring register allocation,
  spill rewriting, ABI models, and `save!` / `load!` expansion.
- GNU and Apple assembly emission.
- Inline expansion with label and virtual-register hygiene.
- Existing stress examples for SHA1/SHA/NEON, SVE memset, virtual registers,
  ABI handling, and native AVL benchmark generation.

## Implemented deflate target

`example/009-deflate-fixed-fast.d` adds a raw fixed-Huffman deflate fast path.
`example/013-deflate-fixed-fast.asm` is the same bootstrap design written in the
GNU input syntax for discussing frontend syntax and macro/compile-time
semantics. `example/019-deflate-fixed-chain.asm` keeps the same bitstream
format and helpers, but replaces the one-entry match finder with a bounded
hash-chain parser and adds an explicit raw stored-block encoder:

- one final deflate block, `BFINAL=1`, `BTYPE=01`;
- raw stored-block output for uncompressed fallback experiments, split at
  65535-byte stored-block boundaries;
- scalar AArch64 bit writer with LSB-first packing;
- fixed-Huffman literal, length, distance, and EOB emission;
- 15-bit hash table, either one previous candidate per bucket (`013`) or
  `head[32768]` plus `prev[32768]` hash chains (`019`);
- fast parser with skipped match bytes reinserted into the hash chains and a
  one-byte lazy-match lookahead;
- caller-provided scratch tables;
- return value is the number of output bytes written.

This is intentionally a level-1 style core. It is useful as a first assembler
stress case because it exercises unaligned loads, bit-field operations,
register-offset addressing, inlined helpers, many local labels, and a real
stateful bitstream.

The current implementation should stay simple until runtime correctness is
locked down. In particular:

- do not add static Huffman tables while the S-expression frontend lacks compact
  data directives and label-indexed loads;
- keep lazy matching conservative until each policy change has a
  decoder-backed test and a stable compression-quality baseline;
- keep bit-writer helpers selected with `.inline` and use `--elim` for example
  output so helper bodies are not emitted as duplicate standalone functions;
- write helper state as `.function` virtual formals and call helpers with
  named-only `.inline helper (formal=actual, ...)` bindings, rather than
  smuggling state through fixed physical registers;
- avoid spelling identity shifts such as `lsl 0`; if the assembler requires one
  for some form, that is an assembler gap to fix, not algorithm logic to copy.

## Algorithm roadmap

1. Fixed-Huffman core
   - Keep the current no-table implementation as the bootstrap target: it
     avoids rodata lookup tables and keeps the emitted stream easy to audit.
   - Keep helper snippets as inline-selected `.function` blocks, so the final
     object contains the exported compressor rather than duplicate standalone
     helpers.
   - Add correctness tests against a deflate decoder once the full pipeline can
     run in this checkout.

2. Better match finding
   - `019-deflate-fixed-chain.asm` now has a small bounded hash chain.
   - Extend the current one-byte lazy match into a tunable level-1/level-3
     policy.
   - Optionally add NEON-assisted compare for extending candidate matches.

3. Dynamic-Huffman blocks
   - Count literal/length and distance frequencies while parsing.
   - Build canonical Huffman codes.
   - Emit code-length trees and dynamic block headers.
   - Keep the explicit stored-block and fixed-Huffman fallbacks for
     incompressible input.

4. Wrappers
   - Keep raw deflate as the kernel ABI.
   - Layer zlib/gzip wrappers, checksums, and block splitting outside or in
     separate assembly/C glue.

## Required assembler extensions

Production-grade deflate will be much easier and faster after these assembler
features land:

- Data directives: `.byte`, `.byte2`, `.byte4`, `.byte8`, `.ascii`, `.section`,
  label-addressable rodata, and alignment for static tables in the
  S-expression frontend. The GNU frontend can already preserve common scalar
  data directives, but the `.d` source used by this kernel still lacks a compact
  table notation.
- Literal pools and constant materialization helpers for 32/64-bit immediates,
  addresses, and platform-specific relocations.
- Parameterized macros or inline templates with explicit inputs, outputs, and
  clobbers. The current `.function` signature plus named-only `.inline` calls
  make state binding explicit; the next gap is using the declared modes and
  clobbers for stronger compile-time checks.
- Better alias modelling for common bit operations such as `ubfx`, immediate
  `lsl`/`lsr`, logical-immediate `and`, and instruction selection when several
  encodings share the same operand signature.
- Register-allocation constraints for pinned registers, scratch registers,
  and inline-template clobber sets.
- Table-friendly addressing conveniences, including label+index loads and
  safe PIC forms for GNU and Apple emitters.
- Object/link pipeline support or a standard compile-to-object test harness.
- Disassembly and execution tests, ideally with a small C/zlib harness and
  optional QEMU or native AArch64 execution.
- Performance instrumentation hooks for block layout, instruction count,
  dependency chains, and microarchitecture-specific scheduling notes.

## Current validation status

The restored `vendor/cutie-ftree` dependency allows the full Racket pipeline to
run again. The fixed-Huffman deflate source passes parser validation,
instruction validation, CFG construction, inline expansion, register allocation,
emission, and an external Apple arm64 assembler smoke test.

Runtime correctness now has a native Apple arm64 zlib harness. The harness
builds `example/019-deflate-fixed-chain.asm`, generates `asmp_deflate.h`, calls
the public `asmp_deflate_raw_fixed`, `asmp_deflate_raw_stored`, and
`asmp_deflate_raw_auto` wrappers, checks status/error paths, and verifies the
raw deflate stream with zlib
`inflateInit2(..., -MAX_WBITS)`.
The LZ77 word-extension variant in `example/023-deflate-fixed-chain-word-extend.asm`
has its own native roundtrip harness and is also included in the compare
runner.
The first NEON extension variant in
`example/024-deflate-fixed-chain-neon-extend.asm` preserves the 023 compressed
output, passes the same native zlib roundtrip harness shape, and is included in
the compare runner as a hand-written source variant.
It also keeps loose compression ceilings for repeated inputs, so allocator or
rewrite regressions that silently turn the stream back into mostly literals are
caught by the deflate test instead of only by manual inspection.

The optimization subproject also has a native compare runner that builds the
same public wrapper path and reports CSV against zlib fixed-Huffman level 1. It
is suitable for manual or nightly integration/performance E2E runs; the default
test suite should keep timing out of the pass/fail criteria until the corpus and
variance policy are more mature.

For versioned optimization experiments, benchmark notes, and the native
roundtrip runner, see `research/deflate-optimization/`. The same subproject now
also tracks the scalar-to-NEON/SVE LZ77 plan: vectorization starts with match
extension after the scalar parser policy is measured, while hash-chain
traversal remains scalar until there is evidence that a broader layout change
is worth the complexity.
