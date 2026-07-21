#lang scribble/doc
@(require "mz.rkt" (for-label racket/random/generator
                              racket/flonum
                              racket/fixnum
                              racket/random))

@title[#:tag "random-generators"]{Fast Random Generators}

@defmodule[racket/random/generator]

The @racketmodname[racket/random/generator] library provides
high-performance, seedable pseudo-random generators backed by the
@deftech{rktrandom} subsystem, a C library linked into the Racket
runtime. Generators are deterministic given a seed and algorithm and
are intended for simulation, sampling, and randomized algorithms;
they are @bold{not} cryptographically secure. For secrets, use
@racket[crypto-random-bytes].

Scalar draws are served from an internal buffer refilled by a single
C call, so a draw costs a few nanoseconds; the
@racket[rgen-bytes!]-style bulk operations and the fused
distribution fills generate whole vectors of output in one C call.

A generator is @emph{not} thread-safe. Use one generator per thread
or place; @racket[rgen-fork], @racket[rgen-jump!], and the
@racket[#:stream] argument of @racket[make-rgen] all produce
decorrelated streams for parallel work.

@defproc[(rgen? [v any/c]) boolean?]{Returns @racket[#t] if
@racket[v] is a fast random generator, @racket[#f] otherwise.}

@defproc[(make-rgen [seed (or/c #f exact-integer? bytes?) #f]
                    [#:algorithm algorithm symbol? 'xoshiro256++]
                    [#:stream stream exact-nonnegative-integer? 0])
         rgen?]{

Creates a generator. A @racket[#f] seed draws fresh entropy from the
operating system; an exact-integer seed is expanded via splitmix64
(matching the C-level and reference-implementation convention for
integer seeds); a 32-byte string is used as seed material directly.

The @racket[algorithm] is one of @racket['xoshiro256++] (the
default), @racket['xoshiro256**], @racket['xoroshiro128++],
@racket['sfc64], @racket['pcg64-dxsm], or @racket['philox4x64].
Distinct @racket[stream] values yield decorrelated streams from the
same seed; for @racket['pcg64-dxsm] and @racket['philox4x64] streams
are mathematically disjoint, while for the xoshiro family use
@racket[rgen-jump!] for guaranteed non-overlap.}

@deftogether[(
@defproc[(rgen-algorithm [g rgen?]) symbol?]
@defproc[(rgen-algorithms) (listof symbol?)]
@defproc[(rgen-copy [g rgen?]) rgen?]
)]{Inspection and duplication. A copy continues the same stream
independently of the original.}

@defproc[(current-rgen) rgen?]{Returns a per-thread default
generator, lazily created with operating-system entropy.}

@section{Scalar Draws}

@deftogether[(
@defproc[(rgen-fixnum [g rgen?]) fixnum?]
@defproc[(rgen-u64 [g rgen?]) exact-nonnegative-integer?]
@defproc[(rgen-integer [g rgen?] [n exact-positive-integer?]) exact-nonnegative-integer?]
@defproc[(rgen-real [g rgen?]) flonum?]
@defproc[(rgen-boolean [g rgen?] [p (or/c #f real?) #f]) boolean?]
@defproc[(rgen-normal [g rgen?] [mu real? 0.0] [sigma real? 1.0]) flonum?]
@defproc[(rgen-exponential [g rgen?] [rate real? 1.0]) flonum?]
)]{

@racket[rgen-fixnum] returns 56 uniform random bits as a nonnegative
fixnum; @racket[rgen-u64] returns a full 64-bit draw (allocating a
bignum when the top bits are set, so prefer the others in hot code).
@racket[rgen-integer] returns an unbiased uniform integer in
@math{[0, n)}. @racket[rgen-real] returns a uniform flonum in
@math{[0, 1)} with 53 random bits. @racket[rgen-normal] and
@racket[rgen-exponential] draw normal and exponential variates from
C-filled buffers (256-layer ziggurat).}

@section{Bulk and Fused Fills}

@deftogether[(
@defproc[(rgen-bytes! [g rgen?] [bstr bytes?] [start exact-nonnegative-integer? 0]
                      [end exact-nonnegative-integer? (bytes-length bstr)]) void?]
@defproc[(rgen-bytes [g rgen?] [n exact-nonnegative-integer?]) bytes?]
)]{Fills bytes with the generator's raw output stream (little-endian
64-bit words).}

@deftogether[(
@defproc[(rgen-f64-bytes! [g rgen?] [bstr bytes?] [start exact-nonnegative-integer? 0]
                          [end exact-nonnegative-integer? (bytes-length bstr)]) void?]
@defproc[(rgen-normal-bytes! [g rgen?] [bstr bytes?] [start exact-nonnegative-integer? 0]
                             [end exact-nonnegative-integer? (bytes-length bstr)]) void?]
@defproc[(rgen-exponential-bytes! [g rgen?] [bstr bytes?] [start exact-nonnegative-integer? 0]
                                  [end exact-nonnegative-integer? (bytes-length bstr)]) void?]
@defproc[(rgen-bounded-bytes! [g rgen?] [bound fixnum?] [bstr bytes?]
                              [start exact-nonnegative-integer? 0]
                              [end exact-nonnegative-integer? (bytes-length bstr)]) void?]
)]{

Zero-copy fused fills: whole arrays of variates in one C call. The
@tt{f64}, @tt{normal}, and @tt{exponential} variants write
native-endian doubles (uniform @math{[0,1)}, @math{N(0,1)}, and
@math{Exp(1)} respectively); @racket[rgen-bounded-bytes!] writes
unbiased little-endian 64-bit integers in @math{[0, bound)}. The
byte range must be a multiple of 8.}

@deftogether[(
@defproc[(rgen-flvector [g rgen?] [n exact-nonnegative-integer?]
                        [dist (or/c 'uniform 'normal 'exponential) 'uniform]
                        [#:mu mu real? 0.0] [#:sigma sigma real? 1.0]
                        [#:rate rate real? 1.0]) flvector?]
@defproc[(rgen-flvector! [g rgen?] [flv flvector?]
                         [dist (or/c 'uniform 'normal 'exponential) 'uniform]
                         [#:mu mu real? 0.0] [#:sigma sigma real? 1.0]
                         [#:rate rate real? 1.0]) void?]
@defproc[(rgen-fxvector [g rgen?] [n exact-nonnegative-integer?] [bound fixnum?]) fxvector?]
)]{

Convenience variants that produce @tech{flvectors} and
@tech{fxvectors}; scaling by @racket[mu]/@racket[sigma] (normal) or
@racket[rate] (exponential) is fused into the copy loop.
@racket[rgen-fxvector] requires @racket[bound] at most
@math{2^{60}-1}.}

@section{Substreams}

@deftogether[(
@defproc[(rgen-jump! [g rgen?]) void?]
@defproc[(rgen-long-jump! [g rgen?]) void?]
@defproc[(rgen-fork [g rgen?]) rgen?]
)]{

@racket[rgen-jump!] advances the state as if a large number of draws
had been made (@math{2^{128}} for the xoshiro256 family), yielding
non-overlapping substreams for parallel work; @racket[rgen-long-jump!]
jumps further (@math{2^{192}}). @racket[rgen-fork] returns a new
generator one jump ahead of @racket[g]'s stream and advances
@racket[g] past the child's region. Jumps are not available for
@racket['sfc64] (and long jumps only for the xoshiro/xoroshiro
family); an unsupported jump raises @racket[exn:fail].}

@section{Collection Operations}

@deftogether[(
@defproc[(rgen-shuffle! [g rgen?] [vec (and/c vector? (not/c immutable?))]) void?]
@defproc[(rgen-shuffle [g rgen?] [lst list?]) list?]
@defproc[(rgen-ref [g rgen?] [seq (or/c vector? list? bytes? string?)]) any/c]
@defproc[(rgen-weighted-index [g rgen?] [weights (vectorof (>=/c 0))]) exact-nonnegative-integer?]
)]{

Fisher--Yates shuffling, uniform element selection, and weighted
index selection (probability proportional to the weight).}

@section{Availability}

@defthing[rktrandom-available? boolean?]{Whether the rktrandom
subsystem is part of this build. On builds without it, the bindings
above raise when called.}
