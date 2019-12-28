# remember

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
