#lang racket/base

(require rackunit
         remember/ring)

(define r (make-ring 3))
(ring-push! r 1)
(ring-push! r 2)
(check-equal? (ring-size r) 2)
(check-eqv? (ring-pop! r) 2)

(ring-push! r 2)
(ring-push! r 3)
(ring-push! r 4)
(check-equal? (ring-size r) 3)
(check-eqv? (ring-pop! r) 4)
(check-eqv? (ring-pop! r) 3)
(check-eqv? (ring-pop! r) 2)
(check-false (ring-pop! r))
(check-false (ring-pop! r))

(ring-push! r 1)
(check-eqv? (ring-pop! r) 1)
(check-false (ring-pop! r))
