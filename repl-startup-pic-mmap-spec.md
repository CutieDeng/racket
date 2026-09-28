# PIC code + mmap-in-place boot (AArch64) — implementation spec

## Goal
Make Chez AArch64 boot code **position-independent** so the code vspace can stay
in the mmap'd boot image (no copy, no relocation writes → no COW). Eliminates,
for the code space, `room+copy`'s copy (~5ms) and `relink-code` (~2.6ms), i.e.
~7.6ms of the ~30ms boot, WITHOUT slowing execution (measured: `ldr`-from-table
ties/beats `movz/movk×4` for working sets ≤64KB; see pic-bench/pic-stress2).

## Why this is now worth specifying
- Measured (Apple Silicon): PIC indirect load is **not slower** than the current
  4-instruction absolute materialization; it is faster for local hot code and
  ~1.8×/ref only for very broad working sets (>64KB of distinct refs, diluted).
- So the old objection ("PIC trades runtime speed for boot") is refuted here.

## Current mechanism (what we change)
- `arm64.ss:1656-1658` (`asm-move`, `[(literal) ...]`): a heap/far reference is
  emitted as `ax-mov64` = **movz + movk×3** (build a 64-bit absolute into a reg),
  tagged with an `arm64-abs` relocation.
- Load time: `relink_code` (vfasl.c) reads each reloc entry, resolves the object,
  and **patches the 4 instructions in the code** via `arm64_set_abs`
  (fasl.c:1791). That write dirties code pages → COW under any mmap-in-place.
- Calls/jumps to far/heap targets use the same abs mechanism (`reloc_arm64_call`
  → `arm64_set_abs`). Intra-segment calls already use PC-relative `bl` (no patch).

## Core design: adrp+ldr GOT (chosen)
Emit heap/far references as a **GOT load**:
```
    adrp  Xtmp, GOT@page          ; PC-relative page of the GOT (±4GB)
    ldr   Xn,  [Xtmp, #slot@lo12] ; load the resolved object from the GOT slot
```
- Position-independent: the `adrp` offset is **code→GOT distance**, which is
  build-time-fixed as long as the loader keeps code and GOT at a fixed relative
  layout. No instruction is patched → code pages stay clean → mmap-in-place.
- Only the **GOT slot** (data) is patched at load.
- Calls become `adrp;ldr;blr` (3 insns) vs `movz/movk×4;blr` (5) — cheaper.
- `adrp` results CSE across loads from the same GOT page → amortized ≈ single load.

### Why adrp+ldr, not the alternatives
- **PC-relative `ldr (literal)`** (±1MB): would need the pool adjacent to code
  and page-separated; per-object pools COW at PAGE granularity → thousands of
  COW pages for racket.boot's thousands of code objects. Rejected.
- **Reserved GOT-base register (TOC model)**: costs a permanent register and
  requires setting it on every code-object entry (call overhead + save/restore).
  Rejected in favor of `adrp` (no reserved reg, temp only).

## Rationale: surviving Racket's runtime dynamism (design foundation)
Racket loads a different set of modules each run and compiles code at runtime.
The design survives this because dynamism is split across three places, none of
which needs a consistent *global* runtime state:

- **Object addresses (ASLR / re-interned symbols+rtds / GC-moved)** live in **GOT
  slot contents** (data): filled at load, and updated by the GC like any pointer.
  Code never holds a moving address. (This is strictly more GC-friendly than
  today's code-patching, which only works because boot objects are immovable.)
- **code↔GOT relative layout** is fixed by the **boot file itself**: under
  mmap-in-place the file's byte layout *is* the memory layout, so the build
  chooses `[code][GOT]` offsets and bakes the (relative, ASLR-invariant) adrp
  immediates. Not a runtime decision.
- **GOT slot indices are a per-code-object, compile-time-local property**, frozen
  in each unit's image/.zo — NOT a global runtime allocation. The GOT is
  **per-unit** (one per code object / compilation unit), exactly like an ELF
  per-.so GOT. Loading a different set of modules loads a different set of
  self-contained units, each carrying its own fixed-index GOT; nothing is
  renumbered. Two units referencing the same object each get their own slot (some
  duplication, zero cross-unit index dependency — this is what makes it survive
  dynamic loading).

So: **content→GOT, layout→file, index→per-unit-compile-time.** No part depends on
"the same modules load each run." This is the standard dynamic-linker model.

## Layout
- Add a **GOT vspace** holding one 8-byte slot per distinct heap/far reference.
- Loader places `[code vspace][GOT vspace]` at a **build-time-fixed relative
  offset** (contiguous, page-aligned boundary between them) so `adrp` offsets are
  constant. GOT within ±4GB of code (always true in one image).
- mmap-in-place: the code+GOT region stays in the mapping; **code pages shared
  read-only, GOT pages COW** on patch (GOT is small: ~#relocs × 8B ≈ tens of KB
  → a few pages).

## Changes by file
1. **arm64.ss**
   - `asm-move` `[(literal) ...]`: emit `adrp Xtmp,GOT@page; ldr Xn,[Xtmp,#lo12]`,
     allocate/reuse a GOT slot for the literal, and record a `arm64-got` reloc
     (slot index + code offset of the pair for `adrp` fixup if needed — see open
     Q1).
   - call/jump literal clauses: `adrp;ldr;blr`.
   - Add `adrp` CSE (reuse Xtmp for same GOT page within a block).
2. **cmacros.ss**: new reloc type `reloc-arm64-got` (records GOT slot index, not a
   code patch site).
3. **fasl.c** / **vfasl.c**: `relink_code` for `reloc-arm64-got` writes the
   resolved object into `GOT[slot]` (data), leaving code untouched. `arm64_set_abs`
   unchanged (legacy path kept for non-PIC objects during transition).
4. **loader (vfasl.c S_vfasl)**: place code+GOT contiguously; extend the existing
   reloc-space zero-copy (283-294) so the **code vspace stays in the mapping** when
   `to_static` and the object is fully PIC (no in-code patches remain).
5. **GC / code-object model**: the code object header still holds object refs
   (reloc ptr, name) — see open Q2 (headers must also be PIC or separated, else
   header pages COW).

## IMPLEMENTATION STATUS (2026-09-27, feat/repl-startup-analysis, uncommitted)
- **P0 DONE + verified**: per-code-object literal pool (trailing `(abs)` quads,
  reached by `adr`) replaces `movz/movk×4`+`arm64-abs` for `asm-move [(literal)]`.
  Zero C changes (reuses reloc-abs). Files: `arm64.ss` (asm-move literal clause,
  `asm-resolve-pool-adrs`, `arm64-adr` placeholder in `asm-size`) + `cpnanopass.ss`
  (`literal-pool-slot!`/`flush-literal-pool`/`resolve-literal-pool-adrs`, LambdaBody
  `(attempt #t)`→`(attempt #f)` fallback). Build rc=0, self-hosts, raco setup all
  collections, codegen battery 0 failures, runtime parity (min-of-15 noise-dominated).
  Two bugs found+fixed: (1) NO dedup — eq?-keyed dedup breaks host-independence
  (boot fixpoint) and mis-merged distinct closures (`entry 374 uninitialized`);
  (2) `adr` ±1MB overflows on WPO-combined racket.so (~2.3MB) → out-of-range
  literals recompile that code object frozen (all `arm64-abs`).
- **P1 DONE + verified**: `asm-helper-jump`/`asm-helper-call` also pool their
  targets (`adr;ldr;br`/`blr` + `(abs)` quad) instead of `movz/movk×4`+
  `arm64-jump`/`arm64-call`. Build rc=0, self-hosts, battery 0 failures, 13 pool
  jump/call loads confirmed live.
- **sharing1@entry518 fixpoint warning is PRE-EXISTING** (baseline reproduces it;
  differing object is an rtd field-vector = data, not code). Non-fatal by design.
- **KEY P2 BLOCKER confirmed**: the P0/P1 pool lives *inside* each code object and
  its quads are patched at load → dirties code pages → COW regardless. So P0/P1 do
  NOT yet enable mmap-in-place. P2 must move the pool to a **separate GOT vspace**
  (adrp-addressed) so code pages carry zero patches. The loader already keeps the
  *reloc* space in the mapping when source is a permanent mmap + to_static
  (`vfasl.c:296-307`); P2 extends that to the code space AND adds a GOT vspace.
  adrp's page-relative immediate is load-address-dependent → must be baked under
  the mmap fixed `[code][GOT]` layout, or relocated (dynamic code path).

## P2 CONCRETE DESIGN (decision-locked 2026-09-28)
Derived hard conclusion: an adr/adrp immediate to an **out-of-object** GOT
depends on the object's position in the code vspace, which is assigned only at
**layout time** — so the immediate MUST be baked at layout time. Compile-time
baking works ONLY for the in-object pool (P0/P1), which is exactly what dirties
code pages. There is no compile-time shortcut. This is the core new machinery.

Chosen addressing: **`adr` to consolidated GOT islands** (not `adrp`).
`adr` is PC-relative by BYTE → load-address-independent → the baked immediate
needs NO page-alignment guarantee from the loader (adrp would). Place GOT
island(s) in the code vspace every <1MB so `adr` (±1MB) always reaches the
nearest island. Islands are consolidated (few pages) not per-object (thousands
of COW pages — rejected). Code (non-island) pages stay clean → shareable;
island pages COW (written by relink). On MAP_JIT platforms (Apple Silicon) code
is copied into MAP_JIT regardless, so the win is Linux-only; codegen correctness
is still verified on both.

Codegen contract: arm64.ss emits `adr Xtmp,<slot-placeholder>; ldr Xn,[Xtmp]`
plus a reloc that records (this object, GOT-slot-index). The layout stage (a)
assigns each object's slots into a consolidated island, (b) bakes the `adr`
byte displacement into the code, (c) emits the slot as an `(abs)` reloc into the
island. Two layout stages: `to-vfasl.ss` (racket.boot — the win target) and the
plain-fasl load path (compile.ss/fasl.c for petite/scheme.boot + .zo). Plain
fasl MAY keep the P0/P1 in-object pool initially (it is not the mmap target);
only vfasl needs the consolidated-island + code-clean treatment.

Loader (vfasl.c): keep the code vspace in the permanent mmap (extend the reloc
zero-copy at 296-307 to vspace_code) on non-MAP_JIT platforms; relink writes
only the island (abs) slots → COW only island pages. GC must scan the island
slots (they hold live object pointers) — either a sub-region of code vspace
walked by the reloc table, or a distinct GOT vspace (cmacros.ss enum at 2277,
pointer-bitmap ordering: GOT holds pointers so it cannot sit after reloc).

Safe staged plan (each stage builds+boots+self-hosts+differential before next):
- **P2.1 DONE** infra: added a `vspace-got` (cmacros.ss enum, adjacent to code)
  + `reloc-arm64-got` type (index 4, fits the 3-bit field), C vspace tables
  updated (hardcoded 9→vspaces_count). Inert (size-0 vspace); builds+boots+
  self-hosts, code-write% unchanged 87%.
- **P2.2a DONE** marker: codegen tags pool quads `arm64-got`; all four fasl
  consumers handle it (c-mkcode, prf0 fasl-write, fasl-write build-target, vfasl
  relink) and `fasl.c` S_set/S_get_code_obj treat reloc-arm64-got as a plain
  pointer store/load (== reloc-abs, in-object quad). Verified inert: build rc=0,
  boot 42, battery 0 failures, code-write% still 87%. NOTE: the prf0 fasl-write
  path is a THIRD code-list consumer beyond c-mkcode — missing it was the first
  failure.
- **P2.2b DONE** transform (vfasl.ss writer + vfasl.c loader):
  * Writer: per code object, count its `reloc-arm64-got` entries and reserve a
    contiguous block of 8-byte slots in `vspace-got` (both passes allocate
    identically); stash each slot's GOT byte offset in the **dead high half of
    the in-object quad** (low half stays the usual vfasl marker) so no reloc
    format change is needed; in the second pass decode the object to find each
    pool `adr Xt,quad; ldr Xt,[Xt,#0]` pair and rewrite it to
    `adrp Xt,page; ldr Xt,[Xt,#lo12]`.
  * Layout contract baked into the immediates: loader places the code vspace
    4096-aligned and the GOT at code start + roundup(code-vspace-size, 4096)
    (one co-allocated space_code block), so page delta and lo12 are
    load-address-invariant. Loader abort if a GOT-bearing image is loaded
    without boot-mode-static (its relocs can't be replayed later).
  * relink redirects `reloc_arm64_got` entries to write `GOT[off]` (offset read
    from the quad's high half) and leaves the code page untouched.
  * **Template code objects opt out** on both sides (pool stays in-object):
    S_instantiate_code_object replays their retained reloc tables against the
    in-object quads.
  * **ORPHAN pool slots exist by design** (found the hard way: first build
    died on "pool quad has no adr" at petite.boot): a regenerating chunk
    (asm-return-address rachunk pre-munge falls back to a pooled asm-move,
    then munges to a short `adr` to the code label) registers a slot whose
    load sequence is discarded. Unmatched quad ⇔ orphan (all instructions sit
    below the pool, so the scan cannot miss a live adr); relink still writes
    the dead GOT slot, nothing loads it.
  * Verified tarm64osx: full build rc=0 (only the two pre-existing
    sharing1@entry518 fixpoint warnings), boot + raco setup, codegen battery
    ok, PLT_VFASL_WRITES **code 87% → 79.0%** (4898/6203 pages), got 929
    pages 100% written (relink fills every slot), PLT_VFASL_TIMES unchanged
    (~7.5ms room+copy / 2.6ms relink — the time win is P2.3's, this stage
    only cleans the pages). Verified tarm64le (docker, native aarch64):
    full build rc=0 incl. self-host fixpoint, Chez battery 0 failures,
    Racket battery ok, **code 87% → 78.8%** (4889/6201), got 928 pages
    100%. Cost: GOT adds ~3.8MB resident (929 pages; no dedup + orphans —
    a host-stable dedup is a later optimization); image bytes are zeros
    (compress away). Remaining ~21% code writes = code-object header
    writes (P3), frozen out-of-range objects, rp-header abs quads.
- **P2.3** loader: code-vspace zero-copy on tarm64le; measure vfasl phase delta
  (target room+copy + relink ↓ ≈7ms) with PLT_VFASL_TIMES A/B.
- **P3** headers: code-object header refs (reloc ptr, name) still dirty first
  pages — PIC or separate them, else the win is capped.
Correctness is high-stakes (wrong slot/immediate = silent bad code): differential
+ full-suite gate every stage; codegen battery + self-host fixpoint each build.

## Phasing (each phase builds + boots + passes tests before the next)
- **P0 (prove codegen) — refined + de-risked (localized to arm64.ss)**:
  Investigation results that shrink P0:
  * **No new `adrp` op needed**: the GOT lives IN each code object (a literal pool
    appended after the code), reached by the existing **`adr`** (±1MB) — code
    objects are <1MB, so in range. (adrp is only for P2's separate GOT region.)
  * **No new reloc type**: a GOT slot is a **quad with the existing `reloc-abs`**
    (compile.ss:135-137 `(abs)` → reloc-abs → fasl.c:1502 plain-uptr store). The
    current in-code mechanism is `(arm64-abs)` → reloc-arm64-abs (movz/movk×4); we
    just switch to `adr;ldr` code + an `(abs)` quad.
  * **No C-side change**: reloc-abs relink already writes the resolved pointer
    into the quad (verify vfasl relink handles reloc-abs in a code object — P0
    test point).
  So P0 = **one file (arm64.ss)**: (a) add a per-code-object GOT/literal-pool
  accumulator (dedup object→slot), (b) in `asm-move [(literal)]` (1656-1658) emit
  `adr Xtmp,GOT_slot; ldr Xn,[Xtmp]` instead of `ax-mov64`+arm64-abs, registering
  the slot, (c) flush the pool as `(abs)` quads at code-end and resolve the `adr`
  labels. Chez AArch64 has NO existing literal-pool (uses movz/movk×4), so the
  pool accumulator/flush is the one piece of new assembler machinery. GOT still
  patched at load, code still copied (NOT yet mmap) — P0 only proves codegen
  correctness + runtime parity.

  P0 files (two): **arm64.ss** (`asm-move [(literal)]` emits `adr;ldr` + registers
  a slot in a per-code-object pool accumulator, dedup object->slot) and
  **cpnanopass.ss `np-generate-code`** (~8470-8752, where `size`+`code-list` for a
  code object are finalized): flush the pool as trailing `(abs)` quads, grow
  `size` by the pool bytes, resolve the `adr`-to-slot label offsets. Deep
  nanopass-backend work; codegen correctness is high-stakes. P0 sub-order:
  (i) pool accumulator + flush plumbing with pool EMPTY (no behavior change,
  proves the size/label math), (ii) route asm-move literals through it,
  (iii) rebuild + boot + full suite + runtime benchmark.
- **P1 (calls)**: extend to call/jump literals.
- **P2 (mmap-in-place, code bodies)**: contiguous code+GOT layout; keep code
  vspace in the mapping; patch only GOT. Measure the ~7.6ms.
- **P3 (headers)**: resolve the code-object header refs (Q2) so first-pages of
  code objects don't COW.

## Dynamic (non-boot) code
Runtime-compiled/loaded code (eval, dynamic-require, JIT) lands at runtime
addresses. Such a unit's GOT slot indices are still compile-time-local (frozen in
its .zo/code), but its code↔GOT relative distance is only known at load, so the
loader resolves the adrp/ldr immediates when it places the unit (a normal reloc
into fresh, writable, non-shared code). Dynamic code keeps today's per-load
relocation cost and is NOT mmapped/shared — only boot code takes the baked/
mmap-in-place path. The two coexist exactly like an ELF main-program (prelinked)
vs. dlopen'd libraries (relocated at load).

## Correctness / testing
- Boot build drives the converter on all boot files — a codegen/reloc bug shows
  up immediately as a boot failure.
- Differential: `PLT_VFASL_TIMES` room+copy + relink deltas per phase.
- Full test suite + REPL + a compute benchmark (confirm no execution regression;
  compare against the pic-bench prediction).
- FASL FORMAT CHANGES → the whole world (boot + all .zo) must be recompiled;
  version-incompatible. AArch64-only (other backends keep the abs path).

## Open questions / risks
- **Q1**: does `adrp` itself need any fixup? If code↔GOT relative layout is fixed
  at load, no. Must verify the loader guarantees that layout (contiguous alloc).
- **Q2 (headers)**: code-object headers hold object refs (reloc ptr, name) the GC
  reads directly in C. To keep code pages fully clean these must be PIC too
  (header→GOT) or headers grouped in a separate patched region. Until P3, header
  pages COW (bounded: ~one page per code object first-page, but with thousands of
  objects that leaks much of the win — P3 is required for the full ~7.6ms).
- **Q3**: `adrp` reach is ±4GB — always fine within one image; confirm the static
  generation keeps code+GOT within range.
- **Q4**: register allocation for Xtmp (adrp scratch) — a normal temp, but verify
  no pressure regression in hot code.
- **Risk**: codegen correctness is high-stakes (a wrong reloc = silent bad code).
  Delicate; needs the differential + full-suite gate every phase.

## Bottom line
Moderate-large, AArch64-only, FASL-format-breaking (full recompile), high-care.
Win ~7.6ms of boot with no measured execution cost. P0 (prove codegen + runtime
parity) is the cheap first increment that de-risks the rest before touching
layout/mmap.
