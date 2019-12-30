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
        ScrollView {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(entries) { entry in
                    EntryListEntry(entry, isCurrent: self.currentEntry.map { entry.id == $0.id } ?? false)
                }
                .padding(.top, 6)
            }
        }
        .frame(width: nil, height: 200, alignment: .top)
    }
}
