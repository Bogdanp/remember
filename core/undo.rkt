#lang racket/base

(require racket/contract
         "ring.rkt")

(provide
 current-undo-ring
 push-undo!
 undo!)

(define/contract current-undo-ring
  (parameter/c ring?)
  (make-parameter (make-ring 128)))

(define/contract (push-undo! f)
  (-> (-> void?) void?)
  (ring-push! (current-undo-ring) f))

(define/contract (undo!)
  (-> void?)
  (define f (ring-pop! (current-undo-ring)))
  (when f (f)))

(module+ test
  (require rackunit)

  (parameterize ([current-undo-ring (make-ring 128)])
    (define x #f)

    (push-undo! (lambda _ (set! x 1)))
    (push-undo! (lambda _ (set! x 2)))
    (push-undo! (lambda _ (set! x 3)))

    (undo!)
    (check-eqv? x 3)

    (undo!)
    (check-eqv? x 2)

    (undo!)
    (check-eqv? x 1)

    (undo!)
    (check-eqv? x 1)))
