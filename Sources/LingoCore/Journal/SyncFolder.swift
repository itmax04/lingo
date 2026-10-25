import Foundation

/// Статус синхронизации для сайдбара (R-38).
public enum SyncStatus: Sendable, Hashable {
    case notConfigured
    case syncing
    case synced(Date)
    /// Часть чужих журналов ещё не загружена из iCloud.
    case waitingICloud(Date)
    case unavailable(String)

    public var title: String {
        switch self {
        case .notConfigured: return "Синхронизация не настроена"
        case .syncing: return "Синхронизация…"
        case .synced(let d): return "Синхронизировано в \(SessionDateFormat.time(d))"
        case .waitingICloud: return "Ожидает iCloud"
        case .unavailable: return "Папка синхронизации недоступна — выбрать снова"
        }
    }
}

/// Папка синхронизации (R-36): `Lingo/v1/devices/<deviceId>/journal-<yyyy-mm>.jsonl` и `device.json`.
/// Каждое устройство пишет только в свою папку; чужие журналы читаются через `NSFileCoordinator`,
/// недогруженные файлы iCloud запрашиваются на загрузку. Платные возможности (iCloud entitlements, CloudKit) не используются.
public struct SyncFolder: Sendable {
    /// Выбранная пользователем папка. Если она сама называется «Lingo», структура создаётся в ней, иначе — в подпапке «Lingo».
    public let picked: URL

    public init(picked: URL) { self.picked = picked }

    public var root: URL {
        picked.lastPathComponent == "Lingo" ? picked : picked.appendingPathComponent("Lingo", isDirectory: true)
    }
    public var devicesDir: URL { root.appendingPathComponent("v1/devices", isDirectory: true) }
    public func deviceDir(_ id: String) -> URL { devicesDir.appendingPathComponent(id, isDirectory: true) }

    public enum SyncError: Error, Equatable, CustomStringConvertible {
        case unavailable(String)
        public var description: String {
            switch self { case .unavailable(let s): return s }
        }
    }

    // MARK: Security-scoped bookmark

    public func bookmark() throws -> Data {
        #if os(macOS)
        if let d = try? picked.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
            return d
        }
        #endif
        return try picked.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// Восстановление папки из закладки. `stale` — закладку нужно пересоздать.
    public static func resolve(bookmark: Data) throws -> (folder: SyncFolder, stale: Bool) {
        var stale = false
        #if os(macOS)
        if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale) {
            return (SyncFolder(picked: url), stale)
        }
        #endif
        let url = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        return (SyncFolder(picked: url), stale)
    }

    func withAccess<T>(_ body: () throws -> T) rethrows -> T {
        let ok = picked.startAccessingSecurityScopedResource()
        defer { if ok { picked.stopAccessingSecurityScopedResource() } }
        return try body()
    }

    /// Папка существует и доступна (S-20).
    public func checkAvailable() throws {
        try withAccess {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: picked.path, isDirectory: &isDir), isDir.boolValue else {
                throw SyncError.unavailable("папка не найдена")
            }
            guard FileManager.default.isReadableFile(atPath: picked.path), FileManager.default.isWritableFile(atPath: picked.path) else {
                throw SyncError.unavailable("нет доступа к папке")
            }
        }
    }

    // MARK: Запись своего журнала

    /// Копирует свои файлы журнала в папку, если они отличаются по размеру. Возвращает число обновлённых файлов.
    @discardableResult
    public func push(deviceID: String, localDir: URL, deviceInfo: DeviceInfo) throws -> Int {
        try checkAvailable()
        return try withAccess {
            let dest = deviceDir(deviceID)
            try coordinatedCreateDirectory(dest)
            var updated = 0
            for file in JournalReader.journalFiles(in: localDir) {
                let local = try Data(contentsOf: file)
                let target = dest.appendingPathComponent(file.lastPathComponent)
                let remoteSize = (try? target.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -1
                if remoteSize == local.count { continue }
                try coordinatedWrite(local, to: target)
                updated += 1
            }
            let info = try JSONEncoder.sorted.encode(deviceInfo)
            let infoURL = dest.appendingPathComponent("device.json")
            if (try? Data(contentsOf: infoURL)) != info { try coordinatedWrite(info, to: infoURL) }
            return updated
        }
    }

    // MARK: Чтение чужих журналов

    public struct PullResult: Sendable, Equatable {
        public var devices = 0
        public var filesUpdated = 0
        /// Файлы, которые ещё загружаются из iCloud.
        public var pending = 0
    }

    /// Копирует журналы других устройств в локальный кэш `cacheDir/<deviceId>/`.
    public func pull(ownDeviceID: String, cacheDir: URL) throws -> PullResult {
        try checkAvailable()
        return try withAccess {
            var r = PullResult()
            let fm = FileManager.default
            let devices = (try? fm.contentsOfDirectory(at: devicesDir, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
            for dev in devices where dev.lastPathComponent != ownDeviceID && !dev.lastPathComponent.hasPrefix(".") {
                guard (try? dev.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
                r.devices += 1
                let names = (try? fm.contentsOfDirectory(atPath: dev.path)) ?? []
                for name in names {
                    // Заглушка iCloud: «.journal-2026-10.jsonl.icloud».
                    var real = name
                    if name.hasPrefix("."), name.hasSuffix(".icloud") {
                        real = String(name.dropFirst().dropLast(".icloud".count))
                    }
                    guard real.hasPrefix("journal-"), real.hasSuffix(".jsonl") else { continue }
                    let url = dev.appendingPathComponent(real)
                    if !isDownloaded(url) || real != name {
                        try? fm.startDownloadingUbiquitousItem(at: url)
                        if real != name || !fm.fileExists(atPath: url.path) { r.pending += 1; continue }
                    }
                    guard let data = coordinatedRead(url) else { r.pending += 1; continue }
                    let localDir = cacheDir.appendingPathComponent(dev.lastPathComponent, isDirectory: true)
                    try fm.createDirectory(at: localDir, withIntermediateDirectories: true)
                    let local = localDir.appendingPathComponent(real)
                    if (try? Data(contentsOf: local)) != data {
                        try data.write(to: local, options: .atomic)
                        r.filesUpdated += 1
                    }
                }
            }
            return r
        }
    }

    private func isDownloaded(_ url: URL) -> Bool {
        guard let v = try? url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]) else { return true }
        guard v.isUbiquitousItem == true else { return true }
        return v.ubiquitousItemDownloadingStatus == .current
    }

    // MARK: NSFileCoordinator

    private func coordinatedRead(_ url: URL) -> Data? {
        var result: Data?
        var err: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &err) { u in
            result = try? Data(contentsOf: u)
        }
        return err == nil ? result : nil
    }

    private func coordinatedWrite(_ data: Data, to url: URL) throws {
        var err: NSError?
        var inner: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: [.forReplacing], error: &err) { u in
            do { try data.write(to: u, options: .atomic) } catch { inner = error }
        }
        if let e = err ?? inner { throw e }
    }

    private func coordinatedCreateDirectory(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) { return }
        var err: NSError?
        var inner: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: [], error: &err) { u in
            do { try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true) } catch { inner = error }
        }
        if let e = err ?? inner { throw e }
    }
}

/// `device.json` (R-36): имя устройства и версия приложения.
public struct DeviceInfo: Codable, Sendable, Hashable {
    public var id: String
    public var name: String
    public var platform: String
    public var appVersion: String
    public var schema: Int

    public init(id: String, name: String, platform: String, appVersion: String, schema: Int = Event.schemaVersion) {
        self.id = id
        self.name = name
        self.platform = platform
        self.appVersion = appVersion
        self.schema = schema
    }
}

extension JSONEncoder {
    static var sorted: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return e
    }
}
