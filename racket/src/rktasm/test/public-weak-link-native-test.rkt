#lang racket

(require rackunit
         rackunit/text-ui
         racket/file
         racket/runtime-path)

(require (only-in "../cli/as.rkt" assemble))   ; in-process 汇编

(define weak-source
  #<<ASM
.function asmp_weak_probe export weak profile=c-aapcs64 (
  out: x.value
)
entry:
  mov x.value, #11
  ret
.end
ASM
  )

(define strong-source
  #<<ASM
.function asmp_weak_probe export profile=c-aapcs64 (
  out: x.value
)
entry:
  mov x.value, #29
  ret
.end
ASM
  )

(define (harness-source expected)
  (format #<<C
#include <stdint.h>
#include <stdio.h>

extern uint64_t asmp_weak_probe(void);

int main(void) {
  uint64_t value = asmp_weak_probe();
  if (value != ~aull) {
    fprintf(stderr, "asmp_weak_probe returned %llu, expected ~a\n",
            (unsigned long long)value);
    return 1;
  }
  return 0;
}
C
          expected
          expected))

(define (native-macos-aarch64?)
  (and (eq? (system-type 'os) 'macosx)
       (eq? (system-type 'arch) 'aarch64)))

(define (run-command exe . args)
  (define ok? (apply system* exe args))
  (unless ok?
    (error 'public-weak-link-native-test "command failed: ~a ~a" exe args)))

(define (write-text path content)
  (call-with-output-file path
    #:exists 'truncate/replace
    (lambda (out) (display content out))))

(define (compile-asmp source-path asm-path)
  (let ([code (assemble source-path
                        #:input-syntax 'gnu #:asm-syntax 'apple #:output asm-path)])
    (unless (zero? code) (error 'public-weak-link "assemble failed: ~a" code))))

(define (link-and-run dir expected asm-paths)
  (define harness-path (build-path dir (format "harness-~a.c" expected)))
  (define exe-path (build-path dir (format "probe-~a" expected)))
  (write-text harness-path (harness-source expected))
  (apply run-command
         (find-executable-path "clang")
         "-O2"
         harness-path
         "-o"
         exe-path
         asm-paths)
  (run-command exe-path))

(define (call-with-temp-dir proc)
  (define dir (make-temporary-file "asmp-public-weak-link-~a" 'directory))
  (dynamic-wind
    void
    (lambda () (proc dir))
    (lambda () (delete-directory/files dir))))

(define public-weak-link-native-tests
  (test-suite
   "native public weak link behavior"

   (test-case "weak exported function links standalone and can be overridden by a strong definition"
     (cond
       [(not (native-macos-aarch64?))
        (printf "skip native public weak link test on ~a/~a\n"
                (system-type 'os)
                (system-type 'arch))
        (check-true #t)]
       [(not (find-executable-path "clang"))
        (printf "skip native public weak link test: clang not found\n")
        (check-true #t)]
       [else
        (call-with-temp-dir
         (lambda (dir)
           (define weak-src-path (build-path dir "weak.asm"))
           (define strong-src-path (build-path dir "strong.asm"))
           (define weak-asm-path (build-path dir "weak.s"))
           (define strong-asm-path (build-path dir "strong.s"))
           (write-text weak-src-path weak-source)
           (write-text strong-src-path strong-source)
           (compile-asmp weak-src-path weak-asm-path)
           (compile-asmp strong-src-path strong-asm-path)

           (define weak-asm (file->string weak-asm-path))
           (check-not-false
            (regexp-match? #rx"\\.weak_definition _asmp_weak_probe" weak-asm))
           (check-not-false
            (regexp-match? #rx"\\.globl _asmp_weak_probe" weak-asm))
           (check-not-false
            (regexp-match? #rx"\\.subsections_via_symbols" weak-asm))

           (link-and-run dir 11 (list weak-asm-path))
           (link-and-run dir 29 (list weak-asm-path strong-asm-path))
           (link-and-run dir 29 (list strong-asm-path weak-asm-path))
           (check-true #t)))]))))

(module+ main
  (void (run-tests public-weak-link-native-tests)))

(module+ test
  (void (run-tests public-weak-link-native-tests)))
