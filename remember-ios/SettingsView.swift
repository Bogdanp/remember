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
          Button(action: {
            UIApplication.shared.open(URL(string: "https://remember.defn.io/manual/")!)
          }, label: {
            Text("Manual")
          })
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
