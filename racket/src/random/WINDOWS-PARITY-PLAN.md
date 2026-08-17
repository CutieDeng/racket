# rktrandom on Windows — Requirements & Design (handoff document)

Status: PLANNED (nothing implemented yet).
Audience: the agent/engineer picking this task up cold. Everything you need
is either in this file or at the file:line references below — verify each
one before relying on it; this document was written against v9.3-dev just
after the 9.3.2 release.

## 1. Goal

`racket/random/generator` (the `rgen-*` API: deterministic PRNG streams,
jumps, forks, float/normal/exponential fills, shuffles, weighted choice) and
the `racket/random` functions that accept an rgen must work on Windows
x86_64 and arm64 exactly as they do on Linux/macOS. Concretely:

- `(require racket/random/generator)` succeeds (it already does — see §3),
  and `rktrandom-available?` returns `#t` on Windows.
- Creating and using generators produces **bit-identical output to Unix for
  the same seed** (the PRNG is deterministic; this is the strongest and
  cheapest cross-platform correctness check).
- Ships in the production Windows portable zip + installer for both arches.

Non-goal: `racket/crypto` / the `#%rktcrypto` primitive table on Windows.
That library genuinely cannot be built with MSVC (`__int128` in the ECC
field arithmetic), which is why TLS went a different route (clang-built
`librktcrypto.dll` loaded via `ffi-lib` — see §7 Prior art). Do not confuse
the two subsystems: **rktrandom has no such blocker.**

## 2. Architecture background (how rktrandom reaches Racket)

Unlike the `openssl` collection (which binds librktcrypto with
`ffi/unsafe` + `(ffi-lib #f)`), rktrandom is wired through the **Chez-level
primitive table** `#%rktrandom`:

- C library: `racket/src/random/` — `rktrandom_gen.c`, `rktrandom_dist.c`,
  `rktrandom_selftest.c`, plus `rktrandom.h` and generated artifacts
  `rktrandom.rktl` / `rktrandom.inc` / `rktrandom.def` (produced from the
  header by `racket/src/rktio/parse.rkt`; see `racket/src/random/build.zuo`).
- Static link: `racket/src/cs/c/build.zuo:152-157` builds `librktrandom.a`
  and links it into the Racket CS executable — but gated
  `(define rktrandom? (not windows?))` with the comment "librktrandom
  follows the librktcrypto platform policy for now". That comment is the
  whole story: the exclusion is **precautionary, not technical**.
- Symbol registration: `racket/src/cs/c/boot.c:133-139` `init_foreign()`
  includes `rktio.inc` unconditionally but wraps `rktcrypto.inc` and
  `rktrandom.inc` in `#ifndef WIN32`. The `.inc` files register the C
  functions as Chez foreign entries.
- Chez side: `racket/src/cs/io.sls:274-284` — `loaded-librktrandom` is
  `(foreign-entry? "rktrandom_selftest")` with an **already-existing
  dynamic-load fallback** (`load-shared-object` of
  `../../lib/librktrandom.<so-suffix>` relative to `RACKET_IO_SOURCE_DIR` or
  the current directory — a build-time affordance, not a production path).
  `io.sls` then includes `rktrandom.rktl` and assembles the
  `#%rktrandom-instance` hash (io.sls:647), adding `rktrandom-available?`
  and three Chez-level refill helpers. `expander.sls:131` exposes it as
  `(primitive-table '#%rktrandom)`.
- Racket side: `racket/collects/racket/random/generator.rkt:56-58` pulls the
  table (the table itself **always exists** on CS builds; only the entries
  raise when the C library is absent) and `racket/collects/racket/random.rkt`
  falls back to the classic pseudo-random generator when no rgen is passed.

Current Windows behavior: module loads fine, `rktrandom-available?` → `#f`,
any attempt to actually construct/use an rgen raises. `crypto-random-bytes`
is unaffected (it goes through rktio's system RNG, which has a
BCryptGenRandom path).

## 3. Key facts already established (verify, then trust)

- `grep -c "__int128\|__attribute__\|__builtin_" racket/src/random/rktrandom_*.c`
  → **0 in every file**. The C is portable C99 math/PRNG code. This is the
  decisive difference from librktcrypto (15 `__int128` uses, 23
  `__attribute__`, 34 `__builtin_*`).
- The whole `racket/src/random` tree already cross-compiles and links as a
  Windows DLL with clang for BOTH x86_64 and aarch64 — done Aug 2026 with
  `zig cc` during the TLS work (librktrandom.dll linked cleanly using
  `rktrandom.def` for exports, no `-lbcrypt` needed).
- The zuo build system already knows how to drive MSVC: see
  `racket/src/crypto/build.zuo:12` (`msvc?` from `toolchain-type`) — the
  random/build.zuo is the same shape.
- `rktrandom.def` (69-line style, same generator as rktcrypto's) exists for
  DLL exports if the DLL route is ever needed.

## 4. Design options

### Option B — static-link parity (RECOMMENDED, try first)

Make Windows identical to Unix: compile `librktrandom` with MSVC and link
it into the executable. Expected to be a 2-line gate change plus fallout:

1. `racket/src/cs/c/build.zuo:154`: `(define rktrandom? (not windows?))` →
   `(define rktrandom? #t)`. Leave `rktcrypto?` strictly alone.
2. `racket/src/cs/c/boot.c`: move `# include "rktrandom.inc"` out of the
   `#ifndef WIN32` block (keep `rktcrypto.inc` inside it).
3. Fix whatever MSVC then complains about in `rktrandom_*.c`. Expected:
   nothing or trivia (C99 loop declarations are fine on modern MSVC; watch
   for `//`-comments-only issues = none, VLAs = check, `<stdint.h>` = fine).
   If MSVC needs flags, `racket/src/random/build.zuo` is where per-toolchain
   CFLAGS live (mirror how crypto/build.zuo handles `msvc?`).
4. Check the Windows link step picks up `librktrandom.lib`:
   `racket/src/cs/c/build.zuo:209-210` and `:663-664` already add it
   generically when `rktrandom?` is true — read those call sites to confirm
   nothing else is Unix-only (e.g. archive tool naming: build.zuo's `lta`
   is already `lib` under MSVC).

Why this is right: no new runtime artifact, no loader changes, io.sls and
generator.rkt need **zero** modifications (`foreign-entry?` succeeds, table
lights up), and it honors the build system's existing "optional subsystem"
design. It also removes a Windows/Unix difference instead of adding a
Windows-only code path.

### Option A — clang DLL + boot-time load (fallback if B hits a real wall)

Mirror the TLS approach: build `librktrandom.dll` with llvm-mingw in the
packaging workflow (the compile/link is already proven), ship it next to
`Racket.exe`, and extend the `loaded-librktrandom` fallback in
`racket/src/cs/io.sls:274-284` to also try, on Windows, a guarded
`(load-shared-object "librktrandom.dll")` (plain name → Windows DLL search
→ exe directory). Notes if you go this way:

- `load-shared-object` failures must stay inside the existing `guard` so a
  missing DLL degrades to `rktrandom-available? = #f` exactly as today.
- io.sls edits require rebuilding the io linklet (happens automatically in
  a source build; no boot-file gymnastics needed for a from-source release).
- Packaging: add the DLL to the librktcrypto.dll step in package-racket's
  `windows-ci-build-job` (see §7) rather than a new step.

Only pick A if MSVC genuinely cannot build the C — which the evidence says
will not happen. Do not implement both.

## 5. Verification plan

1. **Local sanity (macOS)**: after any build.zuo/boot.c change, a normal
   Unix build must still pass; then
   `racket -e "(require racket/random/generator) (displayln rktrandom-available?)"`
   → `#t`, and capture reference outputs: seed a generator deterministically
   and record, say, the first 16 `rgen-ref` integers and a few
   `rgen-flvector` values into the test below.
2. **PoC on real Windows before touching production packaging** — copy the
   pattern of `poc-rktcrypto-win-tls.yml` in the CutieDeng/win-racket repo
   (hand-authored PoC workflows are the established mechanism there):
   matrix over `windows-2022` (x64) + `windows-11-arm` (arm64), build Racket
   from a source archive or the fork branch with the gate change, then
   hard-assert:
   - `rktrandom-available?` → `#t`;
   - **cross-platform determinism**: same seed on Windows produces the exact
     Unix reference values captured in step 1 (this catches real bugs —
     `long` is 32-bit on Windows, so any `unsigned long` arithmetic in the
     C would show up here; grep for `long` in rktrandom_*.c during review);
   - a distribution smoke (`rgen-normal` mean/variance over ~1e5 draws
     within loose bounds) and `rgen-fork` / `rgen-jump!` behavior.
   Note the PoC builds from the 9.3.2 source archive **won't contain your
   changes** — either build from a pushed fork branch (git clone in the
   workflow) or overlay changed files, as the TLS PoC did with pinned-commit
   raw.githubusercontent fetches (pin the FULL 40-char sha; a truncated or
   hand-typed sha caused a 404 loop last time).
3. **Selftest**: `rktrandom_selftest.c` exists — find how it's invoked on
   Unix (grep for callers) and run the same on Windows in the PoC.

## 6. Shipping plan

Same shape as the 9.3.2 cycle (see `packaging-new-version-checklist` memory
and the 9.3.2 commits in CutieDeng/package-racket):

1. Land the fork changes on `v9.3-dev`, bump `MZSCHEME_VERSION_Z` → 9.3.3
   in `racket/src/version/racket_version.h`.
2. Create GitHub release v9.3.3 on CutieDeng/racket via the token API
   FIRST, then `package-racket --target brew` (needs `--formula-build-mode
   full`, `--homebrew-tap`, `--bottle-root-url .../v9.3.3`) +
   `--target source-release` to build/upload the reproducible source tgz.
3. Bump all packaging configs to 9.3.3 revision 1, regenerate ALL targets
   (`brew-ci`, `deb-spec` **and** `deb-ci`, `rpm-spec` **and** `rpm-ci`
   (needs `--rpm-system el9 --rpm-release 1 --rpm-arch x86_64`),
   `windows-portable-ci`), update `tests/package-racket-test.rkt` (including
   the fake racket root's `MZSCHEME_VERSION_Z`), `raco test` green.
4. Add a `rktrandom-available?` hard assertion to the Windows portable
   smoke in package-racket's `windows-ci-build-job` (next to the existing
   TLS smoke), and to the brew formula test for all platforms.
5. Push downstream repos; drive CI green. Known cycle traps, all hit during
   9.3.2: rpm release tags are immutable (fresh `v9.3.3-r1`); rebasing the
   tap onto the bottle-bot commit resurrects the previous bottle block
   (remove it again, and don't leave a doubled blank line — rubocop
   `Layout/EmptyLines` fails tap-syntax); the working token lacks
   `actions:write`, so failed runs are retriggered with empty commits;
   GitHub 503/429 outages killed publish jobs twice — just retrigger.

## 7. Prior art / references

- TLS-on-Windows (the sibling task, SHIPPED in 9.3.2): fork commits
  `d16138335f` (DLL-aware `openssl/private/rktcrypto-ffi.rkt`, crypt32
  trust-store loader) and `11eace2ed1` (9.3.2 bump); win-racket PoC
  workflow `poc-rktcrypto-win-tls.yml` (green run #3 is the reference for
  the PoC pattern: hard asserts, pinned-commit overlays, llvm-mingw
  install); package-racket commit `bd8fe7b` (windows-ci-build-job DLL step
  + hard TLS smoke + 9.3.2 config bump).
- Local working checkouts: fork
  `/Users/cutiedeng/Y2026/M07/D16/racket-feat-swisstable` (branch
  `v9.3-dev`, remote `pri-github`), packaging
  `/Users/cutiedeng/Y2026/M06/D21/package-racket`, win repo
  `/Users/cutiedeng/Y2026/M06/D23/win-racket`.
- Conventions that will bite you: commit messages are raw Racket datums
  `(TYPE "title" () "detail with Modified: list")` validated by
  `~/.claude/skills/commit/scripts/check-commit-message.rkt`; no
  Co-Authored-By; long builds go through the user's tmux session; the
  GitHub token lives at `package-racket/secret/ghtoken.rktd` — never print
  it, never install `gh`-authenticated flows around it.

## 8. Acceptance criteria

- [ ] `rktrandom-available?` is `#t` on Windows x86_64 AND arm64 production
      artifacts (zip + installer), asserted in CI before publish.
- [ ] Same-seed outputs are bit-identical to Unix (spot-checked in CI).
- [ ] Unix/macOS builds unchanged and green (brew/deb/rpm CI).
- [ ] No change to librktcrypto's build gating (`rktcrypto?` stays
      `(not windows?)`).
- [ ] build.zuo comment "follows the librktcrypto platform policy" is
      updated/removed so the next reader isn't misled.
