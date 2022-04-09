#lang scribble/manual

@(require "shortcut.rkt")

@title{Remember: Stash distractions away}
@author[(author+email "Bogdan Popa" "bogdan@defn.io")]

@(define (homepage-anchor text)
  (link "https://remember.defn.io" text))

@homepage-anchor{Remember} is meant to be operated entirely via the
keyboard.  While very convenient once you're used to it, this makes it
challenging to get started.  This document describes the features
available in Remember and their operation.

@(define-syntax-rule (kbd sym ...)
  (let ([text (shortcut 'sym ...)])
    (elemref `("kbd" ,text) text)))

@(define-syntax-rule (defkbd (sym ...) pre-content ...)
  (let ([text (shortcut 'sym ...)])
    (elem
      (elemtag `("kbd" ,text))
      text
      " --- "
      pre-content ...)))

@section{Reading This Document}

Because Remember is keyboard-driven, this document contains many
keyboard shortcuts.  Shortcuts are written using the textual
representation of each key.  When you see a shortcut like @kbd[opt
space], you should interpret it as holding down the Option key and
pressing the Space key.

@tabular[
  #:style 'boxed
  #:row-properties '(bottom-border ())
  (list
   (list @bold{Name} @bold{Symbol})
   (list @elem{Control} @"⌃")
   (list @elem{Option} @"⌥")
   (list @elem{Command} @"⌘")
   (list @elem{Space} @"⎵")
   (list @elem{Delete} @"⌫")
   (list @elem{Return} @"↩")
   (list @elem{Escape} @"⎋"))
]

@subsection{Definitions}

The @deftech{input area} is the text input in which you type
reminders.

The @deftech{current desktop} is the desktop or screen on which the
mouse cursor is currently sitting.


@section{Basics}

@defkbd[(opt space)]{
  Pressing this shortcut shows or hides Remember.  If Remember is
  running, it will appear on the @tech{current desktop} whenever you
  press this shortcut.

  You can customize this shortcut using the Preferences pane (@kbd[cmd
  comma]).
}

@defkbd[(cmd Q)]{
  Pressing this shortcut quits the application.
}

@defkbd[(cmd comma)]{
  Pressing this shortcut opens the Preferences dialog.
}


@section{Navigation & Editing}

@defkbd[(return)]{
  If the @tech{input area} contains text, pressing return creates a
  new reminder.  If an existing reminder is selected, pressing return
  opens the reminder for editing, and pressing return again commits
  the change.
}

@defkbd[(escape)]{
  If the @tech{input area} contains text, pressing escape clears it.
  If the input area is already empty, then pressing escape dismisses
  Remember.
}

@defkbd[(ctl P)]{
  Selects the previous reminder.
}

@defkbd[(ctl N)]{
  Selects the next reminder.
}

@defkbd[(delete)]{
  If an existing reminder is selected, pressing delete archives it.
  @tech{Recurring reminders} are reset instead.
}

@defkbd[(opt delete)]{
  If an existing reminder is selected, pressing @kbd[opt delete]
  deletes it.
}

@defkbd[(cmd Z)]{
  Undoes the previous action.
}


@section{Date/time Modifiers}

Remember recognizes a small set of special modifiers in your reminders
that control if and when it notifies you about them.  For example, a
reminder like @centered{@verbatim{buy milk +30m *every 2 weeks*}}
would fire 30 minutes from when it is created and then once every 2
weeks at the same time of day.

@subsection{Relative Modifiers}

A @litchar{+} character followed by a positive number and an interval
suffix instructs Remember to notify you after a specific amount of
time.  The supported intervals are:

@itemlist[
  @item{@tt{m} --- for minutes, eg. @tt{+10m} meaning 10 minutes from now}
  @item{@tt{h} --- for hours, eg. @tt{+2h} meaning 2 hours from now}
  @item{@tt{d} --- for days, eg. @tt{+1d} meaning 1 day from now}
  @item{@tt{w} --- for weeks, eg. @tt{+1w} meaning 1 week from now}
  @item{@tt{M} --- for months, eg. @tt{+6M} meaning 6 months from now}
]

@subsection{Exact Modifiers}

A @litchar[@"@"] character followed by a time and an optional day of
the week instructs Remember to notify you at an exact time of day.
Some examples:

@itemlist[
  @item{@tt[@"@10am"] --- sets a reminder for 10am}
  @item{@tt[@"@10:30pm"] --- sets a reminder for 10:30pm}
  @item{@tt[@"@22:30"] --- the same as above, but using military time}
  @item{@tt[@"@10am tomorrow"] --- sets a reminder for 10 the following day}
  @item{@tt[@"@10am tmw"] --- a shorthand for the above}
  @item{@tt[@"@8pm mon"] --- sets a reminder for 8pm the following Monday}
]

If you don't specify a day of the week and that time has already
passed in the current day, then Remember implicitly considers the
reminder to be for the following day.  For example, say it is
currently 11am, the reminder @centered{@verbatim[@"buy milk @10am"]}
will fire at 10am the next day.

@subsection{Recurring Reminders}

The following modifiers create @tech{recurring reminders}:

@itemlist[
  @item{@tt{*hourly*}}
  @item{@tt{*daily*}}
  @item{@tt{*weekly*}}
  @item{@tt{*monthly*}}
  @item{@tt{*yearly*}}
  @item{@tt{*every N hours*}}
  @item{@tt{*every N days*}}
  @item{@tt{*every N weeks*}}
  @item{@tt{*every N months*}}
  @item{@tt{*every N years*}}
]

Where @tt{N} is any positive number.

@deftech{Recurring reminders} repeat at the same time of day after
some interval.  Archiving a recurring reminder (@kbd[delete]) resets
it for the next interval.


@subsection{Postponing Reminders}

When editing a reminder (@kbd[return]), you can postpone it by
applying another modifier to it.  For example, if you create a
reminder like @centered{@verbatim{buy milk +20m}} and then edit it
five minutes later to add another modifier like
@centered{@verbatim{buy milk +60m}} then the two modifiers stack up
and you will be reminded about it after 75 minutes.

If you make a mistake, you can undo the change with @kbd[cmd Z].
