#lang racket/base

(require racket/contract)

(provide
 make-ring
 ring?
 ring-push!
 ring-pop!
 ring-size)

(struct ring (sema vs cap [pos #:mutable] [size #:mutable])
  #:transparent)

(define/contract (make-ring cap)
  (-> exact-positive-integer? ring?)
  (ring (make-semaphore 1)
        (make-vector cap #f)
        cap
        0
        0))

(define/contract (ring-push! r v)
  (-> ring? any/c void?)
  (call-with-semaphore (ring-sema r)
    (lambda _
      (define vs (ring-vs r))
      (define cap (ring-cap r))
      (define pos (ring-pos r))
      (vector-set! vs pos v)
      (set-ring-pos! r (modulo (add1 pos) cap))
      (set-ring-size! r (min cap (add1 (ring-size r)))))))

(define/contract (ring-pop! r)
  (-> ring? (or/c false/c any/c))
  (call-with-semaphore (ring-sema r)
    (lambda  _
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

(module+ test
  (require rackunit)

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
  (check-false (ring-pop! r)))
