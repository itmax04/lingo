import Foundation
import LingoCore
import Testing
@testable import LingoMac

@Suite struct VocabularyNoteTests {
    @Test func theAddResultNamesOnlyWhatHappened() {
        #expect(AppServices.addNote(added: 3, duplicates: 0, rejected: 0) == String(localized: "Added: \(3)"))
        let all = AppServices.addNote(added: 1, duplicates: 2, rejected: 4)
        #expect(all.components(separatedBy: " · ").count == 3)
    }
}

@Suite struct VocabularyListTests {
    @Test func filterSearchAndOrder() {
        let t0 = Date(timeIntervalSince1970: 1_792_900_000)
        let all = [
            VocabItem(id: "a", lang: .de, text: "Feierabend", translation: "конец дня", createdAt: t0),
            VocabItem(id: "b", lang: .de, text: "die Ausrede", translation: "отговорка", createdAt: t0.addingTimeInterval(60)),
            VocabItem(id: "c", lang: .en, text: "spot on", translation: "в точку", createdAt: t0.addingTimeInterval(30)),
        ]
        #expect(VocabularyView.shown(all, filter: nil, search: "").map(\.id) == ["b", "c", "a"])  // newest first
        #expect(VocabularyView.shown(all, filter: .de, search: "").map(\.id) == ["b", "a"])
        #expect(VocabularyView.shown(all, filter: nil, search: "ОТГОВОР").map(\.id) == ["b"])  // translation, any case
        #expect(VocabularyView.shown(all, filter: .en, search: "feier").isEmpty)
    }
}
