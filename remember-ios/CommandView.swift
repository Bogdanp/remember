import SwiftUI

struct CommandView: View {
  @Environment(\.dismiss) private var dismiss

  @State private var command = ""
  @FocusState private var focused

  var body: some View {
    NavigationView {
      VStack(alignment: .leading) {
        CommandField($command)
          .focused($focused)
          .frame(width: nil, height: 48)
        Spacer()
      }
      .padding()
      .navigationTitle("New Reminder")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") {
            Backend.shared.commit(command: command).onComplete { _ in
              dismiss()
            }
          }
        }
      }
    }.onAppear {
      focused = true
    }
  }
}
