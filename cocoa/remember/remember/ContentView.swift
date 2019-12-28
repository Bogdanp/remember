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
    @State var isEditable = true
    @State var entriesRequested = false

    init(entryDB: EntryDB, parser: Parser) {
        store = CommandStore(
            entryDB: entryDB,
            parser: parser)
        store.setup()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: nil) {
            HStack {
                Image("Icon")
                    .resizable()
                    .frame(width: 32, height: 32, alignment: .leading)

                CommandField($store.command,
                             tokens: $store.tokens,
                             isEditable: $isEditable) {
                    switch $0 {
                    case .cancel(_):
                        self.store.clear()
                    case .commit(let c):
                        self.isEditable = false
                        self.store.commit(command: c) {
                            self.isEditable = true
                            Notifications.commandDidComplete()
                        }
                    case .next where !self.entriesRequested:
                        self.entriesRequested = true
                        self.store.loadEntries()
                    default:
                        break
                    }
                }
            }

            if !store.entries.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(store.entries) { entry in
                        Text(entry.title)
                    }
                }
            }
        }
        .padding(15)
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
