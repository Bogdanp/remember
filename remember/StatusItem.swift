//
//  StatusItem.swift
//  Remember
//
//  Created by Bogdan Popa on 24/01/2020.
//  Copyright © 2020-2024 CLEARTYPE SRL. All rights reserved.
//

import Foundation

class StatusItemDefaults {
  private static let KEY = "hideStatusItem"

  static func shouldShow() -> Bool {
    return !UserDefaults.standard.bool(forKey: KEY)
  }

  static func hide() {
    UserDefaults.standard.set(true, forKey: KEY)
  }

  static func show() {
    UserDefaults.standard.set(false, forKey: KEY)
  }
}
