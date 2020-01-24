//
//  Client.swift
//  remember
//
//  Created by Bogdan Popa on 26/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import os

class Client: AsyncNotifier & Parser & EntryDB {
    private let rpc: ComsCenter

    init(_ rpc: ComsCenter) {
        self.rpc = rpc
    }

    func addListener(withHandler handler: @escaping (AsyncNotification) -> Void) {
        rpc.addListener(withHandler: handler)
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
        return rpc.call("commit!", [command]) { (res: RPCResult<Entry>) in
            switch res {
            case .ok(let entry):
                handler(.ok(entry))
            case .error(let error):
                handler(.error(error))
            }
        }
    }

    func update(byId id: Entry.Id, withCommand command: String, andCompletionHandler handler: @escaping (CommitResult) -> Void) {
        return rpc.call("update!", [id, command]) { (res: RPCResult<Entry>) in
            switch res {
            case .ok(let entry):
                handler(.ok(entry))
            case .error(let error):
                handler(.error(error))
            }
        }
    }

    func archiveEntry(byId id: Entry.Id) {
        archiveEntry(byId: id) { }
    }

    func archiveEntry(byId id: Entry.Id, withCompletionHandler handler: @escaping () -> Void) {
        return rpc.call("archive-entry!", [id]) { (res: RPCResult<RPCUnit>) in
            handler()
        }
    }

    func snoozeEntry(byId id: Entry.Id) {
        snoozeEntry(byId: id) { }
    }

    func snoozeEntry(byId id: Entry.Id, withCompletionHandler handler: @escaping () -> Void) {
        return rpc.call("snooze-entry!", [id]) { (res: RPCResult<RPCUnit>) in
            handler()
        }
    }

    func deleteEntry(byId id: Entry.Id) {
        deleteEntry(byId: id) { }
    }

    func deleteEntry(byId id: Entry.Id, withCompletionHandler handler: @escaping () -> Void) {
        return rpc.call("delete-entry!", [id]) { (res: RPCResult<RPCUnit>) in
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

    func undo(withCompletionHandler handler: @escaping () -> Void) {
        return rpc.call("undo!", []) { (res: RPCResult<RPCUnit>) in
            handler()
        }
    }

    func createDatabaseCopy(withCompletionHandler handler: @escaping (URL) -> Void) {
        return rpc.call("create-database-copy!", []) { (res: RPCResult<URL>) in
            switch res {
            case .ok(let p):
                handler(p)
            case .error(let e):
                os_log("failed to create database copy: %s", type: .error, "\(e)")
            }
        }
    }
}
