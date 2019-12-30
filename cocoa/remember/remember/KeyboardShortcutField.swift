//
//  KeyboardShortcutField.swift
//  Remember
//
//  Created by Bogdan Popa on 30/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import SwiftUI

final class KeyboardShortcutField: NSViewRepresentable {
    typealias NSViewType = DDHotKeyTextField

    private var handler: ((DDHotKey) -> Void)?

    init(withCompletionHandler handler: @escaping (DDHotKey) -> Void) {
        self.handler = handler
    }

    func makeNSView(context: NSViewRepresentableContext<KeyboardShortcutField>) -> NSViewType {
        return DDHotKeyTextField()
    }

    func updateNSView(_ nsView: NSViewType, context: NSViewRepresentableContext<KeyboardShortcutField>) {
        let defaults = KeyboardShortcutDefaults.load()

        nsView.hotKey = DDHotKey(
            keyCode: defaults.keyCode,
            modifierFlags: defaults.modifierFlags,
            task: { _ in })
        nsView.target = self
        nsView.action = #selector(didChange(_:))
    }

    @objc func didChange(_ sender: DDHotKeyTextField) {
        sender.resignFirstResponder()

        if let handler = self.handler {
            handler(sender.hotKey)
        }
    }
}
