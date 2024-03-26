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
    scheduleLoadEntries()

    Backend.shared.installCallback(entriesDidChangeCb: { [weak self] _ in
      RunLoop.main.schedule {
        self?.scheduleLoadEntries()
      }
    }).onComplete {
      _ = Backend.shared.markReadyForChanges()
    }

    Backend.shared.installCallback(entriesDueCb: { [weak self] entries in
      RunLoop.main.schedule {
        guard let self else { return }
        self.scheduleLoadEntries()
        entries.forEach { entry in
          NotificationsManager.shared.notify(of: entry)
        }
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

  private func scheduleLoadEntries() {
    assert(Thread.current.isMainThread)
    if let timer = self.timer {
      timer.fire()
    }
    timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
      self?.loadEntries()
    }
  }

  private func loadEntries() {
    Backend.shared.getPendingEntries().onComplete { [weak self] entries in
      self?.entries = entries
    }
    Backend.shared.getDueEntries().onComplete { entries in
      NotificationsManager.shared.setBadgeCount(entries.count)
    }
  }
}
