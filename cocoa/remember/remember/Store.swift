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
    @Published var entriesVisible = false
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

        Notifications.observeWillHideWindow {
            self.hideEntries()
        }

        Notifications.observeWillSnoozeEntry {
            self.entryDB.snoozeEntry(byId: $0) { }
        }

        Notifications.observeWillArchiveEntry {
            self.entryDB.archiveEntry(byId: $0) { }
        }
    }

    func clear() {
        self.hideEntries()
        if command.string.isEmpty {
            Notifications.willHideWindow()
        }

        command = NSAttributedString(string: "")
        tokens = []
    }

    func commit(command: String) {
        commit(command: command) {
            Notifications.willHideWindow()
        }
    }

    func commit(command: String, withCompletionHandler handler: @escaping () -> Void) {
        self.hideEntries()
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
        updatePendingEntries { }
    }

    func updatePendingEntries(withCompletionHandler handler: @escaping () -> Void) {
        self.entryDB.findPendingEntries { entries in
            RunLoop.main.schedule {
                self.entries = entries

                if entries.isEmpty {
                    self.currentEntry = nil
                } else if self.currentEntry == nil {
                    self.currentEntry = entries[0]
                } else if let currentEntry = self.currentEntry {
                    if !entries.contains(where: { $0.id == currentEntry.id }) {
                        self.currentEntry = entries[0]
                    }
                }

                handler()
            }
        }
    }

    func archiveCurrentEntry() {
        if let currentEntry = self.currentEntry {
            self.entryDB.archiveEntry(byId: currentEntry.id) {
                UserNotificationsManager.shared.dismiss(byEntryId: currentEntry.id)
                self.updatePendingEntries()
            }
        }
    }

    func selectPreviousEntry() {
        if entries.isEmpty {
            return
        }

        if let currentEntry = self.currentEntry {
            if let index = entries.firstIndex(where: { $0.id == currentEntry.id }) {
                self.currentEntry = entries[(index - 1) < 0 ? entries.count - 1 : index - 1]
            } else {
                self.currentEntry = entries[0]
            }
        } else {
            currentEntry = entries[0]
        }
    }

    func selectNextEntry() {
        if entries.isEmpty {
            return
        }

        if let currentEntry = self.currentEntry {
            if let index = entries.firstIndex(where: { $0.id == currentEntry.id }) {
                self.currentEntry = entries[(index + 1) % entries.count]
            } else  {
                self.currentEntry = entries[0]
            }
        } else {
            currentEntry = entries[0]
        }
    }

    func hideEntries() {
        self.entriesVisible = false
    }

    func showEntries() {
        self.entriesVisible = true
    }

    func undo() {
        self.entryDB.undo {
            self.updatePendingEntries()
        }
    }
}
