#lang racket/base

(require deta
         racket/contract
         racket/string
         threading
         "db.rkt")

(provide
 assign-tags!)

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
