#lang racket/base

(require json
         racket/match
         "rpc.rkt")

(provide
 serve)

(define-logger server)

(define (serve in out [notifications (make-channel)])
  (define sem (make-semaphore))
  (define _
    (thread
     (lambda _
       (let loop ()
         (sync
          (handle-evt
           sem
           (lambda _
             (close-input-port in)
             (close-output-port out)))
          (handle-evt
           notifications
           (lambda (data)
             (write-json (hash-set data 'notification #t) out)
             (loop)))
          (handle-evt
           in
           (lambda _
             (define req (read-json in))
             (unless (eof-object? req)
               (thread
                (lambda _
                  (with-handlers ([exn:fail:read?
                                   (lambda (e)
                                     (write-json (hasheq 'error (format "invalid JSON:\n  ~.a" (exn-message e))) out))]
                                  [exn:misc:match?
                                   (lambda (e)
                                     (write-json (hasheq 'error (format "malformed request:\n   ~.a" (exn-message e))) out))])
                    (match-define (hash-table ['id   id]
                                              ['name name]
                                              ['args args]) req)

                    (define res
                      (with-handlers ([exn:fail? (lambda (e)
                                                   (hasheq 'error (exn-message e)))])
                        (hasheq 'result (dispatch name args))))

                    (write-json (hash-set res 'id id) out))))

               (loop)))))))))

  (lambda _
    (semaphore-post sem)))

(module+ test
  (require rackunit)

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
      (check-regexp-match "procedure \"invalid\" not found" (hash-ref res 'error)))

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

  (stop))
