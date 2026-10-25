import Foundation

/// Версия значения для «последняя запись побеждает» (R-37): больший `lamport`, при равенстве — больший `device`.
public struct Version: Comparable, Sendable, Hashable {
    public var lamport: Int
    public var device: String
    public var id: String

    public init(_ e: Event) { lamport = e.lamport; device = e.device; id = e.id }

    public static func < (a: Version, b: Version) -> Bool {
        (a.lamport, a.device, a.id) < (b.lamport, b.device, b.id)
    }
}

/// Регистр LWW: значение с версией. Применение не зависит от порядка поступления событий.
public struct LWW<T: Sendable & Hashable>: Sendable, Hashable {
    public private(set) var value: T
    public private(set) var version: Version?

    public init(_ value: T) { self.value = value }

    public mutating func apply(_ v: T, _ ver: Version) {
        if let cur = version, ver <= cur { return }
        value = v
        version = ver
    }
}

/// Запись `@fix` с привязкой к сообщению (R-20, R-23).
public struct FixEntry: Sendable, Hashable {
    public var message: String
    public var fix: Fix
    public var ts: Date
}

/// Состояние истории, построенное из множества событий (R-37). Чистая функция множества:
/// результат не зависит от порядка и повторов событий (коммутативность и идемпотентность объединения).
public struct HistoryState: Sendable {
    public var sessions: [String: Session] = [:]
    /// Сообщения сессии в порядке (`ts`, `device`, `seq`).
    public var messages: [String: [ChatMessage]] = [:]
    public var fixes: [String: [FixEntry]] = [:]
    /// Подсказки сессии (`hint.added`), без повторов по ключу фразы.
    public var hints: [String: [Phrase]] = [:]
    /// Словарь ★ (R-28): ключ фразы → фраза.
    public var starred: [String: Phrase] = [:]
    public var eventCount = 0
    public var maxLamport = 0
    /// Последний `seq` каждого устройства — для своего устройства это продолжение нумерации.
    public var lastSeq: [String: Int] = [:]
    /// События неизвестных типов (сохраняются в журнале, при построении игнорируются).
    public var unknownEvents = 0

    public init() {}

    /// Видимые сессии по последней активности (R-05).
    public func visibleSessions(lang: Lang? = nil) -> [Session] {
        sessions.values.filter { !$0.deleted && (lang == nil || $0.settings.lang == lang) }
            .sorted { ($0.lastActivity, $0.id) > ($1.lastActivity, $1.id) }
    }
}

public enum Merger {
    /// `isSynced(event)` — записано ли событие в папку синхронизации (✓✓, R-38).
    public static func build(_ input: [Event], isSynced: (Event) -> Bool = { _ in false }) -> HistoryState {
        // 1. Объединение по id. Если id совпал, а содержимое разное (не должно случаться), выбор детерминирован.
        var byID: [String: Event] = [:]
        for e in input {
            if let cur = byID[e.id] {
                if (e.lamport, e.device, e.seq) > (cur.lamport, cur.device, cur.seq) { byID[e.id] = e }
            } else {
                byID[e.id] = e
            }
        }
        // 2. Детерминированный порядок обхода: (ts, device, seq, id).
        let events = byID.values.sorted { a, b in
            (a.tsMillis, a.device, a.seq, a.id) < (b.tsMillis, b.device, b.seq, b.id)
        }

        var st = HistoryState()
        st.eventCount = events.count

        struct SessionAcc {
            var created: Event?
            var title = LWW("")
            var settings: LWW<SessionSettings>?
            var deleted = LWW(false)
            var ended = LWW(false)
            var summary = LWW(Payload.SummaryUpdated(text: ""))
            var lastActivity = Date.distantPast
        }
        struct MessageAcc {
            var event: Event
            var payload: Payload.MessageCreated
            var text: LWW<String>
            var interrupted = LWW<Int?>(nil)
        }
        var sessions: [String: SessionAcc] = [:]
        var messages: [String: MessageAcc] = [:]
        var edits: [String: [(Version, String)]] = [:]
        var interrupts: [String: [(Version, Int)]] = [:]
        var stars: [String: LWW<Bool>] = [:]
        var starPhrase: [String: Phrase] = [:]
        var hintKeys: [String: Set<String>] = [:]

        for e in events {
            st.maxLamport = max(st.maxLamport, e.lamport)
            st.lastSeq[e.device] = max(st.lastSeq[e.device] ?? 0, e.seq)
            let ver = Version(e)
            if !e.session.isEmpty, EventType.all.contains(e.type) {
                sessions[e.session, default: SessionAcc()].lastActivity = max(sessions[e.session]?.lastActivity ?? .distantPast, e.ts)
            }
            switch e.type {
            case EventType.sessionCreated:
                guard let p = try? e.payload.decode(Payload.SessionCreated.self) else { st.unknownEvents += 1; continue }
                var acc = sessions[e.session] ?? SessionAcc()
                if acc.created == nil || ver < Version(acc.created!) { acc.created = e }
                acc.title.apply(p.title, ver)
                if acc.settings == nil { acc.settings = LWW(p.settings) }
                acc.settings!.apply(p.settings, ver)
                sessions[e.session] = acc
            case EventType.sessionUpdated:
                guard let p = try? e.payload.decode(Payload.SessionUpdated.self) else { st.unknownEvents += 1; continue }
                var acc = sessions[e.session] ?? SessionAcc()
                if let t = p.title { acc.title.apply(t, ver) }
                if let s = p.settings {
                    if acc.settings == nil { acc.settings = LWW(s) }
                    acc.settings!.apply(s, ver)
                }
                sessions[e.session] = acc
            case EventType.sessionDeleted:
                sessions[e.session, default: SessionAcc()].deleted.apply(true, ver)
            case EventType.sessionEnded:
                sessions[e.session, default: SessionAcc()].ended.apply(true, ver)
            case EventType.sessionResumed:
                sessions[e.session, default: SessionAcc()].ended.apply(false, ver)
            case EventType.summaryUpdated:
                guard let p = try? e.payload.decode(Payload.SummaryUpdated.self) else { st.unknownEvents += 1; continue }
                sessions[e.session, default: SessionAcc()].summary.apply(p, ver)
            case EventType.messageCreated:
                guard let p = try? e.payload.decode(Payload.MessageCreated.self) else { st.unknownEvents += 1; continue }
                messages[e.id] = MessageAcc(event: e, payload: p, text: LWW(p.text))
            case EventType.messageEdited:
                guard let p = try? e.payload.decode(Payload.MessageEdited.self) else { st.unknownEvents += 1; continue }
                edits[p.message, default: []].append((ver, p.text))
            case EventType.messageInterrupted:
                guard let p = try? e.payload.decode(Payload.MessageInterrupted.self) else { st.unknownEvents += 1; continue }
                interrupts[p.message, default: []].append((ver, p.at))
            case EventType.fixRecorded:
                guard let p = try? e.payload.decode(Payload.FixRecorded.self) else { st.unknownEvents += 1; continue }
                st.fixes[e.session, default: []].append(FixEntry(message: p.message, fix: p.fix, ts: e.ts))
            case EventType.hintAdded:
                guard let p = try? e.payload.decode(Payload.HintAdded.self) else { st.unknownEvents += 1; continue }
                if hintKeys[e.session, default: []].insert(p.phrase.id).inserted {
                    st.hints[e.session, default: []].append(p.phrase)
                }
            case EventType.phraseStarred, EventType.phraseUnstarred:
                guard let p = try? e.payload.decode(Payload.PhraseMark.self) else { st.unknownEvents += 1; continue }
                let key = p.phrase.id
                var reg = stars[key] ?? LWW(false)
                reg.apply(e.type == EventType.phraseStarred, ver)
                stars[key] = reg
                if reg.version == ver { starPhrase[key] = p.phrase }
            default:
                st.unknownEvents += 1
            }
        }

        for (id, list) in edits { for (v, t) in list { messages[id]?.text.apply(t, v) } }
        for (id, list) in interrupts { for (v, at) in list { messages[id]?.interrupted.apply(at, v) } }

        for (id, acc) in sessions {
            guard let created = acc.created, let settings = acc.settings?.value else { continue }
            st.sessions[id] = Session(id: id, title: acc.title.value, settings: settings, createdAt: created.ts,
                                      lastActivity: acc.lastActivity, state: acc.ended.value ? .ended : .active,
                                      deleted: acc.deleted.value, summary: acc.summary.value.text,
                                      summaryThrough: acc.summary.value.through)
        }
        let ordered = messages.values.sorted { a, b in
            (a.event.tsMillis, a.event.device, a.event.seq, a.event.id) < (b.event.tsMillis, b.event.device, b.event.seq, b.event.id)
        }
        for m in ordered {
            let p = m.payload
            st.messages[m.event.session, default: []].append(
                ChatMessage(id: m.event.id, session: m.event.session, role: p.role, text: m.text.value, lang: p.lang,
                            segments: p.segments ?? [], createdAt: m.event.ts, source: p.source,
                            interruptedAt: m.interrupted.value, synced: isSynced(m.event), kind: p.kind ?? .normal))
        }
        // «Понято как» (R-51): `@heard` ответа показывается под репликой пользователя, на которую он ответ.
        for (sid, list) in st.messages {
            var out = list
            for (i, m) in list.enumerated() where m.role == .assistant {
                guard let h = m.segments.lazy.compactMap({ seg -> String? in if case .heard(let t) = seg { return t }; return nil }).first else { continue }
                let target = messages[m.id]?.payload.replyTo.flatMap { r in out.firstIndex { $0.id == r } }
                    ?? out[..<i].lastIndex { $0.role == .user }
                if let t = target, out[t].role == .user { out[t].heard = h }
            }
            st.messages[sid] = out
        }
        for (key, reg) in stars where reg.value { st.starred[key] = starPhrase[key] }
        return st
    }
}
