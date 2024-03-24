//
//  AppDelegate.swift
//  remember
//
//  Created by Bogdan Popa on 23/12/2019.
//  Copyright © 2019-2024 CLEARTYPE SRL. All rights reserved.
//

import Cocoa
import Combine
import SwiftUI
import UserNotifications
import os

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  var window: NSWindow!

  private var statusItem: NSStatusItem?

  private var updater: AutoUpdater!
  private var syncer: FolderSyncer!

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    updater = AutoUpdater()
    updater.start(withInterval: 3600 * 4) { changes, version in
      RunLoop.main.schedule {
        UpdatesManager.shared.show(withChangelog: changes, andRelease: version)
      }
    }

    syncer = FolderSyncer()
    syncer.start()

    let contentView = ContentView()
    let hostingView = NSHostingView(rootView: contentView)

    window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 680, height: 0),
      styleMask: [.titled, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.collectionBehavior = .moveToActiveSpace
    window.backgroundColor = .clear
    window.isMovableByWindowBackground = true
    window.isOpaque = false
    window.contentView = hostingView
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.styleMask = [.titled, .fullSizeContentView]

    setupStatusItem()
    setupHotKey()
    setupHidingListener()
    setupUserNotifications()

    // This serves the same purpose as `windowDidBecomeKey` in `WindowDelegate`.
    if !NSApp.isActive {
      NSApp.activate(ignoringOtherApps: true)
    }

    OnboardingManager.shared.show()
  }

  func applicationWillBecomeActive(_ notification: Notification) {
    positionWindow()
    window.makeKeyAndOrderFront(nil)
  }

  func applicationWillResignActive(_ notification: Notification) {
    NSApp.hide(nil)

    // Re-position the window in case it was moved around by the user.  Re-positioning it
    // now prevents it from moving around when the user re-activates the application later.
    positionWindow()
  }

  func applicationWillTerminate(_ aNotification: Notification) {
    UserNotificationsManager.shared.dismissAll()
  }

  /// Ensures that the window is always positioned in exactly the same spot.  Roughly the same position as Spotlight.
  private func positionWindow() {
    if let screenFrame = NSScreen.main?.visibleFrame {
      let screenWidth = screenFrame.size.width
      let screenHeight = screenFrame.size.height

      let x = (screenWidth - window.frame.size.width) / 2
      let y = (screenHeight * 0.80) - window.frame.size.height
      let f = NSRect(x: x, y: y, width: window.frame.size.width, height: window.frame.size.height)
        .offsetBy(dx: screenFrame.origin.x, dy: screenFrame.origin.y)

      window.setFrame(f, display: true)
    }
  }

  private func setupStatusItem() {
    if StatusItemDefaults.shouldShow() {
      showStatusItem()
    }

    Notifications.observeDidToggleStatusItem { show in
      if show {
        StatusItemDefaults.show()
        self.showStatusItem()
      } else {
        StatusItemDefaults.hide()
        self.hideStatusItem()
      }
    }
  }

  private func showStatusItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = statusItem?.button {
      let icon = NSImage(named: NSImage.Name("StatusBarIcon"))
      icon?.isTemplate = true
      button.image = icon
      button.action = nil
    }

    let menu = NSMenu()
    menu.addItem(NSMenuItem(title: "Show Remember", action: #selector(showApplicationFromStatusItem(_:)), keyEquivalent: ""))
    menu.addItem(NSMenuItem.separator())
    menu.addItem(NSMenuItem(title: "Help...", action: #selector(showHelpFromStatusItem(_:)), keyEquivalent: ""))
    menu.addItem(NSMenuItem(title: "Manual...", action: #selector(showManualFromStatusItem(_:)), keyEquivalent: ""))
    menu.addItem(NSMenuItem.separator())
    menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferencesFromStatusItem(_:)), keyEquivalent: ","))
    menu.addItem(NSMenuItem.separator())
    menu.addItem(NSMenuItem(title: "Quit Remember", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    statusItem?.menu = menu
  }

  private func hideStatusItem() {
    if let item = statusItem {
      NSStatusBar.system.removeStatusItem(item)
    }
  }

  @objc private func showApplicationFromStatusItem(_ sender: Any) {
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc private func showHelpFromStatusItem(_ sender: Any) {
    NSApp.activate(ignoringOtherApps: true)
    showHelp(sender)
  }

  @objc private func showManualFromStatusItem(_ sender: Any) {
    if let url = Bundle.main.url(forResource: "res/manual/index", withExtension: "html") {
      NSWorkspace.shared.open(url)
    }
  }

  @objc private func showPreferencesFromStatusItem(_ sender: Any) {
    NSApp.activate(ignoringOtherApps: true)
    showPreferences(sender)
  }

  private func setupHotKey() {
    KeyboardShortcut.register()
  }

  /// Sets up the global hiding listener.  This is triggered whenever the user intends to hide the window.
  private func setupHidingListener() {
    Notifications.observeWillHideWindow {
      NSApp.hide(nil)
    }
  }

  /// Sets up access to the notification center and installs an async notification listener to handle `entries-due` events.
  private func setupUserNotifications() {
    UserNotificationsManager.shared.setup()
  }

  /// Called whenever the user presses ⌘,
  @IBAction func showPreferences(_ sender: Any) {
    PreferencesManager.shared.show()
  }

  /// Called whenever the user presses ⌘?
  @IBAction func showHelp(_ sender: Any) {
    OnboardingManager.shared.show(force: true)
  }

  /// Called whenever the global hot key changes.
  @objc func didChangeHotKey(_ sender: DDHotKeyTextField) {
    KeyboardShortcutDefaults(fromHotKey: sender.hotKey).save()
  }
}
