//
//  Onboarding.swift
//  Remember
//
//  Created by Bogdan Popa on 21/01/2020.
//  Copyright © 2020 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import SwiftUI

class OnboardingManager: NSObject, NSWindowDelegate {
    static let shared = OnboardingManager()

    private var window: OnboardingWindow!

    private override init() {
        super.init()

        let window = OnboardingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.closable, .titled, .unifiedTitleAndToolbar],
            backing: .buffered,
            defer: false)
        window.delegate = self
        window.title = "Welcome to Remember"

        self.window = window
    }

    func show(force: Bool = false) {
        if (force || !onboardingWasSeen()) {
            self.window.contentView = NSHostingView(rootView: OnboardingView(store: OnboardingStore()))
            self.window.center()
            self.window.makeKeyAndOrderFront(self)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        markOnboardingSeen()
        window.orderOut(self)
        window.contentView = nil
        return false
    }
}

private class OnboardingStore: ObservableObject {
    @Published var currentStep = OnboardingStep1()
}

private struct StepFrame<Content>: View where Content: View {
    private let content: () -> Content

    init(_ content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack {
            content()
            Spacer()
        }
        .padding(25)
        .frame(width: 600, height: nil, alignment: .top)
        .background(Color.white)
        .clipped()
        .shadow(radius: 2)
    }
}

private struct OnboardingStep1: View {
    var body: some View {
        StepFrame {
            Text("Welcome to Remember")
                .font(.largeTitle)
        }
    }
}

private struct OnboardingView: View {
    @ObservedObject var store: OnboardingStore

    var body: some View {
        VStack {
            store.currentStep

            HStack(alignment: .center, spacing: nil) {
                Button(action: {

                }, label: {
                    Text("Continue")
                        .padding(.leading, 20)
                        .padding(.trailing, 20)
                })
            }
            .frame(width: nil, height: 48, alignment: .center)
        }
        .frame(width: 600, height: 600, alignment: .top)
    }
}

private class OnboardingWindow: NSWindow {

}

fileprivate func onboardingWasSeen() -> Bool {
    return UserDefaults.standard.bool(forKey: "onboardingSeen")
}

fileprivate func markOnboardingSeen() {
    UserDefaults.standard.set(true, forKey: "onboardingSeen")
}
