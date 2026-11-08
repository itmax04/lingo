import Foundation
import Testing
@testable import LingoCore

/// LINGO-05 T-9a: the daily reminder (GR-08, TAC-15): scheduling decisions as pure functions and against a fake notification centre.
@Suite struct ReminderTests {
    static let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Berlin")!; return c }()
    static func local(_ month: Int, _ day: Int, _ h: Int, _ m: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: h, minute: m))!
    }
    static let time = 19 * 60

    final class FakeCenter: ReminderCenter, @unchecked Sendable {
        private let lock = NSLock()
        var auth: ReminderAuth
        private(set) var pending: [String: (fire: Date, title: String, body: String)] = [:]
        private(set) var asked = 0
        init(_ auth: ReminderAuth) { self.auth = auth }
        func authorization() async -> ReminderAuth { lock.withLock { auth } }
        func requestAuthorization() async -> Bool { lock.withLock { asked += 1; return auth == .authorized } }
        func cancel(id: String) async { lock.withLock { pending[id] = nil } }
        func schedule(id: String, fire: Date, title: String, body: String) async { lock.withLock { pending[id] = (fire, title, body) } }
        var fire: Date? { lock.withLock { pending[Reminder.notificationID]?.fire } }
        var body: String? { lock.withLock { pending[Reminder.notificationID]?.body } }
    }

    /// A journal with one session and `minutes` of practice at 08:00 on 2026-11-09 (goal 15 until set).
    static func state(minutes: Int, goal: Int? = nil) -> HistoryState {
        var out: [Event] = []
        func add(_ type: String, _ session: String, _ at: Date, _ payload: some Encodable) {
            let n = out.count + 1
            out.append(Event(id: String(format: "01M5REMIND%016d", n), device: "mac-remind0001", seq: n, lamport: n, ts: at, type: type,
                             session: session, payload: try! JSONValue.from(payload)))
        }
        add(EventType.sessionCreated, "s", local(11, 9, 7, 59), Payload.SessionCreated(title: "s", settings: SessionSettings(lang: .de, mode: .free, corrections: [.after])))
        if let goal { add(EventType.goalSet, "", local(11, 9, 7, 59), Payload.GoalSet(minutes: goal)) }
        for i in 0...minutes {
            add(EventType.messageCreated, "s", local(11, 9, 8).addingTimeInterval(Double(i) * 60),
                Payload.MessageCreated(role: i % 2 == 0 ? .user : .assistant, text: "Ich gehe heute einkaufen.", lang: .de))
        }
        return Merger.build(out)
    }

    static func settings(on: Bool = true) -> AppSettings { var s = AppSettings(); s.reminderOn = on; s.reminderTime = time; s.lastLang = .de; return s }
    static let text: @Sendable (Int, Lang) -> (title: String, body: String) = { m, l in ("Lingo", "Time for \(m) minutes of \(l.rawValue)?") }

    @Test func nextTimeFollowsTheGoalAndTheClock() {
        let now = Self.local(11, 9, 12)
        #expect(Reminder.next(now: now, calendar: Self.cal, goalReached: false, on: true, time: Self.time) == Self.local(11, 9, 19))
        #expect(Reminder.next(now: now, calendar: Self.cal, goalReached: true, on: true, time: Self.time) == Self.local(11, 10, 19), "goal reached: tomorrow")
        #expect(Reminder.next(now: Self.local(11, 9, 19, 30), calendar: Self.cal, goalReached: false, on: true, time: Self.time) == Self.local(11, 10, 19), "time passed")
        #expect(Reminder.next(now: Self.local(11, 9, 19), calendar: Self.cal, goalReached: false, on: true, time: Self.time) == Self.local(11, 10, 19), "exactly now is not pending")
        #expect(Reminder.next(now: now, calendar: Self.cal, goalReached: false, on: false, time: Self.time) == nil)
        #expect(Reminder.next(now: now, calendar: Self.cal, goalReached: false, on: true, time: 99_999) == Self.local(11, 9, 23, 59), "time clamped")
    }

    @Test func nextDayAcrossTheDSTChangeKeepsTheWallClockTime() {
        // 2026-10-25 02:00 → 01:00 in Berlin: 19:00 stays 19:00 on both sides.
        let now = Self.local(10, 24, 20)
        let fire = Reminder.next(now: now, calendar: Self.cal, goalReached: false, on: true, time: Self.time)!
        #expect(Self.cal.dateComponents([.day, .hour, .minute], from: fire) == DateComponents(day: 25, hour: 19, minute: 0))
    }

    @Test func schedulesRemovesOnGoalAndMovesToTomorrow() async {
        let center = FakeCenter(.authorized)
        let now = Self.local(11, 9, 12)
        // Goal 15, 5 minutes done: today's reminder is pending with the goal and language.
        var status = await Reminder.sync(state: Self.state(minutes: 5), settings: Self.settings(), now: now, calendar: Self.cal, center: center, text: Self.text)
        #expect(status == .scheduled(Self.local(11, 9, 19)) && center.fire == Self.local(11, 9, 19) && center.body == "Time for 15 minutes of de?")
        // The goal is reached: today's notification is replaced by tomorrow's (one pending only).
        status = await Reminder.sync(state: Self.state(minutes: 15), settings: Self.settings(), now: now, calendar: Self.cal, center: center, text: Self.text)
        #expect(status == .scheduled(Self.local(11, 10, 19)) && center.fire == Self.local(11, 10, 19) && center.pending.count == 1)
        // The next day, goal not reached yet, before 19:00: that day's time.
        status = await Reminder.sync(state: Self.state(minutes: 15), settings: Self.settings(), now: Self.local(11, 10, 8), calendar: Self.cal, center: center, text: Self.text)
        #expect(status == .scheduled(Self.local(11, 10, 19)))
        // A goal change is honoured: goal 5 is reached by 5 minutes.
        status = await Reminder.sync(state: Self.state(minutes: 5, goal: 5), settings: Self.settings(), now: now, calendar: Self.cal, center: center, text: Self.text)
        #expect(status == .scheduled(Self.local(11, 10, 19)) && center.body == "Time for 5 minutes of de?")
    }

    @Test func offAndDeniedPermissionLeaveNothingPending() async {
        let center = FakeCenter(.authorized)
        let now = Self.local(11, 9, 12)
        _ = await Reminder.sync(state: Self.state(minutes: 5), settings: Self.settings(), now: now, calendar: Self.cal, center: center, text: Self.text)
        #expect(center.fire != nil)
        var status = await Reminder.sync(state: Self.state(minutes: 5), settings: Self.settings(on: false), now: now, calendar: Self.cal, center: center, text: Self.text)
        #expect(status == .off && center.fire == nil, "switching off removes it")
        center.auth = .denied
        status = await Reminder.sync(state: Self.state(minutes: 5), settings: Self.settings(), now: now, calendar: Self.cal, center: center, text: Self.text)
        #expect(status == .blocked(.denied) && center.fire == nil && center.asked == 0, "denied: nothing pending, no prompt from sync")
        center.auth = .notDetermined
        status = await Reminder.sync(state: Self.state(minutes: 5), settings: Self.settings(), now: now, calendar: Self.cal, center: center, text: Self.text)
        #expect(status == .blocked(.notDetermined) && center.fire == nil && center.asked == 0, "sync never asks for permission")
    }

    @Test func settingsAreOffByDefaultAndDecodeTolerantly() throws {
        let fresh = AppSettings()
        #expect(!fresh.reminderOn && fresh.reminderTime == Reminder.defaultTime)
        let old = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"onboardingDone":true}"#.utf8))
        #expect(!old.reminderOn && old.reminderTime == Reminder.defaultTime)
        let odd = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"reminderOn":true,"reminderTime":5000}"#.utf8))
        #expect(odd.reminderOn && odd.reminderTime == 24 * 60 - 1)
        let bad = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"reminderOn":"yes","reminderTime":"noon"}"#.utf8))
        #expect(!bad.reminderOn && bad.reminderTime == Reminder.defaultTime)
    }
}
