#lang racket/base

(require db
         "database.rkt"
         "schema.rkt")

(provide
 call-with-empty-database)

(define (call-with-empty-database f)
  (parameterize ([current-db (make-db
                              (lambda _
                                (sqlite3-connect #:database 'memory)))])
    (migrate!)
    (f)))
