//
//  FolderSync.swift
//  Remember
//
//  Created by Bogdan Popa on 24/01/2020.
//  Copyright © 2020 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import os

class FolderSyncer {
    let entryDB: EntryDB

    private var timer: Timer?

    init(withEntryDB entryDB: EntryDB) {
        self.entryDB = entryDB
    }

    func start() {
        if let t = timer {
            t.invalidate()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { _ in
            self.sync()
        }
        sync()
    }

    private func sync() {
        do {
            if let path = try FolderSyncDefaults.load() {
                self.entryDB.createDatabaseCopy { tempPath in
                    let manager = FileManager.default
                    if path.startAccessingSecurityScopedResource() {
                        defer {
                            path.stopAccessingSecurityScopedResource()
                        }

                        do {
                            let destURL = path.appendingPathComponent("\(self.syncId()).sqlite3")
                            let sourceURL = URL(fileURLWithPath: tempPath.absoluteString)
                            if manager.fileExists(atPath: destURL.relativePath) {
                                try manager.removeItem(at: destURL)
                            }
                            try manager.copyItem(at: sourceURL, to: destURL)
                        } catch {
                            os_log("failed to copy database to sync folder: %s", type: .error, "\(error)")
                        }
                    } else {
                        os_log("failed to acquire security access to %s", type: .error, "\(path)")
                    }
                }
            }
        } catch {
            os_log("failed to load sync folder: %s", type: .error, "\(error)")
        }
    }

    private func syncId() -> String {
        if let id = UserDefaults.standard.string(forKey: "syncId") {
            return id
        }

        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "syncId")
        return id
    }
}

class FolderSyncDefaults {
    private static let KEY = "sync"

    static func load() throws -> URL? {
        return try UserDefaults.standard.data(forKey: KEY).flatMap { d in
            var isStale = false
            let url = try URL(resolvingBookmarkData: d, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
                return nil
            }

            return url
        }
    }

    static func save(path: URL) throws {
        let bookmark = try path.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.setValue(bookmark, forKey: KEY)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: KEY)
    }
}
