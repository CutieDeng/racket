#!/bin/sh
# M3 .frame / .alloca ABI smoke test — aarch64-linux.
#
# The *.S here are emitted by rktasm from the *.asm sources:
#   (cd racket/src/rktasm && \
#     racket cli/as.rkt --gnu-input --default-abi aapcs64 \
#       -o test/m3/frame_a.S  test/m3/frame_a.asm && \
#     racket cli/as.rkt --gnu-input --default-abi aapcs64 \
#       -o test/m3/alloca_a.S test/m3/alloca_a.asm)
#
# Then run this inside the arm64 gcc container (proves the frame is ABI-correct,
# not just textually plausible):
#   docker run --rm -v "$PWD/racket/src/rktasm/test/m3":/work -w /work \
#     gcc12-openeuler-built:latest sh /work/run.sh
set -e
uname -m
gcc --version | head -1
ld --version | head -1
gcc -o m3test main.c frame_a.S alloca_a.S
echo BUILD_OK
./m3test
