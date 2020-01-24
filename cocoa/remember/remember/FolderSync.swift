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
                    if path.startAccessingSecurityScopedResource() {
                        defer {
                            path.stopAccessingSecurityScopedResource()
                        }

                        self.performMerge(from: path)
                        self.performSave(to: path, from: tempPath)
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

    private func performMerge(from root: URL) {
        do {
            if let latestDB = latestDatabaseFile(from: root), !latestDB.absoluteString.contains(syncId()) {
                let manager = FileManager.default
                let destPath = try manager.url(
                    for: .itemReplacementDirectory,
                    in: .userDomainMask,
                    appropriateFor: root,
                    create: true
                ).appendingPathComponent("\(syncId()).sqlite3")

                try manager.copyItem(at: latestDB, to: destPath)
                entryDB.mergeDatabaseCopy(from: destPath) { }
            }
        } catch {
            os_log("failed to perform database merge: %s", type: .error, "\(error)")
        }
    }

    private func performSave(to root: URL, from tempPath: URL) {
        do {
            let manager = FileManager.default
            let destURL = root.appendingPathComponent("\(self.syncId()).sqlite3")
            let sourceURL = URL(fileURLWithPath: tempPath.absoluteString)
            if manager.fileExists(atPath: destURL.relativePath) {
                try manager.removeItem(at: destURL)
            }

            try manager.copyItem(at: sourceURL, to: destURL)
        } catch {
            os_log("failed to copy database to sync folder: %s", type: .error, "\(error)")
        }
    }

    private func latestDatabaseFile(from root: URL) -> URL? {
        do {
            let manager = FileManager.default
            let entries = try manager.contentsOfDirectory(atPath: root.relativePath)
            var latestEntry: URL?
            for entry in entries {
                if entry.suffix(8) == ".sqlite3" {
                    if let latest = latestEntry {
                        let latestAttributes = try manager.attributesOfItem(atPath: latest.relativePath)
                        let latestModifiedAt = latestAttributes[.modificationDate] as! Date
                        let entryURL = root.appendingPathComponent(entry)
                        let entryAttributes = try manager.attributesOfItem(atPath: entryURL.relativePath)
                        let entryModifiedAt = entryAttributes[.modificationDate] as! Date

                        if entryModifiedAt > latestModifiedAt {
                            latestEntry = entryURL
                        }
                    } else {
                        latestEntry = root.appendingPathComponent(entry)
                    }
                }
            }

            return latestEntry
        } catch {
            os_log("failed to find latest database file: %s", type: .error, "\(error)")
            return nil
        }
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
