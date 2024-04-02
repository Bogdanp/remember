import NoiseSerde
import SwiftUI

struct ReminderDetailView: View {
  @FocusState private var focused
  @State var command: String
  let action: (String) -> Void

  var body: some View {
    NavigationView {
      VStack(alignment: .leading) {
        CommandField($command)
          .focused($focused)
          .frame(width: nil, height: 48)
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
