#lang info

;; In-tree copy of the `expeditor-lib` package (upstream:
;; https://github.com/racket/expeditor, path expeditor-lib,
;; commit 65e20a410bdc5f09c0682a1bb57cac2b68d73506), carried here so
;; that REPL-startup changes to the line editor can be committed,
;; measured, and shipped with this distribution.

(define collection "expeditor")

(define deps
  '(("base" #:version "8.15.0.10")
    ("syntax-color-lib" #:version "1.3")))

(define pkg-desc "implementation (no documentation) part of \"expeditor\"")

(define pkg-authors '(mflatt))

(define version "1.2")

(define license '(Apache-2.0 OR MIT))
