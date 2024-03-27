import SwiftUI

struct ContentView: View {
  @Environment(\.scenePhase) var scenePhase
  @ObservedObject var store = Store()

  @State var tab = "home"
  @State var bgTab = "home"
  @State var presentSheet = false

  var body: some View {
    TabView(selection: $tab) {
      RemindersView(store: store)
        .tabItem {
          Image(systemName: "house.fill")
        }
        .tag("home")

      Text("")
        .tabItem {
          Image(systemName: "plus.app.fill")
        }
        .tag("new-reminder")

      SettingsView()
        .tabItem {
          Image(systemName: "gearshape.fill")
        }
        .tag("settings")
    }
    .sheet(isPresented: $presentSheet, onDismiss: {
      tab = bgTab
    }, content: {
      CommandView()
    })
    .onChange(of: tab) {
      if tab == "new-reminder" {
        presentSheet = true
        tab = bgTab
      } else {
        bgTab = tab
      }
    }
    .onChange(of: scenePhase) {
      switch scenePhase {
      case .background:
        FolderSyncer.shared.invalidate()
        NotificationsManager.shared.scheduleRefresh()
      case .inactive:
        FolderSyncer.shared.invalidate()
      case .active:
        FolderSyncer.shared.scheduleSync()
        NotificationsManager.shared.unscheduleRefresh()
      }
    }
  }
}
