//
//  EntryList.swift
//  Remember
//
//  Created by Bogdan Popa on 30/12/2019.
//  Copyright © 2019-2024 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import SwiftUI

struct EntryList: View {
  private let title = "Pending"

  @Binding var entries: [Entry]
  @Binding var currentEntry: Entry?

  init(_ entries: Binding<[Entry]>, currentEntry: Binding<Entry?>) {
    _entries = entries
    _currentEntry = currentEntry
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack {
        Text(title.uppercased())
          .font(.caption)
          .foregroundColor(.secondary)
        Spacer()
        Text("\(entries.count)")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.leading, 5)
          .padding(.trailing, 5)
          .overlay(
            Capsule(style: .continuous)
              .stroke(Color.secondary, lineWidth: 1)
          )
      }
      .padding(.top, 5)
      .padding(.bottom, 5)
      .padding(.leading, 10)
      .padding(.trailing, 10)
      .opacity(0.75)

      ForEach(visibleEntries()) { entry in
        EntryListItem(entry, isCurrent: self.currentEntry.map { entry.id == $0.id } ?? false)
      }
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
