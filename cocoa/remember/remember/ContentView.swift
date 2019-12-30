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
    @State var showingPendingEntries = false

    init(asyncNotifier: AsyncNotifier,
         entryDB: EntryDB,
         parser: Parser) {
        store = CommandStore(
            asyncNotifier: asyncNotifier,
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
                        self.showingPendingEntries = false
                        self.store.clear()
                    case .commit(let c):
                        self.store.commit(command: c) {
                            self.showingPendingEntries = false
                            Notifications.commandDidComplete()
                        }
                    case .previous, .next:
                        self.showingPendingEntries = true
                        self.store.updatePendingEntries()
                    }
                }
            }

            if showingPendingEntries && !store.entries.isEmpty {
                Divider()
                EntryList($store.entries)
            }
        }
        .padding(15)
        .visualEffect()
        .cornerRadius(8)
    }
}
