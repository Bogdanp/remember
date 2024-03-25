#lang racket/base

(require racket/contract/base
         "ring.rkt")

(provide
 (contract-out
  [current-undo-ring (parameter/c ring?)]
  [push-undo! (-> (-> any) void?)]
  [undo! (-> void?)]))

(define current-undo-ring
  (make-parameter (make-ring 128)))

(define (push-undo! proc)
  (ring-push! (current-undo-ring) proc))

(define (undo!)
  (define proc (ring-pop! (current-undo-ring)))
  (when proc (void (proc))))
