import Foundation
import Testing
@testable import LingoCore

/// LINGO-10 G-3: runs with a format (BR-07, BR-09…BR-15, BR-17, BR-18, BR-23…BR-25).
@MainActor @Suite struct GoetheRunTests {
    static let plan = "b1-plan-park", talk = "b1-talk-bicycle", discuss = "b1-discuss-bicycle", partner = "b1-talk-secondhand"
    static func mock() -> ExamRun {
        ExamRun(kind: .goetheB1, tasks: [plan, talk, discuss], format: .mock, partnerTask: partner, now: ExamTests.start)!
    }
    static func training(_ teil: Int) -> ExamRun {
        ExamRun(kind: .goetheB1, tasks: [[plan, talk, discuss][teil - 1]], format: .training, teil: teil, now: ExamTests.start)!
    }
    static func text(_ id: String) -> ExamTask { ExamCatalog.task(id)! }

    /// What the app spoke through `ExamController.speak`, with the state seen while it was speaking.
    final class Speech {
        var spoken: [(voice: String?, parts: [String])] = []
        var closed: [Bool] = []
        /// The voice whose speech does not end until this is cleared.
        var hold: String?
        var lines: [String] { spoken.flatMap(\.parts) }
    }
    func env() throws -> (ExamControllerTests.Env, ExamController, Speech) {
        let (e, c) = try ExamControllerTests().env()
        let s = Speech()
        c.voices = ExamVoices(examiner: "voice-examiner", partner: "voice-partner")
        c.speak = { [weak c] parts, voice in
            s.spoken.append((voice, parts))
            s.closed.append(e.sink.micMuted && c?.canCapture == false && c?.beginCapture() == nil)
            while s.hold == voice, !Task.isCancelled { try? await Task.sleep(for: .milliseconds(5)) }
        }
        return (e, c, s)
    }
    func idle(_ c: ExamController) async { await ExamControllerTests().idle(c) }
    func go(_ c: ExamController, _ phase: ExamPhase) async { await ExamControllerTests().go(c, phase) }

    // MARK: Run value, settings, voices

    @Test func partsTasksRolesAndTimersPerFormat() throws {
        let m = Self.mock()
        #expect(m.phases == [.goetheIntro, .goethe1, .goethe2, .goethe3, .goethePartner, .goetheFeedback])
        #expect(m.phases.map(\.seconds) == [60, 180, 240, 120, 300, 120])
        #expect(Self.training(1).phases == [.goethe1] && Self.training(2).phases == [.goethe2])
        #expect(Self.training(3).phases == [.goethePartner, .goetheFeedback, .goethe3])
        var r = m, tasks: [String] = [], strict: [Bool] = [], mic: [Bool] = [], lines: [[String]] = []
        for p in m.phases {
            tasks.append(r.task.id); strict.append(r.endsAtZero); mic.append(r.microphoneAllowed); lines.append(r.examinerOpening)
            r.advance(expected: p, timeUp: true, turnRunning: false, now: ExamTests.start)
        }
        #expect(r.finished && tasks == [Self.plan, Self.plan, Self.talk, Self.discuss, Self.partner, Self.partner])
        #expect(strict.allSatisfy { $0 } && mic == [true, true, true, true, false, true])
        #expect(lines == [GoetheExaminerLine.intro, .teil1, .teil2, .teil3, .partnerTalk, .feedback].map { [$0.text] })
        var t = Self.training(3)
        #expect(t.task.id == Self.talk && !t.endsAtZero && !t.microphoneAllowed)
        t.advance(expected: .goethePartner, timeUp: false, turnRunning: false, now: ExamTests.start)
        #expect(t.task.id == Self.talk && !t.endsAtZero && t.role.contains("from the talk summary"))
        t.advance(expected: .goetheFeedback, timeUp: false, turnRunning: false, now: ExamTests.start)
        #expect(t.task.id == Self.discuss && t.role.contains("ask nothing new"))
        #expect(t.examinerOpening == [GoetheExaminerLine.teil3.text] + Self.text(Self.discuss).questions)
        #expect(Self.training(2).endsAtZero && !Self.training(1).endsAtZero)
        // Legacy and IELTS keep their parts, roles and no Examiner line.
        let legacy = ExamRun(kind: .goetheB1, tasks: [Self.plan, Self.talk, Self.discuss], now: ExamTests.start)!
        #expect(legacy.phases == [.goethePrep, .goethe1, .goethe2, .goethe3] && legacy.examinerOpening.isEmpty && legacy.role == ExamPhase.goethePrep.role)
        #expect(ExamRun(kind: .goetheB1, tasks: [Self.plan, Self.talk, Self.discuss], format: .mock, partnerTask: Self.talk, now: ExamTests.start) == nil)
        #expect(ExamRun(kind: .goetheB1, tasks: [Self.talk], format: .training, teil: 3, now: ExamTests.start) == nil)
        #expect(ExamRun(kind: .ielts, tasks: ExamKind.ielts.drawTasks(), format: .mock, partnerTask: Self.partner, now: ExamTests.start) == nil)
    }

    @Test func settingsStoreFormatCorrectionsAndPartnerRole() throws {
        let m = try #require(ExamKind.goetheB1.settings(tasks: [Self.plan, Self.talk, Self.discuss], format: .mock, partnerTask: Self.partner))
        #expect(m.corrections == [.after] && m.role == "Gesprächspartner" && m.mode == .free && m.topic == ExamKind.goetheB1.title && m.useVocabulary == false)
        #expect(m.activity?.format == .mock && m.activity?.partnerTask == Self.partner && !m.canResume)
        let t = try #require(ExamKind.goetheB1.settings(tasks: [Self.discuss], format: .training, teil: 3))
        #expect(t.corrections == [.inline] && t.role == "Gesprächspartner" && t.activity?.teil == 3)
        #expect(try JSONValue.from(t).decode(SessionSettings.self) == t && JSONValue.from(m).decode(SessionSettings.self) == m)
        #expect(ExamKind.goetheB1.settings(tasks: [Self.discuss], format: .training, teil: 2) == nil)
        #expect(ExamKind.goetheB1.settings(tasks: [Self.plan, Self.talk, Self.discuss])?.role == "Prüfer")
    }

    @Test func partnerVoiceIsDifferentAndAvoidsPremium() {
        func v(_ id: String, _ q: Int) -> Voices.Info { Voices.Info(id: id, name: id, language: "de-DE", quality: q) }
        let list = [v("petra", 3), v("anna-premium", 3), v("anna", 2), v("markus", 1)]
        #expect(ExamVoices.pick(preferred: "petra", available: list) == ExamVoices(examiner: "petra", partner: "anna"))
        #expect(ExamVoices.pick(preferred: "anna", available: list) == ExamVoices(examiner: "anna", partner: "petra"))
        #expect(ExamVoices.pick(preferred: nil, available: list) == ExamVoices(examiner: "petra", partner: "anna"))
        #expect(ExamVoices.pick(preferred: "gone", available: list).examiner == "petra")
        #expect(ExamVoices.pick(preferred: "petra", available: [v("petra", 3), v("anna-premium", 3)]).partner == "anna-premium")
        #expect(ExamVoices.pick(preferred: nil, available: [v("anna", 2)]) == ExamVoices(examiner: "anna", partner: "anna"))
        #expect(ExamVoices.pick(preferred: "x", available: []) == ExamVoices(examiner: "x", partner: "x"))
    }

    @Test func talkIsSplitIntoSentencesWithoutLoss() throws {
        #expect(ExamRun.sentences("Eins. Zwei! Drei?\nVier ohne Punkt") == ["Eins.", "Zwei!", "Drei?", "Vier ohne Punkt"])
        for t in ExamCatalog.tasks(.goetheB1, part: 2) {
            let talk = try #require(t.talk), parts = ExamRun.sentences(talk)
            #expect(parts.count >= 15 && parts.allSatisfy { $0.count <= 300 })
            #expect(parts.joined(separator: " ") == talk.replacingOccurrences(of: "\n", with: " "))
        }
    }

    // MARK: Prompts (BAC-10)

    @Test func trainingPromptCorrectsInlineAndMockKeepsTheExaminerRule() throws {
        #expect(ExamTests.tokens(PromptBuilder.goetheTrainingRule) <= 200)
        let training = PromptBuilder.system(try #require(ExamKind.goetheB1.settings(tasks: [Self.plan], format: .training, teil: 1)))
        #expect(training.contains(PromptBuilder.goetheTrainingRule) && !training.contains(PromptBuilder.examinerRule))
        #expect(training.contains("INLINE is on") && training.contains("@hint de:") && training.contains("Sag das bitte noch einmal"))
        #expect(training.contains("5. Russian without a request means") && training.contains("mistakes → review the last 10 utterances"))
        #expect(!training.contains("No spoken corrections") && !training.contains("silent @fix lines for the debrief"))
        #expect(training.contains("4b. Keep the current exam task") && training.contains("Your role: Gesprächspartner. Stay in it."))
        #expect(training.contains("Never rate pronunciation or give a score."))
        try ExamTests.fixture("prompts/prompt-exam-goethe_b1-training.txt", training, record: "LINGO_RECORD_SNAPSHOTS")
        // Mock: the legacy exam prompt with only the stored role changed.
        let ids = [Self.plan, Self.talk, Self.discuss]
        let mock = PromptBuilder.system(try #require(ExamKind.goetheB1.settings(tasks: ids, format: .mock, partnerTask: Self.partner)))
        let legacy = PromptBuilder.system(try #require(ExamKind.goetheB1.settings(tasks: ids)))
        #expect(mock.contains(PromptBuilder.examinerRule) && mock.contains("6. No spoken corrections"))
        #expect(mock == legacy.replacingOccurrences(of: "Your role: Prüfer.", with: "Your role: Gesprächspartner."))
    }

    @Test func examBlockPerFormatStaysWithinItsLimits() throws {
        func block(_ run: ExamRun) -> String { PromptBuilder.examBlock(run, now: ExamTests.start) }
        var m = Self.mock()
        m.advance(expected: .goetheIntro, timeUp: true, turnRunning: false, now: ExamTests.start)
        #expect(m.timeIsUp && !block(m).contains("time is up"), "BR-15")
        #expect(block(m).contains("accept one more if the learner brings it") && block(m).contains("4. Aktivitäten bei Regen"))
        m.advance(expected: .goethe1, timeUp: true, turnRunning: false, now: ExamTests.start)
        m.advance(expected: .goethe2, timeUp: true, turnRunning: false, now: ExamTests.start)
        let question = try #require(Self.text(Self.discuss).questions.first)
        #expect(block(m).contains("one short reaction to the talk and one question") && !block(m).contains("questions:") && !block(m).contains(question))
        m.advance(expected: .goethe3, timeUp: true, turnRunning: false, now: ExamTests.start)
        m.advance(expected: .goethePartner, timeUp: true, turnRunning: false, now: ExamTests.start)
        let summary = try #require(Self.text(Self.partner).talkSummary)
        #expect(block(m).contains("talk_summary: " + summary) && !block(m).contains("task:") && !block(m).contains("time is up"))
        var t = Self.training(3)
        t.advance(expected: .goethePartner, timeUp: false, turnRunning: false, now: ExamTests.start)
        t.advance(expected: .goetheFeedback, timeUp: false, turnRunning: false, now: ExamTests.start)
        #expect(block(t).contains("questions: " + question) && block(t).contains("ask nothing new"))
        // Every Goethe task in every part of every format: the block fits, and no sentence of a talk is in it.
        let talks = ExamCatalog.tasks(.goetheB1, part: 2)
        for two in talks {
            let three = try #require(ExamCatalog.tasks(.goetheB1, part: 3).first { $0.linkedTo == two.id })
            let other = try #require(talks.first { $0.id != two.id })
            var runs = [ExamRun(kind: .goetheB1, tasks: [Self.plan, two.id, three.id], format: .mock, partnerTask: other.id, now: ExamTests.start)!,
                        ExamRun(kind: .goetheB1, tasks: [two.id], format: .training, teil: 2, now: ExamTests.start)!,
                        ExamRun(kind: .goetheB1, tasks: [three.id], format: .training, teil: 3, now: ExamTests.start)!]
            for i in runs.indices {
                while !runs[i].finished {
                    let b = block(runs[i])
                    #expect(b.unicodeScalars.count <= 720 && ExamTests.tokens(b) <= 250, "\(runs[i].phase.rawValue) \(two.id)")
                    #expect(b.hasSuffix("\n</exam>") && ExamRun.sentences(two.talk ?? "").allSatisfy { !b.contains($0) })
                    runs[i].advance(expected: runs[i].phase, timeUp: false, turnRunning: false, now: ExamTests.start)
                }
            }
        }
        for one in ExamCatalog.tasks(.goetheB1, part: 1) {
            let b = block(ExamRun(kind: .goetheB1, tasks: [one.id], format: .training, teil: 1, now: ExamTests.start)!)
            #expect(ExamTests.tokens(b) <= 250 && one.points.allSatisfy(b.contains))
        }
    }

    @Test func mockTeil3RequestCarriesTheWholeTalkWithinItsCap() throws {
        func message(_ id: String, _ role: Role, _ text: String) -> ChatMessage {
            ChatMessage(id: id, session: "s", role: role, text: text, lang: .de, createdAt: ExamTests.start)
        }
        var run = Self.mock()
        for p in [ExamPhase.goetheIntro, .goethe1, .goethe2] { run.advance(expected: p, timeUp: false, turnRunning: false, now: ExamTests.start) }
        var history = (0..<10).flatMap { [message("p\($0)", .assistant, "Planung \($0)?"), message("l\($0)", .user, "Vorschlag \($0).")] }
        let lines = (0..<14).map { "Satz \($0) meines Vortrags über das Fahrrad." }
        history += lines.enumerated().map { message("t\($0.offset)", .user, $0.element) }
        run.ownTalk = lines.indices.map { "t\($0)" }
        let settings = try #require(ExamKind.goetheB1.settings(tasks: run.tasks, format: .mock, partnerTask: Self.partner))
        let req = PromptBuilder.dialogRequest(settings: settings, summary: "", messages: history, exam: run, now: ExamTests.start).messages[0].text
        #expect(req.contains("<transcript>\nlearner (de): " + lines.joined(separator: " ") + "\n</transcript>"))
        #expect(!req.contains("Vorschlag") && !req.contains("Planung") && req.contains("part: goethe_b1.3"))
        // Longer than the cap: every line is shortened evenly, none is dropped.
        let long = (0..<20).map { "Zeile \($0) " + String(repeating: "wort ", count: 80) }
        let longHistory = long.enumerated().map { message("t\($0.offset)", .user, $0.element) }
        run.ownTalk = long.indices.map { "t\($0)" }
        let cut = PromptBuilder.examOwnTalk(run, longHistory)
        #expect(cut?.count == 1 && (cut?[0].text.unicodeScalars.count ?? 0) <= PromptBuilder.examOwnTalkCap)
        #expect((0..<20).allSatisfy { cut?[0].text.contains("Zeile \($0) ") == true })
        // Other parts, a legacy run and a silent learner keep the usual window.
        run.ownTalk = []
        #expect(PromptBuilder.examOwnTalk(run, history) == nil)
        #expect(PromptBuilder.examOwnTalk(Self.training(3), history) == nil && PromptBuilder.examOwnTalk(nil, history) == nil)
    }

    // MARK: Mock (BAC-04, BAC-05)

    @Test func mockRunsItsPartsInOrderWithoutModelCallsForTheExaminerOrTheTalk() async throws {
        let (e, c, s) = try env()
        let sid = try #require(try await c.start(.goetheB1, tasks: [Self.plan, Self.talk, Self.discuss], format: .mock,
                                                 partnerTask: Self.partner, automaticTimer: false))
        await idle(c)
        #expect(c.run?.phase == .goetheIntro && e.requests.all.isEmpty && !e.sink.micMuted && c.speaker == nil)
        #expect(s.spoken.count == 1 && s.spoken[0].parts == [GoetheExaminerLine.intro.text] && s.spoken[0].voice == "voice-examiner")
        await c.submit("Ich heiße Max und lebe in Berlin.", lang: .de)
        c.advance(expected: .goethe1); await idle(c) // a stale Done
        #expect(c.run?.phase == .goetheIntro && e.requests.all.isEmpty, "the introduction is held: no model call")
        e.clock.date.addTimeInterval(60); c.tick(); await idle(c)
        #expect(c.run?.phase == .goethe1 && e.requests.all.count == 1)
        #expect(s.lines.suffix(2) == [GoetheExaminerLine.introEnd.text, GoetheExaminerLine.teil1.text])
        #expect(e.requests.all[0].contains("part: goethe_b1.1") && e.requests.all[0].contains("accept one more") && !e.requests.all[0].contains("time is up"))
        await c.submit("Wir treffen uns am Samstag.", lang: .de); await idle(c)
        #expect(e.requests.all.count == 2)
        await go(c, .goethe1)
        #expect(c.run?.phase == .goethe2 && e.requests.all.count == 2 && s.lines.last == GoetheExaminerLine.teil2.text)
        await c.submit("Ich fahre jeden Tag mit dem Fahrrad.", lang: .de)
        await c.submit("In meinem Heimatland ist das selten.", lang: .de)
        e.clock.date.addTimeInterval(239); c.tick(); await idle(c)
        #expect(c.run?.phase == .goethe2 && e.requests.all.count == 2, "the monologue is held for 240 s")
        e.clock.date.addTimeInterval(1); c.tick(); await idle(c)
        #expect(c.run?.phase == .goethe3 && e.requests.all.count == 3 && s.lines.last == GoetheExaminerLine.teil3.text)
        let reaction = e.requests.all[2]
        #expect(reaction.contains("learner (de): Ich fahre jeden Tag mit dem Fahrrad. In meinem Heimatland ist das selten."))
        #expect(!reaction.contains("Samstag") && !reaction.contains("questions:") && reaction.contains("one short reaction to the talk and one question"))
        let question = try #require(Self.text(Self.discuss).questions.first)
        await c.submit("Weil es gesund ist.", lang: .de); await idle(c)
        #expect(e.requests.all.count == 3 && s.spoken.last?.parts == [question] && s.spoken.last?.voice == "voice-examiner")
        let before = s.spoken.count
        await c.submit("Mehr Radwege würden helfen.", lang: .de); await idle(c)
        #expect(e.requests.all.count == 3 && s.spoken.count == before, "the second answer gets no reply")
        await go(c, .goethe3)
        // The partner's talk ends by itself in a Mock, then the feedback part opens.
        let talk = try #require(Self.text(Self.partner).talk)
        #expect(c.run?.phase == .goetheFeedback && e.requests.all.count == 3 && !e.sink.micMuted)
        #expect(s.spoken.suffix(3).map(\.parts) == [[GoetheExaminerLine.partnerTalk.text], ExamRun.sentences(talk), [GoetheExaminerLine.feedback.text]])
        #expect(s.spoken.suffix(3).map(\.voice) == ["voice-examiner", "voice-partner", "voice-examiner"])
        await c.submit("Interessant. Kaufen Sie auch Kleidung gebraucht?", lang: .de); await idle(c)
        let feedback = try #require(e.requests.all.last)
        #expect(e.requests.all.count == 4 && feedback.contains("part: goethe_b1.3.feedback") && feedback.contains("talk_summary: "))
        #expect(ExamRun.sentences(talk).allSatisfy { !e.requests.all.joined().contains($0) }, "the full talk is never sent")
        #expect(await e.store.state.examParts[sid] == [.goetheIntro, .goethe1, .goethe2, .goethe3, .goethePartner, .goetheFeedback])
        await go(c, .goetheFeedback)
        let st = await e.store.state
        #expect(c.run?.finished == true && e.sink.micMuted && st.sessions[sid]?.state == .ended)
        #expect(st.examParts[sid] == [.goetheIntro, .goethe1, .goethe2, .goethe3, .goethePartner, .goetheFeedback, .goetheEnd])
        #expect(st.sessions[sid]?.settings.corrections == [.after] && st.sessions[sid]?.settings.role == "Gesprächspartner")
        let stored = (st.messages[sid] ?? []).map(\.text).joined(separator: "\n")
        #expect(s.lines.allSatisfy { !stored.contains($0) }, "Examiner lines and the talk are never stored")
        #expect(s.closed.allSatisfy { $0 }, "the microphone is closed during every Examiner line and the talk")
        c.stop()
    }

    @Test func examinerLineClosesTheMicrophoneAndStartsTheTimerAfterwards() async throws {
        let (e, c, s) = try env(); s.hold = "voice-examiner"
        _ = try await c.start(.goetheB1, tasks: [Self.plan, Self.talk, Self.discuss], format: .mock, partnerTask: Self.partner, automaticTimer: false)
        for _ in 0..<400 where s.spoken.isEmpty { try? await Task.sleep(for: .milliseconds(5)) }
        #expect(c.busy && c.speaker == .examiner && e.sink.micMuted && !c.microphoneAllowed && c.beginCapture() == nil)
        e.clock.date.addTimeInterval(100); c.tick(); c.tick()
        #expect(c.run?.phase == .goetheIntro, "the timer does not run during the line")
        s.hold = nil; await idle(c)
        #expect(!e.sink.micMuted && c.speaker == nil && c.run?.remaining(now: e.clock.date) == 60)
        // The talk: closed for the whole part; Done stops the speech and moves on.
        for p in [ExamPhase.goetheIntro, .goethe1, .goethe2] { await go(c, p) }
        s.hold = "voice-partner"
        c.advance(expected: .goethe3)
        for _ in 0..<400 where s.spoken.last?.voice != "voice-partner" { try? await Task.sleep(for: .milliseconds(5)) }
        #expect(c.run?.phase == .goethePartner && c.speaker == .partner && e.sink.micMuted && c.beginCapture() == nil)
        await c.submit("not captured", lang: .de)
        e.sink.playing = true
        c.advance(expected: .goethePartner)
        #expect(e.sink.stops == 1, "Done stops the partner's speech")
        s.hold = nil; await idle(c)
        #expect(c.run?.phase == .goetheFeedback && !e.sink.micMuted)
        #expect(await e.store.state.messages[c.sessionID!]?.contains { $0.text == "not captured" } != true)
        // The safety limit of the talk is covered by the same path: a tick at zero is a Done.
        c.stop()
        #expect(await e.store.state.examParts[c.sessionID!]?.contains(.goetheEnd) == false, "Finish never writes the end marker")
        #expect(await e.store.state.sessions[c.sessionID!]?.state != .ended)
    }

    // MARK: Training (BAC-08)

    @Test func trainingTeil1HasSoftTimersAndEndsWithDone() async throws {
        let (e, c, s) = try env()
        let sid = try #require(try await c.start(.goetheB1, tasks: [Self.plan], format: .training, teil: 1, automaticTimer: false))
        await idle(c)
        #expect(c.run?.phase == .goethe1 && s.lines == [GoetheExaminerLine.teil1.text] && e.requests.all.count == 1)
        e.clock.date.addTimeInterval(999); for _ in 0..<3 { c.tick() }; await idle(c)
        #expect(c.run?.phase == .goethe1 && c.run?.finished == false && c.run?.remaining(now: e.clock.date) == 0)
        await c.submit("Wie wäre es am Samstag?", lang: .de); await idle(c)
        #expect(e.requests.all.count == 2 && e.requests.all[1].contains("within the training rule"))
        #expect(await e.store.state.sessions[sid]?.settings.corrections == [.inline])
        await go(c, .goethe1)
        #expect(c.run?.finished == true && s.spoken.count == 1)
        #expect(await e.store.state.examParts[sid] == [.goethe1, .goetheEnd])
        #expect(await e.store.state.sessions[sid]?.state == .ended)
    }

    @Test func trainingTeil2MonologueEndsAtItsLimitWithoutAModelCall() async throws {
        let (e, c, s) = try env()
        let sid = try #require(try await c.start(.goetheB1, tasks: [Self.talk], format: .training, teil: 2, automaticTimer: false))
        await idle(c)
        #expect(s.lines == [GoetheExaminerLine.teil2.text] && !e.sink.micMuted)
        await c.submit("Mein Thema ist das Fahrrad.", lang: .de)
        e.clock.date.addTimeInterval(239); c.tick(); await idle(c)
        #expect(c.run?.finished == false)
        e.clock.date.addTimeInterval(1); c.tick(); await idle(c)
        #expect(c.run?.finished == true && e.requests.all.isEmpty)
        #expect(await e.store.state.examParts[sid] == [.goethe2, .goetheEnd])
    }

    @Test func trainingTeil3ListensWithReplayThenFeedbackThenTheQuestion() async throws {
        let (e, c, s) = try env()
        let sid = try #require(try await c.start(.goetheB1, tasks: [Self.discuss], format: .training, teil: 3, automaticTimer: false))
        await idle(c)
        let talk = ExamRun.sentences(try #require(Self.text(Self.talk).talk))
        #expect(s.spoken.map(\.parts) == [[GoetheExaminerLine.partnerTalk.text], talk] && s.spoken[1].voice == "voice-partner")
        // The part does not end by itself, and the microphone stays closed after the speech.
        e.clock.date.addTimeInterval(999); c.tick(); await idle(c)
        #expect(c.run?.phase == .goethePartner && e.sink.micMuted && c.beginCapture() == nil && e.requests.all.isEmpty)
        c.replayTalk(); await idle(c)
        #expect(s.spoken.count == 3 && s.spoken[2].parts == talk && c.run?.phase == .goethePartner)
        await go(c, .goethePartner)
        #expect(c.run?.phase == .goetheFeedback && s.lines.last == GoetheExaminerLine.feedback.text && !e.sink.micMuted && e.requests.all.isEmpty)
        c.replayTalk(); await idle(c)
        #expect(s.spoken.count == 4, "Replay belongs to the talk part only")
        await c.submit("Guter Vortrag. Fahren Sie auch im Winter?", lang: .de); await idle(c)
        #expect(e.requests.all.count == 1 && e.requests.all[0].contains("talk_summary: "))
        e.clock.date.addTimeInterval(999); c.tick(); await idle(c)
        #expect(c.run?.phase == .goetheFeedback)
        await go(c, .goetheFeedback)
        let question = try #require(Self.text(Self.discuss).questions.first)
        #expect(c.run?.phase == .goethe3 && s.spoken.last?.parts == [GoetheExaminerLine.teil3.text, question] && e.requests.all.count == 1)
        await c.submit("Sichere Radwege wären wichtig.", lang: .de); await idle(c)
        #expect(e.requests.all.count == 2 && e.requests.all[1].contains("questions: " + question) && e.requests.all[1].contains("ask nothing new"))
        await go(c, .goethe3)
        let st = await e.store.state
        #expect(st.examParts[sid] == [.goethePartner, .goetheFeedback, .goethe3, .goetheEnd] && st.sessions[sid]?.state == .ended)
        let stored = (st.messages[sid] ?? []).map(\.text).joined(separator: "\n")
        #expect(talk.allSatisfy { !stored.contains($0) && !e.requests.all.joined().contains($0) }, "the talk is neither stored nor sent")
    }

    // MARK: Voice loop (BR-10, BR-23)

    @Test func voiceLoopSpeaksLinesAsTheExaminerAndRepliesAsThePartner() async throws {
        let e = try await TurnControllerTests().env(texts: [])
        let clock = ExamControllerTests.Clock()
        let c = ExamController(engine: e.engine, sink: e.sink, now: { clock.date }) { [weak tc = e.tc, store = e.store, holder = e.holder] stream in
            if let sid = tc?.exam?.sessionID, let session = await store.state.sessions[sid] {
                holder?.ctx = TurnController.Context(session: session, lastAssistant: nil, lastUser: nil, phrases: [])
            }
            await tc?.consumeExamReply(stream)
        }
        c.voices = ExamVoices(examiner: "voice-examiner", partner: "voice-partner")
        c.speak = { [weak tc = e.tc] parts, voice in await tc?.speakExam(parts, lang: .de, voiceID: voice) }
        e.tc.exam = c
        defer { e.tc.stopVoice(cancelTurn: true) }
        _ = try await c.start(.goetheB1, tasks: [Self.plan], format: .training, teil: 1, automaticTimer: false)
        // The line plays: no audio is taken, and the partner's request waits for its end.
        await e.waitUntil { e.sink.spoken.count == 1 }
        e.tc.startContinuous(); e.tc.pushDown()
        await e.feed(600, speech: true); e.tc.pushUp()
        #expect(e.sink.playing && e.sink.stops == 0 && e.log.all.isEmpty && e.sink.micMuted, "no barge-in on the Examiner")
        #expect(e.sink.spoken.map(\.0) == [GoetheExaminerLine.teil1.text] && e.sink.voices == ["voice-examiner"])
        e.sink.finish()
        await e.waitUntil { e.sink.spoken.count == 2 }
        #expect(e.log.all.count == 1 && e.sink.voices.last == "voice-partner")
        await ExamVoiceTests().drain(e, c)
        #expect(!e.sink.micMuted && c.canCapture)
    }
}
