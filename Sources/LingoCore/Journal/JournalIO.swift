import Foundation

/// Результат чтения журнала (R-39).
public struct JournalReadResult: Sendable {
    public var events: [Event] = []
    /// Оборванная последняя строка (нет перевода строки в конце файла) — игнорируется.
    public var tornTail = false
    /// Повреждённые строки — пропускаются, считаются метрикой.
    public var corruptedLines = 0
    /// В журнале есть события старшей версии схемы — «только чтение» с предупреждением.
    public var newerSchema = false

    public init() {}

    public mutating func absorb(_ other: JournalReadResult) {
        events += other.events
        tornTail = tornTail || other.tornTail
        corruptedLines += other.corruptedLines
        newerSchema = newerSchema || other.newerSchema
    }
}

/// Чтение JSON Lines (R-39).
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

    /// Все файлы `journal-*.jsonl` в папке устройства, по имени (по месяцам).
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

/// Дописывание в журнал своего устройства с fsync (R-34). Один писатель на файл (R-36).
public struct JournalWriter: Sendable {
    public let dir: URL

    public init(dir: URL) { self.dir = dir }

    /// Имя файла по месяцу события (UTC): `journal-2026-10.jsonl`.
    public static func fileName(for date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.year, .month], from: date)
        return String(format: "journal-%04d-%02d.jsonl", c.year ?? 1970, c.month ?? 1)
    }

    public func append(_ events: [Event]) throws {
        guard let first = events.first else { return }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Пачка пишется в файл месяца первого события; соседние события одной пачки создаются в один момент.
        let url = dir.appendingPathComponent(Self.fileName(for: first.ts))
        if !FileManager.default.fileExists(atPath: url.path) {
            guard FileManager.default.createFile(atPath: url.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
        }
        let h = try FileHandle(forUpdating: url)
        defer { try? h.close() }
        let end = try h.seekToEnd()
        var data = Data()
        if end > 0 {
            // R-39: если прошлая запись оборвалась, оборванная строка закрывается переводом строки
            // и при чтении пропускается как повреждённая; новые события идут с новой строки.
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
