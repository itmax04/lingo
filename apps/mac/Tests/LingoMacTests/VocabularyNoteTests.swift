import Testing
@testable import LingoMac

@Suite struct VocabularyNoteTests {
    @Test func theAddResultNamesOnlyWhatHappened() {
        #expect(AppServices.addNote(added: 3, duplicates: 0, rejected: 0) == String(localized: "Added: \(3)"))
        let all = AppServices.addNote(added: 1, duplicates: 2, rejected: 4)
        #expect(all.components(separatedBy: " · ").count == 3)
    }
}
