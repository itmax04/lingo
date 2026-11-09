import CryptoKit
import Foundation
import Testing
@testable import LingoCore

/// LINGO-10 G-2: catalogue content. BR-03 (tasks), BR-04 (fields), BR-05 (phrases), BR-05a (Examiner lines), BR-06 (originality);
/// BAC-01 and BAC-02.
@Suite struct GoetheCatalogTests {
    static func sha(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }
    static func words(_ text: String) -> Int { text.split(whereSeparator: \.isWhitespace).count }
    static func hasCyrillic(_ text: String) -> Bool { text.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) } }
    static func hasLatin(_ text: String) -> Bool { text.unicodeScalars.contains { $0.isASCII && $0.properties.isAlphabetic } }
    /// Lower case, letters and digits only, single spaces: titles compare the same with or without punctuation and dashes.
    static func normal(_ text: String) -> String {
        String(text.lowercased().map { $0.isLetter || $0.isNumber ? $0 : " " }).split(separator: " ").joined(separator: " ")
    }
    static let goethe = ExamCatalog.all.filter { $0.exam == .goetheB1 }

    /// BR-06: titles and task headings of the official sources, read on 2026-11-09 from the Übungssatz Erwachsene (candidate sheets
    /// of the speaking module) and the Modellsatz speaking page. A deny-list only: no official text is used anywhere else.
    static let officialTitles = [
        "Reise nach Köln planen", "Hochzeit – großes Fest oder private Feier?", "Der schönste Tag im Leben", "Ohne Auto leben",
        "Ich brauch kein eigenes Auto!", "Besuch im Krankenhaus und Hilfe planen", "Brauchen Kinder Mobiltelefone?",
        "Papa, ich will ein Handy!", "Sehen Kinder zu viel fern?",
        "Sprachkurs für zwei Personen in Köln", "Wie hinkommen", "Was mitnehmen", "Rückmeldung zur Präsentation",
    ]

    @Test func twelveLinkedTasksPerPart() {
        for part in 1...3 { #expect(ExamCatalog.tasks(.goetheB1, part: part).count == 12) }
        let talks = ExamCatalog.tasks(.goetheB1, part: 2), discussions = ExamCatalog.tasks(.goetheB1, part: 3)
        // One to one: every talk has exactly one discussion, and no discussion points anywhere else.
        #expect(Set(discussions.compactMap(\.linkedTo)) == Set(talks.map(\.id)) && discussions.allSatisfy { $0.linkedTo != nil })
        for d in discussions {
            let talk = ExamCatalog.task(d.linkedTo!)!
            #expect(d.title == talk.title && d.gloss == talk.gloss && d.category == talk.category, "\(d.id)")
            #expect(d.id.dropFirst("b1-discuss-".count) == talk.id.dropFirst("b1-talk-".count))
        }
        for t in ExamCatalog.tasks(.goetheB1, part: 1) { #expect(t.points.count == 4 && t.questions.isEmpty) }
        for t in talks { #expect(t.points.count == 5 && t.questions.isEmpty) }
        for t in discussions { #expect(t.points.isEmpty && t.questions.count == 1) }
    }

    /// BR-03: the 18 tasks of the build before this change keep their ids, order and text (hash of `030eaa3`'s catalogue).
    @Test func originalTasksAreUnchanged() {
        let old = Set(GoetheActivityTests.oldIDs.flatMap { $0 })
        let kept = Self.goethe.filter { old.contains($0.id) }
        #expect(kept.count == 18)
        // The originals come first within each part, so stored snapshots and `tasks(...)[0]` stay the same.
        for part in 1...3 { #expect(ExamCatalog.tasks(.goetheB1, part: part).prefix(6).allSatisfy { old.contains($0.id) }) }
        let canon = kept.map { [$0.id, String($0.part), $0.task, $0.points.joined(separator: ";"), $0.questions.joined(separator: ";"),
                                $0.linkedTo ?? ""].joined(separator: "|") }.joined(separator: "\n")
        #expect(Self.sha(canon) == "6f8ccf2db5070f3db1ad3076820cb4dbcf1533760b29b79a210d272324f3b568")
    }

    @Test func titlesGlossesAndCategories() {
        for t in Self.goethe {
            let title = t.title ?? "", gloss = t.gloss ?? ""
            #expect(!title.isEmpty && title.count <= 60 && !Self.hasCyrillic(title), "\(t.id) title")
            #expect(!gloss.isEmpty && gloss.count <= 60 && Self.hasCyrillic(gloss) && !Self.hasLatin(gloss), "\(t.id) gloss")
            #expect(t.category != nil, "\(t.id) category")
        }
        for part in 1...3 {
            let tasks = ExamCatalog.tasks(.goetheB1, part: part)
            for c in ExamCategory.allCases { #expect(tasks.filter { $0.category == c }.count >= 2, "part \(part) \(c)") }
            #expect(Set(tasks.compactMap(\.title)).count == 12 && Set(tasks.compactMap(\.gloss)).count == 12)
        }
        // Every entry of the content tables is used: no orphan title or talk.
        #expect(Set(GoetheContent.planning.keys.map { "b1-plan-" + $0 }) == Set(ExamCatalog.tasks(.goetheB1, part: 1).map(\.id)))
        #expect(Set(GoetheContent.topics.keys.map { "b1-talk-" + $0 }) == Set(ExamCatalog.tasks(.goetheB1, part: 2).map(\.id)))
    }

    @Test func talksAndSummaries() {
        for t in Self.goethe {
            guard t.part == 2 else { #expect(t.talk == nil && t.talkSummary == nil, "\(t.id)"); continue }
            let talk = t.talk ?? "", summary = t.talkSummary ?? ""
            #expect((360...440).contains(Self.words(talk)), "\(t.id): \(Self.words(talk)) words")
            #expect(talk.count <= 3200, "\(t.id): \(talk.count) characters")
            // One paragraph per slide, in the order of the five slides.
            let slides = talk.components(separatedBy: "\n")
            #expect(slides.count == t.points.count && slides.allSatisfy { Self.words($0) >= 30 }, "\(t.id) slides")
            #expect(slides.first?.hasPrefix("Guten Tag.") == true && slides[2].contains("Heimatland"), "\(t.id)")
            // Read aloud by a speech voice: plain sentences, no quotes, brackets, digits or abbreviations with a full stop inside.
            #expect(talk.rangeOfCharacter(from: CharacterSet(charactersIn: "\"„“”()[]/;0123456789")) == nil, "\(t.id) characters")
            #expect(!talk.contains("z. B.") && !talk.contains(" usw") && !talk.contains("  "), "\(t.id)")
            #expect(!summary.isEmpty && summary.count <= 300 && !Self.hasCyrillic(summary), "\(t.id): summary \(summary.count)")
            #expect(!Self.hasCyrillic(talk))
        }
        #expect(Set(Self.goethe.compactMap(\.talk)).count == 12 && Set(Self.goethe.compactMap(\.talkSummary)).count == 12)
    }

    @Test func usefulPhrases() {
        var all: [GoethePhrase] = []
        for teil in 1...3 {
            let phrases = ExamCatalog.goethePhrases(teil: teil)
            #expect((8...12).contains(phrases.count), "Teil \(teil)")
            for p in phrases {
                #expect(!p.de.isEmpty && p.de.count <= 80 && !Self.hasCyrillic(p.de), "\(p.de)")
                #expect(!p.ru.isEmpty && p.ru.count <= 80 && Self.hasCyrillic(p.ru) && !Self.hasLatin(p.ru), "\(p.ru)")
            }
            all += phrases
        }
        #expect(Set(all.map(\.de)).count == all.count && Set(all.map(\.ru)).count == all.count)
        #expect(ExamCatalog.goethePhrases(teil: 0).isEmpty && ExamCatalog.goethePhrases(teil: 4).isEmpty)
        #expect(Set(ExamCatalog.goethePhrasesByTeil.keys) == ["1", "2", "3"])
    }

    @Test func examinerLines() {
        let lines = ExamCatalog.goetheExaminerLines
        #expect(Set(lines.keys) == ["goethe_b1.intro", "goethe_b1.intro.end", "goethe_b1.1", "goethe_b1.2", "goethe_b1.3",
                                    "goethe_b1.2.partner", "goethe_b1.3.feedback"])
        for line in GoetheExaminerLine.allCases {
            #expect(!line.text.isEmpty && line.text.count <= 200 && !Self.hasCyrillic(line.text), "\(line.rawValue): \(line.text.count)")
        }
        #expect(Set(lines.values).count == lines.count)
        // Every key but the closing thanks is an `exam.part` value, so the engine finds the line of a part by its raw value.
        for key in lines.keys where key != GoetheExaminerLine.introEnd.rawValue { #expect(ExamPhase(rawValue: key) != nil, "\(key)") }
    }

    /// BR-06 and AGENTS.md §6.7: no official title in any German text of the catalogue, and nothing about pronunciation.
    @Test func noOfficialTitleAndNoPronunciation() {
        var texts: [(String, String)] = []
        for t in Self.goethe {
            texts += [(t.id, t.title ?? ""), (t.id, t.task), (t.id, t.talk ?? ""), (t.id, t.talkSummary ?? "")]
            texts += (t.points + t.questions).map { (t.id, $0) }
        }
        for teil in 1...3 { texts += ExamCatalog.goethePhrases(teil: teil).map { ("phrase \(teil)", $0.de) } }
        texts += GoetheExaminerLine.allCases.map { ($0.rawValue, $0.text) }
        let official = Self.officialTitles.map(Self.normal)
        #expect(official.count >= 9 && official.allSatisfy { $0.count >= 12 })
        for (id, text) in texts {
            let n = Self.normal(text)
            for o in official { #expect(!n.contains(o), "\(id) repeats an official title: \(o)") }
            for word in ["aussprache", "akzent", "betonung"] { #expect(!n.contains(word), "\(id): \(word)") }
        }
        // The deny-list works on real input: the mockup's excluded topic (spec BR-06) and a re-punctuated title are caught.
        #expect(Self.normal("Thema: Ohne Auto leben?").contains(Self.normal("Ohne Auto leben")))
        #expect(Self.normal("Hochzeit - großes Fest oder private Feier").contains(official[1]))
    }

    /// BAC-02: the IELTS entries of the exported catalogue are byte-identical to `030eaa3` (hash of that file's IELTS tail).
    @Test func ieltsEntriesAreByteIdentical() throws {
        let firstIELTS = try #require(ExamCatalog.all.firstIndex { $0.exam == .ielts })
        #expect(ExamCatalog.all[firstIELTS...].allSatisfy { $0.exam == .ielts } && ExamCatalog.all.count - firstIELTS == 24)
        for t in ExamCatalog.all[firstIELTS...] {
            #expect(t.title == nil && t.gloss == nil && t.category == nil && t.talk == nil && t.talkSummary == nil, "\(t.id)")
        }
        for text in [try ExamTests.catalogueJSON(),
                     try String(contentsOf: ExamTests.contracts.appendingPathComponent("teacher/exams.json"), encoding: .utf8)] {
            let start = try #require(text.range(of: "    {\n      \"exam\" : \"ielts\""))
            let tail = String(text[start.lowerBound...])
            #expect(tail.utf8.count == 12095)
            #expect(Self.sha(tail) == "74dcca224eec247dd0c22912deddd3755a4e593013a03688ffdf84bfc9c7368f")
        }
    }

    /// The new fields reach the export, and an entry without them (IELTS) decodes as before.
    @Test func exportCarriesTheNewFields() throws {
        struct File: Decodable {
            let goetheExaminerLines: [String: String]; let goethePhrases: [String: [GoethePhrase]]; let tasks: [ExamTask]
        }
        let file = try JSONDecoder().decode(File.self, from: Data(try ExamTests.catalogueJSON().utf8))
        #expect(file.tasks == ExamCatalog.all && file.goetheExaminerLines == ExamCatalog.goetheExaminerLines)
        #expect(file.goethePhrases == ExamCatalog.goethePhrasesByTeil)
        // XR-01 limits of the existing fields hold for the new tasks too, and each one fits the <exam> block (PX-03).
        for t in Self.goethe {
            #expect(t.task.count <= 400 && t.points.allSatisfy { $0.count <= 80 } && t.questions.allSatisfy { $0.count <= 150 })
        }
    }
}
