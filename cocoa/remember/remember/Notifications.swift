//
//  Notifications.swift
//  remember
//
//  Created by Bogdan Popa on 27/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation

struct Notifications {
    static func willHideWindow() {
        NotificationCenter.default.post(
            name: .willHideWindow,
            object: nil)
    }

    static func observeWillHideWindow(withCompletionHandler handler: @escaping () -> Void) {
        NotificationCenter.default.addObserver(
            forName: .willHideWindow,
            object: nil,
            queue: nil) { _ in

                handler()
        }
    }

    static func willArchiveEntry(entryId: Entry.Id) {
        NotificationCenter.default.post(
            name: .willArchiveEntry,
            object: entryId)
    }

    static func observeWillArchiveEntry(withCompletionHandler handler: @escaping (Entry.Id) -> Void) {
        NotificationCenter.default.addObserver(
            forName: .willArchiveEntry,
            object: nil,
            queue: nil) { notification in

                if let id = notification.object as? Entry.Id {
                    handler(id)
                }
        }
    }

    static func willSnoozeEntry(entryId: Entry.Id) {
        NotificationCenter.default.post(
            name: .willSnoozeEntry,
            object: entryId)
    }

    static func observeWillSnoozeEntry(withCompletionHandler handler: @escaping (Entry.Id) -> Void) {
        NotificationCenter.default.addObserver(
            forName: .willSnoozeEntry,
            object: nil,
            queue: nil) { notification in

                if let id = notification.object as? Entry.Id {
                    handler(id)
                }
        }
    }
}

extension Notification.Name {
    static let willHideWindow = Notification.Name("io.defn.remember.willHideWindow")
    static let willArchiveEntry = Notification.Name("io.defn.remember.willArchiveEntry")
    static let willSnoozeEntry = Notification.Name("io.defn.remember.willSnoozeEntry")
}
