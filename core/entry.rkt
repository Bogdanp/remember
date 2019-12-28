#lang racket/base

(require db
         deta
         gregor
         json
         racket/contract
         racket/match
         racket/sequence
         racket/string
         threading
         "command.rkt"
         "db.rkt")

(provide
 (schema-out entry)
 entry->jsexpr
 commit-entry!
 archive-entry!
 find-pending-entries
 find-due-entries)

(define id/c
  exact-nonnegative-integer?)

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

(create-table! (current-db) entry-schema)

(define/contract (commit-entry! command)
  (-> string? entry?)
  (define tokens (parse-command command))
  (define title-out (open-output-string))
  (define-values (due tags)
    (parameterize ([current-output-port title-out])
      (for/fold ([due (+minutes (now/moment) 15)]
                 [tags null])
                ([token (in-list tokens)])
        (case (hash-ref token 'type)
          [("chunk")
           (begin0 (values due tags)
             (display (hash-ref token 'text)))]

          [("relative-date")
           (values (relative-date->moment token) tags)]))))

  (insert-one! (current-db)
               (make-entry #:title (string-trim (get-output-string title-out))
                           #:due-at due)))

(define pending-entries
  (~> (from entry #:as e)
      (where (= e.status "pending"))))

(define due-entries
  (~> pending-entries
      (where (< (datetime e.due-at)
                (datetime "now" "localtime")))))

(define/contract (archive-entry! id)
  (-> id/c void?)
  (query-exec (current-db)
              (~> (from entry #:as e)
                  (update [status "archived"])
                  (where (= e.id ,id)))))

(define/contract (find-pending-entries)
  (-> (listof entry?))
  (sequence->list (in-entities (current-db)
                               (~> pending-entries
                                   (order-by ([(datetime e.due-at)]))))))

(define/contract (find-due-entries)
  (-> (listof entry?))
  (sequence->list (in-entities (current-db) due-entries)))

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

(define/contract (entry->jsexpr e)
  (-> entry? jsexpr?)
  (hasheq 'id (entry-id e)
          'title (entry-title e)))
