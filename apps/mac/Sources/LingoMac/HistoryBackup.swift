import Foundation

/// History export and restore (MR-04, R-44). A backup is a ZIP with one folder `Lingo-history/` that holds only journals:
/// `devices/<id>/journal-*.jsonl` (this device) and `cache/<id>/journal-*.jsonl` (copies of other devices).
/// Keys, settings, device identity and sync state are never exported. Restore never overwrites an existing file.
enum HistoryBackup {
    static let rootName = "Lingo-history"
    static let dailyPrefix = "Lingo-history-"

    struct RestoreReport: Equatable {
        var restored = 0
        var skippedExisting = 0
        var rejected = 0
    }

    enum Failure: Error, LocalizedError {
        case tool(String)
        case notABackup
        var errorDescription: String? {
            switch self {
            case .tool(let m): m
            case .notABackup: String(localized: "This ZIP is not a Lingo history backup.")
            }
        }
    }

    // MARK: Export

    /// Copies this device's journals and the cache of other devices into a staging folder and zips it to `dest`.
    static func export(base: URL, to dest: URL) throws {
        let fm = FileManager.default
        let stage = fm.temporaryDirectory.appendingPathComponent("lingo-export-" + UUID().uuidString, isDirectory: true)
        let root = stage.appendingPathComponent(rootName, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: stage) }
        for sub in ["devices", "cache"] {
            for file in journalFiles(under: base.appendingPathComponent(sub, isDirectory: true)) {
                let rel = relativePath(of: file, in: base)
                let target = root.appendingPathComponent(rel)
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: file, to: target)
            }
        }
        try? fm.removeItem(at: dest)
        try run("/usr/bin/ditto", ["-c", "-k", "--keepParent", root.path, dest.path])
    }

    // MARK: Restore

    /// Merges a backup into `base`. Journals of the device with `ownDeviceID` go back to `devices/<id>`; journals of every other device
    /// become cache copies (`cache/<id>`), so a backup from another Mac never masquerades as this device. Existing files are kept.
    @discardableResult
    static func restore(from zip: URL, into base: URL, ownDeviceID: String) throws -> RestoreReport {
        let fm = FileManager.default
        let stage = fm.temporaryDirectory.appendingPathComponent("lingo-restore-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: stage) }
        try run("/usr/bin/ditto", ["-x", "-k", zip.path, stage.path])
        let root = stage.appendingPathComponent(rootName, isDirectory: true)
        guard fm.fileExists(atPath: root.path) else { throw Failure.notABackup }

        var report = RestoreReport()
        let all = (fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]).map { $0.allObjects as? [URL] } ?? nil) ?? []
        for file in all {
            let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values?.isRegularFile == true else { continue }
            let parts = relativePath(of: file, in: root).split(separator: "/").map(String.init)
            guard parts.count == 3, ["devices", "cache"].contains(parts[0]), isSafeComponent(parts[1]),
                  isJournalName(parts[2]), values?.isSymbolicLink != true else { report.rejected += 1; continue }
            let owner = parts[1]
            let dir: URL?
            switch (parts[0], owner == ownDeviceID) {
            case ("devices", true): dir = base.appendingPathComponent("devices/\(owner)", isDirectory: true)
            case ("devices", false), ("cache", false): dir = base.appendingPathComponent("cache/\(owner)", isDirectory: true)
            default: dir = nil // a cache copy that claims to be this device
            }
            guard let dir else { report.rejected += 1; continue }
            let target = dir.appendingPathComponent(parts[2])
            if fm.fileExists(atPath: target.path) { report.skippedExisting += 1; continue }
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try fm.copyItem(at: file, to: target)
            report.restored += 1
        }
        return report
    }

    // MARK: Daily backup

    /// File name of the daily backup of `day` ("yyyy-MM-dd").
    static func dailyName(for day: String) -> String { "\(dailyPrefix)\(day).zip" }

    /// Writes today's backup into `folder` unless it exists already; keeps the newest `keep` daily files. Returns the file when one was written.
    @discardableResult
    static func dailyBackupIfDue(base: URL, folder: URL, today: String, keep: Int = 14) throws -> URL? {
        let fm = FileManager.default
        let dest = folder.appendingPathComponent(dailyName(for: today))
        guard !fm.fileExists(atPath: dest.path) else { return nil }
        try export(base: base, to: dest)
        let daily = ((try? fm.contentsOfDirectory(atPath: folder.path)) ?? [])
            .filter { $0.hasPrefix(dailyPrefix) && $0.hasSuffix(".zip") }.sorted()
        for old in daily.dropLast(max(keep, 1)) { try? fm.removeItem(at: folder.appendingPathComponent(old)) }
        return dest
    }

    // MARK: Helpers

    private static func journalFiles(under dir: URL) -> [URL] {
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
        return (e.allObjects as? [URL] ?? []).filter { isJournalName($0.lastPathComponent) && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .sorted { $0.path < $1.path }
    }

    static func isJournalName(_ name: String) -> Bool { name.hasPrefix("journal-") && name.hasSuffix(".jsonl") && isSafeComponent(name) }
    static func isSafeComponent(_ s: String) -> Bool { !s.isEmpty && s != "." && s != ".." && !s.contains("/") && !s.contains("\0") }

    private static func relativePath(of file: URL, in root: URL) -> String {
        let r = root.resolvingSymlinksInPath().path, f = file.resolvingSymlinksInPath().path
        return f.hasPrefix(r + "/") ? String(f.dropFirst(r.count + 1)) : file.lastPathComponent
    }

    private static func run(_ tool: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let err = Pipe()
        p.standardError = err
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw Failure.tool(msg.isEmpty ? "\(tool) exited with \(p.terminationStatus)" : msg)
        }
    }
}
