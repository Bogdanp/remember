#lang racket/base

(require rackunit
         remember/ring
         remember/undo)

(parameterize ([current-undo-ring (make-ring 128)])
  (define x #f)

  (push-undo! (lambda () (set! x 1)))
  (push-undo! (lambda () (set! x 2)))
  (push-undo! (lambda () (set! x 3)))

  (undo!)
  (check-eqv? x 3)

  (undo!)
  (check-eqv? x 2)

  (undo!)
  (check-eqv? x 1)

  (undo!)
  (check-eqv? x 1))
