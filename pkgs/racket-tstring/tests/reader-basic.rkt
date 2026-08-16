#lang reader "../lang/reader.rkt"

(provide
 rendered
 template-value
 formatted-rendered
 converted-rendered
 formatted-template
 ordinary-string
) ; end provide

(define name "Alice")
(define rendered f"hello {name}")
(define template-value t"hello {name}")
(define formatted-rendered f"{2:03d}")
(define converted-rendered f"{"hi"!r}")
(define formatted-template t"{name!r:>8s}")
(define ordinary-string "f\"not a template\"")
