import Foundation
import LingoCore

/// Teacher actions of the app (LINGO-05 T-4): the warm-up, the daily goal and card suspension.
@MainActor
extension AppServices {
    /// Starts today's warm-up in a language (WR-01): a session over the frozen queue, opened by the assistant.
    func startWarmup(_ lang: Lang) {
        Task {
            do {
                let corrections = settings.lastCorrections.isEmpty ? [CorrectionMode.inline] : settings.lastCorrections
                guard let id = try await engine.startWarmup(lang: lang, corrections: corrections) else {
                    model.banner = String(localized: "Nothing to review right now.")
                    return
                }
                updateSettings { $0.lastLang = lang }
                model.langFilter = lang
                model.selectedSessionID = id
                model.section = .conversations
                run(engine.respond(session: id))
            } catch { model.banner = String(localized: "Could not create the session: \(String(describing: error))") }
        }
    }

    /// The daily goal in minutes (GR-02), a journal event.
    func setDailyGoal(_ minutes: Int) { Task { try? await engine.setDailyGoal(minutes: minutes) } }

    /// "Don't practise this card" and its undo (WR-05).
    func setCardSuspended(_ card: String, _ suspended: Bool) { Task { await engine.setCardSuspended(card, suspended) } }
}
