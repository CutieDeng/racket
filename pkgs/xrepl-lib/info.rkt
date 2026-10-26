#lang info

;; In-tree copy of the `xrepl-lib` package (upstream:
;; https://github.com/racket/xrepl, path xrepl-lib,
;; commit 977777072e1bbdaf38d23654e281781f26d20488), carried here so
;; that REPL-startup changes to the extended REPL can be committed,
;; measured, and shipped with this distribution.

(define collection 'multi)

(define deps
  '(("base" #:version "8.3.0.2")
    "readline-lib"
    "scribble-text-lib"))

(define pkg-desc "implementation (no documentation) part of \"xrepl\"")

(define pkg-authors '(eli))

(define license '(Apache-2.0 OR MIT))
