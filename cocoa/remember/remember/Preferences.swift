//
//  Preferences.swift
//  Remember
//
//  Created by Bogdan Popa on 30/12/2019.
//  Copyright © 2019-2024 CLEARTYPE SRL. All rights reserved.
//

import Combine
import Foundation
import LaunchAtLogin
import SwiftUI

class PreferencesManager: NSObject, NSWindowDelegate {
  static let shared = PreferencesManager()

  private var window: PreferencesWindow!
  private var toolbarDelegate: PreferencesWindowToolbarDelegate!

  private override init() {
    super.init()

    let window = PreferencesWindow(
      contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
      styleMask: [.closable, .titled],
      backing: .buffered,
      defer: false)
    window.delegate = self
    window.title = "General"

    let toolbar = NSToolbar()
    toolbarDelegate = PreferencesWindowToolbarDelegate()
    toolbar.delegate = toolbarDelegate
    toolbar.selectedItemIdentifier = .general
    window.toolbar = toolbar
    if #available(macOS 11, *) {
      window.toolbarStyle = .preference
    }

    self.window = window
  }

  func show() {
    self.window.contentView = NSHostingView(rootView: GeneralPreferencesView())
    self.window.center()
    self.window.makeKeyAndOrderFront(self)
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    KeyboardShortcut.register()
    self.window.orderOut(self)
    self.window.contentView = nil
    return false
  }
}

private struct GeneralPreferencesView : View {
  @ObservedObject var store = PreferencesStore()

  let formatter: NumberFormatter = {
    let fmt = NumberFormatter()
    fmt.minimum = 1
    fmt.maximum = 1440
    return fmt
  }()

  var body: some View {
    Form {
      Section {
        VStack {
          Preference("Startup:") {
            Toggle("Launch Remember at Login", isOn: $store.launchAtLogin)
          }
          Preference("Behavior:") {
            Toggle("Show Menu Bar Icon", isOn: $store.showStatusIcon)
          }
          Preference("Snooze minutes:") {
            TextField("", value: $store.snoozeMinutes, formatter: formatter)
              .frame(width: 300, height: nil, alignment: .leading)
              .offset(x: -8, y: 0)
          }
          Preference("Show Remember:") {
            KeyboardShortcutField()
          }
          .padding([.top, .bottom], 10)
          Preference("Sync:") {
            VStack(alignment: .leading, spacing: nil) {
              if let url = self.store.syncFolder {
                Text(url.relativePath)
                  .foregroundColor(.secondary)
              }

              HStack {
                Button(action: {
                  let panel = NSOpenPanel()
                  panel.prompt = "Set Sync Folder"
                  panel.allowsMultipleSelection = false
                  panel.canChooseFiles = false
                  panel.canChooseDirectories = true
                  panel.canCreateDirectories = true

                  if panel.runModal() == .OK {
                    self.store.syncFolder = panel.urls[0]
                  }
                }, label: {
                  Text("Set Sync Folder...")
                })

                if self.store.syncFolder != nil {
                  Button(action: {
                    self.store.syncFolder = nil
                  }, label: {
                    Text("Stop Syncing")
                  })
                  Button(action: {
                    Notifications.didRequestSync()
                  }, label: {
                    Text("Sync")
                  })
                }
              }
            }
          }
        }
      }
    }
    .padding(15)
  }
}

private class PreferencesStore: NSObject, ObservableObject {
  @Published var launchAtLogin = LaunchAtLogin.isEnabled
  @Published var showStatusIcon = StatusItemDefaults.shouldShow()
  @Published var snoozeMinutes = SnoozeDefaults.get()
  @Published var syncFolder = try! FolderSyncDefaults.load()

  private var launchAtLoginCancellable: AnyCancellable?
  private var showStatusIconCancellable: AnyCancellable?
  private var snoozeMinutesCancelable: AnyCancellable?
  private var syncFolderCancellable: AnyCancellable?

  override init() {
    super.init()

    launchAtLoginCancellable = $launchAtLogin.sink {
      LaunchAtLogin.isEnabled = $0
    }

    showStatusIconCancellable = $showStatusIcon.sink {
      Notifications.didToggleStatusItem(show: $0)
    }

    snoozeMinutesCancelable = $snoozeMinutes.sink {
      try! SnoozeDefaults.set($0)
    }

    syncFolderCancellable = $syncFolder.sink {
      if let path = $0 {
        if path.startAccessingSecurityScopedResource() {
          defer {
            path.stopAccessingSecurityScopedResource()
          }

          try! FolderSyncDefaults.save(path: path)
        }
      } else {
        FolderSyncDefaults.clear()
      }
    }
  }
}

private struct Preference<Content: View> : View {
  private let label: String
  private let content: Content

  init(_ label: String, @ViewBuilder content: () -> Content) {
    self.label = label
    self.content = content()
  }

  var body: some View {
    HStack(alignment: .top, spacing: nil) {
      Text(label)
        .frame(width: 150, height: nil, alignment: .trailing)
      content
    }
    .frame(width: 450, height: nil, alignment: .leading)
  }
}

private class PreferencesWindow: NSWindow {

}

private class PreferencesWindowToolbarDelegate: NSObject, NSToolbarDelegate {
  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    return [.general]
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
