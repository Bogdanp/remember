//
//  EntryListEntry.swift
//  Remember
//
//  Created by Bogdan Popa on 30/12/2019.
//  Copyright © 2019-2024 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import SwiftUI

struct EntryListItem: View {
  let entry: Entry
  let isCurrent: Bool

  init(_ entry: Entry, isCurrent: Bool) {
    self.entry = entry
    self.isCurrent = isCurrent
  }

  var body: some View {
    HStack {
      Text(entry.title)
      Spacer()
      if entry.recurs {
        Image(nsImage: NSImage(named: NSImage.refreshFreestandingTemplateName)!)
          .foregroundColor(isCurrent ? Color.white : Color.secondary)
      }
      dueIn
    }
    .frame(width: nil, height: 32, alignment: .center)
    .padding(.leading, 10)
    .padding(.trailing, 10)
    .background(isCurrent ? Color.accentColor : .clear)
    .foregroundColor(isCurrent ? Color(NSColor.white) : .primary)
  }

  var dueIn: some View {
    entry.dueIn.map { text in
      Text(text)
        .padding(5)
        .font(.system(size: 10))
        .foregroundColor(isCurrent ? Color.white : Color.secondary)
        .overlay(
          Capsule(style: .continuous)
            .stroke(isCurrent ? Color.white : Color.secondary, lineWidth: 1)
        )
    }
  }
}
