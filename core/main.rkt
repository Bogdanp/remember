#lang racket/base

(require noise/backend
         noise/serde
         "command.rkt"
         "database.rkt"
         "entry.rkt"
         "schema.rkt"
         "undo.rkt")

(provide
 main)

(define-rpc (ping : String)
  "pong")

(define-rpc (parse [command s : String] : (Listof Token))
  (parse-command s))

(define-rpc (commit [command s : String] : Entry)
  (entry->Entry (commit! s)))

(define-rpc (update [entry-with-id id : UVarint]
                    [and-command s : String] : (Optional Entry))
  (define e (update! id s))
  (and e (entry->Entry e)))

(define-rpc (archive [entry-with-id id : UVarint])
  (void (archive-entry! id)))

(define-rpc (snooze [entry-with-id id : UVarint]
                    [for-minutes minutes : UVarint])
  (void (snooze-entry! id minutes)))

(define-rpc (delete [entry-with-id id : UVarint])
  (void (delete-entry! id)))

(define-rpc (get-pending-entries : (Listof Entry))
  (map entry->Entry (find-pending-entries)))

(define-rpc (get-due-entries : (Listof Entry))
  (map entry->Entry (find-due-entries)))

(define-rpc (undo)
  (void (undo!)))

(define-rpc (create-database-copy : String)
  (create-database-copy!))

(define-rpc (merge-database-copy [at-path path : String])
  (merge-database-copy! path))

(define-callout (entries-due-cb [entries : (Listof Entry)]))

(define-rpc (start-scheduler)
  (void (do-start-scheduler)))

(define scheduler-custodian
  (make-custodian))

(define (do-start-scheduler)
  (parameterize ([current-custodian scheduler-custodian])
    (thread
     (lambda ()
       (let loop ()
         (define deadline (+ (current-inexact-milliseconds) 30000))
         (define due-entries (get-due-entries))
         (unless (null? due-entries)
           (entries-due-cb due-entries))
         (sync (alarm-evt deadline))
         (loop))))))

(define (main in-fd out-fd)
  (module-cache-clear!)
  (backup-database!)
  (migrate!)
  (let/cc trap
    (parameterize ([exit-handler
                    (lambda (err-or-code)
                      (when (exn:fail? err-or-code)
                        ((error-display-handler)
                         (format "trap: ~a" (exn-message err-or-code))
                         err-or-code))
                      (trap))])
      (define stop
        (serve in-fd out-fd))
      (with-handlers ([exn:break? void])
        (sync never-evt))
      (stop))))
