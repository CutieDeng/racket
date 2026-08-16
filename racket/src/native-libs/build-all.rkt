#lang racket/base
(require racket/system
         racket/format
         racket/runtime-path
         racket/list
         "cmdline.rkt")

(define (get-package-names win?)
  (append
   '("pkg-config")
   (cond
    [win?
     (append
      '("sed"
        "libiconv")
      (if aarch64?
          null
          '("longdouble")))]
    [else
     null])
   (cond
    [(or win? linux?)
     '("sqlite"
       "zlib")]
    [else
     null])
   ;; No OpenSSL on any platform. Racket's crypto + TLS run entirely on the
   ;; in-tree rktcrypto engine, and the `openssl` collection never loads an
   ;; OpenSSL binary (openssl/libssl and openssl/libcrypto are #f shims;
   ;; ssl-available? probes rktcrypto in the executable, not a bundled libssl).
   ;; A bundled libssl/libcrypto would therefore be dead weight, so the
   ;; distribution ships none — completing the OpenSSL removal on every arch.
   null
   '("expat"
     "gettext")
   (cond
    [linux?
     '("inputproto"
       "xproto"
       "xtrans"
       "kbproto"
       "xextproto"
       "renderproto"
       "libpthread-stubs"
       "libXau"
       "xcb-proto"
       "libxcb"
       "libX11"
       "libXext"
       "libXrender"
       "freefont")]
    [else null])
   (cond
     [win? null]
     [else '("libuuid")])
   '("libffi"
     "glib"
     "libpng"
     "freetype"
     "fontconfig"
     "pixman"
     "cairo"
     "harfbuzz"
     "fribidi"
     "pango"
     "gmp")
   (cond
     [aarch64?
      '("mpfr-4")]
     [else
      '("mpfr-3")])
   '("jpeg"
     "atk"
     "poppler")
   (cond
    [mac?
     '("libedit")]
    [else null])
   (cond
    [linux?
     '("gdk-pixbuf"
       "gtk+")]
    [else null])))

(define-runtime-path build-rkt "build.rkt")

(build-command-line)

(define package-names (get-package-names win?))

(for ([package-name (in-list package-names)])
  (printf "~a\n" (make-string 72 #\=))
  (cond
   [(file-exists? (build-path "dest" "stamps" package-name))
    (printf "Done already: ~a\n" package-name)]
   [else
    (printf "Building ~a\n" package-name)
    (parameterize ([current-namespace (make-base-namespace)]
                   [current-command-line-arguments
                    (list->vector
                     (append
                      (list (if win? "--win" (if linux? "--linux" "--mac"))
                            (if m32?
                                (if ppc? "--mppc" "--m32")
                                (if aarch64? "--maarch64" "--mx86_64")))
                      (cons "--archives"
                            (add-between (map ~a archives-dirs)
                                         "--archives"))
                      (list package-name)))])
      (dynamic-require build-rkt #f))]))
