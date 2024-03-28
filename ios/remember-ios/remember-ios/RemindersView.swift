import SwiftUI

struct RemindersView: View {
  @ObservedObject var store: Store

  var body: some View {
    VStack(alignment: .leading) {
      Text("Remember")
        .font(.title)
        .fontWeight(.bold)
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
      .listStyle(.plain)
      .refreshable {
        FolderSyncer.shared.sync {
          store.loadEntries()
        }
      }
      .onShake { _ in
        _ = Backend.shared.undo()
      }
    }
    .padding()
  }
}
