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
    private var windowDelegate: NSWindowDelegate = WindowDelegate()

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

        let hostingView = NSHostingView(rootView: contentView)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 0),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.delegate = windowDelegate
        window.collectionBehavior = .canJoinAllSpaces
        window.setFrameAutosaveName("Remember")
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.contentView = hostingView
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.makeKeyAndOrderFront(nil)

        setupHotKey()
        setupHidingListener()
        setupUserNotifications()

        // This serves the same purpose as `windowDidBecomeKey` in `WindowDelegate`.
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        positionWindow()
    }

    func applicationWillResignActive(_ notification: Notification) {
        NSApp.hide(nil)

        // Re-position the window in case it was moved around by the user.  Re-positioning it
        // now prevents it from moving around when the user re-activates the application later.
        positionWindow()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        UserNotificationsManager.shared.dismissAll()
        rpc.shutdown()
    }

    /// Ensures that the window is always positioned in exactly the same spot.  Roughly the same position as Spotlight.
    private func positionWindow() {
        if let screenFrame = window.screen?.frame {
            let screenWidth = screenFrame.size.width
            let screenHeight = screenFrame.size.height

            let x = (screenWidth - window.frame.size.width) / 2
            let y = (screenHeight * 0.80) - window.frame.size.height
            let f = NSRect(x: x, y: y, width: window.frame.size.width, height: window.frame.size.height)

            window.setFrame(f, display: true)
        }
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
        UserNotificationsManager.shared.setup(asyncNotifier: client)
    }

    /// Called whenever the user presses ⌘,
    @IBAction func showPreferences(_ sender: Any) {
        PreferencesManager.shared.show()
    }
}

fileprivate class WindowDelegate: NSObject, NSWindowDelegate {
    // This hack ensures that the application becomes active after being started with Spotlight.
    // It's weird that this would be necessary, but whatevs.  Maybe there's a better way...
    func windowDidBecomeKey(_ notification: Notification) {
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
