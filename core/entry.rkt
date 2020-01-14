#lang racket/base

(require db
         deta
         gregor
         gregor/time
         json
         racket/contract
         racket/format
         (only-in racket/list remove-duplicates)
         racket/match
         racket/sequence
         racket/string
         threading
         "command.rkt"
         "database.rkt"
         "json.rkt"
         "notification.rkt"
         "tag.rkt"
         "undo.rkt")

(provide
 (schema-out entry)
 commit!
 update!
 archive-entry!
 snooze-entry!
 delete-entry!
 find-pending-entries
 find-due-entries)

(define entry-status/c
  (or/c 'pending 'archived 'deleted))

(define recurrence-modifier/c
  (or/c 'hour 'day 'week 'month 'year))

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
   [(created-at (now)) datetime/f])

  #:methods gen:to-jsexpr
  [(define (->jsexpr e)
     (hasheq 'id (entry-id e)
             'title (entry-title e)
             'due-in (or (entry-due-in e)
                         (json-null))
             'recurs? (entry-recurs? e)))])

(define (entry-recurs? e)
  (and (not (sql-null? (entry-next-recurrence-at e)))
       (not (sql-null? (entry-recurrence-delta e)))
       (not (sql-null? (entry-recurrence-modifier e)))))

(define (entry-recurrence e)
  (recurrence #f #f (entry-recurrence-delta e) (entry-recurrence-modifier e)))

(define (entry-due-in e)
  (and (not (sql-null? (entry-due-at e)))
       (let* ([t (now)]
              [due (entry-due-at e)]
              [delta (seconds-between t due)])
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
            "due in under a minute"]))))

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
        (match token
          [(chunk text span)
           (begin0 (values due rec tags)
             (display text))]

          [(and (relative-time text span delta modifier) r)
           (define adder (relative-time-adder r))
           (values (adder (or due (now)))
                   rec
                   tags)]

          [(named-datetime text span dt)
           (values dt rec tags)]

          [(named-date text span d)
           (define t (if due (->time due) (time 8 0)))
           (values (at-time d t) rec tags)]

          [(and (recurrence text span delta modifier) the-rec)
           (values due the-rec tags)]

          [(tag text span name)
           (values due rec (cons name tags))]))))


  (values (get-output-string out)
          due
          rec
          tags))

(define/contract (commit! command)
  (-> string? entry?)
  (define-values (title due rec tags)
    (process-command command))

  (define-values (next-rec-at rec-delta rec-modifier)
    (if (and due rec)
        (values (recurrence-next rec due)
                (recurrence-delta rec)
                (recurrence-modifier rec))
        (values #f #f #f)))

  (call-with-database-transaction
    (lambda (conn)
      (define the-entry
        (insert-one! conn
                     (make-entry #:title title
                                 #:due-at (or due sql-null)
                                 #:next-recurrence-at (or next-rec-at sql-null)
                                 #:recurrence-delta (or rec-delta sql-null)
                                 #:recurrence-modifier (or rec-modifier sql-null))))

      (begin0 the-entry
        (assign-tags! (entry-id the-entry) tags)
        (notify 'entries-did-change)))))

(define/contract (update! id command)
  (-> id/c string? entry?)
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
                (if (and due rec)
                    (values (recurrence-next rec due)
                            (recurrence-delta rec)
                            (recurrence-modifier rec))
                    (values #f #f #f)))

              (define updated-entry
                (update-one! conn (~> the-entry
                                      (set-entry-title title)
                                      (set-entry-due-at (or due sql-null))
                                      (set-entry-next-recurrence-at (or next-rec-at sql-null))
                                      (set-entry-recurrence-delta (or rec-delta sql-null))
                                      (set-entry-recurrence-modifier (or rec-modifier sql-null)))))

              (begin0 updated-entry
                (assign-tags! id tags)
                (notify 'entries-did-change)
                (push-undo! (lambda _
                              ;; TODO: undo tag changes!
                              (update-one! conn (~> updated-entry
                                                    (set-entry-title (entry-title the-entry))
                                                    (set-entry-due-at (or (entry-due-at the-entry) sql-null))
                                                    (set-entry-next-recurrence-at (or (entry-next-recurrence-at the-entry) sql-null))
                                                    (set-entry-recurrence-delta (or (entry-recurrence-delta the-entry) sql-null))
                                                    (set-entry-recurrence-modifier (or (entry-recurrence-modifier the-entry) sql-null))))))))]
        [else #f]))))

(define pending-entries
  (~> (from entry #:as e)
      (where (= e.status "pending"))))

(define due-entries
  (~> pending-entries
      (where (and (not (is e.due-at null))
                  (< (datetime e.due-at)
                     (datetime "now" "localtime"))))))

(define/contract (archive-entry! id)
  (-> id/c (or/c false/c entry?))
  (call-with-database-transaction
    (lambda (conn)
      (define the-entry
        (lookup conn (~> (from entry #:as e)
                         (where (= e.id ,id)))))

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
           (update-one! conn (~> the-entry
                                 (set-entry-due-at new-due-at)
                                 (set-entry-next-recurrence-at new-rec-at))))
         (begin0 updated-entry
           (notify 'entries-did-change)
           (push-undo! (lambda _
                         (call-with-database-connection
                           (lambda (conn)
                             (update-one! conn (~> updated-entry
                                                   (set-entry-due-at old-due-at)
                                                   (set-entry-next-recurrence-at old-rec-at)))
                             (notify 'entries-did-change))))))]

        [else
         (define updated-entry
           (update-one! conn (set-entry-status the-entry 'archived)))
         (begin0 updated-entry
           (notify 'entries-did-change)
           (push-undo! (lambda _
                         (call-with-database-connection
                           (lambda (conn)
                             (update-one! conn (set-entry-status updated-entry 'pending))
                             (notify 'entries-did-change))))))]))))

(define/contract (snooze-entry! id)
  (-> id/c void?)
  (define the-entry
    (call-with-database-transaction
      (lambda (conn)
        (and~> (lookup conn (~> (from entry #:as e)
                                (where (= e.id ,id))))
               (set-entry-due-at (+minutes (now) 45))
               (update-one! conn _)))))

  (when the-entry
    (void (notify 'entries-did-change))))

(define/contract (delete-entry! id)
  (-> id/c void?)
  (define the-entry
    (call-with-database-transaction
      (lambda (conn)
        (and~> (lookup conn (~> (from entry #:as e)
                                (where (= e.id ,id))))
               (set-entry-status 'deleted)
               (update-one! conn _)))))

  (when the-entry
    (notify 'entries-did-change)
    (push-undo! (lambda _
                  (call-with-database-connection
                    (lambda (conn)
                      (update-one! conn (set-entry-status the-entry 'pending))))))))

(define/contract (find-pending-entries)
  (-> (listof entry?))
  (call-with-database-connection
    (lambda (conn)
      (sequence->list (in-entities conn
                                   (~> pending-entries
                                       (order-by ([(datetime e.due-at)]))))))))

(define/contract (find-due-entries)
  (-> (listof entry?))
  (call-with-database-connection
    (lambda (conn)
      (sequence->list (in-entities conn due-entries)))))

(module+ test
  (require rackunit
           "ring.rkt"
           "schema.rkt"
           "testing.rkt")

  (call-with-empty-database
   (lambda _
     (define the-entry
       (commit! "buy milk"))

     (check-match
      the-entry
      (struct* entry ([title "buy milk"]
                      [body ""]
                      [status 'pending])))

     (check-not-false (member (entry-id the-entry)
                              (map entry-id (find-pending-entries))))))

  (call-with-empty-database
   (lambda _
     (define t0 (now))
     (define the-entry
       (commit! "buy milk +1h"))

     (check-match
      the-entry
      (struct* entry ([title "buy milk"]
                      [body ""]
                      [status 'pending])))

     (check-eqv? (minutes-between t0 (entry-due-at the-entry)) 60)
     (check-true (null? (find-due-entries)))
     (check-not-false (member (entry-id the-entry)
                              (map entry-id (find-pending-entries))))

     (archive-entry! (entry-id the-entry))
     (check-false (member (entry-id the-entry)
                          (map entry-id (find-pending-entries))))))

  (call-with-empty-database
   (lambda _
     (define t0 (now))
     (define the-entry
       (commit! "buy milk +1h"))

     (define (reload!)
       (set! the-entry
             (call-with-database-connection
               (lambda (conn)
                 (lookup conn (~> (from entry #:as e)
                                  (where (= e.id ,(entry-id the-entry)))))))))

     (snooze-entry! (entry-id the-entry))
     (reload!)
     (check-eqv? (minutes-between t0 (entry-due-at the-entry)) 45)))

  (call-with-empty-database
   (lambda _
     (define t0 (now))
     (define the-entry
       (commit! "buy milk +1h +15m"))

     (check-eqv? (minutes-between t0 (entry-due-at the-entry)) 75)))

  (parameterize ([current-clock (lambda _ 0)])
    (call-with-empty-database
     (lambda _
       (define the-entry
         (commit! "buy milk @mon +1h +15m"))

       (check-equal? (entry-due-at the-entry)
                     (datetime 1970 1 5 9 15)))))

  (parameterize ([current-undo-ring (make-ring 128)])
    (call-with-empty-database
     (lambda _
       (define the-entry
         (commit! "buy milk +1h +15m"))

       (archive-entry! (entry-id the-entry))
       (check-equal? (entry-status
                      (call-with-database-connection
                        (lambda (conn)
                          (lookup conn
                                  (~> (from entry #:as e)
                                      (where (= e.id ,(entry-id the-entry))))))))
                     'archived)

       (undo!)
       (check-equal? (entry-status
                      (call-with-database-connection
                        (lambda (conn)
                          (lookup conn
                                  (~> (from entry #:as e)
                                      (where (= e.id ,(entry-id the-entry))))))))
                     'pending))))

  (call-with-empty-database
   (lambda _
     (define the-entry
       (commit! "buy milk +1d"))

     (assign-tags! (entry-id the-entry) '("groceries" "misc"))
     (assign-tags! (entry-id the-entry) '("groceries" "other"))
     (check-equal? (call-with-database-connection
                     (lambda (conn)
                       (query-list conn "select name from tags order by name")))
                   '("groceries" "misc" "other"))))

  (parameterize ([current-undo-ring (make-ring 128)])
    (call-with-empty-database
     (lambda _
       (define the-entry
         (commit! "buy milk +1d"))

       (define (reload!)
         (set! the-entry
               (call-with-database-connection
                 (lambda (conn)
                   (lookup conn (~> (from entry #:as e)
                                    (where (= e.id ,(entry-id the-entry)))))))))

       (delete-entry! (entry-id the-entry))
       (reload!)
       (check-eq?  (entry-status the-entry) 'deleted)

       (undo!)
       (reload!)
       (check-eq? (entry-status the-entry) 'pending))))

  (parameterize ([current-clock (lambda _ 0)])
    (call-with-empty-database
     (lambda _
       (define the-entry
         (commit! "invoice Tom @10am mon *weekly*"))

       (check-match
        the-entry
        (struct* entry ([title "invoice Tom"]
                        [body ""]
                        [due-at (== (datetime 1970 1 5 10 0))]
                        [next-recurrence-at (== (datetime 1970 1 12 10 0))]
                        [recurrence-delta 1]
                        [recurrence-modifier 'week])))

       (define (reload!)
         (set! the-entry (call-with-database-connection
                           (lambda (conn)
                             (lookup conn (~> (from entry #:as e)
                                              (where (= e.id ,(entry-id the-entry)))))))))

       (archive-entry! (entry-id the-entry))
       (reload!)
       (check-match
        the-entry
        (struct* entry ([title "invoice Tom"]
                        [body ""]
                        [due-at (== (datetime 1970 1 12 10 0))]
                        [next-recurrence-at (== (datetime 1970 1 19 10 0))]
                        [recurrence-delta 1]
                        [recurrence-modifier 'week])))

       (undo!)
       (reload!)
       (check-match
        the-entry
        (struct* entry ([title "invoice Tom"]
                        [body ""]
                        [due-at (== (datetime 1970 1 5 10 0))]
                        [next-recurrence-at (== (datetime 1970 1 12 10 0))]
                        [recurrence-delta 1]
                        [recurrence-modifier 'week])))

       (parameterize ([current-clock (lambda _
                                       (* 14 86400))])
         (archive-entry! (entry-id the-entry))
         (reload!)
         (check-match
          the-entry
          (struct* entry ([title "invoice Tom"]
                          [body ""]
                          [due-at (== (datetime 1970 1 19 10 0))]
                          [next-recurrence-at (== (datetime 1970 1 26 10 0))]
                          [recurrence-delta 1]
                          [recurrence-modifier 'week]))))

       (delete-entry! (entry-id the-entry))
       (undo!)
       (reload!)
       (check-true (entry-recurs? the-entry)))))

  (parameterize ([current-clock (lambda _ 0)])
    (call-with-empty-database
     (lambda _
       (define the-entry
         (commit! "invoice Tom @10am mon *weekly*"))

       (define (reload!)
         (set! the-entry (call-with-database-connection
                           (lambda (conn)
                             (lookup conn (~> (from entry #:as e)
                                              (where (= e.id ,(entry-id the-entry)))))))))

       (update! (entry-id the-entry) "invoice Tommy")
       (reload!)

       (check-match
        the-entry
        (struct* entry ([title "invoice Tommy"]
                        [body ""]
                        [due-at (== (datetime 1970 1 5 10 0))]
                        [next-recurrence-at (== (datetime 1970 1 12 10 0))]
                        [recurrence-delta 1]
                        [recurrence-modifier 'week])))

       (update! (entry-id the-entry) "invoice Tom @11am mon")
       (reload!)

       (check-match
        the-entry
        (struct* entry ([title "invoice Tom"]
                        [body ""]
                        [due-at (== (datetime 1970 1 5 11 0))]
                        [next-recurrence-at (== (datetime 1970 1 12 11 0))]
                        [recurrence-delta 1]
                        [recurrence-modifier 'week])))

       (update! (entry-id the-entry) "invoice Tom *monthly*")
       (reload!)

       (check-match
        the-entry
        (struct* entry ([title "invoice Tom"]
                        [body ""]
                        [due-at (== (datetime 1970 1 5 11 0))]
                        [next-recurrence-at (== (datetime 1970 2 05 11 0))]
                        [recurrence-delta 1]
                        [recurrence-modifier 'month])))

       (define (find-tags)
         (sort
          (call-with-database-connection
            (lambda (conn)
              (find-tags-by-entry-id conn (entry-id the-entry))))
          string<?))

       (check-equal? (find-tags) null)
       (update! (entry-id the-entry) "invoice Tom #accounting #important")
       (reload!)

       (check-match
        the-entry
        (struct* entry ([title "invoice Tom"]
                        [body ""]
                        [due-at (== (datetime 1970 1 5 11 0))]
                        [next-recurrence-at (== (datetime 1970 2 05 11 0))]
                        [recurrence-delta 1]
                        [recurrence-modifier 'month])))
       (check-equal? (find-tags)
                     '("accounting" "important"))))))
