#lang racket
;; A2: TLS 1.3 session resumption (NewSessionTicket + PSK) loopback tests, run
;; directly against the tls13 engine (raw pipes) so the PSK/binder/key-schedule
;; can be checked end to end without the mzssl wrapper.
(require "../../../collects/openssl/private/rktcrypto-tls13.rkt"
         (only-in "../../../collects/openssl/private/rktcrypto-x509-build.rkt"
                  create-self-signed-certificate))

(define fails 0)
(define (check! name ok?) (printf "  ~a ~a\n" (if ok? "ok:" "FAIL:") name) (unless ok? (set! fails (add1 fails))))

(define-values (cert-der key-scalar) (create-self-signed-certificate #:common-name "resume.test"))
(define server-opts-base (hash 'cert-ders (list cert-der) 'key (cons 'p256 key-scalar) 'alpn '()))

;; Run one client<->server handshake over fresh pipes. server-extra/client-extra
;; add resumption opts. Returns (values server-conn-thread-result client-session).
(define (one-exchange #:ticket-store [ticket-store #f] #:resume-box [resume-box #f]
                      #:verify? [verify? #f] #:expect-client-fail [expect-fail #f])
  (define-values (c->s-in c->s-out) (make-pipe))
  (define-values (s->c-in s->c-out) (make-pipe))
  (define sres (make-channel))
  (thread
   (lambda ()
     (with-handlers ([(lambda (_) #t) (lambda (e) (channel-put sres (cons 'err e)))])
       (define sc (tls13-accept c->s-in s->c-out
                                (if ticket-store (hash-set server-opts-base 'ticket-store ticket-store)
                                    server-opts-base)))
       (define got (tls-conn-read-bytes sc 5))
       (tls-conn-write-bytes sc got)          ; echo
       (channel-put sres 'ok))))
  (define client-outcome
    (with-handlers ([(lambda (_) #t) (lambda (e) (cons 'client-fail e))])
      (define cc (tls13-connect s->c-in c->s-out
                                (hash 'host "resume.test" 'verify? verify? 'trust-anchors '() 'alpn '()
                                      'resume-session-box resume-box)))
      (tls-conn-write-bytes cc #"hello")
      (define echo (tls-conn-read-bytes cc 5))  ; forces NST processing before app data
      (list 'ok echo cc)))
  (cond
    [expect-fail (values (if (and (pair? client-outcome) (eq? (car client-outcome) 'client-fail)) 'client-failed 'no-fail)
                         #f #f)]
    [(and (pair? client-outcome) (eq? (car client-outcome) 'client-fail))
     (raise (cdr client-outcome))]
    [else (values (sync/timeout 10 sres) (cadr client-outcome) (caddr client-outcome))]))

;; ---- Test 1: server issues a ticket, client captures it with the same PSK ----
(printf "A2 resumption (tls13 loopback):\n")
(define store (make-hash))
(define sbox (box #f))
(define-values (sr1 echo1 cc1) (one-exchange #:ticket-store store #:resume-box sbox))
(check! "round 1 handshake + echo" (and (eq? sr1 'ok) (equal? echo1 #"hello")))
(check! "server issued exactly one ticket" (= 1 (hash-count store)))
(check! "client captured a session" (tls-session? (unbox sbox)))
(when (tls-session? (unbox sbox))
  (define cs (unbox sbox))
  (define server-side (hash-ref store (tls-session-ticket cs) #f))
  (check! "ticket matches a server-stored ticket" (tls-session? server-side))
  (check! "client PSK == server PSK for the ticket"
          (and server-side (equal? (tls-session-psk cs) (tls-session-psk server-side))))
  (check! "PSK is Hash.length bytes" (= 32 (bytes-length (tls-session-psk cs)))))

;; ---- Test 2: actually resume. With verify?=#t and NO trust anchors, only a
;; resumed (certificate-less) handshake can succeed; a fresh one fails chain
;; verification — so success here proves resumption skipped the certificate. ----
(define store2 (make-hash))
(define sbox2 (box #f))
(let-values ([(sr e _c) (one-exchange #:ticket-store store2 #:resume-box sbox2)])
  (check! "round 1 (issues a ticket)" (and (eq? sr 'ok) (equal? e #"hello"))))
;; sanity: a FRESH strict-verify handshake with no anchors MUST fail
(let-values ([(out _e _c) (one-exchange #:ticket-store store2 #:resume-box (box #f)
                                        #:verify? #t #:expect-client-fail #t)])
  (check! "fresh strict-verify w/o anchors is rejected (discriminates resumption)"
          (eq? out 'client-failed)))
;; now resume with strict verify — succeeds only because the cert step is skipped
(define offered-ticket (tls-session-ticket (unbox sbox2)))
(let-values ([(sr2 echo2 _c) (one-exchange #:ticket-store store2 #:resume-box sbox2 #:verify? #t)])
  (check! "round 2 RESUMED handshake + echo (strict verify, cert skipped)"
          (and (eq? sr2 'ok) (equal? echo2 #"hello")))
  (check! "server consumed the offered ticket (single-use)" (not (hash-has-key? store2 offered-ticket)))
  (check! "resumption issued a fresh, different ticket"
          (and (= 1 (hash-count store2)) (not (equal? offered-ticket (tls-session-ticket (unbox sbox2)))))))

(printf (if (zero? fails) "resumption: 0 failure(s)\n" (format "resumption: ~a FAILURE(S)\n" fails)))
(exit (if (zero? fails) 0 1))
