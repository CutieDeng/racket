#!/bin/sh
# Build and run the constant-time (dudect-style) timing check.
# Usage: sh run-dudect.sh
set -e
here=$(dirname "$0")
src="$here/.."
cc -std=c99 -O2 -I"$src" \
   "$here/dudect_ct.c" \
   "$src/rktcrypto_ct.c" "$src/rktcrypto_x25519.c" \
   -o "$here/dudect_ct" -lm
exec "$here/dudect_ct"
