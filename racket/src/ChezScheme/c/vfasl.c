/* vfasl.c
 * Copyright 1984-2017 Cisco Systems, Inc.
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 * http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "system.h"

/*

   vfasl ("very fast load") format, where "data" corresponds to an
   image to load into memory, "table" is metadata to relocate that
   data, and the fixed-size header determines the overall size. The
   data can be loaded directly to the static generation on boot, since
   it's organized into pieces that should reside in a particular
   space.

        [vfasl_header]
     _
    /   [symbol] ...         -> space_symbol
   /    [rtd] ...            -> space_pure
d |     [closure] ...        -> space_pure
a |     [impure] ...         -> space_impure
t |     [pure_typed] ...     -> space_pure_typed
a |     [impure_record] ...  -> space_impure_record
  |     [code] ...           -> space_code
   \    [data] ...           -> space_data
    \_  [reloc] ...          -> (not kept for direct-to-static)
     _
t   /   [symbol reference offset] ...
a  /    [rtd reference offset] ...
b |     [singleton reference offset] ...
l  \
e   \_  [bitmap of pointers to relocate]

   The bitmap at the end has one bit for each pointer-sized word in
   the data, but it's shorter than the "data" size (divided by the
   pointer size then divided by 8 bits per byte) because the trailing
   zeros for data are omitted. The bitmap doesn't include some fixups
   that are handled more directly, such as for code and its
   relocations.

*/

typedef uptr vfoff;

/* Needs to match vspace enum order, maps vfasl spaces to allocation
   spaces: */
static ISPC vspace_spaces[] = {
  space_symbol,
  space_pure, /* rtd */
  space_pure, /* closure */
  space_impure,
  space_pure_typed_object,
  space_impure_record,
  space_code,
  space_data, /* got --- 8-byte PIC slots, updated via the reloc table, not GC-scanned */
  space_data,
  space_data /* reloc --- but not really, since relocs are never in static */
};

#define ptr_add(p, n) ((ptr)((uptr)(p) + (n)))
#define ptr_subtract(p, n) ((ptr)((uptr)(p) - (n)))
#define ptr_diff(p, q) ((uptr)(p) - (uptr)(q))

#define segment_align(size) (((size)+bytes_per_segment-1) & ~(bytes_per_segment-1))

/* externalref extension (fasl2): a singleton index >= this base means
   "externals[index - base]" (an external literal in a DATA slot) rather
   than a built-in singleton.  Must match #x40000000 in "vfasl.ss".  A plain
   #define keeps the pb bootstrap (upstream headers) building. */
#define VFASL_EXTERNAL_BASE 0x40000000

/* arm64 PIC (P2.3): on platforms whose code space is plain memory (no
   MAP_JIT), a PIC (GOT-bearing) image's code+got vspaces need not be
   copied out of the boot file: the loader takes a code-space block from
   find_room as usual -- so the range has ordinary static space_code
   seginfo and the GC cannot tell the difference (the generated GC
   dereferences SegInfo unchecked on its fast paths, so code must never
   live outside managed segments) -- and then maps the boot file's pages
   over it with MAP_PRIVATE|MAP_FIXED.  The baked adrp/ldr pairs are
   valid because the code lands congruent to its image offset mod 4096
   (the converter pads each image's data start to a 4096-aligned file
   offset; checked at run time, copied otherwise -- this also makes the
   placement page-size-independent, since the window base is page-aligned
   and 4096 divides every supported page size).  Only the pages relink
   and the pointer sweep actually write get COW'd; clean code pages stay
   shared with the file.

   DEFAULT OFF (set PLT_VFASL_CODE_ZC to enable), and that is a MEASURED
   verdict, not a temporary one: the pages the pointer sweep and relink
   write are fixed by the object model (a header per code object), so a
   PIC image dirties ~82% of its code pages no matter how they are
   backed.  Their page-frame allocation + data movement is unavoidable,
   and the plain copy path pays it as one warm sequential memcpy -- close
   to optimal.  Zero-copy variants measured on tarm64le: pure COW +2.5ms,
   anonymous-overmap+memcpy +4ms (first touch of anonymous pages faults
   too), MADV_POPULATE_WRITE batching (kept below) +1.8ms -- the residue
   is kernel-side per-page COW plus read faults on the clean pages the
   sweep visits.  What zero-copy buys is ~970 clean pages (~4MB) of
   file-backed, cross-process-shared memory; enable it when that matters
   more than ~2ms of load time. */
#if defined(AARCH64) && !defined(CANNOT_READ_DIRECTLY_INTO_CODE) && !defined(WIN32)
# define VFASL_CODE_ZERO_COPY 1
# include <sys/mman.h>
# include <unistd.h>
#endif

/* Set by the boot loader ("scheme.c") while the fasl stream reads from
   the permanent boot-file mapping: the file descriptor and the mapping
   base, so the code-space file mapping above can be created.  The fd is
   only valid during the load (it may be closed afterward). */
int S_vfasl_mapping_fd = -1;
uptr S_vfasl_mapping_base = 0;

#ifdef VFASL_CODE_ZERO_COPY
/* P3 dirty-extent hybrid: the writer appends a dirty-page bitmap (one
   bit per 4K page over the 4096-aligned [code, got-end) envelope, then
   a trailing uptr length) to the reloc vspace.  Pages relink and the
   pointer sweep will write are backed with copied anonymous memory up
   front -- one bulk memcpy instead of a COW fault per page -- while
   clean runs of at least ZC_KEEP_PAGES OS pages stay file-backed and
   shared.  The bitmap is a prediction: a page it misses just COWs. */
# define ZC_KEEP_PAGES 2

static int zc_os_page_dirty(const octet *dbm, uptr env_pages, uptr env_file_base,
                            uptr pos, uptr pagesz) {
  uptr end = pos + pagesz, i, iend;
  uptr env_file_end = env_file_base + (env_pages << 12);
  if (end <= env_file_base || pos >= env_file_end) return 0;
  i = (pos > env_file_base) ? ((pos - env_file_base) >> 12) : 0;
  iend = ((end < env_file_end ? end : env_file_end) - env_file_base) >> 12;
  for (; i < iend; i++)
    if (dbm[i >> 3] & (1 << (i & 7))) return 1;
  return 0;
}

static void zc_copy_dirty_extents(uptr w, uptr maplen, uptr pagesz, uptr f0,
                                  faslFile stream, uptr *vspace_offsets, uptr got_len) {
  uptr image_rest = vspace_offsets[vspaces_count] - vspace_offsets[vspace_code];
  uptr env_base, env_pages, bmlen, env_file_base, wpages, j;
  const octet *dbm; octet *tail;
  if ((iptr)(stream->end - stream->next) < (iptr)image_rest) return;
  tail = stream->next + image_rest;
  env_base = vspace_offsets[vspace_code] & ~(uptr)4095;
  env_pages = ((vspace_offsets[vspace_got] + got_len) - env_base + 4095) >> 12;
  memcpy(&bmlen, tail - sizeof(uptr), sizeof(uptr));
  if (bmlen != ((env_pages + 7) >> 3)) return; /* absent/foreign bitmap: pure COW */
  dbm = tail - sizeof(uptr) - bmlen;
  /* 4K-aligned because the caller verified stream->next mod 4096 ==
     vspace_offsets[vspace_code] mod 4096 */
  env_file_base = ((uptr)stream->next - S_vfasl_mapping_base)
                  - (vspace_offsets[vspace_code] - env_base);
  wpages = maplen / pagesz;
  j = 0;
  while (j < wpages) {
    uptr j0, jend;
    if (!zc_os_page_dirty(dbm, env_pages, env_file_base, f0 + j * pagesz, pagesz)) {
      j++;
      continue;
    }
    j0 = j;
    jend = j + 1;
    while (jend < wpages) {
      if (zc_os_page_dirty(dbm, env_pages, env_file_base, f0 + jend * pagesz, pagesz)) {
        jend++;
      } else {
        uptr c = jend;
        while (c < wpages
               && !zc_os_page_dirty(dbm, env_pages, env_file_base, f0 + c * pagesz, pagesz))
          c++;
        if (((c - jend) < ZC_KEEP_PAGES) && (c < wpages))
          jend = c + 1; /* swallow a short clean gap; c itself is dirty */
        else
          break;
      }
    }
    {
      /* pre-COW the extent in one kernel pass: anonymous overmap +
         memcpy would fault per page anyway (zero-fill on first touch),
         so batch the unavoidable page copies without the per-page trap.
         On kernels without MADV_POPULATE_WRITE the extent just COWs. */
#ifdef MADV_POPULATE_WRITE
      (void)madvise(TO_VOIDP(w + j0 * pagesz), (jend - j0) * pagesz,
                    MADV_POPULATE_WRITE);
#endif
    }
    j = jend;
  }
}
#endif

/* optimization A: on platforms where CANNOT_READ_DIRECTLY_INTO_CODE forces the
   code vspace to be read into a temporary and then memcpy'd into the real
   (MAP_JIT) code space, that temp exists only for the fd-read() path: read()
   cannot target a JIT-protected page.  When the vfasl source is a permanent
   mapping with all the bytes present, S_fasl_bytesin degrades to a plain
   memcpy (a userspace write), which can go straight into the code space under
   the same write-enabled state the trailing memcpy already relies on.  So skip
   the temp for the mapping case and copy the code space once instead of twice.
   Define to 0 to disable (A/B). */
#ifndef VFASL_CODE_DIRECT_FROM_MAPPING
# define VFASL_CODE_DIRECT_FROM_MAPPING 1
#endif

static uptr symbol_pos_to_offset(uptr sym_pos) {
  uptr syms_per_segment = bytes_per_segment / size_symbol;
  uptr segs = sym_pos / syms_per_segment;
  uptr syms = sym_pos - (segs * syms_per_segment);
  return (segs * bytes_per_segment) + (syms * size_symbol);
}

static void relink_code(ptr co, ptr sym_base, ptr *vspaces, uptr *vspace_offsets, IBOOL to_static, ptr externals);
static ptr find_pointer_from_offset(uptr p_off, ptr *vspaces, uptr *vspace_offsets, int *hint);

/* externalref extension (fasl2): resolve an external index against the
   per-load externals vector.  Svector_ref is unchecked, and an image that
   declares more externals than the caller supplied (e.g. a length-0 vector)
   would read off the end.  Fail loudly instead: on the normal boot path the
   image declares no externals, so no external index is ever produced and this
   is never reached; only a malformed/mismatched externals-bearing image trips
   it, which is a load invariant violation like the bad-reloc-tag case below. */
static ptr vfasl_external_ref(ptr externals, uptr idx) {
  if (idx >= (uptr)Svector_length(externals))
    S_error_abort("vfasl: external index out of range");
  return Svector_ref(externals, idx);
}

static ptr lookup_singleton(iptr which);

/* Set by the boot loader while the fasl stream's buffer is a
   process-lifetime file mapping: the reloc space, which relinking
   consumes during the load and which would be dropped afterward
   anyway (see relink_code), can then point into the mapping instead
   of being copied into segments.  No heap reference to the mapped
   bytes survives the load: every code object's reloc field ends up
   cleared or pointing at a fresh copy in the static generation, the
   same as with the discarded temporary copy this replaces. */
int S_vfasl_source_is_permanent_mapping = 0;

/* attribution aid: cumulative per-phase load times, gated by
   PLT_VFASL_TIMES and reported at exit */
#include <time.h>
#include <stdlib.h>
#include <stdint.h>
enum {
  vfasl_phase_copy, vfasl_phase_room, vfasl_phase_memcpy,
  vfasl_phase_ptr_sweep, vfasl_phase_singletons,
  vfasl_phase_intern_syms, vfasl_phase_symrefs, vfasl_phase_rtds,
  vfasl_phase_closures, vfasl_phase_relink, vfasl_phase_count
};
static const char *vfasl_phase_names[] = {
  "room+copy", "  find_room", "  memcpy", "ptr-sweep", "singletons", "intern-syms",
  "symrefs", "rtds", "closures", "relink-code"
};
static uint64_t vfasl_phase_ns[vfasl_phase_count];
static int vfasl_times_on = -1;
static uint64_t vfasl_now(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
  return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}
static void vfasl_report_times(void) {
  int i;
  for (i = 0; i < vfasl_phase_count; i++)
    fprintf(stderr, ";; vfasl %-12s %8.2f ms\n",
            vfasl_phase_names[i], vfasl_phase_ns[i] / 1e6);
}
static void vfasl_times_init(void) {
  if (vfasl_times_on < 0) {
    vfasl_times_on = (getenv("PLT_VFASL_TIMES") != NULL);
    if (vfasl_times_on)
      atexit(vfasl_report_times);
  }
}
#define VFASL_PHASE_BEGIN() (vfasl_times_on ? vfasl_now() : 0)
#define VFASL_PHASE_END(t0, phase) \
  do { if (vfasl_times_on) vfasl_phase_ns[phase] += vfasl_now() - (t0); } while (0)

/* attribution aid: distinct pages written after the initial copy,
   per vspace, gated by PLT_VFASL_WRITES */
static int vfasl_writes_on = -1;
static uptr vfasl_w_base[vspaces_count], vfasl_w_end[vspaces_count];
static unsigned char *vfasl_w_bits[vspaces_count];
static uptr vfasl_pages_total[vspaces_count], vfasl_pages_written[vspaces_count];
/* clean/dirty run-length accounting for the code vspace (planning aid for
   the dirty-extent hybrid mapping): counts of maximal clean runs by
   length bucket, and of dirty runs */
static uptr vfasl_code_clean_runs[5]; /* >=1, >=2, >=4, >=8, >=16 pages */
static uptr vfasl_code_dirty_runs, vfasl_code_clean_pages_ge4;
static void vfasl_writes_report(void) {
  static const char *names[] =
    { "symbol", "rtd", "closure", "impure", "pure-typed",
      "impure-record", "code", "got", "data", "reloc" };
  int s;
  for (s = 0; s < vspaces_count; s++)
    if (vfasl_pages_total[s])
      fprintf(stderr, ";; vfasl writes %-14s %6ld / %6ld pages (%.1f%%)\n",
              names[s], (long)vfasl_pages_written[s], (long)vfasl_pages_total[s],
              100.0 * vfasl_pages_written[s] / vfasl_pages_total[s]);
  if (vfasl_code_dirty_runs)
    fprintf(stderr, ";; vfasl code runs: dirty %ld; clean >=1 %ld >=2 %ld >=4 %ld >=8 %ld >=16 %ld; clean pages in >=4 runs %ld\n",
            (long)vfasl_code_dirty_runs,
            (long)vfasl_code_clean_runs[0], (long)vfasl_code_clean_runs[1],
            (long)vfasl_code_clean_runs[2], (long)vfasl_code_clean_runs[3],
            (long)vfasl_code_clean_runs[4], (long)vfasl_code_clean_pages_ge4);
}
static void vfasl_writes_begin(ptr *vspaces, uptr *vspace_offsets) {
  int s;
  if (vfasl_writes_on < 0) {
    vfasl_writes_on = (getenv("PLT_VFASL_WRITES") != NULL);
    if (vfasl_writes_on) atexit(vfasl_writes_report);
  }
  if (!vfasl_writes_on) return;
  for (s = 0; s < vspaces_count; s++) {
    uptr len = vspace_offsets[s+1] - vspace_offsets[s];
    uptr npages = (len + 4095) >> 12;
    vfasl_w_base[s] = (uptr)vspaces[s];
    vfasl_w_end[s] = (uptr)vspaces[s] + len;
    vfasl_w_bits[s] = npages ? calloc((npages + 7) >> 3, 1) : NULL;
    vfasl_pages_total[s] += npages;
  }
}
static void vfasl_writes_end(void) {
  int s;
  if (vfasl_writes_on != 1) return;
  for (s = 0; s < vspaces_count; s++) {
    if (vfasl_w_bits[s]) {
      uptr npages = (vfasl_w_end[s] - vfasl_w_base[s] + 4095) >> 12, i;
      for (i = 0; i < npages; i++)
        if (vfasl_w_bits[s][i >> 3] & (1 << (i & 7)))
          vfasl_pages_written[s]++;
      if (s == vspace_code) {
        uptr run = 0; int dirty_prev = -1;
        for (i = 0; i <= npages; i++) {
          int d = (i < npages) ? ((vfasl_w_bits[s][i >> 3] >> (i & 7)) & 1) : -1;
          if (d != dirty_prev) {
            if (dirty_prev == 0) {
              vfasl_code_clean_runs[0]++;
              if (run >= 2) vfasl_code_clean_runs[1]++;
              if (run >= 4) { vfasl_code_clean_runs[2]++; vfasl_code_clean_pages_ge4 += run; }
              if (run >= 8) vfasl_code_clean_runs[3]++;
              if (run >= 16) vfasl_code_clean_runs[4]++;
            } else if (dirty_prev == 1)
              vfasl_code_dirty_runs++;
            run = 0;
            dirty_prev = d;
          }
          run++;
        }
      }
      free(vfasl_w_bits[s]);
      vfasl_w_bits[s] = NULL;
    }
    vfasl_w_base[s] = vfasl_w_end[s] = 0;
  }
}
static void vfasl_mark_write(void *addr) {
  uptr a = (uptr)addr;
  int s;
  if (vfasl_writes_on != 1) return;
  for (s = 0; s < vspaces_count; s++)
    if (a >= vfasl_w_base[s] && a < vfasl_w_end[s] && vfasl_w_bits[s]) {
      uptr pg = (a - vfasl_w_base[s]) >> 12;
      vfasl_w_bits[s][pg >> 3] |= (1 << (pg & 7));
      return;
    }
}
#define VFASL_MARK(addr) vfasl_mark_write((void *)(addr))

/************************************************************/
/* Loading                                                  */

ptr S_vfasl(ptr bv, faslFile stream, iptr offset, iptr input_len, ptr externals)
{
  ptr vspaces[vspaces_count];
  uptr vspace_offsets[vspaces_count+1];
# define VSPACE_LENGTH(s) (vspace_offsets[(s)+1] - vspace_offsets[(s)])
# define VSPACE_END(s) ptr_add(vspaces[(s)], VSPACE_LENGTH(s))
  ptr tc = get_thread_context();
  octet header_space[size_vfasl_header];
  ptr header = TO_PTR(header_space);
  ptr table;
  vfoff *symrefs, *rtdrefs, *singletonrefs;
  octet *bm, *bm_end;
  iptr used_len;
  int s;
  void *bv_addr;
  IBOOL to_static = 0;
#ifdef AARCH64
  uptr got_len = 0;
#endif
#ifdef VFASL_CODE_ZERO_COPY
  IBOOL code_in_mapping = 0;
#endif

  used_len = sizeof(header);
  if (used_len > input_len)
    S_error("fasl-read", "input length mismatch");

  if (bv)
    memcpy(&header_space, &BVIT(bv, offset), size_vfasl_header);
  else
    S_fasl_bytesin(header_space, size_vfasl_header, stream);

  used_len += VFASLHEADER_DATA_SIZE(header) + VFASLHEADER_TABLE_SIZE(header);
  if (used_len > input_len)
    S_error("fasl-read", "input length mismatch");

  vspace_offsets[0] = 0;
  for (s = 1; s < vspaces_count; s++) {
    vspace_offsets[s] = VFASLHEADER_VSPACE_REL_OFFSETS(header, s-1);
  }
  vspace_offsets[vspaces_count] = VFASLHEADER_DATA_SIZE(header);

  vfasl_times_init();

  /* attribution aid: report each loaded vfasl block's per-space sizes */
  if (getenv("PLT_VFASL_STATS")) {
    static const char *vspace_names[] =
      { "symbol", "rtd", "closure", "impure", "pure-typed",
        "impure-record", "code", "got", "data", "reloc" };
    fprintf(stderr, ";; vfasl block: total %ld", (long)VFASLHEADER_DATA_SIZE(header));
    for (s = 0; s < vspaces_count; s++) {
      long sz = (long)(vspace_offsets[s+1] - vspace_offsets[s]);
      if (sz > 0)
        fprintf(stderr, " %s %ld", vspace_names[s], sz);
    }
    fprintf(stderr, "\n");
  }

  bv_addr = (bv ? &BVIT(bv, size_vfasl_header + offset) : NULL);

  to_static = (S_vfasl_boot_mode > 0);

#ifdef AARCH64
  /* arm64 PIC (P2.2b/c): a GOT-bearing image bakes each pool adrp/ldr
     pair against the image layout (reproduced below) and truncates the
     in-object pool quads, so its reloc entries cannot be replayed later:
     it is only loadable straight to static with relocation dropped. */
  got_len = VSPACE_LENGTH(vspace_got);
  if ((got_len > 0) && (!to_static || S_G.retain_static_relocation))
    S_error_abort("vfasl: PIC GOT image requires boot-mode static load");
#endif

  {
  uint64_t phase_t0 = VFASL_PHASE_BEGIN();
  for (s = 0; s < vspaces_count; s++) {
    uptr sz = vspace_offsets[s+1] - vspace_offsets[s];
    if (sz > 0) {
      uint64_t sub_t0 = VFASL_PHASE_BEGIN();
      if (S_vfasl_source_is_permanent_mapping
          && !bv
          && stream
          && ((s == vspace_reloc) && to_static && !S_G.retain_static_relocation)
          && (((uptr)stream->next & (byte_alignment - 1)) == 0)
          && ((iptr)(stream->end - stream->next) >= (iptr)sz)) {
        /* zero-copy: the space stays in the mapping */
        vspaces[s] = TO_PTR(stream->next);
        stream->next += sz;
        VFASL_PHASE_END(sub_t0, vfasl_phase_room);
        continue;
      }
#ifdef AARCH64
      if ((s == vspace_code) && (got_len > 0)) {
        /* arm64 PIC (P2.2b/c): the writer bakes the adrp/ldr pairs from
           the image layout, so code+got must keep their image-relative
           distance and land congruent to their image offsets mod 4096.
           Zero-copy (P2.3, non-MAP_JIT platforms): both vspaces stay in
           the permanent boot mapping when the converter's alignment pad
           is in place; the mapping range is made writable+executable, the
           pages relink and the pointer sweep write get COW'd, and clean
           code pages stay shared with the file.  Otherwise: one code-space
           block at a congruent base (static and never swept; slot pointers
           stay valid because everything a boot image references is itself
           static), and relink_code fills the slots. */
        uptr code_to_got = vspace_offsets[vspace_got] - vspace_offsets[vspace_code];
        uptr span = code_to_got + got_len;
#ifdef VFASL_CODE_ZERO_COPY
        {
          static int zc_off = -1;
          if (zc_off < 0) zc_off = (getenv("PLT_VFASL_CODE_ZC") == NULL);
          if (getenv("PLT_VFASL_ZC_DEBUG"))
            fprintf(stderr, ";; zc? map=%d fd=%d bv=%d stream=%d align=%ld/%ld span-ok=%d\n",
                    S_vfasl_source_is_permanent_mapping, S_vfasl_mapping_fd,
                    (bv != (ptr)0), (stream != NULL),
                    stream ? (long)(((uptr)stream->next) & 4095) : -1,
                    (long)(vspace_offsets[vspace_code] & 4095),
                    stream ? ((iptr)(stream->end - stream->next) >= (iptr)span) : -1);
          if (!zc_off
              && S_vfasl_source_is_permanent_mapping && (S_vfasl_mapping_fd >= 0)
              && !bv && stream
              && ((((uptr)stream->next) & 4095) == (vspace_offsets[vspace_code] & 4095))
              && ((iptr)(stream->end - stream->next) >= (iptr)span)) {
            uptr pagesz = (uptr)getpagesize();
            uptr file_off = (uptr)stream->next - S_vfasl_mapping_base;
            uptr f0 = file_off & ~(pagesz - 1);
            uptr head = file_off - f0;
            uptr maplen = (head + span + (pagesz - 1)) & ~(pagesz - 1);
            ptr blk; uptr w;
            find_room(tc, space_code, (to_static ? static_generation : 0), type_untyped,
                      ptr_align(maplen + 2 * pagesz), blk);
            w = ((uptr)blk + (pagesz - 1)) & ~(pagesz - 1);
            /* failure (W^X policy, etc.) falls back to copying into the
               block just allocated -- congruence still holds below */
            if (mmap(TO_VOIDP(w), maplen, PROT_READ|PROT_WRITE|PROT_EXEC,
                     MAP_PRIVATE|MAP_FIXED, S_vfasl_mapping_fd, (off_t)f0) != MAP_FAILED) {
              zc_copy_dirty_extents(w, maplen, pagesz, f0, stream, vspace_offsets, got_len);
              vspaces[s] = TO_PTR(w + head);
              vspaces[vspace_got] = ptr_add(vspaces[s], code_to_got);
              stream->next += sz;
              code_in_mapping = 1;
              VFASL_PHASE_END(sub_t0, vfasl_phase_room);
              continue;
            }
            /* MAP_FAILED (W^X policy, etc.): fall through to the plain
               copying path below; the block just allocated is abandoned */
          }
        }
#endif
        {
          ptr blk;
          find_room(tc, space_code, (to_static ? static_generation : 0), type_untyped,
                    ptr_align(span + 2 * 4096), blk);
          vspaces[s] = TO_PTR(((((uptr)blk + 4095) & ~(uptr)4095)
                               + (vspace_offsets[vspace_code] & 4095)));
          vspaces[vspace_got] = ptr_add(vspaces[s], code_to_got);
        }
      } else if ((s == vspace_got) && (got_len > 0)) {
#ifdef VFASL_CODE_ZERO_COPY
        if (code_in_mapping) {
          /* the slots (carrying their markers) stay in the mapping too;
             relink resolves them in place and only those pages COW */
          stream->next += sz;
          VFASL_PHASE_END(sub_t0, vfasl_phase_room);
          continue;
        }
#endif
        /* placed with the code vspace above; fall through to fill it */
      } else
#endif
      if ((s == vspace_reloc) && to_static && !S_G.retain_static_relocation) {
        newspace_find_room(tc, type_untyped, sz, vspaces[s]);
      } else {
        find_room(tc, vspace_spaces[s], (to_static ? static_generation : 0), type_untyped, sz, vspaces[s]);
      }
      VFASL_PHASE_END(sub_t0, vfasl_phase_room);
      if (bv) {
        sub_t0 = VFASL_PHASE_BEGIN();
        memcpy(TO_VOIDP(vspaces[s]), bv_addr, sz);
        VFASL_PHASE_END(sub_t0, vfasl_phase_memcpy);
        bv_addr = TO_VOIDP(ptr_add(TO_PTR(bv_addr), sz));
      } else {
	ptr dest;
#ifdef CANNOT_READ_DIRECTLY_INTO_CODE
	/* optimization A: for the code space, use the temp only when the read
	   really needs it (fd-read into a JIT page).  If the source is a
	   permanent mapping with all `sz` bytes present, S_fasl_bytesin is a
	   plain memcpy and can target the code space directly. */
	if (((s == vspace_code)
#ifdef AARCH64
	     /* arm64 PIC (P2.2b): a co-allocated GOT sits in the same
	        (possibly MAP_JIT) code-space block, so a plain read()
	        cannot target it either */
	     || ((s == vspace_got) && (got_len > 0))
#endif
	     )
#if VFASL_CODE_DIRECT_FROM_MAPPING
	    && !(S_vfasl_source_is_permanent_mapping
	         && stream
	         && ((iptr)(stream->end - stream->next) >= (iptr)sz))
#endif
	    )
	  newspace_find_room(tc, type_untyped, sz, dest);
	else
	  dest = vspaces[s];
#else
	dest = vspaces[s];
#endif
        S_fasl_bytesin(TO_VOIDP(dest), sz, stream);
#ifdef CANNOT_READ_DIRECTLY_INTO_CODE
	if (dest != vspaces[s])
	  memcpy(TO_VOIDP(vspaces[s]), TO_VOIDP(dest), sz);
#endif
      }
    } else
      vspaces[s] = (ptr)0;
  }
  for (s = vspaces_count - 1; s--; ) {
    if (!vspaces[s])
      vspaces[s] = vspaces[s+1];
  }

  if (bv)
    table = TO_PTR(bv_addr);
  else {
    newspace_find_room(tc, type_untyped, ptr_align(VFASLHEADER_TABLE_SIZE(header)), table);
    S_fasl_bytesin(TO_VOIDP(table), VFASLHEADER_TABLE_SIZE(header), stream);
  }

  symrefs = TO_VOIDP(table);
  rtdrefs = TO_VOIDP(ptr_add(TO_PTR(symrefs), VFASLHEADER_SYMREF_COUNT(header) * sizeof(vfoff)));
  singletonrefs = TO_VOIDP(ptr_add(TO_PTR(rtdrefs), VFASLHEADER_RTDREF_COUNT(header) * sizeof(vfoff)));
  bm = TO_VOIDP(ptr_add(TO_PTR(singletonrefs), VFASLHEADER_SINGLETONREF_COUNT(header) * sizeof(vfoff)));
  bm_end = TO_VOIDP(ptr_add(TO_PTR(table), VFASLHEADER_TABLE_SIZE(header)));

#if 0
  printf("\n"
         "hdr  %ld\n"
         "syms %ld\n"
         "rtds %ld\n"
         "clos %ld\n"
         "code %ld\n"
         "rloc %ld\n"
         "data %ld\n"
         "othr %ld\n"
         "tabl %ld  symref %ld  rtdref %ld  sglref %ld\n",
         (uptr)size_vfasl_header,
         VSPACE_LENGTH(vspace_symbol),
         VSPACE_LENGTH(vspace_rtd),
         VSPACE_LENGTH(vspace_closure),
         VSPACE_LENGTH(vspace_code),
         VSPACE_LENGTH(vspace_reloc),
         VSPACE_LENGTH(vspace_data),
         (VSPACE_LENGTH(vspace_impure)
          + VSPACE_LENGTH(vspace_pure_typed)
          + VSPACE_LENGTH(vspace_impure_record)),
         VFASLHEADER_TABLE_SIZE(header),
         VFASLHEADER_SYMREF_COUNT(header) * sizeof(vfoff),
         VFASLHEADER_RTDREF_COUNT(header) * sizeof(vfoff),
         VFASLHEADER_SINGLETONREF_COUNT(header) * sizeof(vfoff));
#endif
    
  /* We have to convert an offset relative to the start of data in the
     vfasl format to an offset relative to an individual space, at
     least for target generations other than 0. Rely on the fact that
     the spaces and the references are both sorted. */
#define SPACE_OFFSET_DECLS                      \
  int s2 = 0;                                   \
  uptr offset2 = vspace_offsets[s2];            \
  uptr next_offset2 = vspace_offsets[s2+1]
#define INC_SPACE_OFFSET(off)                   \
  do {                                          \
    while ((off) >= next_offset2) {             \
      s2++;                                     \
      offset2 = next_offset2;                   \
      next_offset2 = vspace_offsets[s2+1];      \
    }                                           \
  } while (0)
#define SPACE_PTR(off) TO_VOIDP(ptr_add(vspaces[s2], (off) - offset2))

  VFASL_PHASE_END(phase_t0, vfasl_phase_copy);
  vfasl_writes_begin(vspaces, vspace_offsets);
  phase_t0 = VFASL_PHASE_BEGIN();

  /* Fix up pointers. The initial content has all pointers relative to
     the start of the data. Since the spaces of referenced pointers
     may be discontiguous, use `find_pointer_from_offset` to get each
     new pointer. */
  {
    SPACE_OFFSET_DECLS;
    uptr p_off = 0;
    int target_hint = 0;
    while (bm != bm_end) {
      octet m = *bm;
#     define MAYBE_FIXUP(i)                                             \
      if (m & (1 << i)) {                                               \
        ptr *p3;                                                        \
        INC_SPACE_OFFSET(p_off);                                        \
        p3 = SPACE_PTR(p_off);                                          \
        VFASL_MARK(p3); *p3 = find_pointer_from_offset((uptr)*p3, vspaces, vspace_offsets, &target_hint); \
      }                                                                 \
      p_off += sizeof(uptr);

      MAYBE_FIXUP(0);
      MAYBE_FIXUP(1);
      MAYBE_FIXUP(2);
      MAYBE_FIXUP(3);
      MAYBE_FIXUP(4);
      MAYBE_FIXUP(5);
      MAYBE_FIXUP(6);
      MAYBE_FIXUP(7);

#     undef MAYBE_FIXUP
      bm++;
    }
  }

  VFASL_PHASE_END(phase_t0, vfasl_phase_ptr_sweep);
  phase_t0 = VFASL_PHASE_BEGIN();

  /* Replace references to singletons like "" and #vu8().
     This needs to be before interning symbols, in case ""
     is a symbol name. */
  {
    SPACE_OFFSET_DECLS;
    vfoff i;
    for (i = 0; i < VFASLHEADER_SINGLETONREF_COUNT(header); i++) {
      uptr r_off;
      ptr *ref;
      uptr which;
      r_off = singletonrefs[i];
      INC_SPACE_OFFSET(r_off);
      ref = SPACE_PTR(r_off);
      VFASL_MARK(ref);
      which = UNFIX(*ref);
      /* externalref extension (fasl2): a data-position external literal
         rides the singletonref table with a high-index marker. */
      if (which >= VFASL_EXTERNAL_BASE)
        *ref = vfasl_external_ref(externals, which - VFASL_EXTERNAL_BASE);
      else
        *ref = lookup_singleton(which);
    }
  }

  VFASL_PHASE_END(phase_t0, vfasl_phase_singletons);
  phase_t0 = VFASL_PHASE_BEGIN();

  /* Intern symbols */
  {
    uptr in_seg_off = 0;
    ptr sym = TYPE(vspaces[vspace_symbol], type_symbol);
    ptr end_syms = TYPE(VSPACE_END(vspace_symbol), type_symbol);

    if (sym != end_syms) {
      tc_mutex_acquire();

      /* size the symbol table for this image's symbols up front (an
         upper bound: the space may include segment padding) */
      S_resize_oblist_for(VSPACE_LENGTH(vspace_symbol) / size_symbol);

      while (sym < end_syms) {
        ptr isym;
        IBOOL uninterned;

        /* Make sure we don't try to claim a symbol that crosses
           a segment boundary */
        if ((in_seg_off + size_symbol) > bytes_per_segment) {
          if (in_seg_off == bytes_per_segment) {
            in_seg_off = 0;
          } else {
            /* Back up, then round up to next segment */
            sym = ptr_add(ptr_subtract(sym, size_symbol),
                          (bytes_per_segment - (in_seg_off - size_symbol)));
            in_seg_off = 0;
          }
        }

        uninterned = (SYMPVAL(sym) == Sfalse);

        VFASL_MARK(TO_VOIDP(UNTYPE(sym, type_symbol)));
        INITSYMVAL(sym) = sunbound;
        INITSYMCODE(sym, S_G.nonprocedure_code);

#if 0
        S_prin1(sym); printf("\n");
#endif

        if (!uninterned) {
          isym = S_intern4(sym);
          if (isym != sym) {
            /* The symbol was already interned, so point to the existing one */
            VFASL_MARK(TO_VOIDP(UNTYPE(sym, type_symbol)));
            INITSYMVAL(sym) = isym;
            if (S_vfasl_boot_mode > 0) {
              IGEN gen = SegInfo(ptr_get_segment(isym))->generation;
              if (gen < static_generation) {
                printf("WARNING: vfasl symbol already interned, but at generation %d: %p ", gen, TO_VOIDP(isym));
                S_prin1(isym);
                printf("\n");
              }
            }
          }
        }

        sym = ptr_add(sym, size_symbol);
        in_seg_off += size_symbol;
      }

      tc_mutex_release();
    }
  }

  VFASL_PHASE_END(phase_t0, vfasl_phase_intern_syms);
  phase_t0 = VFASL_PHASE_BEGIN();

  /* Replace symbol references with interned references */
  {
    SPACE_OFFSET_DECLS;
    ptr syms = vspaces[vspace_symbol];
    vfoff i;
    for (i = 0; i < VFASLHEADER_SYMREF_COUNT(header); i++) {
      uptr p2_off, sym_pos;
      ptr *p2, sym, val;
      p2_off = symrefs[i];
      INC_SPACE_OFFSET(p2_off);
      p2 = SPACE_PTR(p2_off);
      sym_pos = UNFIX(*p2);
      sym = TYPE(ptr_add(syms, symbol_pos_to_offset(sym_pos)), type_symbol);
      if ((val = SYMVAL(sym)) != sunbound)
        sym = val;
      *p2 = sym;
    }
  }
  
  VFASL_PHASE_END(phase_t0, vfasl_phase_symrefs);
  phase_t0 = VFASL_PHASE_BEGIN();

  /* Intern rtds */
  if (VSPACE_LENGTH(vspace_rtd) > 0) {
    ptr rtd = TYPE(vspaces[vspace_rtd], type_typed_object);
    ptr rtd_end = TYPE(VSPACE_END(vspace_rtd), type_typed_object);
    
    /* first one corresponds to base_rtd */
    RECORDINSTTYPE(rtd) = S_G.base_rtd;
    RECORDDESCUID(rtd) = S_G.base_rtd;

    tc_mutex_acquire();

    while (1) {
      ptr new_rtd, meta_rtd, parent_rtd;

      rtd = ptr_add(rtd, size_record_inst(UNFIX(RECORDDESCSIZE(RECORDINSTTYPE(rtd)))));
      if (rtd == rtd_end)
        break;

      /* fixup type of rtd (where the type is usually base_rtd) */
      meta_rtd = RECORDINSTTYPE(rtd);
      if (!Ssymbolp(RECORDDESCUID(meta_rtd)))
        RECORDINSTTYPE(rtd) = RECORDDESCUID(meta_rtd);
 
      /* fixup parent before continuing, relying on parents being earlier in `rtd`s;
         we let the rest of the ancestor vector get fixed up later */
      parent_rtd = rtd_parent(rtd);
      if (parent_rtd != Sfalse) {
        ptr parent_uid = RECORDDESCUID(parent_rtd);
        if (!Ssymbolp(parent_uid)) {
          VFASL_MARK(TO_VOIDP(UNTYPE(rtd, type_typed_object)));
          rtd_parent(rtd) = parent_uid;
        }
      }

      new_rtd = rtd;
      if (S_fasl_intern_rtd(&new_rtd)) {
        if (new_rtd == rtd) {
          S_error1("vfasl", "incompatible record type ~s", RECORDDESCNAME(rtd));
        } else {
          /* Use the UID field to record already-interned replacement: */
          RECORDDESCUID(rtd) = new_rtd;
        }
      }
    }

    tc_mutex_release();
  }
  
  /* Replace rtd references to interned references */
  {
    SPACE_OFFSET_DECLS;
    vfoff i;
    for (i = 0; i < VFASLHEADER_RTDREF_COUNT(header); i++) {
      uptr r_off;
      ptr *ref, rtd, uid;
      r_off = rtdrefs[i];
      INC_SPACE_OFFSET(r_off);
      ref = SPACE_PTR(r_off);
      rtd = *ref;
      uid = RECORDDESCUID(rtd);
      if (!Ssymbolp(uid)) {
        /* uid is replacement interned rtd */
        VFASL_MARK(ref); *ref = uid;
      }
    }
  }

  VFASL_PHASE_END(phase_t0, vfasl_phase_rtds);
  phase_t0 = VFASL_PHASE_BEGIN();

  /* Fix code pointers on closures */
  {
    ptr cl = TYPE(vspaces[vspace_closure], type_closure);
    ptr end_closures = TYPE(VSPACE_END(vspace_closure), type_closure);
    uptr code_delta = (uptr)ptr_subtract(vspaces[vspace_code], vspace_offsets[vspace_code]);

    while (cl != end_closures) {
      ptr entry = CLOSENTRY(cl);

      /* externalref extension (fasl2): a runtime closure whose code is a
         boot-world code object carries a marker (>= VFASL_EXTERNAL_BASE) in
         its entry slot in place of a code-vspace offset.  Resolve it to the
         external code object (SETCLOSCODE re-adds code_data_disp); the normal
         case relocates the copied code by code_delta. */
      if ((uptr)entry >= VFASL_EXTERNAL_BASE) {
        ptr cod = vfasl_external_ref(externals, (uptr)entry - VFASL_EXTERNAL_BASE);
        VFASL_MARK(TO_VOIDP(UNTYPE(cl, type_closure)));
        SETCLOSCODE(cl, cod);
      } else {
        ptr code = CLOSCODE(cl);
        code = ptr_add(code, code_delta);

#if 0
        printf("%p ", code);
        S_prin1(CODENAME(code));
        printf("\n");
#endif

        VFASL_MARK(TO_VOIDP(UNTYPE(cl, type_closure)));
        SETCLOSCODE(cl,code);
      }
      cl = ptr_add(cl, size_closure(CLOSLEN(cl)));
    }
  }

  VFASL_PHASE_END(phase_t0, vfasl_phase_closures);
  phase_t0 = VFASL_PHASE_BEGIN();

  /* Fix code via relocations */
  {    
    ptr sym_base = vspaces[vspace_symbol];
    ptr code = TYPE(vspaces[vspace_code], type_typed_object);
    ptr code_end = TYPE(VSPACE_END(vspace_code), type_typed_object);
    S_record_code_mod(tc, (uptr)vspaces[vspace_code], (uptr)code_end - (uptr)code);
    while (code != code_end) {
      relink_code(code, sym_base, vspaces, vspace_offsets, to_static, externals);
      code = ptr_add(code, size_code(CODELEN(code)));
    }
  }

  VFASL_PHASE_END(phase_t0, vfasl_phase_relink);
  }
  vfasl_writes_end();

  /* Turn result offset into a value, unboxing if it's a box (which
     supports a symbol result, for example). */
  {
    ptr v;
    ITYPE t;
    int result_hint = 0;
    v = find_pointer_from_offset(VFASLHEADER_RESULT_OFFSET(header), vspaces, vspace_offsets, &result_hint);
    if (((t = TYPEBITS(v)) == type_typed_object)
        && TYPEP(TYPEFIELD(v), mask_box, type_box))
      v = Sunbox(v);

    return v;
  }
}

ptr S_vfasl_to(ptr bv)
{
  return S_vfasl(bv, NULL, 0, Sbytevector_length(bv), Sfalse);
}

/*************************************************************/
/* Code and relocation handling for save and load            */

#define VFASL_RELOC_C_ENTRY(p) (((uptr)(p) << vfasl_reloc_tag_bits) | vfasl_reloc_c_entry_tag)
#define VFASL_RELOC_LIBRARY_ENTRY(p) (((uptr)(p) << vfasl_reloc_tag_bits) | vfasl_reloc_library_entry_tag)
#define VFASL_RELOC_LIBRARY_ENTRY_CODE(p) (((uptr)(p) << vfasl_reloc_tag_bits) | vfasl_reloc_library_entry_code_tag)
#define VFASL_RELOC_SYMBOL(p) (((uptr)(p) << vfasl_reloc_tag_bits) | vfasl_reloc_symbol_tag)
#define VFASL_RELOC_SINGLETON(p) (((uptr)(p) << vfasl_reloc_tag_bits) | vfasl_reloc_singleton_tag)

#define VFASL_RELOC_TAG(p) (UNFIX(p) & ((1 << vfasl_reloc_tag_bits) - 1))
#define VFASL_RELOC_POS(p) (UNFIX(p) >> vfasl_reloc_tag_bits)

static void relink_code(ptr co, ptr sym_base, ptr *vspaces, uptr *vspace_offsets, IBOOL to_static, ptr externals) {
  int target_hint = 0;
    ptr t; iptr a, m, n;

    t = CODERELOC(co);
    t = ptr_add(vspaces[vspace_reloc], (uptr)t - vspace_offsets[vspace_reloc]);

    if (to_static && !S_G.retain_static_relocation) {
      if ((CODETYPE(co) & (code_flag_template << code_flags_offset)) == 0)
        CODERELOC(co) = (ptr)0;
      else {
        ptr tc = get_thread_context();
        iptr sz = size_reloc_table(RELOCSIZE(t));
        ptr new_t;
        find_room(tc, space_data, static_generation, type_untyped, ptr_align(sz), new_t);
        memcpy(TO_VOIDP(new_t), TO_VOIDP(t), sz);
        t = new_t;
        CODERELOC(co) = t;
        RELOCCODE(t) = co;
      }
    } else {
      CODERELOC(co) = t;
      RELOCCODE(t) = co;
    }

    m = RELOCSIZE(t);
    a = 0;
    n = 0;
    while (n < m) {
      uptr entry, item_off, code_off; ptr obj; I32 saved_off;
#ifdef AARCH64
      uptr *got_slot = NULL;
#endif

        entry = RELOCIT(t, n); n += 1;
        if (RELOC_EXTENDED_FORMAT(entry)) {
            item_off = RELOCIT(t, n); n += 1;
            code_off = RELOCIT(t, n); n += 1;
        } else {
            item_off = RELOC_ITEM_OFFSET(entry);
            code_off = RELOC_CODE_OFFSET(entry);
        }
#ifdef AARCH64
        if ((RELOC_TYPE(entry) == reloc_arm64_got)
            && ((vspace_offsets[vspace_got+1] - vspace_offsets[vspace_got]) > 0)
            && ((CODETYPE(co) & (code_flag_template << code_flags_offset)) == 0)) {
          /* arm64 PIC (P2.2c): the pool quad was truncated from the code
             object; this entry's code-offset field carries the absolute GOT
             byte offset of its (deduped) slot, and the slot holds the vfasl
             marker until resolved below and written back in place -- the
             code page is never touched.  Pool entries are the reloc table's
             suffix, so not advancing the `a` cursor disturbs nothing.  (A
             template code object keeps its pool in-object -- the writer
             skips it -- because S_instantiate_code_object replays the
             retained reloc table against the in-object quads.) */
          got_slot = TO_VOIDP(ptr_add(vspaces[vspace_got], code_off));
          obj = (ptr)*got_slot;
        } else {
#endif
        a += code_off;

        /* offset is stored in place of constant-loading code: */
        memcpy(&saved_off, TO_VOIDP((ptr)((uptr)co + a)), sizeof(I32));
        obj = (ptr)(iptr)saved_off;
#ifdef AARCH64
        }
#endif

        if (FIXMEDIATE(obj)) {
          if (Sfixnump(obj)) {
            int tag = VFASL_RELOC_TAG(obj);
            iptr pos = VFASL_RELOC_POS(obj);
            if (tag == vfasl_reloc_singleton_tag)
              /* externalref extension (fasl2): a data-position external
                 rides the singleton path with a high-index marker. */
              obj = ((uptr)pos >= VFASL_EXTERNAL_BASE)
                    ? vfasl_external_ref(externals, (uptr)pos - VFASL_EXTERNAL_BASE)
                    : lookup_singleton(pos);
            else if (tag == vfasl_reloc_c_entry_tag)
              obj = S_lookup_c_entry(pos);
            else if ((tag == vfasl_reloc_library_entry_tag)
                     || (tag == vfasl_reloc_library_entry_code_tag)) {
              obj = S_lookup_library_entry(pos, 1);
              if (tag == vfasl_reloc_library_entry_code_tag)
                obj = CLOSCODE(obj);
            } else if (tag == vfasl_reloc_symbol_tag) {
              ptr val;
              obj = TYPE(ptr_add(sym_base, symbol_pos_to_offset(pos)), type_symbol);
              if ((val = SYMVAL(obj)) != sunbound)
                obj = val;
#ifdef vfasl_reloc_external_tag
            } else if (tag == vfasl_reloc_external_tag) {
              /* externalref extension (fasl2): a code reloc referencing the
                 per-load externals vector at position pos.  Guarded by
                 #ifdef so the pb bootstrap kernel (upstream headers, no such
                 tag) still builds; pb never emits externalref. */
              obj = vfasl_external_ref(externals, pos);
#endif
            } else if (obj == FIX(0)) {
              /* leave as-is */
            } else {
              S_error_abort("vfasl: bad relocation tag");
            }
          } else {
            /* some other immediate, such as black-hole; leave as-is */
          }
        } else {
          uptr offset = (uptr)obj;

          obj = find_pointer_from_offset(offset, vspaces, vspace_offsets, &target_hint);
          if (TYPEBITS(obj) == type_typed_object) {
            ptr tf = TYPEFIELD(obj);
            if (TYPEP(tf, mask_record, type_record)) {
              while (1) {
                if (tf == S_G.base_rtd) {
                  /* Similar to symbols: potentially replace with interned */
                  ptr uid = RECORDDESCUID(obj);
                  if (!Ssymbolp(uid)) {
                    /* "uid" is actually the interned rtd to use instead */
                    obj = uid;
                  }
                  break;
                }
                tf = rtd_parent(tf);
                if (tf == Sfalse)
                  break;
              }
            }
          }
        }

#ifdef AARCH64
        if (got_slot) {
          *got_slot = (uptr)obj + item_off;
          VFASL_MARK(got_slot);
          continue;
        }
#endif
        VFASL_MARK(TO_VOIDP((uptr)UNTYPE(co, type_typed_object) + a));
        S_set_code_obj("vfasl", RELOC_TYPE(entry), co, a, obj, item_off);
    }
}

static ptr find_pointer_from_offset(uptr p_off, ptr *vspaces, uptr *vspace_offsets, int *hint)
{
  int s = *hint;
  ITYPE t = TYPEBITS(p_off);

  p_off = (uptr)UNTYPE(p_off, t);
  /* references cluster by target space, so first try where the
     previous reference landed */
  if ((p_off < vspace_offsets[s]) || (p_off >= vspace_offsets[s+1])) {
    s = 0;
    while (p_off >= vspace_offsets[s+1])
      s++;
    *hint = s;
  }

  return TYPE(ptr_add(vspaces[s], p_off - vspace_offsets[s]), t);
}

/*************************************************************/
/* Singletons, such as ""                                    */

/* This array needs to be in the same order as the enumeration in "cmacros.ss" */
static ptr *singleton_refs[] = { &S_G.null_string,
                                 &S_G.null_vector,
                                 &S_G.null_fxvector,
                                 &S_G.null_flvector,
                                 &S_G.null_bytevector,
                                 &S_G.null_immutable_string,
                                 &S_G.null_immutable_vector,
                                 &S_G.null_immutable_bytevector,
                                 &S_G.eqp,
                                 &S_G.eqvp,
                                 &S_G.equalp,
                                 &S_G.symboleqp,
                                 &S_G.symbol_symbol,
                                 &S_G.symbol_ht_rtd,
                                 /* fasl2 eq-hashtable imaging (order matches
                                    the singleton enum tail in "cmacros.ss") */
                                 &S_G.eq_symbol,
                                 &S_G.eq_ht_rtd };

static ptr lookup_singleton(iptr which) {
  ptr v;

  v = *(singleton_refs[which-1]);

  if (v == Sfalse) {
    if (which == singleton_symbol_ht_rtd) {
      S_G.symbol_ht_rtd = SYMVAL(S_intern((const unsigned char *)"$symbol-ht-rtd"));
      if (!Srecordp(S_G.symbol_ht_rtd)) S_error_abort("$symbol-ht-rtd has not been set");
    } else if (which == singleton_eq) {
      S_G.eqp = SYMVAL(S_intern((const unsigned char *)"eq?"));
      if (!Sprocedurep(S_G.eqp)) S_error_abort("eq? has not been set");
    } else if (singleton_refs[which-1] == &S_G.eq_ht_rtd) {
      /* fasl2 eq-hashtable imaging: same lazy bind as $symbol-ht-rtd above.
         Match on the ref slot rather than a named singleton_eq_ht_rtd macro so
         the pb bootstrap (which compiles this file against a checked-in
         equates.h that predates the new singleton) still builds; the enum
         value only needs to exist on the Scheme side, which is compiled from
         the current cmacros.ss.  (singleton_eq_symbol needs no lazy init:
         S_G.eq_symbol is interned at fasl startup, so its ref is non-false.) */
      S_G.eq_ht_rtd = SYMVAL(S_intern((const unsigned char *)"$eq-ht-rtd"));
      if (!Srecordp(S_G.eq_ht_rtd)) S_error_abort("$eq-ht-rtd has not been set");
    } else
      S_error_abort("vfasl: singleton not ready");
    v = *(singleton_refs[which-1]);
  }

  return v;
}  
