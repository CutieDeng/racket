#!/usr/bin/env bash
# Prepare the Arm Machine Readable Spec for a regen.
#
# The official compressed archive (5.1 MB) is COMMITTED next to this script, so
# regen is offline and reproducible and does not depend on Arm's CDN (whose
# permalinks rotate). This script verifies its sha256 and extracts the JSON to a
# gitignored cache/. The ~200 MB raw JSON is never committed; and because rktasm
# is not a Racket collection, none of this is in the build/install output — only
# the source tree (clone / source-dist) carries the 5.1 MB archive.
#
# Version bumps: pass --download to (re)fetch from the pinned URL, then commit
# the refreshed archive + updated SHA256 here.
set -euo pipefail

VERSION="AARCHMRS_OPENSOURCE_A_profile_FAT-2025-12"
URL="https://developer.arm.com/-/cdn-downloads/permalink/Exploration-Tools-OS-Machine-Readable-Data/AARCHMRS_BSD/${VERSION}.tar.gz"
SHA256="4dc5da62a5c856d7b1086b895075f54807f821ea21a333049cb0f40f9479cecc"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE="$HERE/${VERSION}.tar.gz"      # committed (source-of-truth)
CACHE="$HERE/cache"                    # gitignored
EXTRACT="$CACHE/${VERSION}"

if [ "${1:-}" = "--download" ] || [ ! -f "$ARCHIVE" ]; then
    echo "downloading $VERSION from Arm CDN ..."
    curl -fsSL -o "$ARCHIVE" "$URL"
fi

echo "verifying sha256 of committed archive ..."
got="$(shasum -a 256 "$ARCHIVE" | cut -d' ' -f1)"
if [ "$got" != "$SHA256" ]; then
    echo "ERROR: sha256 mismatch for $ARCHIVE" >&2
    echo "  expected $SHA256" >&2
    echo "  got      $got"      >&2
    exit 1
fi

mkdir -p "$EXTRACT"
tar xzf "$ARCHIVE" -C "$EXTRACT" Instructions.json Registers.json Features.json
echo "ready (offline): $EXTRACT/{Instructions,Registers,Features}.json"
