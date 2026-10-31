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

    @Test func restoreFillsMissingEventsInAnExistingFileWithoutChangingIt() throws {
        let src = tmp("m-src"), dst = tmp("m-dst")
        let name = "journal-2026-10.jsonl"
        for (base, lines) in [(src, "{\"a\":1}\n{\"b\":2}\n{\"c\":3}\n"), (dst, "{\"b\":2}\n{\"x\":9}\n")] {
            let dir = base.appendingPathComponent("devices/mac-aaaa", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try lines.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        let zip = tmp("m-zip").appendingPathComponent("b.zip")
        try HistoryBackup.export(base: src, to: zip)
        let r = try HistoryBackup.restore(from: zip, into: dst, ownDeviceID: "mac-aaaa")
        #expect(r.restored == 1)
        let merged = try String(contentsOf: dst.appendingPathComponent("devices/mac-aaaa/\(name)"), encoding: .utf8)
        #expect(merged == "{\"b\":2}\n{\"x\":9}\n{\"a\":1}\n{\"c\":3}\n")
        #expect(try HistoryBackup.restore(from: zip, into: dst, ownDeviceID: "mac-aaaa").restored == 0)
    }

    @Test func hostileZipOnlyRestoresJournalsOfTheRightShape() throws {
        let fm = FileManager.default
        let stage = tmp("h-stage"), root = stage.appendingPathComponent("Lingo-history", isDirectory: true)
        func put(_ rel: String, _ text: String = "{\"e\":1}\n") throws {
            let f = root.appendingPathComponent(rel)
            try fm.createDirectory(at: f.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: f, atomically: true, encoding: .utf8)
        }
        try put("devices/mac-aaaa/journal-2026-10.jsonl")          // own journal: restored
        try put("devices/web-bbbb/journal-2026-10.jsonl")          // foreign device: goes to the cache
        try put("cache/mac-aaaa/journal-2026-10.jsonl")            // a cache copy claiming to be this device: rejected
        try put("device.json", "{\"id\":\"mac-aaaa\"}")              // identity: rejected
        try put("sync-state.json", "{}")                            // sync state: rejected
        try put("devices/mac-aaaa/notes.txt", "x")                  // not a journal: rejected
        try put("devices/mac-aaaa/deeper/journal-2026-10.jsonl")    // wrong depth: rejected
        try fm.createSymbolicLink(at: root.appendingPathComponent("devices/mac-aaaa/journal-2026-11.jsonl"), withDestinationURL: URL(fileURLWithPath: "/etc/hosts"))
        let zip = tmp("h-zip").appendingPathComponent("h.zip")
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        p.arguments = ["-c", "-k", "--keepParent", root.path, zip.path]
        try p.run(); p.waitUntilExit()
        let base = tmp("h-base")
        let r = try HistoryBackup.restore(from: zip, into: base, ownDeviceID: "mac-aaaa")
        #expect(r.restored == 2)
        #expect(fm.fileExists(atPath: base.appendingPathComponent("devices/mac-aaaa/journal-2026-10.jsonl").path))
        #expect(fm.fileExists(atPath: base.appendingPathComponent("cache/web-bbbb/journal-2026-10.jsonl").path))
        #expect(!fm.fileExists(atPath: base.appendingPathComponent("cache/mac-aaaa").path))
        #expect(!fm.fileExists(atPath: base.appendingPathComponent("device.json").path))
        #expect(!fm.fileExists(atPath: base.appendingPathComponent("sync-state.json").path))
        #expect(!fm.fileExists(atPath: base.appendingPathComponent("devices/mac-aaaa/journal-2026-11.jsonl").path))
    }

    @Test func exportContainsOnlyJournals() throws {
        let fm = FileManager.default
        let base = tmp("e-base")
        let dir = base.appendingPathComponent("devices/mac-aaaa", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try "{\"e\":1}\n".write(to: dir.appendingPathComponent("journal-2026-10.jsonl"), atomically: true, encoding: .utf8)
        try "{\"id\":\"mac-aaaa\"}".write(to: base.appendingPathComponent("device.json"), atomically: true, encoding: .utf8)
        try "{}".write(to: base.appendingPathComponent("sync-state.json"), atomically: true, encoding: .utf8)
        try "secret".write(to: dir.appendingPathComponent("keys.txt"), atomically: true, encoding: .utf8)
        let zip = tmp("e-zip").appendingPathComponent("e.zip")
        try HistoryBackup.export(base: base, to: zip)
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/zipinfo"); p.arguments = ["-1", zip.path]
        let out = Pipe(); p.standardOutput = out
        try p.run(); let data = out.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        let files = String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init).filter { !$0.hasSuffix("/") }
        #expect(files == ["Lingo-history/devices/mac-aaaa/journal-2026-10.jsonl"])
    }
}
