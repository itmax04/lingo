import Foundation

/// LINGO-10 BR-23: who the app is speaking as. Model replies of a run with a format are the partner's.
public enum ExamSpeaker: Sendable { case examiner, partner }

/// BR-23: the Examiner keeps the learner's German voice; the partner takes the first other voice, a non-Premium one first when the
/// Examiner's is Premium (memory, AGENTS.md §8). With one installed voice both share it. A pure function of the voice list.
public struct ExamVoices: Sendable, Equatable {
    public var examiner: String?
    public var partner: String?
    public init(examiner: String? = nil, partner: String? = nil) { self.examiner = examiner; self.partner = partner }
    public static func pick(preferred: String?, available: [Voices.Info]) -> ExamVoices {
        guard let examiner = available.first(where: { $0.id == preferred }) ?? available.first else {
            return ExamVoices(examiner: preferred, partner: preferred)
        }
        let others = available.filter { $0.id != examiner.id }
        let partner = (examiner.quality >= 3 ? others.first { $0.quality < 3 } : nil) ?? others.first ?? examiner
        return ExamVoices(examiner: examiner.id, partner: partner.id)
    }
}

/// Live XR-02 coordination. The consumer must drain the reply AND its speech before returning.
/// The Mac attaches the view/timer callbacks and TurnController; no live provider is needed in tests.
@MainActor
public final class ExamController {
    public private(set) var sessionID: String?
    public private(set) var run: ExamRun?
    public private(set) var busy = false
    public private(set) var monologueReleased = false
    public var onChange: (() -> Void)?
    /// Host selects and attaches the newly created session before any input or opening reply.
    public var onStarted: ((String) async -> Void)?
    public var onFinished: (() -> Void)?
    public var onFailure: ((Error) -> Void)?
    /// Flush a recording into recognition before a deadline releases the held monologue.
    public var flushUtterance: (() -> Void)?
    /// LINGO-10 BR-10: speaks Examiner lines and the partner's talk in the given voice; returns when the speech has ended or was
    /// stopped. The text is never stored and never sent to a model.
    public var speak: (([String], String?) async -> Void)?
    public var voices = ExamVoices()
    /// BR-23: the current speaker for the exam panel; nil while the learner has the floor.
    public private(set) var speaker: ExamSpeaker?
    private let engine: DialogEngine
    private let sink: SpeechSink
    private let consume: (AsyncStream<TurnEvent>) async -> Void
    private let now: () -> Date
    private var timer: Task<Void, Never>?
    private var operation: Task<Void, Never>?
    private var captures: Set<UUID> = []
    private var pending: (ExamPhase, Bool)?
    private var stopped = false
    private var starting = false
    private var lastUser: String?
    private var replying = false
    private var userWaiting = false
    /// An Examiner line is being spoken: microphone closed, the timer waits (BR-10).
    private var lineRunning = false
    private var talking = false
    /// Learner answers in the current part that reached `answer()` (BR-14).
    private var answers = 0

    public init(engine: DialogEngine, sink: SpeechSink, now: @escaping () -> Date = Date.init,
                consume: @escaping (AsyncStream<TurnEvent>) async -> Void) {
        self.engine = engine; self.sink = sink; self.now = now; self.consume = consume
    }

    public var microphoneAllowed: Bool { !stopped && pending == nil && !lineRunning && run?.microphoneAllowed == true }
    /// The voice of a model reply: the partner's in a run with a format (BR-23).
    public var replyVoice: String? { run?.format == nil ? nil : voices.partner }
    public var canCapture: Bool { microphoneAllowed && captures.isEmpty && (!busy || replying) }

    /// A single controller is single-use. The guard precedes the first suspension (double Start).
    /// A Mock needs its three tasks and `partnerTask`; a Training its one task and `teil` (BR-01).
    @discardableResult public func start(_ kind: ExamKind, tasks: [String]? = nil, format: Activity.Format? = nil, teil: Int? = nil,
                                         partnerTask: String? = nil, automaticTimer: Bool = true) async throws -> String? {
        guard !starting, sessionID == nil, !stopped else { return sessionID }
        let ids = tasks ?? kind.drawTasks()
        guard let settings = kind.settings(tasks: ids, format: format, teil: teil, partnerTask: partnerTask) else { return nil }
        starting = true
        sink.micMuted = true
        defer { starting = false }
        let sid = try await engine.createSession(settings)
        sessionID = sid
        await onStarted?(sid)
        guard !stopped else { return sid }
        run = ExamRun(kind: kind, tasks: ids, format: format, teil: teil, partnerTask: partnerTask, now: now())
        lineRunning = format != nil
        do { try await recordPhase() } catch { stop(); throw error }
        guard !stopped else { return sid }
        updateMicrophone()
        if automaticTimer {
            timer = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled, let self else { return }
                    self.tick()
                }
            }
        }
        if format != nil { open() } else if run?.phase.isPreparation == false { request() }
        return sid
    }

    public func tick() {
        onChange?()
        guard let r = run, !r.finished, !stopped, !lineRunning, r.endsAtZero, r.remaining(now: now()) == 0 else { return }
        // IELTS's one follow-up is outside the held two-minute talk. Its answer starts Part 3.
        guard !(r.phase == .ielts2 && monologueReleased) else { return }
        advance(expected: r.phase, timeUp: true)
    }

    /// The UI passes the phase it displayed: stale Done clicks cannot skip the next part.
    public func advance(expected: ExamPhase, timeUp: Bool = false) {
        guard !stopped, let r = run, !r.finished, r.phase == expected else { return }
        guard !(expected == .ielts2 && monologueReleased) else { return }
        flushUtterance?()
        if pending == nil { pending = (expected, timeUp) }
        stopTalk() // BR-13: Done or the safety limit stops the partner's speech
        drainTransition()
    }

    /// BR-17: Replay restarts the partner's talk in Training.
    public func replayTalk() {
        guard !stopped, pending == nil, !lineRunning, let r = run, r.format == .training, r.phase == .goethePartner else { return }
        stopTalk(); talk()
    }

    /// Called synchronously before STT starts, so a deadline waits for that transcript.
    public func beginCapture() -> UUID? {
        guard canCapture else { return nil }
        return enqueueCapture()
    }

    /// Reserve closed audio synchronously, even while earlier recognition/journal work is pending.
    /// TurnController drains these reservations in audio order; transitions wait for every token.
    func enqueueCapture() -> UUID? {
        guard microphoneAllowed, !busy || replying else { return nil }
        let token = UUID(); captures.insert(token)
        return token
    }

    func ownsCapture(_ token: UUID) -> Bool { !stopped && captures.contains(token) }

    public func endCapture(_ token: UUID, text: String, lang: Lang) async {
        guard captures.contains(token), !stopped, let sid = sessionID, let r = run else { return }
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Keep the capture lock across journal I/O; a timer cannot overtake the final utterance.
        if !text.isEmpty {
            do { lastUser = try await engine.recordUser(session: sid, text: text, lang: lang) }
            catch { stop(); onFailure?(error); return }
            if r.format == .mock, r.phase == .goethe2, let id = lastUser { run?.ownTalk.append(id) }
        }
        guard captures.contains(token), !stopped else { return }
        captures.remove(token)
        if r.phase.isMonologue && !monologueReleased {
            if ExamRun.isDoneUtterance(text), pending == nil { pending = (r.phase, false) }
            drainTransition()
        } else if r.phase == .ielts2, !text.isEmpty {
            pending = (.ielts2, false); drainTransition()
        } else {
            if !text.isEmpty { userWaiting = true }
            drainTransition()
            if userWaiting, pending == nil, captures.isEmpty, !busy { answer() }
        }
    }

    /// Typed input follows exactly the same holding/release rules as recognition.
    public func submit(_ text: String, lang: Lang) async {
        guard let token = beginCapture() else { return }
        await endCapture(token, text: text, lang: lang)
    }

    /// Finish, deletion or leaving the live exam: no timer, late transcript, transition or speech survives.
    public func stop() {
        stopped = true; timer?.cancel(); timer = nil; operation?.cancel(); operation = nil
        captures.removeAll(); pending = nil; busy = false; replying = false; userWaiting = false
        lineRunning = false; talking = false; speaker = nil
        sink.stopSpeaking(); sink.micMuted = true
        onChange?()
    }

    private func updateMicrophone() { sink.micMuted = !microphoneAllowed; onChange?() }

    private func recordPhase(_ part: ExamPhase? = nil) async throws {
        guard let sid = sessionID, let r = run else { return }
        _ = try await engine.store.append(EventType.examPart, session: sid, Payload.ExamPart(part: part ?? r.phase))
    }

    private func say(_ who: ExamSpeaker, _ parts: [String]) async {
        guard !parts.isEmpty, !stopped else { return }
        speaker = who; onChange?()
        await speak?(parts, who == .examiner ? voices.examiner : voices.partner)
        guard !stopped, !Task.isCancelled else { return }
        speaker = nil; onChange?()
    }

    /// An Examiner line: the microphone is closed until it has ended (BR-10).
    private func line(_ parts: [String], then next: @escaping (ExamController) -> Void) {
        busy = true; lineRunning = true; updateMicrophone()
        operation = Task { [weak self] in
            guard let self, !self.stopped, !Task.isCancelled else { return }
            await self.say(.examiner, parts)
            guard !self.stopped, !Task.isCancelled else { return }
            self.busy = false; self.lineRunning = false
            next(self)
        }
    }

    /// LINGO-10 BR-10: a part of a run with a format opens with its Examiner line; then its timer starts and the part begins.
    private func open() {
        guard !stopped, let r = run, !r.finished else { return }
        // A turn left unanswered by the previous part's end is not answered in this one.
        answers = 0; userWaiting = false
        line(r.examinerOpening) { c in
            c.run?.restart(now: c.now())
            c.updateMicrophone()
            if c.pending != nil { c.drainTransition() } // Done during the line
            else if r.phase == .goethe1 || (r.phase == .goethe3 && r.format == .mock) { c.request() }
            else if r.phase == .goethePartner { c.talk() }
        }
    }

    /// BR-13, BR-17: the pre-written talk, spoken and never stored. A Mock moves on when the speech has ended; a Training waits for Done.
    private func talk() {
        guard !stopped, !busy, let r = run, r.phase == .goethePartner, let text = r.task.talk else { return }
        busy = true; talking = true; onChange?()
        operation = Task { [weak self] in
            guard let self, !self.stopped, !Task.isCancelled else { return }
            await self.say(.partner, ExamRun.sentences(text))
            guard !self.stopped, !Task.isCancelled else { return }
            self.busy = false; self.talking = false; self.onChange?()
            if r.format == .mock, self.pending == nil { self.pending = (.goethePartner, false) }
            self.drainTransition()
        }
    }

    private func stopTalk() {
        guard talking else { return }
        operation?.cancel(); operation = nil; sink.stopSpeaking()
        talking = false; busy = false; speaker = nil
    }

    /// The reply to the learner's turn. BR-14: in Mock Teil 3 the first answer is followed by the Examiner's catalogue question
    /// (no model call), and a later answer gets no reply: the part waits for its timer or Done.
    private func answer() {
        guard let r = run, r.format == .mock, r.phase == .goethe3 else { request(replyTo: lastUser); return }
        userWaiting = false; answers += 1
        guard answers == 1, !r.task.questions.isEmpty else { return }
        line(Array(r.task.questions.prefix(1))) { c in c.updateMicrophone(); c.drainTransition() }
    }

    private func drainTransition() {
        guard !stopped, !busy, captures.isEmpty, let (phase, timeUp) = pending, let r = run else { return }
        pending = nil
        if r.phase.isMonologue && !monologueReleased {
            monologueReleased = true
            if phase == .ielts2 { request(); return } // one follow-up, still using the cue card
        }
        guard run?.advance(expected: phase, timeUp: timeUp, turnRunning: false, now: now()) == true else { return }
        monologueReleased = false
        let formatted = run?.format != nil
        lineRunning = formatted && run?.finished == false // the next part's Examiner line follows: no open microphone in between
        updateMicrophone()
        busy = true; onChange?()
        operation = Task { [weak self] in
            guard let self, !self.stopped, !Task.isCancelled else { return }
            // BR-11: the Examiner thanks the learner for the introduction before Teil 1 begins.
            if formatted, phase == .goetheIntro { await self.say(.examiner, [GoetheExaminerLine.introEnd.text]) }
            guard !self.stopped, !Task.isCancelled else { return }
            do {
                if self.run?.finished == true {
                    self.timer?.cancel()
                    // BR-02a: the end marker, written only here: the run reached its natural end.
                    if formatted { try await self.recordPhase(.goetheEnd) }
                    if let sid = self.sessionID {
                        _ = try await self.engine.store.append(EventType.sessionEnded, session: sid, payload: .object([:]))
                    }
                    if !self.stopped { self.onFinished?() }
                } else { try await self.recordPhase() }
            } catch { self.stop(); self.onFailure?(error); return }
            guard !self.stopped, !Task.isCancelled else { return }
            self.busy = false; self.onChange?()
            if formatted { self.open() }
            else if self.run?.finished == false, self.run?.phase.isPreparation == false,
               self.run?.phase.isMonologue == false { self.request() }
            else { self.drainTransition() }
        }
    }

    private func request(replyTo: String? = nil) {
        guard !stopped, !busy, let sid = sessionID, let snapshot = run, !snapshot.finished, !snapshot.phase.isPreparation else { return }
        busy = true; replying = true; userWaiting = false
        if snapshot.format != nil { speaker = .partner }
        onChange?()
        run?.consumeTransition()
        operation = Task { [weak self] in
            guard let self, !self.stopped, !Task.isCancelled else { return }
            await self.consume(self.engine.respond(session: sid, replyTo: replyTo, exam: snapshot))
            guard !self.stopped, !Task.isCancelled else { return }
            self.busy = false; self.replying = false; self.speaker = nil; self.onChange?(); self.drainTransition()
            if self.userWaiting, self.pending == nil, self.captures.isEmpty, !self.busy { self.answer() }
        }
    }
}
