import Foundation
import SwiftUI
import UserNotifications
import os

fileprivate let logger = Logger(
  subsystem: "io.defn.remember-ios",
  category: "Store"
)

class Store: ObservableObject {
  @Published var entries = [Entry]()

  private var timer: Timer?

  init() {
    loadEntries()

    Backend.shared.installCallback(entriesDidChangeCb: { [weak self] _ in
      logger.debug("Entries changed.")
      self?.loadEntries()
    }).onComplete {
      _ = Backend.shared.markReadyForChanges()
    }

    Backend.shared.installCallback(entriesDueCb: { [weak self] entries in
      logger.debug("Have \(entries.count) due entries.")
      RunLoop.main.schedule {
        self?.loadEntries()
        NotificationsManager.shared.notify(ofEntries: entries)
      }
    }).onComplete {
      _ = Backend.shared.startScheduler()
    }
  }

  func archive(entry: Entry) {
    Backend.shared.archive(entryWithId: entry.id).onComplete {
      NotificationsManager.shared.removePendingNotification(for: entry)
    }
  }

  func delete(entry: Entry) {
    Backend.shared.delete(entryWithId: entry.id).onComplete {
      NotificationsManager.shared.removePendingNotification(for: entry)
    }
  }

  func snooze(entry: Entry) {
    Backend.shared.snooze(entryWithId: entry.id, forMinutes: 15).onComplete {
      NotificationsManager.shared.removePendingNotification(for: entry)
    }
  }

  func update(
    entry: Entry,
    withCommand command: String,
    andCompletionHandler completionHandler: @escaping () -> Void = { }
  ) {
    Backend.shared.update(entryWithId: entry.id, andCommand: command).onComplete { _ in
      NotificationsManager.shared.removePendingNotification(for: entry)
      completionHandler()
    }
  }

  func invalidate() {
    assert(Thread.current.isMainThread)
    logger.debug("Invalidating timer.")
    timer?.invalidate()
  }

  func scheduleLoadEntries() {
    assert(Thread.current.isMainThread)
    logger.debug("Scheduling entry load timer.")
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
      logger.debug("Entry load timer fired.")
      self?.loadEntries()
    }
  }

  func loadEntries() {
    logger.debug("Loading entries.")
    Backend.shared.getPendingEntries().onComplete { [weak self] entries in
      RunLoop.main.schedule {
        self?.entries = entries
        Backend.shared.getDueEntries().onComplete { entries in
          NotificationsManager.shared.notify(ofEntries: entries)
        }
      }
    }
  }
}
