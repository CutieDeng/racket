#lang racket

(provide
  (struct-out reg-physical)
  (struct-out reg-virtual)
  (struct-out reg-general)
  (struct-out reg-predicate)
  reg-class/c
  pred-mode/c
  pred-mask/c
  binding/c
  reg-general/c
  reg-predicate/c
)

(struct reg-physical (id) #:transparent)
(struct reg-virtual (id) #:transparent)

(define reg-class/c (or/c 'x 'w 'z))
(define binding/c (or/c reg-physical? reg-virtual?))

(struct reg-general (class binding) #:transparent)
(struct reg-predicate (p mode mask binding) #:transparent)

(define reg-general/c (struct/c reg-general reg-class/c binding/c))
(define pred-mode/c (or/c #f 'B 'H 'W 'D))
(define pred-mask/c (or/c #f 'm 'z))
(define reg-predicate/c (struct/c reg-predicate any/c pred-mode/c pred-mask/c binding/c))
