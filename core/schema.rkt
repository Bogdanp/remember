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
          ;; This is pretty piggy but db-lib doesn't support multiple statements per query.
          (define migration (file->string migration-path))
          (define statements (string-split migration ";\n"))
          (for ([statement (in-list statements)])
            (when (non-empty-string? (string-trim statement))
              (query-exec conn statement)))
          (query-exec conn "insert into schema_migrations values($1)" ref))))))
