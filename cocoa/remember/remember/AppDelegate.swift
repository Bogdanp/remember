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

    var rpc: ComsCenter!
    var client: Client!

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
            entryDB: client,
            parser: client)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 64),
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
        setupHidingListener()
        requestNotificationsAccess()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        rpc.shutdown()
    }

    private func setupHotKey() {
        DDHotKeyCenter.shared()?.registerHotKey(
            withKeyCode: Keycode.space,
            modifierFlags: NSEvent.ModifierFlags.option.rawValue,
            task: { _ in

                if NSApp.isActive {
                    NSApp.hide(nil)
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                }
        })
    }

    private func setupHidingListener() {
        NotificationCenter.default.addObserver(
            forName: .commandDidComplete,
            object: nil,
            queue: nil) { _ in

                NSApp.hide(nil)
        }
    }

    private func requestNotificationsAccess() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: [.alert, .sound], completionHandler: { granted, err in
            if !granted {
                os_log("alert acess not granted", type: .error)
            }
        })
    }
}
