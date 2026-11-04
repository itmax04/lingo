import Foundation

/// Live XR-02 coordination. The consumer must drain the reply AND its speech before returning.
/// The Mac attaches the view/timer callbacks and TurnController; no live provider is needed in tests.
@MainActor
public final class ExamController {
    public private(set) var sessionID: String?
    public private(set) var run: ExamRun?
    public private(set) var busy = false
    public private(set) var monologueReleased = false
    public var onChange: (() -> Void)?
    public var onFinished: (() -> Void)?
    public var onFailure: ((Error) -> Void)?
    /// Flush a recording into recognition before a deadline releases the held monologue.
    public var flushUtterance: (() -> Void)?
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

    public init(engine: DialogEngine, sink: SpeechSink, now: @escaping () -> Date = Date.init,
                consume: @escaping (AsyncStream<TurnEvent>) async -> Void) {
        self.engine = engine; self.sink = sink; self.now = now; self.consume = consume
    }

    public var microphoneAllowed: Bool { !stopped && pending == nil && run?.microphoneAllowed == true }
    public var canCapture: Bool { microphoneAllowed && captures.isEmpty && (!busy || replying) }

    /// A single controller is single-use. The guard precedes the first suspension (double Start).
    @discardableResult public func start(_ kind: ExamKind, tasks: [String]? = nil, automaticTimer: Bool = true) async throws -> String? {
        guard !starting, sessionID == nil, !stopped else { return sessionID }
        let ids = tasks ?? kind.drawTasks()
        guard let settings = kind.settings(tasks: ids) else { return nil }
        starting = true
        sink.micMuted = true
        defer { starting = false }
        let sid = try await engine.createSession(settings)
        sessionID = sid
        guard !stopped else { return sid }
        run = ExamRun(kind: kind, tasks: ids, now: now())
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
        if run?.phase.isPreparation == false { request() }
        return sid
    }

    public func tick() {
        onChange?()
        guard let r = run, !r.finished, !stopped, r.remaining(now: now()) == 0 else { return }
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
        drainTransition()
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
            if userWaiting, pending == nil, captures.isEmpty, !busy { request(replyTo: lastUser) }
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
        sink.stopSpeaking(); sink.micMuted = true
        onChange?()
    }

    private func updateMicrophone() { sink.micMuted = !microphoneAllowed; onChange?() }

    private func recordPhase() async throws {
        guard let sid = sessionID, let r = run else { return }
        _ = try await engine.store.append(EventType.examPart, session: sid, Payload.ExamPart(part: r.phase))
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
        updateMicrophone()
        busy = true
        operation = Task { [weak self] in
            guard let self, !self.stopped, !Task.isCancelled else { return }
            do {
                if self.run?.finished == true {
                    self.timer?.cancel()
                    if let sid = self.sessionID {
                        _ = try await self.engine.store.append(EventType.sessionEnded, session: sid, payload: .object([:]))
                    }
                    if !self.stopped { self.onFinished?() }
                } else { try await self.recordPhase() }
            } catch { self.stop(); self.onFailure?(error); return }
            guard !self.stopped, !Task.isCancelled else { return }
            self.busy = false; self.onChange?()
            if self.run?.finished == false, self.run?.phase.isPreparation == false,
               self.run?.phase.isMonologue == false { self.request() }
            else { self.drainTransition() }
        }
    }

    private func request(replyTo: String? = nil) {
        guard !stopped, !busy, let sid = sessionID, let snapshot = run, !snapshot.finished, !snapshot.phase.isPreparation else { return }
        busy = true; replying = true; userWaiting = false
        run?.consumeTransition()
        operation = Task { [weak self] in
            guard let self, !self.stopped, !Task.isCancelled else { return }
            await self.consume(self.engine.respond(session: sid, replyTo: replyTo, exam: snapshot))
            guard !self.stopped, !Task.isCancelled else { return }
            self.busy = false; self.replying = false; self.onChange?(); self.drainTransition()
            if self.userWaiting, self.pending == nil, self.captures.isEmpty { self.request(replyTo: self.lastUser) }
        }
    }
}
