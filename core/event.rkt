#lang racket/base

(require noise/backend
         noise/serde)

(provide
 entries-did-change)

(define-callout (entries-did-change-cb [ok : Bool]))

(define ready-for-changes? #f)

(define-rpc (mark-ready-for-changes)
  (set! ready-for-changes? #t))

(define (entries-did-change)
  (when ready-for-changes?
    (entries-did-change-cb #t)))
