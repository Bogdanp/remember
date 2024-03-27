import SwiftUI
import UIKit

@main
struct Remember: App {
  private var notifications = NotificationsManager.shared

  init() {
    NotificationsManager.shared.registerTasks()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
