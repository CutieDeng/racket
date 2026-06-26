#lang scribble/doc
@(require "mz.rkt"
          (for-label racket/intmap
                     racket/serialize
                     racket/stream))

@(define intmap-eval (make-base-eval))
@(intmap-eval '(require racket/intmap
                        racket/serialize
                        racket/stream))

@title[#:tag "intmap"]{Intmaps}

An @deftech{intmap} is an immutable ordered map whose keys are exact
integers. Operations that add, replace, or remove an entry return a
new intmap while the original intmap remains intact. Entries are ordered
by numeric key order.

Unless otherwise specified, lookup, update, removal, and nearest-entry
operations take @math{O(log N)} time for an intmap with @math{N}
entries. Full traversal, conversion to a list, and construction from
all entries take @math{O(N)} time. Implementations may use faster paths
for fixnum keys, but all exact integers are accepted.

An intmap can be used directly as a two-valued @tech{sequence}, where
each iteration produces a key and a value. As a @tech{stream}, an
intmap produces key-value pairs. Intmaps compare with @racket[equal?]
by their ordered entries and are serializable when their values are
serializable.

@note-lib[racket/intmap #:use-sources (racket/intmap)]

@examples[
#:eval intmap-eval
(define m (intmap 3 'c 1 'a 2 'b))
(for/list ([(k v) m]) (cons k v))
(intmap-entry< m 3)
(intmap-range->list m 2 4)
(stream->list m)
(equal? (deserialize (serialize m)) m)
]

@section[#:tag "intmap-implementation"]{Implementation Notes}

An intmap is represented as a persistent weight-balanced binary search
tree with cached subtree sizes. Updating operations path-copy the
search path and share untouched subtrees with older versions. Bulk
constructors such as @racket[sorted-vector->intmap] build a balanced
tree directly and should be preferred for already-sorted input or
literal data.

On Racket CS, the implementation can use a runtime backend with core
records and cursor primitives. The Racket fallback exposes the same
public API. Programs should treat the concrete representation as
opaque.

In write mode, an intmap prints as a readable @racketresultfont{#intmap}
literal whose payload is the sorted entry list. This representation
shares the validation and linear construction path of
@racket[sorted-list->intmap].

@section[#:tag "intmap-constructing"]{Constructing Intmaps}

@defproc[(intmap? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[v] is an @tech{intmap}, @racket[#f]
otherwise.}

@deftogether[(
@defthing[intmap-empty intmap?]
@defproc[(intmap-empty? [v any/c]) boolean?]
)]{

The @racket[intmap-empty] value is the empty intmap. The
@racket[intmap-empty?] predicate returns @racket[#t] when @racket[v]
is the empty intmap, and @racket[#f] otherwise.}

@defproc[(intmap [key exact-integer?] [value any/c] ...) intmap?]{

Returns an intmap containing the supplied key-value pairs. An even
number of arguments must be supplied. If a key appears more than once,
the rightmost value is retained.}

@deftogether[(
@defproc[(intmap->literal-datum [m intmap?]) list?]
@defproc[(literal-datum->intmap [datum any/c]) intmap?]
@defproc[(write-intmap-literal [m intmap?]
                                [out output-port? (current-output-port)]
                                [#:pretty? pretty? boolean? #f])
         void?]
)]{

Converts an intmap to and from the datum payload of the
@racketresultfont{#intmap} reader literal, or writes the full literal to
@racket[out]. The datum shape is a sorted list of entries, where each
entry is a pair whose @racket[car] is an exact-integer key and whose
@racket[cdr] is the value. The reader accepts the same shape as
@racketresultfont{#intmap((1 . a) (2 . b))}. When @racket[pretty?] is
true, the literal datum is emitted with @racket[pretty-write] instead of
@racket[write]. Parsing @racketresultfont{#intmap} input is controlled
by @racket[read-accept-intmap].}

@deftogether[(
@defproc[(sorted-list->intmap [entries list?]) intmap?]
@defproc[(sorted-vector->intmap [entries vector?]) intmap?]
)]{

Returns an intmap containing @racket[entries], where each entry is a
pair whose @racket[car] is an exact-integer key and whose @racket[cdr]
is the value. Keys must be strictly increasing.}

@section[#:tag "intmap-accessing-updating"]{Accessing and Updating}

@defproc[(intmap-count [m intmap?]) exact-nonnegative-integer?]{

Returns the number of entries in @racket[m].}

@defproc[(intmap-ref [m intmap?] [key exact-integer?] [default any/c]) any/c]{

Returns the value for @racket[key]. If @racket[key] is absent and
@racket[default] is supplied, @racket[default] is returned, or called
with no arguments when it is a procedure. If @racket[default] is not
supplied, an @racket[exn:fail:contract] exception is raised.}

@defproc[(intmap-has-key? [m intmap?] [key exact-integer?]) boolean?]{

Returns @racket[#t] if @racket[m] contains @racket[key], @racket[#f]
otherwise.}

@deftogether[(
@defproc[(intmap-set [m intmap?] [key exact-integer?] [value any/c]) intmap?]
@defproc[(intmap-remove [m intmap?] [key exact-integer?]) intmap?]
)]{

Returns an intmap like @racket[m], but with @racket[key] mapped to
@racket[value], or with @racket[key] removed.}

@defproc[(intmap-update [m intmap?]
                        [key exact-integer?]
                        [absent-proc any/c]
                        [present-proc any/c])
         intmap?]{

Returns an intmap where @racket[key] is updated. If @racket[key] is
absent, @racket[absent-proc] is called with no arguments when it is a
procedure, otherwise it is used directly as the new value. If
@racket[key] is present, @racket[present-proc] is called with the old
value when it is a procedure, otherwise it is used directly as the new
value.}

@deftogether[(
@defproc[(intmap-set/absent [m intmap?] [key exact-integer?] [value any/c])
         (values intmap? boolean?)]
@defproc[(intmap-replace [m intmap?] [key exact-integer?] [value any/c])
         (values intmap? boolean?)]
)]{

Returns an intmap and a boolean. @racket[intmap-set/absent] adds
@racket[key] only when it is absent; the boolean reports whether an
entry was inserted. @racket[intmap-replace] replaces @racket[key] only
when it is present; the boolean reports whether replacement happened.}

@deftogether[(
@defproc[(intmap-replace/eq [m intmap?] [key exact-integer?] [old-value any/c] [new-value any/c])
         (values intmap? boolean?)]
@defproc[(intmap-replace/equal [m intmap?] [key exact-integer?] [old-value any/c] [new-value any/c])
         (values intmap? boolean?)]
)]{

Conditionally replaces the value for @racket[key]. The
@racketidfont{/eq} forms require the current value to be @racket[eq?]
to @racket[old-value]; the @racketidfont{/equal} forms require it to be
@racket[equal?]. The boolean reports whether the condition matched and
the replacement was performed.}

@deftogether[(
@defproc[(intmap-remove/eq [m intmap?] [key exact-integer?] [old-value any/c])
         (values intmap? boolean?)]
@defproc[(intmap-remove/equal [m intmap?] [key exact-integer?] [old-value any/c])
         (values intmap? boolean?)]
)]{

Conditionally removes @racket[key] when the current value matches
@racket[old-value] using @racket[eq?] or @racket[equal?]. The boolean
reports whether the entry was removed.}

@section[#:tag "intmap-ordered-queries"]{Ordered Queries}

@deftogether[(
@defproc[(intmap-entry< [m intmap?] [key exact-integer?] [default any/c #f]) any/c]
@defproc[(intmap-entry<= [m intmap?] [key exact-integer?] [default any/c #f]) any/c]
@defproc[(intmap-entry> [m intmap?] [key exact-integer?] [default any/c #f]) any/c]
@defproc[(intmap-entry>= [m intmap?] [key exact-integer?] [default any/c #f]) any/c]
)]{

Returns the nearest entry as a pair. The comparison in the procedure
name determines which keys are candidates. If no entry matches,
@racket[default] is returned.}

@deftogether[(
@defproc[(intmap-min-entry [m intmap?] [default any/c]) any/c]
@defproc[(intmap-max-entry [m intmap?] [default any/c]) any/c]
)]{

Returns the minimum or maximum entry as a pair. If @racket[m] is empty
and @racket[default] is supplied, @racket[default] is returned;
otherwise an @racket[exn:fail:contract] exception is raised.}

@defproc[(intmap-range->list [m intmap?]
                             [lo (or/c exact-integer? #f) #f]
                             [hi (or/c exact-integer? #f) #f]
                             [inclusive-lo? any/c #t]
                             [inclusive-hi? any/c #f])
         list?]{

Returns the ordered list of entries in range. A @racket[#f] bound is
unbounded. By default, the interval is half-open:
@racket[lo] @math{<=} key @math{<} @racket[hi].}

@section[#:tag "intmap-sequences"]{Sequences}

@deftogether[(
@defproc[(in-intmap [m intmap?] [#:reverse? reverse? any/c #f]) sequence?]
@defproc[(in-intmap-range [m intmap?] [lo exact-integer?] [hi exact-integer?]
                          [#:reverse? reverse? any/c #f]) sequence?]
)]{

Returns a two-valued sequence of keys and values. The range form uses
the half-open interval @racket[lo] @math{<=} key @math{<} @racket[hi].
When @racket[reverse?] is not @racket[#f], the sequence is in descending
key order.}

@deftogether[(
@defproc[(in-intmap-keys [m intmap?] [#:reverse? reverse? any/c #f]) sequence?]
@defproc[(in-intmap-values [m intmap?] [#:reverse? reverse? any/c #f]) sequence?]
@defproc[(in-intmap-pairs [m intmap?] [#:reverse? reverse? any/c #f]) sequence?]
@defproc[(in-intmap-range-keys [m intmap?] [lo exact-integer?] [hi exact-integer?]
                               [#:reverse? reverse? any/c #f]) sequence?]
@defproc[(in-intmap-range-values [m intmap?] [lo exact-integer?] [hi exact-integer?]
                                 [#:reverse? reverse? any/c #f]) sequence?]
@defproc[(in-intmap-range-pairs [m intmap?] [lo exact-integer?] [hi exact-integer?]
                                [#:reverse? reverse? any/c #f]) sequence?]
)]{

Returns a single-valued sequence of keys, values, or entry pairs. When
@racket[reverse?] is not @racket[#f], the sequence is in descending key
order.}
