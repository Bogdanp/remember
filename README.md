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
