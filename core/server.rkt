#lang racket/base

(require json
         racket/async-channel
         racket/contract
         racket/match
         racket/port
         "rpc.rkt")

(provide
 serve)

(define-logger server)

(define/contract (serve in out [notifications-ch (make-channel)])
  (->* (input-port? output-port?) (channel?) (-> void?))
  (define stopped (make-semaphore))

  (define writes-ch (make-async-channel 128))
  (define (send response)
    (async-channel-put writes-ch response))

  (define thd
    (thread
     (lambda _
       (let loop ()
         (log-server-debug "waiting for events")
         (sync
          (handle-evt
           stopped
           (lambda _
             (log-server-debug "received stop event")))

          (handle-evt
           writes-ch
           (lambda (data)
             (log-server-debug "received write event: ~.s" data)
             (write-json data out)
             (loop)))

          (handle-evt
           notifications-ch
           (lambda (data)
             (log-server-debug "received notification: ~.s" data)
             (send (hash 'notification data))
             (loop)))

          (handle-evt
           in
           (lambda _
             (log-server-debug "received read event")
             (define req (read-json in))
             (unless (eof-object? req)
               (thread
                (lambda _
                  (log-server-debug "handling request: ~.s" req)
                  (with-handlers ([exn:fail:read?
                                   (lambda (e)
                                     (define message (format "invalid JSON:\n  ~.a" (exn-message e)))
                                     (log-server-warning message)
                                     (send (hasheq 'error message)))]
                                  [exn:misc:match?
                                   (lambda (e)
                                     (define message (format "malformed request:\n   ~.a" (exn-message e)))
                                     (log-server-warning message)
                                     (send (hasheq 'error message)))]
                                  [exn:fail?
                                   (lambda (e)
                                     (log-server-error (exn-message e))
                                     (raise e))])
                    (match-define (hash-table ['id   id]
                                              ['name name]
                                              ['args args]) req)

                    (define res
                      (with-handlers ([exn:fail? (lambda (e)
                                                   (log-server-warning "error: ~.s" (exn-message e))
                                                   (hasheq 'error (exn-message e)))])
                        (hasheq 'result (dispatch (string->symbol name) args))))

                    (send (hash-set res 'id id)))))

               (loop)))))))))

  (lambda ()
    (void
     (semaphore-post stopped)
     (sync thd))))

(module+ test
  (require rackunit)

  (parameterize ([current-rpc-registry (make-hasheq)])
    (define-values (c-in c-out) (make-pipe))
    (define-values (s-in s-out) (make-pipe))

    (register-rpc add1 sub1)

    (define stop
      (serve s-in c-out))

    (parameterize ([current-input-port c-in]
                   [current-output-port s-out])
      (write-json (hasheq 'foo 1))
      (let ([res (read-json)])
        (check-regexp-match "malformed request" (hash-ref res 'error)))

      (write-json (hasheq 'id 0 'name "invalid" 'args '()))
      (let ([res (read-json)])
        (check-equal? (hash-ref res 'id) 0)
        (check-regexp-match "procedure invalid not found" (hash-ref res 'error)))

      (write-json (hasheq 'id 0 'name "add1" 'args '()))
      (let ([res (read-json)])
        (check-equal? (hash-ref res 'id) 0)
        (check-regexp-match  "arity mismatch" (hash-ref res 'error)))

      (write-json (hasheq 'id 0 'name "add1" 'args '(4)))
      (let ([res (read-json)])
        (check-equal? (hash-ref res 'id) 0)
        (check-equal? (hash-ref res 'result) 5))

      (write-json (hasheq 'id 0 'name "sub1" 'args '(4)))
      (let ([res (read-json)])
        (check-equal? (hash-ref res 'id) 0)
        (check-equal? (hash-ref res 'result) 3)))

    (stop)))
