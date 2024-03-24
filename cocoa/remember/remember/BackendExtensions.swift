import Foundation

extension Backend {
  static let shared = Backend(
    withZo: Bundle.main.url(forResource: "res/core-\(ARCH)", withExtension: "zo")!,
    andMod: "main",
    andProc: "main"
  )
}

extension Entry: Identifiable {
  
}
