#lang racket/base

(require ffi/unsafe/nsstring
         ffi/unsafe/objc)

(provide
 get-current-system-timezone)

(import-class NSTimeZone)

;; On iOS, gregor has trouble determining the system timezone, so let's
;; always just ask the system directly instead.
(define (get-current-system-timezone)
  (tell #:type _NSString
        (tell NSTimeZone systemTimeZone)
        name))
