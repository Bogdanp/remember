//
//  KeyboardShortcutField.swift
//  Remember
//
//  Created by Bogdan Popa on 30/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import SwiftUI

struct KeyboardShortcutField: NSViewRepresentable {
    typealias NSViewType = DDHotKeyTextField

    func makeNSView(context: NSViewRepresentableContext<KeyboardShortcutField>) -> NSViewType {
        return DDHotKeyTextField()
    }

    func updateNSView(_ nsView: NSViewType, context: NSViewRepresentableContext<KeyboardShortcutField>) {
        let defaults = KeyboardShortcutDefaults.load()

        nsView.hotKey = DDHotKey(
            keyCode: defaults.keyCode,
            modifierFlags: defaults.modifierFlags,
            task: { _ in })
        nsView.target = NSApplication.shared.delegate
        nsView.action = #selector(AppDelegate.didChangeHotKey(_:))
    }
}
