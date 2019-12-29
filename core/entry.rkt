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
         "db.rkt"
         "json.rkt"
         "notification.rkt")

(provide
 (schema-out entry)
 commit-entry!
 archive-entry!
 snooze-entry!
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
   [(created-at (now/moment)) datetime/f])

  #:pre-persist-hook
  (lambda (e)
    (begin0 e
      (notify 'entries-will-change)))

  #:pre-delete-hook
  (lambda (e)
    (begin0 e
      (notify 'entries-will-change)))

  #:methods gen:to-jsexpr
  [(define (->jsexpr e)
     (hasheq 'id (entry-id e)
             'title (entry-title e)))])

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
        (match token
          [(chunk text span)
           (begin0 (values due tags)
             (display text))]

          [(relative-date text span delta modifier)
           (define adder
             (case modifier
               [(m) +minutes]
               [(h) +hours]
               [(d) +days]
               [(w) +weeks]
               [(M) +months]))
           (values (adder (now/moment) delta) tags)]

          [(tag text span name)
           (values due (cons name tags))]))))

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
                  (where (= e.id ,id))))
  (notify 'entries-will-change))

(define/contract (snooze-entry! id)
  (-> id/c void?)
  (define conn (current-db))
  (call-with-transaction conn
    (lambda ()
      (define entry
        (lookup conn (~> (from entry #:as e)
                         (where (= e.id ,id)))))

      (when entry
        (define updated-entry
          (set-entry-due-at entry (+minutes (now/moment) 15)))
        (void
         (update-one! conn updated-entry))))))

(define/contract (find-pending-entries)
  (-> (listof entry?))
  (sequence->list (in-entities (current-db)
                               (~> pending-entries
                                   (order-by ([(datetime e.due-at)]))))))

(define/contract (find-due-entries)
  (-> (listof entry?))
  (sequence->list (in-entities (current-db) due-entries)))

(module+ test
  (require rackunit)

  (parameterize ([current-db (sqlite3-connect #:database 'memory)])
    (create-table! (current-db) entry-schema)

    (define t0 (now/moment))
    (define the-entry
      (commit-entry! "buy milk +1h"))

    (check-match
     the-entry
     (entry _ some-id "buy milk" "" 'pending some-due-at some-created-at))

    (check-eqv? (minutes-between t0 (entry-due-at the-entry)) 60)
    (check-true (null? (find-due-entries)))
    (check-not-false (member (entry-id the-entry)
                             (map entry-id (find-pending-entries))))

    (archive-entry! (entry-id the-entry))
    (check-false (member (entry-id the-entry)
                         (map entry-id (find-pending-entries))))))
