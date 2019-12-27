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

fileprivate let BG_RELATIVE_DATE = hexColor(rgb: "21262d")!
fileprivate let BG_TAG = hexColor(rgb: "4c88f2")!

struct CommandField: NSViewRepresentable {
    typealias NSViewType = NSTextField

    @Binding var text: NSAttributedString
    @Binding var tokens: [Token]

    init(_ text: Binding<NSAttributedString>, tokens: Binding<[Token]>) {
        _text = text
        _tokens = tokens
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
            case .relativeDate(let r):
                attributedText += r.text.withFont(systemFont)
                    .withBackgroundColor(BG_RELATIVE_DATE)
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
        return Coordinator() {
            self.text = $0
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

fileprivate func hexColor(rgb: String) -> NSColor? {
    guard let n = UInt32(rgb, radix: 16) else {
        return nil
    }

    let r = CGFloat((n & 0xFF0000) >> 16) / 255.0
    let g = CGFloat((n & 0x00FF00) >>  8) / 255.0
    let b = CGFloat((n & 0x0000FF))       / 255.0
    return NSColor(red: r, green: g, blue: b, alpha: 1.0)
}
