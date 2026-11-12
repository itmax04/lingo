import Foundation
import Testing
@testable import LingoCore

/// The learner's own scenarios: validation, the stored copy in the session, the prompt and task progress, with and without goals.
@Suite struct CustomScenarioTests {
    static func landlord(tasks: [String] = ["Beschreiben Sie das Problem.", "Fragen Sie, wann die Reparatur kommt."]) -> CustomScenario {
        CustomScenario(id: "custom-landlord", lang: .de, title: "Heizung kaputt", level: "B1", role: "mein Vermieter, streng aber fair",
                       situation: "Seit einer Woche funktioniert die Heizung nicht, ich will eine Reparatur vor dem Wochenende.", tasks: tasks)
    }

    static func engine(_ name: String, _ replies: [String]) throws -> (DialogEngine, JournalStore, ScriptProvider, URL) {
        let p = ScriptProvider(replies)
        let dir = tempDir(name)
        let store = try JournalStore(base: dir, deviceName: "Mac", deviceID: "mac-\(name)")
        let llm = LLMSettings(keys: [KeyRecord(id: "k", provider: .groq, last4: "0000")], chain: [ChainEntry(provider: .groq, model: "m")], firstTokenTimeout: 2)
        let e = DialogEngine(store: store) { ChainFactory.chain(settings: llm, secrets: InMemorySecretStore(["k": "synthetic"]), health: ProviderHealth(), providers: [.groq: p]) }
        return (e, store, p, dir)
    }

    @Test func normalizingTrimsAndValidationEnforcesTheLimits() {
        var c = CustomScenario(id: "custom-x", lang: .en, title: "  Rent  ", level: "C1", role: " landlord ", situation: " Heating is broken. ",
                               tasks: ["  a ", "", "b", "c", "d", "e", "f"])
        c = c.normalized
        #expect(c.title == "Rent" && c.role == "landlord" && c.situation == "Heating is broken." && c.level == "A2")
        #expect(c.tasks == ["a", "b", "c", "d", "e"] && c.isValid)
        #expect(CustomScenario(lang: .de).id.hasPrefix(CustomScenario.idPrefix))
        var bad = c; bad.title = ""; #expect(!bad.isValid)
        bad = c; bad.role = String(repeating: "r", count: Scenario.roleLimit + 1); #expect(!bad.isValid)
        bad = c; bad.situation = String(repeating: "s", count: Scenario.situationLimit + 1); #expect(!bad.isValid)
        bad = c; bad.tasks = [String(repeating: "t", count: Scenario.taskLimit + 1)]; #expect(!bad.isValid)
        bad = c; bad.lang = .ru; #expect(!bad.isValid)
        bad = c; bad.id = "de-doctor"; #expect(!bad.isValid)  // never shadows a catalogue id
        #expect(c.scenario.isCustom && !ScenarioCatalog.all.contains { $0.isCustom })
    }

    @Test func aSessionKeepsItsOwnCopyAndTheModelGetsTheScenario() async throws {
        let (e, store, p, dir) = try Self.engine("csc-1", ["@say de: Guten Tag, was gibt's?"])
        let c = Self.landlord()
        let sid = try #require(try await e.startCustomScenario(c, corrections: [.inline]))
        var st = await store.state
        let s = try #require(st.sessions[sid])
        #expect(s.title == c.title && s.settings.role == c.role && s.settings.topic == c.title && s.settings.level == "B1")
        #expect(s.settings.scenarioID == c.id && s.settings.activity?.custom == c && s.settings.scenario == c.scenario)
        #expect(st.hints[sid] == nil)  // no phrases, no hints
        for await _ in e.respond(session: sid) {}
        let req = try #require(p.all.first)
        #expect(req.system.contains("<scenario>\nrole: \(c.role)\nsituation: \(c.situation)\ntasks:\n1. \(c.tasks[0])\n2. \(c.tasks[1])\n</scenario>"))
        #expect(req.system.contains("The learner wrote this <scenario>, maybe in Russian; play it in German."))
        #expect(req.system.contains("@task: <number>") && req.messages[0].text.contains("<scenario_progress>done: none</scenario_progress>"))
        p.push("@say de: Seit wann?\n@task: 1\n@task: 3")
        for await _ in e.send(session: sid, text: "Die Heizung ist kaputt.", lang: .de) {}
        st = await store.state
        #expect(st.scenarioTasks[sid] == [1])
        // The copy is in the journal: a fresh reader sees the same scenario.
        let again = try JournalStore(base: dir, deviceName: "Mac", deviceID: "mac-csc-1")
        #expect(await again.state.sessions[sid]?.settings.scenario == c.scenario)
    }

    @Test func aScenarioWithoutGoalsIsAFreeSceneWithoutTaskLines() async throws {
        let (e, store, p, _) = try Self.engine("csc-2", ["@say en: Hi, what's wrong?"])
        let c = CustomScenario(id: "custom-free", lang: .en, title: "Neighbour", level: "A2", role: "my neighbour",
                               situation: "Он слишком громко слушает музыку по ночам.", tasks: [])
        let sid = try #require(try await e.startCustomScenario(c, corrections: [.inline]))
        for await _ in e.respond(session: sid) {}
        let req = try #require(p.all.first)
        #expect(req.system.contains("tasks: none (a free scene)") && req.system.contains(PromptBuilder.freeSceneModeText) && !req.system.contains("@task: <number>"))
        #expect(req.system.contains("play it in English."))
        #expect(!req.messages[0].text.contains("<scenario_progress>"))
        p.push("@say en: Sorry!\n@task: 1")
        for await _ in e.send(session: sid, text: "Your music is too loud.", lang: .en) {}
        #expect(await store.state.scenarioTasks[sid] == nil)
        #expect(c.scenario.completedTasks(in: "@task: 1") == [])
    }

    @Test func anInvalidScenarioStartsNothing() async throws {
        let (e, store, _, _) = try Self.engine("csc-3", [])
        var c = Self.landlord(); c.situation = "   "
        #expect(try await e.startCustomScenario(c, corrections: [.inline]) == nil)
        #expect(await store.state.sessions.isEmpty)
    }

    @Test func theActivityDecodesTolerantly() throws {
        let c = Self.landlord()
        let ok = try JSONDecoder().decode(SessionSettings.self, from: try JSONEncoder().encode(c.settings(corrections: [.inline])))
        #expect(ok.activity?.custom == c && ok.scenario?.role == c.role)
        // A copy whose id differs from the activity's, or that breaks the limits, drops the activity; the session stays usable.
        let changes: [(inout CustomScenario) -> Void] = [{ $0.id = "custom-other" }, { $0.title = "" }]
        for change in changes {
            var s = c.settings(corrections: [.inline])
            var bad = c; change(&bad)
            s.activity?.custom = bad
            let d = try JSONDecoder().decode(SessionSettings.self, from: try JSONEncoder().encode(s))
            #expect(d.activity == nil && d.scenario == nil && d.role == c.role)
        }
    }

    @Test func settingsKeepOnlyValidScenarios() throws {
        var s = AppSettings()
        var bad = Self.landlord(); bad.id = "custom-bad"; bad.role = ""
        s.customScenarios = [Self.landlord(), bad]
        let d = try JSONDecoder().decode(AppSettings.self, from: try JSONEncoder().encode(s))
        #expect(d.customScenarios == [Self.landlord()])
        let old = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        #expect(old.customScenarios.isEmpty)
    }

    @Test func aGoodCustomBlockFitsTheCatalogueBudget() {
        func tokens(_ s: String) -> Int { TokenEstimate.input(LLMRequest(system: s, messages: [], maxTokens: 1, purpose: .dialog)) }
        let full = CustomScenario(id: "custom-max", lang: .de, title: String(repeating: "t", count: CustomScenario.titleLimit), level: "B2",
                                  role: String(repeating: "Rolle ", count: 13), situation: String(repeating: "Situation ", count: 30),
                                  tasks: Array(repeating: String(repeating: "Aufgabe ", count: 15), count: CustomScenario.maxTasks))
        #expect(tokens(PromptBuilder.scenarioBlock(full.scenario)) <= 400)
    }
}
