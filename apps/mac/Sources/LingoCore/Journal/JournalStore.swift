import Foundation

/// Local history store (R-34): this device's journal is the source of truth on the device, plus a cache of other devices' journals.
/// The index (HistoryState) is built from the journals at start-up and after every change. It works without a sync folder.
///
/// Layout of `base`:
/// ```
/// device.json                         id and name of this device
/// devices/<deviceId>/journal-*.jsonl  this device's journal (append-only, fsync)
/// cache/<otherId>/journal-*.jsonl     copies of other devices' journals from the sync folder
/// sync-state.json                     up to which seq this journal has been written to the folder (✓✓)
/// ```
public actor JournalStore {
    public nonisolated let base: URL
    public nonisolated let deviceID: String
    public nonisolated let deviceName: String
    private let writer: JournalWriter
    private var own: [Event] = []
    private var others: [Event] = []
    private var seq = 0
    private var lamport = 0
    private var pushedSeq = 0
    private(set) var readResult = JournalReadResult()
    public private(set) var state = HistoryState()
    private var observers: [UUID: @Sendable (HistoryState) -> Void] = [:]
    private let clock: @Sendable () -> Date

    public enum StoreError: Error, Equatable {
        /// The journals contain events with a newer schema version (R-39): writing is blocked until the app is updated.
        case readOnly
    }

    public var isReadOnly: Bool { readResult.newerSchema }
    public var corruptedLines: Int { readResult.corruptedLines }

    public nonisolated var ownDir: URL { base.appendingPathComponent("devices/\(deviceID)", isDirectory: true) }
    public nonisolated var cacheDir: URL { base.appendingPathComponent("cache", isDirectory: true) }

    /// `deviceID` is set explicitly only in tests and `lingo-eval`; otherwise it is read from `device.json` or created.
    public init(base: URL, deviceName: String, deviceID: String? = nil, clock: @escaping @Sendable () -> Date = { Date() }) throws {
        self.base = base
        self.deviceName = deviceName
        self.clock = clock
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let idURL = base.appendingPathComponent("device.json")
        if let id = deviceID {
            self.deviceID = id
        } else if let d = try? Data(contentsOf: idURL), let info = try? JSONDecoder().decode(DeviceInfo.self, from: d) {
            self.deviceID = info.id
        } else {
            self.deviceID = Self.newDeviceID()
        }
        if !FileManager.default.fileExists(atPath: idURL.path) {
            let info = DeviceInfo(id: self.deviceID, name: deviceName, platform: Self.platform, appVersion: Self.appVersion)
            try JSONEncoder.sorted.encode(info).write(to: idURL, options: .atomic)
        }
        writer = JournalWriter(dir: base.appendingPathComponent("devices/\(self.deviceID)", isDirectory: true))
        let st = base.appendingPathComponent("sync-state.json")
        if let d = try? Data(contentsOf: st), let s = try? JSONDecoder().decode(SyncState.self, from: d) { pushedSeq = s.pushedSeq }
        let l = Self.load(base: base, deviceID: self.deviceID, pushedSeq: pushedSeq)
        (own, others, readResult, seq, state) = (l.own, l.others, l.read, l.seq, l.state)
        lamport = state.maxLamport
    }

    /// "mac-" + 10 Crockford Base32 characters.
    public static func newDeviceID() -> String {
        let prefix: String
        #if os(macOS)
        prefix = "mac"
        #else
        prefix = "ios"
        #endif
        return "\(prefix)-\(ULID.make().suffix(10).lowercased())"
    }

    static var platform: String {
        #if os(macOS)
        "macOS"
        #else
        "iOS"
        #endif
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    struct SyncState: Codable { var pushedSeq: Int }

    // MARK: Reading

    private struct Loaded { var own: [Event]; var others: [Event]; var read: JournalReadResult; var seq: Int; var state: HistoryState }

    private static func load(base: URL, deviceID: String, pushedSeq: Int) -> Loaded {
        var r = JournalReader.readDevice(base.appendingPathComponent("devices/\(deviceID)", isDirectory: true))
        let own = r.events
        var o = JournalReadResult()
        let cache = base.appendingPathComponent("cache", isDirectory: true)
        let devices = (try? FileManager.default.contentsOfDirectory(at: cache, includingPropertiesForKeys: nil)) ?? []
        for d in devices where d.lastPathComponent != deviceID { o.absorb(JournalReader.readDevice(d)) }
        r.absorb(JournalReadResult.counts(of: o))
        let state = Merger.build(own + o.events) { e in e.device != deviceID || e.seq <= pushedSeq }
        return Loaded(own: own, others: o.events, read: r, seq: own.map(\.seq).max() ?? 0, state: state)
    }

    private func reloadSync() {
        let l = Self.load(base: base, deviceID: deviceID, pushedSeq: pushedSeq)
        (own, others, readResult, seq) = (l.own, l.others, l.read, l.seq)
        rebuild()
    }

    /// Re-read the journals from disk (after a sync).
    public func reload() {
        reloadSync()
    }

    private func rebuild() {
        let mine = deviceID, pushed = pushedSeq
        state = Merger.build(own + others) { e in e.device != mine || e.seq <= pushed }
        lamport = max(lamport, state.maxLamport)
        for o in observers.values { o(state) }
    }

    @discardableResult
    public func observe(_ f: @escaping @Sendable (HistoryState) -> Void) -> UUID {
        let id = UUID()
        observers[id] = f
        f(state)
        return id
    }

    public func removeObserver(_ id: UUID) { observers[id] = nil }

    // MARK: Writing

    /// Creates an event of this device, writes it to the journal with fsync and updates the index.
    @discardableResult
    public func append(_ type: String, session: String, payload: JSONValue = .object([:]), at date: Date? = nil) throws -> Event {
        try appendBatch([(type, session, payload)], at: date).first!
    }

    @discardableResult
    public func append<P: Encodable>(_ type: String, session: String, _ payload: P, at date: Date? = nil) throws -> Event {
        try append(type, session: session, payload: try JSONValue.from(payload), at: date)
    }

    /// Several events in one write (for example, an assistant reply and its `@fix`).
    @discardableResult
    public func appendBatch(_ items: [(type: String, session: String, payload: JSONValue)], at date: Date? = nil) throws -> [Event] {
        guard !readResult.newerSchema else { throw StoreError.readOnly }
        let now = date ?? clock()
        // Time is rounded to milliseconds: that is exactly how the journal stores it (R-37).
        let ts = Date(timeIntervalSince1970: (now.timeIntervalSince1970 * 1000).rounded() / 1000)
        var out: [Event] = []
        for item in items {
            seq += 1
            lamport += 1
            out.append(Event(id: ULID.make(date: ts), device: deviceID, seq: seq, lamport: lamport, ts: ts,
                             type: item.type, session: item.session, payload: item.payload))
        }
        do {
            try writer.append(out)
        } catch {
            seq -= out.count
            lamport -= out.count
            throw error
        }
        own += out
        rebuild()
        return out
    }

    // MARK: Sync (R-36, R-38)

    /// Writes this journal to the folder and reads the others. Folder errors never touch the local history (S-20).
    public func sync(with folder: SyncFolder) -> SyncStatus {
        let info = DeviceInfo(id: deviceID, name: deviceName, platform: Self.platform, appVersion: Self.appVersion)
        let seqBefore = seq
        do {
            try folder.push(deviceID: deviceID, localDir: ownDir, deviceInfo: info)
            pushedSeq = max(pushedSeq, seqBefore)
            try? JSONEncoder().encode(SyncState(pushedSeq: pushedSeq))
                .write(to: base.appendingPathComponent("sync-state.json"), options: .atomic)
            let r = try folder.pull(ownDeviceID: deviceID, cacheDir: cacheDir)
            reloadSync()
            Log.sync.notice("metric sync devices=\(r.devices, privacy: .public) updated=\(r.filesUpdated, privacy: .public) pending=\(r.pending, privacy: .public)")
            return r.pending > 0 ? .waitingICloud(clock()) : .synced(clock())
        } catch {
            Log.sync.error("sync failed: \(String(describing: error), privacy: .public)")
            return .unavailable(String(describing: error))
        }
    }

    /// The sync folder changed: ✓✓ are recalculated after the next write.
    public func resetSyncWatermark() {
        pushedSeq = 0
        try? FileManager.default.removeItem(at: base.appendingPathComponent("sync-state.json"))
        rebuild()
    }

    // MARK: Debugging and export

    public func allEvents() -> [Event] { own + others }
}

extension JournalReadResult {
    /// Counters only (no events) — so events are not duplicated when merging.
    static func counts(of r: JournalReadResult) -> JournalReadResult {
        var x = JournalReadResult()
        x.tornTail = r.tornTail
        x.corruptedLines = r.corruptedLines
        x.newerSchema = r.newerSchema
        return x
    }
}
