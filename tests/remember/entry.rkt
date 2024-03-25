#lang racket/base

(require db
         (except-in deta update!)
         gregor
         racket/match
         rackunit
         remember/database
         remember/entry
         (submod remember/entry private)
         remember/ring
         remember/schema
         remember/tag
         remember/undo
         threading)

(define (call-with-empty-database proc)
  (parameterize ([current-db (make-db
                              (lambda ()
                                (sqlite3-connect #:database 'memory)))])
    (migrate!)
    (proc)))

(call-with-empty-database
 (lambda ()
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
 (lambda ()
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
 (lambda ()
   (define t0 (now))
   (define the-entry
     (commit! "buy milk +1h"))

   (define (reload!)
     (set! the-entry
           (call-with-database-connection
             (lambda (conn)
               (lookup conn (~> (from entry #:as e)
                                (where (= e.id ,(entry-id the-entry)))))))))

   (snooze-entry! (entry-id the-entry) 45)
   (reload!)
   (check-eqv? (minutes-between t0 (entry-due-at the-entry)) 45)))

(call-with-empty-database
 (lambda ()
   (define t0 (now))
   (define the-entry
     (commit! "buy milk +1h +15m"))

   (check-eqv? (minutes-between t0 (entry-due-at the-entry)) 75)))

(parameterize ([current-clock (lambda () 0)])
  (call-with-empty-database
   (lambda ()
     (define the-entry
       (commit! "buy milk @mon +1h +15m"))

     (check-equal? (entry-due-at the-entry)
                   (datetime 1970 1 5 9 15)))))

(parameterize ([current-undo-ring (make-ring 128)])
  (call-with-empty-database
   (lambda ()
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
 (lambda ()
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
   (lambda ()
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

(parameterize ([current-clock (lambda () 0)])
  (call-with-empty-database
   (lambda ()
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

     (parameterize ([current-clock (lambda ()
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

(parameterize ([current-clock (lambda () 0)])
  (call-with-empty-database
   (lambda ()
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
                   '("accounting" "important")))))
