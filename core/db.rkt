#lang racket/base

(require db)

(provide
 current-db)

(define current-db
  (make-parameter
   (sqlite3-connect #:database "/tmp/remember.sqlite3"
                    #:mode 'create
                    #:use-place #t)))
