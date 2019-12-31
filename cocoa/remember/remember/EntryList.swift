//
//  EntryList.swift
//  Remember
//
//  Created by Bogdan Popa on 30/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import SwiftUI

struct EntryList: View {
    @Binding var entries: [Entry]
    @Binding var currentEntry: Entry?

    init(_ entries: Binding<[Entry]>, currentEntry: Binding<Entry?>) {
        _entries = entries
        _currentEntry = currentEntry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(visibleEntries()) { entry in
                EntryListItem(entry, isCurrent: self.currentEntry.map { entry.id == $0.id } ?? false)
            }
            .padding(.top, 6)
        }
    }

    func visibleEntries() -> [Entry] {
        guard let currentEntry = self.currentEntry else {
            return []
        }

        if let index = entries.firstIndex(where: { $0.id == currentEntry.id }) {
            if index - 2 < 0 {
                let lo = 0
                let hi = min(5, entries.count)
                return Array(entries[lo ..< hi])
            } else if index + 2 >= entries.count {
                let lo = max(0, entries.count - 5)
                let hi = entries.count
                return Array(entries[lo ..< hi])
            } else {
                let lo = index - 2
                let hi = index + 2
                return Array(entries[lo ... hi])
            }
        }

        return []
    }
}
