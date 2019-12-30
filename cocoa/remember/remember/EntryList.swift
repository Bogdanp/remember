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

    init(_ entries: Binding<[Entry]>) {
        _entries = entries
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(entries) { entry in
                    HStack {
                        Text(entry.title)
                        Spacer()
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
                .padding(.top, 6)
            }
        }
        .frame(width: nil, height: 200, alignment: .top)
    }
}
