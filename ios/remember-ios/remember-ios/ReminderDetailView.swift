import NoiseSerde
import SwiftUI

struct ReminderDetailView: View {
  @FocusState private var focused
  @State var command: String
  let action: (String) -> Void

  var body: some View {
    NavigationView {
      VStack(alignment: .leading) {
        TextField("Remember...", text: $command)
          .focused($focused)
        Spacer()
      }
      .padding()
    }
    .toolbar {
      ToolbarItem {
        Button("Done") {
          action(command)
        }
      }
    }
    .onAppear {
      focused = true
    }
  }
}
