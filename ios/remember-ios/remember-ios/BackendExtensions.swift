import Foundation

extension Backend {
  static let shared = Backend(
    withZo: Bundle.main.url(forResource: "res/core", withExtension: "zo")!,
    andMod: "main",
    andProc: "main"
  )
}

extension Entry: Hashable, Identifiable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  public static func == (lhs: Entry, rhs: Entry) -> Bool {
    return lhs.id == rhs.id
  }

  var notificationId: String {
    "io.defn.remember-ios.Entry.\(id)"
  }
}
