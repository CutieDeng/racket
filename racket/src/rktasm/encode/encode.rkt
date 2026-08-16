#lang racket

(require
 (only-in racket/pvector pvector?))

(provide
 (struct-out encode)
 (struct-out encode-field)
 encode/c
 ordered-mapof
 encode-tags/c
 encode-field/c
 encode-fields/c)

;; tags 集合已迁为不可变 hash (原 vendor ordered-map)
(define ordered-mapof (and/c hash? immutable?))

(define encode-tags/c (and/c hash? immutable?))

(struct encode-field (name len lo hi) #:transparent)

(define encode-field/c
  (struct/c encode-field (or/c string? #f) exact-nonnegative-integer?
            exact-nonnegative-integer? exact-nonnegative-integer?))
(define encode-fields/c pvector?)

(struct encode (name tags encodings) #:transparent)

(define encode/c (struct/c encode string? encode-tags/c encode-fields/c))
