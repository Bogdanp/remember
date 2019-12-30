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
    @ObservedObject var store: Store
    @State var entriesVisible = false

    init(asyncNotifier: AsyncNotifier,
         entryDB: EntryDB,
         parser: Parser) {
        store = Store(
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
                             tokens: $store.tokens) {
                    switch $0 {
                    case .cancel(_):
                        self.entriesVisible = false
                        self.store.clear()
                    case .commit(let c):
                        self.store.commit(command: c) {
                            self.entriesVisible = false
                            Notifications.commandDidComplete()
                        }
                    case .archive:
                        self.store.archiveCurrentEntry()
                    case .previous:
                        self.entriesVisible = true
                        self.store.updatePendingEntries {
                            self.store.selectPreviousEntry()
                        }
                    case .next:
                        self.entriesVisible = true
                        self.store.updatePendingEntries {
                            self.store.selectNextEntry()
                        }
                    }
                }
            }

            if entriesVisible && !store.entries.isEmpty {
                Divider()
                EntryList($store.entries, currentEntry: $store.currentEntry)
            }
        }
        .padding(15)
        .visualEffect()
        .cornerRadius(8)
    }
}
