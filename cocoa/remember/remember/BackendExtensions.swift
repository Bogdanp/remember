import Foundation

#if arch(arm64)
let ARCH = "arm64"
#else
let ARCH = "x86_64"
#endif

extension Backend {
  static let shared = Backend(
    withZo: Bundle.main.url(forResource: "res/core-\(ARCH)", withExtension: "zo")!,
    andMod: "main",
    andProc: "main"
  )
}

extension Entry: Identifiable {}
