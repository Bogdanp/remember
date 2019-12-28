//
//  Notifications.swift
//  remember
//
//  Created by Bogdan Popa on 27/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation

struct Notifications {
    static func commandDidComplete() {
        NotificationCenter.default.post(
            name: .commandDidComplete,
            object: nil)
    }

    static func userDidArchive(entryId: UInt32) {
        NotificationCenter.default.post(
            name: .userDidArchive,
            object: entryId)
    }
}

extension Notification.Name {
    static let commandDidComplete = Notification.Name("io.defn.remember.commandDidComplete")
    static let userDidArchive = Notification.Name("io.defn.remember.userDidArchive")
}
