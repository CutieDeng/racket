#lang scribble/doc
@(require (except-in "mz.rkt"
                     crypto-bytes-clear!
                     crypto-bytes=?
                     crypto-random-bytes!
                     crypto-subsystem-self-test?)
          (for-label racket/crypto
                              racket/crypto/random
                              racket/crypto/util
                              racket/crypto/digest
                              racket/crypto/mac
                              racket/crypto/aead
                              racket/crypto/secretbox
                              racket/crypto/kex
                              racket/crypto/sign
                              (except-in racket/random crypto-random-bytes)))

@title[#:tag "crypto" #:style 'toc]{Cryptography}

@defmodule[racket/crypto]{The @racketmodname[racket/crypto] library
re-exports @racketmodname[racket/crypto/random] and
@racketmodname[racket/crypto/util].}

Racket's built-in cryptography support is implemented by the
@deftech{rktcrypto} subsystem, a C library linked into the Racket
runtime, so it does not depend on OpenSSL or any other external
library. Operations on secret data are constant-time with respect to
the data's @emph{content}; lengths are not treated as secrets.

@local-table-of-contents[]

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

@; ------------------------------------------------------------------------

@section{Message Digests}

@defmodule[racket/crypto/digest]

Digest algorithms are named by symbol. The supported algorithms are
@racket['sha224], @racket['sha256], @racket['sha384], @racket['sha512],
@racket['sha512/256], @racket['sha3-224], @racket['sha3-256],
@racket['sha3-384], @racket['sha3-512], @racket['shake128],
@racket['shake256], @racket['blake2b], and @racket['blake3]. The SHAKE
algorithms are @deftech{extendable-output functions} (@deftech{XOFs}): they have
no fixed output size, so a length must be supplied. BLAKE3 is also an
XOF but has a 32-byte default, so a length is optional for it.

@defthing[digest-algorithm/c flat-contract?]{
A contract for the digest algorithm symbols listed above.}

@defproc[(digest-bytes [alg digest-algorithm/c]
                       [in (or/c bytes? input-port?)]
                       [#:start start exact-nonnegative-integer? 0]
                       [#:end end (or/c exact-nonnegative-integer? #f) #f]
                       [#:length length (or/c exact-positive-integer? #f) #f])
         bytes?]{

Computes the digest of @racket[in] (a byte string or input port). For a
byte string, @racket[start] and @racket[end] select a subrange. For a
fixed-size algorithm @racket[length] may be omitted; for an @tech{XOF}
it is required.}

@defproc[(digest-file [alg digest-algorithm/c] [path path-string?]
                      [#:length length (or/c exact-positive-integer? #f) #f])
         bytes?]{
Computes the digest of a file's contents.}

@defproc[(make-digest [alg digest-algorithm/c]
                      [#:length length exact-nonnegative-integer? 0])
         digest?]{
Creates an incremental digest context.}

@defproc[(digest? [v any/c]) boolean?]{Recognizes digest contexts.}

@defproc[(digest-update! [dg digest?] [data bytes?]
                         [#:start start exact-nonnegative-integer? 0]
                         [#:end end (or/c exact-nonnegative-integer? #f) #f])
         void?]{
Absorbs @racket[data] into @racket[dg]. An error is raised if
@racket[dg] has been finalized.}

@defproc[(digest-final! [dg digest?]
                        [#:length length (or/c exact-positive-integer? #f) #f])
         bytes?]{
Finalizes @racket[dg] and returns the digest. The context becomes
unusable afterward.}

@deftogether[(
@defproc[(digest-output-size [alg (and/c digest-algorithm/c (not/c (lambda (a) (digest-xof? a))))]) exact-positive-integer?]
@defproc[(digest-block-size [alg digest-algorithm/c]) exact-positive-integer?]
@defproc[(digest-xof? [alg digest-algorithm/c]) boolean?]
@defproc[(digest-algorithms) (listof symbol?)]
)]{
Digest metadata: the default output size (not defined for XOFs), the
input block size (as used by HMAC), whether the algorithm is an XOF,
and the list of all supported algorithms.}

@; ------------------------------------------------------------------------

@section{Message Authentication Codes}

@defmodule[racket/crypto/mac]

@defthing[hmac-algorithm/c flat-contract?]{
Like @racket[digest-algorithm/c] but excludes the XOF algorithms, which
cannot key an HMAC.}

@defproc[(hmac-bytes [alg hmac-algorithm/c] [key bytes?] [data bytes?]
                     [#:start start exact-nonnegative-integer? 0]
                     [#:end end exact-nonnegative-integer? (bytes-length data)])
         bytes?]{

Computes @tt{HMAC}(@racket[key], @racket[data]) using @racket[alg] as
the underlying hash (FIPS 198-1 / RFC 2104). To verify a received MAC,
compare with @racket[crypto-bytes=?].}

@defproc[(make-hmac [alg hmac-algorithm/c] [key bytes?]) hmac?]{
Creates an incremental HMAC context.}

@defproc[(hmac? [v any/c]) boolean?]{Recognizes HMAC contexts.}

@defproc[(hmac-update! [h hmac?] [data bytes?]
                       [#:start start exact-nonnegative-integer? 0]
                       [#:end end exact-nonnegative-integer? (bytes-length data)])
         void?]{Absorbs @racket[data] into @racket[h].}

@defproc[(hmac-final! [h hmac?]) bytes?]{
Finalizes @racket[h] and returns the MAC.}

@; ------------------------------------------------------------------------

@section{Key Exchange}

@defmodule[racket/crypto/kex]

X25519 (RFC 7748) is Diffie-Hellman on Curve25519. A private key is 32
random bytes; the public key is the private key applied to the curve
base point.

@defproc[(x25519-generate-private-key) bytes?]{
Generates a fresh 32-byte X25519 private key.}

@defproc[(x25519-public-key [private-key bytes?]) bytes?]{
Derives the 32-byte public key for @racket[private-key].}

@defproc[(x25519 [private-key bytes?] [peer-public-key bytes?])
         (or/c bytes? #f)]{

Computes the 32-byte shared secret between @racket[private-key] and a
peer's public key, or @racket[#f] if the peer key is a low-order point
(the shared secret would be all-zero). A typical exchange derives a
symmetric key from the shared secret with @racket[hkdf].}

@deftogether[(
@defproc[(p256-generate-private-key) bytes?]
@defproc[(p256-public-key [private-key bytes?]) bytes?]
@defproc[(p256-ecdh [private-key bytes?] [peer-public-key bytes?]) (or/c bytes? #f)]
)]{
NIST P-256 (secp256r1) ECDH. A private key is 32 bytes; a public key is
a 65-byte uncompressed point (@tt{0x04}||x||y). @racket[p256-ecdh]
returns the 32-byte shared x-coordinate, or @racket[#f] on a malformed
peer point.}

@; ------------------------------------------------------------------------

@section{Signatures}

@defmodule[racket/crypto/sign]

Ed25519 (RFC 8032) signatures. A private key is a 32-byte seed; public
keys are 32 bytes and signatures are 64 bytes.

@defproc[(ed25519-generate-private-key) bytes?]{
Generates a fresh 32-byte Ed25519 private key.}

@defproc[(ed25519-public-key [private-key bytes?]) bytes?]{
Derives the 32-byte public key for @racket[private-key].}

@defproc[(ed25519-sign [private-key bytes?] [message bytes?]) bytes?]{
Signs @racket[message], returning a 64-byte signature.}

@defproc[(ed25519-verify [public-key bytes?] [message bytes?] [signature bytes?]) boolean?]{
Returns @racket[#t] if @racket[signature] is a valid Ed25519 signature
of @racket[message] under @racket[public-key].}

@deftogether[(
@defproc[(p256-ecdsa-sign [private-key bytes?] [message bytes?]) bytes?]
@defproc[(p256-ecdsa-verify [public-key bytes?] [message bytes?] [signature bytes?]) boolean?]
)]{
NIST P-256 ECDSA with SHA-256. Keys come from
@racket[p256-generate-private-key] and @racket[p256-public-key] (in
@racketmodname[racket/crypto/kex]); signatures are 64-byte @tt{r||s}.
Signing uses a random nonce, so a given message signs differently each
time.}

@; ------------------------------------------------------------------------

@section{Key Derivation}

@defmodule[racket/crypto/kdf]

@defthing[kdf-hash/c flat-contract?]{
A contract for the hash algorithms usable with a KDF: the fixed-size
digest algorithms (the XOFs are excluded).}

@defproc[(hkdf [alg kdf-hash/c] [ikm bytes?]
               [#:length length exact-positive-integer?]
               [#:salt salt bytes? #""]
               [#:info info bytes? #""])
         bytes?]{

HKDF (RFC 5869): derives @racket[length] bytes of key material from the
input keying material @racket[ikm], with optional @racket[salt] and
context @racket[info]. Equivalent to @racket[hkdf-extract] followed by
@racket[hkdf-expand].}

@deftogether[(
@defproc[(hkdf-extract [alg kdf-hash/c] [ikm bytes?] [#:salt salt bytes? #""]) bytes?]
@defproc[(hkdf-expand [alg kdf-hash/c] [prk bytes?] [length exact-positive-integer?] [#:info info bytes? #""]) bytes?]
)]{
The two HKDF stages separately, when finer control is needed.}

@defproc[(pbkdf2 [alg kdf-hash/c] [password bytes?] [salt bytes?]
                 [#:iterations iterations exact-positive-integer?]
                 [#:length length exact-positive-integer?])
         bytes?]{

PBKDF2 (RFC 8018) with @racket[alg]-based HMAC. Use a high
@racket[iterations] count for password hashing; @racket[argon2id] is a
stronger, memory-hard alternative.}

@defproc[(argon2id [password bytes?] [salt bytes?]
                   [#:iterations iterations exact-positive-integer? 3]
                   [#:memory memory exact-positive-integer? 65536]
                   [#:parallelism parallelism exact-positive-integer? 4]
                   [#:length length exact-positive-integer? 32]
                   [#:secret secret bytes? #""]
                   [#:ad ad bytes? #""])
         bytes?]{

Argon2id (RFC 9106), a memory-hard password hashing function.
@racket[memory] is in kibibytes; the defaults follow the RFC's
memory-constrained recommendation (3 iterations, 64 MiB, 4 lanes).
@racket[secret] and @racket[ad] are optional keying and associated
data.}

@; ------------------------------------------------------------------------

@section{Authenticated Encryption}

@subsection{High-Level: Secretbox}

@defmodule[racket/crypto/secretbox]

The secretbox interface is the recommended default for symmetric
encryption. The caller supplies only a key; each message is sealed with
a fresh random nonce carried in the output, so there is no way to reuse
a nonce by accident. It is built on XChaCha20-Poly1305, whose 192-bit
nonce makes random nonces collision-safe.

@defproc[(secretbox-key) bytes?]{
Generates a fresh random key.}

@defproc[(secretbox-encrypt [key bytes?] [plaintext bytes?]
                            [#:aad aad bytes? #""])
         bytes?]{

Encrypts @racket[plaintext] under @racket[key], returning a
self-describing sealed byte string (a version byte, the random nonce,
the ciphertext, and the authentication tag). @racket[aad] is
authenticated but not encrypted.}

@defproc[(secretbox-decrypt [key bytes?] [sealed bytes?]
                            [#:aad aad bytes? #""])
         (or/c bytes? #f)]{

Decrypts a byte string produced by @racket[secretbox-encrypt], returning
the plaintext, or @racket[#f] if it is malformed or authentication
fails. The two failure kinds are deliberately not distinguished.}

@subsection{Low-Level: Explicit-Nonce AEAD}

@defmodule[racket/crypto/aead]

This is the expert-facing interface: the caller chooses the nonce and is
responsible for @bold{never reusing a @racket[(key nonce)] pair}, which
would be catastrophic. Prefer @racketmodname[racket/crypto/secretbox]
unless you specifically need to control the nonce.

@defthing[aead-algorithm/c flat-contract?]{
A contract for the AEAD algorithm symbols @racket['chacha20-poly1305],
@racket['xchacha20-poly1305], and @racket['aes-256-gcm]. On hardware
without AES acceleration, prefer a ChaCha20-Poly1305 variant: the
portable AES here is constant-time but not fast.}

@defproc[(aead-encrypt [alg aead-algorithm/c] [key bytes?] [nonce bytes?]
                       [plaintext bytes?] [#:aad aad bytes? #""])
         bytes?]{

Encrypts and authenticates @racket[plaintext], returning the ciphertext
with the authentication tag appended. @racket[key] and @racket[nonce]
must match the algorithm's sizes.}

@defproc[(aead-decrypt [alg aead-algorithm/c] [key bytes?] [nonce bytes?]
                       [ciphertext+tag bytes?] [#:aad aad bytes? #""])
         (or/c bytes? #f)]{

Verifies and decrypts, returning the plaintext, or @racket[#f] if
authentication fails.}

@deftogether[(
@defproc[(aead-key-size [alg aead-algorithm/c]) exact-positive-integer?]
@defproc[(aead-nonce-size [alg aead-algorithm/c]) exact-positive-integer?]
@defproc[(aead-tag-size [alg aead-algorithm/c]) exact-positive-integer?]
@defproc[(aead-algorithms) (listof symbol?)]
)]{
AEAD metadata: key, nonce, and tag sizes in bytes, and the list of
supported algorithms.}
