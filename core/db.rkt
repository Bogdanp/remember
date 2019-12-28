#lang racket/base

(require db
         "appdata.rkt")

(provide
 current-db)

(define current-db
  (make-parameter
   (sqlite3-connect #:database (build-application-path "remember.sqlite3")
                    #:mode 'create
                    #:use-place #t)))
