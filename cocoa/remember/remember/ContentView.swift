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
    @ObservedObject private var store: Store

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
                    case .update(_):
                        self.store.hideEntries()
                    case .cancel(_):
                        self.store.clear()
                    case .commit(let c):
                        self.store.commit(command: c)
                    case .archive:
                        if self.store.entriesVisible {
                            self.store.archiveCurrentEntry()
                        }
                    case .delete:
                        if self.store.entriesVisible {
                            self.store.deleteCurrentEntry()
                        }
                    case .previous:
                        self.store.updatePendingEntries {
                            self.store.selectPreviousEntry()
                        }
                    case .next:
                        self.store.updatePendingEntries {
                            self.store.selectNextEntry()
                        }
                    case .undo:
                        self.store.undo()
                    }
                }
            }
            .padding(.top, 15)
            .padding(.leading, 15)
            .padding(.trailing, 15)
            .padding(.bottom, entriesVisible ? 10 : 15)

            if entriesVisible {
                Divider()
                EntryList($store.entries, currentEntry: $store.currentEntry)
            }
        }
        .visualEffect()
        .cornerRadius(8)
    }

    var entriesVisible: Bool {
        store.entriesVisible && !store.entries.isEmpty
    }
}
