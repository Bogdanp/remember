#lang racket/base

(require (for-syntax racket/base
                     syntax/parse)
         racket/contract)

(provide
 define/listener
 notify)

(define-logger notifications)

(define notifications-registry/c
  (and/c hash-eq? (hash/c symbol? (listof procedure?)) (not/c immutable?)))

(define/contract current-notifications-registry
  (parameter/c notifications-registry/c)
  (make-parameter (make-hasheq)))

(define/contract (add-listener! notification f)
  (-> symbol? procedure? void?)
  (hash-update! (current-notifications-registry)
                notification
                (lambda (listeners)
                  (cons f listeners))
                null))

(define/contract (notify notification . args)
  (-> symbol? any/c ... void?)
  (define listeners
    (hash-ref (current-notifications-registry)
                   notification
                   (lambda _
                     (error 'notify "unknown notification ~.s" notification))))

  (log-notifications-debug "dispatching ~.s to ~a listeners" notification (length listeners))
  (define threads
    (for/list ([listener (in-list listeners)])
      (thread
       (lambda _
         (apply listener args)))))

  (for-each sync threads))

(define-syntax (define/listener stx)
  (syntax-parse stx
    [(_ (notification:id . args) e ...+)
     #'(add-listener! 'notification (lambda args
                                      e ...))]))

(module+ test
  (require rackunit)

  (parameterize ([current-notifications-registry (make-hasheq)])
    (define listener-1-notified? #f)
    (define listener-2-notified? #f)
    (define listener-3-notified? #f)

    (define/listener (on-entries-changed)
      (set! listener-1-notified? #t))

    (define/listener (on-entries-changed)
      (error 'on-entries-changed "this failure should not impact anything else"))

    (define/listener (on-entries-changed)
      (set! listener-2-notified? #t))

    (define/listener (on-entry-deleted e)
      (set! listener-3-notified? #t))

    (notify 'on-entries-changed)
    (check-true listener-1-notified?)
    (check-true listener-2-notified?)
    (check-false listener-3-notified?)

    (notify 'on-entry-deleted #f)
    (check-true listener-3-notified?)))
