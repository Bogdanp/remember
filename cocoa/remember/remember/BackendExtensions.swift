import Foundation
import SwiftUI

#if arch(arm64)
let ARCH = "arm64"
#else
let ARCH = "x86_64"
#endif

// - MARK: Backend
extension Backend {
  static let shared = Backend(
    withZo: Bundle.main.url(forResource: "res/core-\(ARCH)", withExtension: "zo")!,
    andMod: "main",
    andProc: "main"
  )
}

// - MARK: Entry
extension Entry: Identifiable {
}

// - MARK: Token
extension Token {
  var color: Color {
    switch self.data {
    case .relativeTime(_, _):
      return .blue
    case .namedDatetime(_):
      return .blue
    case .namedDate(_):
      return .blue
    case .recurrence(_, _):
      return .green
    case .tag(_):
      return .red
    default:
      return .primary
    }
  }

  var range: NSRange {
    return NSRange(
      location: Int(span.lo.offset),
      length: Int(span.hi.offset - span.lo.offset))
  }
}

