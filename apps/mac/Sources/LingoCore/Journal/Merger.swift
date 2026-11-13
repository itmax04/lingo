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
    /// ★ phrases as items (VR-01a), by `VocabItem.starredID`, with statistics.
    public var starredStats: [String: VocabItem] = [:]
    /// Items the learner used correctly in each session (VR-06: they make room for the next ones).
    public var vocabUsedInSession: [String: Set<String>] = [:]
    /// De-duplicated `vocab.used` events (canonical item ids), for statistics "before a session" (VR-06).
    public var vocabUses: [VocabUse] = []
    /// Keys of the add-time texts of live items (duplicates included): an edited item still owns its original text (VR-02, VR-03).
    public var vocabAddKeys: Set<String> = []
    public var profile = LearnerProfile()
    /// All `profile.updated` events with their versions, for the profile as it was before a session (PR-01).
    public var profileUpdates: [ProfileUpdate] = []
    /// Counted card reviews (LINGO-05 CR-02) by card id in traversal order: only the first per (session, card). Reviews of unknown
    /// cards are kept here and ignored by the queue.
    public var cardReviews: [String: [CardReview]] = [:]
        /// Suspended cards (CR-02, last writer wins).
    public var suspendedCards: Set<String> = []
    /// The earliest `phrase.starred` per vocabulary key (`VocabularyText.key`), so a word card keeps its first date (CR-01).
    public var firstStarred: [String: Date] = [:]
    /// All `goal.set` events (GR-02); the goal of a day is resolved from them.
    public var goalSets: [GoalSet] = []
    /// Completed scenario tasks per session, each once, in traversal order (SR-03).
    public var scenarioTasks: [String: [Int]] = [:]
    public var examParts: [String: [ExamPhase]] = [:]
    /// LINGO-10 BR-26: the last `exam.part` before each message in event order, by message id (absent before the first part).
    public var examMessageParts: [String: ExamPhase] = [:]
    /// The stored weekly report per ISO week "YYYY-Www" (GR-05), last writer by (lamport, device).
    public var weeklyReports: [String: WeeklyReport] = [:]
    /// Live memory facts in event order (GR-06), their duplicate keys, the keys of deleted facts and the switch (on by default).
    public var memoryFacts: [MemoryFact] = []
    public var removedFactKeys: Set<String> = []
    public var memoryOn = true
    public var eventCount = 0
    public var maxLamport = 0
    /// The last `seq` of each device — for this device it is where numbering continues.
    public var lastSeq: [String: Int] = [:]
    /// Events of unknown types (kept in the journal, ignored when building state).
    public var unknownEvents = 0

    public init() {}

    /// All practice items of a language (or all): own items and ★ phrases (VR-01a); an own item hides a ★ phrase with the same key.
    public func vocabulary(lang: Lang? = nil) -> [VocabItem] {
        var out = vocab.values.filter { lang == nil || $0.lang == lang }
        let own = Set(out.map { VocabularyText.key(lang: $0.lang, text: $0.text) })
        for item in starredStats.values where (lang == nil || item.lang == lang) && !own.contains(VocabularyText.key(lang: item.lang, text: item.text)) {
            out.append(item)
        }
        return out.sorted { Array($0.id.utf8).lexicographicallyPrecedes(Array($1.id.utf8)) }
    }

    /// The session's targets (VR-06): 3, or 6 with the vocabulary focus; none when the vocabulary is off for the session.
    public func vocabTargets(session: String) -> [VocabItem] {
        guard let s = sessions[session], s.settings.vocabularyOn else { return [] }
        return VocabularySelection.select(vocabulary(lang: s.settings.lang, before: session), lang: s.settings.lang,
                                          usedInSession: vocabUsedInSession[session] ?? [],
                                          count: s.settings.isVocabularyFocus ? VocabularySelection.wordsModeCount : VocabularySelection.ordinaryCount,
                                          pinned: s.settings.pinnedVocab)
    }

    /// Items with the statistics as they were before `session` (its own uses are left out), so the targets stay stable within it (VR-06).
    public func vocabulary(lang: Lang, before session: String) -> [VocabItem] {
        var base = Dictionary(uniqueKeysWithValues: vocabulary(lang: lang).map { item -> (String, VocabItem) in
            var x = item
            x.offered = 0; x.used = 0; x.mistakes = 0; x.lastPractised = nil
            return (item.id, x)
        })
        for u in vocabUses where u.session != session { base[u.item]?.count(u) }
        return base.values.sorted { Array($0.id.utf8).lexicographicallyPrecedes(Array($1.id.utf8)) }
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
            var resumedAt: Date?
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
        }
        var vocab: [String: VocabAcc] = [:]
        var vocabUpdates: [(Version, Payload.VocabUpdated)] = []
        var vocabRemovals: [(Version, String)] = []
        var vocabUseEvents: [(Event, Payload.VocabUsed)] = []
        var starTime: [String: Date] = [:]
        var goals = LWW(""), interests = LWW("")
        var memNoted: [String: (event: Event, lang: Lang?, text: String)] = [:]
        var memUpdates: [(Version, Payload.MemoryUpdated)] = []
        var memRemoved: Set<String> = []
        var memSwitch = LWW(true)
        var reviewed: Set<String> = [], suspended: [String: LWW<Bool>] = [:]
        var lastExamPart: [String: ExamPhase] = [:]

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
                sessions[e.session]!.resumedAt = max(sessions[e.session]!.resumedAt ?? e.ts, e.ts)
            case EventType.summaryUpdated:
                guard let p = try? e.payload.decode(Payload.SummaryUpdated.self) else { st.unknownEvents += 1; continue }
                sessions[e.session, default: SessionAcc()].summary.apply(p, ver)
            case EventType.messageCreated:
                guard let p = try? e.payload.decode(Payload.MessageCreated.self) else { st.unknownEvents += 1; continue }
                messages[e.id] = MessageAcc(event: e, payload: p, text: LWW(p.text))
                if let part = lastExamPart[e.session] { st.examMessageParts[e.id] = part }
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
                if e.type == EventType.phraseStarred {
                    let vk = VocabularyText.key(lang: p.phrase.lang, text: p.phrase.text)
                    st.firstStarred[vk] = min(st.firstStarred[vk] ?? e.ts, e.ts)
                }
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
                vocabUseEvents.append((e, p))
            case EventType.cardReviewed:
                guard let p = try? e.payload.decode(Payload.CardReviewed.self) else { st.unknownEvents += 1; continue }
                guard reviewed.insert(e.session + "\u{0}" + p.card).inserted else { continue }
                st.cardReviews[p.card, default: []].append(CardReview(rating: p.rating, at: e.ts, session: e.session, message: p.message))
            case EventType.cardSuspended:
                guard let p = try? e.payload.decode(Payload.CardSuspended.self) else { st.unknownEvents += 1; continue }
                suspended[p.card, default: LWW(false)].apply(p.suspended, ver)
            case EventType.scenarioTask:
                guard let p = try? e.payload.decode(Payload.ScenarioTask.self), p.task >= 1 else { st.unknownEvents += 1; continue }
                if !(st.scenarioTasks[e.session] ?? []).contains(p.task) { st.scenarioTasks[e.session, default: []].append(p.task) }
            case EventType.examPart:
                guard let p = try? e.payload.decode(Payload.ExamPart.self) else { st.unknownEvents += 1; continue }
                st.examParts[e.session, default: []].append(p.part)
                lastExamPart[e.session] = p.part
            case EventType.reportWeekly:
                guard let p = try? e.payload.decode(Payload.ReportWeekly.self), HistoryState.isWeekID(p.week) else { st.unknownEvents += 1; continue }
                if let old = st.weeklyReports[p.week], old.version > ver { continue }
                st.weeklyReports[p.week] = WeeklyReport(week: p.week, text: p.text, ts: e.ts, version: ver)
            case EventType.memoryNoted:
                guard let p = try? e.payload.decode(Payload.MemoryNoted.self), let l = MemoryText.lang(wire: p.lang),
                      !p.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { st.unknownEvents += 1; continue }
                memNoted[e.id] = (e, l, MemoryText.clean(p.text))
            case EventType.memoryUpdated:
                guard let p = try? e.payload.decode(Payload.MemoryUpdated.self) else { st.unknownEvents += 1; continue }
                memUpdates.append((ver, p))
            case EventType.memoryRemoved:
                guard let p = try? e.payload.decode(Payload.MemoryRemoved.self) else { st.unknownEvents += 1; continue }
                memRemoved.insert(p.fact)
            case EventType.memorySwitched:
                guard let p = try? e.payload.decode(Payload.MemorySwitched.self) else { st.unknownEvents += 1; continue }
                memSwitch.apply(p.on, ver)
            case EventType.replyRevealed:
                // A record for statistics only; it changes no state. A malformed payload counts as unknown (MR-45).
                guard let p = try? e.payload.decode(Payload.ReplyRevealed.self), p.index >= 0 else { st.unknownEvents += 1; continue }
            case EventType.toneFiltered:
                // A record for statistics only; it changes no state. A malformed payload counts as unknown (MR-45).
                guard let p = try? e.payload.decode(Payload.ToneFiltered.self), p.removed >= 1 else { st.unknownEvents += 1; continue }
            case EventType.goalSet:
                guard let p = try? e.payload.decode(Payload.GoalSet.self) else { st.unknownEvents += 1; continue }
                st.goalSets.append(GoalSet(minutes: min(HistoryState.goalRange.upperBound, max(HistoryState.goalRange.lowerBound, p.minutes)), ts: e.ts, version: ver))
            case EventType.profileUpdated:
                guard let p = try? e.payload.decode(Payload.ProfileUpdated.self) else { st.unknownEvents += 1; continue }
                if let g = p.goals { goals.apply(g, ver) }
                if let i = p.interests { interests.apply(i, ver) }
                st.profileUpdates.append(ProfileUpdate(ts: e.ts, version: ver, goals: p.goals, interests: p.interests))
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
                                      summaryThrough: acc.summary.value.through, resumedAt: acc.resumedAt)
        }
        let ordered = messages.values.sorted { a, b in
            (a.event.tsMillis, a.event.device, a.event.seq, a.event.id) < (b.event.tsMillis, b.event.device, b.event.seq, b.event.id)
        }
        for m in ordered {
            let p = m.payload
            st.messages[m.event.session, default: []].append(
                ChatMessage(id: m.event.id, session: m.event.session, role: p.role, text: m.text.value, lang: p.lang,
                            segments: p.segments ?? [], createdAt: m.event.ts, source: p.source,
                            interruptedAt: m.interrupted.value, synced: isSynced(m.event), kind: p.kind ?? .normal, local: p.local == true))
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

        // Memory facts (GR-06): text by last writer, a removal is final, event order, the earliest of equal keys is kept.
        var memText: [String: LWW<String>] = memNoted.mapValues { LWW($0.text) }
        for (v, u) in memUpdates {
            let t = MemoryText.clean(u.text)
            if !t.isEmpty { memText[u.fact]?.apply(t, v) }
        }
        var liveKeys: Set<String> = []
        for (id, n) in memNoted.sorted(by: { (a, b) in (a.value.event.tsMillis, a.value.event.device, a.value.event.seq, a.key) < (b.value.event.tsMillis, b.value.event.device, b.value.event.seq, b.key) }) {
            let text = memText[id]?.value ?? ""
            if text.isEmpty { continue }   // nothing left after cleaning (e.g. only data tags)
            let key = MemoryText.key(lang: n.lang, text: text)
            if memRemoved.contains(id) { st.removedFactKeys.insert(key); continue }
            guard liveKeys.insert(key).inserted else { continue }
            st.memoryFacts.append(MemoryFact(id: id, lang: n.lang, text: text, ts: n.event.ts, session: n.event.session, key: key))
        }
        st.memoryOn = memSwitch.value

        // My vocabulary (VR-02). A removal of any item with a given language and text removes every add of that text whose version is
        // below the removal's (removal is final for them); later adds start again. Of the live adds of one text (two devices), the
        // earliest is canonical. Removed adds map to themselves and are dropped, with their updates and uses.
        func addKey(_ acc: VocabAcc) -> String { VocabularyText.key(lang: acc.draft.lang, text: acc.draft.text) }
        var removedBelow: [String: Version] = [:]
        for (v, id) in vocabRemovals {
            guard let acc = vocab[id] else { continue }
            let k = addKey(acc)
            if let cur = removedBelow[k], cur >= v { continue }
            removedBelow[k] = v
        }
        var canonical: [String: String] = [:]
        var byKey: [String: String] = [:]
        var dead: Set<String> = []
        for (id, acc) in vocab.sorted(by: { (a, b) in (a.value.event.tsMillis, a.value.event.device, a.value.event.seq, a.key) < (b.value.event.tsMillis, b.value.event.device, b.value.event.seq, b.key) }) {
            let key = addKey(acc)
            if let r = removedBelow[key], Version(acc.event) < r { dead.insert(id); canonical[id] = id; continue }
            if let first = byKey[key] { canonical[id] = first } else { byKey[key] = id; canonical[id] = id }
            st.vocabAddKeys.insert(key)
        }
        // Field updates are applied by version (order of arrival does not matter).
        for (v, u) in vocabUpdates {
            guard let id = canonical[u.item] else { continue }
            if let t = u.text, !VocabularyText.normalize(t).isEmpty { vocab[id]?.text.apply(t, v) }
            if let t = u.translation { vocab[id]?.translation.apply(t, v) }
            if let t = u.note { vocab[id]?.note.apply(t, v) }
            if let t = u.example { vocab[id]?.example.apply(t, v) }
        }
        for (id, acc) in vocab where canonical[id] == id && !dead.contains(id) {
            st.vocab[id] = VocabItem(id: id, lang: acc.draft.lang, text: acc.text.value, translation: acc.translation.value,
                                     note: acc.note.value, example: acc.example.value, source: acc.draft.source, createdAt: acc.event.ts)
        }
        for p in st.starred.values.sorted(by: { $0.id < $1.id }) {
            let id = VocabItem.starredID(lang: p.lang, text: p.text)
            guard st.starredStats[id] == nil else { continue }  // two ★ phrases with the same key: the first by phrase key
            st.starredStats[id] = VocabItem(id: id, lang: p.lang, text: p.text, translation: p.translation, source: .starred,
                                            createdAt: starTime[p.id] ?? .distantPast)
        }
        // Uses: one per (item, by, message), `mistake` wins over `ok`; ids of duplicates count for the canonical item (VR-02).
        var uses: [String: VocabUse] = [:]
        var order: [String] = []
        for (e, u) in vocabUseEvents.sorted(by: { ($0.0.tsMillis, $0.0.device, $0.0.seq, $0.0.id) < ($1.0.tsMillis, $1.0.device, $1.0.seq, $1.0.id) }) {
            let id = canonical[u.item] ?? u.item
            guard st.vocab[id] != nil || st.starredStats[id] != nil else { continue }
            let k = "\(id)|\(u.by.rawValue)|\(u.message)"
            if let cur = uses[k] {
                if u.outcome == .mistake, cur.outcome == .ok { uses[k]!.outcome = .mistake }
                continue
            }
            uses[k] = VocabUse(item: id, session: e.session, by: u.by, outcome: u.outcome, at: e.ts)
            order.append(k)
        }
        for k in order {
            let use = uses[k]!
            st.vocabUses.append(use)
            if st.vocab[use.item] != nil { st.vocab[use.item]!.count(use) } else { st.starredStats[use.item]!.count(use) }
            if use.by == .learner, use.outcome == .ok, !use.session.isEmpty { st.vocabUsedInSession[use.session, default: []].insert(use.item) }
        }
        st.profile = LearnerProfile(goals: goals.value, interests: interests.value)
        st.suspendedCards = Set(suspended.filter(\.value.value).keys)
        return st
    }
}
