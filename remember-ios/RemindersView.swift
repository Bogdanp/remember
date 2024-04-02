import SwiftUI

struct RemindersView: View {
  @ObservedObject var store: Store

  @State private var loaded = false
  @State private var path = [Entry]()

  var body: some View {
    NavigationStack(path: $path) {
      if !loaded {
        ProgressView()
          .padding()
      }
      List {
        ForEach(store.entries) { entry in
          NavigationLink(value: entry) {
            Reminder(
              store: store,
              entry: entry
            )
          }
        }
      }
      .listStyle(.plain)
      .navigationTitle("Remember")
      .navigationDestination(for: Entry.self) { entry in
        ReminderDetailView(command: entry.title) { command in
          store.update(entry: entry, withCommand: command) {
            RunLoop.main.schedule {
              path = []
            }
          }
        }
        .navigationTitle("Edit Reminder")
        .navigationBarTitleDisplayMode(.inline)
      }
      .refreshable {
        FolderSyncer.shared.sync {
          store.loadEntries()
        }
      }
      .onShake { _ in
        _ = Backend.shared.undo()
      }
      .onAppear {
        if !loaded {
          Backend.shared.ping().onComplete { _ in
            RunLoop.main.schedule {
              loaded = true
            }
          }
        }
      }
    }
  }
}

fileprivate struct Reminder: View {
  @ObservedObject var store: Store
  let entry: Entry

  var body: some View {
    HStack {
      Text(entry.title)
      Spacer()
      if let dueIn = entry.dueIn {
        Text(dueIn)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .swipeActions(edge: .leading) {
      Button(action: {
        store.snooze(entry: entry)
      }, label: {
        Label("Snooze", systemImage: "bell.slash.fill")
      }).tint(.secondary)
    }
    .swipeActions(edge: .trailing) {
      Button(action: {
        store.archive(entry: entry)
      }, label: {
        Label("Archive", systemImage: "checkmark.circle")
      }).tint(.accentColor)
      Button(role: .destructive, action: {
        store.delete(entry: entry)
      }, label: {
        Label("Delete", systemImage: "trash.slash.fill")
      }).tint(.red)
    }
  }
}
