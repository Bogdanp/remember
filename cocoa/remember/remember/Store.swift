//
//  CommandStore.swift
//  remember
//
//  Created by Bogdan Popa on 27/12/2019.
//  Copyright © 2019-2024 CLEARTYPE SRL. All rights reserved.
//

import Combine
import Foundation
import NoiseSerde

class Store: ObservableObject {
  private var parseCancellable: AnyCancellable? = nil

  @Published var command = NSAttributedString(string: "")
  @Published var tokens = [Token]()
  @Published var entries = [Entry]()
  @Published var entriesVisible = false
  @Published var currentEntry: Entry? = nil
  @Published var editingEntryWithId: UVarint? = nil

  init() {
    self.parseCancellable = $command
      .map(\.string)
      .filter { !$0.isEmpty }
      .receive(on: RunLoop.main)
      .sink { text in
        Backend.shared.parse(command: text).onComplete { [weak self] ts in
          self?.tokens = ts
        }
      }

    self.updatePendingEntries()
    try! Backend.shared.installCallback(entriesDidChangeCb: { [weak self] _ in
      DispatchQueue.main.async {
        self?.updatePendingEntries()
      }
    }).wait()
    try! Backend.shared.markReadyForChanges().wait()

    Notifications.observeWillArchiveEntry {
      _ = Backend.shared.archive(entryWithId: $0)
    }

    Notifications.observeWillSelectEntry { id in
      if let entry = self.entries.first(where: { $0.id == id }) {
        RunLoop.main.schedule {
          self.currentEntry = entry
          self.updatePendingEntries {
            self.showEntries()
          }
        }
      }
    }

    Notifications.observeWillSnoozeEntry {
      _ = Backend.shared.snooze(entryWithId: $0, forMinutes: UVarint(SnoozeDefaults.get()))
    }
  }

  func clear() {
    hideEntries()
    if command.string.isEmpty {
      Notifications.willHideWindow()
    }

    command = NSAttributedString(string: "")
    tokens = []
    editingEntryWithId = nil
  }

  func commit(command: String) {
    commit(command: command) {
      Notifications.willHideWindow()
    }
  }

  func commit(command: String, withCompletionHandler handler: @escaping () -> Void) {
    if command.isEmpty {
      editCurrentEntry()
    } else if let id = editingEntryWithId {
      Backend.shared.update(
        entryWithId: id,
        andCommand: command
      ).onComplete { [weak self] _ in
        self?.clear()
        handler()
      }
    } else {
      Backend.shared.commit(command: command).onComplete { [weak self] _ in
        self?.clear()
        handler()
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

    Backend.shared.getPendingEntries().onComplete { [weak self] entries in
      guard let self else { return }

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

  func archiveCurrentEntry() {
    if let currentEntry = self.currentEntry {
      Backend.shared.archive(entryWithId: currentEntry.id).onComplete { [weak self] in
        UserNotificationsManager.shared.dismiss(byEntryId: currentEntry.id)
        self?.updatePendingEntries()
      }
    }
  }

  func deleteCurrentEntry() {
    if let currentEntry = self.currentEntry {
      Backend.shared.delete(entryWithId: currentEntry.id).onComplete { [weak self] in
        UserNotificationsManager.shared.dismiss(byEntryId: currentEntry.id)
        self?.updatePendingEntries()
      }
    }
  }

  func editCurrentEntry() {
    if let currentEntry = self.currentEntry {
      command = NSAttributedString(string: currentEntry.title)
      editingEntryWithId = currentEntry.id
    }
  }

  func stopEditing() {
    if editingEntryWithId != nil {
      command = NSAttributedString(string: "")
      editingEntryWithId = nil
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
      stopEditing()
    }
  }

  func selectNextEntry() {
    if entries.isEmpty {
      entriesVisible = false
    } else if !entriesVisible {
      entriesVisible = true
    } else {
      currentEntry = entries[findNextEntryIndex()]
      stopEditing()
    }
  }

  func undo() {
    Backend.shared.undo().onComplete { [weak self] in
      self?.updatePendingEntries()
    }
  }
}
