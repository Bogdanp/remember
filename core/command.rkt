#lang racket/base

(require gregor
         gregor/time
         json
         racket/contract
         racket/format
         racket/generic
         racket/match
         racket/port
         racket/string
         threading
         "json.rkt")

(provide
 (struct-out location)
 (struct-out span)
 (struct-out token)
 (struct-out chunk)
 (struct-out relative-time)
 relative-time-adder
 (struct-out named-date)
 (struct-out named-datetime)
 (struct-out recurrence)
 recurrence-next
 (struct-out tag)
 parse-command
 parse-command/jsexpr)

(struct location (line column offset)
  #:transparent
  #:methods gen:to-jsexpr
  [(define (->jsexpr loc)
     (list (location-line loc)
           (location-column loc)
           (location-offset loc)))])

(struct span (lo hi)
  #:transparent
  #:methods gen:to-jsexpr
  [(define/generic ->jsexpr/super ->jsexpr)
   (define (->jsexpr s)
     (list (->jsexpr/super (span-lo s))
           (->jsexpr/super (span-hi s))))])

(struct token (text span)
  #:transparent
  #:methods gen:to-jsexpr
  [(define (->jsexpr _)
     (error '->jsexpr "not implemented for token"))])

(define (token->jsexpr t type)
  (hasheq 'type type
          'text (token-text t)
          'span (->jsexpr (token-span t))))

(struct chunk token ()
  #:transparent
  #:methods gen:to-jsexpr
  [(define (->jsexpr c)
     (token->jsexpr c "chunk"))])

(struct relative-time token (delta modifier)
  #:transparent
  #:methods gen:to-jsexpr
  [(define (->jsexpr rd)
     (~> (token->jsexpr rd "relative-time")
         (hash-set 'delta (relative-time-delta rd))
         (hash-set 'modifier (symbol->string (relative-time-modifier rd)))))])

(define ((relative-time-adder r) dp)
  (define adder
    (case (relative-time-modifier r)
      [(m) +minutes]
      [(h) +hours]
      [(d) +days]
      [(w) +weeks]
      [(M) +months]))
  (adder dp (relative-time-delta r)))

(struct named-date token (d)
  #:transparent
  #:methods gen:to-jsexpr
  [(define (->jsexpr t)
     (~> (token->jsexpr t "named-date")
         (hash-set 'date (date->iso8601 (named-date-d t)))))])

(struct named-datetime token (dt)
  #:transparent
  #:methods gen:to-jsexpr
  [(define (->jsexpr t)
     (~> (token->jsexpr t "named-datetime")
         (hash-set 'datetime (datetime->iso8601 (named-datetime-dt t)))))])

(struct recurrence token (delta modifier)
  #:transparent
  #:methods gen:to-jsexpr
  [(define (->jsexpr t)
     (~> (token->jsexpr t "recurrence")
         (hash-set 'delta (recurrence-delta t))
         (hash-set 'modifier (symbol->string (recurrence-modifier t)))))])

(define/contract (recurrence-next r dt)
  (-> recurrence? datetime-provider? datetime-provider?)
  (define adder
    (case (recurrence-modifier r)
      [(hour)  +hours]
      [(day)   +days]
      [(week)  +weeks]
      [(month) +months]
      [(year)  +years]))

  (let loop ([dt dt])
    (define next-dt
      (adder dt (recurrence-delta r)))

    (cond
      [(datetime>=? next-dt (now)) next-dt]
      [else (loop next-dt)])))

(struct tag token (name)
  #:transparent
  #:methods gen:to-jsexpr
  [(define (->jsexpr t)
     (~> (token->jsexpr t "tag")
         (hash-set 'name (tag-name t))))])

(define PREFIX-CHARS '(#\+ #\* #\@ #\#))
(define RELATIVE-TIME-RE #px"^\\+(0|[1-9][0-9]*)([mhdwM])")
(define NAMED-DATE-RE #px"^@(tmw|tomorrow|mon|tue|wed|thu|fri|sat|sun)")
(define NAMED-DATETIME-RE #px"^@(([1-9]|10|11|12)(:(0[0-9]|[1-9][0-9]))?(am|pm)) ?(tmw|tomorrow|mon|tue|wed|thu|fri|sat|sun)?")
(define RECURRENCE-RE #px"^\\*(hourly|daily|weekly|monthly|yearly|every ([1-9][0-9]*) (hours|days|weeks|months|years))\\*")
(define TAG-RE #px"^#([^ ]+)")

(define bytes->number (compose1 string->number bytes->string/utf-8))
(define bytes->symbol (compose1 string->symbol bytes->string/utf-8))

(define (port-location in)
  (call-with-values
   (lambda _
     (port-next-location in))
   (lambda (line col next-offset)
     (location line col (sub1 next-offset)))))

(define (read-tag [in (current-input-port)])
  (define start-loc (port-location in))
  (match (regexp-try-match TAG-RE in)
    [(list text name)
     (tag (bytes->string/utf-8 text)
          (span start-loc (port-location in))
          (bytes->string/utf-8 name))]

    [_
     (chunk (read-string 1 in)
            (span start-loc (port-location in)))]))

(define (read-relative-time [in (current-input-port)])
  (define start-loc (port-location in))
  (match (regexp-try-match RELATIVE-TIME-RE in)
    [(list text delta modifier)
     (relative-time (bytes->string/utf-8 text)
                    (span start-loc (port-location in))
                    (bytes->number delta)
                    (or (and modifier (bytes->symbol modifier)) 'd))]

    [_
     (chunk (read-string 1 in)
            (span start-loc (port-location in)))]))

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
     (named-date (bytes->string/utf-8 text)
                 (span start-loc (port-location in))
                 (+days (today) 1))]

    [(list text weekday)
     (named-date (bytes->string/utf-8 text)
                 (span start-loc (port-location in))
                 (weekday->date weekday))]

    [_ #f]))

(define (read-named-datetime [in (current-input-port)])
  (define (make-time hour:bs minute:bs period)
    (time (modulo (+ (bytes->number hour:bs)
                     (case period
                       [(#"am") 0]
                       [(#"pm") 12]))
                  24)
          (or (and minute:bs (bytes->number minute:bs))
              0)))

  (define start-loc (port-location in))
  (match (regexp-try-match NAMED-DATETIME-RE in)
    [(list text _ hour sep minute period #f)
     (named-datetime (bytes->string/utf-8 text)
                     (span start-loc (port-location in))
                     (let ([t (make-time hour minute period)])
                       (if (time<? t (->time (now)))
                           (at-time (+days (today) 1) t)
                           (at-time (today) t))))]

    [(list text _ hour sep minute period (or #"tmw" #"tomorrow"))
     (named-datetime (bytes->string/utf-8 text)
                     (span start-loc (port-location in))
                     (at-time (+days (today) 1)
                              (make-time hour minute period)))]

    [(list text _ hour sep minute period weekday)
     (named-datetime (bytes->string/utf-8 text)
                     (span start-loc (port-location in))
                     (at-time (weekday->date weekday)
                              (make-time hour minute period)))]

    [_ #f]))

(define (read-named-date/time [in (current-input-port)])
  (define start-loc (port-location in))
  (or (read-named-datetime in)
      (read-named-date in)
      (chunk (read-string 1 in)
             (span start-loc (port-location in)))))

(define (read-recurrence [in (current-input-port)])
  (define start-loc (port-location in))
  (match (regexp-try-match RECURRENCE-RE in)
    [(list text modifier #f #f)
     (recurrence (bytes->string/utf-8 text)
                 (span start-loc (port-location in))
                 1
                 (case modifier
                   [(#"hourly")  'hour]
                   [(#"daily")   'day]
                   [(#"weekly")  'week]
                   [(#"monthly") 'month]
                   [(#"yearly")  'year]))]

    [(list text _ delta modifier)
     (recurrence (bytes->string/utf-8 text)
                 (span start-loc (port-location in))
                 (bytes->number delta)
                 (case modifier
                   [(#"hours")  'hour]
                   [(#"days")   'day]
                   [(#"weeks")  'week]
                   [(#"months") 'month]
                   [(#"years")  'year]))]

    [_
     (chunk (read-string 1 in)
            (span start-loc (port-location in)))]))

(define (read-chunk [in (current-input-port)])
  (define out (open-output-string))
  (define start-loc (port-location in))
  (let loop ([c (peek-char in)])
    (cond
      [(or (eof-object? c)
           (member c PREFIX-CHARS))
       (chunk  (get-output-string out)
               (span start-loc (port-location in)))]

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

(define/contract (parse-command s)
  (-> non-empty-string? (listof token?))
  (call-with-input-string s read-command))

(define/contract (parse-command/jsexpr s)
  (-> non-empty-string? (non-empty-listof jsexpr?))
  (->jsexpr (parse-command s)))

(module+ test
  (require rackunit)

  (check-equal?
   (parse-command/jsexpr "hello")
   '(#hasheq((type . "chunk")
             (text . "hello")
             (span . ((1 0 0)
                      (1 5 5))))))

  (check-equal?
   (parse-command/jsexpr "hello +1d there")
   '(#hasheq((type . "chunk")
             (text . "hello ")
             (span . ((1 0 0)
                      (1 6 6))))
     #hasheq((type . "relative-time")
             (text . "+1d")
             (span . ((1 6 6)
                      (1 9 9)))
             (delta . 1)
             (modifier . "d"))
     #hasheq((type . "chunk")
             (text . " there")
             (span . ((1 9 9)
                      (1 15 15))))))

  (check-equal?
   (parse-command/jsexpr "hello + there")
   '(#hasheq((type . "chunk")
             (text . "hello ")
             (span . ((1 0 0)
                      (1 6 6))))
     #hasheq((type . "chunk")
             (text . "+")
             (span . ((1 6 6)
                      (1 7 7))))
     #hasheq((type . "chunk")
             (text . " there")
             (span . ((1 7 7)
                      (1 13 13))))))

  (check-equal?
   (parse-command/jsexpr "buy milk +1d #groceries")
   '(#hasheq((type . "chunk")
             (text . "buy milk ")
             (span . ((1 0 0)
                      (1 9 9))))
     #hasheq((type . "relative-time")
             (text . "+1d")
             (span . ((1 9 9)
                      (1 12 12)))
             (delta . 1)
             (modifier . "d"))
     #hasheq((type . "chunk")
             (text . " ")
             (span . ((1 12 12)
                      (1 13 13))) )
     #hasheq((type . "tag")
             (text . "#groceries")
             (span . ((1 13 13)
                      (1 23 23)))
             (name . "groceries"))))

  (parameterize ([current-clock (lambda _ 0)])
    (check-equal?
     (parse-command/jsexpr "buy milk @mon #groceries")
     '(#hasheq((type . "chunk")
               (text . "buy milk ")
               (span . ((1 0 0)
                        (1 9 9))) )
       #hasheq((type . "named-date")
               (text . "@mon")
               (span . ((1 9 9)
                        (1 13 13)))
               (date . "1970-01-05"))
       #hasheq((type . "chunk")
               (text . " ")
               (span . ((1 13 13)
                        (1 14 14))))
       #hasheq((type . "tag")
               (text . "#groceries")
               (span . ((1 14 14)
                        (1 24 24)))
               (name . "groceries"))))

    (check-equal?
     (parse-command/jsexpr "buy milk @thu #groceries")
     '(#hasheq((type . "chunk")
               (text . "buy milk ")
               (span . ((1 0 0)
                        (1 9 9))) )
       #hasheq((type . "named-date")
               (text . "@thu")
               (span . ((1 9 9)
                        (1 13 13)))
               (date . "1970-01-08"))
       #hasheq((type . "chunk")
               (text . " ")
               (span . ((1 13 13)
                        (1 14 14))))
       #hasheq((type . "tag")
               (text . "#groceries")
               (span . ((1 14 14)
                        (1 24 24)))
               (name . "groceries"))))

    (check-equal?
     (parse-command/jsexpr "buy milk @3pm #groceries")
     '(#hasheq((type . "chunk")
               (text . "buy milk ")
               (span . ((1 0 0)
                        (1 9 9))) )
       #hasheq((type . "named-datetime")
               (text . "@3pm ")
               (span . ((1 9 9)
                        (1 14 14)))
               (datetime . "1970-01-01T15:00:00"))
       #hasheq((type . "tag")
               (text . "#groceries")
               (span . ((1 14 14)
                        (1 24 24)))
               (name . "groceries"))))

    (check-equal?
     (parse-command/jsexpr "buy milk @3:15pm tmw #groceries")
     '(#hasheq((type . "chunk")
               (text . "buy milk ")
               (span . ((1 0 0)
                        (1 9 9))) )
       #hasheq((type . "named-datetime")
               (text . "@3:15pm tmw")
               (span . ((1 9 9)
                        (1 20 20)))
               (datetime . "1970-01-02T15:15:00"))
       #hasheq((type . "chunk")
               (text . " ")
               (span . ((1 20 20)
                        (1 21 21))))
       #hasheq((type . "tag")
               (text . "#groceries")
               (span . ((1 21 21)
                        (1 31 31)))
               (name . "groceries"))))

    (check-equal?
     (parse-command/jsexpr "invoice Jim @10am mon *weekly*")
     '(#hasheq((type . "chunk")
               (text . "invoice Jim ")
               (span . ((1 0 0)
                        (1 12 12))))
       #hasheq((type . "named-datetime")
               (text . "@10am mon")
               (span . ((1 12 12)
                        (1 21 21)))
               (datetime . "1970-01-05T10:00:00"))
       #hasheq((type . "chunk")
               (text . " ")
               (span . ((1 21 21)
                        (1 22 22))))
       #hasheq((type . "recurrence")
               (text . "*weekly*")
               (span . ((1 22 22)
                        (1 30 30)))
               (delta . 1)
               (modifier . "week"))))

    (check-equal?
     (parse-command/jsexpr "invoice Jim @10am mon *every 2 weeks*")
     '(#hasheq((type . "chunk")
               (text . "invoice Jim ")
               (span . ((1 0 0)
                        (1 12 12))))
       #hasheq((type . "named-datetime")
               (text . "@10am mon")
               (span . ((1 12 12)
                        (1 21 21)))
               (datetime . "1970-01-05T10:00:00"))
       #hasheq((type . "chunk")
               (text . " ")
               (span . ((1 21 21)
                        (1 22 22))))
       #hasheq((type . "recurrence")
               (text . "*every 2 weeks*")
               (span . ((1 22 22)
                        (1 37 37)))
               (delta . 2)
               (modifier . "week"))))))
