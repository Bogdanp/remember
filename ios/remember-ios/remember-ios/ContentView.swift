import SwiftUI

struct ContentView: View {
  @ObservedObject var store = Store()

  @State var presentSheet = false

  var body: some View {
    VStack {
      List {
        ForEach(store.entries) { entry in
          HStack {
            Text(entry.title)
            Spacer()
            if let dueIn = entry.dueIn {
              Text(dueIn)
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
          }.swipeActions {
            Button(action: {
              _ = Backend.shared.archive(entryWithId: entry.id)
            }, label: {
              Image(systemName: "checkmark.circle")
            }).tint(.accentColor)
            Button(action: {
              _ = Backend.shared.delete(entryWithId: entry.id)
            }, label: {
              Image(systemName: "trash.slash.fill")
            }).tint(.red)
          }
        }
      }
      HStack {
        Button(action: {
          presentSheet.toggle()
        }, label: {
          Image(systemName: "plus.app")
            .font(.system(size: 24))
        }).sheet(isPresented: $presentSheet, content: {
          CommandView()
            .padding()
        })
      }
    }
    .padding()
  }
}

struct CommandView: View {
  @Environment(\.dismiss) private var dismiss

  @State var command = ""

  var body: some View {
    VStack {
      TextField(text: $command, label: { Text("Remember...") })
      Button(action: {
        if command != "" {
          _ = Backend.shared.commit(command: command)
        }
        dismiss()
      }, label: {
        Text("Save")
      })
    }
  }
}
