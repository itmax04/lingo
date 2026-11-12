import Foundation
import LingoCore

/// Teacher actions of the app (LINGO-05 T-4): the warm-up, the daily goal and card suspension.
@MainActor
extension AppServices {
    /// Starts today's warm-up in a language (WR-01): a session over the frozen queue, opened by the assistant.
    func startWarmup(_ lang: Lang) {
        guard !model.startingWarmup.contains(lang) else { return }  // a double click starts one warm-up, not two
        model.startingWarmup.insert(lang)
        Task {
            defer { model.startingWarmup.remove(lang) }
            do {
                if let open = await engine.reusableWarmup(lang: lang) {
                    model.langFilter = lang
                    model.selectedSessionID = open
                    model.section = .conversations
                    return
                }
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

    /// Starts a scenario (SR-02): its own session, phrases as hints, the assistant opens in the role.
    func startScenario(_ id: String) {
        guard !model.startingScenario else { return }  // a double click starts one scenario
        model.startingScenario = true
        Task {
            defer { model.startingScenario = false }
            do {
                let corrections = settings.lastCorrections.isEmpty ? [CorrectionMode.inline] : settings.lastCorrections
                let lang = ScenarioCatalog.scenario(id)?.lang ?? model.langFilter
                guard let sid = try await engine.startScenario(id, corrections: corrections, level: model.history.learnerChosenLevel(lang: lang)) else { return }
                updateSettings { $0.lastLang = lang }
                model.langFilter = lang
                model.selectedSessionID = sid
                model.section = .conversations
                run(engine.respond(session: sid))
            } catch { model.banner = String(localized: "Could not create the session: \(String(describing: error))") }
        }
    }

    /// Starts the learner's own scenario: like a catalogue one, at the level the learner gave it.
    func startCustomScenario(_ custom: CustomScenario) {
        guard !model.startingScenario else { return }
        model.startingScenario = true
        Task {
            defer { model.startingScenario = false }
            do {
                let corrections = settings.lastCorrections.isEmpty ? [CorrectionMode.inline] : settings.lastCorrections
                guard let sid = try await engine.startCustomScenario(custom, corrections: corrections) else {
                    model.banner = String(localized: "This scenario is incomplete: give it a title, a role and a situation.")
                    return
                }
                updateSettings { $0.lastLang = custom.lang }
                model.langFilter = custom.lang
                model.selectedSessionID = sid
                model.section = .conversations
                run(engine.respond(session: sid))
            } catch { model.banner = String(localized: "Could not create the session: \(String(describing: error))") }
        }
    }

    /// Saves a new or edited scenario of the learner (normalized; an invalid one is not saved).
    @discardableResult
    func saveCustomScenario(_ custom: CustomScenario) -> Bool {
        let c = custom.normalized
        guard c.isValid else { return false }
        updateSettings { s in
            if let i = s.customScenarios.firstIndex(where: { $0.id == c.id }) { s.customScenarios[i] = c } else { s.customScenarios.append(c) }
        }
        return true
    }

    /// Removes a saved scenario; sessions that already ran keep their own copy.
    func deleteCustomScenario(_ id: String) { updateSettings { $0.customScenarios.removeAll { $0.id == id } } }

    /// The daily goal in minutes (GR-02), a journal event.
    func setDailyGoal(_ minutes: Int) { Task { try? await engine.setDailyGoal(minutes: minutes) } }

    /// "Don't practise this card" and its undo (WR-05).
    /// GR-05: one weekly-advice request per click ("Advice from Lingo", "Update", "Retry"); a click while one runs sends nothing.
    func runWeeklyReport() {
        guard !model.weeklyRunning else { return }
        model.weeklyRunning = true
        model.weeklyFailed = false
        Task {
            let result = await engine.weeklyReport()
            model.weeklyRunning = false
            model.weeklyFailed = result == .failed
            model.apply(await store.state)
        }
    }

    /// GR-06: the memory switch, a fact edit and a fact deletion; each one is a journal event.
    func setMemory(on: Bool) { Task { await engine.setMemory(on: on); model.apply(await store.state) } }
    func updateMemory(_ fact: String, _ text: String) { Task { await engine.updateMemory(fact, text: text); model.apply(await store.state) } }
    func removeMemory(_ fact: String) { Task { await engine.removeMemory(fact); model.apply(await store.state) } }

    func setCardSuspended(_ card: String, _ suspended: Bool) { Task { await engine.setCardSuspended(card, suspended) } }
}
