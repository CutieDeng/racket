# IPA Regalloc Roadmap For Library-Grade Deflate

This roadmap is scoped to the deflate subproject, but the machinery should live
in asmp generally. The goal is to make private implementation code fast while
keeping public ABI profiles stable.

## Phase 0: Boundary Model

Status: MVP present.

- Treat `export` as a public root.
- Record explicit `export profile=<name>` metadata.
- Preserve function identity across clones.
- Keep private clone symbols versioned and non-public.
- Preserve `public-abi-origin-profile` metadata when IPA clones an exported root.
- Enforce minimal profile-specific entry rules: ordinary public profiles reject
  private managed ABIs on the canonical entry, while `jit-private` /
  `project-abi` require an explicit `abi=<name>`.
- Lower C-like public managed signatures with independent ABI argument and
  return slots.
- Document that C ABI is only the default public profile, not the only profile.

Missing:

- full profile-specific checkers beyond the minimal entry-rule MVP;
- visibility distinction: public, hidden, local/private;
- address-taken analysis.

## Phase 1: Correct Private Call ABI Selection

Status: MVP present.

- `.call abi=...` source hints can choose a private ABI at one callsite.
- IPA callconv planner can clone and rewrite managed `.call` edges.
- Function clone metadata preserves logical identity.

Next:

- Make automatic planner callsite-aware, not only caller/callee-edge-aware.
- Add explicit clone budgets.
- Add conflict diagnostics that mention source callsite locations.
- Emit a report mapping each selected callsite to its clone.

## Phase 2: Regalloc-Aware Selection

Current planner mostly estimates caller-side move cost. That is not enough for
high-performance deflate.

Needed selection cost model:

```text
total_cost =
  argument_move_cost
  + return_move_cost
  + estimated_spill_cost(caller)
  + estimated_spill_cost(callee)
  + call_clobber_save_restore_cost
  + code_size_penalty
```

Required data:

- per-function register pressure by class;
- per-call live-across set by class;
- callee clobber/effect summary by class;
- estimated spill count/weight after trying an ABI candidate;
- profile or static loop-depth weights.

Implementation direction:

1. Build a cheap static pressure summary first.
2. Try candidate ABI plans and rerun regalloc only for affected functions.
3. Cache results by `(function-version, abi-candidate, caller-set)`.
4. Select the plan with the lowest weighted cost.

## Phase 3: Internal ABI Profiles

Internal ABI profiles should be first-class, just like public profiles, but
they are optimization contracts rather than external contracts.

Examples:

```text
deflate_writer_abi
  gpr args: x20 x21 x22 x23 x24
  scratch: many caller-saved GPRs
  preserved: minimal

deflate_parser_abi
  gpr args: x8 x9 x10 x11 x12 x13
  vector args: v16 v17
  preserved: only what measured callers need
```

The profile should describe:

- argument slots by register class;
- result slots;
- clobber/effect sets;
- stack alignment and frame expectations;
- whether caller and callee may share an inout register;
- whether the ABI is legal across public boundaries.

Only the last point should be false for most internal ABIs.

## Phase 4: Vector/SVE-Aware IPA

Deflate optimization will eventually want faster match extension.

Before exposing vector-heavy internals, asmp needs:

- FPR/NEON clobber summaries that affect caller regalloc;
- SVE `z` and predicate `p` summaries;
- SVE spill/fill support with scalable stack slots;
- ABI profiles for vector/predicate arguments;
- cost model that understands vector register pressure separately from GPR
  pressure.

Do not expose SVE public ABI until private SVE summaries are solid.

## Phase 5: Multi-Version Library Dispatch

Once multiple private implementations exist:

- keep one stable public symbol;
- choose implementation by build flag or runtime CPU feature;
- keep private implementation symbols hidden;
- preserve clone family metadata for debug/profile attribution.

Possible dispatch modes:

| Mode | Portability | Cost | Notes |
|------|-------------|------|-------|
| build-time selected direct call | highest | zero runtime dispatch | MVP |
| first-call cached function pointer | high | one indirect call | works on Mach-O/ELF |
| ELF IFUNC | ELF only | near-zero after resolver | later |
| JIT/runtime patch | runtime-specific | lowest steady-state | later |

## Deflate-Specific Next Step

For `020`, keep public API work separate from parser-quality work:

1. Add `020-deflate-reinsert.asm` as a private implementation version.
2. Keep `019` untouched.
3. Update `VERSIONS.md`.
4. Add `020` to `bench-native.rkt` only after roundtrip passes.
5. Compare CSV output against the `019` baseline.

Keep the existing `019` public wrapper as the stable exported entry:

```text
asmp_deflate_raw_fixed
  -> selected private impl
```

Future `020` versions should update the selected private implementation while
the native harness continues to call the wrapper, not the private symbol.
