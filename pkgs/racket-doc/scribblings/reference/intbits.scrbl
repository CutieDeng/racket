#lang scribble/doc
@(require "mz.rkt"
          (for-label racket/intbits))

@(define intbits-eval (make-base-eval))
@(intbits-eval '(require racket/intbits))

@title[#:tag "intbits"]{Intbits}

An @deftech{intbits} value is an exact integer used as an immutable set
of bit indexes. A nonnegative integer represents a finite set. A
negative integer represents a co-finite set, using Racket's semi-infinite
two's-complement integer representation, so all sufficiently high bits
are set.

Unbounded enumeration and size operations require a finite intbits value
and raise @exnraise[exn:fail:contract] for a negative value. Bounded
operations use half-open ranges @racket[lo] @math{<=} index
@math{<} @racket[hi] and support both finite and co-finite intbits
values.

Traversal operations enumerate set bit indexes, not boolean occupancy
values. Use @racket[intbits-fold] or @racket[intbits-for-each] for hot
paths that should avoid materializing a list.

@note-lib[racket/intbits #:use-sources (racket/intbits)]

@section[#:tag "intbits-predicates"]{Predicates and Constants}

@defproc[(intbits? [v any/c]) boolean?]{

Returns @racket[#t] when @racket[v] is an exact integer.}

@defproc[(intbits-finite? [v any/c]) boolean?]{

Returns @racket[#t] when @racket[v] is an exact nonnegative integer.}

@defthing[intbits-empty intbits?]{

The empty intbits value, @racket[0].}

@defproc[(intbits-empty? [v any/c]) boolean?]{

Returns @racket[#t] when @racket[v] is @racket[0].}

@section[#:tag "intbits-single-bit"]{Single-Bit Operations}

@defproc[(intbits-ref [bits intbits?] [pos exact-nonnegative-integer?])
         boolean?]{

Returns whether bit @racket[pos] is set in @racket[bits].}

@defproc[(intbits-set [bits intbits?]
                      [pos exact-nonnegative-integer?]
                      [value boolean? #t])
         intbits?]{

Returns @racket[bits] with bit @racket[pos] set when @racket[value] is
true, or cleared otherwise.}

@defproc[(intbits-clear [bits intbits?] [pos exact-nonnegative-integer?])
         intbits?]{

Returns @racket[bits] with bit @racket[pos] cleared.}

@defproc[(intbits-toggle [bits intbits?] [pos exact-nonnegative-integer?])
         intbits?]{

Returns @racket[bits] with bit @racket[pos] toggled.}

@section[#:tag "intbits-set-algebra"]{Set Algebra}

@defproc[(intbits-complement [bits intbits?]) intbits?]{

Returns the bitwise complement of @racket[bits]. The result can be
negative.}

@defproc[(intbits-union [bits intbits?] ...) intbits?]{

Returns the union of all @racket[bits] values. With no arguments, the
result is @racket[0].}

@defproc[(intbits-intersect [bits intbits?] ...) intbits?]{

Returns the intersection of all @racket[bits] values. With no arguments,
the result is @racket[-1], the set of all bit indexes.}

@defproc[(intbits-subtract [bits intbits?] [remove-bits intbits?] ...)
         intbits?]{

Returns @racket[bits] with all bits from each @racket[remove-bits]
cleared.}

@defproc[(intbits-xor [bits intbits?] ...) intbits?]{

Returns the symmetric difference of all @racket[bits] values. With no
arguments, the result is @racket[0].}

@defproc[(intbits-intersects? [a intbits?] [b intbits?]) boolean?]{

Returns whether @racket[a] and @racket[b] share any set bit.}

@defproc[(intbits-disjoint? [a intbits?] [b intbits?]) boolean?]{

Returns whether @racket[a] and @racket[b] share no set bit.}

@defproc[(intbits-subset? [a intbits?] [b intbits?]) boolean?]{

Returns whether every bit set in @racket[a] is also set in @racket[b].}

@section[#:tag "intbits-queries"]{Queries}

@defproc[(intbits-count [bits intbits-finite?]) exact-nonnegative-integer?]{

Returns the number of set bits in finite @racket[bits].}

@defproc[(intbits-count-range [bits intbits?]
                              [lo exact-nonnegative-integer?]
                              [hi exact-nonnegative-integer?])
         exact-nonnegative-integer?]{

Returns the number of set bits in the half-open range from @racket[lo]
to @racket[hi].}

@defproc[(intbits-width [bits intbits-finite?]) exact-nonnegative-integer?]{

Returns @racket[(integer-length bits)] for finite @racket[bits].}

@defproc[(intbits-first [bits intbits?]) (or/c #f exact-nonnegative-integer?)]{

Returns the smallest set bit index in @racket[bits], or @racket[#f] if
none is set.}

@defproc[(intbits-last [bits intbits-finite?]) (or/c #f exact-nonnegative-integer?)]{

Returns the largest set bit index in finite @racket[bits], or
@racket[#f] if none is set.}

@defproc[(intbits-next [bits intbits?] [pos exact-nonnegative-integer?])
         (or/c #f exact-nonnegative-integer?)]{

Returns the smallest set bit index greater than or equal to @racket[pos],
or @racket[#f] if none exists.}

@defproc[(intbits-prev [bits intbits?] [pos exact-nonnegative-integer?])
         (or/c #f exact-nonnegative-integer?)]{

Returns the largest set bit index less than or equal to @racket[pos], or
@racket[#f] if none exists.}

@defproc[(intbits-rank [bits intbits?] [pos exact-nonnegative-integer?])
         exact-nonnegative-integer?]{

Returns the number of set bits with indexes less than @racket[pos].}

@defproc[(intbits-select [bits intbits?] [index exact-nonnegative-integer?])
         (or/c #f exact-nonnegative-integer?)]{

Returns the index of the @racket[index]th set bit, counting from zero,
or @racket[#f] if @racket[bits] has too few set bits.}

@section[#:tag "intbits-ranges"]{Range Operations}

@defproc[(intbits-range-mask [lo exact-nonnegative-integer?]
                             [hi exact-nonnegative-integer?])
         intbits?]{

Returns a finite intbits value with exactly the bits in the half-open
range from @racket[lo] to @racket[hi] set.}

@defproc[(intbits-field [bits intbits?]
                        [lo exact-nonnegative-integer?]
                        [hi exact-nonnegative-integer?])
         intbits-finite?]{

Returns the low-shifted field of @racket[bits] in the half-open range
from @racket[lo] to @racket[hi].}

@defproc[(intbits-set-range [bits intbits?]
                            [lo exact-nonnegative-integer?]
                            [hi exact-nonnegative-integer?])
         intbits?]{

Returns @racket[bits] with all bits in the half-open range set.}

@defproc[(intbits-clear-range [bits intbits?]
                              [lo exact-nonnegative-integer?]
                              [hi exact-nonnegative-integer?])
         intbits?]{

Returns @racket[bits] with all bits in the half-open range cleared.}

@defproc[(intbits-toggle-range [bits intbits?]
                               [lo exact-nonnegative-integer?]
                               [hi exact-nonnegative-integer?])
         intbits?]{

Returns @racket[bits] with all bits in the half-open range toggled.}

@defproc[(intbits-replace-field [bits intbits?]
                                [lo exact-nonnegative-integer?]
                                [hi exact-nonnegative-integer?]
                                [field intbits?])
         intbits?]{

Returns @racket[bits] with the half-open range replaced by the low
@racket[(- hi lo)] bits of @racket[field].}

@section[#:tag "intbits-traversal"]{Traversal}

@defproc[(intbits-for-each [bits intbits-finite?]
                           [proc (-> exact-nonnegative-integer? any)])
         void?]{

Applies @racket[proc] to each set bit index in finite @racket[bits], in
increasing order.}

@defproc[(intbits-for-each/range [bits intbits?]
                                 [lo exact-nonnegative-integer?]
                                 [hi exact-nonnegative-integer?]
                                 [proc (-> exact-nonnegative-integer? any)])
         void?]{

Applies @racket[proc] to each set bit index in the half-open range, in
increasing order.}

@defproc[(intbits-fold [bits intbits-finite?]
                       [init any/c]
                       [proc (-> any/c exact-nonnegative-integer? any/c)])
         any/c]{

Folds over set bit indexes in finite @racket[bits], in increasing order.
The @racket[proc] procedure receives the accumulator followed by the bit
index.}

@defproc[(intbits-fold/range [bits intbits?]
                             [lo exact-nonnegative-integer?]
                             [hi exact-nonnegative-integer?]
                             [init any/c]
                             [proc (-> any/c exact-nonnegative-integer? any/c)])
         any/c]{

Folds over set bit indexes in the half-open range, in increasing order.
The @racket[proc] procedure receives the accumulator followed by the bit
index.}

@section[#:tag "intbits-conversions"]{Conversions and Sequences}

@defproc[(intbits->list [bits intbits-finite?]) (listof exact-nonnegative-integer?)]{

Returns the set bit indexes in finite @racket[bits].}

@defproc[(intbits->list/range [bits intbits?]
                              [lo exact-nonnegative-integer?]
                              [hi exact-nonnegative-integer?])
         (listof exact-nonnegative-integer?)]{

Returns the set bit indexes in the half-open range.}

@defproc[(list->intbits [positions (listof exact-nonnegative-integer?)])
         intbits-finite?]{

Returns a finite intbits value with the indexes in @racket[positions]
set. Duplicate indexes are ignored.}

@defproc[(intbits->string [bits intbits-finite?]) string?]{

Returns a string of @litchar{0}s and @litchar{1}s for finite
@racket[bits]. The character at position @racket[i] corresponds to bit
index @racket[i].}

@defproc[(intbits->string/range [bits intbits?]
                                  [lo exact-nonnegative-integer?]
                                  [hi exact-nonnegative-integer?])
         string?]{

Returns a string of @litchar{0}s and @litchar{1}s for the half-open
range.}

@defproc[(string->intbits [str string?]) intbits-finite?]{

Returns a finite intbits value from a string of @litchar{0}s and
@litchar{1}s. The character at position @racket[i] corresponds to bit
index @racket[i].}

@defproc[(in-intbits [bits intbits-finite?]) sequence?]{

Returns a sequence of set bit indexes in finite @racket[bits].}

@defproc[(in-intbits-range [bits intbits?]
                           [lo exact-nonnegative-integer?]
                           [hi exact-nonnegative-integer?])
         sequence?]{

Returns a sequence of set bit indexes in the half-open range.}

@examples[
#:eval intbits-eval
(define bits (list->intbits '(0 2 5)))
(intbits->list bits)
(intbits-fold bits 0 +)
(intbits-ref (intbits-complement bits) 100)
(intbits->list/range (intbits-complement bits) 0 8)
(intbits-fold/range -1 3 7 0 +)
(for/list ([i (in-intbits-range -1 3 7)]) i)
]
