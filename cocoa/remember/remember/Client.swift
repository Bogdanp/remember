//
//  Client.swift
//  remember
//
//  Created by Bogdan Popa on 26/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import UserNotifications
import os

class Client: Parser & EntryDB {
    private let rpc: ComsCenter

    init(_ rpc: ComsCenter) {
        self.rpc = rpc

        rpc.asyncNotificationHandler = { notification in
            switch notification {
            case .entriesDue(let notification):
                self.handleEntriesDueNotification(notification)
            }
        }
    }

    func parse(command: String, withCompletionHandler handler: @escaping (ParseResult) -> Void) {
        return rpc.call("parse-command", [command]) { (res: RPCResult<[Token]>) in
            switch res {
            case .ok(let tokens):
                handler(.ok(tokens))
            case .error(let error):
                handler(.error(error))
            }
        }
    }

    func commit(command: String, withCompletionHandler handler: @escaping (CommitResult) -> Void) {
        return rpc.call("commit-entry!", [command]) { (res: RPCResult<Entry>) in
            switch res {
            case .ok(let entry):
                handler(.ok(entry))
            case .error(let error):
                handler(.error(error))
            }
        }
    }

    func archiveEntry(byId id: UInt32, withCompletionHandler handler: @escaping () -> Void) {
        return rpc.call("archive-entry!", [id]) { (res: RPCResult<RPCUnit>) in
            handler()
        }
    }

    func findPendingEntries(withCompletionHandler handler: @escaping ([Entry]) -> Void) {
        return rpc.call("find-pending-entries", []) { (res: RPCResult<[Entry]>) in
            switch res {
            case .ok(let entries):
                handler(entries)
            case .error:
                handler([])
            }
        }
    }

    private func handleEntriesDueNotification(_ notification: EntriesDueNotification) {
        let center = UNUserNotificationCenter.current()
        for entry in notification.entries {
            let content = UNMutableNotificationContent()
            content.title = "Remember"
            content.subtitle = entry.title
            content.sound = .default
            content.userInfo = [UserNotificationInfo.entryId.rawValue: entry.id]
            content.categoryIdentifier = UserNotificationCategory.entry.rawValue

            let request = UNNotificationRequest(
                identifier: "remember:\(entry.id)",
                content: content,
                trigger: nil)

            center.add(request) { error in
                if let err = error {
                    os_log("failed to add notification: %s", type: .error, "\(err)")
                }
            }
        }
    }
}
