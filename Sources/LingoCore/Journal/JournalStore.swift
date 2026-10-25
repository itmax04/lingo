import Foundation

/// Локальное хранилище истории (R-34): свой журнал — источник истины на устройстве, плюс кэш журналов других устройств.
/// Индекс (HistoryState) строится из журналов при старте и после каждого изменения. Работа не зависит от папки синхронизации.
///
/// Раскладка `base`:
/// ```
/// device.json                         id и имя этого устройства
/// devices/<deviceId>/journal-*.jsonl  свой журнал (только дописывание, fsync)
/// cache/<otherId>/journal-*.jsonl     копии чужих журналов из папки синхронизации
/// sync-state.json                     до какого seq свой журнал записан в папку (✓✓)
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
        /// В журналах есть события старшей версии схемы (R-39): запись запрещена до обновления приложения.
        case readOnly
    }

    public var isReadOnly: Bool { readResult.newerSchema }
    public var corruptedLines: Int { readResult.corruptedLines }

    public nonisolated var ownDir: URL { base.appendingPathComponent("devices/\(deviceID)", isDirectory: true) }
    public nonisolated var cacheDir: URL { base.appendingPathComponent("cache", isDirectory: true) }

    /// `deviceID` задаётся явно только в тестах и `lingo-eval`; иначе берётся из `device.json` или создаётся.
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

    /// «mac-» + 10 символов Crockford Base32.
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

    // MARK: Чтение

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

    /// Перечитать журналы с диска (после синхронизации).
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

    // MARK: Запись

    /// Создаёт событие своего устройства, пишет его в журнал с fsync и обновляет индекс.
    @discardableResult
    public func append(_ type: String, session: String, payload: JSONValue = .object([:]), at date: Date? = nil) throws -> Event {
        try appendBatch([(type, session, payload)], at: date).first!
    }

    @discardableResult
    public func append<P: Encodable>(_ type: String, session: String, _ payload: P, at date: Date? = nil) throws -> Event {
        try append(type, session: session, payload: try JSONValue.from(payload), at: date)
    }

    /// Несколько событий одной записью (например, ответ помощника и его `@fix`).
    @discardableResult
    public func appendBatch(_ items: [(type: String, session: String, payload: JSONValue)], at date: Date? = nil) throws -> [Event] {
        guard !readResult.newerSchema else { throw StoreError.readOnly }
        let now = date ?? clock()
        // Время округляется до миллисекунд: в журнале оно хранится именно так (R-37).
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

    // MARK: Синхронизация (R-36, R-38)

    /// Запись своего журнала в папку и чтение чужих. Ошибки папки не трогают локальную историю (S-20).
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

    /// Папка синхронизации сменилась: ✓✓ считаются заново после следующей записи.
    public func resetSyncWatermark() {
        pushedSeq = 0
        try? FileManager.default.removeItem(at: base.appendingPathComponent("sync-state.json"))
        rebuild()
    }

    // MARK: Отладка и экспорт

    public func allEvents() -> [Event] { own + others }
}

extension JournalReadResult {
    /// Только счётчики (без событий) — чтобы не дублировать события при объединении.
    static func counts(of r: JournalReadResult) -> JournalReadResult {
        var x = JournalReadResult()
        x.tornTail = r.tornTail
        x.corruptedLines = r.corruptedLines
        x.newerSchema = r.newerSchema
        return x
    }
}
