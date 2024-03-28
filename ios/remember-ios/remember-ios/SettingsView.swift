import SwiftUI

struct SettingsView: View {
  var body: some View {
    NavigationView {
      List {
        Section(content: {
          NavigationLink("Sync") {
            SettingsSyncView()
          }
        }, header: {
          Text("General")
        })

        Section(content: {
          HStack {
            Text("Version")
            Spacer()
            Text("1.0.0")
          }
        }, header: {
          Text("About")
        })
      }
      .navigationTitle("Settings")
    }
  }
}
