#lang racket/base

(require db
         deta
         racket/contract/base
         racket/string
         threading
         "database.rkt")

(provide
 (contract-out
  [assign-tags! (-> id/c (listof non-empty-string?) void?)]
  [find-tags-by-entry-id (-> connection? id/c (listof non-empty-string?))]))

(define-schema tag
  #:table "tags"
  ([id id/f #:primary-key #:auto-increment]
   [name string/f #:contract non-empty-string? #:wrapper string-trim]))

(define-schema entry-tag
  #:table "entry_tags"
  ([entry-id id/f]
   [tag-id id/f]))

(define (assign-tags! entry-id tags)
  (unless (null? tags)
    (call-with-database-transaction
      (lambda (conn)
        (for ([name (in-list tags)])
          (define t
            (or (~> (from tag #:as t)
                    (where (= t.name ,name))
                    (limit 1)
                    (lookup conn _))
                (~> (make-tag #:name name)
                    (insert-one! conn _))))
          (unless (~> (from entry-tag #:as et)
                      (where (and (= et.entry-id ,entry-id)
                                  (= et.tag-id ,(tag-id t))))
                      (lookup conn _))
            (~> (make-entry-tag #:entry-id entry-id
                                #:tag-id (tag-id t))
                (insert-one! conn _))))))))

(define (find-tags-by-entry-id conn id)
  (~> (from entry-tag #:as et)
      (join tag #:as t #:on (= t.id et.tag-id))
      (select t.name)
      (where (= et.entry-id ,id))
      (query-list conn _)))
