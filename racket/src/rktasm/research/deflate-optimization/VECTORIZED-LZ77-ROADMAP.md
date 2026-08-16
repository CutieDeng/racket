# Vectorized LZ77 Roadmap

This roadmap describes when and how to start vectorizing the deflate LZ77
parser after the scalar implementation is mature.

## Start Criteria

Do not start vectorization just because a SIMD instruction is available. Start
only after the scalar line has stable answers for:

- match finder policy: hash width, chain depth, lazy lookahead, skipped-byte
  insertion policy;
- scalar match extension: byte loop and word-at-a-time extender measured on the
  same corpus;
- block policy: fixed/stored/dynamic cost model is at least testable;
- native correctness: zlib roundtrip, public C wrapper, status/error paths;
- quality guard: compressed-size baseline catches parser regressions;
- benchmark guard: timing is recorded enough to see a real trend.

The current scalar vectorization base is `023-deflate-fixed-chain-word-extend`.
It keeps the 019 parser policy and replaces byte-at-a-time match extension with
8-byte scalar chunks plus `rbit`/`clz` mismatch location.

The first NEON preserved implementation is
`024-deflate-fixed-chain-neon-extend`. It keeps the 023 parser policy and
compressed output, but skips equal 16-byte chunks before falling back to the
scalar mismatch locator.

## What To Vectorize First

Vectorize match extension first.

The hash-chain walk is pointer-chasing and branch-heavy, so SIMD has limited
leverage there. The extension loop, however, compares contiguous bytes from the
current position and a candidate position. Long matches in repeated text,
tables, zeros, or structured binary data spend meaningful time there.

Initial target:

```text
candidate accepted by 3-byte prefix
  -> scalar computes max_len
  -> vector loop compares 16 or more bytes per step
  -> on all-equal chunk, advance
  -> on mismatch, fall back to scalar word/byte locator inside that chunk
```

This avoids the hardest NEON problem at first: building a cheap movemask to
find the first mismatching lane. NEON can quickly answer "does this whole chunk
match?" with vector `eor` plus horizontal reduction; the scalar 023 locator can
then handle the rare mismatching chunk.

## Hand-Written Variants

The NEON implementation is hand-written assembly. It is not expected to appear
because the optimizer auto-vectorized the scalar body.

Use the function-version metadata to say that the hand-written implementation
belongs to the same logical function family:

```asm
.function asmp.deflate.fixed.neon-extend variant-of=asmp.deflate.fixed version=neon-extend feature=neon (
  in:  x.dst, x.dst_cap, x.dst_len_ptr, x.src, x.src_len,
       x.scratch, x.scratch_len,
  out: w.status
)
  ...
.end
```

In this model, "clone" or "variant" means a concrete implementation version
under one logical function identity. A version can come from:

- compiler-created call-convention cloning;
- caller/profile specialization;
- a user-written source variant such as NEON or SVE.

The optimizer or dispatcher may choose the NEON variant when the build target
or runtime CPU feature set allows it, but it does not invent the NEON body. For
experiments, a caller can explicitly call the concrete NEON symbol or select it
through the logical target:

```asm
.call asmp.deflate.fixed variant=neon-extend (...)
.call asmp.deflate.fixed feature=neon (...)
```

`example/024-deflate-fixed-chain-neon-extend.asm` now uses this logical-call
form in its public fixed/auto wrappers, so the native roundtrip test validates
both the NEON code path and the source-variant call lowering.

`example/025-deflate-default-neon-dispatch.asm` is the matching build-time
selector: it provides strong stable raw-deflate API symbols and tail-branches
to the 024 NEON wrappers when both objects are linked.

`example/026-deflate-default-word-dispatch.asm` provides the same strong stable
API symbols for the 023 word-extend implementation. This keeps build-time
selection as object selection for now: link one selector object into the final
library image.

`example/027-deflate-runtime-dispatch.asm` links both implementations and
selects at runtime by updating cached target-pointer slots from
`asmp_deflate_runtime_features`. Bit 0 clear chooses word-extend, bit 0 set
chooses NEON-extend. Stable public entries load the selected slot and `br` to
it. The hidden no-header init entrypoint calls a weak hidden detector hook,
which currently returns baseline NEON and can be replaced by a strong platform
definition, and then feeds the setter. This is not CPU probing yet; it is the
runtime dispatch ABI and control-flow shape that future probes can feed.

## NEON Plan

NEON is the first vector target because it is baseline AArch64.

Proposed preserved source:

```text
example/024-deflate-fixed-chain-neon-extend.asm
asmp_deflate_raw_fixed_neon_extend
```

Core helper shape:

```asm
.function df_extend_match_neon (
  in:  x.src, x.find_pos, x.candidate, x.max_len,
  out: w.match_len
)
```

Expected algorithm:

1. Start at length 3 because the hash-chain filter already proved the first
   three bytes.
2. While at least 16 bytes remain:
   - load current and candidate chunks with `ldr q`;
   - `eor` the two vectors;
   - reduce with a whole-vector nonzero test;
   - if zero, advance by 16;
   - otherwise drop to the scalar 8-byte/byte mismatch locator.
3. Finish remaining bytes with the scalar 023 tail path.

Important constraints:

- Never read beyond `src + len`. Do not use speculative overread until there is
  a documented padding contract.
- Use unaligned vector loads only within the validated remaining range.
- Keep the public C ABI unchanged. NEON stays inside hidden/private helpers or
  private source variants.
- Track SIMD clobbers explicitly. If a helper uses `v0..v7`, it can be
  caller-clobbered under AAPCS64; if it uses `v8..v15`, save/restore or teach
  the ABI summary.

## SVE Plan

SVE should come after NEON, not before it.

SVE is attractive because predicate operations can express "compare until first
mismatch" more naturally and vector length scales across cores. But it adds
toolchain, feature detection, and ABI complexity:

- vector length is runtime-variable;
- predicate registers need explicit clobber modeling;
- not every AArch64 deployment has SVE;
- current asmp support for SVE calls/ABI summaries is still younger than GPR
  and scalar memory support.

Proposed preserved source:

```text
example/025-deflate-fixed-chain-sve-extend.asm
asmp_deflate_raw_fixed_sve_extend
```

Expected SVE algorithm:

1. Use `whilelo` for the remaining match range.
2. Load current and candidate bytes under the predicate.
3. Compare equality into a predicate.
4. Count the equal prefix or derive first mismatch using predicate operations.
5. Advance by the active vector length while all active lanes match.

SVE should be selected through a private variant or runtime dispatch path, not by
changing the public C API.

## What Not To Vectorize First

Avoid these as first targets:

- hash-table updates for every source position;
- chain traversal itself;
- lazy-match policy;
- full multi-candidate scoring.

Those areas have serial dependencies, unpredictable memory access, or policy
uncertainty. They may still benefit later through prefetching, batched hash
computation, or layout changes, but they are not the first SIMD win.

## ABI And IPA Coordination

The public entry should stay a stable scalar C-profile wrapper:

```text
external caller
  -> public C ABI wrapper
  -> private scalar / NEON / SVE implementation variant
```

The optimizer can then choose among internal implementations:

```text
asmp.deflate.fixed.scalar
asmp.deflate.fixed.neon_extend
asmp.deflate.fixed.sve_extend
```

Version metadata must preserve the logical function identity so profiling and
debugging can still answer "which version of the deflate parser is this?"

## Validation Gates

Every vector version must pass these before it is considered useful:

1. Byte-for-byte compressed-size baseline against scalar 023 for the fixed
   test corpus, unless the parser policy intentionally changes.
2. zlib raw-inflate roundtrip.
3. Public wrapper status/error checks.
4. `git diff --check`, `raco make`, and full Racket test suite.
5. Native compare runner with scalar 019/023, NEON 024, runtime 027, and zlib rows.
6. Timing runs on repeated, period257, long-repeat, binary, and high-literal
   cases. Treat tiny-input timings as noise.

## Milestone Order

1. Keep 023 as the scalar word-at-a-time extension baseline.
2. Keep 024 as the first hand-written NEON extension baseline.
3. Compare 023 and 024 with longer timing runs and larger corpora.
4. Add runtime or build-time selection for scalar vs NEON private variant.
5. Continue scalar parser/block-policy experiments independently:
   - chain depth and lazy policy experiments;
   - optional scalar prefetching;
   - block-level stored/fixed/dynamic policy.
6. Implement SVE extension helper in a preserved 025 source.
7. Add SVE-specific validation on hardware that supports it.
8. Revisit vectorized hash precomputation and multi-candidate scoring only
   after the extension path is measured.
