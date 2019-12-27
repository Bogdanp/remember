//
//  ContentView.swift
//  remember
//
//  Created by Bogdan Popa on 23/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Combine
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: CommandStore

    init(parser: Parser) {
        store = CommandStore(parser: parser)
        store.setup()
    }

    var body: some View {
        VStack {
            CommandField($store.command, tokens: $store.tokens) {
                switch $0 {
                case .cancel(_):
                    self.store.clear()
                case .commit(let c):
                    self.store.commit(command: c) { 

                    }
                }
            }
                .padding(15)
                .padding(.leading, 25)
        }
        .visualEffect()
        .cornerRadius(8)
    }
}

//#if DEBUG
//struct FakeParser: Parser {
//    let result: [Token]
//
//    func parse(command: String) -> AnyPublisher<[Token], ParseError> {
//        return Result.Publisher.init(result).eraseToAnyPublisher()
//    }
//}
//
//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView(parser: FakeParser(result: []))
//    }
//}
//#endif
