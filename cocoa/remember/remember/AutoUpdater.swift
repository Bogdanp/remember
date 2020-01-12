//
//  AutoUpdater.swift
//  Remember
//
//  Created by Bogdan Popa on 12/01/2020.
//  Copyright © 2020 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import os

/// Checks the given service URL for new versions of the current application.  If newer versions (by string comparison)
/// are found, then an action is fired.  The application can then notify the user that updates are available and ask them
/// if they want to perform the update.
///
/// The service must expose two files under its root URL:
///   * `changelog.txt` -- containing plain text describing all of the changes between versions and
///   * `versions.json` -- containing a JSON array with `{version, macURL}` objects inside it.
class AutoUpdater {
    private let serviceURL: URL
    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String

    private var timer: Timer?

    private let decoder = JSONDecoder()

    init(withServiceURL serviceURL: URL) {
        self.serviceURL = serviceURL
    }

    func start(withInterval interval: Double, andCompletionHandler handler: @escaping (String, Version) -> Void) {
        stop()
        checkForUpdates(withCompletionHandler: handler)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.checkForUpdates(withCompletionHandler: handler)
       }
    }

    func stop() {
        if let timer = self.timer {
            timer.invalidate()
        }
    }

    func performUpdate(version: Version) {

    }

    func checkForUpdates(withCompletionHandler handler: @escaping (String, Version) -> Void) {
        fetchChangelog { changelog in
            self.fetchVersionsJSON { versions in
                let latest = versions.sorted { a, b in
                    a.version > b.version
                }.first

                if let latest = latest, latest.version != self.currentVersion {
                    handler(changelog, latest)
                }
            }
        }
    }

    private func fetchChangelog(withCompletionHandler handler: @escaping (String) -> Void) {
        let changelogURL = serviceURL.appendingPathComponent("changelog.txt")
        let task = URLSession.shared.dataTask(with: changelogURL) { data, response, error in
            if let error = error {
                os_log("failed to check for updates: %s", type: .error, "\(error)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                let mimeType = httpResponse.mimeType, mimeType == "text/plain" else {

                    os_log("invalid response from server: %s", type: .error, String(describing: response))
                    return
            }

            guard let data = data else {
                os_log("empty changelog data from server", type: .error)
                return
            }

            handler(String(decoding: data, as: UTF8.self))
        }
        task.resume()
    }

    private func fetchVersionsJSON(withCompletionHandler handler: @escaping ([Version]) -> Void) {
        let versionsURL = serviceURL.appendingPathComponent("versions.json")
        let task = URLSession.shared.dataTask(with: versionsURL) { data, response, error in
            if let error = error {
                os_log("failed to check for updates: %s", type: .error, "\(error)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                let mimeType = httpResponse.mimeType, mimeType == "application/json" else {

                    os_log("invalid response from server: %s", type: .error, String(describing: response))
                    return
            }

            guard let data = data else {
                os_log("didn't receive any data from the server", type: .error)
                return
            }

            do {
                handler(try self.decoder.decode([Version].self, from: data))
            } catch {
                os_log("failed to parse versions JSON: %s", type: .error, "\(error)")
            }
        }
        task.resume()
    }
}

struct Version: Codable {
    let version: String
    let macURL: URL
}
