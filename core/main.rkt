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
  (define in (current-input-port))
  (define out (current-output-port))
  (file-stream-buffer-mode in 'none)
  (file-stream-buffer-mode out 'none)
  (define stop (serve in out))
  (with-handlers ([exn:break?
                   (lambda _
                     (stop))])
    (sync/enable-break never-evt)))
