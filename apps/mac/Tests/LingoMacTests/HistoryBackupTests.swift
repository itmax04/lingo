import Foundation
import Testing
import LingoCore
@testable import LingoMac

@Suite struct HistoryBackupTests {
    private func tmp(_ name: String) -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("lingo-backup-\(name)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    private let settings = SessionSettings(lang: .de, mode: .free, topic: "Wohnort", level: "A2", corrections: [.inline])

    private func seed(_ store: JournalStore, session: String, texts: [String]) async throws {
        try await store.append(EventType.sessionCreated, session: session, Payload.SessionCreated(title: "T-\(session)", settings: settings))
        for (i, t) in texts.enumerated() {
            try await store.append(EventType.messageCreated, session: session, Payload.MessageCreated(role: .user, text: t, lang: .de),
                                   at: Date(timeIntervalSince1970: 1_761_400_000 + Double(i)))
        }
    }

    @Test func exportThenRestoreIntoAFreshBaseGivesTheSameState() async throws {
        let src = try JournalStore(base: tmp("src"), deviceName: "Mac", deviceID: "mac-aaaa")
        try await seed(src, session: "s1", texts: ["eins", "zwei", "drei"])
        // A copy of another device's journal in the cache (R-34) must be exported too.
        let other = try JournalStore(base: tmp("other"), deviceName: "Web", deviceID: "web-bbbb")
        try await seed(other, session: "s2", texts: ["vier"])
        let cache = src.base.appendingPathComponent("cache/web-bbbb", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        for f in try FileManager.default.contentsOfDirectory(at: other.ownDir, includingPropertiesForKeys: nil) {
            try FileManager.default.copyItem(at: f, to: cache.appendingPathComponent(f.lastPathComponent))
        }
        await src.reload()
        let before = await src.state

        let zip = tmp("zip").appendingPathComponent("backup.zip")
        try HistoryBackup.export(base: src.base, to: zip)

        let freshBase = tmp("fresh")
        let report = try HistoryBackup.restore(from: zip, into: freshBase, ownDeviceID: "mac-aaaa")
        #expect(report.restored >= 2 && report.rejected == 0 && report.skippedExisting == 0)
        let restored = try JournalStore(base: freshBase, deviceName: "Mac", deviceID: "mac-aaaa")
        let after = await restored.state
        #expect(after.sessions.keys.sorted() == before.sessions.keys.sorted())
        #expect(after.messages["s1"]?.map(\.text) == ["eins", "zwei", "drei"])
        #expect(after.messages["s2"]?.map(\.text) == ["vier"])
    }

    @Test func restoreKeepsExistingFilesAndSendsForeignDevicesToTheCache() async throws {
        let src = try JournalStore(base: tmp("src2"), deviceName: "Mac", deviceID: "mac-aaaa")
        try await seed(src, session: "s1", texts: ["eins"])
        let zip = tmp("zip2").appendingPathComponent("backup.zip")
        try HistoryBackup.export(base: src.base, to: zip)

        // Restoring on a different Mac: the journal of mac-aaaa becomes a cache copy, never this device's own journal.
        let otherBase = tmp("otherMac")
        let r1 = try HistoryBackup.restore(from: zip, into: otherBase, ownDeviceID: "mac-cccc")
        #expect(r1.restored >= 1)
        #expect(FileManager.default.fileExists(atPath: otherBase.appendingPathComponent("cache/mac-aaaa").path))
        #expect(!FileManager.default.fileExists(atPath: otherBase.appendingPathComponent("devices/mac-aaaa").path))
        // Running it again changes nothing.
        let r2 = try HistoryBackup.restore(from: zip, into: otherBase, ownDeviceID: "mac-cccc")
        #expect(r2.restored == 0 && r2.skippedExisting == r1.restored)
    }

    @Test func notABackupIsRejectedAndPathsAreValidated() throws {
        let dir = tmp("junk")
        let file = dir.appendingPathComponent("x.txt")
        try "hello".write(to: file, atomically: true, encoding: .utf8)
        let zip = dir.appendingPathComponent("x.zip")
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto"); p.arguments = ["-c", "-k", file.path, zip.path]
        try p.run(); p.waitUntilExit()
        #expect(throws: HistoryBackup.Failure.self) { try HistoryBackup.restore(from: zip, into: tmp("t"), ownDeviceID: "mac-aaaa") }
        #expect(!HistoryBackup.isSafeComponent("..") && !HistoryBackup.isSafeComponent("a/b") && HistoryBackup.isSafeComponent("mac-aaaa"))
        #expect(HistoryBackup.isJournalName("journal-2026-10.jsonl") && !HistoryBackup.isJournalName("device.json"))
    }

    @Test func dailyBackupWritesOncePerDayAndKeepsTheNewest() async throws {
        let src = try JournalStore(base: tmp("src3"), deviceName: "Mac", deviceID: "mac-aaaa")
        try await seed(src, session: "s1", texts: ["eins"])
        let folder = tmp("folder")
        #expect(try HistoryBackup.dailyBackupIfDue(base: src.base, folder: folder, today: "2026-10-01", keep: 2) != nil)
        #expect(try HistoryBackup.dailyBackupIfDue(base: src.base, folder: folder, today: "2026-10-01", keep: 2) == nil)
        _ = try HistoryBackup.dailyBackupIfDue(base: src.base, folder: folder, today: "2026-10-02", keep: 2)
        _ = try HistoryBackup.dailyBackupIfDue(base: src.base, folder: folder, today: "2026-10-03", keep: 2)
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        #expect(names == [HistoryBackup.dailyName(for: "2026-10-02"), HistoryBackup.dailyName(for: "2026-10-03")])
    }
}
