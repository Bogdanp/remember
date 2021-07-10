#lang racket/base

(require (for-syntax racket/base
                     syntax/parse)
         racket/contract)

(provide
 current-rpc-registry
 register-rpc
 dispatch)

(define/contract current-rpc-registry
  (parameter/c (and/c hash-eq? (not/c immutable?)))
  (make-parameter (make-hasheq)))

(define/contract (register! name fn)
  (-> symbol? procedure? void?)
  (hash-set! (current-rpc-registry) name fn))

(define-syntax (register-rpc stx)
  (define-syntax-class command
    (pattern (id:id e))
    (pattern id:id #:with e #'id))

  (syntax-parse stx
    [(_ command:command ...+)
     #'(begin
         (register! 'command.id command.e) ...)]))

(define/contract (dispatch name [args null])
  (->* (symbol?) ((listof any/c)) any/c)
  (apply (hash-ref (current-rpc-registry)
                   name
                   (lambda ()
                     (error 'dispatch "procedure ~.s not found" name)))
         args))

(module+ test
  (require rackunit)

  (parameterize ([current-rpc-registry (make-hasheq)])
    (register-rpc add1
                  [ping (lambda _
                          "PONG")])

    (check-eqv? (dispatch 'add1 '(1)) 2)
    (check-equal? (dispatch 'ping '()) "PONG")
    (check-exn
     (lambda (e)
       (and (exn:fail? e)
            (check-regexp-match "procedure foo not found" (exn-message e))))
     (lambda _
       (dispatch 'foo '())))))
