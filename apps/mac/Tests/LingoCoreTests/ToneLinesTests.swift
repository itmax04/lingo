import Foundation
import Testing
@testable import LingoCore

/// LINGO-09 M-3a: the local line catalogue (MR-21), its export `tone-lines.json`, the deny-list (MR-06, MR-47; MAC-12)
/// and the `local` mark in the merged state (the open point F1 of the M-1a review).
@Suite struct ToneLinesTests {
    static let contracts = ScenarioTests.contracts.deletingLastPathComponent().deletingLastPathComponent()
    static let denyList: [String: [String]] = {
        let url = contracts.appendingPathComponent("fixtures/teacher/tone-deny-list.json")
        struct File: Decodable { let categories: [String: [String]] }
        return try! JSONDecoder().decode(File.self, from: Data(contentsOf: url)).categories
    }()

    /// Whole-word match, case-insensitive; a trailing `*` is a stem.
    static func hits(_ text: String, _ term: String) -> Bool {
        let words = text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
        let t = term.lowercased().split(separator: " ").map(String.init)
        guard !t.isEmpty, words.count >= t.count else { return false }
        for i in 0...(words.count - t.count) {
            var ok = true
            for (j, part) in t.enumerated() {
                let w = words[i + j]
                if part.hasSuffix("*") { if !w.hasPrefix(part.dropLast()) { ok = false; break } } else if w != part { ok = false; break }
            }
            if ok { return true }
        }
        return false
    }

    static var allLines: [(where: String, text: String)] {
        let e = ToneLines.export()
        var out: [(String, String)] = []
        for (lang, kinds) in e.lines { for (kind, bands) in kinds { for (band, ls) in bands { for l in ls { out.append(("\(lang)/\(kind)/L\(band)", l)) } } } }
        for (lang, kinds) in e.profane { for (kind, ls) in kinds { for l in ls { out.append(("\(lang)/\(kind)/profane", l)) } } }
        return out
    }

    @Test func countsPerKindLanguageAndBand() {
        for lang in Lang.studied {
            for band in ToneLines.bands {
                for kind in ToneLineKind.allCases {
                    let ls = ToneLines.lines(kind, lang: lang, level: band)
                    if ToneLines.kinds(band: band).contains(kind) {
                        #expect(ls.count >= ToneLines.minimumPerCell, "\(lang)/\(kind)/L\(band)")
                        #expect(Set(ls).count == ls.count, "duplicates in \(lang)/\(kind)/L\(band)")
                        #expect(ls.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty && $0.count <= 80 })
                    } else {
                        #expect(ls.isEmpty, "level 1 speaks only neutral and calm: \(lang)/\(kind)")
                    }
                }
            }
            for kind in ToneLines.profaneKinds {
                #expect(ToneLines.lines(kind, lang: lang, level: 5, profane: true).count >= ToneLines.minimumPerCell, "\(lang)/\(kind) profane")
            }
        }
    }

    @Test func exportEqualsTheContractFile() throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
        let text = String(decoding: try enc.encode(ToneLines.export()), as: UTF8.self) + "\n"
        try ExamTests.fixture("teacher/tone-lines.json", text)
        // Every cell of the export is the cell of the catalogue, nothing is added or lost.
        let back = try JSONDecoder().decode(ToneLines.Export.self, from: Data(text.utf8))
        #expect(back == ToneLines.export())
    }

    @Test func profaneLinesAreSeparateAndOnlyWithTheSwitch() {
        for lang in Lang.studied {
            for kind in ToneLineKind.allCases {
                let plain = Set((1...5).flatMap { ToneLines.lines(kind, lang: lang, level: $0) })
                let profane = Set(ToneLines.lines(kind, lang: lang, level: 5, profane: true))
                #expect(plain.isDisjoint(with: profane), "\(lang)/\(kind)")
                for band in 1...4 { #expect(ToneLines.lines(kind, lang: lang, level: band, profane: true).isEmpty) }
            }
        }
        var picker = ToneLinePicker()
        var g = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let line = picker.next(.pressure, lang: .en, level: 5, profane: false, using: &g)
            #expect(line != nil && !ToneLines.lines(.pressure, lang: .en, level: 5, profane: true).contains(line!))
        }
    }

    @Test func noLineHitsTheDenyList() {
        #expect(Set(Self.denyList.keys) == ["violence", "protected traits", "sexual content", "self-harm", "pronunciation", "profanity (plain lines only)"])
        #expect(!Self.allLines.isEmpty)
        for (place, text) in Self.allLines {
            for (category, terms) in Self.denyList where !(category.hasPrefix("profanity") && place.hasSuffix("profane")) { for term in terms { #expect(!Self.hits(text, term), "\(place) «\(text)» hits \(category): \(term)") } }
        }
    }

    @Test func theDenyListMatcherWorks() {
        #expect(Self.hits("You will be killed", "kill*"))
        #expect(Self.hits("Falsche Aussprache", "aussprache"))
        #expect(Self.hits("Your accent is odd", "accent*"))
        #expect(Self.hits("hit you hard", "hit you"))
        #expect(!Self.hits("This is white", "hit you"))
        #expect(!Self.hits("a skilled worker", "kill*"))
        #expect(Self.hits("Ich bringe Sie um", "bringe* sie um"))
        #expect(Self.hits("Du Krüppel", "krüppel*") && Self.hits("Erschieß ihn", "erschieß*") && Self.hits("Mädchen", "mädchen"))
        #expect(!Self.hits("Hello? Anything coming?", "hell"), "a stem-less term is a whole word")
        #expect(!Self.hits("Schlampig", "schlampe*"))
    }

    @Test func aLineIsNeverUsedTwiceInARow() {
        var picker = ToneLinePicker()
        var g = SystemRandomNumberGenerator()
        for lang in Lang.studied {
            for kind in ToneLineKind.allCases {
                var prev: String?
                for _ in 0..<60 {
                    let line = picker.next(kind, lang: lang, level: 3, using: &g)
                    #expect(line != nil && line != prev, "\(lang)/\(kind)")
                    prev = line
                }
            }
        }
        #expect(picker.next(.pressure, lang: .en, level: 1) == nil, "no pressure line at level 1")
        #expect(picker.next(.neutral, lang: .de, level: 0) != nil, "levels are clamped to the band")
    }

    // F1 of the M-1a review: the `local` mark reaches the merged ChatMessage.
    @Test func theLocalMarkSurvivesTheMerger() throws {
        var out: [Event] = []
        func add(_ type: String, _ payload: some Encodable) {
            let n = out.count + 1
            out.append(Event(id: String(format: "01M3ALOCAL%016d", n), device: "mac-local00001", seq: n, lamport: n,
                             ts: Date(timeIntervalSince1970: 1_800_000_000 + Double(n)), type: type, session: "s", payload: try! JSONValue.from(payload)))
        }
        add(EventType.sessionCreated, Payload.SessionCreated(title: "s", settings: SessionSettings(lang: .de, mode: .free, corrections: [.after])))
        add(EventType.messageCreated, Payload.MessageCreated(role: .assistant, text: "Noch einmal, bitte.", lang: .de, local: true))
        add(EventType.messageCreated, Payload.MessageCreated(role: .assistant, text: "Wie geht es Ihnen?", lang: .de))
        let msgs = try #require(Merger.build(out).messages["s"])
        #expect(msgs.map(\.local) == [true, false])
    }
}
