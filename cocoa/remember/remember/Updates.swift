//
//  Updates.swift
//  Remember
//
//  Created by Bogdan Popa on 12/01/2020.
//  Copyright © 2020 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import SwiftUI

class UpdatesManager: NSObject, NSWindowDelegate {
    static let shared = UpdatesManager()

    private var window: UpdatesWindow!

    private override init() {
        super.init()

        let window = UpdatesWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 600),
            styleMask: [.closable, .titled],
            backing: .buffered,
            defer: false)
        window.delegate = self
        window.title = "Software Update"
        self.window = window
    }

    func show(withChangelog changelog: String, andVersion version: Version) {
        let updatesView = UpdatesView(changelog: changelog, version: version)
        self.window.contentView = NSHostingView(rootView: updatesView)
        self.window.center()
        self.window.makeKeyAndOrderFront(self)
    }

    func hide() {
        self.window.orderOut(self)
        self.window.contentView = nil
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }
}

fileprivate struct UpdatesView: View {
    let changelog: String
    let version: Version

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image("Icon")
                .resizable()
                .frame(width: 32, height: 32, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text("A new version of Remember is available!").bold()
                Text("Version \(version.version) is now available. Would you like to install it now?")
                Text("Release notes:").bold()
                Changelog(changelog)
                    .frame(width: nil, height: 150, alignment: .top)
                HStack {
                    Spacer()

                    Button(action: {
                        UpdatesManager.shared.hide()
                    }, label: {
                        Text("Remind me Later")
                    })
                        .buttonStyle(BorderedButtonStyle())

                    Button(action: {

                    }, label: {
                        Text("Install Updates")
                    })
                        .buttonStyle(BorderedButtonStyle())
                }
            }
        }
        .padding(16)
    }
}

fileprivate struct Changelog: NSViewRepresentable {
    typealias NSViewType = NSScrollView

    let changelog: String

    init(_ changelog: String) {
        self.changelog = changelog
    }

    func makeNSView(context: NSViewRepresentableContext<Changelog>) -> NSViewType {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        let textView = NSTextView()
        scrollView.addSubview(textView)
        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ nsView: NSViewType, context: NSViewRepresentableContext<Changelog>) {
        nsView.backgroundColor = .white
        nsView.borderType = .lineBorder
        nsView.hasVerticalScroller = true
        nsView.hasHorizontalScroller = true
        nsView.autoresizingMask = [.width, .height]

        let contentSize = nsView.contentSize
        if let textView = nsView.documentView as? NSTextView {
            textView.backgroundColor = .white
            textView.isEditable = false
            textView.isVerticallyResizable = true
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = [.height, .width]
            textView.textContainer?.size = NSMakeSize(contentSize.width, .infinity)
            textView.textContainer?.widthTracksTextView = true
            textView.string = changelog
        }
    }
}

fileprivate class UpdatesWindow: NSWindow {

}
