#lang racket/base

(require db)

(provide conn)

(define conn
  (sqlite3-connect #:database "/tmp/remember.sqlite3"
                   #:mode 'create
                   #:use-place #t))
