//
//  AutoUpdater.swift
//  Remember
//
//  Created by Bogdan Popa on 12/01/2020.
//  Copyright © 2020 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import os

#if DEBUG
let VERSIONS_SERVICE_URL = "http://local.remember/versions/"
#else
let VERSIONS_SERVICE_URL = "https://remember.defn.io/versions/"
#endif

struct Release: Codable {
    let arch: String
    let version: String
    let macURL: URL
}

enum UpdateResult {
    case ok
    case error(String)
}

fileprivate enum ReleaseDownloadResult {
    case ok(URL)
    case error(String)
}

/// Checks the given service URL for new versions of the current application.  If newer versions (by string comparison)
/// are found, then an action is fired.  The application can then notify the user that updates are available and ask them
/// if they want to perform the update.
///
/// The service must expose two files under its root URL:
///   * `changelog.txt` -- containing plain text describing all of the changes between versions and
///   * `versions.json` -- containing a JSON array with `{arch, version, macURL}` objects inside it.
class AutoUpdater {
    private let serviceURL = URL(string: VERSIONS_SERVICE_URL)!
    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
    private let session = URLSession(configuration: .ephemeral)
    private let decoder = JSONDecoder()

    private var timer: Timer?

    func start(withInterval interval: Double, andCompletionHandler handler: @escaping (String, Release) -> Void) {
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

    func performUpdate(toRelease release: Release, withCompletionHandler handler: @escaping (UpdateResult) -> Void) {
        fetchRelease(release) { res in
            switch res {
            case .ok(let path):
                let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
                let targetURL = downloadsURL.appendingPathComponent("Remember \(release.version).dmg")
                do {
                    try FileManager.default.copyItem(at: path, to: targetURL)
                } catch {
                    os_log("failed to copy update to downloads folder: %s", type: .error, "\(error)")
                }

                NSWorkspace.shared.open(targetURL)
                handler(.ok)
            case .error(let message):
                handler(.error(message))
            }
        }
    }

    func checkForUpdates(withCompletionHandler handler: @escaping (String, Release) -> Void) {
        fetchChangelog { changelog in
            self.fetchReleasesJSON { releases in
                let latest = releases.sorted { a, b in
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
        let task = session.dataTask(with: changelogURL) { data, response, error in
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

    private func fetchReleasesJSON(withCompletionHandler handler: @escaping ([Release]) -> Void) {
        let versionsURL = serviceURL.appendingPathComponent("versions.json")
        let task = session.dataTask(with: versionsURL) { data, response, error in
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
                handler(try self.decoder.decode([Release].self, from: data).filter({ release in
                    release.arch == ARCH
                }))
            } catch {
                os_log("failed to parse versions JSON: %s", type: .error, "\(error)")
            }
        }
        task.resume()
    }

    private func fetchRelease(_ release: Release, withCompletionHandler handler: @escaping (ReleaseDownloadResult) -> Void) {
        let task = session.downloadTask(with: release.macURL) { fileURL, response, error in
            if let error = error {
                os_log("failed to download release: %s", type: .error, "\(error)")
                handler(.error("We were unable to retrieve the updated files.  Please check your connection and try again later."))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                os_log("invalid response from server: %s", type: .error, String(describing: response))
                handler(.error("An unexpected error occurred.  Please try again later."))
                return
            }

            guard let theURL = fileURL else {
                os_log("release failed to download", type: .error)
                handler(.error("An unexpected error occurred.  Please try again later."))
                return
            }

            handler(.ok(theURL))
        }
        task.resume()
    }
}
