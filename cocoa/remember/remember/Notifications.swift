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
}

extension Notification.Name {
    static let commandDidComplete = Notification.Name("commandDidComplete")
}
