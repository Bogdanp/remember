//
//  UserNotifications.swift
//  Remember
//
//  Created by Bogdan Popa on 28/12/2019.
//  Copyright © 2019-2024 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import NoiseSerde
import UserNotifications
import os

fileprivate let logger = Logger(
  subsystem: "io.defn.remember",
  category: "UserNotifications"
)

enum UserNotificationInfo: String {
  case entryId
}

enum UserNotificationAction: String {
  case `default` = "com.apple.UNNotificationDefaultActionIdentifier"
  case dismiss = "com.apple.UNNotificationDismissActionIdentifier"
  case archive = "io.defn.remember.ArchiveAction"
  case snooze = "io.defn.remember.SnoozeAction"
}

enum UserNotificationCategory: String {
  case entry = "io.defn.remember.EntryCategory"
}

class UserNotificationsManager: NSObject, UNUserNotificationCenterDelegate {
  public static let shared = UserNotificationsManager()

  private let queue = DispatchQueue(label: "io.defn.remember.UserNotificationsManager")
  private var pending = [UVarint]()

  private override init() {
    super.init()
  }

  private func addPending(byId id: UVarint, withDeadline deadline: DispatchTime) -> Bool {
    queue.sync {
      if self.pending.contains(id) {
        return false
      }

      queue.asyncAfter(deadline: deadline) {
        self.pending.removeAll(where: { $0 == id })
      }

      self.pending.append(id)
      return true
    }
  }

  private func removePending(byId id: UVarint) {
    queue.sync {
      self.pending.removeAll(where: { $0 == id })
    }
  }

  func setup() {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .badge, .sound], completionHandler: { granted, err in
      if !granted {
        logger.error("Alert access not granted.")
        return
      }

      let archiveAction = UNNotificationAction(
        identifier: UserNotificationAction.archive.rawValue,
        title: "Archive",
        options: [.destructive, .authenticationRequired])

      let snoozeAction = UNNotificationAction(
        identifier: UserNotificationAction.snooze.rawValue,
        title: "Snooze",
        options: [.destructive, .authenticationRequired])

      let entryCategory = UNNotificationCategory(
        identifier: UserNotificationCategory.entry.rawValue,
        actions: [archiveAction, snoozeAction],
        intentIdentifiers: [],
        options: .customDismissAction)

      center.setNotificationCategories([entryCategory])
      center.delegate = self

      try! Backend.shared.installCallback(entriesDueCb: { entries in
        for entry in entries {
          if !self.addPending(byId: entry.id, withDeadline: .now() + .seconds(15 * 60)) {
            logger.debug("Notification for entry \(entry.id) ignored.")
            continue
          }

          let content = UNMutableNotificationContent()
          content.title = "Remember"
          content.subtitle = entry.title
          content.sound = .default
          content.userInfo = [UserNotificationInfo.entryId.rawValue: entry.id]
          content.categoryIdentifier = UserNotificationCategory.entry.rawValue

          let request = UNNotificationRequest(
            identifier: String(entry.id),
            content: content,
            trigger: nil)

          center.add(request) { error in
            if let err = error {
              logger.error("Failed to add notification: \(err)")
            }
          }
        }
      }).wait()
      try! Backend.shared.startScheduler().wait()
    })
  }

  func dismiss(byEntryId id: UVarint) {
    let center  = UNUserNotificationCenter.current()
    center.removeDeliveredNotifications(withIdentifiers: [String(id)])
    self.removePending(byId: id)
  }

  func dismissAll() {
    let center = UNUserNotificationCenter.current()
    center.removeAllDeliveredNotifications()
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    return completionHandler([.list])
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    guard let action = UserNotificationAction(rawValue: response.actionIdentifier) else {
      return completionHandler()
    }

    let userInfo = response.notification.request.content.userInfo
    if let id = userInfo[UserNotificationInfo.entryId.rawValue] as? UVarint {
      self.removePending(byId: id)

      switch action {
      case .archive:
        Notifications.willArchiveEntry(entryId: id)
      case .dismiss, .snooze:
        Notifications.willSnoozeEntry(entryId: id)
      case .`default`:
        Notifications.willSelectEntry(entryId: id)
      }
    }

    completionHandler()
  }
}
