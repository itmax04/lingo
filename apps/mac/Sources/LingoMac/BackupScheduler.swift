import Foundation
import LingoCore

/// Daily automatic backup (MR-04, plan P-04b): once a day while the app runs (checked hourly), or at the next launch, into the folder
/// the learner chose. The export is atomic (`HistoryBackup.export`); the newest 14 daily files are kept. The clock is injected for tests.
@MainActor
final class BackupScheduler {
    enum Status: Equatable {
        case off
        case running
        case done(day: String)
        case failed(String)
    }

    let base: URL
    let clock: () -> Date
    let calendar: Calendar
    private(set) var folder: SyncFolder?
    /// A saved folder that could not be resolved (an unplugged disk): retried on every run, reported until it comes back.
    private var bookmark: Data?
    private(set) var status: Status = .off
    var onStatus: (Status) -> Void = { _ in }
    private var timer: Task<Void, Never>?
    /// The run in progress: the timer, choosing a folder and "Back up now" never export at the same time.
    private var inFlight: Task<URL?, Never>?
    /// Bumped when the folder changes, so a run that finishes late does not report for a folder that is no longer used.
    private var generation = 0

    init(base: URL, clock: @escaping () -> Date = Date.init, calendar: Calendar = .autoupdatingCurrent) {
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
        generation += 1
        folder = f
        bookmark = nil
        if f == nil { report(.off) }
    }

    /// A saved bookmark: resolved now and on every run until it works (and refreshed by the caller when stale).
    func setBookmark(_ data: Data?) {
        guard let data else { setFolder(nil); return }
        if let r = try? SyncFolder.resolve(bookmark: data) { setFolder(r.folder) } else {
            generation += 1
            folder = nil
            bookmark = data
            report(.failed(String(localized: "the backup folder is not available")))
        }
    }

    /// Checks now, then every hour while the app runs (a Mac that slept past midnight backs up within the hour).
    func start(every interval: Duration = .seconds(3600)) {
        timer?.cancel()
        timer = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                _ = await self.runIfDue()
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stop() { timer?.cancel(); timer = nil }

    /// Writes today's backup if it is not there yet ("Back up now": `force`, replacing today's file). Returns the new file, nil when
    /// nothing was due. Errors (a revoked folder, a full disk) are reported in `status` and never thrown at the caller.
    @discardableResult
    func runIfDue(force: Bool = false) async -> URL? {
        if let running = inFlight { _ = await running.value }  // one run at a time; the next one sees today's file
        if folder == nil, let data = bookmark, let r = try? SyncFolder.resolve(bookmark: data) { setFolder(r.folder) }
        guard let f = folder else {
            if bookmark != nil { report(.failed(String(localized: "the backup folder is not available"))) } else { report(.off) }
            return nil
        }
        let day = today(), base = base, gen = generation
        report(.running)
        let task = Task.detached { () -> Result<URL?, Error> in
            Result {
                try f.withAccess {
                    try f.checkAvailable()
                    guard force else { return try HistoryBackup.dailyBackupIfDue(base: base, folder: f.picked, today: day) }
                    // "Back up now" replaces today's file atomically: a failed run keeps the earlier copy.
                    let dest = f.picked.appendingPathComponent(HistoryBackup.dailyName(for: day))
                    try HistoryBackup.export(base: base, to: dest)
                    HistoryBackup.prune(folder: f.picked, except: dest.lastPathComponent)
                    return dest
                }
            }
        }
        let run = Task { () -> URL? in
            switch await task.value {
            case .success(let url): if gen == generation { report(.done(day: day)) }; return url
            case .failure(let e): if gen == generation { report(.failed(e.localizedDescription)) }; return nil
            }
        }
        inFlight = run
        let url = await run.value
        if inFlight == run { inFlight = nil }
        return url
    }

    private func report(_ s: Status) {
        status = s
        onStatus(s)
    }
}
