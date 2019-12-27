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
            .flatMap {
                self.parser.parse(command: $0)
                    .replaceError(with: [])
            }
            .receive(on: RunLoop.main)
            .assign(to: \.tokens, on: self)
    }
}
