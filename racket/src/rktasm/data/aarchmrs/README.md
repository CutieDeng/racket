# AARCHMRS — Arm Machine Readable Architecture Specification (vendored regen input)

rktasm's encoding/spec tables are *generated from* Arm's Machine Readable Spec.
The official compressed archive is committed here as the source of truth; the
generated `.rktd` tables under `syntax/data/generated/` are what rktasm uses at
runtime.

## Why it lives here (source dist yes, build no)

- **Committed:** `AARCHMRS_OPENSOURCE_A_profile_FAT-2025-12.tar.gz` (5.1 MB) +
  `prepare-aarchmrs.sh` + this README.
- **Not committed:** the ~200 MB uncompressed JSON, extracted to `cache/`
  (gitignored) only during a regen.
- **Not in the build/install:** rktasm has no `info.rkt`, is not a Racket
  collection, and is not in the Racket build graph — so nothing here reaches the
  built/installed product. Only the source tree (clone / source distribution)
  carries the 5.1 MB archive, which is acceptable.

Committing the archive (rather than fetching at regen) keeps regen **offline and
reproducible** and independent of Arm's CDN — its permalinks rotate (the 2024-12
link already 404s). The committed archive's sha256 can be checked against Arm's.

## Usage (regen only)

```sh
./prepare-aarchmrs.sh            # verify sha256 + extract to cache/ (offline)
./prepare-aarchmrs.sh --download # version bump: refetch from Arm, then commit
```

Generators then read:
```
cache/AARCHMRS_OPENSOURCE_A_profile_FAT-2025-12/Instructions.json
cache/AARCHMRS_OPENSOURCE_A_profile_FAT-2025-12/Registers.json   # sysreg name -> encoding
```

## Pinned release

- Version: FAT A-profile **2025-12** (BSD-licensed open-source MRS).
- URL: `https://developer.arm.com/-/cdn-downloads/permalink/Exploration-Tools-OS-Machine-Readable-Data/AARCHMRS_BSD/AARCHMRS_OPENSOURCE_A_profile_FAT-2025-12.tar.gz`
- sha256: `4dc5da62a5c856d7b1086b895075f54807f821ea21a333049cb0f40f9479cecc`
- Expands to `Instructions.json` (~110 MB), `Registers.json` (~89 MB),
  `Features.json` (~1.1 MB), `docs/`.

`Registers.json` carries every system register's `asmvalue → {op0,op1,CRn,CRm,op2}`
(1810 registers), e.g. `CNTVCTSS_EL0 = 3/3/14/0/6` — the source for named
`mrs`/`msr` operand support.
