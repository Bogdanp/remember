import SwiftUI

@main
struct Remember: App {
  private var notifications = NotificationsManager.shared

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
