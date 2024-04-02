import SwiftUI
import os

fileprivate let logger = Logger(
  subsystem: "io.defn.remember-ios",
  category: "SettingsSyncView"
)

struct SettingsSyncView: View {
  @State var sync = (try? FolderSyncDefaults.load()) != nil
  @State var presentFileImporter = false

  var body: some View {
    List {
      Section {
        Toggle(isOn: $sync, label: {
          Text("Sync")
        }).disabled(!sync)
        Button {
          presentFileImporter.toggle()
        } label: {
          Text("Select Folder...")
        }.fileImporter(
          isPresented: $presentFileImporter,
          allowedContentTypes: [.folder]
        ) { result in
          switch result {
          case .failure(_):
            FolderSyncDefaults.clear()
            sync = false
          case .success(let url):
            do {
              try FolderSyncDefaults.save(path: url)
              sync = true
            } catch {
              logger.error("Failed to save sync folder defaults: \(error)")
            }
          }
        }
      }
    }
    .navigationTitle("Sync")
    .navigationBarTitleDisplayMode(.inline)
  }
}


class FolderSyncDefaults {
  private static let KEY = "sync.folder"

  static func load() throws -> URL? {
    return try UserDefaults.standard.data(forKey: KEY).flatMap { d in
      var isStale = false
      let url = try URL(
        resolvingBookmarkData: d,
        bookmarkDataIsStale: &isStale)
      if isStale {
        return nil
      }

      return url
    }
  }

  static func save(path: URL) throws {
    guard path.startAccessingSecurityScopedResource() else {
      logger.error("Failed to access security scoped resource.")
      return
    }
    defer { path.stopAccessingSecurityScopedResource() }
    let bookmark = try path.bookmarkData(
      options: [.minimalBookmark],
      includingResourceValuesForKeys: nil,
      relativeTo: nil)
    UserDefaults.standard.setValue(bookmark, forKey: KEY)
  }

  static func clear() {
    UserDefaults.standard.removeObject(forKey: KEY)
  }
}
