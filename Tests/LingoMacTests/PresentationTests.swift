import Testing
import LingoCore
@testable import LingoMac

@Suite struct PresentationTests {
    @Test func correctionPreservesUnchangedContext() throws {
        let original = "Ich habe seit zwei Tage Kopfschmerzen."
        let fix = Fix(original: original, corrected: "Ich habe seit zwei Tagen Kopfschmerzen.", rule: "Dativ")
        let diff = try #require(InlineCorrection(text: original, fix: fix))
        #expect(diff.before == "Ich habe seit zwei ")
        #expect(diff.wrong == "Tage")
        #expect(diff.right == "Tagen")
        #expect(diff.after == " Kopfschmerzen.")
        #expect(original == "Ich habe seit zwei Tage Kopfschmerzen.")
    }
    @Test func correctionCannotAttachToAnUnrelatedTranscript() {
        let fix = Fix(original: "I is here.", corrected: "I am here.", rule: "Agreement")
        #expect(InlineCorrection(text: "A different sentence.", fix: fix) == nil)
        #expect(InlineCorrection(text: "I am here.", fix: Fix(original: "I am here.", corrected: "I am here.", rule: "")) == nil)
    }
    @Test func insertionAndDeletionKeepSurroundingText() throws {
        let inserted = try #require(InlineCorrection(text: "I ready.", fix: Fix(original: "I ready.", corrected: "I am ready.", rule: "Verb")))
        #expect(inserted.wrong.isEmpty)
        #expect(inserted.right == "am")
        let deleted = try #require(InlineCorrection(text: "I am am ready.", fix: Fix(original: "I am am ready.", corrected: "I am ready.", rule: "Duplicate")))
        #expect(deleted.wrong == "am")
        #expect(deleted.right.isEmpty)
    }
}
