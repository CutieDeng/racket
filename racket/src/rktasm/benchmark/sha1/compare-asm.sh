#!/usr/bin/env sh
set -eu

if [ "$#" -ne 2 ] && [ "$#" -ne 3 ]; then
  echo "Usage: $0 <asm_000.s> <asm_001.s> [asm_002.s]" >&2
  exit 2
fi

asm_000="$1"
asm_001="$2"
asm_002="${3:-}"

count() {
  pattern="$1"
  file="$2"
  rg -o "$pattern" "$file" 2>/dev/null | wc -l | tr -d ' '
}

if [ -n "$asm_002" ]; then
  echo "=== Static ASM Comparison (000 vs 001 vs 002) ==="
else
  echo "=== Static ASM Comparison (000 vs 001) ==="
fi
echo "000 stack-bounce stp/ldr pair : $(count 'str q[0-9]+, \[sp, #-16\]!|ldr w[0-9]+, \[sp\]' "$asm_000")"
echo "001 stack-bounce stp/ldr pair : $(count 'str q[0-9]+, \[sp, #-16\]!|ldr w[0-9]+, \[sp\]' "$asm_001")"
if [ -n "$asm_002" ]; then
  echo "002 stack-bounce stp/ldr pair : $(count 'str q[0-9]+, \[sp, #-16\]!|ldr w[0-9]+, \[sp\]' "$asm_002")"
fi
echo "000 umov lane extract         : $(count 'umov w[0-9]+, v[0-9]+\.s\[0\]' "$asm_000")"
echo "001 umov lane extract         : $(count 'umov w[0-9]+, v[0-9]+\.s\[0\]' "$asm_001")"
if [ -n "$asm_002" ]; then
  echo "002 umov lane extract         : $(count 'umov w[0-9]+, v[0-9]+\.s\[0\]' "$asm_002")"
fi
echo "000 sha1h usage               : $(count 'sha1h s[0-9]+, s[0-9]+' "$asm_000")"
echo "001 sha1h usage               : $(count 'sha1h s[0-9]+, s[0-9]+' "$asm_001")"
if [ -n "$asm_002" ]; then
  echo "002 sha1h usage               : $(count 'sha1h s[0-9]+, s[0-9]+' "$asm_002")"
fi
echo "000 save pre-index stp        : $(count 'stp x29, x30, \[sp, #-[0-9]+\]!' "$asm_000")"
echo "001 save pre-index stp        : $(count 'stp x29, x30, \[sp, #-[0-9]+\]!' "$asm_001")"
if [ -n "$asm_002" ]; then
  echo "002 save pre-index stp        : $(count 'stp x29, x30, \[sp, #-[0-9]+\]!' "$asm_002")"
fi
