#lang racket/base

(require racket/generic)

(provide
 gen:to-jsexpr
 ->jsexpr)

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
