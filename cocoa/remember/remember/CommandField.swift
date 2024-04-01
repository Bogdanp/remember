//
//  CustomTextField.swift
//  remember
//
//  Created by Bogdan Popa on 23/12/2019.
//  Copyright © 2019-2024 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import SwiftUI

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

  @Binding var text: String

  private let action: (CommandAction) -> Void

  init(_ text: Binding<String>,
       action theAction: @escaping (CommandAction) -> Void) {
    _text = text
    action = theAction
  }

  func makeNSView(context: NSViewRepresentableContext<CommandField>) -> NSViewType {
    let field = CommandTextField()
    field.allowsEditingTextAttributes = true
    field.backgroundColor = NSColor.clear
    field.delegate = context.coordinator
    field.font = .systemFont(ofSize: 24)
    field.isBordered = false
    field.focusRingType = .none
    field.placeholderString = "Remember"

    field.keyBindings.append(contentsOf: [
      KeyBinding(withKeyCode: Keycode.z, andModifierFlags: [.command], using: #selector(Coordinator.undo(_:))),
    ])

    return field
  }

  func updateNSView(_ nsView: NSViewType, context: NSViewRepresentableContext<CommandField>) {
    nsView.stringValue = text
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
    private var setter: (String) -> Void
    private var timer: Timer?

    var didBecomeFirstResponder = false

    init(action: @escaping (CommandAction) -> Void,
         setter: @escaping (String) -> Void) {

      self.action = action
      self.setter = setter
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

    func scheduleHighlight(ofTextField field: NSTextField) {
      timer?.invalidate()
      timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: false) { [weak self] _ in
        self?.highlight(textField: field)
      }
    }

    func highlight(textField field: NSTextField) {
      guard !field.stringValue.isEmpty else { return }
      guard let tokens = try? Backend.shared.parse(command: field.stringValue).wait() else { return }
      let systemFont = NSFont.systemFont(ofSize: 24)
      let attributedText = NSMutableAttributedString(string: field.stringValue)
      attributedText.beginEditing()
      attributedText.setAttributes(
        [NSAttributedString.Key.font: systemFont],
        range: NSRange(location: 0, length: attributedText.length))
      for token in tokens {
        attributedText.addAttribute(
          .foregroundColor,
          value: NSColor(token.color),
          range: token.range)
      }
      attributedText.endEditing()
      field.attributedStringValue = attributedText
    }

    func controlTextDidChange(_ aNotification: Notification) {
      if let textField = aNotification.object as? NSTextField {
        setter(textField.stringValue)
        action(.update(textField.stringValue))
        scheduleHighlight(ofTextField: textField)
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
