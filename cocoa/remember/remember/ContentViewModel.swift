//
//  CommandViewModel.swift
//  remember
//
//  Created by Bogdan Popa on 26/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Combine
import Foundation
import SwiftUI

class ContentViewModel: ObservableObject {
    @Published private(set) var tokens = [Token]()

    private let parser: Parser

    private var parseCancellable: AnyCancellable? {
        didSet {
            oldValue?.cancel()
        }
    }

    init(parser: Parser) {
        self.parser = parser
    }

    deinit {
        parseCancellable?.cancel()
    }

    func parse(command: String) {
        parseCancellable = parser
            .parse(command: command)
            .replaceError(with: [])
            .receive(on: RunLoop.main)
            .assign(to: \.tokens, on: self)
    }
}
