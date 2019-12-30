//
//  KeyboardShortcutDefaults.swift
//  Remember
//
//  Created by Bogdan Popa on 30/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation

struct KeyboardShortcutDefaults: Codable {
    let keyCode: UInt16
    let modifierFlags: UInt

    init(keyCode: UInt16, modifierFlags: UInt) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }

    init(fromHotKey hk: DDHotKey) {
        self.keyCode = hk.keyCode
        self.modifierFlags = hk.modifierFlags
    }

    static func load() -> KeyboardShortcutDefaults {
        if let data = UserDefaults.standard.data(forKey: "keyboardShortcut") {
            return (try? JSONDecoder().decode(KeyboardShortcutDefaults.self, from: data)) ?? `default`()
        }

        return `default`()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "keyboardShortcut")
        }
    }

    static func `default`() -> KeyboardShortcutDefaults {
        KeyboardShortcutDefaults(
            keyCode: Keycode.space,
            modifierFlags: NSEvent.ModifierFlags.option.rawValue)
    }
}
