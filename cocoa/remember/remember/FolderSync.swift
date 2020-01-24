//
//  FolderSync.swift
//  Remember
//
//  Created by Bogdan Popa on 24/01/2020.
//  Copyright © 2020 CLEARTYPE SRL. All rights reserved.
//

import Foundation

class FolderSyncDefaults {
    private static let KEY = "sync"

    static func load() -> URL? {
        return UserDefaults.standard.url(forKey: KEY)
    }

    static func save(path: URL) {
        UserDefaults.standard.set(path, forKey: KEY)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: KEY)
    }
}
