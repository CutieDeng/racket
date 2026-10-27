# Route 2: vfasl imaging of eq-hashtables (design spec)

## Goal
Let vfasl image an `eq-hashtable` into the static generation, preserving its
type (so `eq-hashtable?` stays true and rumble's `eq-hashtable-ref` fast path
works). Needed so the instantiated-namespace state can travel to static memory
without externalizing + rebuilding the ~947 module/instance hash tables.

## Why it is not trivial
- `eq_hash` (segment.h:78) is purely address-based: `(iptr)key >> primary_type_bits`
  then bit-mixing. It does NOT use a symbol's stored hash.
- vfasl runs at build/convert time; the image loads in a different process whose
  boot symbols (the keys) sit at different (ASLR'd) addresses. So any bucket
  index vfasl computes at convert time is stale at load.
- eq-hashtable entries are TLCs (top-level cells: keyval/ht/next; type-tlc).
  The GC re-buckets a TLC only when its key *relocates* during collection
  (gc.c:1737, `tlcs_to_rehash`). Static-generation objects never relocate, so a
  statically-imaged eq-hashtable is never auto-rehashed.
- No Scheme-callable in-place rehash exists.

Conclusion: imaging the structure is necessary but not sufficient; the loader
must re-bucket every imaged eq-hashtable's TLCs with load-time `eq_hash`.

## The eq-hashtable layout (from fasl.c:971-1016)
- record rtd `$eq-ht-rtd`; fields: type(=symbol `eq`), mutable?, subtype
  (normal/weak/ephemeron), minlen, vec (bucket vector), size.
- bucket vector length `veclen`; empty bucket slot holds sentinel `FIX(idx)`.
- each entry is `S_tlc(keyval=(k . v), ht, next)`, chained per bucket, chain
  terminated by the `FIX(idx)` sentinel.
- bucket index at load = `eq_hash(key) & (veclen-1)`.

## fasl encoding (strip-types.ss:23)
`(eq-hashtable mutable? subtype minlen veclen vpfasl)` where vpfasl is a vector
of (k . v) pairs. (Symbol-hashtable is the sibling case vfasl.ss:903 already
handles by recomputing buckets via the STABLE target-symbol-hash.)

## The five coordinated changes
1. cmacros.ss: add singletons `singleton-eq-ht-rtd`, `singleton-eq-symbol`
   (after `singleton-symbol-ht-rtd`); add an `eqhtref-count` slot + offset
   array to the vfasl header (mirror singletonref-count).
2. vfasl.c `singleton_refs[]`: append `&S_G.eq_ht_rtd`, `&S_G.eq_symbol`;
   `lookup_singleton` lazy-init them (`$eq-ht-rtd`, symbol `eq`) like
   `$symbol-ht-rtd`.
3. vfasl.ss do-copy: add an `(eq-hashtable mutable? subtype minlen veclen vpfasl)`
   case that builds the eq-ht record (rtd = singleton-eq-ht-rtd, type =
   singleton-eq-symbol, mutable?, subtype, minlen, size, vec) + a bucket vector
   + one TLC per entry, all chained into ONE bucket (index 0) with the terminal
   `FIX(0)` sentinel (placement is provisional; the loader re-buckets). Record
   the eq-ht image offset into the header's eqhtref list.
4. vfasl.c load: after the singleton/symbol/rtd passes, iterate the eqhtref
   list and re-bucket each eq-hashtable's TLCs with load-time `eq_hash` — a new
   `rehash_imaged_eq_hashtable(ht)` that walks every bucket chain, recomputes
   `eq_hash(key) & (veclen-1)`, and rebuilds the chains + terminal sentinels.
   (Full-table variant of gc.c:1737.)
5. Producer imageable?: allow eq-hashtables (image inline) instead of
   externalizing them.

## Validation
Round-trip a standalone symbol-keyed eq-hashtable: image → vfasl-convert →
load → verify `eq-hashtable?`, `hashtable-size`, and `hashtable-ref` on every
key return the imaged values (proves the loader rehash produced correct
buckets). Then the boot build must remain byte-identical on the normal path
(the new do-copy case only fires for eq-hashtables, which compiler fasls never
contain).

## Status
Design complete. Implementation is ~150-200 lines across cmacros.ss / vfasl.ss
/ vfasl.c plus the vfasl header format, with rebuild+test cycles (make cs).
