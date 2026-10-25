import Foundation

/// Когда синхронизировать (R-38): при запуске, при возврате в активное состояние, раз в 60 с, пока приложение активно,
/// после завершения сессии и по кнопке. Синхронизация идёт в фоне и никогда не блокирует разговор; запросы во время
/// идущей синхронизации склеиваются в один следующий проход.
public actor SyncScheduler {
    public enum Reason: String, Sendable { case launch, becameActive, timer, sessionEnded, manual, folderChanged }

    private let store: JournalStore
    private var folder: SyncFolder?
    private var running = false
    private var again = false
    private var timer: Task<Void, Never>?
    private let interval: Duration
    private var onStatus: (@Sendable (SyncStatus) -> Void)?
    public private(set) var status: SyncStatus = .notConfigured

    public init(store: JournalStore, folder: SyncFolder?, interval: Duration = .seconds(60)) {
        self.store = store
        self.folder = folder
        self.interval = interval
    }

    public func setStatusHandler(_ f: @escaping @Sendable (SyncStatus) -> Void) {
        onStatus = f
        f(status)
    }

    public func setFolder(_ f: SyncFolder?) async {
        folder = f
        await store.resetSyncWatermark()
        publish(f == nil ? .notConfigured : status)
        if f != nil { trigger(.folderChanged) }
    }

    /// Таймер работает, пока приложение активно (R-38).
    public func setActive(_ active: Bool) {
        timer?.cancel()
        timer = nil
        guard active else { return }
        let iv = interval
        timer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: iv)
                if Task.isCancelled { break }
                await self?.trigger(.timer)
            }
        }
        trigger(.becameActive)
    }

    public func trigger(_ reason: Reason) {
        guard folder != nil else { publish(.notConfigured); return }
        if running { again = true; return }
        running = true
        Task { await self.runLoop(reason) }
    }

    /// Синхронизация сейчас с ожиданием результата (кнопка «Синхронизировать», тесты).
    public func syncNow() async -> SyncStatus {
        guard let f = folder else { publish(.notConfigured); return .notConfigured }
        let s = await store.sync(with: f)
        publish(s)
        return s
    }

    private func runLoop(_ reason: Reason) async {
        repeat {
            again = false
            guard let f = folder else { publish(.notConfigured); break }
            Log.sync.notice("sync start reason=\(reason.rawValue, privacy: .public)")
            publish(.syncing)
            let s = await store.sync(with: f)
            publish(s)
        } while again
        running = false
    }

    private func publish(_ s: SyncStatus) {
        // «Синхронизация…» не перекрывает последний известный результат в сайдбаре дольше одного прохода.
        status = s
        onStatus?(s)
    }
}
