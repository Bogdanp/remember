//
//  Client.swift
//  remember
//
//  Created by Bogdan Popa on 26/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation

class Client: Parser & EntryDB {
    private let rpc: ComsCenter

    init(_ rpc: ComsCenter) {
        self.rpc = rpc
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
}
