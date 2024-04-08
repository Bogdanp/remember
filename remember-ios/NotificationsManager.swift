import BackgroundTasks
import Foundation
import NoiseSerde
import UserNotifications
import os

fileprivate let logger = Logger(
  subsystem: "io.defn.remember-ios",
  category: "NotificationsManager"
)

class NotificationsManager: NSObject {
  static let shared = NotificationsManager()

  private var entries = [String: Entry]()

  private static let refreshIdentifier = "io.defn.remember.NotificationsManager.refresh"

  override init() {
    super.init()

    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.requestAuthorization(options: [.alert, .badge, .sound]) { _, error in
      guard error == nil else {
        logger.error("Did not receive authorization to send notifications: \(error)")
        return
      }
    }
  }

  func registerTasks() {
    logger.debug("Registering refresh task.")
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: Self.refreshIdentifier,
      using: nil) { [weak self] task in
        self?.handleRefresh(task as! BGAppRefreshTask)
      }
  }

  func scheduleRefresh() {
    logger.debug("Preparing to schedule refresh.")
    Backend.shared.getPendingEntries().onComplete { entries in
      let now = UVarint(Date().timeIntervalSince1970)
      let request = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
      var deadline: TimeInterval? = nil
      for entry in entries {
        if let dueAt = entry.dueAt, dueAt >= now {
          deadline = TimeInterval(dueAt)
          break
        }
      }
      guard let deadline = deadline else {
        logger.warning("No pending tasks, not scheduling refresh.")
        return
      }
      request.earliestBeginDate = Date(timeIntervalSince1970: deadline)
      logger.debug("Scheduling refresh at \(request.earliestBeginDate!.ISO8601Format()).")

      do {
        try BGTaskScheduler.shared.submit(request)
      } catch {
        logger.error("Failed to schedule refresh: \(error)")
      }
    }
  }

  func unscheduleRefresh() {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshIdentifier)
  }

  private func handleRefresh(_ task: BGAppRefreshTask) {
    scheduleRefresh()

    let future = Backend.shared.getDueEntries()
    future.onComplete { entries in
      RunLoop.main.schedule {
        self.notify(ofEntries: entries)
        task.setTaskCompleted(success: true)
      }
    }

    task.expirationHandler = {
      future.cancel()
      task.setTaskCompleted(success: false)
    }
  }

  func removePendingNotification(for entry: Entry) {
    assert(Thread.current.isMainThread)
    entries.removeValue(forKey: entry.notificationId)
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [entry.notificationId])
  }

  func notify(ofEntries entries: [Entry]) {
    assert(Thread.current.isMainThread)
    self.entries.forEach({ removePendingNotification(for: $0.value) })
    self.entries.removeAll(keepingCapacity: true)
    for entry in entries {
      self.entries[entry.notificationId] = entry
      let content = UNMutableNotificationContent()
      content.title = "Remember"
      content.body = entry.title
      content.badge = NSNumber(value: entries.count)
      let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 15, repeats: false)
      let request = UNNotificationRequest(
        identifier: entry.notificationId,
        content: content,
        trigger: trigger)
      UNUserNotificationCenter
        .current()
        .add(request) { _ in }
    }
  }

  func setBadgeCount(_ count: Int) {
    UNUserNotificationCenter
      .current()
      .setBadgeCount(count)
  }
}

extension NotificationsManager: UNUserNotificationCenterDelegate {
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void) {

      RunLoop.main.schedule { [weak self] in
        guard let self else { return }
        if let entry = self.entries[response.notification.request.identifier] {
          self.removePendingNotification(for: entry)
        }
      }
  }
}
