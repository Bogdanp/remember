#lang racket/base

(require db
         deta
         gregor
         json
         racket/contract
         racket/format
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
 commit!
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
   [(due-at (now/moment)) datetime/f #:nullable]
   [(created-at (now/moment)) datetime/f])

  #:methods gen:to-jsexpr
  [(define (->jsexpr e)
     (hasheq 'id (entry-id e)
             'title (entry-title e)
             'due-in (or (entry-due-in e)
                         (json-null))))])

(define (entry-due-at/local e)
  (and (not (sql-null? (entry-due-at e)))
       (with-timezone (entry-due-at e) (current-timezone))))

(define (entry-due-in e)
  (and (not (sql-null? (entry-due-at e)))
       (let* ([now (now/moment)]
              [due (entry-due-at/local e)]
              [delta (seconds-between now due)])
         (cond
           [(<= delta 0)           "past due"]
           [(>= delta (* 7 86400)) (~a "due on " (if (= (->year due)
                                                        (->year (now/moment)))
                                                     (~t due "MMM dd")
                                                     (~t due "MMM dd, yyyy")))]
           [(>= delta 86400)       (~a "due in " (format-delta (add1 (days-between now due)) "day" "days"))]
           [(>= delta 3600)        (~a "due in " (format-delta (add1 (hours-between now due)) "hour" "hours"))]
           [(>= delta 60)          (~a "due in " (format-delta (add1 (minutes-between now due)) "minute" "minutes"))]
           [else                   "due in under a minute"]))))

(define (format-delta d singular plural)
  (format "~a ~a" d (if (= d 1)
                        singular
                        plural)))

(create-table! (current-db) entry-schema)

(define/contract (commit! command)
  (-> string? entry?)
  (define tokens (parse-command command))
  (define out (open-output-string))
  (define-values (due tags)
    (parameterize ([current-output-port out])
      (for/fold ([due #f]
                 [tags null])
                ([token (in-list tokens)])
        (match token
          [(chunk text span)
           (display text)
           (values due tags)]

          [(relative-datetime text span delta modifier)
           (define adder
             (case modifier
               [(m) +minutes]
               [(h) +hours]
               [(d) +days]
               [(w) +weeks]
               [(M) +months]))
           (values (adder (or due (now/moment)) delta) tags)]

          [(tag text span name)
           (values due (cons name tags))]))))

  (define the-entry
    (insert-one! (current-db)
                 (make-entry #:title (string-trim (get-output-string out))
                             #:due-at (or due sql-null))))

  (begin0 the-entry
    (notify 'entries-did-change)))

(define pending-entries
  (~> (from entry #:as e)
      (where (= e.status "pending"))))

(define due-entries
  (~> pending-entries
      (where (and (not (is e.due-at null))
                  (< (datetime e.due-at)
                     (datetime "now" "localtime"))))))

(define/contract (archive-entry! id)
  (-> id/c void?)
  (query-exec (current-db)
              (~> (from entry #:as e)
                  (update [status "archived"])
                  (where (= e.id ,id))))
  (void (notify 'entries-did-change)))

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
        (update-one! conn updated-entry))))
  (void (notify 'entries-did-change)))

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

  (define (call-with-empty-db f)
    (parameterize ([current-db (sqlite3-connect #:database 'memory)])
      (create-table! (current-db) entry-schema)
      (f)))


  (call-with-empty-db
   (lambda _
     (define the-entry
       (commit! "buy milk"))

     (check-match
      the-entry
      (entry _ some-id "buy milk" "" 'pending (== sql-null) some-created-at))

     (check-not-false (member (entry-id the-entry)
                              (map entry-id (find-pending-entries))))))

  (call-with-empty-db
   (lambda _
     (define t0 (now/moment))
     (define the-entry
       (commit! "buy milk +1h"))

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

  (call-with-empty-db
   (lambda _
     (define t0 (now/moment))
     (define the-entry
       (commit! "buy milk +1h +15m"))

     (check-eqv? (minutes-between t0 (entry-due-at the-entry)) 75))))
