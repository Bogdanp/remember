#lang racket/base

(require (for-syntax racket/base)
         db
         racket/file
         racket/list
         racket/path
         racket/runtime-path
         racket/string
         "db.rkt")

(provide
 migrate!)

(define-runtime-path migrations-path
  (build-path 'up "migrations"))

(define migration-paths
  (sort
   (find-files
    (lambda (p)
      (string-suffix? (path->string p) ".sql"))
    (normalize-path migrations-path))
   (lambda (a b)
     (string-ci<? (path->string a)
                  (path->string b)))))

(define (migrate!)
  (call-with-database-connection
    (lambda (conn)
      (query-exec conn "create table if not exists schema_migrations(ref text not null unique)")
      (for ([migration-path (in-list migration-paths)])
        (define ref (path->string (last (explode-path migration-path))))
        (unless (query-maybe-value conn "select true from schema_migrations where ref = $1" ref)
          (query-exec conn (file->string migration-path))
          (query-exec conn "insert into schema_migrations values($1)" ref))))))
