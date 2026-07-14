#lang scribble/doc
@(require "mz.rkt" (for-label racket/crypto
                              racket/crypto/random
                              racket/crypto/util
                              racket/random))

@title[#:tag "crypto"]{Cryptography}

@defmodule[racket/crypto]{The @racketmodname[racket/crypto] library
re-exports @racketmodname[racket/crypto/random] and
@racketmodname[racket/crypto/util].}

Racket's built-in cryptography support is implemented by the
@deftech{rktcrypto} subsystem, a C library linked into the Racket
runtime, so it does not depend on OpenSSL or any other external
library. Operations on secret data are constant-time with respect to
the data's @emph{content}; lengths are not treated as secrets.

@; ------------------------------------------------------------------------

@section{Cryptographic Randomness}

@defmodule[racket/crypto/random]

@defproc[(crypto-random-bytes [n exact-nonnegative-integer?])
         bytes?]{

Returns @racket[n] cryptographically secure random bytes from the
operating system, via @tt{getentropy}, @tt{getrandom}, or
@tt{BCryptGenRandom} as available, falling back to
@filepath{/dev/urandom}. The same binding is available from
@racketmodname[racket/random].

An @racket[exn:fail] exception is raised if the system entropy source
is unavailable.}

@defproc[(crypto-random-bytes! [bstr (and/c bytes? (not/c immutable?))]
                               [start exact-nonnegative-integer? 0]
                               [end exact-nonnegative-integer? (bytes-length bstr)])
         void?]{

Like @racket[crypto-random-bytes], but fills @racket[bstr] from
@racket[start] (inclusive) to @racket[end] (exclusive) instead of
allocating, for use in hot paths.}

@; ------------------------------------------------------------------------

@section{Constant-Time Utilities}

@defmodule[racket/crypto/util]

@defproc[(crypto-bytes=? [a bytes?] [b bytes?]) boolean?]{

Like @racket[bytes=?] on two byte strings, but runs in constant time
with respect to the strings' contents when they have the same length,
so a timing channel does not reveal the position of the first
difference. Use it to compare MACs, password digests, or other
secret-derived tokens.

Byte strings of different lengths compare @racket[#f] immediately;
lengths are not treated as secrets.}

@defproc[(crypto-bytes-clear! [bstr (and/c bytes? (not/c immutable?))]
                              [start exact-nonnegative-integer? 0]
                              [end exact-nonnegative-integer? (bytes-length bstr)])
         void?]{

Zeroes @racket[bstr] from @racket[start] (inclusive) to @racket[end]
(exclusive) in a way that low-level compiler optimization will not
elide, for discarding key material.

The clearing is best-effort at the process level: it reliably clears
the argument byte string itself, but copies that were already made by
the garbage collector, the operating system's swap, or explicit
copying in user code are outside its reach.}

@defproc[(call-with-secret-bytes [n exact-nonnegative-integer?]
                                 [proc (-> bytes? any)])
         any]{

Calls @racket[proc] with a fresh mutable byte string of @racket[n]
zero bytes, and clears the byte string with
@racket[crypto-bytes-clear!] when control leaves @racket[proc],
whether by normal return or by escape. If control re-enters
@racket[proc] via a captured continuation, the byte string will
already have been cleared.}

@defproc[(crypto-subsystem-self-test?) boolean?]{

Runs the @tech{rktcrypto} subsystem's known-answer self-tests and
returns @racket[#t] if all pass. Returns @racket[#f] on hosts without
the built-in subsystem (currently, the BC implementation of Racket,
where the operations above fall back to best-effort Racket
implementations without a constant-time guarantee).}
