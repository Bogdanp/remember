import SwiftUI
import UIKit

@main
struct Remember: App {
  private let notifications = NotificationsManager.shared
  private let syncer = FolderSyncer.shared

  init() {
    NotificationsManager.shared.registerTasks()
    FolderSyncer.shared.registerTasks()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
