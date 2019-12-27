#lang racket/base

(require deta
         gregor
         racket/match
         racket/string
         "command.rkt"
         "db.rkt")

(provide
 (schema-out entry)
 commit-entry!)

(define-schema entry
  #:table "entries"
  ([id id/f #:primary-key #:auto-increment]
   [title string/f #:contract non-empty-string?]
   [(body "") string/f]
   [(due-at (now/moment)) datetime-tz/f]
   [(created-at (now/moment)) datetime-tz/f]))

(create-table! conn entry-schema)

(define (commit-entry! command)
  (define tokens (parse-command command))
  (define title-out (open-output-string))
  (define-values (due tags)
    (for/fold ([due (+hours (now/moment) 1)]
               [tags null])
              ([token (in-list tokens)])
      (case (hash-ref token 'type)
        [("chunk")
         (begin0 (values due tags)
           (display (hash-ref token 'text) title-out))]

        [("relative-date")
         (values
          (relative-date->moment token)
          tags)])))

  (define the-entry
    (insert-one! conn (make-entry #:title (string-trim (get-output-string title-out))
                                  #:due-at due)))

  (hasheq 'id (entry-id the-entry)
          'title (entry-title the-entry)))

(define/match (relative-date->moment token)
  [((hash-table ['delta d]
                ['modifier m]))
   (define adder
     (case m
       [("h") +hours]
       [("d") +days]
       [("w") +weeks]
       [("m") +months]))

   (adder (now/moment) d)])
