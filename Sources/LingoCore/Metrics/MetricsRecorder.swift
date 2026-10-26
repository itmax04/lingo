import Foundation

/// Turn marks (R-47): `speech_end`, `stt_final`, `llm_first_token`, `first_audio`, `reply_end` + memory.
/// JSON Lines in `<base>/metrics/metrics-<yyyy-mm-dd>.jsonl`. Utterance texts are not written — only lengths, languages and identifiers.
public final class MetricsRecorder: @unchecked Sendable {
    public let dir: URL
    private let lock = NSLock()
    private var turns: [String: [String: Double]] = [:]
    private var meta: [String: [String: String]] = [:]

    public init(dir: URL) {
        self.dir = dir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// Time in seconds on the monotonic clock.
    public static func now() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1e9 }

    public func mark(_ turn: String, _ name: String, at t: Double = MetricsRecorder.now()) {
        lock.withLock { turns[turn, default: [:]][name] = turns[turn]?[name] ?? t }
    }

    public func note(_ turn: String, _ key: String, _ value: String) {
        lock.withLock { meta[turn, default: [:]][key] = value }
    }

    /// The turn is over — one line to the file.
    public func flush(_ turn: String) {
        let (marks, m) = lock.withLock { (turns.removeValue(forKey: turn) ?? [:], meta.removeValue(forKey: turn) ?? [:]) }
        guard !marks.isEmpty else { return }
        var obj: [String: Any] = ["type": "turn", "turn": turn, "ts": Event.formatTS(Date()), "footprint_mb": Int(Memory.mb(Memory.physFootprint()))]
        for (k, v) in marks { obj[k] = v }
        for (k, v) in m { obj[k] = v }
        write(obj)
    }

    public func memorySample() {
        write(["type": "memory", "ts": Event.formatTS(Date()), "footprint_mb": Int(Memory.mb(Memory.physFootprint()))])
    }

    private func write(_ obj: [String: Any]) {
        guard let d = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]) else { return }
        let f = dir.appendingPathComponent("metrics-\(Self.day()).jsonl")
        if !FileManager.default.fileExists(atPath: f.path) { FileManager.default.createFile(atPath: f.path, contents: nil) }
        guard let h = try? FileHandle(forWritingTo: f) else { return }
        defer { try? h.close() }
        _ = try? h.seekToEnd()
        try? h.write(contentsOf: d + Data([0x0A]))
    }

    public static func day() -> String {
        let c = Calendar(identifier: .gregorian).dateComponents(in: .current, from: Date())
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
