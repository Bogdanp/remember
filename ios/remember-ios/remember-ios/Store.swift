import Foundation
import SwiftUI

class Store: ObservableObject {
  @Published var entries = [Entry]()

  init() {
    load()
    Backend.shared.installCallback(entriesDidChangeCb: { [weak self] _ in
      self?.load()
    }).onComplete {
      _ = Backend.shared.markReadyForChanges()
    }
  }

  private func load() {
    Backend.shared.getPendingEntries().onComplete { [weak self] entries in
      self?.entries = entries
    }
  }
}
