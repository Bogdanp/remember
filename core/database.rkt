#lang racket/base

(require db
         gregor
         racket/contract
         racket/file
         racket/format
         racket/list
         racket/path
         "appdata.rkt")

(provide
 id/c
 isolation-level/c

 make-db
 current-db
 call-with-database-connection
 call-with-database-transaction
 sql->
 backup-database!
 create-database-copy!
 merge-database-copy!)

(define id/c
  exact-nonnegative-integer?)

(define isolation-level/c
  (or/c false/c
        'serializable
        'repeatable-read
        'read-committed
        'read-uncommitted))

(struct db (conn sem)
  #:transparent)

(define/contract (make-db connector)
  (-> (-> connection?) db?)
  (db (connector)
      (make-semaphore 1)))

(define/contract current-db
  (parameter/c db?)
  (make-parameter
   (make-db (lambda ()
              (sqlite3-connect #:mode 'create
                               #:database (build-application-path "remember.sqlite3")
                               #:use-place 'os-thread)))))

(define current-connection
  (make-parameter #f))

(define/contract (call-with-database-connection f #:db [the-db (current-db)])
  (->* ((-> connection? any)) (#:db db?) any)
  (call-with-semaphore (db-sem the-db)
    (lambda _
      (f (db-conn the-db)))))

(define/contract (call-with-database-transaction f
                   #:db [the-db (current-db)]
                   #:isolation [isolation #f])
  (->* ((-> connection? any))
       (#:db db?
        #:isolation isolation-level/c)
       any)
  (cond
    [(current-connection)
     => (lambda (conn)
          (call-with-transaction conn
            (lambda _
              (f conn))))]

    [else
     (call-with-database-connection
       #:db the-db
       (lambda (conn)
         (parameterize ([current-connection conn])
           (call-with-transaction conn
             #:isolation isolation
             (lambda _
               (f conn))))))]))

(define (sql-> v)
  (cond
    [(sql-null? v) #f]
    [else v]))

(define max-backups 7)

(define (delete-old-backups!)
  (define all-backups
    (sort
     (find-files
      (lambda (p)
        (equal? (path-get-extension p) #".bak"))
      (build-application-path))
     (lambda (a b)
       (bytes<? (path->bytes a)
                (path->bytes b)))))

  (when (> (length all-backups) max-backups)
    (for-each delete-file (drop-right all-backups max-backups))))

(define (backup-database!)
  (define database-path (build-application-path "remember.sqlite3"))
  (when (file-exists? database-path)
    (define backup-suffix (~a "-" (~t (today) "yyyy-MM-dd") ".bak"))
    (define backup-path (path-add-extension database-path (string->bytes/utf-8 backup-suffix)))
    (copy-file database-path backup-path #t)
    (delete-old-backups!)))

(define (create-database-copy!)
  (define path (path->string (make-temporary-file)))
  (begin0 path
    (delete-file path)
    (call-with-database-connection
      (lambda (conn)
        (query-exec conn "vacuum into ?" path)))))

(define (merge-database-copy! path)
  (call-with-database-connection
    (lambda (conn)
      (dynamic-wind
        (lambda ()
          (query-exec conn "attach ? as newer_db" path))
        (lambda ()
          (call-with-transaction conn
            (lambda ()
              (query-exec conn #<<QUERY
INSERT INTO entries
  SELECT *
    FROM newer_db.entries
    WHERE true
  ON CONFLICT(id)
  DO UPDATE SET
      title=excluded.title,
      body=excluded.body,
      status=excluded.status,
      due_at=excluded.due_at,
      next_recurrence_at=excluded.next_recurrence_at,
      recurrence_delta=excluded.recurrence_delta,
      recurrence_modifier=excluded.recurrence_modifier,
      created_at=excluded.created_at,
      updated_at=excluded.updated_at
    WHERE DATETIME(excluded.updated_at) > DATETIME(updated_at)
QUERY
                          )

              (query-exec conn #<<QUERY
INSERT INTO tags
  SELECT *
    FROM newer_db.tags
    WHERE true
  ON CONFLICT(id)
  DO NOTHING
QUERY
                          )

              (query-exec conn #<<QUERY
INSERT INTO entry_tags
  SELECT *
    FROM newer_db.entry_tags
    WHERE true
  ON CONFLICT(entry_id, tag_id)
  DO NOTHING
QUERY
                          ))))
        (lambda ()
          (query-exec conn "detach newer_db"))))))
