import Foundation
import LingoCore

/// My vocabulary (LINGO-08 VR-03…VR-11) and the learner profile (PR-01): thin wrappers over `DialogEngine`. Item texts are never logged.
extension AppServices {
    /// Adds items and reports the result in the banner (VR-03: added, duplicates, rejected).
    func addVocabulary(lang: Lang, entries: [(text: String, translation: String)], source: VocabSource, rejected extra: Int = 0) {
        Task {
            do {
                let r = try await engine.addVocabulary(lang: lang, entries: entries, source: source)
                model.vocabularyNote = Self.addNote(added: r.added, duplicates: r.duplicates, rejected: r.rejected + extra)
            } catch { model.banner = String(localized: "Could not add: \(String(describing: error))") }
        }
    }

    nonisolated static func addNote(added: Int, duplicates: Int, rejected: Int) -> String {
        var parts = [String(localized: "Added: \(added)")]
        if duplicates > 0 { parts.append(String(localized: "already in the list: \(duplicates)")) }
        if rejected > 0 { parts.append(String(localized: "too long or over 200 lines: \(rejected)")) }
        return parts.joined(separator: " · ")
    }

    func updateVocabulary(_ item: VocabItem, text: String, translation: String, note: String, example: String) {
        Task {
            do {
                try await engine.updateVocabulary(item.id, text: text, translation: translation, note: note, example: example)
            } catch DialogEngine.VocabularyError.emptyText {
                model.banner = String(localized: "The text cannot be empty.")
            } catch DialogEngine.VocabularyError.tooLong {
                model.banner = String(localized: "The text is longer than 120 characters.")
            } catch { model.banner = String(localized: "Could not save: \(String(describing: error))") }
        }
    }

    func removeVocabulary(_ item: VocabItem) {
        Task {
            do { try await engine.removeVocabulary(item.id) }
            catch { model.banner = String(localized: "Could not remove: \(String(describing: error))") }
        }
    }

    /// "Translate" in the add form (VR-10): one `translate` request, only on the learner's click.
    func translateDraft(_ text: String, from lang: Lang) async -> String? {
        do { return try await engine.translate(text, from: lang) }
        catch { model.banner = String(localized: "Translation failed: \(String(describing: error))"); return nil }
    }

    /// ▶ on an item: the voice of its language, outside a session, without the microphone (R-27).
    func playVocabulary(_ item: VocabItem) { speakWithoutMicrophone(item.text, lang: item.lang) }

    /// "Practise" (VR-11): a "My words" session in the item's language with this item as the first target; the assistant opens.
    func practise(_ item: VocabItem) {
        model.section = .conversations
        createSession(.myWords(for: item, corrections: settings.lastCorrections), title: nil)
    }

    /// The session menu switch (VR-08).
    func toggleVocabulary() {
        guard let s = model.selectedSession, !s.settings.isVocabularyFocus, !model.isExam else { return }
        Task {
            do { try await engine.updateSettings(s.id, s.settings.togglingVocabulary()) }
            catch { model.banner = String(localized: "Could not save: \(String(describing: error))") }
        }
    }

    func updateProfile(goals: String, interests: String) {
        Task {
            do { try await engine.updateProfile(goals: goals, interests: interests) }
            catch { model.banner = String(localized: "Could not save: \(String(describing: error))") }
        }
    }
}
