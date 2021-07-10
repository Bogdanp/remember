//
//  Snooze.swift
//  Remember
//
//  Created by Bogdan Popa on 10.07.2021.
//  Copyright © 2021 CLEARTYPE SRL. All rights reserved.
//

import Foundation

enum SnoozeError: Error {
    case invalidMinutes
}

class SnoozeDefaults {
    private static let KEY = "snoozeMinutes"
    private static let DEFAULT = 45

    static func get() -> Int {
        let minutes = UserDefaults.standard.integer(forKey: KEY)
        if minutes == 0 {
            return DEFAULT
        }
        return minutes
    }

    static func set(_ minutes: Int) throws {
        if (minutes <= 0) {
            throw SnoozeError.invalidMinutes
        }
        UserDefaults.standard.setValue(minutes, forKey: KEY)
    }
}
