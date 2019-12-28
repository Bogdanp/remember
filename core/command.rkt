#lang racket/base

(require json
         racket/contract
         racket/generic
         racket/match
         racket/port
         racket/string)

(provide
 parse-command
 parse-command/jsexpr)

(define PREFIX-CHARS '(#\+ #\#))
(define RELATIVE-DATE-RE #px"^\\+(0|[1-9][0-9]*)([hdmw])?")
(define TAG-RE #px"^#([^ ]+)")

(define bytes->number (compose1 string->number bytes->string/utf-8))

(define (port-location in)
  (call-with-values
   (lambda _
     (port-next-location in))
   (lambda (line col next-pos)
     (list line col (sub1 next-pos)))))

(define (read-tag [in (current-input-port)])
  (define start-loc (port-location in))
  (match (regexp-try-match TAG-RE in)
    [(list text tag)
     (hasheq 'type "tag"
             'text (bytes->string/utf-8 text)
             'span (list start-loc (port-location in))
             'tag (bytes->string/utf-8 tag))]

    [_
     (hasheq 'type "chunk"
             'text (read-string 1 in)
             'span (list start-loc (port-location in)))]))

(define (read-relative-date [in (current-input-port)])
  (define start-loc (port-location in))
  (match (regexp-try-match RELATIVE-DATE-RE in)
    [(list text delta modifier)
     (hasheq 'type "relative-date"
             'text (bytes->string/utf-8 text)
             'span (list start-loc (port-location in))
             'delta (bytes->number delta)
             'modifier (or (and modifier (bytes->string/utf-8 modifier)) "d"))]

    [_
     (hasheq 'type "chunk"
             'text (read-string 1 in)
             'span (list start-loc (port-location in)))]))

(define (read-chunk [in (current-input-port)])
  (define out (open-output-string))
  (define start-loc (port-location in))
  (let loop ([c (peek-char in)])
    (cond
      [(or (eof-object? c)
           (member c PREFIX-CHARS))
       (hasheq 'type "chunk"
               'text (get-output-string out)
               'span (list start-loc (port-location in)))]

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
             [(#\+) (read-relative-date)]
             [(#\#) (read-tag)]
             [else  (read-chunk)]))
         (loop (cons token tokens)
               (peek-char))]))))

(define/contract (parse-command s)
  (-> non-empty-string? (listof (and/c hash-eq? immutable?)))
  (call-with-input-string s read-command))

(define/contract (parse-command/jsexpr s)
  (-> non-empty-string? (non-empty-listof jsexpr?))
  (map token->jsexpr (parse-command s)))

(define token->jsexpr values)

(module+ test
  (require rackunit)

  (check-equal?
   (parse-command/jsexpr "hello")
   (list (hasheq 'type "chunk"
                 'text "hello"
                 'span '((1 0 0)
                         (1 5 5)))))

  (check-equal?
   (parse-command/jsexpr "hello +1d there")
   (list (hasheq 'type "chunk"
                 'text "hello "
                 'span '((1 0 0)
                         (1 6 6)))
         (hasheq 'type "relative-date"
                 'text "+1d"
                 'span '((1 6 6)
                         (1 9 9))
                 'delta 1
                 'modifier "d")
         (hasheq 'type "chunk"
                 'text " there"
                 'span '((1 9 9)
                         (1 15 15)))))

  (check-equal?
   (parse-command/jsexpr "hello + there")
   (list (hasheq 'type "chunk"
                 'text "hello "
                 'span '((1 0 0)
                         (1 6 6)))
         (hasheq 'type "chunk"
                 'text "+"
                 'span '((1 6 6)
                         (1 7 7)))
         (hasheq 'type "chunk"
                 'text " there"
                 'span '((1 7 7)
                         (1 13 13)))))

  (check-equal?
   (parse-command/jsexpr "buy milk +1d #groceries")
   '(#hasheq((type . "chunk")
             (text . "buy milk ")
             (span . ((1 0 0)
                      (1 9 9))))
     #hasheq((type . "relative-date")
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
             (tag . "groceries")))))
