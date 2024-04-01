import SwiftUI

struct CommandField: UIViewRepresentable {
  typealias UIViewType = CommandTextField

  @Binding var text: String

  init(_ text: Binding<String>) {
    _text = text
  }

  func makeUIView(context: Context) -> CommandTextField {
    let field = CommandTextField()
    field.allowsEditingTextAttributes = true
    field.backgroundColor = UIColor.clear
    field.placeholder = "Remember..."
    field.text = text
    field.addTarget(
      context.coordinator,
      action: #selector(Coordinator.textFieldDidChange(sender:)),
      for: .editingChanged)
    return field
  }

  func updateUIView(_ field: CommandTextField, context: Context) {
    if field.text != text {
      field.text = text
      context.coordinator.scheduleHighlight(forTextField: field)
    }
  }

  func makeCoordinator() -> Coordinator {
    return Coordinator($text)
  }

  final class Coordinator: NSObject {
    @Binding var text: String

    private var timer: Timer?

    init(_ text: Binding<String>) {
      _text = text
    }

    func scheduleHighlight(forTextField field: UITextField) {
      timer?.invalidate()
      timer = .scheduledTimer(withTimeInterval: 1.0/30.0, repeats: false) { _ in
        RunLoop.main.schedule { [weak self] in
          self?.highlight(textField: field)
        }
      }
    }

    func highlight(textField field: UITextField) {
      guard let text = field.text else { return }
      guard let tokens = try? Backend.shared.parse(command: text).wait() else { return }
      let string = NSMutableAttributedString(string: text)
      for token in tokens {
        string.setAttributes(
          [NSAttributedString.Key.foregroundColor: UIColor(token.color)],
          range: token.range)
      }
      field.attributedText = string
    }

    @objc func textFieldDidChange(sender: UITextField) {
      scheduleHighlight(forTextField: sender)
      text = sender.text ?? ""
    }
  }
}

// - MARK: CommandTextField
class CommandTextField: UITextField {
}
