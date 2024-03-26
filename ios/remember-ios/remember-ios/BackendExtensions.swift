import Foundation

extension Backend {
  static let shared = Backend(
    withZo: Bundle.main.url(forResource: "res/core", withExtension: "zo")!,
    andMod: "main",
    andProc: "main"
  )
}

extension Entry: Identifiable {
  var notificationId: String {
    "io.defn.remember-ios.Entry.\(id)"
  }
}
