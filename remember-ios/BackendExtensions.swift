import Foundation
import SwiftUI

// - MARK: Backend
extension Backend {
  static let shared = Backend(
    withZo: Bundle.main.url(forResource: "res/core", withExtension: "zo")!,
    andMod: "main",
    andProc: "main"
  )
}

// - MARK: Entry
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
