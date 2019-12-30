//
//  UserNotifications.swift
//  Remember
//
//  Created by Bogdan Popa on 28/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import UserNotifications
import os

enum UserNotificationInfo: String {
    case entryId
}

enum UserNotificationAction: String {
    case dismiss = "com.apple.UNNotificationDismissActionIdentifier"
    case archive = "io.defn.remember.ArchiveAction"
}

enum UserNotificationCategory: String {
    case entry = "io.defn.remember.EntryCategory"
}

class UserNotificationsManager: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = UserNotificationsManager()

    private let queue = DispatchQueue(label: "io.defn.remember.UserNotificationsManager")
    private var pending = [UInt32]()

    private override init() {
        super.init()
    }

    private func addPending(byId id: UInt32) -> Bool {
        queue.sync {
            if self.pending.contains(id) {
                return false
            }

            self.pending.append(id)
            return true
        }
    }

    private func removePending(byId id: UInt32) {
        queue.sync {
            self.pending.removeAll(where: { $0 == id })
        }
    }

    func setup(asyncNotifier: AsyncNotifier) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound], completionHandler: { granted, err in
            if !granted {
                os_log("alert acess not granted", type: .error)
                return
            }

            let archiveAction = UNNotificationAction(
                identifier: UserNotificationAction.archive.rawValue,
                title: "Archive",
                options: [.destructive, .authenticationRequired])

            let entryCategory = UNNotificationCategory(
                identifier: UserNotificationCategory.entry.rawValue,
                actions: [archiveAction],
                intentIdentifiers: [],
                options: .customDismissAction)

            center.setNotificationCategories([entryCategory])
            center.delegate = self

            asyncNotifier.addListener { notification in
                switch notification {
                case .entriesDue(let notification):
                    for entry in notification.entries {
                        if !self.addPending(byId: entry.id) {
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
                                os_log("failed to add notification: %s", type: .error, "\(err)")
                            }
                        }
                    }

                default:
                    break
                }
            }
        })
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        guard let action = UserNotificationAction(rawValue: response.actionIdentifier) else {
            return completionHandler()
        }

        let userInfo = response.notification.request.content.userInfo
        if let id = userInfo[UserNotificationInfo.entryId.rawValue] as? UInt32 {
            self.removePending(byId: id)

            switch action {
            case .dismiss:
                Notifications.userDidSnooze(entryId: id)
            case .archive:
                Notifications.userDidArchive(entryId: id)
            }
        }

        completionHandler()
    }
}
