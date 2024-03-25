#lang racket/base

(require gregor
         racket/match
         rackunit
         remember/command)

(check-equal?
 (parse-command "hello")
 (list
  (make-Token
   #:text "hello"
   #:span (Span
           (Location 1 0 0)
           (Location 1 5 5)))))

(check-equal?
 (parse-command "hello +1d there")
 (list
  (make-Token
   #:text "hello "
   #:span (Span
           (Location 1 0 0)
           (Location 1 6 6)))
  (make-Token
   #:text "+1d"
   #:span (Span
           (Location 1 6 6)
           (Location 1 9 9))
   #:data (TokenData.relative-time 1 'd))
  (make-Token
   #:text " there"
   #:span (Span
           (Location 1 9 9)
           (Location 1 15 15)))))

(check-equal?
 (parse-command "hello + there")
 (list
  (make-Token
   #:text "hello "
   #:span (Span
           (Location 1 0 0)
           (Location 1 6 6)))
  (make-Token
   #:text "+"
   #:span (Span
           (Location 1 6 6)
           (Location 1 7 7)))
  (make-Token
   #:text " there"
   #:span (Span
           (Location 1 7 7)
           (Location 1 13 13)))))

(check-equal?
 (parse-command "buy milk +1d #groceries")
 (list
  (make-Token
   #:text "buy milk "
   #:span (Span
           (Location 1 0 0)
           (Location 1 9 9)))
  (make-Token
   #:text "+1d"
   #:span (Span
           (Location 1 9 9)
           (Location 1 12 12))
   #:data (TokenData.relative-time 1 'd))
  (make-Token
   #:text " "
   #:span (Span
           (Location 1 12 12)
           (Location 1 13 13)))
  (make-Token
   #:text "#groceries"
   #:span (Span
           (Location 1 13 13)
           (Location 1 23 23))
   #:data (TokenData.tag "groceries"))))

(parameterize ([current-clock (lambda () 0)])
  (check-equal?
   (parse-command "buy milk @mon #groceries")
   (list
    (make-Token
     #:text "buy milk "
     #:span (Span
             (Location 1 0 0)
             (Location 1 9 9)))
    (make-Token
     #:text "@mon"
     #:span (Span
             (Location 1 9 9)
             (Location 1 13 13))
     #:data (TokenData.named-date
             (date 1970 1 5)))
    (make-Token
     #:text " "
     #:span (Span
             (Location 1 13 13)
             (Location 1 14 14)))
    (make-Token
     #:text "#groceries"
     #:span (Span
             (Location 1 14 14)
             (Location 1 24 24))
     #:data (TokenData.tag "groceries"))))

  (check-equal?
   (parse-command "buy milk @thu #groceries")
   (list
    (make-Token
     #:text "buy milk "
     #:span (Span
             (Location 1 0 0)
             (Location 1 9 9)))
    (make-Token
     #:text "@thu"
     #:span (Span
             (Location 1 9 9)
             (Location 1 13 13))
     #:data (TokenData.named-date
             (date 1970 1 8)))
    (make-Token
     #:text " "
     #:span (Span
             (Location 1 13 13)
             (Location 1 14 14)))
    (make-Token
     #:text "#groceries"
     #:span (Span
             (Location 1 14 14)
             (Location 1 24 24))
     #:data (TokenData.tag "groceries"))))

  (check-equal?
   (parse-command "buy milk @3pm #groceries")
   (list
    (make-Token
     #:text "buy milk "
     #:span (Span
             (Location 1 0 0)
             (Location 1 9 9)))
    (make-Token
     #:text "@3pm "
     #:span (Span
             (Location 1 9 9)
             (Location 1 14 14))
     #:data (TokenData.named-datetime
             (datetime 1970 1 1 15)))
    (make-Token
     #:text "#groceries"
     #:span (Span
             (Location 1 14 14)
             (Location 1 24 24))
     #:data (TokenData.tag "groceries"))))

  (check-equal?
   (parse-command "buy milk @3:15pm tmw #groceries")
   (list
    (make-Token
     #:text "buy milk "
     #:span (Span
             (Location 1 0 0)
             (Location 1 9 9)))
    (make-Token
     #:text "@3:15pm tmw"
     #:span (Span
             (Location 1 9 9)
             (Location 1 20 20))
     #:data (TokenData.named-datetime
             (datetime 1970 1 2 15 15)))
    (make-Token
     #:text " "
     #:span (Span
             (Location 1 20 20)
             (Location 1 21 21)))
    (make-Token
     #:text "#groceries"
     #:span (Span
             (Location 1 21 21)
             (Location 1 31 31))
     #:data (TokenData.tag "groceries"))))

  (check-equal?
   (parse-command "invoice Jim @10am mon *weekly*")
   (list
    (make-Token
     #:text "invoice Jim "
     #:span (Span
             (Location 1 0 0)
             (Location 1 12 12)))
    (make-Token
     #:text "@10am mon"
     #:span (Span
             (Location 1 12 12)
             (Location 1 21 21))
     #:data (TokenData.named-datetime
             (datetime 1970 1 5 10)))
    (make-Token
     #:text " "
     #:span (Span
             (Location 1 21 21)
             (Location 1 22 22)))
    (make-Token
     #:text "*weekly*"
     #:span (Span
             (Location 1 22 22)
             (Location 1 30 30))
     #:data (TokenData.recurrence 1 'week))))

  (check-equal?
   (parse-command "invoice Jim @10am mon *every 2 weeks*")
   (list
    (make-Token
     #:text "invoice Jim "
     #:span (Span
             (Location 1 0 0)
             (Location 1 12 12)))
    (make-Token
     #:text "@10am mon"
     #:span (Span
             (Location 1 12 12)
             (Location 1 21 21))
     #:data (TokenData.named-datetime
             (datetime 1970 1 5 10)))
    (make-Token
     #:text " "
     #:span (Span
             (Location 1 21 21)
             (Location 1 22 22)))
    (make-Token
     #:text "*every 2 weeks*"
     #:span (Span
             (Location 1 22 22)
             (Location 1 37 37))
     #:data (TokenData.recurrence 2 'week))))

  (define-check (check-named-datetime command expected)
    (match-define (TokenData.named-datetime datetime)
      (Token-data (car (parse-command command))))
    (check-equal? datetime expected))

  (check-named-datetime "@9am" (datetime 1970 1 1 9 0 0 0))
  (check-named-datetime "@09am" (datetime 1970 1 1 9 0 0 0))
  (check-named-datetime "@10pm" (datetime 1970 1 1 22 0 0 0))
  (check-named-datetime "@10:35pm" (datetime 1970 1 1 22 35 0 0))
  (check-named-datetime "@10:35pm tmw" (datetime 1970 1 2 22 35 0 0))
  (check-named-datetime "@09" (datetime 1970 1 1 9 0 0 0))
  (check-named-datetime "@09:59 mon" (datetime 1970 1 5 9 59 0 0))
  (check-named-datetime "@22" (datetime 1970 1 1 22 0 0 0))
  (check-named-datetime "@22:35" (datetime 1970 1 1 22 35 0 0))
  (check-named-datetime "@22:35 tmw" (datetime 1970 1 2 22 35 0 0))
  (check-named-datetime "@25:59 mon" (datetime 1970 1 1 2 0 0 0)))
