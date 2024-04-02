import BackgroundTasks
import Foundation
import os

fileprivate let logger = Logger(
  subsystem: "io.defn.remember",
  category: "FolderSyncer"
)

class FolderSyncer {
  static let shared = FolderSyncer()

  static private let refreshIdentifier = "io.defn.remember-ios.FolderSyncer.refresh"

  init() {
    sync()
    scheduleSync()
  }

  private var timer: Timer?
  private var id: String {
    if let id = UserDefaults.standard.string(forKey: "sync.id") {
      return id
    }

    let id = UUID().uuidString
    UserDefaults.standard.set(id, forKey: "sync.id")
    return id
  }

  func registerTasks() {
    logger.debug("Registering refresh task.")
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: Self.refreshIdentifier,
      using: .main) { [weak self] task in
        self?.handleRefresh(task)
      }
  }

  func scheduleRefresh() {
    logger.debug("Preparing to schedule refresh.")
    let request = BGProcessingTaskRequest(identifier: Self.refreshIdentifier)
    let deadline = Date(timeIntervalSinceNow: 30*60)
    request.earliestBeginDate = deadline
    logger.debug("Scheduling refresh at \(deadline.ISO8601Format()).")
    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      logger.error("Failed to schedule refresh: \(error)")
    }
  }

  func unscheduleRefresh() {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshIdentifier)
  }

  private func handleRefresh(_ task: BGTask) {
    scheduleRefresh()
    sync() {
      NotificationsManager.shared.scheduleRefresh()
      task.setTaskCompleted(success: true)
    }
  }

  func invalidate() {
    timer?.invalidate()
  }

  func scheduleSync() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(
      withTimeInterval: 5*60,
      repeats: true
    ) { [weak self] _ in
      self?.sync()
    }
  }

  func sync(withCompletionHandler completionHandler: @escaping () -> Void = { }) {
    do {
      if let path = try FolderSyncDefaults.load() {
        logger.debug("Initiating sync to \(path).")
        Backend.shared.createDatabaseCopy().onComplete { [weak self] tempPath in
          guard let self else { return }
          guard let tempURL = URL(string: tempPath) else { return }
          if path.startAccessingSecurityScopedResource() {
            defer {
              path.stopAccessingSecurityScopedResource()
            }

            self.performMerge(from: path)
            self.performSave(to: path, from: tempURL)
          } else {
            logger.error("Failed to acquire security access to \(path).")
          }
          completionHandler()
        }
      } else {
        logger.debug("No sync folder. Doing nothing.")
        completionHandler()
      }
    } catch {
      logger.error("Failed to load sync folder: \(error)")
      completionHandler()
    }
  }

  private func performMerge(from root: URL) {
    do {
      if let latestDB = latestDatabaseFile(from: root), !latestDB.absoluteString.contains(id) {
        let manager = FileManager.default
        let destPath = try manager.url(
          for: .itemReplacementDirectory,
          in: .userDomainMask,
          appropriateFor: root,
          create: true
        ).appendingPathComponent("\(id).sqlite3")

        try manager.copyItem(at: latestDB, to: destPath)
        try Backend.shared.mergeDatabaseCopy(atPath: destPath.absoluteString).wait()
      }
    } catch {
      logger.error("Failed to perform database merge; \(error)")
    }
  }

  private func performSave(to root: URL, from tempPath: URL) {
    do {
      let manager = FileManager.default
      let destURL = root.appendingPathComponent("\(id).sqlite3")
      let sourceURL = URL(fileURLWithPath: tempPath.absoluteString)
      if manager.fileExists(atPath: destURL.relativePath) {
        try manager.removeItem(at: destURL)
      }

      try manager.moveItem(at: sourceURL, to: destURL)
    } catch {
      logger.error("Failed to save database to sync folder: \(error)")
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
      logger.error("Failed to find latest database file: \(error)")
      return nil
    }
  }
}
