
(load-relative "loadtest.rktl")

(Section 'crypto-digest)

(require racket/crypto
         file/sha1)

(define (hx alg in) (bytes->hex-string (digest-bytes alg in)))

;; ----------------------------------------
;; SHA-2 (FIPS 180-4 vectors)

(test "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
      hx 'sha256 #"abc")
(test "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      hx 'sha256 #"")
(test "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
      hx 'sha256 #"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")
(test "23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7"
      hx 'sha224 #"abc")
(test (string-append "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a"
                     "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f")
      hx 'sha512 #"abc")
(test "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7"
      hx 'sha384 #"abc")
(test "53048e2681941ef99b2e29b76b4c7dabe4c2d0c634fc6d46e0e2f13107e7af23"
      hx 'sha512/256 #"abc")

;; ----------------------------------------
;; SHA-3 and SHAKE (FIPS 202 vectors)

(test "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532"
      hx 'sha3-256 #"abc")
(test "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a"
      hx 'sha3-256 #"")
(test (string-append "b751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712e"
                     "10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f0")
      hx 'sha3-512 #"abc")
(test "e642824c3f8cf24ad09234ee7d3c766fc9a3a5168d0c94ad73b46fdf"
      hx 'sha3-224 #"abc")
(test "ec01498288516fc926459f58e2c6ad8df9b473cb0fc08c2596da7cf0e49be4b298d88cea927ac7f539f1edf228376d25"
      hx 'sha3-384 #"abc")
;; SHAKE XOF (empty input)
(test "7f9c2ba4e88f827d616045507605853ed73b8093f6efbc88eb1a6eacfa66ef26"
      values (bytes->hex-string (digest-bytes 'shake128 #"" #:length 32)))
(test (string-append "46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762f"
                     "d75dc4ddd8c0f200cb05019d67b592f6fc821c49479ab48640292eacb3b7c4be")
      values (bytes->hex-string (digest-bytes 'shake256 #"" #:length 64)))

;; ----------------------------------------
;; BLAKE2b (RFC 7693)

(test (string-append "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d1"
                     "7d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923")
      hx 'blake2b #"abc")

;; ----------------------------------------
;; BLAKE3 (official spec; default 32-byte output, also an XOF)

(test "6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85"
      hx 'blake3 #"abc")
(test "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262"
      hx 'blake3 #"")
;; XOF: default length is 32, but longer is allowed and a prefix of it
(test (subbytes (digest-bytes 'blake3 #"abc" #:length 131) 0 32)
      values (digest-bytes 'blake3 #"abc"))
(test 32 digest-output-size 'blake3)
(test #t digest-xof? 'blake3)
;; multi-chunk input (2 KiB) incremental == one-shot
(let ([msg (make-bytes 2048 90)])
  (define d (make-digest 'blake3))
  (digest-update! d msg #:start 0 #:end 1000)
  (digest-update! d msg #:start 1000 #:end 2048)
  (test (digest-bytes 'blake3 msg) digest-final! d))

;; ----------------------------------------
;; Region selection (#:start / #:end)

(test (hx 'sha256 #"abc")
      values (bytes->hex-string (digest-bytes 'sha256 #"__abc__" #:start 2 #:end 5)))

;; ----------------------------------------
;; Incremental == one-shot, arbitrary chunking

(let ([msg #"the quick brown fox jumps over the lazy dog"])
  (for ([alg '(sha256 sha512 sha3-256 blake2b)])
    (define d (make-digest alg))
    (for ([i (in-range (bytes-length msg))])
      (digest-update! d msg #:start i #:end (add1 i)))
    (test (digest-bytes alg msg) digest-final! d)))

;; XOF incremental
(let ([d (make-digest 'shake256)])
  (digest-update! d #"abc")
  (test (digest-bytes 'shake256 #"abc" #:length 40)
        digest-final! d #:length 40))

;; ----------------------------------------
;; Context copy (fork) and peek

;; Fork at a non-block-boundary offset: both branches must match a
;; full one-shot recompute, for every algorithm.
(let ([prefix (make-bytes 100 65)]
      [sfx-a #"suffix one"]
      [sfx-b #"and a different, longer suffix two"])
  (for ([alg (in-list (digest-algorithms))])
    (define len (and (digest-xof? alg) 48))
    (define (one-shot suffix)
      (digest-bytes alg (bytes-append prefix suffix) #:length len))
    (define d (make-digest alg))
    (digest-update! d prefix)
    (define d2 (digest-copy d))
    (digest-update! d sfx-a)
    (digest-update! d2 sfx-b)
    (test (one-shot sfx-a) digest-final! d #:length len)
    (test (one-shot sfx-b) digest-final! d2 #:length len)))

;; BLAKE3 fork with a multi-chunk prefix (CV stack in play)
(let* ([prefix (make-bytes 3000 42)]
       [d (make-digest 'blake3)])
  (digest-update! d prefix)
  (define d2 (digest-copy d))
  (digest-update! d #"tail-a")
  (digest-update! d2 #"tail-b")
  (test (digest-bytes 'blake3 (bytes-append prefix #"tail-a")) digest-final! d)
  (test (digest-bytes 'blake3 (bytes-append prefix #"tail-b")) digest-final! d2))

;; peek returns the digest so far and leaves the context usable
(let ([d (make-digest 'sha256)])
  (digest-update! d #"hello ")
  (test (digest-bytes 'sha256 #"hello ") digest-peek d)
  (digest-update! d #"world")
  (test (digest-bytes 'sha256 #"hello world") digest-peek d)
  (test (digest-bytes 'sha256 #"hello world") digest-final! d))
;; XOF peek needs a length
(let ([d (make-digest 'shake128)])
  (digest-update! d #"abc")
  (test (digest-bytes 'shake128 #"abc" #:length 16) digest-peek d #:length 16))
;; a copy of a finalized digest is finalized too, and peek respects it
(err/rt-test (let ([d (make-digest 'sha256)])
               (digest-final! d)
               (digest-final! (digest-copy d)))
             exn:fail?)
(err/rt-test (let ([d (make-digest 'sha256)]) (digest-final! d) (digest-peek d))
             exn:fail?)

;; ----------------------------------------
;; Port input matches byte-string input

(test (digest-bytes 'sha256 #"hello world")
      values (digest-bytes 'sha256 (open-input-bytes #"hello world")))
(test (digest-bytes 'sha512 (make-bytes 100000 65))
      values (digest-bytes 'sha512 (open-input-bytes (make-bytes 100000 65))))

;; ----------------------------------------
;; Metadata

(test 32 digest-output-size 'sha256)
(test 64 digest-output-size 'sha512)
(test 64 digest-block-size 'sha256)
(test 136 digest-block-size 'sha3-256)
(test #t digest-xof? 'shake128)
(test #f digest-xof? 'sha256)
(test #t list? (member 'sha3-256 (digest-algorithms)))

;; ----------------------------------------
;; SHA-1 and MD5 (legacy, broken; vectors from FIPS 180-4 / RFC 1321)

(test "a9993e364706816aba3e25717850c26c9cd0d89d" hx 'sha1 #"abc")
(test "da39a3ee5e6b4b0d3255bfef95601890afd80709" hx 'sha1 #"")
(test "84983e441c3bd26ebaae4aa1f95129e5e54670f1"
      hx 'sha1 #"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")
(test "900150983cd24fb0d6963f7d28e17f72" hx 'md5 #"abc")
(test "d41d8cd98f00b204e9800998ecf8427e" hx 'md5 #"")
(test "9e107d9d372bb6826bd81d3542a419d6"
      hx 'md5 #"The quick brown fox jumps over the lazy dog")
(test 20 digest-output-size 'sha1)
(test 16 digest-output-size 'md5)

;; ----------------------------------------
;; Negative cases

(err/rt-test (digest-bytes 'sha999 #"x") exn:fail:contract?)       ; unknown alg
(err/rt-test (digest-bytes 'shake128 #"x") exn:fail:contract?)     ; XOF needs #:length
(err/rt-test (digest-output-size 'shake128) exn:fail:contract?)    ; XOF has no fixed size
(err/rt-test (digest-bytes 'sha256 "not bytes") exn:fail:contract?)
(err/rt-test (digest-bytes 'sha256 #"abc" #:length 0) exn:fail:contract?)
;; use after finalize
(err/rt-test (let ([d (make-digest 'sha256)]) (digest-final! d) (digest-update! d #"x"))
             exn:fail?)
(err/rt-test (let ([d (make-digest 'sha256)]) (digest-final! d) (digest-final! d))
             exn:fail?)

;; ----------------------------------------
;; HMAC (RFC 4231)

(define (hmac-hx alg key data) (bytes->hex-string (hmac-bytes alg key data)))

(test "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"
      hmac-hx 'sha256 (make-bytes 20 #x0b) #"Hi There")
(test "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
      hmac-hx 'sha256 #"Jefe" #"what do ya want for nothing?")
(test "773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe"
      hmac-hx 'sha256 (make-bytes 20 #xaa) (make-bytes 50 #xdd))
;; long key (> block size): hashed first
(test "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54"
      hmac-hx 'sha256 (make-bytes 131 #xaa) #"Test Using Larger Than Block-Size Key - Hash Key First")
(test (string-append "164b7a7bfcf819e2e395fbe73b56e0a387bd64222e831fd610270cd7ea250554"
                     "9758bf75c05a994a6d034f65f8f0e6fdcaeab1a34d4a6b4b636e070a38bce737")
      hmac-hx 'sha512 #"Jefe" #"what do ya want for nothing?")

;; HMAC incremental == one-shot
(let ([h (make-hmac 'sha256 #"key")])
  (hmac-update! h #"The quick brown fox ")
  (hmac-update! h #"jumps over the lazy dog")
  (test (hmac-bytes 'sha256 #"key" #"The quick brown fox jumps over the lazy dog")
        hmac-final! h))

;; HMAC copy: many MACs from one primed context, and mid-stream forks
(let ([base (make-hmac 'sha256 #"key")])
  (define h1 (hmac-copy base))
  (hmac-update! h1 #"message one")
  (test (hmac-bytes 'sha256 #"key" #"message one") hmac-final! h1)
  (define h2 (hmac-copy base))
  (hmac-update! h2 #"message two")
  (test (hmac-bytes 'sha256 #"key" #"message two") hmac-final! h2)
  (hmac-update! base #"shared prefix ")
  (define h3 (hmac-copy base))
  (hmac-update! base #"left")
  (hmac-update! h3 #"right")
  (test (hmac-bytes 'sha256 #"key" #"shared prefix left") hmac-final! base)
  (test (hmac-bytes 'sha256 #"key" #"shared prefix right") hmac-final! h3))
;; long key (hashed to a key block) through the primed-midstate path
(let* ([key (make-bytes 200 7)]
       [h (make-hmac 'sha512 key)])
  (hmac-update! h #"data")
  (test (hmac-bytes 'sha512 key #"data") hmac-final! h))
(err/rt-test (let ([h (make-hmac 'sha256 #"k")])
               (hmac-final! h)
               (hmac-final! (hmac-copy h)))
             exn:fail?)

;; HMAC with a SHA-3 digest
(test #t bytes? (hmac-bytes 'sha3-256 #"k" #"data"))

;; Negative: XOF cannot key an HMAC; finalized reuse
(err/rt-test (hmac-bytes 'shake128 #"k" #"d") exn:fail:contract?)
(err/rt-test (let ([h (make-hmac 'sha256 #"k")]) (hmac-final! h) (hmac-final! h)) exn:fail?)

(report-errs)
