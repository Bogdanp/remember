//
//  CustomTextField.swift
//  remember
//
//  Created by Bogdan Popa on 23/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import SwiftUI
import SwiftyAttributes

struct CommandField: NSViewRepresentable {
    typealias NSViewType = NSTextField

    @State var text: NSAttributedString = NSAttributedString(string: "")

    private var tokens: [Token]
    private var action: ((String) -> Void)? = nil

    init(tokens theTokens: [Token], action theAction: @escaping (String) -> Void) {
        tokens = theTokens
        action = theAction
    }

    func makeNSView(context: NSViewRepresentableContext<CommandField>) -> NSViewType {
        let field = NSTextField()
        field.allowsEditingTextAttributes = true
        field.backgroundColor = NSColor.clear
        field.delegate = context.coordinator
        field.isBordered = false
        field.focusRingType = .none
        field.placeholderString = "Remember"
        return field
    }

    func updateNSView(_ nsView: NSViewType, context: NSViewRepresentableContext<CommandField>) {
        let font = NSFont.systemFont(ofSize: 24)
        var attributedText = "".withFont(font)
        for token in tokens {
            switch token {
            case .chunk(let c):
                attributedText += c.text.withFont(font)
            case .relativeDate(let r):
                attributedText += r.text.withFont(font).withBackgroundColor(Color.blue).withTextColor(Color.white)
            case .tag(let t):
                attributedText += t.text.withFont(font).withBackgroundColor(Color.red).withTextColor(Color.white)
            }
        }

        nsView.font = font
        if attributedText.string == text.string {
            nsView.attributedStringValue = attributedText
        } else {
            nsView.attributedStringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator() {
            self.text = $0

            if let action = self.action {
                action($0.string)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        private var setter: (NSAttributedString) -> Void

        init(_ setter: @escaping (NSAttributedString) -> Void) {
            self.setter = setter
        }

        func controlTextDidChange(_ aNotification: Notification) {
            if let textField = aNotification.object as? NSTextField {
                setter(textField.attributedStringValue)
            }
        }
    }
}
