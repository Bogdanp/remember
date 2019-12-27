//
//  CommandStore.swift
//  remember
//
//  Created by Bogdan Popa on 27/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Combine
import Foundation

class CommandStore: ObservableObject {
    private let parser: Parser
    private var parseCancellable: AnyCancellable?

    @Published var command = NSAttributedString(string: "")
    @Published var tokens = [Token]()

    init(parser theParser: Parser) {
        parser = theParser
        parseCancellable = nil
    }

    func setup() {
        parseCancellable = $command
            .map(\.string)
            .debounce(for: 0.1, scheduler: RunLoop.main)
            .removeDuplicates()
            .flatMap { text in
                return Future { promise in
                    self.parser.parse(command: text) {
                        switch $0 {
                        case .ok(let tokens):
                            promise(.success(tokens))
                        case .error:
                            promise(.success([]))
                        }
                    }
                }
            }
            .receive(on: RunLoop.main)
            .assign(to: \.tokens, on: self)
    }

    func clear() {
        self.command = NSAttributedString(string: "")
        self.tokens = []
    }

    func commit(command: String, action: () -> Void) {
        
    }
}
