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

fileprivate let BG_RELATIVE_DATETIME = hexColor(rgb: "21262d")!
fileprivate let BG_TAG = hexColor(rgb: "4c88f2")!

enum CommandAction {
    case cancel(String)
    case commit(String)
    case previous
    case next
}

struct CommandField: NSViewRepresentable {
    typealias NSViewType = NSTextField

    @Binding var text: NSAttributedString
    @Binding var tokens: [Token]
    @Binding var isEditable: Bool

    private let action: (CommandAction) -> Void

    init(_ text: Binding<NSAttributedString>,
         tokens: Binding<[Token]>,
         isEditable: Binding<Bool>,
         action theAction: @escaping (CommandAction) -> Void) {
        _text = text
        _tokens = tokens
        _isEditable = isEditable
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
        nsView.isEditable = isEditable
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

fileprivate func hexColor(rgb: String) -> NSColor? {
    guard let n = UInt32(rgb, radix: 16) else {
        return nil
    }

    let r = CGFloat((n & 0xFF0000) >> 16) / 255.0
    let g = CGFloat((n & 0x00FF00) >>  8) / 255.0
    let b = CGFloat((n & 0x0000FF))       / 255.0
    return NSColor(red: r, green: g, blue: b, alpha: 1.0)
}
