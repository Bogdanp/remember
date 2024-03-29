//
//  CustomTextField.swift
//  remember
//
//  Created by Bogdan Popa on 23/12/2019.
//  Copyright © 2019-2024 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import SwiftUI
import SwiftyAttributes

enum CommandAction {
  case update(String)
  case cancel(String)
  case commit(String)
  case archive
  case delete
  case previous
  case next
  case undo
}

struct CommandField: NSViewRepresentable {
  typealias NSViewType = NSTextField

  @Binding var text: NSAttributedString
  @Binding var tokens: [Token]

  private let action: (CommandAction) -> Void

  init(_ text: Binding<NSAttributedString>,
       tokens: Binding<[Token]>,
       action theAction: @escaping (CommandAction) -> Void) {
    _text = text
    _tokens = tokens
    action = theAction
  }

  func makeNSView(context: NSViewRepresentableContext<CommandField>) -> NSViewType {
    let field = CommandTextField()
    field.allowsEditingTextAttributes = true
    field.backgroundColor = NSColor.clear
    field.delegate = context.coordinator
    field.isBordered = false
    field.focusRingType = .none
    field.placeholderString = "Remember"

    field.keyBindings.append(contentsOf: [
      KeyBinding(withKeyCode: Keycode.z, andModifierFlags: [.command], using: #selector(Coordinator.undo(_:))),
    ])

    return field
  }

  func updateNSView(_ nsView: NSViewType, context: NSViewRepresentableContext<CommandField>) {
    let systemFont = NSFont.systemFont(ofSize: 24)
    var attributedText = "".withFont(systemFont)
    for token in tokens {
      switch token.data {
      case nil:
        attributedText += token.text
          .withFont(systemFont)
          .withTextColor(NSColor.textColor)
      case .relativeTime(_, _):
        attributedText += token.text
          .withFont(systemFont)
          .withTextColor(NSColor.systemBlue)
      case .namedDatetime(_):
        attributedText += token.text
          .withFont(systemFont)
          .withTextColor(NSColor.systemBlue)
      case .namedDate(_):
        attributedText += token.text
          .withFont(systemFont)
          .withTextColor(NSColor.systemBlue)
      case .recurrence(_, _):
        attributedText += token.text
          .withFont(systemFont)
          .withTextColor(NSColor.systemGreen)
      case .tag(_):
        attributedText += token.text
          .withFont(systemFont)
          .withTextColor(NSColor.systemPink)
      }
    }

    nsView.font = systemFont
    if attributedText.string == text.string {
      nsView.attributedStringValue = attributedText
    } else {
      nsView.attributedStringValue = text.withFont(systemFont)
    }

    // Become the first responder as soon as the window becomes visible.  Doing this before has no effect.
    // As usual, hacky, but it seems to work.  This seems to be the norm with SwiftUI.
    if nsView.window != nil && !context.coordinator.didBecomeFirstResponder {
      nsView.becomeFirstResponder()
      context.coordinator.didBecomeFirstResponder = true
    }
  }

  func makeCoordinator() -> Coordinator {
    return Coordinator(action: {
      self.action($0)
    }, setter: {
      self.text = $0
    })
  }

  final class Coordinator: NSObject, NSTextFieldDelegate {
    private var action: (CommandAction) -> Void
    private var setter: (NSAttributedString) -> Void

    var didBecomeFirstResponder = false

    init(action theAction: @escaping (CommandAction) -> Void,
         setter theSetter: @escaping (NSAttributedString) -> Void) {

      action = theAction
      setter = theSetter
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
      if commandSelector == #selector(NSResponder.insertNewline(_:)) {
        action(.commit(control.stringValue))
        return true
      } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
        action(.cancel(control.stringValue))
        return true
      } else if commandSelector == #selector(NSResponder.moveUp(_:)) || commandSelector == #selector(NSResponder.insertBacktab(_:)) {
        action(.previous)
        return true
      } else if commandSelector == #selector(NSResponder.moveDown(_:)) || commandSelector == #selector(NSResponder.insertTab(_:)) {
        action(.next)
        return true
      } else if commandSelector == #selector(NSResponder.deleteBackward(_:)) && control.stringValue.isEmpty {
        action(.archive)
        return true
      } else if commandSelector == #selector(NSResponder.deleteWordBackward(_:)) && control.stringValue.isEmpty {
        action(.delete)
        return true
      }

      return false
    }

    @objc func undo(_ sender: NSTextField) {
      if sender.stringValue.isEmpty {
        action(.undo)
      }
    }

    func controlTextDidChange(_ aNotification: Notification) {
      if let textField = aNotification.object as? NSTextField {
        setter(textField.attributedStringValue)
        action(.update(textField.stringValue))
      }
    }
  }
}

fileprivate struct KeyBinding {
  private let keyCode: UInt16
  private let modifierFlags: NSEvent.ModifierFlags

  let selector: Selector

  init(withKeyCode keyCode: UInt16, andModifierFlags modifierFlags: NSEvent.ModifierFlags, using selector: Selector) {
    self.keyCode = keyCode
    self.modifierFlags = modifierFlags
    self.selector = selector
  }

  func matches(_ event: NSEvent) -> Bool {
    return event.keyCode == keyCode &&
    event.modifierFlags.contains(modifierFlags)
  }
}

fileprivate class CommandTextField: NSTextField {
  var keyBindings = [KeyBinding]()

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    for binding in keyBindings {
      if binding.matches(event) {
        return NSApp.sendAction(binding.selector, to: delegate, from: self)
      }
    }

    return super.performKeyEquivalent(with: event)
  }
}
