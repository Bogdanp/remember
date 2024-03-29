//
//  KeyboardShortcut.swift
//  Remember
//
//  Created by Bogdan Popa on 30/12/2019.
//  Copyright © 2019-2024 CLEARTYPE SRL. All rights reserved.
//

import Foundation

class KeyboardShortcut {
  static func register() {
    let defaults = KeyboardShortcutDefaults.load()

    DDHotKeyCenter.shared()?.registerHotKey(
      withKeyCode: defaults.keyCode,
      modifierFlags: defaults.modifierFlags,
      task: { _ in

        if NSApp.isActive {
          Notifications.willHideWindow()
        } else {
          NSApp.activate(ignoringOtherApps: true)
        }
      })
  }
}
