#ifndef ASMP_ZSTD_H
#define ASMP_ZSTD_H

#include <stdint.h>

#if defined(__GNUC__) || defined(__clang__)
#define ASMP_PUBLIC_SYM(name) __asm__(name)
#else
#define ASMP_PUBLIC_SYM(name)
#endif

#ifdef __cplusplus
extern "C" {
#endif

enum asmp_zstd_status {
  ASMP_ZSTD_OK = 0,
  ASMP_ZSTD_DST_TOO_SMALL = 1,
  ASMP_ZSTD_SCRATCH_TOO_SMALL = 2,
  ASMP_ZSTD_BAD_ARGUMENT = 3
};

/* Stable API. */
extern uint64_t asmp_zstd_compress_bound(uint64_t src_len);
extern uint64_t asmp_zstd_scratch_size(void);
extern uint64_t asmp_zstd_scratch_align(void);
extern int asmp_zstd_compress_default(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);

/* Experimental API. These symbols may change before promotion. */
extern uint64_t asmp_zstd_compress_litonly_bound(uint64_t src_len);
extern uint64_t asmp_zstd_compress_litonly_scratch_size(void);
extern uint64_t asmp_zstd_compress_litonly_scratch_align(void);
extern int asmp_zstd_compress_litonly(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);
extern uint64_t asmp_zstd_compress_seqrle_bound(uint64_t src_len);
extern uint64_t asmp_zstd_compress_seqrle_scratch_size(void);
extern uint64_t asmp_zstd_compress_seqrle_scratch_align(void);
extern int asmp_zstd_compress_seqrle(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);
extern uint64_t asmp_zstd_compress_seqrle_wide_bound(uint64_t src_len);
extern uint64_t asmp_zstd_compress_seqrle_wide_scratch_size(void);
extern uint64_t asmp_zstd_compress_seqrle_wide_scratch_align(void);
extern int asmp_zstd_compress_seqrle_wide(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);
extern uint64_t asmp_zstd_compress_seqrle_full_bound(uint64_t src_len);
extern uint64_t asmp_zstd_compress_seqrle_full_scratch_size(void);
extern uint64_t asmp_zstd_compress_seqrle_full_scratch_align(void);
extern int asmp_zstd_compress_seqrle_full(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);
extern uint64_t asmp_zstd_compress_singlematch_bound(uint64_t src_len);
extern uint64_t asmp_zstd_compress_singlematch_scratch_size(void);
extern uint64_t asmp_zstd_compress_singlematch_scratch_align(void);
extern int asmp_zstd_compress_singlematch(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);
extern uint64_t asmp_zstd_compress_predef_singlematch_bound(uint64_t src_len);
extern uint64_t asmp_zstd_compress_predef_singlematch_scratch_size(void);
extern uint64_t asmp_zstd_compress_predef_singlematch_scratch_align(void);
extern int asmp_zstd_compress_predef_singlematch(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);
extern uint64_t asmp_zstd_compress_multirle_bound(uint64_t src_len);
extern uint64_t asmp_zstd_compress_multirle_scratch_size(void);
extern uint64_t asmp_zstd_compress_multirle_scratch_align(void);
extern int asmp_zstd_compress_multirle(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);
extern uint64_t asmp_zstd_compress_multitoken_bound(uint64_t src_len);
extern uint64_t asmp_zstd_compress_multitoken_scratch_size(void);
extern uint64_t asmp_zstd_compress_multitoken_scratch_align(void);
extern int asmp_zstd_compress_multitoken(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);
extern uint64_t asmp_zstd_compress_multitoken_tail_bound(uint64_t src_len);
extern uint64_t asmp_zstd_compress_multitoken_tail_scratch_size(void);
extern uint64_t asmp_zstd_compress_multitoken_tail_scratch_align(void);
extern int asmp_zstd_compress_multitoken_tail(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);
extern uint64_t asmp_zstd_compress_predef_seqstore_bound(uint64_t src_len);
extern uint64_t asmp_zstd_compress_predef_seqstore_scratch_size(void);
extern uint64_t asmp_zstd_compress_predef_seqstore_scratch_align(void);
extern int asmp_zstd_compress_predef_seqstore(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);

#ifdef __cplusplus
}
#endif

#undef ASMP_PUBLIC_SYM

#endif /* ASMP_ZSTD_H */
