#lang racket/base

(require gregor
         gregor/time
         noise/serde
         racket/contract/base
         racket/match
         racket/port
         racket/string)

(provide
 (record-out Location)
 (record-out Span)
 (record-out Token)
 (enum-out TokenData)
 (contract-out
  [parse-command (-> non-empty-string? (listof Token?))]))

(define-record Location
  [line : UVarint]
  [column : UVarint]
  [offset : UVarint])

(define-record Span
  [lo : Location]
  [hi : Location])

(define-enum TokenData
  [relative-time
   {delta : UVarint}
   {modifier : Symbol}]
  [named-date
   {date : (StringConvertible iso8601->date date->iso8601)}]
  [named-datetime
   {datetime : (StringConvertible iso8601->datetime datetime->iso8601)}]
  [recurrence
   {delta : UVarint}
   {modifier : Symbol}]
  [tag
   {name : String}])

(define-record Token
  [text : String]
  [span : Span]
  [(data #f) : (Optional TokenData)])

(define PREFIX-CHARS '(#\+ #\* #\@ #\#))
(define RELATIVE-TIME-RE #px"^\\+(0|[1-9][0-9]*)([mhdwM])")
(define NAMED-DATE-RE #px"^@(tmw|tomorrow|mon|tue|wed|thu|fri|sat|sun)")
(define NAMED-DATETIME-RE #px"^@((0?[1-9]|10|11|12)(:(0[0-9]|[1-5][0-9]))?(am|pm)) ?(tmw|tomorrow|mon|tue|wed|thu|fri|sat|sun)?")
(define NAMED-DATETIME/MT-RE #px"^@((2[0-3]|1[0-9]|0?[0-9])(:(0[0-9]|[1-5][0-9]))?) ?(tmw|tomorrow|mon|tue|wed|thu|fri|sat|sun)?")
(define RECURRENCE-RE #px"^\\*(hourly|daily|weekly|monthly|yearly|every ([1-9][0-9]*) (hours|days|weeks|months|years))\\*")
(define TAG-RE #px"^#([^ ]+)")

(define bytes->number (compose1 string->number bytes->string/utf-8))
(define bytes->symbol (compose1 string->symbol bytes->string/utf-8))

(define (port-location in)
  (call-with-values
   (lambda ()
     (port-next-location in))
   (lambda (line col next-offset)
     (make-Location
      #:line line
      #:column col
      #:offset (sub1 next-offset)))))

(define (read-tag [in (current-input-port)])
  (define start-loc (port-location in))
  (match (regexp-try-match TAG-RE in)
    [(list text name)
     (make-Token
      #:text (bytes->string/utf-8 text)
      #:span (Span start-loc (port-location in))
      #:data (TokenData.tag (bytes->string/utf-8 name)))]

    [_
     (make-Token
      #:text (read-string 1 in)
      #:span (Span start-loc (port-location in)))]))

(define (read-relative-time [in (current-input-port)])
  (define start-loc (port-location in))
  (match (regexp-try-match RELATIVE-TIME-RE in)
    [(list text delta modifier)
     (make-Token
      #:text (bytes->string/utf-8 text)
      #:span (Span start-loc (port-location in))
      #:data (TokenData.relative-time
              (bytes->number delta)
              (or (and modifier (bytes->symbol modifier)) 'd)))]

    [_
     (make-Token
      #:text (read-string 1 in)
      #:span (Span start-loc (port-location in)))]))

(define (weekday->date weekday)
  (define d (today))
  (define delta
    (- (case weekday
         [(#"sun") 0]
         [(#"mon") 1]
         [(#"tue") 2]
         [(#"wed") 3]
         [(#"thu") 4]
         [(#"fri") 5]
         [(#"sat") 6]
         [else (raise-argument-error 'weekday "a valid weekday" weekday)])
       (->wday d)))

  (if (< delta 1)
      (+days d (+ 7 delta))
      (+days d delta)))

(define (read-named-date [in (current-input-port)])
  (define start-loc (port-location in))
  (match (regexp-try-match NAMED-DATE-RE in)
    [(list text (or #"tmw" #"tomorrow"))
     (make-Token
      #:text (bytes->string/utf-8 text)
      #:span (Span start-loc (port-location in))
      #:data (TokenData.named-date (+days (today) 1)))]

    [(list text weekday)
     (make-Token
      #:text (bytes->string/utf-8 text)
      #:span (Span start-loc (port-location in))
      #:data (TokenData.named-date (weekday->date weekday)))]

    [_ #f]))

(define (read-named-datetime [in (current-input-port)])
  (define (make-time hour:bs minute:bs period) ;; noqa
    (time (modulo (+ (bytes->number hour:bs)
                     (case period
                       [(#"am" #f) 0]
                       [(#"pm")    12]))
                  24)
          (or (and minute:bs (bytes->number minute:bs))
              0)))

  (define/match (prepare _text _hour _minute _period _weekday)
    [(text hour minute period #f)
     (make-Token
      #:text (bytes->string/utf-8 text)
      #:span (Span start-loc (port-location in))
      #:data (TokenData.named-datetime
              (let ([t (make-time hour minute period)])
                (if (time<? t (->time (now)))
                    (at-time (+days (today) 1) t)
                    (at-time (today) t)))))]

    [(text hour minute period (or #"tmw" #"tomorrow"))
     (make-Token
      #:text (bytes->string/utf-8 text)
      #:span (Span start-loc (port-location in))
      #:data (TokenData.named-datetime
              (at-time (+days (today) 1)
                       (make-time hour minute period))))]

    [(text hour minute period weekday)
     (make-Token
      #:text (bytes->string/utf-8 text)
      #:span (Span start-loc (port-location in))
      #:data (TokenData.named-datetime
              (at-time (weekday->date weekday)
                       (make-time hour minute period))))])

  (define start-loc (port-location in)) ;; noqa
  (match (or (regexp-try-match NAMED-DATETIME-RE in)
             (regexp-try-match NAMED-DATETIME/MT-RE in))
    [(list text _ hour _ minute period weekday)
     (prepare text hour minute period weekday)]

    [(list text _ hour _ minute weekday)
     (prepare text hour minute #f weekday)]

    [_ #f]))

(define (read-named-date/time [in (current-input-port)])
  (define start-loc (port-location in))
  (or (read-named-datetime in)
      (read-named-date in)
      (make-Token
       #:text (read-string 1 in)
       #:span (Span start-loc (port-location in)))))

(define (read-recurrence [in (current-input-port)])
  (define start-loc (port-location in))
  (match (regexp-try-match RECURRENCE-RE in)
    [(list text modifier #f #f)
     (make-Token
      #:text (bytes->string/utf-8 text)
      #:span (Span start-loc (port-location in))
      #:data (TokenData.recurrence 1 (->recurrence-modifier modifier)))]

    [(list text _ delta modifier)
     (make-Token
      #:text (bytes->string/utf-8 text)
      #:span (Span start-loc (port-location in))
      #:data (TokenData.recurrence
              (bytes->number delta)
              (->recurrence-modifier modifier)))]

    [_
     (make-Token
      #:text (read-string 1 in)
      #:span (Span start-loc (port-location in)))]))

(define (->recurrence-modifier bs)
  (case bs
    [(#"hours"  #"hourly")  'hour]
    [(#"days"   #"daily" )  'day]
    [(#"weeks"  #"weekly")  'week]
    [(#"months" #"monthly") 'month]
    [(#"years"  #"yearly")  'year]
    [else (raise-argument-error '->recurrence-modifier "recurrence-modifier-bytes/c" bs)]))

(define (read-chunk [in (current-input-port)])
  (define out (open-output-string))
  (define start-loc (port-location in))
  (let loop ([c (peek-char in)])
    (cond
      [(or (eof-object? c)
           (member c PREFIX-CHARS))
       (make-Token
        #:text (get-output-string out)
        #:span (Span start-loc (port-location in)))]

      [else
       (write-char (read-char in) out)
       (loop (peek-char in))])))

(define (read-command [in (current-input-port)])
  (parameterize ([current-input-port in])
    (port-count-lines! in)
    (let loop ([tokens null]
               [c (peek-char)])
      (cond
        [(eof-object? c)
         (reverse tokens)]

        [else
         (define token
           (case c
             [(#\+) (read-relative-time)]
             [(#\@) (read-named-date/time)]
             [(#\*) (read-recurrence)]
             [(#\#) (read-tag)]
             [else  (read-chunk)]))
         (loop (cons token tokens)
               (peek-char))]))))

(define (parse-command s)
  (call-with-input-string s read-command))
