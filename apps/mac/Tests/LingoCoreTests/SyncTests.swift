import Foundation
import Testing
@testable import LingoCore

@Suite struct SyncTests {
    /// S-19: two offline devices write 25 messages each into one session; after a sync both have 50 messages
    /// in the same order, without duplicates or losses.
    @Test func twoWritersTwentyFiveEach() async throws {
        let shared = tempDir("icloud")
        let folder = SyncFolder(picked: shared.appendingPathComponent("Lingo"))
        try FileManager.default.createDirectory(at: folder.picked, withIntermediateDirectories: true)
        let a = try JournalStore(base: tempDir("a"), deviceName: "Mac", deviceID: "mac-aaaa")
        let b = try JournalStore(base: tempDir("b"), deviceName: "iPhone", deviceID: "ios-bbbb")

        try await a.append(EventType.sessionCreated, session: "s1", Payload.SessionCreated(title: "Wohnort", settings: settingsDE))
        _ = await a.sync(with: folder)
        _ = await b.sync(with: folder)
        #expect(await b.state.sessions["s1"] != nil)

        // "Offline": they write independently, alternating, with equal and close times.
        let t0 = Date(timeIntervalSince1970: 1_761_400_000)
        for i in 0..<25 {
            let t = t0.addingTimeInterval(Double(i))
            try await a.append(EventType.messageCreated, session: "s1", Payload.MessageCreated(role: .user, text: "A\(i)", lang: .de), at: t)
            try await b.append(EventType.messageCreated, session: "s1", Payload.MessageCreated(role: .user, text: "B\(i)", lang: .de), at: t)
        }
        _ = await a.sync(with: folder)
        _ = await b.sync(with: folder)
        _ = await a.sync(with: folder)

        let ma = await a.state.messages["s1"]!, mb = await b.state.messages["s1"]!
        #expect(ma.count == 50 && mb.count == 50)
        #expect(Set(ma.map(\.id)).count == 50)
        #expect(ma.map(\.id) == mb.map(\.id))
        // A repeated sync duplicates nothing.
        _ = await b.sync(with: folder)
        #expect(await b.state.messages["s1"]!.count == 50)
        // Each device writes only to its own folder.
        let devs = try FileManager.default.contentsOfDirectory(atPath: folder.devicesDir.path).sorted()
        #expect(devs == ["ios-bbbb", "mac-aaaa"])
        // ✓✓: own messages are written to the folder.
        let allSynced = ma.allSatisfy { $0.synced }
        #expect(allSynced)
    }

    /// S-20: the folder is unavailable — work continues locally, history is not lost, ✓✓ is not set.
    @Test func unavailableFolderKeepsLocalHistory() async throws {
        let shared = tempDir("gone")
        let folder = SyncFolder(picked: shared.appendingPathComponent("Lingo"))
        let base = tempDir("a")
        let a = try JournalStore(base: base, deviceName: "Mac", deviceID: "mac-aaaa")
        try await a.append(EventType.sessionCreated, session: "s1", Payload.SessionCreated(title: "X", settings: settingsDE))
        try await a.append(EventType.messageCreated, session: "s1", Payload.MessageCreated(role: .user, text: "Hallo", lang: .de))
        let status = await a.sync(with: folder)
        guard case .unavailable = status else { Issue.record("expected unavailable, got \(status)"); return }
        #expect(status.title == "Sync folder unavailable — choose it again")
        #expect(await a.state.messages["s1"]?.first?.synced == false)
        // Restart: the history is still there.
        let again = try JournalStore(base: base, deviceName: "Mac")
        #expect(again.deviceID == "mac-aaaa")
        #expect(await again.state.messages["s1"]?.count == 1)
    }

    /// R-39: another device's journal with a newer schema version → read-only.
    @Test func newerSchemaFromOtherDeviceMakesStoreReadOnly() async throws {
        let base = tempDir("a")
        let cache = base.appendingPathComponent("cache/ios-new", isDirectory: true)
        var e = ev("N1", device: "ios-new", seq: 1, lamport: 1, ms: 1000, type: EventType.messageCreated, payload: msg("x"))
        e.v = Event.schemaVersion + 1
        try JournalWriter(dir: cache).append([e])
        let a = try JournalStore(base: base, deviceName: "Mac", deviceID: "mac-aaaa")
        #expect(await a.isReadOnly)
        await #expect(throws: JournalStore.StoreError.readOnly) {
            try await a.append(EventType.messageCreated, session: "s1", payload: msg("y"))
        }
    }

    /// Lamport continues after a restart and after reading other devices' events.
    @Test func lamportAndSeqContinue() async throws {
        let base = tempDir("a")
        let a = try JournalStore(base: base, deviceName: "Mac", deviceID: "mac-aaaa")
        let e1 = try await a.append(EventType.messageCreated, session: "s1", payload: msg("1"))
        let cache = base.appendingPathComponent("cache/ios-b", isDirectory: true)
        try JournalWriter(dir: cache).append([ev("O", device: "ios-b", seq: 1, lamport: 40, ms: 1000, type: EventType.messageCreated, payload: msg("o"))])
        let a2 = try JournalStore(base: base, deviceName: "Mac")
        let e2 = try await a2.append(EventType.messageCreated, session: "s1", payload: msg("2"))
        #expect(e2.seq == e1.seq + 1)
        #expect(e2.lamport == 41)
    }
}

extension SyncStatus {
    var date: Date? {
        switch self {
        case .synced(let d), .waitingICloud(let d): return d
        default: return nil
        }
    }
}
