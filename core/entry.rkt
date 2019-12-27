#lang racket/base

(require deta
         gregor
         racket/contract
         racket/match
         racket/string
         threading
         "command.rkt"
         "db.rkt")

(provide
 (schema-out entry)
 entry->jsexpr
 commit-entry!
 find-due-entries)

(define entry-status/c
  (or/c 'pending 'archived))

(define-schema entry
  #:table "entries"
  ([id id/f #:primary-key #:auto-increment]
   [title string/f #:contract non-empty-string?]
   [(body "") string/f]
   [(status 'pending) symbol/f #:contract entry-status/c]
   [(due-at (now/moment)) datetime/f]
   [(created-at (now/moment)) datetime/f]))

(create-table! conn entry-schema)

(define (commit-entry! command)
  (define tokens (parse-command command))
  (define title-out (open-output-string))
  (define-values (due tags)
    (parameterize ([current-output-port title-out])
      (for/fold ([due (+hours (now/moment) 1)]
                 [tags null])
                ([token (in-list tokens)])
        (case (hash-ref token 'type)
          [("chunk")
           (begin0 (values due tags)
             (display (hash-ref token 'text)))]

          [("relative-date")
           (values (relative-date->moment token) tags)]))))

  (define the-entry
    (insert-one! conn (make-entry #:title (string-trim (get-output-string title-out))
                                  #:due-at due)))

  (entry->jsexpr the-entry))

(define (find-due-entries)
  (for/list ([entry (in-entities conn
                                 (~> (from entry #:as e)
                                     (where (and
                                             (= e.status "pending")
                                             (< (datetime e.due-at)
                                                (datetime "now"))))))])
    entry))

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

(define (entry->jsexpr e)
  (hasheq 'id (entry-id e)
          'title (entry-title e)))
