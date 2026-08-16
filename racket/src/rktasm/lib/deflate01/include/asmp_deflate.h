#ifndef ASMP_DEFLATE_H
#define ASMP_DEFLATE_H

#include <stdint.h>

#if defined(__GNUC__) || defined(__clang__)
#define ASMP_PUBLIC_SYM(name) __asm__(name)
#else
#define ASMP_PUBLIC_SYM(name)
#endif

#ifdef __cplusplus
extern "C" {
#endif

enum asmp_deflate_status {
  ASMP_DEFLATE_OK = 0,
  ASMP_DEFLATE_DST_TOO_SMALL = 1,
  ASMP_DEFLATE_SCRATCH_TOO_SMALL = 2,
  ASMP_DEFLATE_BAD_ARGUMENT = 3
};

/* Stable API. */
extern uint64_t asmp_deflate_raw_bound(uint64_t src_len);
extern uint64_t asmp_deflate_raw_scratch_size(void);
extern uint64_t asmp_deflate_raw_scratch_align(void);
extern int asmp_deflate_raw_fixed(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);
extern int asmp_deflate_raw_stored(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len);
extern int asmp_deflate_raw_auto(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);

/* Experimental API. These symbols may change before promotion. */
extern uint64_t asmp_deflate_raw_dynamic_lz77_huffman_bound(uint64_t src_len);
extern uint64_t asmp_deflate_raw_dynamic_lz77_huffman_scratch_size(void);
extern uint64_t asmp_deflate_raw_dynamic_lz77_huffman_scratch_align(void);
extern int asmp_deflate_raw_dynamic_lz77_huffman(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);
extern uint64_t asmp_deflate_raw_auto_dynamic_probe_bound(uint64_t src_len);
extern uint64_t asmp_deflate_raw_auto_dynamic_probe_scratch_size(void);
extern uint64_t asmp_deflate_raw_auto_dynamic_probe_scratch_align(void);
extern int asmp_deflate_raw_auto_dynamic_probe(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);
extern uint64_t asmp_deflate_raw_auto_dynamic_cost_probe_bound(uint64_t src_len);
extern uint64_t asmp_deflate_raw_auto_dynamic_cost_probe_scratch_size(void);
extern uint64_t asmp_deflate_raw_auto_dynamic_cost_probe_scratch_align(void);
extern int asmp_deflate_raw_auto_dynamic_cost_probe(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);
extern uint64_t asmp_deflate_raw_auto_dynamic_size_probe_bound(uint64_t src_len);
extern uint64_t asmp_deflate_raw_auto_dynamic_size_probe_scratch_size(void);
extern uint64_t asmp_deflate_raw_auto_dynamic_size_probe_scratch_align(void);
extern int asmp_deflate_raw_auto_dynamic_size_probe(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);
extern uint64_t asmp_deflate_raw_auto_dynamic_prepared_size_probe_bound(uint64_t src_len);
extern uint64_t asmp_deflate_raw_auto_dynamic_prepared_size_probe_scratch_size(void);
extern uint64_t asmp_deflate_raw_auto_dynamic_prepared_size_probe_scratch_align(void);
extern int asmp_deflate_raw_auto_dynamic_prepared_size_probe(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);
extern uint64_t asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_bound(uint64_t src_len);
extern uint64_t asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_scratch_size(void);
extern uint64_t asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe_scratch_align(void);
extern int asmp_deflate_raw_auto_dynamic_cheap_prepared_size_probe(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);
extern uint64_t asmp_deflate_raw_blocked_fixed_bound(uint64_t src_len);
extern uint64_t asmp_deflate_raw_blocked_fixed_scratch_size(void);
extern uint64_t asmp_deflate_raw_blocked_fixed_scratch_align(void);
extern int asmp_deflate_raw_blocked_fixed(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);
extern uint64_t asmp_deflate_raw_blocked_auto_bound(uint64_t src_len);
extern uint64_t asmp_deflate_raw_blocked_auto_scratch_size(void);
extern uint64_t asmp_deflate_raw_blocked_auto_scratch_align(void);
extern int asmp_deflate_raw_blocked_auto(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);
extern uint64_t asmp_deflate_raw_blocked_dynamic_auto_bound(uint64_t src_len);
extern uint64_t asmp_deflate_raw_blocked_dynamic_auto_scratch_size(void);
extern uint64_t asmp_deflate_raw_blocked_dynamic_auto_scratch_align(void);
extern int asmp_deflate_raw_blocked_dynamic_auto(uint8_t * dst, uint64_t dst_cap, uint64_t * dst_len, const uint8_t * src, uint64_t src_len, void * scratch, uint64_t scratch_len);

#ifdef __cplusplus
}
#endif

#undef ASMP_PUBLIC_SYM

#endif /* ASMP_DEFLATE_H */
