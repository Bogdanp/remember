//
//  AppDelegate.swift
//  remember
//
//  Created by Bogdan Popa on 23/12/2019.
//  Copyright © 2019 CLEARTYPE SRL. All rights reserved.
//

import Cocoa
import Combine
import SwiftUI
import UserNotifications
import os

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    private var rpc: ComsCenter!
    private var client: Client!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard let coreURL = Bundle.main.url(forResource: "core/bin/remember-core", withExtension: nil) else {
            fatalError("failed to find core executable")
        }

        guard let rpc = try? ComsCenter(withCoreURL: coreURL) else {
            fatalError("failed to start core process")
        }

        self.rpc = rpc
        client = Client(rpc)

        let contentView = ContentView(
            asyncNotifier: client,
            entryDB: client,
            parser: client)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 0),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.collectionBehavior = .canJoinAllSpaces
        window.setFrameAutosaveName("Remember")
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.contentView = NSHostingView(rootView: contentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.makeKeyAndOrderFront(nil)

        setupHotKey()
        setupArchivingListener()
        setupSnoozingListener()
        setupHidingListener()
        setupUserNotifications()
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        window.center()
    }

    func applicationDidResignActive(_ notification: Notification) {
        window.center()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        rpc.shutdown()
    }

    private func setupHotKey() {
        KeyboardShortcut.register()
    }

    /// Sets up the global listener for archive events.  This is triggered whenever a user hits "Archive" on a due entry notification.
    private func setupArchivingListener() {
        NotificationCenter.default.addObserver(
            forName: .userDidArchive,
            object: nil,
            queue: nil) { notification in

                if let entryId = notification.object as? UInt32 {
                    self.client.archiveEntry(byId: entryId) { }
                }
        }
    }

    /// Sets up the global listener for snooze events.  This is triggered whenever a user hits "Close" on a due entry notification.
    private func setupSnoozingListener() {
        NotificationCenter.default.addObserver(
            forName: .userDidSnooze,
            object: nil,
            queue: nil) { notification in

                if let entryId = notification.object as? UInt32 {
                    self.client.snoozeEntry(byId: entryId) { }
                }
        }
    }

    /// Sets up the global hiding listener.  This is triggered whenever the user intends to hide the window.
    private func setupHidingListener() {
        NotificationCenter.default.addObserver(
            forName: .commandDidComplete,
            object: nil,
            queue: nil) { _ in

                NSApp.hide(nil)
        }
    }

    /// Sets up access to the notification center and installs an async notification listener to handle `entries-due` events.
    private func setupUserNotifications() {
        UserNotificationsManager.shared.setup(asyncNotifier: client)
    }

    /// Called whenever the user presses ⌘,
    @IBAction func showPreferences(_ sender: Any) {
        PreferencesManager.shared.show()
    }
}
