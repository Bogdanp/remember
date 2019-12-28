#lang racket/base

(provide
 unit)

;; Composes with RPCs that have no return value (i.e. return void?) to
;; generate RPCUnit results.
(define (unit _)
  (hasheq))
