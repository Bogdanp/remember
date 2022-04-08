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
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 600),
            styleMask: [.titled],
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

    func hide() {
        markOnboardingSeen()
        window.orderOut(self)
        window.contentView = nil
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }
}

fileprivate enum Step {
    case one
    case two
}

fileprivate class OnboardingStore: ObservableObject {
    @Published var currentStep = Step.one

    func `continue`() {
        switch currentStep {
        case .one:
            currentStep = .two
        case .two:
            OnboardingManager.shared.hide()
        }
    }
}

fileprivate struct StepFrame<Content>: View where Content: View {
    @Environment(\.colorScheme) var colorScheme

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
        .background(colorScheme == .dark ? Color.black : Color.white)
        .clipped()
        .shadow(radius: 2)
    }
}

fileprivate struct Pill<Content>: View where Content: View {
    @Environment(\.colorScheme) var colorScheme

    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack {
            content()
        }
        .padding(10)
        .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.05))
        .cornerRadius(5)
    }
}

fileprivate struct OnboardingStep1: View {
    var body: some View {
        StepFrame {
            VStack {
                Text("Welcome to Remember")
                    .font(.largeTitle)
                Text("Stash distractions away for later.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                VStack(alignment: .center, spacing: 10) {
                    Pill {
                        Text("Remember is a keyboard-driven application.  To activate or de-activate it, you can press ") +
                            Text(KeyboardShortcutDefaults.asString()).bold() +
                            Text(" at any time.")
                    }

                    Pill {
                        HStack {
                            Text("When the application is active, you can add entries like ") +
                                Text("buy milk").bold() +
                                Text(" and press ") +
                                Text("return").bold() +
                                Text(" to save them.")

                            Image("OnboardingStep1-1")
                                .resizable()
                                .frame(width: 258, height: 64, alignment: .center)
                        }
                    }

                    Pill {
                        HStack {
                            Image("OnboardingStep1-2")
                                .resizable()
                                .frame(width: 258, height: 64, alignment: .center)
                            Text("Entries can contain modifiers like ") +
                                Text("+1d").foregroundColor(.accentColor) +
                                Text(" or ") +
                                Text("@10am").foregroundColor(.accentColor) +
                                Text(" that tell Remember when it should remind you about them.")
                        }
                    }

                    Pill {
                        HStack {
                            Text("You can use the arrow keys to navigate through your pending entries and ") +
                                Text("⌫").bold() +
                                Text(" to archive any of the ones you're done with.")

                            Image("OnboardingStep1-3")
                                .resizable()
                                .frame(width: 335, height: 128, alignment: .center)
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 10)
            }
        }
    }
}

fileprivate struct OnboardingStep2: View {
    var body: some View {
        StepFrame {
            VStack {
                Spacer()

                VStack(alignment: .center, spacing: 10) {
                    Pill {
                        VStack {
                            HStack {
                                (
                                    Text("You can create repeating entries by using modifiers like ") +
                                    Text("\\*daily\\*").foregroundColor(.green) +
                                    Text(", ") +
                                    Text("\\*weekly\\*").foregroundColor(.green) +
                                    Text(" or ") +
                                    Text("\\*every two days\\*").foregroundColor(.green) +
                                    Text(".  These entries update their due date whenever you archive them.")
                                )
                                .frame(width: nil, height: 88, alignment: .leading)
                                .lineLimit(nil)

                                Image("OnboardingStep2-1")
                                    .resizable()
                                    .frame(width: 258.5, height: 64, alignment: .center)
                            }

                            Image("OnboardingStep2-2")
                                .resizable()
                                .frame(width: 301, height: 128, alignment: .center)
                        }
                    }

                    Pill {
                        Text("Press ") +
                            Text("⌘,").bold() +
                            Text(" to bring up the Preferences window where you can change the default key binding and make Remember launch at login.")
                    }

                    Pill {
                        Text("Press ") +
                            Text("⌘/").bold() +
                            Text(" to go through this guide again whenever you need a refresher on how Remember works.")
                    }

                    Pill {
                        Text("I sincerely hope you'll find Remember to be a useful addition to your workflow!")
                    }
                }

                Spacer()
            }
        }
    }
}

fileprivate struct OnboardingView: View {
    @ObservedObject var store: OnboardingStore

    var body: some View {
        VStack {
            if store.currentStep == .one {
                OnboardingStep1()
            } else if store.currentStep == .two {
                OnboardingStep2()
            }

            HStack(alignment: .center, spacing: nil) {
                Button(action: {
                    self.store.continue()
                }, label: {
                    Text(store.currentStep == .one ? "Continue" : "Get Started")
                        .padding(.leading, 20)
                        .padding(.trailing, 20)
                })
            }
            .frame(width: nil, height: 48, alignment: .center)
        }
        .frame(width: 600, height: 600, alignment: .top)
    }
}

fileprivate class OnboardingWindow: NSWindow {

}

fileprivate func onboardingWasSeen() -> Bool {
    return UserDefaults.standard.bool(forKey: "onboardingSeen")
}

fileprivate func markOnboardingSeen() {
    UserDefaults.standard.set(true, forKey: "onboardingSeen")
}
