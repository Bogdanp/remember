#lang racket/base

(require db
         deta
         gregor
         gregor/time
         noise/serde
         racket/contract/base
         racket/format
         racket/match
         racket/math
         racket/string
         threading
         "command.rkt"
         "database.rkt"
         "event.rkt"
         "tag.rkt"
         "undo.rkt")

(provide
 (record-out Entry)
 (schema-out entry)
 (contract-out
  [entry->Entry (-> entry? Entry?)]
  [commit! (-> string? entry?)]
  [update! (-> id/c string? entry?)]
  [archive-entry! (-> id/c (or/c #f entry?))]
  [snooze-entry! (-> id/c exact-positive-integer? void?)]
  [delete-entry! (-> id/c void?)]
  [find-pending-entries (-> (listof entry?))]
  [find-due-entries (-> (listof entry?))]))

(define entry-status/c
  (or/c 'pending 'archived 'deleted))

(define recurrence-modifier/c
  (or/c 'hour 'day 'week 'month 'year))

(define-record Entry
  [id : UVarint]
  [title : String]
  [due-at : (Optional UVarint)]
  [due-in : (Optional String)]
  [recurs : Bool])

(define (entry->Entry e)
  (make-Entry
   #:id (entry-id e)
   #:title (entry-title e)
   #:due-at (let ([due-at (entry-due-at e)])
              (and (not (sql-null? due-at))
                   (exact-floor (->posix due-at))))
   #:due-in (entry-due-in e)
   #:recurs (entry-recurs? e)))

(define-schema entry
  #:table "entries"
  ([id id/f #:primary-key #:auto-increment]
   [title string/f #:contract non-empty-string? #:wrapper string-trim]
   [(body "") string/f]
   [(status 'pending) symbol/f #:contract entry-status/c]
   [(due-at (now)) datetime/f #:nullable]
   [next-recurrence-at datetime/f #:nullable]
   [recurrence-delta integer/f #:nullable]
   [recurrence-modifier symbol/f #:nullable #:contract recurrence-modifier/c]
   [(created-at (now)) datetime/f]
   [(updated-at (now)) datetime/f])

  #:pre-persist-hook
  (lambda (e)
    (set-entry-updated-at e (now))))

(module+ private
  (provide entry-recurs?))

(define (entry-recurs? e)
  (and (not (sql-null? (entry-next-recurrence-at e)))
       (not (sql-null? (entry-recurrence-delta e)))
       (not (sql-null? (entry-recurrence-modifier e)))))

(define (entry-recurrence e)
  (TokenData.recurrence
   (entry-recurrence-delta e)
   (entry-recurrence-modifier e)))

(define (entry-due-in e)
  (cond
    [(sql-null? (entry-due-at e)) #f]
    [else
     (define t (now))
     (define due (entry-due-at e))
     (define delta (seconds-between t due))
     (cond
       [(<= delta 0)
        "past due"]

       [(>= delta (* 7 86400))
        (~a "due on " (if (= (->year due)
                             (->year (now)))
                          (~t due "MMM dd")
                          (~t due "MMM dd, yyyy")))]

       [(or (> (days-between t due) 1)
            (date=? (->date (+days t 2))
                    (->date due)))
        (~a "due in " (format-delta (add1 (days-between t due)) "day" "days"))]

       [(date=? (->date (+days t 1))
                (->date due))
        (cond
          [(>= (->hours due) 23) "due tomorrow night"]
          [(>= (->hours due) 17) "due tomorrow evening"]
          [(>= (->hours due) 12) "due tomorrow afternoon"]
          [(>= (->hours due) 11) "due at noon tomorrow"]
          [(>= (->hours due) 5)  "due tomorrow morning"]
          [else                  "due tonight"])]

       [(>= delta (* 3600 4))
        (cond
          [(>= (->hours due) 23) "due tonight"]
          [(>= (->hours due) 17) "due this evening"]
          [(>= (->hours due) 12) "due this afternoon"]
          [(>= (->hours due) 11) "due at noon"]
          [(>= (->hours due) 5)  "due this morning"]
          [else                  "due today"])]

       [(>= delta 3600)
        (~a "due in " (format-delta (add1 (hours-between t due)) "hour" "hours"))]

       [(>= delta 60)
        (~a "due in " (format-delta (add1 (minutes-between t due)) "minute" "minutes"))]

       [else
        "due in under a minute"])]))

(define (format-delta d singular plural)
  (format "~a ~a" d (if (= d 1)
                        singular
                        plural)))

(define (process-command command
                         #:init-due [init-due #f]
                         #:init-rec [init-rec #f]
                         #:init-tags [init-tags null])
  (define tokens (parse-command command))
  (define out (open-output-string))
  (define-values (due rec tags)
    (parameterize ([current-output-port out])
      (for/fold ([due init-due]
                 [rec init-rec]
                 [tags init-tags])
                ([token (in-list tokens)])
        (match (Token-data token)
          [#f
           (begin0 (values due rec tags)
             (display (Token-text token)))]

          [(and (TokenData.relative-time delta modifier) r)
           (define adder
             (case modifier
               [(m) +minutes]
               [(h) +hours]
               [(d) +days]
               [(w) +weeks]
               [(M) +months]))
           (values (adder (or due (now)) delta) rec tags)]

          [(TokenData.named-datetime dt)
           (values dt rec tags)]

          [(TokenData.named-date d)
           (define t (if due (->time due) (time 8 0)))
           (values (at-time d t) rec tags)]

          [(and (TokenData.recurrence _delta _modifier) the-rec)
           (values due the-rec tags)]

          [(TokenData.tag name)
           (values due rec (cons name tags))]))))

  (values (get-output-string out)
          due
          rec
          tags))

(define (recurrence-next data due)
  (match-define (TokenData.recurrence delta modifier)
    data)
  (define adder
    (case modifier
      [(hour)  +hours]
      [(day)   +days]
      [(week)  +weeks]
      [(month) +months]
      [(year)  +years]))
  (let loop ([due due])
    (define next-due
      (adder due delta))
    (cond
      [(datetime>=? next-due (now)) next-due]
      [else (loop next-due)])))

(define (commit! command)
  (define-values (title due rec tags)
    (process-command command))

  (define-values (next-rec-at rec-delta rec-modifier)
    (match (and due rec)
      [(TokenData.recurrence delta modifier)
       (values (recurrence-next rec due) delta modifier)]
      [_
       (values #f #f #f)]))

  (call-with-database-transaction
    (lambda (conn)
      (define the-entry
        (~> (make-entry #:title title
                        #:due-at (or due sql-null)
                        #:next-recurrence-at (or next-rec-at sql-null)
                        #:recurrence-delta (or rec-delta sql-null)
                        #:recurrence-modifier (or rec-modifier sql-null))
            (insert-one! conn _)))

      (begin0 the-entry
        (assign-tags! (entry-id the-entry) tags)
        (entries-did-change)))))

(define (update! id command)
  (call-with-database-transaction
    (lambda (conn)
      (cond
        [(lookup conn (~> (from entry #:as e)
                          (where (= e.id ,id))))
         => (lambda (the-entry)
              ;; Scenario 1:
              ;;  - (commit! "buy milk +1h")
              ;;  - (update! 1 "buy milk +1h")
              ;;  - *entry is due in 2 hours*
              ;;
              ;; Scenario 2:
              ;;  - (commit! "buy milk +1h")
              ;;  - *4 hours pass*
              ;;  - (update! 1 "buy milk +1")
              ;;  - *entry is due in 1 hour*
              (define due/dwim
                (cond
                  [(sql-> (entry-due-at the-entry))
                   => (lambda (due)
                        (cond
                          [(datetime>=? due (now)) due]
                          [else (now)]))]

                  [else #f]))

              (define-values (title due rec tags)
                (process-command command
                                 #:init-due due/dwim
                                 #:init-rec (and (entry-recurs? the-entry)
                                                 (entry-recurrence the-entry))
                                 #:init-tags (find-tags-by-entry-id conn id)))

              (define-values (next-rec-at rec-delta rec-modifier)
                (match (and due rec)
                  [(TokenData.recurrence delta modifier)
                   (values (recurrence-next rec due) delta modifier)]
                  [_
                   (values #f #f #f)]))

              (define updated-entry
                (~> the-entry
                    (set-entry-title title)
                    (set-entry-due-at (or due sql-null))
                    (set-entry-next-recurrence-at (or next-rec-at sql-null))
                    (set-entry-recurrence-delta (or rec-delta sql-null))
                    (set-entry-recurrence-modifier (or rec-modifier sql-null))
                    (update-one! conn _)))

              (begin0 updated-entry
                (assign-tags! id tags)
                (entries-did-change)
                (push-undo!
                 (lambda ()
                   ;; TODO: undo tag changes!
                   (~> updated-entry
                       (set-entry-title (entry-title the-entry))
                       (set-entry-due-at (or (entry-due-at the-entry) sql-null))
                       (set-entry-next-recurrence-at (or (entry-next-recurrence-at the-entry) sql-null))
                       (set-entry-recurrence-delta (or (entry-recurrence-delta the-entry) sql-null))
                       (set-entry-recurrence-modifier (or (entry-recurrence-modifier the-entry) sql-null))
                       (update-one! conn _))
                   (entries-did-change)))))]
        [else #f]))))

(define pending-entries
  (~> (from entry #:as e)
      (where (= e.status "pending"))))

(define (archive-entry! id)
  (call-with-database-transaction
    (lambda (conn)
      (define the-entry
        (~> (from entry #:as e)
            (where (= e.id ,id))
            (lookup conn _)))

      (cond
        [(not the-entry)]

        [(entry-recurs? the-entry)
         (define rec (entry-recurrence the-entry))
         (define old-due-at (entry-due-at the-entry))
         (define new-due-at
           (if (datetime>=? (entry-next-recurrence-at the-entry) (now))
               (entry-next-recurrence-at the-entry)
               (recurrence-next rec (entry-next-recurrence-at the-entry))))
         (define old-rec-at (entry-next-recurrence-at the-entry))
         (define new-rec-at (recurrence-next rec new-due-at))
         (define updated-entry
           (~> the-entry
               (set-entry-due-at new-due-at)
               (set-entry-next-recurrence-at new-rec-at)
               (update-one! conn _)))
         (begin0 updated-entry
           (entries-did-change)
           (push-undo!
            (lambda ()
              (call-with-database-connection
                (lambda (conn)
                  (~> updated-entry
                      (set-entry-due-at old-due-at)
                      (set-entry-next-recurrence-at old-rec-at)
                      (update-one! conn _))))
              (entries-did-change))))]

        [else
         (define updated-entry
           (update-one! conn (set-entry-status the-entry 'archived)))
         (begin0 updated-entry
           (entries-did-change)
           (push-undo!
            (lambda ()
              (call-with-database-connection
                (lambda (conn)
                  (~> updated-entry
                      (set-entry-status 'pending)
                      (update-one! conn _))))
              (entries-did-change))))]))))

(define (snooze-entry! id amount)
  (define the-entry
    (call-with-database-transaction
      (lambda (conn)
        (and~> (lookup conn (~> (from entry #:as e)
                                (where (= e.id ,id))))
               (set-entry-due-at (+minutes (now) amount))
               (update-one! conn _)))))

  (when the-entry
    (entries-did-change)))

(define (delete-entry! id)
  (define the-entry
    (call-with-database-transaction
      (lambda (conn)
        (and~> (lookup conn (~> (from entry #:as e)
                                (where (= e.id ,id))))
               (set-entry-status 'deleted)
               (update-one! conn _)))))

  (when the-entry
    (entries-did-change)
    (push-undo!
     (lambda ()
       (call-with-database-connection
         (lambda (conn)
           (update-one! conn (set-entry-status the-entry 'pending))))
       (entries-did-change)))))

(define (find-pending-entries)
  (call-with-database-connection
    (lambda (conn)
      (~> pending-entries
          (order-by ([(datetime e.due-at)]))
          (query-entities conn _)))))

(define (find-due-entries)
  (call-with-database-connection
    (lambda (conn)
      (~> pending-entries
          (where (and (not (is e.due-at null))
                      (<= (datetime e.due-at)
                          (datetime "now" "localtime"))))
          (query-entities conn _)))))
