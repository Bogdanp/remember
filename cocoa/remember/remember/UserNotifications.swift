//
//  UserNotifications.swift
//  Remember
//
//  Created by Bogdan Popa on 28/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import UserNotifications

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

class UserNotificationsHandler: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        guard let action = UserNotificationAction(rawValue: response.actionIdentifier) else {
            return completionHandler()
        }

        let userInfo = response.notification.request.content.userInfo

        switch action {
        case .dismiss:
            // TODO: snooze
            break
        case .archive:
            if let entryId = userInfo[UserNotificationInfo.entryId.rawValue] as? UInt32 {
                Notifications.userDidArchive(entryId: entryId)
            }
        }

        completionHandler()
    }
}
