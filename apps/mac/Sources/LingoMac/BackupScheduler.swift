import Foundation
import LingoCore

/// Daily automatic backup (MR-04, plan P-04b): once a day while the app runs (checked hourly), or at the next launch, into the folder
/// the learner chose. The export is atomic (`HistoryBackup.export`); the newest 14 daily files are kept. The clock is injected for tests.
@MainActor
final class BackupScheduler {
    enum Status: Equatable {
        case off
        case done(day: String)
        case failed(String)
    }

    let base: URL
    let clock: () -> Date
    let calendar: Calendar
    private(set) var folder: SyncFolder?
    private(set) var status: Status = .off
    var onStatus: (Status) -> Void = { _ in }
    private var timer: Task<Void, Never>?

    init(base: URL, clock: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.base = base
        self.clock = clock
        self.calendar = calendar
    }

    /// The local calendar day, "yyyy-MM-dd" (the name of the daily file).
    func today() -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: clock())
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func setFolder(_ f: SyncFolder?) {
        folder = f
        if f == nil { report(.off) }
    }

    /// Checks now, then every hour while the app runs (a Mac that slept past midnight backs up within the hour).
    func start(every interval: Duration = .seconds(3600)) {
        timer?.cancel()
        timer = Task { [weak self] in
            while !Task.isCancelled {
                _ = await self?.runIfDue()
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stop() { timer?.cancel(); timer = nil }

    /// Writes today's backup if it is not there yet. Returns the new file, nil when nothing was due. Errors (a revoked folder, a full
    /// disk) are reported in `status` and never thrown at the caller.
    @discardableResult
    func runIfDue(force: Bool = false) async -> URL? {
        guard let f = folder else { report(.off); return nil }
        let day = today(), base = base
        let result: Result<URL?, Error> = await Task.detached {
            Result {
                try f.withAccess {
                    try f.checkAvailable()
                    guard force else { return try HistoryBackup.dailyBackupIfDue(base: base, folder: f.picked, today: day) }
                    // "Back up now" replaces today's file atomically: a failed run keeps the earlier copy.
                    let dest = f.picked.appendingPathComponent(HistoryBackup.dailyName(for: day))
                    try HistoryBackup.export(base: base, to: dest)
                    return dest
                }
            }
        }.value
        switch result {
        case .success(let url): report(.done(day: day)); return url
        case .failure(let e): report(.failed(e.localizedDescription)); return nil
        }
    }

    private func report(_ s: Status) {
        status = s
        onStatus(s)
    }
}
