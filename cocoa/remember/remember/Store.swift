//
//  CommandStore.swift
//  remember
//
//  Created by Bogdan Popa on 27/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Combine
import Foundation

class Store: ObservableObject {
    private let asyncNotifier: AsyncNotifier
    private let entryDB: EntryDB
    private let parser: Parser
    private var parseCancellable: AnyCancellable?

    @Published var command = NSAttributedString(string: "")
    @Published var tokens = [Token]()
    @Published var entries = [Entry]()
    @Published var currentEntry: Entry? = nil

    init(asyncNotifier: AsyncNotifier, entryDB: EntryDB, parser: Parser) {
        self.asyncNotifier = asyncNotifier
        self.entryDB = entryDB
        self.parser = parser
        self.parseCancellable = nil
    }

    func setup() {
        parseCancellable = $command
            .map(\.string)
            .filter { !$0.isEmpty }
            .removeDuplicates()
            .flatMap { text in
                return Future { promise in
                    self.parser.parse(command: text) {
                        switch $0 {
                        case .ok(let tokens):
                            promise(.success(tokens))
                        case .error:
                            promise(.success([]))
                        }
                    }
                }
            }
            .receive(on: RunLoop.main)
            .assign(to: \.tokens, on: self)

        self.updatePendingEntries()
        self.asyncNotifier.addListener {
            switch $0 {
            case .entriesDidChange:
                self.updatePendingEntries()
            default:
                break
            }
        }
    }

    func clear() {
        if command.string.isEmpty {
            Notifications.commandDidComplete()
        }

        command = NSAttributedString(string: "")
        tokens = []
    }

    func commit(command: String, withCompletionHandler handler: @escaping () -> Void) {
        self.entryDB.commit(command: command) { res in
            RunLoop.main.schedule {
                switch res {
                case .ok:
                    self.clear()
                    handler()
                case .error:
                    handler()
                }
            }
        }
    }

    func updatePendingEntries() {
        self.entryDB.findPendingEntries { entries in
            RunLoop.main.schedule {
                self.entries = entries

                if self.currentEntry == nil && !entries.isEmpty {
                    self.currentEntry = entries[0]
                }
            }
        }
    }
}
