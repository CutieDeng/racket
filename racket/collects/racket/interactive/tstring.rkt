#lang racket/base

(require
 racket/interactive/tstring-reader
) ; end require

(when (collection-file-path "main.rkt" "xrepl"
                            #:fail (lambda _ #f)
      ) ; end collection-file-path
  (dynamic-require 'xrepl #f)
  (define toplevel-prefix (dynamic-require 'xrepl/xrepl 'toplevel-prefix))
  (toplevel-prefix "")
) ; end when xrepl

(let ((init-file (cleanse-path (find-system-path 'init-file))))
  (when (file-exists? init-file)
    (load init-file)
  ) ; end when init file
) ; end let init-file
