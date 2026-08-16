# zstd01 Roadmap

The implementation grows in versioned steps. Old versions should remain
readable and testable while new ones explore more of the format.

1. `001-frame-raw-rle.asm`
   - standard frame header
   - raw blocks
   - RLE blocks
   - libzstd roundtrip tests

2. `002-frame-litonly.asm`
   - compressed block header
   - raw literals section
   - zero-sequence section
   - no match finder yet

3. `003-frame-seq-rle.asm`
   - first non-empty sequence section
   - LL/OF/ML tables emitted in RLE mode
   - one short repeated-byte sequence
   - literal-only fallback for complete API coverage

4. `004-frame-seq-rle-wide.asm`
   - ML code selection for match lengths through 258
   - one-byte ML extra-bit sequence bitstream
   - repeated-byte inputs through 259 bytes

5. `005-frame-seq-rle-full.asm`
   - ML code selection through the zstd block limit
   - multi-byte ML extra-bit sequence bitstream
   - repeated-byte inputs through one 128 KiB block

6. `006-frame-single-match.asm`
   - one narrow prefix-literal parser
   - one offset-1 repeated suffix match
   - validates non-pure-RLE sequence emission before a hash match finder

7. `007-frame-predef-single-match.asm`
   - Predefined_Mode LL/OF/ML table selection
   - initial FSE states for one short sequence
   - fallback to the RLE single-match encoder outside the no-extra-bits range

8. `008-frame-multirle.asm`
   - first multi-sequence block writer
   - RLE_Mode LL/OF/ML tables over repeated four-byte runs
   - fallback to the predefined single-match encoder outside the run shape

9. `009-frame-multitoken.asm`
   - fixed-width sequence store with two literal bytes per token
   - RLE_Mode LL/OF/ML tables over repeated five-byte token shapes
   - fallback to the multi-run encoder outside the token shape

10. `010-frame-multitoken-tail.asm`
   - explicit zstd last-literals handling after repeated token sequences
   - same RLE_Mode LL/OF/ML shape as 009
   - fallback to the no-tail multi-token encoder outside the tail shape

11. `011-frame-predef-seqstore.asm`
   - LL Predefined_Mode with two symbols in one block
   - OF/ML remain RLE_Mode
   - fallback to multitoken-tail outside the two-sequence shape

12. Multi-sequence predefined block
   - raw literal section
   - simple sequence store
   - fast hash match finder for short-offset repeats
   - predefined LL/ML/OF FSE tables

13. Dynamic sequence tables
   - count LL/ML/OF code frequencies
   - normalize FSE counts
   - emit table descriptions
   - compare size policy against predefined tables

14. Literal Huffman
   - literal histogram
   - huff0-compatible weights
   - 1X first, 4X later

15. Match finder variants
   - double-fast
   - lazy
   - binary-tree/optimal probes
   - NEON and SVE variants as `variant-of` implementations
