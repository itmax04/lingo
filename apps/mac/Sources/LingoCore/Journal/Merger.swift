import Foundation

/// Value version for last-writer-wins (R-37): the larger `lamport`, on a tie — the larger `device`.
public struct Version: Comparable, Sendable, Hashable {
    public var lamport: Int
    public var device: String
    public var id: String

    public init(_ e: Event) { lamport = e.lamport; device = e.device; id = e.id }

    public static func < (a: Version, b: Version) -> Bool {
        (a.lamport, a.device, a.id) < (b.lamport, b.device, b.id)
    }
}

/// LWW register: a value with a version. Applying it does not depend on the order in which events arrive.
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

/// A `@fix` record linked to a message (R-20, R-23).
public struct FixEntry: Sendable, Hashable {
    public var message: String
    public var fix: Fix
    public var ts: Date
}

/// History state built from a set of events (R-37). A pure function of the set:
/// the result does not depend on event order or duplicates (merging is commutative and idempotent).
public struct HistoryState: Sendable {
    public var sessions: [String: Session] = [:]
    /// Session messages in (`ts`, `device`, `seq`) order.
    public var messages: [String: [ChatMessage]] = [:]
    public var fixes: [String: [FixEntry]] = [:]
    /// Session hints (`hint.added`), deduplicated by phrase key.
    public var hints: [String: [Phrase]] = [:]
    /// Vocabulary ★ (R-28): phrase key → phrase.
    public var starred: [String: Phrase] = [:]
    /// My vocabulary (VR-01…VR-05): the learner's own items with statistics; ★ phrases are added by `vocabulary(lang:)`.
    public var vocab: [String: VocabItem] = [:]
    /// Statistics of ★ phrases used as items, by `VocabItem.starredID`.
    public var starredStats: [String: VocabItem] = [:]
    /// Items the learner used correctly in each session (VR-06: they make room for the next ones).
    public var vocabUsedInSession: [String: Set<String>] = [:]
    public var profile = LearnerProfile()
    public var eventCount = 0
    public var maxLamport = 0
    /// The last `seq` of each device — for this device it is where numbering continues.
    public var lastSeq: [String: Int] = [:]
    /// Events of unknown types (kept in the journal, ignored when building state).
    public var unknownEvents = 0

    public init() {}

    /// All practice items of a language (or all): the learner's own items and the ★ phrases (A-02).
    public func vocabulary(lang: Lang? = nil) -> [VocabItem] {
        var out = vocab.values.filter { lang == nil || $0.lang == lang }
        for (key, p) in starred where lang == nil || p.lang == lang {
            let id = VocabItem.starredID(key)
            var item = starredStats[id] ?? VocabItem(id: id, lang: p.lang, text: p.text, createdAt: .distantPast)
            item.lang = p.lang; item.text = p.text; item.translation = p.translation; item.source = .starred
            // A ★ phrase that is also a manual item is shown once (the manual one).
            if !out.contains(where: { VocabularyText.key(lang: $0.lang, text: $0.text) == VocabularyText.key(lang: p.lang, text: p.text) }) {
                out.append(item)
            }
        }
        return out
    }

    /// Visible sessions by last activity (R-05).
    public func visibleSessions(lang: Lang? = nil) -> [Session] {
        sessions.values.filter { !$0.deleted && (lang == nil || $0.settings.lang == lang) }
            .sorted { ($0.lastActivity, $0.id) > ($1.lastActivity, $1.id) }
    }
}

public enum Merger {
    /// `isSynced(event)` — whether the event has been written to the sync folder (✓✓, R-38).
    public static func build(_ input: [Event], isSynced: (Event) -> Bool = { _ in false }) -> HistoryState {
        // 1. Union by id. If the id matches but the content differs (should not happen), the choice is deterministic.
        var byID: [String: Event] = [:]
        for e in input {
            if let cur = byID[e.id] {
                if (e.lamport, e.device, e.seq) > (cur.lamport, cur.device, cur.seq) { byID[e.id] = e }
            } else {
                byID[e.id] = e
            }
        }
        // 2. Deterministic traversal order: (ts, device, seq, id).
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
        struct VocabAcc {
            var event: Event
            var draft: Payload.VocabDraft
            var text: LWW<String>
            var translation: LWW<String>
            var note: LWW<String>
            var example: LWW<String>
            var removed = LWW(false)
        }
        var vocab: [String: VocabAcc] = [:]
        var vocabUpdates: [(Version, Payload.VocabUpdated)] = []
        var vocabRemovals: [(Version, String)] = []
        var vocabUses: [(Event, Payload.VocabUsed)] = []
        var starTime: [String: Date] = [:]
        var goals = LWW(""), interests = LWW("")

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
                if reg.version == ver { starPhrase[key] = p.phrase; if e.type == EventType.phraseStarred { starTime[key] = e.ts } }
            case EventType.vocabAdded:
                guard let p = try? e.payload.decode(Payload.VocabAdded.self) else { st.unknownEvents += 1; continue }
                let d = p.item
                vocab[e.id] = VocabAcc(event: e, draft: d, text: LWW(d.text), translation: LWW(d.translation ?? ""),
                                       note: LWW(d.note ?? ""), example: LWW(d.example ?? ""))
            case EventType.vocabUpdated:
                guard let p = try? e.payload.decode(Payload.VocabUpdated.self) else { st.unknownEvents += 1; continue }
                vocabUpdates.append((ver, p))
            case EventType.vocabRemoved:
                guard let p = try? e.payload.decode(Payload.VocabRemoved.self) else { st.unknownEvents += 1; continue }
                vocabRemovals.append((ver, p.item))
            case EventType.vocabUsed:
                guard let p = try? e.payload.decode(Payload.VocabUsed.self) else { st.unknownEvents += 1; continue }
                vocabUses.append((e, p))
            case EventType.profileUpdated:
                guard let p = try? e.payload.decode(Payload.ProfileUpdated.self) else { st.unknownEvents += 1; continue }
                if let g = p.goals { goals.apply(g, ver) }
                if let i = p.interests { interests.apply(i, ver) }
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
        // "Understood as" (R-51): the reply's `@heard` is shown under the user utterance it answers.
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

        // My vocabulary: field updates and removals are applied by version (order of arrival does not matter).
        for (v, u) in vocabUpdates {
            if let t = u.text { vocab[u.item]?.text.apply(t, v) }
            if let t = u.translation { vocab[u.item]?.translation.apply(t, v) }
            if let t = u.note { vocab[u.item]?.note.apply(t, v) }
            if let t = u.example { vocab[u.item]?.example.apply(t, v) }
        }
        for (v, id) in vocabRemovals { vocab[id]?.removed.apply(true, v) }
        for (id, acc) in vocab where !acc.removed.value {
            st.vocab[id] = VocabItem(id: id, lang: acc.draft.lang, text: acc.text.value, translation: acc.translation.value,
                                     note: acc.note.value, example: acc.example.value, source: acc.draft.source, createdAt: acc.event.ts)
        }
        for (key, p) in st.starred {
            let id = VocabItem.starredID(key)
            st.starredStats[id] = VocabItem(id: id, lang: p.lang, text: p.text, translation: p.translation, source: .starred,
                                            createdAt: starTime[key] ?? .distantPast)
        }
        for (e, u) in vocabUses {
            func bump(_ item: inout VocabItem) {
                switch (u.by, u.outcome) {
                case (.assistant, _): item.offered += 1
                case (.learner, .ok): item.used += 1
                case (.learner, .mistake): item.mistakes += 1
                }
                item.lastPractised = max(item.lastPractised ?? .distantPast, e.ts)
            }
            if st.vocab[u.item] != nil { bump(&st.vocab[u.item]!) } else if st.starredStats[u.item] != nil { bump(&st.starredStats[u.item]!) }
            if u.by == .learner, u.outcome == .ok, !e.session.isEmpty { st.vocabUsedInSession[e.session, default: []].insert(u.item) }
        }
        st.profile = LearnerProfile(goals: goals.value, interests: interests.value)
        return st
    }
}
