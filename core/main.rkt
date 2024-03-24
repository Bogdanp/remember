#lang racket/base

(require "command.rkt"
         "database.rkt"
         "entry.rkt"
         "json.rkt"
         "logging.rkt"
         "notification.rkt"
         "rpc.rkt"
         "schema.rkt"
         "server.rkt"
         "undo.rkt")

(define notifications (make-channel))

(backup-database!)
(migrate!)
(register-rpc
 [parse-command parse-command/jsexpr]
 [commit! (compose1 ->jsexpr commit!)]
 [update! (compose1 ->jsexpr update!)]
 [archive-entry! (compose1 unit archive-entry!)]
 [snooze-entry! (compose1 unit snooze-entry!)]
 [delete-entry! (compose1 unit delete-entry!)]
 [find-pending-entries (compose1 ->jsexpr find-pending-entries)]
 [undo! (compose1 unit undo!)]
 create-database-copy!
 [merge-database-copy! (compose1 unit merge-database-copy!)])

(define-listener (entries-did-change)
  (channel-put notifications (hasheq 'type "entries-did-change")))

(module+ main
  (define scheduler
    (thread
     (lambda ()
       (let loop ()
         (define deadline (+ (current-inexact-milliseconds) 30000))
         (define entries (find-due-entries))
         (unless (null? entries)
           (channel-put notifications (hasheq 'type "entries-due"
                                              'entries (->jsexpr entries))))
         (sync (alarm-evt deadline))
         (loop)))))

  (define stop-logger
    (start-logger #:levels '((notifications . debug)
                             (server . debug))))

  (define in (current-input-port))
  (define out (current-output-port))
  (file-stream-buffer-mode in 'none)
  (file-stream-buffer-mode out 'none)
  (define-values (server stop-server)
    (serve in out notifications))
  (with-handlers ([exn:break?
                   (lambda ()
                     (stop-server)
                     (stop-logger))])
    (sync/enable-break server)))
