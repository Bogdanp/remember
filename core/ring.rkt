#lang racket/base

(require racket/contract/base)

(provide
 (contract-out
  [make-ring (-> exact-positive-integer? ring?)]
  [ring? (-> any/c boolean?)]
  [ring-push! (-> ring? any/c void?)]
  [ring-pop! (-> ring? (or/c #f any/c))]
  [ring-size (-> ring? exact-nonnegative-integer?)]))

(struct ring (sema vs cap [pos #:mutable] [size #:mutable])
  #:transparent)

(define (make-ring cap)
  (ring (make-semaphore 1)
        (make-vector cap #f)
        cap
        0
        0))

(define (ring-push! r v)
  (call-with-semaphore (ring-sema r)
    (lambda ()
      (define vs (ring-vs r))
      (define cap (ring-cap r))
      (define pos (ring-pos r))
      (vector-set! vs pos v)
      (set-ring-pos! r (modulo (add1 pos) cap))
      (set-ring-size! r (min cap (add1 (ring-size r)))))))

(define (ring-pop! r)
  (call-with-semaphore (ring-sema r)
    (lambda ()
      (cond
        [(zero? (ring-size r)) #f]
        [else
         (define vs (ring-vs r))
         (define cap (ring-cap r))
         (define pos (if (zero? (ring-pos r))
                         (sub1 cap)
                         (sub1 (ring-pos r))))
         (begin0 (vector-ref vs pos)
           (vector-set! vs pos #f)
           (set-ring-pos! r pos)
           (set-ring-size! r (sub1 (ring-size r))))]))))
