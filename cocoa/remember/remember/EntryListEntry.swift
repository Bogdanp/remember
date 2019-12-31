//
//  EntryListEntry.swift
//  Remember
//
//  Created by Bogdan Popa on 30/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import SwiftUI

struct EntryListEntry: View {
    let entry: Entry
    let isCurrent: Bool

    init(_ entry: Entry, isCurrent: Bool) {
        self.entry = entry
        self.isCurrent = isCurrent
    }

    var body: some View {
        content
            .padding(6)
            .background(isCurrent ? Color(BG_CURRENT_ENTRY) : .clear)
            .cornerRadius(5)
    }

    var content: some View {
        HStack {
            Text(entry.title)
            Spacer()
            dueIn
        }
    }

    var dueIn: some View {
        entry.dueIn.map { text in
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(Color.white)
                .padding(5)
                .background(Color(BG_DUE_IN))
                .cornerRadius(5)
        }
    }
}
