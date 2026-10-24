;; ===== fasl2 fourth-segment build step (the "build.zuo 四段" producer) =====
;; Runs against a built scheme; produces a vfasl fourth-segment image + a
;; locator table from a representative language-layer state.  In production
;; this runs against a fully-instantiated racket/init+xrepl namespace; here
;; it uses a representative registry-shaped state so the produce->load cycle
;; is buildable and testable end to end.
;;
;;   scheme --script gen-seg4.ss <out-dir> [N]
;; produces <out-dir>/seg4.vfasl  and  <out-dir>/seg4.locators
(define args (command-line-arguments))
(define OUT (car args))
(define N (if (pair? (cdr args)) (string->number (cadr args)) 8000))

;; interned-by-spec wrapper: stands in for resolved-module-path / keyword,
;; the interned types base fasl cannot serialize and fasl2 externalizes.
(define-record-type modname (fields spec))
(define modname-table (make-hashtable string-hash string=?))
(define (intern-modname spec)
  (or (hashtable-ref modname-table spec #f)
      (let ([m (make-modname spec)]) (hashtable-set! modname-table spec m) m)))

;; build a representative state: a module registry keyed by interned
;; module-name objects, plus per-entry body graphs.
(define state
  (let loop ([i 0] [reg '()])
    (if (fx= i N)
        (vector 'namespace (list->vector reg))
        (loop (fx+ i 1)
              (cons (cons (intern-modname (string-append "collects/mod" (number->string i)))
                          (vector 'entry i (cons i (fx* i 7))))
                    reg)))))

;; fasl2-write: externalize the interned modname objects as locators
;; (locator = the spec string; production also does rmp/kw/prefab), image
;; the rest, convert to vfasl (externalref).
(define captured '())
(define (locate x) (and (modname? x)
                        (begin (set! captured (cons (modname-spec x) captured)) #t)))
(define ff (string-append OUT "/seg4.fasl"))
(define vf (string-append OUT "/seg4.vfasl"))
(let ([p (open-file-output-port ff (file-options replace))])
  (fasl-write state p locate) (close-port p))
(vfasl-convert-file ff vf '("petite" "scheme"))
(with-output-to-file (string-append OUT "/seg4.locators")
  (lambda () (write (reverse captured))) 'replace)
(printf "gen-seg4: N=~a  seg4.vfasl=~a KB  externals=~a\n"
        N (quotient (call-with-port (open-file-input-port vf) file-length) 1024)
        (length captured))
(exit)
