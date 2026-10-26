/* intern.c
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

/* locally defined functions */
static void oblist_insert(ptr sym, iptr idx, IGEN g);
static iptr hash(const unsigned char *s, iptr n);
static iptr hash_sc(const string_char *s, iptr n);
static iptr hash_uname(const string_char *s, iptr n);
static ptr mkstring(const string_char *s, iptr n);

#define OBINDEX(hc, len) ((hc) & ((len) - 1))
#define MIN_OBLIST_LENGTH 4096

void S_intern_init(void) {
    IGEN g;

    if (!S_boot_time) return;

    S_G.oblist_length = MIN_OBLIST_LENGTH;
    S_G.oblist_count = 0;
    S_G.oblist = S_getmem(S_G.oblist_length * sizeof(bucket *), 1, 0);
    for (g = 0; g < static_generation; g += 1) S_G.buckets_of_generation[g] = NULL;
}

static void oblist_insert(ptr sym, iptr idx, IGEN g) {
  ptr tc = get_thread_context();
  bucket *b, *oldb, **pb;

  find_room_voidp(tc, g == 0 ? space_new : space_data, g, ptr_align(sizeof(bucket)), b);
  b->sym = sym;
  if (g == 0) {
    b->next = S_G.oblist[idx];
    S_G.oblist[idx] = b;
  } else {
    for (pb = &S_G.oblist[idx]; (oldb = *pb) != NULL && SegmentGeneration(addr_get_segment(TO_PTR(oldb))) < g; pb = &oldb->next);
    b->next = oldb;
    *pb = b;
  }

  if (g != static_generation) {
    bucket_list *bl;
    find_room_voidp(tc, g == 0 ? space_new : space_data, g, ptr_align(sizeof(bucket_list)), bl);
    bl->car = b;
    bl->cdr = S_G.buckets_of_generation[g];
    S_G.buckets_of_generation[g] = bl;
  }

  S_G.oblist_count += 1;
}

static iptr oblist_length_for(iptr count) {
  iptr new_oblist_length = MIN_OBLIST_LENGTH;
  while ((new_oblist_length >> 1) < count)
    new_oblist_length <<= 1;
  return new_oblist_length;
}

static void resize_oblist_to(iptr new_oblist_length);

void S_resize_oblist(void) {
  iptr new_oblist_length = oblist_length_for(S_G.oblist_count);

  if (new_oblist_length == S_G.oblist_length)
    return;

  resize_oblist_to(new_oblist_length);
}

/* Grow the table ahead of interning `count` more symbols. The table
   otherwise grows only after a collection, so the tens of thousands of
   symbols of a boot image would all go through the initial 4096
   buckets. */
void S_resize_oblist_for(iptr count) {
  iptr new_oblist_length = oblist_length_for(S_G.oblist_count + count);

  if (new_oblist_length > S_G.oblist_length)
    resize_oblist_to(new_oblist_length);
}

static void resize_oblist_to(iptr new_oblist_length) {
  bucket **new_oblist, *b, *oldb, **pb, *bnext;
  iptr i, idx;
  ptr sym;
  IGEN g;

  new_oblist = S_getmem(new_oblist_length * sizeof(bucket *), 1, 0);

  for (i = 0; i < S_G.oblist_length; i += 1) {
    for (b = S_G.oblist[i]; b != NULL; b = bnext) {
      bnext = b->next;
      sym = b->sym;
      idx = OBINDEX(UNFIX(SYMHASH(sym)), new_oblist_length);
      g = GENERATION(sym);

      for (pb = &new_oblist[idx];
           (oldb = *pb) != NULL && SegmentGeneration(addr_get_segment(TO_PTR(oldb))) < g;
           pb = &oldb->next);
      b->next = oldb;
      *pb = b;
    }
  }

  S_freemem(S_G.oblist, S_G.oblist_length * sizeof(bucket *), 0);
  S_G.bytesof[static_generation][countof_oblist] += (new_oblist_length - S_G.oblist_length) * sizeof(bucket *);

  S_G.oblist_length = new_oblist_length;
  S_G.oblist = new_oblist;
}

#define MIX_HASH(hc) SYM_HASH_MIX(hc)

#define SYM_HASH_LOOP(uptr, iptr, extract, mask)  {     \
    uptr h = SYM_HASH_INIT(n);                          \
    while (n--) { h += extract(*s++); MIX_HASH(h); }    \
    return (iptr)h & mask;                              \
  }

#define identity_extract(x) x

static iptr hash(const unsigned char *s, iptr n) {
  SYM_HASH_LOOP(uptr, iptr, identity_extract, most_positive_fixnum);
}

static iptr hash_sc(const string_char *s, iptr n) {
  SYM_HASH_LOOP(uptr, iptr, Schar_value, most_positive_fixnum);
}

static iptr hash_uname(const string_char *s, iptr n) {
  return hash_sc(s, n);
}

/* on any platform, computes the value that is computed on a 32-bit platform,
   but needs to be `bitwise-and`ed with most_positive_fixnum */
I32 S_symbol_hash32(ptr str) {
  const string_char *s = &STRIT(str, 0); iptr n = Sstring_length(str);
  SYM_HASH_LOOP(U32, I32, Schar_value, (I32)-1);
}

/* like S_symbol_hash32 for the value that is computed on a 64-bit platform */
I64 S_symbol_hash64(ptr str) {
  const string_char *s = &STRIT(str, 0); iptr n = Sstring_length(str);
  SYM_HASH_LOOP(U64, I64, Schar_value, (U64)-1);
}

static ptr mkstring(const string_char *s, iptr n) {
  if (n == 0) {
    return S_G.null_immutable_string;
  } else {
    iptr i;
    ptr str = S_string(NULL, n);
    for (i = 0; i != n; i += 1) STRIT(str, i) = s[i];
    STRTYPE(str) |= string_immutable_flag;
    return str;
  }
}

ptr S_mkstring(const string_char *s, iptr n) {
  return mkstring(s, n);
}

/* handles single-byte characters, implicit length */
ptr S_intern(const unsigned char *s) {
  iptr n = strlen((const char *)s);
  iptr hc = hash(s, n);
  iptr idx = OBINDEX(hc, S_G.oblist_length);
  ptr sym, str;
  bucket *b;

  tc_mutex_acquire();

  b = S_G.oblist[idx];
  while (b != NULL) {
    sym = b->sym;
    if (!GENSYMP(sym)) {
       ptr str = SYMNAME(sym);
       if (Sstring_length(str) == n) {
          iptr i;
          for (i = 0; ; i += 1) {
            if (i == n) {
               tc_mutex_release();
               return sym;
            }
            if (Sstring_ref(str, i) != s[i]) break;
          }
       }
    }
    b = b->next;
  }

  str = S_string((const char *)s, n);
  STRTYPE(str) |= string_immutable_flag;

  sym = S_symbol(str);
  INITSYMHASH(sym) = FIX(hc);
  oblist_insert(sym, idx, 0);

  tc_mutex_release();
  return sym;
}

/* handles string_chars, explicit length */
ptr S_intern_sc(const string_char *name, iptr n, ptr name_str) {
  return S_intern_sc_hc(name, n, hash_sc(name, n), name_str);
}

/* `hc` is the symbol-name hash of `name`, as `hash_sc` computes it */
ptr S_intern_sc_hc(const string_char *name, iptr n, iptr hc, ptr name_str) {
  iptr idx = OBINDEX(hc, S_G.oblist_length);
  ptr sym;
  bucket *b;

  tc_mutex_acquire();

  b = S_G.oblist[idx];
  while (b != NULL) {
    sym = b->sym;
    if (!GENSYMP(sym)) {
       ptr str = SYMNAME(sym);
       if (Sstring_length(str) == n) {
          iptr i;
          for (i = 0; ; i += 1) {
            if (i == n) {
               tc_mutex_release();
               return sym;
            }
            if (STRIT(str, i) != name[i]) break;
          }
       }
    }
    b = b->next;
  }

  if ((name_str == Sfalse) || !(STRTYPE(name_str) & string_immutable_flag))
    name_str = mkstring(name, n);
  sym = S_symbol(name_str);
  INITSYMHASH(sym) = FIX(hc);
  oblist_insert(sym, idx, 0);

  tc_mutex_release();
  return sym;
}

ptr S_intern3(const string_char *pname, iptr plen, const string_char *uname, iptr ulen, ptr pname_str, ptr uname_str) {
  return S_intern3_hc(pname, plen, uname, ulen, hash_uname(uname, ulen), pname_str, uname_str);
}

/* `hc` is the symbol-name hash of `uname`, as `hash_uname` computes it */
ptr S_intern3_hc(const string_char *pname, iptr plen, const string_char *uname, iptr ulen, iptr hc, ptr pname_str, ptr uname_str) {
  iptr idx = OBINDEX(hc, S_G.oblist_length);
  ptr sym;
  bucket *b;

  tc_mutex_acquire();

  b = S_G.oblist[idx];
  while (b != NULL) {
    sym = b->sym;
    if (GENSYMP(sym)) {
       ptr str = Scar(SYMNAME(sym));
       if (Sstring_length(str) == ulen) {
          iptr i;
          for (i = 0; ; i += 1) {
            if (i == ulen) {
               tc_mutex_release();
               return sym;
            }
            if (STRIT(str, i) != uname[i]) break;
          }
       }
    }
    b = b->next;
  }

  if ((pname_str == Sfalse) || !(STRTYPE(pname_str) & string_immutable_flag))
    pname_str = mkstring(pname, plen);
  if ((uname_str == Sfalse)  || !(STRTYPE(uname_str) & string_immutable_flag))
    uname_str = mkstring(uname, ulen);
  sym = S_symbol(Scons(uname_str, pname_str));
  INITSYMHASH(sym) = FIX(hc);
  oblist_insert(sym, idx, 0);

  tc_mutex_release();
  return sym;
}

void S_intern_gensym(ptr sym, ptr sym_name) {
  ptr uname_str = Scar(sym_name);
  const string_char *uname = &STRIT(uname_str, 0);
  iptr ulen = Sstring_length(uname_str);
  iptr hc = hash_uname(uname, ulen);
  iptr idx = OBINDEX(hc, S_G.oblist_length);
  bucket *b;

  tc_mutex_acquire();

  b = S_G.oblist[idx];
  while (b != NULL) {
    ptr x = b->sym;
    if (GENSYMP(x)) {
       ptr str = Scar(SYMNAME(x));
       if (Sstring_length(str) == ulen) {
          iptr i;
          for (i = 0; ; i += 1) {
            if (i == ulen) {
               tc_mutex_release();
               S_error1("intern-gensym", "unique name ~s already interned", uname_str);
            }
            if (STRIT(str, i) != uname[i]) break;
          }
       }
    }
    b = b->next;
  }

  SETSYMNAME(sym, sym_name);
  INITSYMHASH(sym) = FIX(hc);
  oblist_insert(sym, idx, GENERATION(sym));

  tc_mutex_release();
}

/* must hold mutex */
ptr S_intern4(ptr sym) {
  ptr name = SYMNAME(sym);
  ptr hash = SYMHASH(sym);
  iptr hc = UNFIX(hash);
  iptr idx = OBINDEX(hc, S_G.oblist_length);
  bucket *b;

  /* Compare hashes before names: the name strings live elsewhere in
     memory, and most of the symbols a boot image interns have no
     bucket to compare with at all, so do not touch the names unless a
     bucket's hash matches (a symbol whose hash is not a fixnum is
     compared by name regardless). */
  b = S_G.oblist[idx];
  while (b != NULL) {
    ptr x = b->sym;
    ptr x_hash = SYMHASH(x);
    if ((x_hash == hash) || !Sfixnump(x_hash)) {
      ptr x_name = SYMNAME(x);
      if (Sstringp(name) == Sstringp(x_name)) {
        ptr uname_str = (Sstringp(name) ? name : Scar(name));
        ptr str = (Sstringp(x_name) ? x_name : Scar(x_name));
        iptr ulen = Sstring_length(uname_str);
        if (Sstring_length(str) == ulen) {
          const string_char *uname = &STRIT(uname_str, 0);
          iptr i;
          for (i = 0; ; i += 1) {
            if (i == ulen) {
              return x;
            }
            if (STRIT(str, i) != uname[i]) break;
          }
        }
      }
    }
    b = b->next;
  }

  oblist_insert(sym, idx, GENERATION(sym));

  return sym;
}

/* retrofit existing symbols once nonprocedure_code is available */
void S_retrofit_nonprocedure_code(void) {
  ptr npc, sym, val; bucket_list *bl;

  npc = S_G.nonprocedure_code;

  /* assuming this happens early, before collector has been called, so need look only for generation 0 symbols */
  for (bl = S_G.buckets_of_generation[0]; bl != NULL; bl = bl->cdr) {
    sym = bl->car->sym;
    val = SYMVAL(sym);
    SETSYMCODE(sym, Sprocedurep(val) ? CLOSCODE(val) : npc);
  }
}
