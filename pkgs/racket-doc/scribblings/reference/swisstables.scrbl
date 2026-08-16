#lang scribble/doc
@(require "mz.rkt"
          (for-label racket/swisstable
                     racket/dict))

@(define swiss-eval (make-base-eval))
@(swiss-eval '(require racket/swisstable))

@title[#:tag "swisstables"]{Swisstables}

A @deftech{swisstable} is a mutable hash table with an open-addressing
``SwissTable'' representation: a flat control-byte array plus a flat
slot array, probed in small groups. Compared to the standard mutable
@tech{hash tables}, a swisstable stores all entries in two flat
arrays, so lookups avoid pointer chasing, and a one-byte hash
fragment per slot filters out almost all non-matching keys before any
full key comparison happens. The representation particularly benefits
tables with @racket[equal?]-based keys whose comparison is expensive
(strings, lists, nested data), and read-heavy workloads.

A swisstable holds its keys and values strongly by default; weak and
@tech{ephemeron} variants are also available. A weak swisstable
refers to its keys weakly while holding values strongly, so a value
that refers back to its key retains the entry; an ephemeron
swisstable additionally drops the value as soon as the key becomes
unreachable, so key-to-value reference cycles do not prevent
collection. An entry whose key has been collected disappears from
counting and iteration no later than the next counting,
iteration-starting, or mutating operation on the table. Keys are
compared with @racket[equal?], @racket[eqv?], or @racket[eq?],
depending on the constructor used.
A swisstable can be used directly as a two-valued @tech{sequence}
(or via @racket[in-swisstable]), where each iteration produces a key
and a value. Two swisstables are @racket[equal?] when they have the
same key-comparison mode, the same key-retention mode, and
@racket[equal?] keys mapped to @racket[equal?] values; swisstables
are hashable accordingly, so they can serve as keys of
@racket[equal?]-based tables. A swisstable is not a @tech{hash
table} in the sense of @racket[hash?], and it cannot be used with
@racketidfont{hash-} operations.

Swisstables are @emph{not} safe for concurrent access from multiple
@tech{threads}: concurrent reads are harmless, but a mutation that is
interleaved with other operations on the same table can leave the
table in an inconsistent (though still memory-safe) state. Guard
shared tables with a @tech{semaphore} when needed. Iteration order is
unspecified and can change after any insertion or removal.

A swisstable is a @tech{dictionary}: it supports the complete
@racketmodname[racket/dict] interface (@racket[dict-ref],
@racket[dict-set!], @racket[in-dict], @racket[dict-map], and so on),
so it can be dropped into dict-generic code as a faster alternative
to a mutable hash table. Generic @racketidfont{dict-} operations
dispatch dynamically; performance-sensitive code should prefer the
direct @racketidfont{swisstable-} operations.

On the CS runtime, swisstables are implemented by runtime-core
primitives; on other runtimes, a functionally identical pure-Racket
implementation is used. See
@racket[swisstable-runtime-adapter-backend]. The standard mutable
@tech{hash tables} keep their own implementation, so using this
library never changes the performance characteristics of existing
code.

@note-lib[racket/swisstable #:use-sources (racket/swisstable)]

@examples[
#:eval swiss-eval
(define st (make-swisstable))
(swisstable-set! st "apple" 1)
(swisstable-set! st (list 1 2 3) 'listy)
(swisstable-ref st "apple")
(swisstable-ref st (list 1 2 3))
(swisstable-count st)
(swisstable-remove! st "apple")
(for/list ([(k v) (in-swisstable st)]) (cons k v))
]

@defproc[(make-swisstable [expected-count exact-nonnegative-integer? 0])
         swisstable?]{

Creates an empty swisstable that compares keys with @racket[equal?].
When @racket[expected-count] is positive, the table is pre-sized so
that @racket[expected-count] insertions do not force a resize.}

@defproc[(make-swisstable-eqv [expected-count exact-nonnegative-integer? 0])
         swisstable?]{

Like @racket[make-swisstable], but compares keys with @racket[eqv?].}

@defproc[(make-swisstable-eq [expected-count exact-nonnegative-integer? 0])
         swisstable?]{

Like @racket[make-swisstable], but compares keys with @racket[eq?].}

@deftogether[(
@defproc[(make-swisstable-weak [expected-count exact-nonnegative-integer? 0])
         swisstable?]
@defproc[(make-swisstable-weak-eqv [expected-count exact-nonnegative-integer? 0])
         swisstable?]
@defproc[(make-swisstable-weak-eq [expected-count exact-nonnegative-integer? 0])
         swisstable?]
)]{

Like the corresponding strong constructors, but the table refers to
its keys weakly: an entry whose key becomes otherwise unreachable is
removed. Values are held strongly until the entry is removed, so a
value that refers to its own key keeps the entry alive; use an
ephemeron swisstable to avoid that. Weak references to values that
are not allocated objects (fixnums, characters) never go away.}

@deftogether[(
@defproc[(make-swisstable-ephemeron [expected-count exact-nonnegative-integer? 0])
         swisstable?]
@defproc[(make-swisstable-ephemeron-eqv [expected-count exact-nonnegative-integer? 0])
         swisstable?]
@defproc[(make-swisstable-ephemeron-eq [expected-count exact-nonnegative-integer? 0])
         swisstable?]
)]{

Like the weak constructors, but the value of an entry is retained
only while its key is reachable, so key-to-value reference cycles do
not prevent collection and values are released promptly when their
keys die.}

@defproc[(swisstable-weakness [st swisstable?])
         (or/c 'strong 'weak 'ephemeron)]{

Reports the key-retention mode of @racket[st].}

@defproc[(swisstable? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[v] is a swisstable, @racket[#f]
otherwise.}

@defproc[(swisstable-kind [st swisstable?]) (or/c 'equal 'eqv 'eq)]{

Reports the key-comparison mode of @racket[st].}

@defproc[(swisstable-count [st swisstable?]) exact-nonnegative-integer?]{

Returns the number of entries in @racket[st]. This operation takes
constant time.}

@defproc[(swisstable-empty? [st swisstable?]) boolean?]{

Equivalent to @racket[(zero? (swisstable-count st))].}

@defproc[(swisstable-ref [st swisstable?]
                         [key any/c]
                         [failure-result failure-result/c
                                         (lambda ()
                                           (raise
                                            (exn:fail:contract ....)))])
         any]{

Returns the value mapped to @racket[key] in @racket[st]. If no such
entry exists, then @racket[failure-result] determines the result: if
it is a procedure of no arguments, it is called and its result
returned, otherwise @racket[failure-result] itself is returned. When
@racket[failure-result] is not supplied, an absent key raises
@racket[exn:fail:contract].}

@defproc[(swisstable-ref! [st swisstable?]
                          [key any/c]
                          [to-set failure-result/c])
         any]{

Like @racket[swisstable-ref], but when no entry exists for
@racket[key], the value produced by @racket[to-set] is first installed
in @racket[st] and then returned.}

@defproc[(swisstable-has-key? [st swisstable?] [key any/c]) boolean?]{

Returns @racket[#t] if @racket[st] has an entry for @racket[key],
@racket[#f] otherwise.}

@defproc[(swisstable-set! [st swisstable?] [key any/c] [v any/c]) void?]{

Maps @racket[key] to @racket[v] in @racket[st], replacing any existing
mapping for @racket[key].}

@defproc[(swisstable-remove! [st swisstable?] [key any/c]) boolean?]{

Removes the entry for @racket[key] in @racket[st]. Returns
@racket[#t] when an entry was removed, @racket[#f] when @racket[st]
had no entry for @racket[key].}

@defproc[(swisstable-update! [st swisstable?]
                             [key any/c]
                             [updater (any/c . -> . any/c)]
                             [failure-result failure-result/c
                                             (lambda ()
                                               (raise
                                                (exn:fail:contract ....)))])
         void?]{

Composes @racket[swisstable-ref] and @racket[swisstable-set!]:
applies @racket[updater] to the current value for @racket[key] (or to
the value that @racket[failure-result] determines, when no entry
exists) and installs the result.}

@defproc[(swisstable-clear! [st swisstable?]) void?]{

Removes all entries from @racket[st], keeping its current capacity.}

@defproc[(swisstable-copy [st swisstable?]) swisstable?]{

Returns a new swisstable with the same key-comparison mode and the
same entries as @racket[st].}

@deftogether[(
@defproc[(swisstable->list [st swisstable?]) (listof pair?)]
@defproc[(swisstable-keys [st swisstable?]) list?]
@defproc[(swisstable-values [st swisstable?]) list?]
)]{

Return the entries of @racket[st] as a list of key--value pairs, the
keys, or the values, respectively, in an unspecified order.}

@deftogether[(
@defproc[(swisstable-for-each [st swisstable?]
                              [proc (any/c any/c . -> . any)])
         void?]
@defproc[(swisstable-map [st swisstable?]
                         [proc (any/c any/c . -> . any/c)])
         list?]
)]{

Apply @racket[proc] to each key and value of @racket[st], in an
unspecified order. @racket[swisstable-map] returns the list of
results.}

@deftogether[(
@defproc[(in-swisstable [st swisstable?]) sequence?]
@defproc[(in-swisstable-keys [st swisstable?]) sequence?]
@defproc[(in-swisstable-values [st swisstable?]) sequence?]
)]{

Return a sequence over the entries of @racket[st]:
@racket[in-swisstable] produces a key and a value per iteration, the
other two produce keys or values only. The table must not be mutated
while the sequence is being traversed; otherwise elements may be
skipped or visited twice.}

@deftogether[(
@defform[(for/swisstable (for-clause ...) body-or-break ... body)]
@defform[(for*/swisstable (for-clause ...) body-or-break ... body)]
)]{

Like @racket[for/hash] and @racket[for*/hash], but produce a mutable
swisstable with @racket[equal?]-based keys: the last @racket[body]
must produce two values, a key and a value.}

@defproc[(swisstable->hash [st swisstable?]) hash?]{

Returns a new mutable @tech{hash table} with the same key-comparison
mode, key-retention mode, and entries as @racket[st].}

@defproc[(hash->swisstable [h hash?]) swisstable?]{

Returns a new swisstable with the same key-comparison mode,
key-retention mode, and entries as @racket[h]. Immutable hash tables
convert to strong swisstables. An @racket[equal-always?]-based hash
table is not supported and triggers an @racket[exn:fail:contract]
error.}

@deftogether[(
@defproc[(swisstable-iterate-first [st swisstable?])
         (or/c exact-nonnegative-integer? #f)]
@defproc[(swisstable-iterate-next [st swisstable?]
                                  [pos exact-nonnegative-integer?])
         (or/c exact-nonnegative-integer? #f)]
@defproc[(swisstable-iterate-key [st swisstable?]
                                 [pos exact-nonnegative-integer?])
         any/c]
@defproc[(swisstable-iterate-value [st swisstable?]
                                   [pos exact-nonnegative-integer?])
         any/c]
@defproc[(swisstable-iterate-key+value [st swisstable?]
                                       [pos exact-nonnegative-integer?])
         (values any/c any/c)]
)]{

Low-level iteration over @racket[st], analogous to
@racket[hash-iterate-first] and company. A position is an index into
the table's slot array; any insertion or removal can invalidate
positions. The @racketidfont{-key}, @racketidfont{-value}, and
@racketidfont{-key+value} accessors raise @racket[exn:fail:contract]
when @racket[pos] does not refer to an occupied slot.}

@defproc[(swisstable-stats [st swisstable?])
         (vector/c (or/c 'equal 'eqv 'eq)
                   exact-nonnegative-integer?
                   exact-nonnegative-integer?
                   exact-nonnegative-integer?
                   (or/c 'strong 'weak 'ephemeron))]{

Returns implementation statistics for @racket[st] as a vector of the
key-comparison mode, the current slot capacity, the entry count, the
current number of tombstone slots, and the key-retention mode.
Intended for testing and performance analysis; the precise values
are implementation-specific.}

@deftogether[(
@defproc[(swisstable-runtime-adapter-backend) (or/c 'cs-core 'racket)]
@defproc[(swisstable-runtime-adapter-core-available?) boolean?]
)]{

Report which backend implements swisstables in the running runtime:
@racket['cs-core] when the CS runtime-core primitives are available,
@racket['racket] for the portable pure-Racket implementation.}

@section[#:tag "swisstable-implementation"]{Implementation Notes}

A swisstable stores one control byte per slot: @racketvalfont{#xFF}
for an empty slot, @racketvalfont{#x80} for a tombstone, and
otherwise the low 7 bits of the key's mixed hash code (``H2''). A
lookup first locates a 16-byte aligned group of control bytes from
the high hash bits and matches all sixteen bytes against H2 at once,
so a full key comparison runs only on slots whose H2 byte already
agrees --- about a 1/128 false-positive rate.

On the CS runtime, all control-byte scanning happens in runtime-kernel
C probe loops that use SSE2 or NEON group matching where available.
For @racket[eq?]-based tables (and fixnum or character keys in
@racket[eqv?]-based tables, where @racket[eqv?] coincides with
@racket[eq?]), the entire probe including key comparison is a single
C call. For @racket[equal?]-based tables and other @racket[eqv?]
keys, a C candidate iterator yields H2-matching slots in probe order
while the (possibly user-defined) comparison runs in Racket between
steps; the iterator's resume state is a single immediate value, so a
comparison that touches the same table cannot corrupt an ongoing
scan. The C loops perform no allocation and cannot trigger a garbage
collection mid-probe. This state encoding bounds a table's capacity
to @racket[(expt 2 28)] slots.

Groups are probed in a triangular sequence, capacity is a power of
two, and the load factor is bounded by 7/8 counting tombstones;
removing an entry whose group still has an empty slot reverts the
slot to empty instead of leaving a tombstone.

Because Racket hash codes are stable across garbage collections, the
table layout never depends on object addresses, and a swisstable is
never rehashed by the collector; for a strong table, the two flat
arrays also present only two objects to the garbage collector
regardless of entry count.

A weak or ephemeron swisstable stores one collector-managed pair per
entry in the key slot --- a weak pair or an ephemeron pair carrying
the value --- and the collector clears a dead entry by rewriting the
pair contents, never the control bytes, so all probing machinery is
unaffected. Dead entries are reclaimed lazily: tables sweep when a
counting, iteration-starting, or mutating operation first runs after
a collection. Note that for keys that are not fixnums, symbols,
characters, or numbers, @racket[eq?]-based hashing consults a global
registry, which can dominate lookup cost regardless of table
representation.}
