#lang info

;; In-tree copy of the `parser-tools-lib` package (upstream:
;; https://github.com/racket/parser-tools, path parser-tools-lib,
;; commit 2f3638fa66c83d0c53f8aec7cc6cfd3775daf8a5), carried here so
;; that REPL-startup changes to the `lexer` macro (whose tables the
;; default REPL's syntax coloring builds at startup) can be committed,
;; measured, and shipped with this distribution.

(define collection 'multi)

(define deps '("base"))

(define build-deps '("rackunit-lib"))

(define pkg-desc "implementation (no documentation) part of \"parser-tools\"")

(define pkg-authors '(mflatt))

(define version "9.0")

(define license '(Apache-2.0 OR MIT))
