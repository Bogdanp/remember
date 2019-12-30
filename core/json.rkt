#lang racket/base

(require racket/generic)

(provide
 gen:to-jsexpr
 ->jsexpr
 unit)

(define-generics to-jsexpr
  (->jsexpr to-jsexpr)
  #:fast-defaults
  ([boolean? (define ->jsexpr values)]
   [number?  (define ->jsexpr values)]
   [string?  (define ->jsexpr values)]
   [symbol?  (define ->jsexpr symbol->string)]
   [list?
    (define/generic ->jsexpr/super ->jsexpr)
    (define (->jsexpr xs)
      (map ->jsexpr/super xs))]))

;; Composes with RPCs that have no return value (i.e. return void?) to
;; generate RPCUnit results.
(define (unit _)
  (hasheq))
