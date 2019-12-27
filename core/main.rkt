#lang racket/base

(require racket/cmdline
         "command.rkt"
         "entry.rkt"
         "rpc.rkt"
         "server.rkt")

(register-rpc
 parse-command
 commit-entry!)

(module+ main
  (define notifications (make-channel))
  (define scheduler
    (thread
     (lambda _
       (let loop ()
         (define deadline (+ (current-inexact-milliseconds) 60000))
         (define entries (find-due-entries))
         (when entries
           (channel-put notifications (hasheq 'type "entries-due"
                                              'entries (map entry->jsexpr entries))))
         (sync (alarm-evt deadline))
         (loop)))))

  (define in (current-input-port))
  (define out (current-output-port))
  (file-stream-buffer-mode in 'none)
  (file-stream-buffer-mode out 'none)
  (define stop (serve in out notifications))
  (with-handlers ([exn:break?
                   (lambda _
                     (stop))])
    (sync/enable-break never-evt)))
