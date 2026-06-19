#lang racket/base

(require
 racket-tstring/private/read-syntax
) ; end require

(namespace-require '(lib "tstring/main.rkt"))
(namespace-require '(only (lib "racket-tstring/private/expand.rkt")
                          #%tstring-tpl
                          #%tstring-fpl
                    ) ; end only
) ; end namespace-require

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

(current-read-interaction read-interaction/tstring)
