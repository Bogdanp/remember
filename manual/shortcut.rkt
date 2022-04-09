#lang racket/base

(require racket/string)

(provide
 shortcut)

(define (sym->str s)
  (case s
    [(ctl) "⌃"]
    [(opt) "⌥"]
    [(cmd) "⌘"]
    [(space) "⎵"]
    [(shift) "⇧"]
    [(return) "↩"]
    [(delete) "⌫"]
    [(escape) "⎋"]
    [(comma) ","]
    [(up) "↑"]
    [(down) "↓"]
    [else (symbol->string s)]))

(define (shortcut . syms)
  (define strs (map sym->str syms))
  (string-join strs " "))
