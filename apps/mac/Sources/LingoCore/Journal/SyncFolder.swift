import Foundation

/// Sync status for the sidebar (R-38).
public enum SyncStatus: Sendable, Hashable {
    case notConfigured
    case syncing
    case synced(Date)
    /// Some journals of other devices have not been downloaded from iCloud yet.
    case waitingICloud(Date)
    case unavailable(String)

    public var title: String {
        switch self {
        case .notConfigured: return String(localized: "Sync is not set up")
        case .syncing: return String(localized: "Syncing…")
        case .synced(let d): return String(localized: "Synced at \(SessionDateFormat.time(d))")
        case .waitingICloud: return String(localized: "Waiting for iCloud")
        case .unavailable: return String(localized: "Sync folder unavailable — choose it again")
        }
    }
}

/// Sync folder (R-36): `Lingo/v1/devices/<deviceId>/journal-<yyyy-mm>.jsonl` and `device.json`.
/// Each device writes only to its own folder; other journals are read through `NSFileCoordinator`,
/// and iCloud files that are not downloaded yet are requested. No paid features (iCloud entitlements, CloudKit) are used.
public struct SyncFolder: Sendable {
    /// The folder chosen by the user. If it is itself named "Lingo", the structure is created inside it, otherwise in a "Lingo" subfolder.
    public let picked: URL

    public init(picked: URL) { self.picked = picked }

    public var root: URL {
        picked.lastPathComponent == "Lingo" ? picked : picked.appendingPathComponent("Lingo", isDirectory: true)
    }
    public var devicesDir: URL { root.appendingPathComponent("v1/devices", isDirectory: true) }
    public func deviceDir(_ id: String) -> URL { devicesDir.appendingPathComponent(id, isDirectory: true) }

    public enum SyncError: Error, Equatable, CustomStringConvertible, LocalizedError {
        case unavailable(String)
        public var description: String {
            switch self { case .unavailable(let s): return s }
        }
        /// `localizedDescription` shows the reason ("folder not found"), not "The operation couldn't be completed".
        public var errorDescription: String? { description }
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

    /// Restore the folder from a bookmark. `stale` — the bookmark must be recreated.
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

    public func withAccess<T>(_ body: () throws -> T) rethrows -> T {
        let ok = picked.startAccessingSecurityScopedResource()
        defer { if ok { picked.stopAccessingSecurityScopedResource() } }
        return try body()
    }

    /// The folder exists and is accessible (S-20).
    public func checkAvailable() throws {
        try withAccess {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: picked.path, isDirectory: &isDir), isDir.boolValue else {
                throw SyncError.unavailable(String(localized: "folder not found"))
            }
            guard FileManager.default.isReadableFile(atPath: picked.path), FileManager.default.isWritableFile(atPath: picked.path) else {
                throw SyncError.unavailable(String(localized: "no access to the folder"))
            }
        }
    }

    // MARK: Writing this device's journal

    /// Copies this device's journal files to the folder if their sizes differ. Returns the number of updated files.
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

    // MARK: Reading other journals

    public struct PullResult: Sendable, Equatable {
        public var devices = 0
        public var filesUpdated = 0
        /// Files that are still downloading from iCloud.
        public var pending = 0
    }

    /// Copies other devices' journals to the local cache `cacheDir/<deviceId>/`.
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
                    // iCloud placeholder: ".journal-2026-10.jsonl.icloud".
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

/// `device.json` (R-36): device name and app version.
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
