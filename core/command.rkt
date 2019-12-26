#lang racket/base

(require racket/generic
         racket/match
         racket/port)

(provide
 parse-command)

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
     (read-chunk in)]))

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
     (read-chunk in)]))

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

(define (parse-command s)
  (call-with-input-string s read-command))
