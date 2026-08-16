#lang racket/base

;; TLS 1.2 (RFC 5246 + RFC 5288 GCM + RFC 7905 ChaCha20-Poly1305 + RFC 7627
;; extended master secret) client and server, sharing the record framing,
;; transcript, and byte helpers with the 1.3 engine. ECDHE key exchange
;; only (X25519 / P-256 / P-384); AEAD cipher suites only. The PRF is
;; HMAC-based (SHA-256 or SHA-384 per suite). All crypto is in rktcrypto C.

(require "rktcrypto-ffi.rkt"
         "rktcrypto-x509.rkt"
         "rktcrypto-verify.rkt"
         "rktcrypto-tls13.rkt")   ; shared record layer, hsr, transcript, helpers

(provide tls12-client-finish
         tls12-accept
         tls12-suites)

;; ---- cipher suites (IANA) -> (values kx sig aead key-len prf-alg) ----
;; kx is always ecdhe; sig is 'rsa or 'ecdsa (server auth).
(define (suite12 id)
  (case id
    [(#xC02F) (values 'rsa   AEAD-AES128-GCM 16 SHA256)] ; ECDHE-RSA-AES128-GCM-SHA256
    [(#xC02B) (values 'ecdsa AEAD-AES128-GCM 16 SHA256)] ; ECDHE-ECDSA-AES128-GCM-SHA256
    [(#xC030) (values 'rsa   AEAD-AES256-GCM 32 SHA384)] ; ECDHE-RSA-AES256-GCM-SHA384
    [(#xC02C) (values 'ecdsa AEAD-AES256-GCM 32 SHA384)] ; ECDHE-ECDSA-AES256-GCM-SHA384
    [(#xCCA8) (values 'rsa   AEAD-CHACHA20-POLY1305 32 SHA256)] ; ECDHE-RSA-CHACHA20
    [(#xCCA9) (values 'ecdsa AEAD-CHACHA20-POLY1305 32 SHA256)] ; ECDHE-ECDSA-CHACHA20
    [else (values #f #f #f #f)]))
;; Client offer order (server auth type is filtered by the cert at runtime).
;; A function so it can be lazy-required from the 1.3 module without a cycle.
(define (tls12-suites) (list #xC02B #xC02F #xC02C #xC030 #xCCA9 #xCCA8))

(define GROUP-X25519 #x001d)
(define GROUP-P256   #x0017)
(define GROUP-P384   #x0018)

;; ---- HMAC-based PRF (RFC 5246 sec 5) ----
(define (p-hash alg secret seed out-len)
  ;; A(0)=seed; A(i)=HMAC(secret,A(i-1)); output = HMAC(secret,A(i)||seed)...
  (let loop ([a (hmac alg secret seed)] [acc #""])
    (if (>= (bytes-length acc) out-len)
        (subbytes acc 0 out-len)
        (loop (hmac alg secret a)
              (bytes-append acc (hmac alg secret (bytes-append a seed)))))))
(define (prf alg secret label seed out-len)
  (p-hash alg secret (bytes-append label seed) out-len))

;; =====================================================================
;; 1.2 AEAD record layer
;; =====================================================================
;; keys: client/server write key + fixed IV. GCM uses a 4-byte fixed IV +
;; 8-byte explicit nonce (sent on the wire); ChaCha20 uses a 12-byte fixed
;; IV XORed with the sequence number (RFC 7905), no explicit nonce.
(struct r12 (in out aead
             ckey cfixed skey sfixed
             chacha?
             [rseq #:mutable] [wseq #:mutable]
             we-are-client?))

(define (seq->bytes n)
  (bytes (bitwise-and (arithmetic-shift n -56) 255) (bitwise-and (arithmetic-shift n -48) 255)
         (bitwise-and (arithmetic-shift n -40) 255) (bitwise-and (arithmetic-shift n -32) 255)
         (bitwise-and (arithmetic-shift n -24) 255) (bitwise-and (arithmetic-shift n -16) 255)
         (bitwise-and (arithmetic-shift n -8) 255) (bitwise-and n 255)))

(define (aad seq type len)
  (bytes-append (seq->bytes seq) (bytes type 3 3)
                (bytes (arithmetic-shift len -8) (bitwise-and len 255))))

(define (xor-iv fixed seq)
  (define n (bytes-copy fixed))       ; 12 bytes
  (define s (seq->bytes seq))
  (for ([i (in-range 8)])
    (bytes-set! n (+ 4 i) (bitwise-xor (bytes-ref n (+ 4 i)) (bytes-ref s i))))
  n)

;; write one record (already the plaintext fragment for `type`)
(define (r12-write r type frag)
  (define seq (r12-wseq r))
  (define key (if (r12-we-are-client? r) (r12-ckey r) (r12-skey r)))
  (define fixed (if (r12-we-are-client? r) (r12-cfixed r) (r12-sfixed r)))
  (define a (aad seq type (bytes-length frag)))
  (define body
    (cond
      [(r12-chacha? r)
       (define nonce (xor-iv fixed seq))
       (aead-seal (r12-aead r) key nonce a frag)]
      [else
       (define expl (subbytes (seq->bytes seq) 0 8))
       (define nonce (bytes-append fixed expl))
       (bytes-append expl (aead-seal (r12-aead r) key nonce a frag))]))
  (set-r12-wseq! r (add1 seq))
  (with-transport-errors
    (write-bytes (bytes-append (bytes type 3 3)
                               (bytes (arithmetic-shift (bytes-length body) -8) (bitwise-and (bytes-length body) 255))
                               body)
                 (r12-out r))
    (flush-output (r12-out r))))

(define (read-exact in n)
  (define bs (with-transport-errors (read-bytes n in)))
  (when (or (eof-object? bs) (< (bytes-length bs) n)) (raise (tls-error "EOF in 1.2 record")))
  bs)

;; read one record -> (values type plaintext)  (plaintext #f for pass-through CCS)
(define (r12-read r)
  (define hdr (read-exact (r12-in r) 5))
  (define type (bytes-ref hdr 0))
  (define len (+ (* 256 (bytes-ref hdr 3)) (bytes-ref hdr 4)))
  (define body (read-exact (r12-in r) len))
  (cond
    [(= type 20) (values 20 #f)]                 ; change_cipher_spec (plaintext)
    [(and (= type 21) (not (r12-cseq-installed? r)))
     (values 21 body)]
    [else
     (define seq (r12-rseq r))
     (define key (if (r12-we-are-client? r) (r12-skey r) (r12-ckey r)))
     (define fixed (if (r12-we-are-client? r) (r12-sfixed r) (r12-cfixed r)))
     (define-values (nonce ct)
       (if (r12-chacha? r)
           (values (xor-iv fixed seq) body)
           (values (bytes-append fixed (subbytes body 0 8)) (subbytes body 8))))
     (define a (aad seq type (- (bytes-length ct) (aead-tag (r12-aead r)))))
     (define pt (aead-open (r12-aead r) key nonce a ct))
     (unless pt (raise (tls-alert 20 "bad_record_mac")))
     (set-r12-rseq! r (add1 seq))
     (values type pt)]))

(define (aead-tag aead) (rktcrypto_aead_tag_size aead))
;; reads are always encrypted once we build r12 post-CCS; CCS handled above
(define (r12-cseq-installed? r) #t)

;; =====================================================================
;; Client: continue after ServerHello chose TLS 1.2
;; =====================================================================
;; Args: r (record layer from tls13, plaintext), hs (hsr), transcript-bytes
;; (CH||SH already accumulated as raw bytes), sh (ServerHello msg),
;; client-random, server chosen fields, opts.
(define (tls12-client-finish rl-in rl-out hs raw-transcript sh client-random opts)
  (define host (hash-ref opts 'host #f))
  (define verify? (hash-ref opts 'verify? #t))
  (define anchors (hash-ref opts 'trust-anchors '()))
  ;; parse ServerHello
  (define server-random (subbytes sh 6 38))
  (define sid-len (bytes-ref sh 38))
  (define pos (+ 39 sid-len))
  (define suite (+ (* 256 (bytes-ref sh pos)) (bytes-ref sh (add1 pos))))
  (define exts-em? (sh-has-ems? sh pos))
  ;; A2 (1.2): resumption is signalled by the server echoing our (non-empty)
  ;; session_id (RFC 5077 §3.4) when we offered a ticket.
  (define ticket12-box (hash-ref opts 'ticket12-box #f))
  (define resuming?
    (and ticket12-box (vector? (unbox ticket12-box))
         (let* ([ch1 (subbytes raw-transcript 0 (- (bytes-length raw-transcript) (bytes-length sh)))]
                [csid (subbytes ch1 39 (+ 39 (bytes-ref ch1 38)))]
                [ssid (subbytes sh 39 (+ 39 sid-len))])
           (and (positive? (bytes-length csid)) (equal? csid ssid)))))
  (cond
   [resuming? (tls12-client-resume rl-in rl-out raw-transcript sh client-random ticket12-box)]
   [else
  (define-values (sig-type aead key-len prf-alg) (suite12 suite))
  (unless aead (raise (tls-error "server chose unsupported 1.2 suite")))
  (define chacha? (= aead AEAD-CHACHA20-POLY1305))
  (define tr (box raw-transcript))
  (define (tr+ b) (set-box! tr (bytes-append (unbox tr) b)))

  ;; read Certificate, ServerKeyExchange, [CertificateRequest], ServerHelloDone
  (define peer-ders (box '()))
  (define ske (box #f))
  (define cert-requested? (box #f))
  (let loop ()
    (define-values (mt msg) (hsr-next hs))
    (tr+ msg)
    (case mt
      [(11) (set-box! peer-ders (parse-certificate-msg-12 msg)) (loop)]
      [(12) (set-box! ske msg) (loop)]
      [(13) (set-box! cert-requested? #t) (loop)]   ; CertificateRequest (A4)
      [(14) (void)]                              ; ServerHelloDone
      [else (raise (tls-error (format "unexpected 1.2 msg ~a" mt)))]))

  (when (null? (unbox peer-ders)) (raise (tls-error "server sent no certificate")))
  (define leaf (parse-certificate (car (unbox peer-ders))))

  ;; parse ServerKeyExchange: ECParams + pubkey + sig
  (define-values (group server-pub ske-sig-scheme ske-sig) (parse-ske (unbox ske)))
  ;; verify SKE signature over client_random||server_random||ECParams
  (define signed (bytes-append client-random server-random (ske-params (unbox ske))))
  (unless (verify-signature-over ske-sig-scheme (certificate-pub leaf) signed ske-sig)
    (raise (tls-alert 51 "ServerKeyExchange signature invalid")))
  ;; verify chain + hostname
  (when verify?
    (verify-chain (unbox peer-ders) anchors)
    (when host (check-hostname leaf host)))

  ;; our ECDHE key + premaster secret
  (define-values (our-priv our-pub) (gen-kx group))
  (define pms (ecdhe group our-priv server-pub))

  ;; A4: if the server asked for a client cert and we have one, send Certificate
  ;; before ClientKeyExchange (it precedes CKE in the flight and the transcript).
  (define client-key (hash-ref opts 'client-key #f))
  (define client-cert-ders (hash-ref opts 'client-cert-ders '()))
  (define send-client-cert? (and (unbox cert-requested?) client-key (pair? client-cert-ders)))
  (define ccert
    (and (unbox cert-requested?)
         (let ([b (vec 3 (apply bytes-append (for/list ([d (in-list client-cert-ders)]) (vec 3 d))))])
           (bytes-append (u8 11) (u24 (bytes-length b)) b))))     ; empty list -> empty Certificate
  (when ccert (tr+ ccert))

  ;; ClientKeyExchange (must be in the transcript before the extended-master-
  ;; secret session hash and the Finished hash are taken)
  (define cke-body (vec 1 our-pub))
  (define cke (bytes-append (u8 16) (u24 (bytes-length cke-body)) cke-body))
  (tr+ cke)

  ;; master secret (extended master secret if negotiated: session hash covers
  ;; ClientHello..ClientKeyExchange)
  (define master
    (if exts-em?
        (prf prf-alg pms #"extended master secret" (digest prf-alg (unbox tr)) 48)
        (prf prf-alg pms #"master secret" (bytes-append client-random server-random) 48)))

  ;; SSLKEYLOGFILE line so Wireshark can decrypt a 1.2 session (de-facto format):
  ;; CLIENT_RANDOM <client_random> <master_secret>.
  (let ([kl (hash-ref opts 'keylog #f)])
    (when kl
      (define (hx bs) (apply string-append (for/list ([b (in-bytes bs)])
                        (let ([s (number->string b 16)]) (if (= 1 (string-length s)) (string-append "0" s) s)))))
      (kl (string-append "CLIENT_RANDOM " (hx client-random) " " (hx master)))))
  ;; key block
  (define fixed-iv-len (if chacha? 12 4))
  (define kb (prf prf-alg master #"key expansion"
                  (bytes-append server-random client-random)
                  (+ (* 2 key-len) (* 2 fixed-iv-len))))
  (define ckey (subbytes kb 0 key-len))
  (define skey (subbytes kb key-len (* 2 key-len)))
  (define cfixed (subbytes kb (* 2 key-len) (+ (* 2 key-len) fixed-iv-len)))
  (define sfixed (subbytes kb (+ (* 2 key-len) fixed-iv-len) (+ (* 2 key-len) (* 2 fixed-iv-len))))

  ;; A4: CertificateVerify signs the handshake so far (CH..Certificate..CKE).
  (define ccv
    (and send-client-cert?
         (let* ([scheme (if (eq? (car client-key) 'p256) #x0403 #x0804)]
                [sig (sign-12 client-key scheme (unbox tr))]
                [body (bytes-append (u16 scheme) (vec 2 sig))])
           (bytes-append (u8 15) (u24 (bytes-length body)) body))))
  (when ccv (tr+ ccv))

  ;; send [Certificate], CKE, [CertificateVerify], CCS, then encrypted Finished
  (when ccert (write-plaintext rl-out 22 ccert))
  (write-plaintext rl-out 22 cke)
  (when ccv (write-plaintext rl-out 22 ccv))
  (write-plaintext rl-out 20 (bytes 1))         ; ChangeCipherSpec

  (define r (r12 rl-in rl-out aead ckey cfixed skey sfixed chacha? 0 0 #t))

  ;; client Finished: PRF(master,"client finished",Hash(handshake))[0:12]
  (define cfin-vd (prf prf-alg master #"client finished" (digest prf-alg (unbox tr)) 12))
  (define cfin (bytes-append (u8 20) (u24 12) cfin-vd))
  (tr+ cfin)
  (r12-write r 22 cfin)

  ;; read the server's second flight: an optional NewSessionTicket (plaintext,
  ;; before the server ChangeCipherSpec, and covered by the server Finished
  ;; hash), then CCS, then the encrypted Finished. A2 (1.2): cache the ticket.
  (let loop ()
    (define hdr (read-exact rl-in 5))
    (define rlen (+ (* 256 (bytes-ref hdr 3)) (bytes-ref hdr 4)))
    (define body (read-exact rl-in rlen))
    (cond
      [(= (bytes-ref hdr 0) 20) (void)]                                        ; ChangeCipherSpec
      [(and (= (bytes-ref hdr 0) 22) (>= (bytes-length body) 1) (= (bytes-ref body 0) 4)) ; NewSessionTicket
       (tr+ body)
       (when ticket12-box
         (let ([tlen (+ (* 256 (bytes-ref body 8)) (bytes-ref body 9))])
           (when (positive? tlen)
             (set-box! ticket12-box (vector (subbytes body 10 (+ 10 tlen)) master suite (and exts-em? #t))))))
       (loop)]
      [else (loop)]))
  (define-values (ftype fmsg) (r12-read-handshake r))
  (unless (= ftype 20) (raise (tls-error "expected server Finished")))
  (define expect-sfin (prf prf-alg master #"server finished" (digest prf-alg (unbox tr)) 12))
  (unless (ct-equal? expect-sfin (subbytes fmsg 4)) (raise (tls-alert 51 "server Finished mismatch")))

  (make-conn-12 r (unbox peer-ders) cfin-vd)]))

;; A2 (1.2): abbreviated (resumption) client handshake. Keys come from the cached
;; master secret; read the server's [NewSessionTicket] + CCS + Finished, then send
;; our CCS + Finished. No Certificate/ServerKeyExchange in either direction.
(define (tls12-client-resume rl-in rl-out raw-transcript sh client-random ticket12-box)
  (define server-random (subbytes sh 6 38))
  (define sid-len (bytes-ref sh 38))
  (define suite (let ([p (+ 39 sid-len)]) (+ (* 256 (bytes-ref sh p)) (bytes-ref sh (add1 p)))))
  (define-values (sig-type aead key-len prf-alg) (suite12 suite))
  (define chacha? (= aead AEAD-CHACHA20-POLY1305))
  (define rec (unbox ticket12-box))            ; #(ticket master suite ems?)
  (define master (vector-ref rec 1))
  (define ems? (vector-ref rec 3))
  (define tr (box raw-transcript))             ; CH1 || SH
  (define (tr+ b) (set-box! tr (bytes-append (unbox tr) b)))
  (define fixed-iv-len (if chacha? 12 4))
  (define kb (prf prf-alg master #"key expansion" (bytes-append server-random client-random)
                  (+ (* 2 key-len) (* 2 fixed-iv-len))))
  (define ckey (subbytes kb 0 key-len))
  (define skey (subbytes kb key-len (* 2 key-len)))
  (define cfixed (subbytes kb (* 2 key-len) (+ (* 2 key-len) fixed-iv-len)))
  (define sfixed (subbytes kb (+ (* 2 key-len) fixed-iv-len) (+ (* 2 key-len) (* 2 fixed-iv-len))))
  (define r (r12 rl-in rl-out aead ckey cfixed skey sfixed chacha? 0 0 #t))
  ;; server flight: optional NewSessionTicket (plaintext) then ChangeCipherSpec
  (let loop ()
    (define hdr (read-exact rl-in 5))
    (define rlen (+ (* 256 (bytes-ref hdr 3)) (bytes-ref hdr 4)))
    (define body (read-exact rl-in rlen))
    (cond
      [(= (bytes-ref hdr 0) 20) (void)]                                        ; ChangeCipherSpec
      [(and (= (bytes-ref hdr 0) 22) (>= (bytes-length body) 1) (= (bytes-ref body 0) 4)) ; NewSessionTicket
       (tr+ body)
       (let ([tlen (+ (* 256 (bytes-ref body 8)) (bytes-ref body 9))])
         (when (positive? tlen) (set-box! ticket12-box (vector (subbytes body 10 (+ 10 tlen)) master suite ems?))))
       (loop)]
      [else (loop)]))
  (define-values (ft fmsg) (r12-read-handshake r))     ; encrypted server Finished
  (unless (= ft 20) (raise (tls-error "expected server Finished (resume)")))
  (define expect-sfin (prf prf-alg master #"server finished" (digest prf-alg (unbox tr)) 12))
  (unless (ct-equal? expect-sfin (subbytes fmsg 4)) (raise (tls-alert 51 "server Finished mismatch (resume)")))
  (tr+ fmsg)
  (write-plaintext rl-out 20 (bytes 1))                ; client ChangeCipherSpec
  (define cfin-vd (prf prf-alg master #"client finished" (digest prf-alg (unbox tr)) 12))
  (r12-write r 22 (bytes-append (u8 20) (u24 12) cfin-vd))
  (make-conn-12 r '() cfin-vd))

;; =====================================================================
;; Server (1.2)
;; =====================================================================
;; RFC 8446 §4.1.3 downgrade-protection sentinel a TLS-1.3-capable server writes
;; into the last 8 bytes of ServerHello.random when it negotiates TLS 1.2.
(define DOWNGRADE-12 #"\x44\x4f\x57\x4e\x47\x52\x44\x01")
(define (tls12-accept rl-in rl-out hs ch client-random suite opts)
  (define cert-ders (hash-ref opts 'cert-ders))
  (define key (hash-ref opts 'key))
  (define-values (sig-type aead key-len prf-alg) (suite12 suite))
  (unless aead (raise (tls-error "unsupported 1.2 suite (server)")))
  (define chacha? (= aead AEAD-CHACHA20-POLY1305))
  (define ch-exts (client-hello-exts ch))
  (define ems? (assoc #x0017 ch-exts))          ; extended_master_secret ext type = 0x0017
  ;; A2 (1.2) SessionTicket (RFC 5077): a store maps ticket bytes -> a session
  ;; record #(master suite ems? issued-ms). If the client presents a live ticket
  ;; for this suite we do an abbreviated handshake; otherwise, if it signalled
  ;; support (SessionTicket ext present), we issue one after the full handshake.
  (define ticket-store (hash-ref opts 'ticket-store #f))
  (define ticket-ext (assoc #x0023 ch-exts))
  (define presented-ticket (and ticket-ext (positive? (bytes-length (cdr ticket-ext))) (cdr ticket-ext)))
  (define resume-entry
    (and ticket-store presented-ticket
         (let ([e (hash-ref ticket-store presented-ticket #f)])
           (and e (= (vector-ref e 1) suite)
                (< (- (current-inexact-milliseconds) (vector-ref e 3)) (* 1000 7200)) e))))
  (define tr (box ch))                           ; transcript begins with ClientHello
  (define (tr+ b) (set-box! tr (bytes-append (unbox tr) b)))

  (cond
   [resume-entry
    ;; abbreviated handshake: recover the master secret, skip cert/kx
    (tls12-server-resume rl-in rl-out hs ch client-random suite (vector-ref resume-entry 0))]
   [else
  (define server-random
    (let ([r (random-bytes 32)]) (bytes-copy! r 24 DOWNGRADE-12) r)) ; downgrade sentinel
  ;; ServerHello (1.2)
  (define issue-ticket? (and ticket-store ticket-ext))    ; both sides support tickets
  (define sh-exts (bytes-append
                   (if ems? (ext #x0017 #"") #"")
                   (if issue-ticket? (ext #x0023 #"") #"")  ; SessionTicket: negotiate (empty in SH)
                   (ext #xff01 (vec 1 #""))))    ; renegotiation_info (empty)
  (define sh-body (bytes-append (u16 #x0303) server-random (vec 1 #"")
                                (u16 suite) (u8 0) (vec 2 sh-exts)))
  (define sh (bytes-append (u8 2) (u24 (bytes-length sh-body)) sh-body))
  (tr+ sh) (write-plaintext rl-out 22 sh)

  ;; Certificate
  (define cert-list (apply bytes-append (for/list ([d (in-list cert-ders)]) (vec 3 d))))
  (define cert-msg (let ([b (vec 3 cert-list)]) (bytes-append (u8 11) (u24 (bytes-length b)) b)))
  (tr+ cert-msg) (write-plaintext rl-out 22 cert-msg)

  ;; ServerKeyExchange: choose group from client's supported_groups
  (define group (choose-group ch-exts))
  (define-values (our-priv our-pub) (gen-kx group))
  (define ec-params (bytes-append (u8 3) (u16 group) (vec 1 our-pub)))  ; named_curve
  (define scheme (if (eq? sig-type 'ecdsa) #x0403 #x0804))
  (define signed (bytes-append client-random server-random ec-params))
  (define sig (sign-12 key scheme signed))
  (define ske-body (bytes-append ec-params (u16 scheme) (vec 2 sig)))
  (define ske (bytes-append (u8 12) (u24 (bytes-length ske-body)) ske-body))
  (tr+ ske) (write-plaintext rl-out 22 ske)

  ;; A4: CertificateRequest (ask the client to authenticate) if configured.
  (define request-client-cert? (hash-ref opts 'request-client-cert #f))
  (when request-client-cert?
    (define creq-body (bytes-append (vec 1 (bytes 64 1))                     ; ecdsa_sign, rsa_sign
                                    (vec 2 (bytes #x04 #x03 #x08 #x04 #x04 #x01)) ; sigalgs: ecdsa/rsapss/rsapkcs1-sha256
                                    (vec 2 #"")))                            ; certificate_authorities: empty
    (define creq (bytes-append (u8 13) (u24 (bytes-length creq-body)) creq-body))
    (tr+ creq) (write-plaintext rl-out 22 creq))

  ;; ServerHelloDone
  (define shd (bytes-append (u8 14) (u24 0)))
  (tr+ shd) (write-plaintext rl-out 22 shd)

  ;; read [Certificate], ClientKeyExchange, [CertificateVerify] (all plaintext)
  (define client-ders (box '()))
  (define cv-content (box #f)) (define cv-sig (box #f)) (define cv-scheme (box #f))
  (define cke (box #f))
  (let loop ()
    (define-values (mt msg) (hsr-next hs))
    (case mt
      [(11) (set-box! client-ders (parse-certificate-msg-12 msg)) (tr+ msg) (loop)]
      [(16) (set-box! cke msg) (tr+ msg)]                 ; ClientKeyExchange ends this flight
      [else (raise (tls-error (format "expected Certificate/ClientKeyExchange, got ~a" mt)))]))
  ;; EMS session hash is taken up to and including ClientKeyExchange (RFC 7627).
  (define ems-session-hash (digest prf-alg (unbox tr)))
  (when (pair? (unbox client-ders))                       ; client authenticated -> CertificateVerify
    (set-box! cv-content (bytes-copy (unbox tr)))          ; signed content = CH..CKE (raw)
    (define-values (cvt cvmsg) (hsr-next hs))
    (unless (= cvt 15) (raise (tls-error "expected CertificateVerify")))
    (set-box! cv-scheme (be->int cvmsg 4 6))
    (set-box! cv-sig (subbytes cvmsg 8 (+ 8 (be->int cvmsg 6 8))))
    (tr+ cvmsg))
  (define client-pub (subbytes (unbox cke) 5 (+ 5 (bytes-ref (unbox cke) 4))))
  (define pms (ecdhe group our-priv client-pub))
  (define master
    (if ems?
        (prf prf-alg pms #"extended master secret" ems-session-hash 48)
        (prf prf-alg pms #"master secret" (bytes-append client-random server-random) 48)))
  ;; A4: verify the client's certificate + CertificateVerify against policy.
  (when request-client-cert?
    (cond
      [(pair? (unbox client-ders))
       (unless (verify-signature-over (unbox cv-scheme) (certificate-pub (parse-certificate (car (unbox client-ders))))
                                      (unbox cv-content) (unbox cv-sig))
         (raise (tls-alert 51 "client CertificateVerify invalid")))
       (let ([anchors (hash-ref opts 'client-ca-anchors '())])
         (when (pair? anchors) (verify-chain (unbox client-ders) anchors)))]
      [(hash-ref opts 'require-client-cert #f)
       (with-handlers ([exn:fail? void]) (write-plaintext rl-out 21 (bytes 2 40))) ; handshake_failure alert
       (raise (tls-alert 40 "client certificate required"))]
      [else (void)]))
  (define fixed-iv-len (if chacha? 12 4))
  (define kb (prf prf-alg master #"key expansion" (bytes-append server-random client-random)
                  (+ (* 2 key-len) (* 2 fixed-iv-len))))
  (define ckey (subbytes kb 0 key-len))
  (define skey (subbytes kb key-len (* 2 key-len)))
  (define cfixed (subbytes kb (* 2 key-len) (+ (* 2 key-len) fixed-iv-len)))
  (define sfixed (subbytes kb (+ (* 2 key-len) fixed-iv-len) (+ (* 2 key-len) (* 2 fixed-iv-len))))
  (define r (r12 rl-in rl-out aead ckey cfixed skey sfixed chacha? 0 0 #f))

  ;; read client CCS + Finished
  (read-until-ccs rl-in)
  (define-values (cft cfmsg) (r12-read-handshake r))
  (unless (= cft 20) (raise (tls-error "expected client Finished")))
  (define expect-cfin (prf prf-alg master #"client finished" (digest prf-alg (unbox tr)) 12))
  (unless (ct-equal? expect-cfin (subbytes cfmsg 4)) (raise (tls-alert 51 "client Finished mismatch")))
  (define cfin-vd expect-cfin)   ; RFC 5929 tls-unique = client Finished verify_data
  (tr+ cfmsg)

  ;; A2 (1.2): issue a NewSessionTicket (RFC 5077) when the client signalled
  ;; SessionTicket support; it precedes the server ChangeCipherSpec (plaintext)
  ;; and is covered by the server Finished hash.
  (when (and ticket-store ticket-ext)
    (define ticket (random-bytes 48))
    (hash-set! ticket-store ticket (vector master suite (and ems? #t) (current-inexact-milliseconds)))
    (define nst-body (bytes-append (u32 7200) (vec 2 ticket)))
    (define nst (bytes-append (u8 4) (u24 (bytes-length nst-body)) nst-body))
    (tr+ nst)
    (write-plaintext rl-out 22 nst))

  ;; server CCS + Finished
  (write-plaintext rl-out 20 (bytes 1))
  (define sfin-vd (prf prf-alg master #"server finished" (digest prf-alg (unbox tr)) 12))
  (r12-write r 22 (bytes-append (u8 20) (u24 12) sfin-vd))
  (make-conn-12 r '() cfin-vd)]))

;; A2 (1.2): abbreviated (resumption) server handshake — ServerHello + CCS +
;; Finished first, then read the client's CCS + Finished. Keys come from the
;; recovered master secret and the new randoms (no Certificate/ServerKeyExchange).
(define (tls12-server-resume rl-in rl-out hs ch client-random suite master)
  (define-values (sig-type aead key-len prf-alg) (suite12 suite))
  (define chacha? (= aead AEAD-CHACHA20-POLY1305))
  (define tr (box ch))
  (define (tr+ b) (set-box! tr (bytes-append (unbox tr) b)))
  (define server-random (let ([r (random-bytes 32)]) (bytes-copy! r 24 DOWNGRADE-12) r))
  (define sid (let ([sl (bytes-ref ch 38)]) (subbytes ch 39 (+ 39 sl)))) ; echo the client's session id
  (define sh-exts (bytes-append (ext #x0023 #"") (ext #xff01 (vec 1 #""))))
  (define sh-body (bytes-append (u16 #x0303) server-random (vec 1 sid) (u16 suite) (u8 0) (vec 2 sh-exts)))
  (define sh (bytes-append (u8 2) (u24 (bytes-length sh-body)) sh-body))
  (tr+ sh) (write-plaintext rl-out 22 sh)
  (define fixed-iv-len (if chacha? 12 4))
  (define kb (prf prf-alg master #"key expansion" (bytes-append server-random client-random)
                  (+ (* 2 key-len) (* 2 fixed-iv-len))))
  (define ckey (subbytes kb 0 key-len))
  (define skey (subbytes kb key-len (* 2 key-len)))
  (define cfixed (subbytes kb (* 2 key-len) (+ (* 2 key-len) fixed-iv-len)))
  (define sfixed (subbytes kb (+ (* 2 key-len) fixed-iv-len) (+ (* 2 key-len) (* 2 fixed-iv-len))))
  (define r (r12 rl-in rl-out aead ckey cfixed skey sfixed chacha? 0 0 #f))
  (write-plaintext rl-out 20 (bytes 1))                       ; server ChangeCipherSpec
  (define sfin-vd (prf prf-alg master #"server finished" (digest prf-alg (unbox tr)) 12))
  (tr+ (bytes-append (u8 20) (u24 12) sfin-vd))               ; server Finished in the transcript
  (r12-write r 22 (bytes-append (u8 20) (u24 12) sfin-vd))
  (read-until-ccs rl-in)
  (define-values (cft cfmsg) (r12-read-handshake r))
  (unless (= cft 20) (raise (tls-error "expected client Finished (resume)")))
  (define expect-cfin (prf prf-alg master #"client finished" (digest prf-alg (unbox tr)) 12))
  (unless (ct-equal? expect-cfin (subbytes cfmsg 4)) (raise (tls-alert 51 "client Finished mismatch (resume)")))
  (make-conn-12 r '() expect-cfin))

;; =====================================================================
;; helpers
;; =====================================================================
(define (write-plaintext out type payload)
  (with-transport-errors
    (write-bytes (bytes-append (bytes type 3 3)
                               (bytes (arithmetic-shift (bytes-length payload) -8) (bitwise-and (bytes-length payload) 255))
                               payload) out)
    (flush-output out)))

;; Read raw records until a ChangeCipherSpec passes (discard it). Handshake
;; records that arrive before are buffered by the caller's hsr already.
(define (read-until-ccs in)
  (let loop ()
    (define hdr (read-exact in 5))
    (define len (+ (* 256 (bytes-ref hdr 3)) (bytes-ref hdr 4)))
    (define body (read-exact in len))
    (unless (= (bytes-ref hdr 0) 20) (loop))))

;; Read one handshake message from the encrypted 1.2 stream.
(define (r12-read-handshake r)
  (let loop ()
    (define-values (type pt) (r12-read r))
    (cond
      [(= type 20) (loop)]
      [(= type 22) (values (bytes-ref pt 0) pt)]
      [(= type 21) (raise (tls-alert (if (>= (bytes-length pt) 2) (bytes-ref pt 1) 0) "fatal"))]
      [else (loop)])))

(define (parse-certificate-msg-12 msg)
  ;; handshake header(4) certificate_list(vec3 of vec3 cert)
  (define list-len (+ (* 65536 (bytes-ref msg 4)) (* 256 (bytes-ref msg 5)) (bytes-ref msg 6)))
  (let loop ([pos 7] [acc '()])
    (if (>= pos (+ 7 list-len))
        (reverse acc)
        (let ([clen (+ (* 65536 (bytes-ref msg pos)) (* 256 (bytes-ref msg (+ pos 1))) (bytes-ref msg (+ pos 2)))])
          (loop (+ pos 3 clen) (cons (subbytes msg (+ pos 3) (+ pos 3 clen)) acc))))))

;; ServerKeyExchange body starts at msg[4]: ECParams(curve_type=3, named_curve,
;; point vec1), then SignatureAndHashAlgorithm(2) + signature vec2.
(define (ske-params msg)
  ;; ECParams = curve_type(1) named_curve(2) public(vec1); msg[4]=3,
  ;; [5..6]=curve, [7]=point len, [8..]=point.
  (define pt-len (bytes-ref msg 7))
  (subbytes msg 4 (+ 8 pt-len)))
(define (parse-ske msg)
  (define group (+ (* 256 (bytes-ref msg 5)) (bytes-ref msg 6)))
  (define pt-len (bytes-ref msg 7))
  (define pub (subbytes msg 8 (+ 8 pt-len)))
  (define sig-pos (+ 8 pt-len))
  (define scheme (+ (* 256 (bytes-ref msg sig-pos)) (bytes-ref msg (add1 sig-pos))))
  (define sig-len (+ (* 256 (bytes-ref msg (+ sig-pos 2))) (bytes-ref msg (+ sig-pos 3))))
  (define sig (subbytes msg (+ sig-pos 4) (+ sig-pos 4 sig-len)))
  (values group pub scheme sig))

(define (sh-has-ems? sh pos)
  ;; pos points at cipher_suite; after suite(2)+compression(1) come extensions
  (define ep (+ pos 3))
  (and (< ep (bytes-length sh))
       (let ([elen (+ (* 256 (bytes-ref sh ep)) (bytes-ref sh (add1 ep)))])
         (let loop ([p (+ ep 2)] [end (+ ep 2 elen)])
           (and (< p end)
                (let ([t (+ (* 256 (bytes-ref sh p)) (bytes-ref sh (add1 p)))]
                      [l (+ (* 256 (bytes-ref sh (+ p 2))) (bytes-ref sh (+ p 3)))])
                  (or (= t #x0017) (loop (+ p 4 l) end))))))))

(define (client-hello-exts ch)
  (define sid-len (bytes-ref ch 38))
  (define pos (+ 39 sid-len))
  (define cs-len (+ (* 256 (bytes-ref ch pos)) (bytes-ref ch (add1 pos))))
  (set! pos (+ pos 2 cs-len))
  (define comp-len (bytes-ref ch pos))
  (set! pos (+ pos 1 comp-len))
  (if (>= (+ pos 2) (bytes-length ch)) '()
      (let ([elen (+ (* 256 (bytes-ref ch pos)) (bytes-ref ch (add1 pos)))])
        (let loop ([p (+ pos 2)] [end (+ pos 2 elen)] [acc '()])
          (if (>= p end) (reverse acc)
              (let ([t (+ (* 256 (bytes-ref ch p)) (bytes-ref ch (add1 p)))]
                    [l (+ (* 256 (bytes-ref ch (+ p 2))) (bytes-ref ch (+ p 3)))])
                (loop (+ p 4 l) end (cons (cons t (subbytes ch (+ p 4) (+ p 4 l))) acc))))))))

(define (choose-group ch-exts)
  (define sg (assoc #x000a ch-exts))
  (or (and sg
           (let* ([body (cdr sg)]
                  [len (+ (* 256 (bytes-ref body 0)) (bytes-ref body 1))])
             (let loop ([p 2])
               (and (< p (+ 2 len))
                    (let ([g (+ (* 256 (bytes-ref body p)) (bytes-ref body (add1 p)))])
                      (if (memv g (list GROUP-X25519 GROUP-P256 GROUP-P384)) g (loop (+ p 2))))))))
      GROUP-X25519))

(define (gen-kx group)
  (case group
    [(#x001d) (let ([priv (random-bytes 32)] [pub (make-bytes 32)])
                (rktcrypto_x25519 pub priv (bytes-append (bytes 9) (make-bytes 31 0)))
                (values priv pub))]
    [(#x0017) (let loop () (let ([priv (random-bytes 32)] [pub (make-bytes 65)])
                             (if (eqv? 1 (rktcrypto_p256_pubkey pub priv)) (values priv pub) (loop))))]
    [(#x0018) (let ([priv (random-bytes 48)] [pub (make-bytes 97)])
                (rktcrypto_p384_pubkey pub priv) (values priv pub))]))

(define (ecdhe group priv peer)
  (case group
    [(#x001d) (let ([o (make-bytes 32)]) (unless (eqv? 1 (rktcrypto_x25519 o priv peer)) (raise (tls-error "x25519"))) o)]
    [(#x0017) (let ([o (make-bytes 32)]) (unless (eqv? 1 (rktcrypto_p256_ecdh o priv peer)) (raise (tls-error "p256"))) o)]
    [(#x0018) (let ([o (make-bytes 48)]) (unless (eqv? 1 (rktcrypto_p384_ecdh o priv peer)) (raise (tls-error "p384"))) o)]))

(define (sign-12 key scheme content)
  (case (car key)
    [(rsa) (let* ([kd (cdr key)] [sig (make-bytes 512)]
                  [n (rktcrypto_rsa_sign_msg 1 SHA256 kd (bytes-length kd) content (bytes-length content) sig)])
             (when (zero? n) (raise (tls-error "RSA sign failed"))) (subbytes sig 0 n))]
    [(p256) (let ([sig (make-bytes 64)])
              (unless (eqv? 1 (rktcrypto_p256_ecdsa_sign sig content (bytes-length content) (cdr key)))
                (raise (tls-error "ECDSA sign failed")))
              (raw->der sig 32))]))

(define (raw->der raw fb)
  (define (di b)
    (define v (let s ([i 0]) (if (and (< i (sub1 (bytes-length b))) (zero? (bytes-ref b i))) (s (add1 i)) (subbytes b i))))
    (define v2 (if (>= (bytes-ref v 0) #x80) (bytes-append (bytes 0) v) v))
    (bytes-append (bytes 2 (bytes-length v2)) v2))
  (define r (di (subbytes raw 0 fb))) (define s (di (subbytes raw fb (* 2 fb))))
  (bytes-append (bytes #x30 (+ (bytes-length r) (bytes-length s))) r s))

;; Build a tls-conn from the 1.2 record layer. tls-unique (RFC 5929 §3.1) is the
;; first Finished's verify_data = the client Finished for a full handshake.
(define (make-conn-12 r peer-ders [tls-unique #f])
  (define (recv)
    (let loop ()
      (with-handlers ([(lambda (e) (and (exn:tls? e) (not (exn:tls-alert e)))) (lambda (_) eof)])
        (define-values (type pt) (r12-read r))
        (cond
          [(and (= type 23) (positive? (bytes-length pt))) pt]
          [(= type 23) (loop)]
          [(= type 21) eof]
          [(= type 20) (loop)]
          [(= type 22) (loop)]
          [else (loop)]))))
  (define (send bs)
    (let loop ([off 0])
      (when (< off (bytes-length bs))
        (define chunk (min 16384 (- (bytes-length bs) off)))
        (r12-write r 23 (subbytes bs off (+ off chunk)))
        (loop (+ off chunk)))))
  (define (shut) (with-handlers ([exn:fail? void]) (r12-write r 21 (bytes 1 0))))
  (make-tls-conn recv send shut peer-ders 'tls1.2 (and tls-unique (hash 'tls-unique tls-unique))))
