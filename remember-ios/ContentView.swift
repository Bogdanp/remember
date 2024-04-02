import SwiftUI

struct ContentView: View {
  @Environment(\.scenePhase) private var scenePhase
  @ObservedObject private var store = Store()
  @State private var tab = "home"
  @State private var bgTab = "home"
  @State private var presentSheet = false

  var body: some View {
    TabView(selection: $tab) {
      RemindersView(store: store)
        .tabItem { Image(systemName: "house.fill") }
        .tag("home")

      Text("")
        .tabItem { Image(systemName: "plus.app.fill") }
        .tag("new-reminder")

      SettingsView()
        .tabItem { Image(systemName: "gearshape.fill") }
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
        store.invalidate()
        FolderSyncer.shared.invalidate()
        FolderSyncer.shared.scheduleRefresh()
        NotificationsManager.shared.scheduleRefresh()
      case .inactive:
        store.invalidate()
        FolderSyncer.shared.invalidate()
      case .active:
        store.scheduleLoadEntries()
        FolderSyncer.shared.scheduleSync()
        FolderSyncer.shared.unscheduleRefresh()
        NotificationsManager.shared.unscheduleRefresh()
      @unknown default:
        fatalError()
      }
    }
  }
}
