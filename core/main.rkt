#lang racket/base

(require racket/cmdline
         "command.rkt"
         "common.rkt"
         "entry.rkt"
         "logging.rkt"
         "notification.rkt"
         "rpc.rkt"
         "server.rkt")

(register-rpc
 [parse-command parse-command/jsexpr]
 [commit-entry! (compose1 entry->jsexpr commit-entry!)]
 [archive-entry! (compose1 unit archive-entry!)]
 [snooze-entry! (compose1 unit snooze-entry!)]
 [find-pending-entries (lambda ()
                         (map entry->jsexpr (find-pending-entries)))])

(module+ main
  (define notifications (make-channel))

  (define-listener (on-entries-changed)
    (define entries (find-pending-entries))
    (unless (null? entries)
      (channel-put notifications (hasheq 'type "entries-changed"
                                         'entries (map entry->jsexpr entries)))))

  (define scheduler
    (thread
     (lambda _
       (let loop ()
         (define deadline (+ (current-inexact-milliseconds) 60000))
         (define entries (find-due-entries))
         (unless (null? entries)
           (channel-put notifications (hasheq 'type "entries-due"
                                              'entries (map entry->jsexpr entries))))
         (sync (alarm-evt deadline))
         (loop)))))

  (define stop-logger
    (start-logger #:levels '((notifications . debug)
                             (server . debug))))

  (define in (current-input-port))
  (define out (current-output-port))
  (file-stream-buffer-mode in 'none)
  (file-stream-buffer-mode out 'none)
  (define stop-server (serve in out notifications))
  (with-handlers ([exn:break?
                   (lambda _
                     (stop-server)
                     (stop-logger))])
    (sync/enable-break never-evt)))
