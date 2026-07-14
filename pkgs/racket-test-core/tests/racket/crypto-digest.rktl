
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
;; Negative cases

(err/rt-test (digest-bytes 'md5 #"x") exn:fail:contract?)          ; unknown alg
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

;; HMAC with a SHA-3 digest
(test #t bytes? (hmac-bytes 'sha3-256 #"k" #"data"))

;; Negative: XOF cannot key an HMAC; finalized reuse
(err/rt-test (hmac-bytes 'shake128 #"k" #"d") exn:fail:contract?)
(err/rt-test (let ([h (make-hmac 'sha256 #"k")]) (hmac-final! h) (hmac-final! h)) exn:fail?)

(report-errs)
