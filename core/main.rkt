#lang racket/base

(require racket/cmdline
         "command.rkt"
         "rpc.rkt"
         "server.rkt")

(define command-mode (make-parameter #f))

(register-rpc
 parse-command)

(module+ main
  (command-line
   #:once-each
   [("--command" "-c") "Run a single command."
                       (command-mode #t)])

  (define in (current-input-port))
  (define out (current-output-port))
  (file-stream-buffer-mode in 'none)
  (file-stream-buffer-mode out 'none)
  (define stop (serve in out))
  (with-handlers ([exn:break?
                   (lambda _
                     (stop))])
    (sync/enable-break never-evt)))
