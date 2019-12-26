//
//  Client.swift
//  remember
//
//  Created by Bogdan Popa on 26/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Combine
import Foundation

class Client: Parser {
    private let rpc: ComsCenter

    init(_ rpc: ComsCenter) {
        self.rpc = rpc
    }

    func parse(command: String) -> AnyPublisher<[Token], ParseError> {
        return rpc.call("parse-command", [command])
            .mapError { .error($0) }
            .eraseToAnyPublisher()
    }
}
