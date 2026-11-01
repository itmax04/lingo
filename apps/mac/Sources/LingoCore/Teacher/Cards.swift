import Foundation

public enum CardKind: String, Codable, Sendable, Hashable { case word, mistake }
/// Where a review happened; only the warm-up in LINGO-05 (CR-02).
public enum CardReviewSource: String, Codable, Sendable, Hashable { case warmup }

/// One counted review (CR-02): the first of its card in its session.
public struct CardReview: Sendable, Hashable {
    public var rating: CardRating
    public var at: Date
    public var session: String
    /// The graded learner message; "" for a skipped card.
    public var message: String
}

/// A review card (LINGO-05 CR-01): derived from the vocabulary and the recurring mistakes, never stored.
public struct Card: Sendable, Hashable, Identifiable {
    public var id: String
    public var lang: Lang
    public var kind: CardKind
    /// What the learner should produce: the item text, or the corrected text of a mistake.
    public var front: String
    /// The Russian meaning of a word, or the rule of a mistake.
    public var hint: String
    public var createdAt: Date
}

public extension HistoryState {
    static let mistakeKeyLimit = 60
    static let mistakeFrontLimit = 80
    static let mistakeHintLimit = 120
    static let newCardsPerDay = 5

    /// Word cards (one per vocabulary key) and mistake cards (one per recurring mistake group) of a language, by id bytes (CR-01).
    func cards(lang: Lang) -> [Card] {
        (wordCards(lang: lang) + mistakeCards(lang: lang)).sorted { Self.idOrder($0.id, $1.id) }
    }

    /// One card per key of the shown vocabulary, so ★ → own item and same-text duplicates keep one id and one history (CR-01).
    func wordCards(lang: Lang) -> [Card] {
        var byKey: [String: [VocabItem]] = [:]
        for item in vocabulary(lang: lang) { byKey[VocabularyText.key(lang: lang, text: item.text), default: []].append(item) }
        // The ★ phrase hidden by an own item still dates the card.
        let starred = starredStats.values.filter { $0.lang == lang }
        return byKey.map { key, items in
            let shown = items.min { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }!
            let dates = items.map(\.createdAt) + starred.filter { VocabularyText.key(lang: lang, text: $0.text) == key }.map(\.createdAt)
            return Card(id: "word:" + key, lang: lang, kind: .word, front: shown.text, hint: shown.translation, createdAt: dates.min()!)
        }
    }

        /// Recurring mistakes (CR-01, best effort): fixes of live sessions of the language, in (ts, session, message, rule, original) order,
    /// grouped by the normalised rule cut to 60 Characters (an empty rule is not grouped); the same (session, normalised original) counts
    /// once; at least two counted fixes make a card.
    func mistakeCards(lang: Lang) -> [Card] {
        var picked: [(sid: String, f: FixEntry)] = []
        for (sid, list) in fixes {
            guard let s = sessions[sid], !s.deleted, s.settings.lang == lang else { continue }
            for f in list { picked.append((sid, f)) }
        }
        picked.sort { ($0.f.ts, $0.sid, $0.f.message, $0.f.fix.rule, $0.f.fix.original) < ($1.f.ts, $1.sid, $1.f.message, $1.f.fix.rule, $1.f.fix.original) }
        var groups: [String: (rule: String, fronts: [String], times: [Date], seen: Set<String>)] = [:]
        for (sid, f) in picked {
            let key = String(VocabularyText.normalize(f.fix.rule).prefix(Self.mistakeKeyLimit))
            guard !key.isEmpty else { continue }
            var g = groups[key] ?? (f.fix.rule, [], [], [])
            guard g.seen.insert(sid + "\u{0}" + VocabularyText.normalize(f.fix.original)).inserted else { continue }
            g.rule = f.fix.rule
            g.fronts.append(f.fix.corrected)
            g.times.append(f.ts)
            groups[key] = g
        }
        return groups.compactMap { key, g -> Card? in
            guard g.times.count >= 2 else { return nil }
            // The shortest corrected text (then byte order), so the card's front does not depend on dictionary order.
            let shortest = g.fronts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .min { a, b in a.count != b.count ? a.count < b.count : Self.idOrder(a, b) } ?? ""
            return Card(id: "mistake:\(lang.rawValue):\(key)", lang: lang, kind: .mistake, front: String(shortest.prefix(Self.mistakeFrontLimit)),
                        hint: String(g.rule.prefix(Self.mistakeHintLimit)), createdAt: g.times[1])
        }
    }

    /// The schedule of a card from its counted reviews (CR-03); nil = never reviewed.
    func cardState(_ id: String) -> CardState? {
        FSRS.schedule((cardReviews[id] ?? []).map { ($0.rating, $0.at) })
    }

        /// Cards to practise now (CR-04): due cards (last reviewed before today, due on or before today's local day) by retrievability
    /// ascending, mistakes first,
    /// oldest first, id; then new cards by (createdAt, id) up to 5 per language per local day, minus cards first reviewed today.
    /// Suspended cards are left out.
    func dueCards(lang: Lang, now: Date, calendar: Calendar = .autoupdatingCurrent) -> [Card] {
        let today = calendar.startOfDay(for: now)
        var due: [(card: Card, r: Double)] = []
        var fresh: [Card] = []
        var newToday = 0
        for c in cards(lang: lang) where !suspendedCards.contains(c.id) {
            guard let st = cardState(c.id) else { fresh.append(c); continue }
            if let first = cardReviews[c.id]?.first, calendar.startOfDay(for: first.at) == today { newToday += 1 }
                        guard calendar.startOfDay(for: st.lastReview) < today, calendar.startOfDay(for: st.due) <= today else { continue }
            due.append((c, FSRS.retrievability(days: FSRS.elapsedDays(from: st.lastReview, to: now), stability: st.stability)))
        }
        due.sort { a, b in
            if a.r != b.r { return a.r < b.r }
            if a.card.kind != b.card.kind { return a.card.kind == .mistake }
            if a.card.createdAt != b.card.createdAt { return a.card.createdAt < b.card.createdAt }
            return Self.idOrder(a.card.id, b.card.id)
        }
        fresh.sort { a, b in a.createdAt != b.createdAt ? a.createdAt < b.createdAt : Self.idOrder(a.id, b.id) }
        return due.map(\.card) + fresh.prefix(max(0, Self.newCardsPerDay - newToday))
    }

    static func idOrder(_ a: String, _ b: String) -> Bool { Array(a.utf8).lexicographicallyPrecedes(Array(b.utf8)) }
}
