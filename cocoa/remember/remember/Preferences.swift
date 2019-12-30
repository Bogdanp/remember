//
//  Preferences.swift
//  Remember
//
//  Created by Bogdan Popa on 30/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import SwiftUI

class PreferencesManager: NSObject, NSWindowDelegate {
    static let shared = PreferencesManager()

    private var window: PreferencesWindow!
    private var toolbarDelegate: PreferencesWindowToolbarDelegate!

    private override init() {
        super.init()

        let window = PreferencesWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.closable, .titled, .unifiedTitleAndToolbar],
            backing: .buffered,
            defer: false)
        window.delegate = self
        window.title = "General"

        let toolbar = NSToolbar()
        toolbarDelegate = PreferencesWindowToolbarDelegate()
        toolbar.delegate = toolbarDelegate
        toolbar.selectedItemIdentifier = .general
        window.toolbar = toolbar

        self.window = window
    }

    func show() {
        self.window.contentView = NSHostingView(rootView: GeneralPreferencesView())
        self.window.center()
        self.window.makeKeyAndOrderFront(self)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        self.window.orderOut(self)
        self.window.contentView = nil
        return false
    }
}

private struct GeneralPreferencesView : View {
    @State var shortcut = ""

    var body: some View {
        VStack {
            HStack {
                Text("Test:")
                TextField("Test", text: $shortcut)
            }
            HStack {
                Text("Keyboard Shortcut:")
                KeyboardShortcutField { hk in
                    KeyboardShortcutDefaults(fromHotKey: hk).save()
                }
            }
        }
        .padding(15)
    }
}

private class PreferencesWindow: NSWindow {

}

private class PreferencesWindowToolbarDelegate: NSObject, NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace, .general]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.general]
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.general]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .general:
            let item = NSToolbarItem(itemIdentifier: .general)
            item.target = self
            item.action = #selector(viewSelected(_:))
            item.isEnabled = true
            item.image = NSImage(named: NSImage.preferencesGeneralName)
            item.label = "General"
            return item
        default:
            return nil
        }
    }

    @objc func viewSelected(_ sender: NSToolbarItem) {
    }
}

private extension NSToolbarItem.Identifier {
    static let general = NSToolbarItem.Identifier(rawValue: "General")
}
