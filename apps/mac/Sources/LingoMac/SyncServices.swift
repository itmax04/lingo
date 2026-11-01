import AppKit
import Foundation
import LingoCore

/// Sync and network in the app (R-36…R-38, S-17, S-20).
@MainActor
extension AppServices {
    func startSyncAndNetwork() {
        let m = model
        reachability.onChange = { up in Task { @MainActor in m.networkUp = up; m.recomputeOnline() } }
        reachability.start()
        let folder = settings.syncBookmark.flatMap { try? SyncFolder.resolve(bookmark: $0) }
        if let (_, stale) = settings.syncBookmark.flatMap({ try? SyncFolder.resolve(bookmark: $0) }), stale, let f = folder?.folder {
            if let b = try? f.bookmark() { updateSettings { $0.syncBookmark = b } }
        }
        let sch = SyncScheduler(store: store, folder: folder?.folder)
        scheduler = sch
        Task {
            await sch.setStatusHandler { s in Task { @MainActor in m.syncStatus = s.title; m.syncState = s } }
            await sch.setActive(true)
            await sch.trigger(.launch)
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            Task { await sch.setActive(true) }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { _ in
            Task { await sch.setActive(false) }
        }
    }

    /// Choosing the sync folder (R-36): the system file picker, access through a security-scoped bookmark.
    func chooseSyncFolder() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.canCreateDirectories = true
        p.allowsMultipleSelection = false
        p.prompt = String(localized: "Choose")
        p.message = String(localized: "Choose the “Lingo” folder in iCloud Drive. Each device writes its own journal there.")
        let icloud = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        let lingo = icloud.appendingPathComponent("Lingo", isDirectory: true)
        p.directoryURL = FileManager.default.fileExists(atPath: lingo.path) ? lingo : icloud
        guard p.runModal() == .OK, let url = p.url else { return }
        let f = SyncFolder(picked: url)
        do {
            let b = try f.bookmark()
            updateSettings { $0.syncBookmark = b }
            Task { await scheduler?.setFolder(f); await scheduler?.trigger(.folderChanged) }
            model.syncFolderPath = url.path
        } catch {
            model.banner = String(localized: "Sync folder: \(error.localizedDescription)")
        }
    }

    func syncNow() { Task { await scheduler?.trigger(.manual) } }

    func forgetSyncFolder() {
        updateSettings { $0.syncBookmark = nil }
        model.syncFolderPath = nil
        Task { await scheduler?.setFolder(nil) }
    }

    /// History export (R-44 "Data"): a ZIP with this device's journals and the cache of other devices (`HistoryBackup`).
    func exportHistory() {
        let p = NSSavePanel()
        p.nameFieldStringValue = HistoryBackup.dailyName(for: MetricsDay.today())
        guard p.runModal() == .OK, let dest = p.url else { return }
        let base = store.base, m = model
        Task.detached {  // the copy and the zip run off the main thread
            do {
                try HistoryBackup.export(base: base, to: dest)
                await MainActor.run { NSWorkspace.shared.activateFileViewerSelecting([dest]) }
            } catch { await MainActor.run { m.banner = String(localized: "Export: \(error.localizedDescription)") } }
        }
    }

    // MARK: Daily backup (MR-04, P-04b)

    func startDailyBackup() {
        let b = BackupScheduler(base: store.base)
        let m = model
        b.onStatus = { s in
            let wasFailed = m.backupFailed
            m.backupRunning = s == .running
            switch s {
            case .off: m.backupStatus = String(localized: "Off"); m.backupFailed = false
            case .running: m.backupStatus = String(localized: "Backing up…")
            case .done(let day): m.backupStatus = String(localized: "Last backup: \(day)"); m.backupFailed = false
            case .failed(let why):
                m.backupStatus = String(localized: "Backup failed: \(why)")
                // The banner only when the backup starts failing, not again on every hourly retry.
                if !wasFailed { m.banner = String(localized: "Daily backup failed: \(why). Check the folder in Settings → Data.") }
                m.backupFailed = true
            }
        }
        backup = b
        if let data = settings.backupBookmark {
            if let r = try? SyncFolder.resolve(bookmark: data) {
                if r.stale, let fresh = try? r.folder.bookmark() { updateSettings { $0.backupBookmark = fresh } }
                model.backupFolderPath = r.folder.picked.path
            } else {
                model.backupFolderPath = String(localized: "Saved folder (not available now)")
            }
        }
        b.setBookmark(settings.backupBookmark)
        b.start()
    }

    func chooseBackupFolder() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.canCreateDirectories = true
        p.allowsMultipleSelection = false
        p.prompt = String(localized: "Choose")
        p.message = String(localized: "Choose a folder for the daily backup of your history (for example in iCloud Drive or on an external disk).")
        guard p.runModal() == .OK, let url = p.url else { return }
        let f = SyncFolder(picked: url)
        do {
            let data = try f.bookmark()
            updateSettings { $0.backupBookmark = data }
            backup?.setFolder(f)
            model.backupFolderPath = url.path
            Task { await backup?.runIfDue() }
        } catch {
            model.banner = String(localized: "Backup folder: \(error.localizedDescription)")
        }
    }

    func backupNow() { Task { await backup?.runIfDue(force: true) } }

    func turnOffDailyBackup() {
        updateSettings { $0.backupBookmark = nil }
        backup?.setFolder(nil)
        model.backupFolderPath = nil
    }

    /// Restore from a ZIP made by `exportHistory`: merges journals, never overwrites a file (MR-04).
    func restoreHistory() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.zip]
        p.canChooseDirectories = false
        guard p.runModal() == .OK, let zip = p.url else { return }
        let base = store.base, id = store.deviceID, m = model, store = store
        Task.detached {
            do {
                let r = try HistoryBackup.restore(from: zip, into: base, ownDeviceID: id)
                await store.reload()
                await MainActor.run { m.banner = String(localized: "Restored \(r.restored) files, \(r.skippedExisting) already here, \(r.rejected) skipped.") }
            } catch { await MainActor.run { m.banner = String(localized: "Restore: \(error.localizedDescription)") } }
        }
    }

    /// Deleting the local history (R-44): only the journals on this Mac; copies on other devices and in the sync folder remain.
    func deleteLocalHistory() {
        let a = NSAlert()
        a.messageText = String(localized: "Delete the local history?")
        a.informativeText = String(localized: "The journals on this Mac will be deleted. Copies on other devices and in the sync folder remain; the history comes back from the folder at the next sync. Keys and settings are not deleted.")
        a.addButton(withTitle: String(localized: "Delete"))
        a.addButton(withTitle: String(localized: "Cancel"))
        a.alertStyle = .warning
        guard a.runModal() == .alertFirstButtonReturn else { return }
        for sub in ["devices", "cache", "sync-state.json"] { try? FileManager.default.removeItem(at: store.base.appendingPathComponent(sub)) }
        Task { await store.reload() }
    }
}

enum MetricsDay {
    static func today() -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
