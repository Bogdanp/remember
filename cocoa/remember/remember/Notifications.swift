//
//  Notifications.swift
//  remember
//
//  Created by Bogdan Popa on 27/12/2019.
//  Copyright © 2019-2024 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import NoiseSerde

struct Notifications {
  private static func observe(_ name: NSNotification.Name, using handler: @escaping (Notification) -> Void) {
    NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil, using: handler)
  }

  static func didToggleStatusItem(show: Bool) {
    NotificationCenter.default.post(
      name: .didToggleStatusItem,
      object: show)
  }

  static func observeDidToggleStatusItem(withCompletionHandler handler: @escaping (Bool) -> Void) {
    observe(.didToggleStatusItem) { notification in
      if let show = notification.object as? Bool {
        handler(show)
      }
    }
  }

  static func didRequestSync() {
    NotificationCenter.default.post(
      name: .didRequestSync,
      object: nil)
  }

  static func observeDidRequestSync(withCompletionHandler handler: @escaping () -> Void) {
    observe(.didRequestSync) { notification in
      handler()
    }
  }

  static func willHideWindow() {
    NotificationCenter.default.post(
      name: .willHideWindow,
      object: nil)
  }

  static func observeWillHideWindow(withCompletionHandler handler: @escaping () -> Void) {
    observe(.willHideWindow) { _ in
      handler()
    }
  }

  static func willArchiveEntry(entryId: UVarint) {
    NotificationCenter.default.post(
      name: .willArchiveEntry,
      object: entryId)
  }

  static func observeWillArchiveEntry(withCompletionHandler handler: @escaping (UVarint) -> Void) {
    observe(.willArchiveEntry) { notification in
      if let id = notification.object as? UVarint {
        handler(id)
      }
    }
  }

  static func willSelectEntry(entryId: UVarint) {
    NotificationCenter.default.post(
      name: .willSelectEntry,
      object: entryId)
  }

  static func observeWillSelectEntry(withCompletionHandler handler: @escaping (UVarint) -> Void) {
    observe(.willSelectEntry) { notification in
      if let id = notification.object as? UVarint {
        handler(id)
      }
    }
  }

  static func willSnoozeEntry(entryId: UVarint) {
    NotificationCenter.default.post(
      name: .willSnoozeEntry,
      object: entryId)
  }

  static func observeWillSnoozeEntry(withCompletionHandler handler: @escaping (UVarint) -> Void) {
    observe(.willSnoozeEntry) { notification in
      if let id = notification.object as? UVarint {
        handler(id)
      }
    }
  }
}

extension Notification.Name {
  static let didToggleStatusItem = Notification.Name("io.defn.remember.didToggleStatusItem")
  static let didRequestSync = Notification.Name("io.defn.remember.didRequestSync")
  static let willHideWindow = Notification.Name("io.defn.remember.willHideWindow")
  static let willArchiveEntry = Notification.Name("io.defn.remember.willArchiveEntry")
  static let willSelectEntry = Notification.Name("io.defn.remember.willSelectEntry")
  static let willSnoozeEntry = Notification.Name("io.defn.remember.willSnoozeEntry")
}
