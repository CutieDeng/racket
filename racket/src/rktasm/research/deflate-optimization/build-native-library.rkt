#!/usr/bin/env racket
#lang racket

(require racket/cmdline
         racket/file
         racket/runtime-path
         racket/string
         "library-manifest.rkt"
         "../../cli/as.rkt")            ; in-process 汇编 (assemble), 免 racket 子进程

(define-runtime-path root-dir "../..")
(define-runtime-path default-out-dir "build/native")
(define-runtime-path default-manifest "asmp-deflate-library.rktd")


(define (arg->string value)
  (cond
    [(path? value) (path->string value)]
    [else (format "~a" value)]))

(define (run-command exe . args)
  (define argv (map arg->string args))
  (printf "+ ~a ~a\n" (arg->string exe) (string-join argv " "))
  (unless (apply system* exe argv)
    (error 'build-native-library "command failed: ~a ~a" exe argv)))

(define (native-macos-aarch64?)
  (and (eq? (system-type 'os) 'macosx)
       (eq? (system-type 'arch) 'aarch64)))

(define (require-tool name)
  (or (find-executable-path name)
      (error 'build-native-library "required tool not found: ~a" name)))

(define (compile-asmp-source name source asm-dir object-dir)
  (define asm-path (build-path asm-dir (format "~a.s" name)))
  (define object-path (build-path object-dir (format "~a.o" name)))
  ;; in-process 调 rktasm(同一个 racket),不再 system* racket cli/as.rkt
  (define code (assemble source
                         #:input-syntax 'gnu
                         #:asm-syntax   'apple
                         #:elim?        #t
                         #:abi-config   (path->string (build-path root-dir "config" "abi.rktd"))
                         #:output       asm-path))
  (unless (zero? code)
    (error 'build-native-library "assemble failed (code ~a): ~a" code source))
  (values asm-path object-path))

(define (compile-object clang asm-path object-path)
  (run-command clang "-c" asm-path "-o" object-path)
  object-path)

(define (build-native-library manifest-path out-dir library-name-override)
  (unless (native-macos-aarch64?)
    (error 'build-native-library
           "native library build is currently macOS arm64 only; host is ~a/~a"
           (system-type 'os)
           (system-type 'arch)))
  (define manifest (read-library-manifest manifest-path))
  (define library-name (manifest-library-name manifest library-name-override))
  (define clang (require-tool "clang"))
  (define ar (require-tool "ar"))
  (define ranlib (require-tool "ranlib"))

  (define asm-dir (build-path out-dir "asm"))
  (define object-dir (build-path out-dir "obj"))
  (define include-dir (build-path out-dir "include"))
  (make-directory* asm-dir)
  (make-directory* object-dir)
  (make-directory* include-dir)

  (define object-paths
    (for/list ([source-entry (in-list (manifest-sources manifest))])
      (define name (car source-entry))
      (define source (cdr source-entry))
      (define-values (asm-path object-path)
        (compile-asmp-source name source asm-dir object-dir))
      (compile-object clang asm-path object-path)))

  (define library-path (build-path out-dir library-name))
  (when (file-exists? library-path)
    (delete-file library-path))
  (apply run-command ar "rcs" library-path object-paths)
  (run-command ranlib library-path)

  (define installed-header (build-path include-dir "asmp_deflate.h"))
  (write-library-header manifest installed-header)

  (printf "built static library: ~a\n" library-path)
  (printf "installed header: ~a\n" installed-header)
  (values library-path installed-header))

(module+ main
  (define out-dir default-out-dir)
  (define manifest-path default-manifest)
  (define library-name-override #f)
  (command-line
   #:program "build-native-library.rkt"
   #:once-each
   [("--manifest") path "Library manifest to build"
                   (set! manifest-path path)]
   [("--out-dir") path "Output directory for asm, objects, library, and header"
                  (set! out-dir path)]
   [("--library-name") name "Static library filename"
                       (set! library-name-override name)]
   #:args ()
   (call-with-values
    (lambda () (build-native-library manifest-path out-dir library-name-override))
    (lambda results (void)))))
