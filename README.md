<p align="center">
  <a href="https://remember.defn.io">
    <img alt="Remember Logo" src=".github/media/logo.png" width="256">
  </a>
  <h1 align="center">
    Remember
    <a href="https://github.com/Bogdanp/remember/actions?query=workflow%3A%22CI%22">
      <img alt="GitHub Actions status" src="https://github.com/Bogdanp/remember/workflows/CI/badge.svg">
    </a>
  </h1>
</p>

Remember is a tool for stashing distractions away for later.  You bind
it to a hotkey (⌥⎵ by default) and whenever something unexpected pops
up -- say you suddenly realize you need to stock up on milk -- you hit
the hotkey, then type in `buy milk +1h` and hit return.  An hour
later, you'll get reminded that you need to go out and buy some milk.

<p align="center">
   <img alt="Demo" src=".github/media/demo.gif">
</p>

If you find Remember useful, please consider [buying a copy].

This application is **not** Open Source.  I'm providing the source
code here because I want users to be able to see the code they're
running and even change and build it for themselves if they want to.
In that vein, you're free to read, build and run the application
yourself, on your own devices, but please don't share any built
artifacts with others.

[buying a copy]: https://gumroad.com/l/rememberapp

## Build

### Requirements

* [Racket 7.5+](https://racket-lang.org/)
* macOS Catalina
* Xcode 11+
* [Carthage](https://github.com/Carthage/Carthage)

### First-time Setup

    $ raco pkg install --name remember core/
    $ $(cd cocoa/remember && carthage update)

### Building

    $ make
    $ $(cd cocoa/remember && xcodebuild)

## License

    Copyright 2019 CLEARTYPE SRL.  All rights reserved.
