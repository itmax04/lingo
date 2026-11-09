import Foundation
import Testing
@testable import LingoCore

/// LINGO-10 G-1: BR-01 (Activity fields), BR-02a (part values), BR-39a (rollback), BAC-03, BAC-19.
@Suite struct GoetheActivityTests {
    /// The 18 Goethe ids of the build before LINGO-10 (pinned): an older build validates against these only.
    static let oldIDs: [[String]] = [
        ["park", "repair", "welcome", "books", "walk", "cooking"].map { "b1-plan-" + $0 },
        ["bicycle", "online", "cooking", "courses", "garden", "travel"].map { "b1-talk-" + $0 },
        ["bicycle", "online", "cooking", "courses", "garden", "travel"].map { "b1-discuss-" + $0 },
    ].map { $0 }

    static func json(_ activity: JSONValue) throws -> SessionSettings {
        var obj = try #require({ () -> [String: JSONValue]? in
            if case .object(let o) = try JSONValue.from(ExamKind.goetheB1.settings(tasks: ExamKind.goetheB1.drawTasks())!) { return o }
            return nil
        }())
        obj["activity"] = activity
        return try JSONValue.object(obj).decode(SessionSettings.self)
    }
    static func exam(_ extra: [String: JSONValue], tasks: [String]) -> JSONValue {
        .object(["kind": .string("exam"), "exam": .string("goethe_b1"), "tasks": .array(tasks.map(JSONValue.string))].merging(extra) { $1 })
    }

    @Test func pinnedOldIDsStayInTheCatalogue() {
        #expect(Self.oldIDs.flatMap { $0 }.count == 18)
        for id in Self.oldIDs.flatMap({ $0 }) { #expect(ExamCatalog.task(id) != nil, "\(id)") }
    }

    @Test func validMockAndTrainingRoundTrip() throws {
        let ids = ExamKind.goetheB1.drawTasks()
        let partner = try #require(ExamCatalog.tasks(.goetheB1, part: 2).first { $0.id != ids[1] }).id
        let mock = Activity(kind: .exam, exam: "goethe_b1", tasks: ids, format: .mock, partnerTask: partner)
        let training = Activity(kind: .exam, exam: "goethe_b1", tasks: [ids[2]], format: .training, teil: 3)
        for a in [mock, training] {
            let s = SessionSettings(lang: .de, mode: .free, topic: "x", activity: a)
            #expect(try JSONValue.from(s).decode(SessionSettings.self).activity == a)
        }
        #expect(!SessionSettings(lang: .de, mode: .free, activity: mock).canResume)
        // The legacy shape is unchanged and encodes without the new keys.
        let legacy = Activity(kind: .exam, exam: "goethe_b1", tasks: ids)
        let text = String(decoding: try JSONEncoder().encode(legacy), as: UTF8.self)
        #expect(!text.contains("format") && !text.contains("teil") && !text.contains("partnerTask"))
    }

    @Test func invalidContentDecodesAsNoActivity() throws {
        let ids = ExamKind.goetheB1.drawTasks()
        let other = try #require(ExamCatalog.tasks(.goetheB1, part: 2).first { $0.id != ids[1] }).id
        let ielts = ExamKind.ielts.drawTasks()
        let bad: [JSONValue] = [
            Self.exam(["format": .string("exam")], tasks: ids),                                          // unknown format
            Self.exam(["format": .number(1)], tasks: ids),                                               // wrong type
            Self.exam(["format": .string("mock")], tasks: ids),                                          // no partner
            Self.exam(["format": .string("mock"), "partnerTask": .string(ids[1])], tasks: ids),          // partner = own talk
            Self.exam(["format": .string("mock"), "partnerTask": .string(ids[0])], tasks: ids),          // partner not part 2
            Self.exam(["format": .string("mock"), "partnerTask": .string("missing")], tasks: ids),
            Self.exam(["format": .string("mock"), "partnerTask": .string(other), "teil": .number(1)], tasks: ids),
            Self.exam(["format": .string("mock"), "partnerTask": .string(other)], tasks: [ids[0]]),      // wrong count
            Self.exam(["format": .string("training"), "teil": .number(1)], tasks: ids),                  // three ids
            Self.exam(["format": .string("training")], tasks: [ids[0]]),                                 // no teil
            Self.exam(["format": .string("training"), "teil": .number(2)], tasks: [ids[0]]),             // wrong part
            Self.exam(["format": .string("training"), "teil": .number(4)], tasks: [ids[0]]),
            Self.exam(["format": .string("training"), "teil": .number(1), "partnerTask": .string(other)], tasks: [ids[0]]),
            Self.exam(["format": .string("training"), "teil": .string("1")], tasks: [ids[0]]),
            Self.exam(["format": .string("training"), "teil": .number(1)], tasks: ["missing"]),
            Self.exam(["teil": .number(1)], tasks: ids),                                                 // legacy with stray fields
            Self.exam(["partnerTask": .string(other)], tasks: ids),
            .object(["kind": .string("exam"), "exam": .string("ielts"), "format": .string("training"), "teil": .number(1),
                     "tasks": .array([.string(ielts[0])])]),
            .object(["kind": .string("exam"), "exam": .string("ielts"), "format": .string("mock"), "partnerTask": .string(other),
                     "tasks": .array(ielts.map(JSONValue.string))]),
        ]
        for (i, a) in bad.enumerated() { #expect(try Self.json(a).activity == nil, "case \(i)") }
        #expect(try Self.json(Self.exam([:], tasks: ids)).activity?.tasks == ids)  // legacy stays valid
    }

    @Test func olderBuildRollbackShape() throws {
        // BR-39a: an older build knows only the pinned ids. A mock of old ids is a normal exam to it; a mock with a new id is not.
        let old = Set(Self.oldIDs.flatMap { $0 })
        let ids = ExamKind.goetheB1.drawTasks()
        #expect(ids.allSatisfy(old.contains))  // the catalogue is unchanged in G-1; G-2 adds ids, and this test then pins the rule.
        #expect(!["b1-plan-new", ids[1], ids[2]].allSatisfy(old.contains))
        #expect(![ids[0]].isEmpty && ids.count == 3)  // a training has one id: an older build requires three and decodes no activity
    }

    @Test func newPartValuesAreAdditive() {
        let raw = ExamPhase.allCases.map(\.rawValue)
        #expect(raw.prefix(8) == ["goethe_b1.1.prep", "goethe_b1.1", "goethe_b1.2", "goethe_b1.3", "ielts.1", "ielts.2.prep", "ielts.2", "ielts.3"])
        #expect(Set(raw).isSuperset(of: ["goethe_b1.intro", "goethe_b1.2.partner", "goethe_b1.3.feedback", "goethe_b1.end"]))
        #expect(ExamPhase.goethe2.seconds == 180)  // unchanged until G-3
        #expect(ExamPhase.allCases.filter(\.isMonologue) == [.goethe2, .ielts2])
        #expect(ExamPhase.allCases.filter(\.isPreparation) == [.goethePrep, .ieltsPrep])
    }
}
