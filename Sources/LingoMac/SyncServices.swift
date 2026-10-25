import AppKit
import Foundation
import LingoCore

/// Синхронизация и сеть в приложении (R-36…R-38, S-17, S-20).
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

    /// Выбор папки синхронизации (R-36): системный выбор файлов, доступ — security-scoped bookmark.
    func chooseSyncFolder() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.canCreateDirectories = true
        p.allowsMultipleSelection = false
        p.prompt = "Выбрать"
        p.message = "Выберите папку «Lingo» в iCloud Drive. В ней каждое устройство пишет свой журнал."
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
            model.banner = "Папка синхронизации: \(error.localizedDescription)"
        }
    }

    func syncNow() { Task { await scheduler?.trigger(.manual) } }

    func forgetSyncFolder() {
        updateSettings { $0.syncBookmark = nil }
        model.syncFolderPath = nil
        Task { await scheduler?.setFolder(nil) }
    }

    /// Экспорт истории (R-44 «Данные»): ZIP журналов этого устройства и кэша других устройств — `ditto -c -k`.
    func exportHistory() {
        let p = NSSavePanel()
        p.nameFieldStringValue = "Lingo-history-\(MetricsDay.today()).zip"
        guard p.runModal() == .OK, let dest = p.url else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        task.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", store.base.appendingPathComponent("devices").path, dest.path]
        do { try task.run(); task.waitUntilExit() } catch { model.banner = "Экспорт: \(error.localizedDescription)" }
        if task.terminationStatus == 0 { NSWorkspace.shared.activateFileViewerSelecting([dest]) }
    }

    /// Удаление локальной истории (R-44): только журналы на этом Mac; копии на других устройствах и в папке синхронизации остаются.
    func deleteLocalHistory() {
        let a = NSAlert()
        a.messageText = "Удалить локальную историю?"
        a.informativeText = "Будут удалены журналы на этом Mac. Копии на других устройствах и в папке синхронизации останутся; при следующей синхронизации история вернётся из папки. Ключи и настройки не удаляются."
        a.addButton(withTitle: "Удалить")
        a.addButton(withTitle: "Отмена")
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
