#lang racket/base

(require db
         "database.rkt"
         "schema.rkt")

(provide
 call-with-empty-database)

(define (call-with-empty-database proc)
  (parameterize ([current-db (make-db
                              (lambda ()
                                (sqlite3-connect #:database 'memory)))])
    (migrate!)
    (proc)))
