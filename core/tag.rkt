#lang racket/base

(require db
         deta
         racket/contract
         (only-in racket/list remove-duplicates)
         racket/string
         threading
         "database.rkt")

(provide
 assign-tags!
 find-tags-by-entry-id)

(define-schema tag
  #:table "tags"
  ([id id/f #:primary-key #:auto-increment]
   [name string/f #:contract non-empty-string? #:wrapper string-trim]))

(define-schema entry-tag
  #:table "entry_tags"
  ([entry-id id/f]
   [tag-id id/f]))

(define/contract (assign-tags! entry-id tags)
  (-> id/c (listof non-empty-string?) void?)
  (unless (null? tags)
    (call-with-database-transaction
      (lambda (conn)
        (for ([name (in-list tags)])
          (define t
            (or (lookup conn (~> (from tag #:as t)
                                 (where (= t.name ,name))
                                 (limit 1)))
                (insert-one! conn (make-tag #:name name))))

          (unless (lookup conn (~> (from entry-tag #:as et)
                                   (where (and (= et.entry-id ,entry-id)
                                               (= et.tag-id ,(tag-id t))))))
            (insert! conn (make-entry-tag #:entry-id entry-id
                                          #:tag-id (tag-id t)))))))))

(define/contract (find-tags-by-entry-id conn id)
  (-> connection? id/c (listof non-empty-string?))
  (query-list conn (~> (from "entry_tags" #:as et)
                       (join "tags" #:as t #:on (= t.id et.tag-id))
                       (select t.name)
                       (where (= et.entry-id ,id)))))
