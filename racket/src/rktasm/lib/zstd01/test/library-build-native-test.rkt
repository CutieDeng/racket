#lang racket

(require rackunit
         rackunit/text-ui
         racket/file
         racket/list
         racket/runtime-path
         racket/string
         racket/system)

(define-runtime-path build-source "../build.rkt")
(define-runtime-path roundtrip-source "../c-examples/roundtrip.c")

(define (arg->string value)
  (cond
    [(path? value) (path->string value)]
    [else (format "~a" value)]))

(define (run-command exe . args)
  (define argv (map arg->string args))
  (printf "+ ~a ~a\n" (arg->string exe) (string-join argv " "))
  (unless (apply system* exe argv)
    (error 'library-build-native-test "command failed: ~a ~a" exe argv)))

(define (capture-command/env env exe . args)
  (define out (open-output-string))
  (define err (open-output-string))
  (define env-vars (environment-variables-copy (current-environment-variables)))
  (for ([assignment (in-list env)])
    (match (regexp-match #rx"^([^=]+)=(.*)$" assignment)
      [(list _ key value)
       (environment-variables-set! env-vars
                                   (string->bytes/utf-8 key)
                                   (string->bytes/utf-8 value))]
      [_
       (error 'library-build-native-test
              "invalid environment assignment: ~a"
              assignment)]))
  (define ok?
    (parameterize ([current-output-port out]
                   [current-error-port err]
                   [current-environment-variables env-vars])
      (apply system*/exit-code exe (map arg->string args))))
  (unless (zero? ok?)
    (error 'library-build-native-test
           "command failed: ~a ~a\n~a"
           exe
           args
           (get-output-string err)))
  (string-split (string-trim (get-output-string out))))

(define (pkg-config-flags env . args)
  (apply capture-command/env
         env
         (or (find-executable-path "pkg-config")
             (error 'library-build-native-test "pkg-config not found"))
         args))

(define (native-macos-aarch64?)
  (and (eq? (system-type 'os) 'macosx)
       (eq? (system-type 'arch) 'aarch64)))

(define tests
  (test-suite
   "zstd01 native library build"
   (test-case "static library installs and roundtrips through libzstd"
     (unless (native-macos-aarch64?)
       (displayln "skipping native zstd01 build test on non-macOS/aarch64 host"))
     (when (native-macos-aarch64?)
       (define clang
         (or (find-executable-path "clang")
             (error 'library-build-native-test "clang not found")))
       (define pkg-config
         (or (find-executable-path "pkg-config")
             (error 'library-build-native-test "pkg-config not found")))
       (void pkg-config)

       (define tmp (make-temporary-file "asmp-zstd01-~a" 'directory))
       (define build-dir (build-path tmp "build"))
       (define install-dir (build-path tmp "install"))
       (run-command (find-executable-path "racket")
                    build-source
                    "--out-dir"
                    build-dir
                    "--prefix"
                    install-dir
                    "--install")

       (define lib-path (build-path install-dir "lib" "libasmp_zstd.a"))
       (define header-path (build-path install-dir "include" "asmp_zstd.h"))
       (define pc-path (build-path install-dir "lib" "pkgconfig" "asmp-zstd.pc"))
       (check-true (file-exists? lib-path))
       (check-true (file-exists? header-path))
       (check-true (file-exists? pc-path))

       (define zstd-cflags (pkg-config-flags '() "--cflags" "libzstd"))
       (define zstd-libs (pkg-config-flags '() "--libs" "libzstd"))

       (define manual-bin (build-path tmp "roundtrip-manual"))
       (apply run-command
              clang
              (append (list roundtrip-source
                            "-I"
                            (build-path install-dir "include")
                            lib-path
                            "-o"
                            manual-bin)
                      zstd-cflags
                      zstd-libs))
       (run-command manual-bin)

       (define pkg-env
         (list (format "PKG_CONFIG_PATH=~a"
                       (build-path install-dir "lib" "pkgconfig"))))
       (define asmp-cflags
         (pkg-config-flags pkg-env "--cflags" "asmp-zstd" "libzstd"))
       (define asmp-libs
         (pkg-config-flags pkg-env "--libs" "asmp-zstd" "libzstd"))
       (define pkg-bin (build-path tmp "roundtrip-pkg-config"))
       (apply run-command
              clang
              (append (list roundtrip-source "-o" pkg-bin)
                      asmp-cflags
                      asmp-libs))
       (run-command pkg-bin)))))

(module+ test
  (run-tests tests))
