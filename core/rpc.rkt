#lang racket/base

(require syntax/parse/define)

(provide
 register-rpc
 dispatch)

(define REGISTRY (make-hasheq))

(define (register! name fn)
  (hash-set! REGISTRY name fn))

(define-simple-macro (register-rpc name:id ...+)
  (begin
    (register! 'name name) ...))

(define (dispatch name args)
  (apply (hash-ref REGISTRY
                   (string->symbol name)
                   (lambda _
                     (error 'dispatch "procedure ~.s not found" name)))
         args))
