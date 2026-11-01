import Foundation
import Testing
import LingoCore
@testable import LingoMac

/// Daily backup scheduling (MR-04, P-04b) with an injected clock.
@MainActor
@Suite struct BackupSchedulerTests {
    final class Clock { var now: Date; init(_ d: Date) { now = d } }

    private func tmp(_ name: String) -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("lingo-sched-\(name)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    private func scheduler(_ name: String, at date: Date) async throws -> (BackupScheduler, Clock, URL) {
        let store = try JournalStore(base: tmp("\(name)-base"), deviceName: "Mac", deviceID: "mac-aaaa")
        try await store.append(EventType.sessionCreated, session: "s1",
                               Payload.SessionCreated(title: "T", settings: SessionSettings(lang: .de, mode: .free, corrections: [.inline])))
        let clock = Clock(date)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let b = BackupScheduler(base: store.base, clock: { clock.now }, calendar: cal)
        let folder = tmp("\(name)-folder")
        return (b, clock, folder)
    }

    private func names(_ folder: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0.hasSuffix(".zip") }.sorted()
    }

    @Test func onceADayAndAgainAfterMidnight() async throws {
        // 2026-10-31 23:30 Berlin (CET), then 00:10 the next day.
        let (b, clock, folder) = try await scheduler("daily", at: Date(timeIntervalSince1970: 1_793_485_800))
        b.setFolder(SyncFolder(picked: folder))
        #expect(b.today() == "2026-10-31")
        #expect(await b.runIfDue() != nil)
        #expect(await b.runIfDue() == nil)  // the same day: nothing to do
        #expect(b.status == .done(day: "2026-10-31"))
        clock.now = clock.now.addingTimeInterval(40 * 60)
        #expect(b.today() == "2026-11-01")
        #expect(await b.runIfDue() != nil)
        #expect(names(folder) == [HistoryBackup.dailyName(for: "2026-10-31"), HistoryBackup.dailyName(for: "2026-11-01")])
    }

    @Test func offWithoutAFolderAndFailedWhenTheFolderIsGone() async throws {
        let (b, _, folder) = try await scheduler("off", at: Date(timeIntervalSince1970: 1_793_485_800))
        #expect(await b.runIfDue() == nil)
        #expect(b.status == .off)
        var reported: [BackupScheduler.Status] = []
        b.onStatus = { reported.append($0) }
        b.setFolder(SyncFolder(picked: folder.appendingPathComponent("missing")))
        #expect(await b.runIfDue() == nil)  // a revoked or removed folder is reported, never thrown
        guard case .failed(let why) = b.status else { Issue.record("expected a failure, got \(b.status)"); return }
        #expect(why == String(localized: "folder not found"))  // the reason, not "The operation couldn't be completed"
        #expect(reported == [.running, .failed(why)])
        #expect(names(folder).isEmpty)
    }

    @Test func backUpNowReplacesTodaysFile() async throws {
        let (b, _, folder) = try await scheduler("now", at: Date(timeIntervalSince1970: 1_793_485_800))
        b.setFolder(SyncFolder(picked: folder))
        let first = try #require(await b.runIfDue())
        let before = try FileManager.default.attributesOfItem(atPath: first.path)[.modificationDate] as? Date
        try await Task.sleep(for: .milliseconds(1100))
        #expect(await b.runIfDue(force: true) == first)
        let after = try FileManager.default.attributesOfItem(atPath: first.path)[.modificationDate] as? Date
        #expect(after != before)
        #expect(names(folder).count == 1)
    }

    @Test func twoRunsAtOnceWriteOneFileWithoutAFalseFailure() async throws {
        let (b, _, folder) = try await scheduler("twice", at: Date(timeIntervalSince1970: 1_793_485_800))
        b.setFolder(SyncFolder(picked: folder))
        async let first = b.runIfDue()
        async let second = b.runIfDue(force: true)
        let results = await [first, second]
        #expect(results.compactMap { $0 }.count >= 1)
        #expect(b.status == .done(day: "2026-10-31"))
        #expect(names(folder) == [HistoryBackup.dailyName(for: "2026-10-31")])
    }

    @Test func aSavedFolderThatCannotBeResolvedIsReportedAndRetried() async throws {
        let (b, _, _) = try await scheduler("lost", at: Date(timeIntervalSince1970: 1_793_485_800))
        b.setBookmark(Data([0, 1, 2, 3]))  // like an unplugged disk: the bookmark does not resolve
        guard case .failed = b.status else { Issue.record("expected a failure, got \(b.status)"); return }
        #expect(await b.runIfDue() == nil)
        guard case .failed = b.status else { Issue.record("still expected a failure, got \(b.status)"); return }
        b.setBookmark(nil)
        #expect(b.status == .off)
    }

    @Test func pruningKeepsOtherFiles() throws {
        let folder = tmp("prune")
        for n in ["Lingo-history-2026-10-01.zip", "Lingo-history-2026-10-02.zip", "Lingo-history-2026-10-03.zip", "Lingo-history-old.zip", "notes.txt"] {
            try Data().write(to: folder.appendingPathComponent(n))
        }
        HistoryBackup.prune(folder: folder, keep: 2)
        let left = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        #expect(left == ["Lingo-history-2026-10-02.zip", "Lingo-history-2026-10-03.zip", "Lingo-history-old.zip", "notes.txt"])
    }
}
