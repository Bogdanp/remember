//
//  Notifications.swift
//  remember
//
//  Created by Bogdan Popa on 27/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation

struct Notifications {
    private static func observe(_ name: NSNotification.Name, using handler: @escaping (Notification) -> Void) {
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil, using: handler)
    }

    static func willHideWindow() {
        NotificationCenter.default.post(
            name: .willHideWindow,
            object: nil)
    }

    static func observeWillHideWindow(withCompletionHandler handler: @escaping () -> Void) {
        observe(.willHideWindow) { _ in
            handler()
        }
    }

    static func willArchiveEntry(entryId: Entry.Id) {
        NotificationCenter.default.post(
            name: .willArchiveEntry,
            object: entryId)
    }

    static func observeWillArchiveEntry(withCompletionHandler handler: @escaping (Entry.Id) -> Void) {
        observe(.willArchiveEntry) { notification in
            if let id = notification.object as? Entry.Id {
                handler(id)
            }
        }
    }

    static func willSelectEntry(entryId: Entry.Id) {
        NotificationCenter.default.post(
            name: .willSelectEntry,
            object: entryId)
    }

    static func observeWillSelectEntry(withCompletionHandler handler: @escaping (Entry.Id) -> Void) {
        observe(.willSelectEntry) { notification in
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
        observe(.willSnoozeEntry) { notification in
            if let id = notification.object as? Entry.Id {
                handler(id)
            }
        }
    }
}

extension Notification.Name {
    static let willHideWindow = Notification.Name("io.defn.remember.willHideWindow")
    static let willArchiveEntry = Notification.Name("io.defn.remember.willArchiveEntry")
    static let willSelectEntry = Notification.Name("io.defn.remember.willSelectEntry")
    static let willSnoozeEntry = Notification.Name("io.defn.remember.willSnoozeEntry")
}
