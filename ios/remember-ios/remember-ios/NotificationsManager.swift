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

  func removePendingNotification(for entry: Entry) {
    assert(Thread.current.isMainThread)
    entries.removeValue(forKey: entry.notificationId)
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [entry.notificationId])
  }

  func notify(of entry: Entry) {
    assert(Thread.current.isMainThread)
    if entries.contains(where: { $0.key == entry.notificationId }) {
      return
    }

    entries[entry.notificationId] = entry
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
