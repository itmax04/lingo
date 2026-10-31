import Foundation

/// Result of reading a journal (R-39).
public struct JournalReadResult: Sendable {
    public var events: [Event] = []
    /// A truncated last line (no trailing newline at the end of the file) — ignored.
    public var tornTail = false
    /// Corrupted lines — skipped and counted as a metric.
    public var corruptedLines = 0
    /// The journal has events with a newer schema version — read-only with a warning.
    public var newerSchema = false

    public init() {}

    public mutating func absorb(_ other: JournalReadResult) {
        events += other.events
        tornTail = tornTail || other.tornTail
        corruptedLines += other.corruptedLines
        newerSchema = newerSchema || other.newerSchema
    }
}

/// JSON Lines reader (R-39).
public enum JournalReader {
    public static func parse(_ data: Data) -> JournalReadResult {
        var r = JournalReadResult()
        guard !data.isEmpty else { return r }
        let text = String(decoding: data, as: UTF8.self)
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        if let last = lines.last {
            if last.isEmpty { lines.removeLast() } else { r.tornTail = true; lines.removeLast() }
        }
        for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            do {
                let e = try Event(line: line)
                if e.v > Event.schemaVersion { r.newerSchema = true }
                r.events.append(e)
            } catch {
                r.corruptedLines += 1
            }
        }
        if r.corruptedLines > 0 || r.tornTail {
            Log.journal.notice("metric journal_read corrupted=\(r.corruptedLines, privacy: .public) torn=\(r.tornTail, privacy: .public)")
        }
        return r
    }

    public static func read(_ url: URL) throws -> JournalReadResult {
        parse(try Data(contentsOf: url))
    }

    /// All `journal-*.jsonl` files in a device folder, by name (one per month).
    public static func journalFiles(in dir: URL) -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return items.filter { $0.lastPathComponent.hasPrefix("journal-") && $0.pathExtension == "jsonl" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public static func readDevice(_ dir: URL) -> JournalReadResult {
        var r = JournalReadResult()
        for f in journalFiles(in: dir) {
            if let x = try? read(f) { r.absorb(x) } else { r.corruptedLines += 1 }
        }
        return r
    }
}

/// Appends to this device's journal with fsync (R-34). One writer per file (R-36).
public struct JournalWriter: Sendable {
    public let dir: URL

    public init(dir: URL) { self.dir = dir }

    /// File name by the event's month (UTC): `journal-2026-10.jsonl`.
    public static func fileName(for date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.year, .month], from: date)
        return String(format: "journal-%04d-%02d.jsonl", c.year ?? 1970, c.month ?? 1)
    }

    public func append(_ events: [Event]) throws {
        guard let first = events.first else { return }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // A batch goes to the file of its first event's month; events of one batch are created at the same moment.
        let url = dir.appendingPathComponent(Self.fileName(for: first.ts))
        if !FileManager.default.fileExists(atPath: url.path) {
            guard FileManager.default.createFile(atPath: url.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
        }
        let h = try FileHandle(forUpdating: url)
        defer { try? h.close() }
        let end = try h.seekToEnd()
        var data = Data()
        if end > 0 {
            // R-39: if the previous write was cut off, the truncated line is closed with a newline
            // and skipped as corrupted on read; new events start on a new line.
            try h.seek(toOffset: end - 1)
            let last = try h.read(upToCount: 1)
            if last != Data([0x0A]) { data.append(0x0A) }
            try h.seekToEnd()
        }
        for e in events { data.append(Data(try e.line().utf8)); data.append(0x0A) }
        try h.write(contentsOf: data)
        try h.synchronize()
    }
}
