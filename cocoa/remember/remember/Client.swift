//
//  Client.swift
//  remember
//
//  Created by Bogdan Popa on 26/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import UserNotifications

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

    func parse(command: String, action: @escaping (ParseResult) -> Void) {
        return rpc.call("parse-command", [command]) { (res: RPCResult<[Token]>) in
            switch res {
            case .ok(let tokens):
                action(.ok(tokens))
            case .error(let error):
                action(.error(error))
            }
        }
    }

    func commit(command: String, action: @escaping (CommitResult) -> Void) {
        return rpc.call("commit-entry!", [command]) { (res: RPCResult<Entry>) in
            switch res {
            case .ok(let entry):
                action(.ok(entry))
            case .error(let error):
                action(.error(error))
            }
        }
    }

    private func handleEntriesDueNotification(_ notification: EntriesDueNotification) {
        let center = UNUserNotificationCenter.current()
        for entry in notification.entries {
            let content = UNMutableNotificationContent()
            content.body = entry.title
            content.sound = .defaultCritical

            let request = UNNotificationRequest(
                identifier: "remember:\(entry.id)",
                content: content,
                trigger: nil)

            center.add(request) { error in
                print(error)
            }
        }
    }
}
