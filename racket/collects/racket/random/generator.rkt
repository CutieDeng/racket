#lang racket/base

;; High-performance seedable pseudo-random generators, backed by the
;; built-in rktrandom subsystem (librktrandom). These are for
;; simulation, sampling, and randomized algorithms: deterministic
;; given a seed, NOT cryptographically secure. For secrets, use
;; `crypto-random-bytes` from `racket/crypto`.
;;
;; Scalar draws are served from a per-generator buffer refilled by
;; one C call per 8 KB, so a draw costs a few nanoseconds; bulk
;; fills go straight to the target byte string. A generator is not
;; thread-safe; use one generator per thread/place, created via
;; `rgen-jump!`-separated states or distinct `#:stream`s.

(require '#%linklet
         (for-syntax racket/base)
         racket/fixnum
         racket/flonum
         racket/unsafe/ops)

(provide rgen?
         rgen-algorithm
         rgen-algorithms
         make-rgen
         rgen-copy
         rgen-bytes!
         rgen-bytes
         rgen-u64
         rgen-fixnum
         rgen-integer
         rgen-real
         rgen-boolean
         rgen-normal
         rgen-exponential
         rgen-f64-bytes!
         rgen-normal-bytes!
         rgen-exponential-bytes!
         rgen-bounded-bytes!
         rgen-flvector
         rgen-flvector!
         rgen-fxvector
         rgen-jump!
         rgen-long-jump!
         rgen-fork
         rgen-shuffle!
         rgen-shuffle
         rgen-ref
         rgen-weighted-index
         current-rgen
         rktrandom-available?)

;; ----------------------------------------
;; primitive table

(define rktrandom-table
  (or (primitive-table '#%rktrandom)
      (error '#%rktrandom "rktrandom not supported by host")))

(define (prim n) (hash-ref rktrandom-table n))

(define rktrandom_state_size (prim 'rktrandom_state_size))
(define rktrandom_init       (prim 'rktrandom_init))
(define rktrandom_init_int   (prim 'rktrandom_init_int))
(define rktrandom_fill       (prim 'rktrandom_fill))
(define rktrandom_jump       (prim 'rktrandom_jump))
(define rktrandom_long_jump  (prim 'rktrandom_long_jump))
(define rktrandom_fill_f64     (prim 'rktrandom_fill_f64))
(define rktrandom_fill_normal  (prim 'rktrandom_fill_normal))
(define rktrandom_fill_exp     (prim 'rktrandom_fill_exp))
(define rktrandom_fill_bounded (prim 'rktrandom_fill_bounded))

(define rktrandom-available?
  (let ([p (hash-ref rktrandom-table 'rktrandom-available? #f)])
    (or (not p) (and (p) #t))))

(define algorithm-ids
  (hasheq 'xoshiro256++   (hash-ref rktrandom-table 'RKTRANDOM_XOSHIRO256PP)
          'xoshiro256**   (hash-ref rktrandom-table 'RKTRANDOM_XOSHIRO256SS)
          'xoroshiro128++ (hash-ref rktrandom-table 'RKTRANDOM_XOROSHIRO128PP)
          'sfc64          (hash-ref rktrandom-table 'RKTRANDOM_SFC64)
          'pcg64-dxsm     (hash-ref rktrandom-table 'RKTRANDOM_PCG64DXSM)
          'philox4x64     (hash-ref rktrandom-table 'RKTRANDOM_PHILOX4X64)))

(define (rgen-algorithms) (hash-keys algorithm-ids))

;; ----------------------------------------
;; generator objects

(define BUF-SIZE 8192)
(define DBUF-SIZE 4096) ; scalar normal/exponential refill: 512 doubles

;; `pos` is the next unread byte offset in `buf`; BUF-SIZE = empty.
;; `nbuf`/`ebuf` are lazily created buffers of C-generated normal and
;; exponential variates for the scalar draws.
(struct rgen (alg           ; symbol
              id            ; int generator id
              state         ; state byte string
              buf           ; refill buffer
              [pos #:mutable]
              [nbuf #:mutable] ; #f or bytes
              [npos #:mutable]
              [ebuf #:mutable]
              [epos #:mutable])
  #:authentic
  #:reflection-name 'random-generator)

(define (make-rgen-struct alg id state)
  (rgen alg id state (make-bytes BUF-SIZE) BUF-SIZE #f DBUF-SIZE #f DBUF-SIZE))

;; After any state-level reposition (jump, fork), buffered draws no
;; longer belong to the stream: drop them.
(define (rgen-drop-buffers! g)
  (set-rgen-pos! g BUF-SIZE)
  (set-rgen-npos! g DBUF-SIZE)
  (set-rgen-epos! g DBUF-SIZE))

(define (rgen-algorithm g) (rgen-alg g))

(define (make-rgen [seed #f]
                   #:algorithm [alg 'xoshiro256++]
                   #:stream [stream 0])
  (define id (hash-ref algorithm-ids alg
                       (lambda ()
                         (raise-argument-error 'make-rgen "(or/c 'xoshiro256++ 'xoshiro256** 'xoroshiro128++ 'sfc64 'pcg64-dxsm 'philox4x64)" alg))))
  (unless (exact-nonnegative-integer? stream)
    (raise-argument-error 'make-rgen "exact-nonnegative-integer?" stream))
  (define state (make-bytes (hash-ref rktrandom-table 'RKTRANDOM_STATE_SIZE) 0))
  (cond
    ;; a small integer seed takes the splitmix64-expansion path, so
    ;; the stream matches the C-level rktrandom_init_int convention
    [(and (exact-integer? seed)
          (<= 0 seed #x7FFFFFFFFFFFFFFF)
          (<= stream #x7FFFFFFFFFFFFFFF))
     (rktrandom_init_int id state seed stream)
     (make-rgen-struct alg id state)]
    [else
     (define seed-bytes
       (cond
         [(not seed)
          ;; fresh unpredictable stream from the crypto subsystem
          ((dynamic-require 'racket/private/crypto-core 'crypto-random-bytes) 32)]
         [(bytes? seed)
          (unless (= (bytes-length seed) 32)
            (raise-argument-error 'make-rgen "a 32-byte string" seed))
          seed]
         [(exact-integer? seed)
          ;; any exact integer: low 256 bits, sign folded in
          (define n (if (negative? seed)
                        (bitwise-xor (- seed) (arithmetic-shift 1 255))
                        seed))
          (define bs (make-bytes 32 0))
          (for ([i (in-range 32)])
            (bytes-set! bs i (bitwise-and (arithmetic-shift n (* -8 i)) 255)))
          bs]
         [else
          (raise-argument-error 'make-rgen "(or/c #f exact-integer? (and/c bytes? 32-byte))" seed)]))
     ;; large streams flow through the 64-bit C `seq` plus extra seed mixing
     (rgen-init-with id alg state seed-bytes stream)]))

(define (rgen-init-with id alg state seed-bytes stream)
  (define seq (bitwise-and stream #xFFFFFFFFFFFFFFFF))
  (define seed*
    (if (> stream #xFFFFFFFFFFFFFFFF)
        ;; fold high stream bits into the seed material
        (let ([bs (bytes-copy seed-bytes)]
              [hi (arithmetic-shift stream -64)])
          (for ([i (in-range 8)])
            (bytes-set! bs i (bitwise-xor (bytes-ref bs i)
                                          (bitwise-and (arithmetic-shift hi (* -8 i)) 255))))
          bs)
        seed-bytes))
  ;; seq crosses the C boundary as intptr_t; pass the low 63 bits and
  ;; fold bit 63 into the seed to stay fixnum-safe on the FFI edge
  (define seq* (bitwise-and seq #x7FFFFFFFFFFFFFFF))
  (define seed**
    (if (> seq #x7FFFFFFFFFFFFFFF)
        (let ([bs (bytes-copy seed*)])
          (bytes-set! bs 8 (bitwise-xor (bytes-ref bs 8) 1))
          bs)
        seed*))
  (rktrandom_init id state seed** 0 seq*)
  (make-rgen-struct alg id state))

(define (rgen-copy g)
  (rgen (rgen-alg g) (rgen-id g)
        (bytes-copy (rgen-state g))
        (bytes-copy (rgen-buf g))
        (rgen-pos g)
        (let ([nb (rgen-nbuf g)]) (and nb (bytes-copy nb)))
        (rgen-npos g)
        (let ([eb (rgen-ebuf g)]) (and eb (bytes-copy eb)))
        (rgen-epos g)))

;; ----------------------------------------
;; bulk fill

(define (rgen-bytes! g bstr [start 0] [end (bytes-length bstr)])
  (rktrandom_fill (rgen-id g) (rgen-state g) bstr start end)
  (void))

(define (rgen-bytes g n)
  (define bs (make-bytes n))
  (rgen-bytes! g bs)
  bs)

;; ----------------------------------------
;; buffered scalar draws
;;
;; The buffer is consumed in 8-byte steps; a refill is one C call.

(define-syntax-rule (with-word g word body ...)
  (let ([pos (rgen-pos g)])
    (let-values ([(buf pos*)
                  (if (unsafe-fx<= pos (- BUF-SIZE 8))
                      (values (rgen-buf g) pos)
                      (let ([buf (rgen-buf g)])
                        (rktrandom_fill (rgen-id g) (rgen-state g) buf 0 BUF-SIZE)
                        (values buf 0)))])
      (set-rgen-pos! g (unsafe-fx+ pos* 8))
      (let ([word (lambda (k) (unsafe-bytes-ref buf (unsafe-fx+ pos* k)))])
        body ...))))

;; Full 64-bit draw as an exact integer (allocates a bignum when the
;; top bits are set; prefer rgen-fixnum/rgen-real in hot code).
(define (rgen-u64 g)
  (with-word g b
    (bitwise-ior
     (unsafe-fxior (b 0)
                   (unsafe-fxior (unsafe-fxlshift (b 1) 8)
                                 (unsafe-fxior (unsafe-fxlshift (b 2) 16)
                                               (unsafe-fxlshift (b 3) 24))))
     (arithmetic-shift
      (unsafe-fxior (b 4)
                    (unsafe-fxior (unsafe-fxlshift (b 5) 8)
                                  (unsafe-fxior (unsafe-fxlshift (b 6) 16)
                                                (unsafe-fxlshift (b 7) 24))))
      32))))

;; 56 uniform random bits as a nonnegative fixnum (fixnum-safe on all
;; 64-bit Racket CS builds).
(define (rgen-fixnum g)
  (with-word g b
    (unsafe-fxior
     (unsafe-fxior (b 0)
                   (unsafe-fxior (unsafe-fxlshift (b 1) 8)
                                 (unsafe-fxior (unsafe-fxlshift (b 2) 16)
                                               (unsafe-fxlshift (b 3) 24))))
     (unsafe-fxior (unsafe-fxlshift (b 4) 32)
                   (unsafe-fxior (unsafe-fxlshift (b 5) 40)
                                 (unsafe-fxlshift (b 6) 48))))))

;; Uniform [0,1) with 53 random bits: (hi27 * 2^26 + lo26) * 2^-53.
(define (rgen-real g)
  (with-word g b
    (define lo26
      (unsafe-fxior (b 0)
                    (unsafe-fxior (unsafe-fxlshift (b 1) 8)
                                  (unsafe-fxlshift (unsafe-fxand (b 2) #x3F) 16))))
    (define hi27
      (unsafe-fxior (b 3)
                    (unsafe-fxior (unsafe-fxlshift (b 4) 8)
                                  (unsafe-fxior (unsafe-fxlshift (b 5) 16)
                                                (unsafe-fxlshift (unsafe-fxand (b 6) #x7) 24)))))
    (fl* (fl+ (fl* (fx->fl hi27) 67108864.0) ; 2^26
              (fx->fl lo26))
         1.1102230246251565e-16)))           ; 2^-53

;; 60 uniform random bits as a nonnegative fixnum (internal; public
;; rgen-fixnum stays at 56 bits for headroom in user arithmetic).
(define (rgen-fixnum60 g)
  (with-word g b
    (unsafe-fxior
     (unsafe-fxior (unsafe-fxior (b 0)
                                 (unsafe-fxior (unsafe-fxlshift (b 1) 8)
                                               (unsafe-fxior (unsafe-fxlshift (b 2) 16)
                                                             (unsafe-fxlshift (b 3) 24))))
                   (unsafe-fxior (unsafe-fxlshift (b 4) 32)
                                 (unsafe-fxior (unsafe-fxlshift (b 5) 40)
                                               (unsafe-fxlshift (b 6) 48))))
     (unsafe-fxlshift (unsafe-fxand (b 7) #xF) 56))))

;; Unbiased uniform integer in [0,n): masked rejection for n below
;; 2^60 (average < 2 draws), bignum path above that.
(define (rgen-integer g n)
  (cond
    [(and (fixnum? n) (unsafe-fx<= n 1152921504606846975)) ; 2^60-1
     (unless (unsafe-fx> n 0)
       (raise-argument-error 'rgen-integer "exact-positive-integer?" n))
     (define mask (unsafe-fx- (next-pow2 n) 1))
     (let loop ()
       (define v (unsafe-fxand (rgen-fixnum60 g) mask))
       (if (unsafe-fx< v n) v (loop)))]
    [(and (exact-integer? n) (positive? n))
     ;; wide path: assemble ceil(bits/56) fixnum draws, reject
     (define bits (integer-length (- n 1)))
     (let loop ()
       (define v (let build ([acc 0] [got 0])
                   (if (>= got bits)
                       (bitwise-and acc (- (arithmetic-shift 1 bits) 1))
                       (build (bitwise-ior (arithmetic-shift acc 56) (rgen-fixnum g))
                              (+ got 56)))))
       (if (< v n) v (loop)))]
    [else
     (raise-argument-error 'rgen-integer "exact-positive-integer?" n)]))

(define (next-pow2 n)
  (unsafe-fxlshift 1 (integer-length (unsafe-fx- n 1))))

(define rgen-boolean
  (case-lambda
    [(g) (with-word g b (unsafe-fx< (unsafe-fxand (b 0) 1) 1))]
    [(g p) (fl< (rgen-real g) (real->double-flonum p))]))

;; ----------------------------------------
;; fused distribution fills
;;
;; Whole vectors of variates in one C call: no per-element FFI, no
;; user-side composition. Byte-string variants write native-endian
;; doubles (or little-endian uint64s for the bounded fill) and are
;; the zero-copy fast path; the flvector/fxvector variants copy out
;; of an internal chunk with scaling fused into the copy loop.

(define (check-f64-span who start end)
  (unless (and (fixnum? start) (fixnum? end)
               (fx<= start end)
               (fx= 0 (fxand (fx- end start) 7)))
    (raise-arguments-error who "byte range must be nonempty-ok and a multiple of 8"
                           "start" start "end" end)))

(define (rgen-f64-bytes! g bstr [start 0] [end (bytes-length bstr)])
  (check-f64-span 'rgen-f64-bytes! start end)
  (rktrandom_fill_f64 (rgen-id g) (rgen-state g) bstr start end)
  (void))

(define (rgen-normal-bytes! g bstr [start 0] [end (bytes-length bstr)])
  (check-f64-span 'rgen-normal-bytes! start end)
  (rktrandom_fill_normal (rgen-id g) (rgen-state g) bstr start end)
  (void))

(define (rgen-exponential-bytes! g bstr [start 0] [end (bytes-length bstr)])
  (check-f64-span 'rgen-exponential-bytes! start end)
  (rktrandom_fill_exp (rgen-id g) (rgen-state g) bstr start end)
  (void))

(define (rgen-bounded-bytes! g bound bstr [start 0] [end (bytes-length bstr)])
  (check-f64-span 'rgen-bounded-bytes! start end)
  (unless (and (fixnum? bound) (fx> bound 0))
    (raise-argument-error 'rgen-bounded-bytes! "positive fixnum" bound))
  (rktrandom_fill_bounded (rgen-id g) (rgen-state g) bstr start end bound)
  (void))

;; Fills `flv` with variates; scaling (mu/sigma, rate) is fused into
;; the copy loop. Works through a bounded scratch chunk so peak extra
;; memory stays at 64 KB regardless of vector size.
(define SCRATCH-DOUBLES 8192)

(define (rgen-flvector! g flv
                        [dist 'uniform]
                        #:mu [mu 0.0] #:sigma [sigma 1.0] #:rate [rate 1.0])
  (define n (flvector-length flv))
  (define fill
    (case dist
      [(uniform) rktrandom_fill_f64]
      [(normal) rktrandom_fill_normal]
      [(exponential) rktrandom_fill_exp]
      [else (raise-argument-error 'rgen-flvector! "(or/c 'uniform 'normal 'exponential)" dist)]))
  (define mu* (real->double-flonum mu))
  (define sigma* (real->double-flonum sigma))
  (define inv-rate (fl/ 1.0 (real->double-flonum rate)))
  (define scratch (make-bytes (* 8 (min n SCRATCH-DOUBLES))))
  (define big? (system-big-endian?))
  (let loop ([done 0])
    (when (fx< done n)
      (define m (fxmin (fx- n done) SCRATCH-DOUBLES))
      (fill (rgen-id g) (rgen-state g) scratch 0 (fx* m 8))
      (for ([i (in-range m)])
        (define x (floating-point-bytes->real scratch big? (fx* i 8) (fx* (fx+ i 1) 8)))
        (unsafe-flvector-set!
         flv (fx+ done i)
         (case dist
           [(uniform) x]
           [(normal) (fl+ mu* (fl* sigma* x))]
           [else (fl* inv-rate x)])))
      (loop (fx+ done m))))
  (void))

(define (rgen-flvector g n
                       [dist 'uniform]
                       #:mu [mu 0.0] #:sigma [sigma 1.0] #:rate [rate 1.0])
  (define flv (make-flvector n))
  (rgen-flvector! g flv dist #:mu mu #:sigma sigma #:rate rate)
  flv)

;; Uniform integers in [0,bound) as an fxvector; bound is limited to
;; 2^60-1 so every element reads back as a fixnum.
(define (rgen-fxvector g n bound)
  (unless (and (fixnum? bound) (fx> bound 0) (fx<= bound 1152921504606846975))
    (raise-argument-error 'rgen-fxvector "positive fixnum < 2^60" bound))
  (define fxv (make-fxvector n))
  (define scratch (make-bytes (* 8 (min n SCRATCH-DOUBLES))))
  (let loop ([done 0])
    (when (fx< done n)
      (define m (fxmin (fx- n done) SCRATCH-DOUBLES))
      (rktrandom_fill_bounded (rgen-id g) (rgen-state g) scratch 0 (fx* m 8) bound)
      (for ([i (in-range m)])
        (define base (fx* i 8))
        (unsafe-fxvector-set!
         fxv (fx+ done i)
         (unsafe-fxior
          (unsafe-fxior (unsafe-bytes-ref scratch base)
                        (unsafe-fxior (unsafe-fxlshift (unsafe-bytes-ref scratch (fx+ base 1)) 8)
                                      (unsafe-fxior (unsafe-fxlshift (unsafe-bytes-ref scratch (fx+ base 2)) 16)
                                                    (unsafe-fxlshift (unsafe-bytes-ref scratch (fx+ base 3)) 24))))
          (unsafe-fxior (unsafe-fxlshift (unsafe-bytes-ref scratch (fx+ base 4)) 32)
                        (unsafe-fxior (unsafe-fxlshift (unsafe-bytes-ref scratch (fx+ base 5)) 40)
                                      (unsafe-fxior (unsafe-fxlshift (unsafe-bytes-ref scratch (fx+ base 6)) 48)
                                                    (unsafe-fxlshift (unsafe-bytes-ref scratch (fx+ base 7)) 56)))))))
      (loop (fx+ done m))))
  fxv)

;; ----------------------------------------
;; buffered scalar variates

(define big-endian? (system-big-endian?))

(define (rgen-normal-raw g)
  (define pos (rgen-npos g))
  (define buf
    (cond
      [(fx<= pos (fx- DBUF-SIZE 8)) (rgen-nbuf g)]
      [else
       (define buf (or (rgen-nbuf g)
                       (let ([b (make-bytes DBUF-SIZE)])
                         (set-rgen-nbuf! g b)
                         b)))
       (rktrandom_fill_normal (rgen-id g) (rgen-state g) buf 0 DBUF-SIZE)
       (set-rgen-npos! g 0)
       buf]))
  (define p (rgen-npos g))
  (set-rgen-npos! g (fx+ p 8))
  (floating-point-bytes->real buf big-endian? p (fx+ p 8)))

(define rgen-normal
  (case-lambda
    [(g) (rgen-normal-raw g)]
    [(g mu) (fl+ (real->double-flonum mu) (rgen-normal-raw g))]
    [(g mu sigma) (fl+ (real->double-flonum mu)
                       (fl* (real->double-flonum sigma) (rgen-normal-raw g)))]))

(define (rgen-exponential-raw g)
  (define pos (rgen-epos g))
  (define buf
    (cond
      [(fx<= pos (fx- DBUF-SIZE 8)) (rgen-ebuf g)]
      [else
       (define buf (or (rgen-ebuf g)
                       (let ([b (make-bytes DBUF-SIZE)])
                         (set-rgen-ebuf! g b)
                         b)))
       (rktrandom_fill_exp (rgen-id g) (rgen-state g) buf 0 DBUF-SIZE)
       (set-rgen-epos! g 0)
       buf]))
  (define p (rgen-epos g))
  (set-rgen-epos! g (fx+ p 8))
  (floating-point-bytes->real buf big-endian? p (fx+ p 8)))

(define rgen-exponential
  (case-lambda
    [(g) (rgen-exponential-raw g)]
    [(g rate) (fl/ (rgen-exponential-raw g) (real->double-flonum rate))]))

;; ----------------------------------------
;; substreams

(define (rgen-jump! g)
  (unless (= 1 (rktrandom_jump (rgen-id g) (rgen-state g)))
    (raise-arguments-error 'rgen-jump! "generator has no jump function"
                           "algorithm" (rgen-alg g)))
  (rgen-drop-buffers! g)
  (void))

(define (rgen-long-jump! g)
  (unless (= 1 (rktrandom_long_jump (rgen-id g) (rgen-state g)))
    (raise-arguments-error 'rgen-long-jump! "generator has no long-jump function"
                           "algorithm" (rgen-alg g)))
  (rgen-drop-buffers! g)
  (void))

;; Returns a new generator whose stream is separated from g's by one
;; jump, advancing g past the region the child will use.
(define (rgen-fork g)
  (define child (rgen-copy g))
  (rgen-jump! g)
  (rgen-drop-buffers! child)
  child)

;; ----------------------------------------
;; per-thread default generator
;;
;; Generators are not thread-safe, so the default is one lazily
;; created, OS-entropy-seeded generator per thread (and hence per
;; place); it is not preserved across `thread` creation.

(define current-rgen-cell (make-thread-cell #f #f))

(define (current-rgen)
  (or (thread-cell-ref current-rgen-cell)
      (let ([g (make-rgen)])
        (thread-cell-set! current-rgen-cell g)
        g)))

;; ----------------------------------------
;; collection operations

(define (rgen-shuffle! g vec)
  (define n (vector-length vec))
  (let loop ([i (- n 1)])
    (when (> i 0)
      (define j (rgen-integer g (+ i 1)))
      (define tmp (vector-ref vec i))
      (vector-set! vec i (vector-ref vec j))
      (vector-set! vec j tmp)
      (loop (- i 1))))
  (void))

(define (rgen-shuffle g lst)
  (define vec (list->vector lst))
  (rgen-shuffle! g vec)
  (vector->list vec))

(define (rgen-ref g seq)
  (cond
    [(vector? seq) (vector-ref seq (rgen-integer g (vector-length seq)))]
    [(list? seq) (list-ref seq (rgen-integer g (length seq)))]
    [(bytes? seq) (bytes-ref seq (rgen-integer g (bytes-length seq)))]
    [(string? seq) (string-ref seq (rgen-integer g (string-length seq)))]
    [else (raise-argument-error 'rgen-ref "(or/c vector? list? bytes? string?)" seq)]))

;; Draws an index with probability proportional to weights (a vector
;; of nonnegative reals).
(define (rgen-weighted-index g weights)
  (define n (vector-length weights))
  (when (zero? n)
    (raise-argument-error 'rgen-weighted-index "non-empty vector" weights))
  (define total
    (for/fold ([acc 0.0]) ([w (in-vector weights)])
      (+ acc (real->double-flonum w))))
  (define x (fl* (rgen-real g) total))
  (let loop ([i 0] [acc 0.0])
    (define acc* (fl+ acc (real->double-flonum (vector-ref weights i))))
    (if (or (fl< x acc*) (= i (- n 1)))
        i
        (loop (+ i 1) acc*))))
