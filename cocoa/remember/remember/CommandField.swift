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

enum CommandAction {
    case cancel(String)
    case commit(String)
    case archive
    case previous
    case next
}

struct CommandField: NSViewRepresentable {
    typealias NSViewType = NSTextField

    @Binding var text: NSAttributedString
    @Binding var tokens: [Token]

    private let action: (CommandAction) -> Void

    init(_ text: Binding<NSAttributedString>,
         tokens: Binding<[Token]>,
         action theAction: @escaping (CommandAction) -> Void) {
        _text = text
        _tokens = tokens
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
        let systemFont = NSFont.systemFont(ofSize: 24)
        var attributedText = "".withFont(systemFont)
        for token in tokens {
            switch token {
            case .chunk(let c):
                attributedText += c.text
                    .withFont(systemFont)
            case .relativeDateTime(let r):
                attributedText += r.text.withFont(systemFont)
                    .withBackgroundColor(BG_RELATIVE_DATETIME)
                    .withTextColor(Color.white)
            case .tag(let t):
                attributedText += t.text.withFont(systemFont)
                    .withBackgroundColor(BG_TAG)
                    .withTextColor(Color.white)
            }
        }

        nsView.font = systemFont
        if attributedText.string == text.string {
            nsView.attributedStringValue = attributedText
        } else {
            nsView.attributedStringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(action: {
            self.action($0)
        }, setter: {
            self.text = $0
        })
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        private var action: (CommandAction) -> Void
        private var setter: (NSAttributedString) -> Void

        init(action theAction: @escaping (CommandAction) -> Void,
             setter theSetter: @escaping (NSAttributedString) -> Void) {

            action = theAction
            setter = theSetter
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                action(.commit(control.stringValue))
                return true
            } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                action(.cancel(control.stringValue))
                return true
            } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
                action(.previous)
                return true
            } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
                action(.next)
                return true
            } else if commandSelector == #selector(NSResponder.deleteBackward(_:)) && control.stringValue.isEmpty {
                action(.archive)
                return true
            }

            return false
        }

        func controlTextDidChange(_ aNotification: Notification) {
            if let textField = aNotification.object as? NSTextField {
                setter(textField.attributedStringValue)
            }
        }
    }
}
