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

        Notifications.observeWillArchiveEntry {
            self.entryDB.archiveEntry(byId: $0) { }
        }

        Notifications.observeWillSelectEntry { id in
            if let entry = self.entries.first(where: { $0.id == id }) {
                RunLoop.main.schedule {
                    self.currentEntry = entry
                    self.showEntries()
                }
            }
        }

        Notifications.observeWillSnoozeEntry {
            self.entryDB.snoozeEntry(byId: $0) { }
        }
    }

    func clear() {
        hideEntries()
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
        hideEntries()
        entryDB.commit(command: command) { res in
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

    func hideEntries() {
        entriesVisible = false
    }

    func showEntries() {
        entriesVisible = true
    }

    func updatePendingEntries() {
        updatePendingEntries { }
    }

    func updatePendingEntries(withCompletionHandler handler: @escaping () -> Void) {
        // Ensure that the "cursor" is preserved as much as possible when the entries
        // change by keeping track of the current position.
        var currentEntryIndex = 0
        if let currentEntry = self.currentEntry {
            currentEntryIndex = entries.firstIndex(where: { $0.id == currentEntry.id }) ?? 0
        }

        entryDB.findPendingEntries { entries in
            RunLoop.main.schedule {
                self.entries = entries

                if entries.isEmpty {
                    self.currentEntry = nil
                } else if self.currentEntry == nil {
                    self.currentEntry = entries[0]
                } else if let currentEntry = self.currentEntry {
                    if !entries.contains(where: { $0.id == currentEntry.id }) {
                        self.currentEntry = entries[currentEntryIndex % entries.count]
                    }
                }

                handler()
            }
        }
    }

    func archiveCurrentEntry() {
        if let currentEntry = self.currentEntry {
            entryDB.archiveEntry(byId: currentEntry.id) {
                UserNotificationsManager.shared.dismiss(byEntryId: currentEntry.id)
                self.updatePendingEntries()
            }
        }
    }

    func deleteCurrentEntry() {
        if let currentEntry = self.currentEntry {
            entryDB.deleteEntry(byId: currentEntry.id) {
                UserNotificationsManager.shared.dismiss(byEntryId: currentEntry.id)
                self.updatePendingEntries()
            }
        }
    }

    private func findPreviousEntryIndex() -> Int {
        if let currentEntry = self.currentEntry,
            let index = entries.firstIndex(where: { $0.id == currentEntry.id }) {

            return (index - 1) < 0 ? entries.count - 1 : index - 1
        }

        return 0
    }

    private func findNextEntryIndex() -> Int {
        if let currentEntry = self.currentEntry,
            let index = entries.firstIndex(where: { $0.id == currentEntry.id }) {

            return (index + 1) % entries.count
        }

        return 0
    }

    func selectPreviousEntry() {
        if entries.isEmpty {
            entriesVisible = false
        } else if !entriesVisible {
            entriesVisible = true
        } else {
            currentEntry = entries[self.findPreviousEntryIndex()]
        }
    }

    func selectNextEntry() {
        if entries.isEmpty {
            entriesVisible = false
        } else if !entriesVisible {
            entriesVisible = true
        } else {
            currentEntry = entries[findNextEntryIndex()]
        }
    }

    func undo() {
        entryDB.undo {
            self.updatePendingEntries()
        }
    }
}
