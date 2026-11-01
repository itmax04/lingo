import { EventType, KNOWN_EVENT_TYPES, type JournalEvent } from "./event.js";
import { Payload, type SummaryUpdated } from "./payloads.js";
import { countUse, selectTargets, starredID, ORDINARY_COUNT, WORDS_MODE_COUNT, type VocabItem, type VocabUse } from "../vocab/item.js";
import { normalizeVocab, vocabKey } from "../vocab/text.js";
import { compareCodePoints } from "../json.js";
import { phraseKey, type Fix, type Lang, type MessageKind, type Phrase, type ReplySegment, type Role, type SessionSettings } from "../model/types.js";

/** Value version for last-writer-wins (R-37): the larger `lamport`, then `device`, then `id` — as Swift `Version`. */
export interface Version { lamport: number; device: string; id: string }

export function compareVersions(a: Version, b: Version): number {
  return a.lamport - b.lamport || cmp(a.device, b.device) || cmp(a.id, b.id);
}

function cmp(a: string, b: string): number {
  return a < b ? -1 : a > b ? 1 : 0;
}

/** LWW register: applying versions in any order gives the same value. */
class LWW<T> {
  version: Version | undefined;
  constructor(public value: T) {}
  apply(v: T, ver: Version): void {
    if (this.version && compareVersions(ver, this.version) <= 0) return;
    this.value = v;
    this.version = ver;
  }
}

export interface Session {
  id: string; title: string; settings: SessionSettings; createdAt: number; lastActivity: number;
  state: "active" | "ended"; deleted: boolean; summary: string; summaryThrough?: string;
}
export interface ChatMessage {
  id: string; session: string; role: Role; text: string; lang: Lang; heard?: string; segments: ReplySegment[]; createdAt: number;
  source?: string; interruptedAt?: number; synced: boolean; kind: MessageKind;
}
export interface FixEntry { message: string; fix: Fix; ts: number }
export interface ProfileUpdate { ts: number; version: Version; goals?: string; interests?: string }

/** History state built from a set of events (R-37), as Swift `HistoryState`. */
export interface HistoryState {
  sessions: Map<string, Session>;
  /** Session messages in (`ts`, `device`, `seq`, `id`) order. */
  messages: Map<string, ChatMessage[]>;
  fixes: Map<string, FixEntry[]>;
  /** Session hints (`hint.added`), de-duplicated by phrase key. */
  hints: Map<string, Phrase[]>;
  /** Vocabulary ★ (R-28): phrase key → phrase. */
  starred: Map<string, Phrase>;
  /** My vocabulary (VR-01…VR-05): own items with statistics; ★ phrases are added by `vocabulary()`. */
  vocab: Map<string, VocabItem>;
  /** ★ phrases as items (VR-01a), by `starredID`, with statistics. */
  starredStats: Map<string, VocabItem>;
  /** Items the learner used correctly in each session (VR-06). */
  vocabUsedInSession: Map<string, Set<string>>;
  /** De-duplicated uses, canonical ids (statistics "before a session"). */
  vocabUses: VocabUse[];
  /** Add-time keys of live items: an edited item still owns its original text (VR-02, VR-03). */
  vocabAddKeys: Set<string>;
  profile: { goals: string; interests: string };
  profileUpdates: ProfileUpdate[];
  eventCount: number;
  maxLamport: number;
  /** The last `seq` of each device. */
  lastSeq: Map<string, number>;
  /** Events of unknown types or with undecodable payloads (kept in the journal, ignored here). */
  unknownEvents: number;
}

/** Swift `Date.distantPast` in milliseconds: the last activity of a session without dated events. */
const DISTANT_PAST = -62135596800000;

const version = (e: JournalEvent): Version => ({ lamport: e.lamport, device: e.device, id: e.id });
const traversal = (a: JournalEvent, b: JournalEvent): number => a.ts - b.ts || cmp(a.device, b.device) || a.seq - b.seq || cmp(a.id, b.id);

interface SessionAcc {
  created?: JournalEvent; title: LWW<string>; settings?: LWW<SessionSettings>; deleted: LWW<boolean>; ended: LWW<boolean>;
  summary: LWW<SummaryUpdated>; lastActivity: number;
}
interface MessageAcc { event: JournalEvent; replyTo?: string; base: Omit<ChatMessage, "text" | "interruptedAt" | "synced">; text: LWW<string>; interrupted: LWW<number | undefined> }

/**
 * `Merger.build` (R-37): a pure function of the event set — the result does not depend on event order or duplicates.
 * `isSynced(event)` — whether the event is written to the sync folder (✓✓, R-38).
 */
export function buildState(input: readonly JournalEvent[], isSynced: (e: JournalEvent) => boolean = () => false): HistoryState {
  // 1. Union by id; if an id repeats with different content (should not happen), the choice is deterministic.
  const byID = new Map<string, JournalEvent>();
  for (const e of input) {
    const cur = byID.get(e.id);
    if (!cur || (e.lamport - cur.lamport || cmp(e.device, cur.device) || e.seq - cur.seq) > 0) byID.set(e.id, e);
  }
  // 2. Deterministic traversal order.
  const events = [...byID.values()].sort(traversal);
  const st: HistoryState = {
    sessions: new Map(), messages: new Map(), fixes: new Map(), hints: new Map(), starred: new Map(),
    vocab: new Map(), starredStats: new Map(), vocabUsedInSession: new Map(), vocabUses: [], vocabAddKeys: new Set(),
    profile: { goals: "", interests: "" }, profileUpdates: [], eventCount: events.length, maxLamport: 0, lastSeq: new Map(), unknownEvents: 0,
  };
  const sessions = new Map<string, SessionAcc>();
  const session = (id: string): SessionAcc => {
    let acc = sessions.get(id);
    if (!acc) {
      acc = { title: new LWW(""), deleted: new LWW(false), ended: new LWW(false), summary: new LWW<SummaryUpdated>({ text: "" }), lastActivity: DISTANT_PAST };
      sessions.set(id, acc);
    }
    return acc;
  };
  const messages = new Map<string, MessageAcc>();
  const edits: [string, Version, string][] = [];
  const interrupts: [string, Version, number][] = [];
  const stars = new Map<string, LWW<boolean>>();
  const starPhrase = new Map<string, Phrase>();
  const hintKeys = new Map<string, Set<string>>();
  const goals = new LWW(""), interests = new LWW("");
  interface VocabAcc { event: JournalEvent; lang: Lang; draftText: string; source: VocabItem["source"]; text: LWW<string>; translation: LWW<string>; note: LWW<string>; example: LWW<string> }
  const vocab = new Map<string, VocabAcc>();
  const vocabUpdates: [Version, { item: string; text?: string | undefined; translation?: string | undefined; note?: string | undefined; example?: string | undefined }][] = [];
  const vocabRemovals: [Version, string][] = [];
  const vocabUseEvents: [JournalEvent, { item: string; message: string; by: "learner" | "assistant"; outcome: "ok" | "mistake" }][] = [];
  const starTime = new Map<string, number>();

  for (const e of events) {
    st.maxLamport = Math.max(st.maxLamport, e.lamport);
    st.lastSeq.set(e.device, Math.max(st.lastSeq.get(e.device) ?? 0, e.seq));
    const ver = version(e);
    if (e.session !== "" && KNOWN_EVENT_TYPES.has(e.type)) {
      const acc = session(e.session);
      acc.lastActivity = Math.max(acc.lastActivity, e.ts);
    }
    switch (e.type) {
      case EventType.sessionCreated: {
        const p = Payload.sessionCreated(e.payload);
        if (!p) { st.unknownEvents++; break; }
        const acc = session(e.session);
        if (!acc.created || compareVersions(ver, version(acc.created)) < 0) acc.created = e;
        acc.title.apply(p.title, ver);
        (acc.settings ??= new LWW(p.settings)).apply(p.settings, ver);
        break;
      }
      case EventType.sessionUpdated: {
        const p = Payload.sessionUpdated(e.payload);
        if (!p) { st.unknownEvents++; break; }
        const acc = session(e.session);
        if (p.title !== undefined) acc.title.apply(p.title, ver);
        if (p.settings) (acc.settings ??= new LWW(p.settings)).apply(p.settings, ver);
        break;
      }
      case EventType.sessionDeleted: session(e.session).deleted.apply(true, ver); break;
      case EventType.sessionEnded: session(e.session).ended.apply(true, ver); break;
      case EventType.sessionResumed: session(e.session).ended.apply(false, ver); break;
      case EventType.summaryUpdated: {
        const p = Payload.summaryUpdated(e.payload);
        if (!p) { st.unknownEvents++; break; }
        session(e.session).summary.apply(p, ver);
        break;
      }
      case EventType.messageCreated: {
        const p = Payload.messageCreated(e.payload);
        if (!p) { st.unknownEvents++; break; }
        const base: MessageAcc["base"] = { id: e.id, session: e.session, role: p.role, lang: p.lang, segments: p.segments ?? [],
          createdAt: e.ts, kind: p.kind ?? "normal" };
        if (p.source !== undefined) base.source = p.source;
        const m: MessageAcc = { event: e, base, text: new LWW(p.text), interrupted: new LWW<number | undefined>(undefined) };
        if (p.replyTo !== undefined) m.replyTo = p.replyTo;
        messages.set(e.id, m);
        break;
      }
      case EventType.messageEdited: {
        const p = Payload.messageEdited(e.payload);
        if (!p) { st.unknownEvents++; break; }
        edits.push([p.message, ver, p.text]);
        break;
      }
      case EventType.messageInterrupted: {
        const p = Payload.messageInterrupted(e.payload);
        if (!p) { st.unknownEvents++; break; }
        interrupts.push([p.message, ver, p.at]);
        break;
      }
      case EventType.fixRecorded: {
        const p = Payload.fixRecorded(e.payload);
        if (!p) { st.unknownEvents++; break; }
        push(st.fixes, e.session, { message: p.message, fix: p.fix, ts: e.ts });
        break;
      }
      case EventType.hintAdded: {
        const p = Payload.phraseEvent(e.payload);
        if (!p) { st.unknownEvents++; break; }
        const keys = hintKeys.get(e.session) ?? new Set<string>();
        hintKeys.set(e.session, keys);
        const key = phraseKey(p.phrase.lang, p.phrase.text);
        if (!keys.has(key)) { keys.add(key); push(st.hints, e.session, p.phrase); }
        break;
      }
      case EventType.phraseStarred:
      case EventType.phraseUnstarred: {
        const p = Payload.phraseEvent(e.payload);
        if (!p) { st.unknownEvents++; break; }
        const key = phraseKey(p.phrase.lang, p.phrase.text);
        const reg = stars.get(key) ?? new LWW(false);
        stars.set(key, reg);
        reg.apply(e.type === EventType.phraseStarred, ver);
        if (reg.version && compareVersions(reg.version, ver) === 0) {
          starPhrase.set(key, p.phrase);
          if (e.type === EventType.phraseStarred) starTime.set(key, e.ts);
        }
        break;
      }
      case EventType.profileUpdated: {
        const p = Payload.profileUpdated(e.payload);
        if (!p) { st.unknownEvents++; break; }
        if (p.goals !== undefined) goals.apply(p.goals, ver);
        if (p.interests !== undefined) interests.apply(p.interests, ver);
        const u: ProfileUpdate = { ts: e.ts, version: ver };
        if (p.goals !== undefined) u.goals = p.goals;
        if (p.interests !== undefined) u.interests = p.interests;
        st.profileUpdates.push(u);
        break;
      }
      case EventType.vocabAdded: {
        const p = Payload.vocabAdded(e.payload);
        if (!p) { st.unknownEvents++; break; }
        const d = p.item;
        vocab.set(e.id, { event: e, lang: d.lang, draftText: d.text, source: d.source, text: new LWW(d.text), translation: new LWW(d.translation ?? ""),
          note: new LWW(d.note ?? ""), example: new LWW(d.example ?? "") });
        break;
      }
      case EventType.vocabUpdated: {
        const p = Payload.vocabUpdated(e.payload);
        if (!p) { st.unknownEvents++; break; }
        vocabUpdates.push([ver, p]);
        break;
      }
      case EventType.vocabRemoved: {
        const p = Payload.vocabRemoved(e.payload);
        if (!p) { st.unknownEvents++; break; }
        vocabRemovals.push([ver, p.item]);
        break;
      }
      case EventType.vocabUsed: {
        const p = Payload.vocabUsed(e.payload);
        if (!p) { st.unknownEvents++; break; }
        vocabUseEvents.push([e, p]);
        break;
      }
      default: st.unknownEvents++;
    }
  }

  for (const [id, ver, text] of edits) messages.get(id)?.text.apply(text, ver);
  for (const [id, ver, at] of interrupts) messages.get(id)?.interrupted.apply(at, ver);

  for (const [id, acc] of sessions) {
    if (!acc.created || !acc.settings) continue;
    const s: Session = { id, title: acc.title.value, settings: acc.settings.value, createdAt: acc.created.ts, lastActivity: acc.lastActivity,
      state: acc.ended.value ? "ended" : "active", deleted: acc.deleted.value, summary: acc.summary.value.text };
    if (acc.summary.value.through !== undefined) s.summaryThrough = acc.summary.value.through;
    st.sessions.set(id, s);
  }
  for (const m of [...messages.values()].sort((a, b) => traversal(a.event, b.event))) {
    const msg: ChatMessage = { ...m.base, text: m.text.value, synced: isSynced(m.event) };
    if (m.interrupted.value !== undefined) msg.interruptedAt = m.interrupted.value;
    push(st.messages, m.event.session, msg);
  }
  // "Understood as" (R-51): a reply's `@heard` goes under the user utterance it answers.
  for (const list of st.messages.values()) {
    list.forEach((m, i) => {
      if (m.role !== "assistant") return;
      const heard = m.segments.find((s): s is { heard: { _0: string } } => "heard" in s);
      if (!heard) return;
      const replyTo = messages.get(m.id)?.replyTo;
      let t = replyTo === undefined ? -1 : list.findIndex((x) => x.id === replyTo);
      if (t < 0) t = list.slice(0, i).map((x) => x.role).lastIndexOf("user");
      const target = list[t];
      if (t >= 0 && target?.role === "user") target.heard = heard.heard._0;
    });
  }
  for (const [key, reg] of stars) { const p = starPhrase.get(key); if (reg.value && p) st.starred.set(key, p); }

  // My vocabulary (VR-02). A removal of an item removes every add of the same text (key) whose version is below it; later adds start
  // again. Of the live adds of one text, the earliest is canonical. Removed adds map to themselves and are dropped with their data.
  const addKey = (a: VocabAcc) => vocabKey(a.lang, a.draftText);
  const removedBelow = new Map<string, Version>();
  for (const [v, id] of vocabRemovals) {
    const acc = vocab.get(id);
    if (!acc) continue;
    const k = addKey(acc), cur = removedBelow.get(k);
    if (!cur || compareVersions(v, cur) > 0) removedBelow.set(k, v);
  }
  const canonical = new Map<string, string>(), byKey = new Map<string, string>(), dead = new Set<string>();
  for (const [id, acc] of [...vocab].sort(([ia, a], [ib, b]) => traversal(a.event, b.event) || cmp(ia, ib))) {
    const key = addKey(acc), r = removedBelow.get(key);
    if (r && compareVersions(version(acc.event), r) < 0) { dead.add(id); canonical.set(id, id); continue; }
    const first = byKey.get(key);
    if (first) canonical.set(id, first); else { byKey.set(key, id); canonical.set(id, id); }
    st.vocabAddKeys.add(key);
  }
  for (const [v, u] of vocabUpdates) {
    const acc = vocab.get(canonical.get(u.item) ?? "");
    if (!acc) continue;
    if (u.text !== undefined && normalizeVocab(u.text) !== "") acc.text.apply(u.text, v);
    if (u.translation !== undefined) acc.translation.apply(u.translation, v);
    if (u.note !== undefined) acc.note.apply(u.note, v);
    if (u.example !== undefined) acc.example.apply(u.example, v);
  }
  for (const [id, acc] of vocab) {
    if (canonical.get(id) !== id || dead.has(id)) continue;
    st.vocab.set(id, { id, lang: acc.lang, text: acc.text.value, translation: acc.translation.value, note: acc.note.value, example: acc.example.value,
      source: acc.source, createdAt: acc.event.ts, offered: 0, used: 0, mistakes: 0 });
  }
  for (const p of [...st.starred.values()].sort((a, b) => cmp(phraseKey(a.lang, a.text), phraseKey(b.lang, b.text)))) {
    const id = starredID(p.lang, p.text);
    if (st.starredStats.has(id)) continue;  // two ★ phrases with the same key: the first by phrase key
    st.starredStats.set(id, { id, lang: p.lang, text: p.text, translation: p.translation, note: "", example: "", source: "starred",
      createdAt: starTime.get(phraseKey(p.lang, p.text)) ?? DISTANT_PAST, offered: 0, used: 0, mistakes: 0 });
  }
  // Uses: one per (item, by, message), `mistake` wins over `ok`; ids of duplicates count for the canonical item.
  const uses = new Map<string, VocabUse>();
  const order: string[] = [];
  for (const [e, u] of [...vocabUseEvents].sort(([a], [b]) => traversal(a, b))) {
    const id = canonical.get(u.item) ?? u.item;
    if (!st.vocab.has(id) && !st.starredStats.has(id)) continue;
    const k = `${id}|${u.by}|${u.message}`;
    const cur = uses.get(k);
    if (cur) { if (u.outcome === "mistake" && cur.outcome === "ok") cur.outcome = "mistake"; continue; }
    uses.set(k, { item: id, session: e.session, by: u.by, outcome: u.outcome, at: e.ts });
    order.push(k);
  }
  for (const k of order) {
    const use = uses.get(k) as VocabUse;
    st.vocabUses.push(use);
    countUse((st.vocab.get(use.item) ?? st.starredStats.get(use.item)) as VocabItem, use);
    if (use.by === "learner" && use.outcome === "ok" && use.session !== "") {
      const set = st.vocabUsedInSession.get(use.session) ?? new Set<string>();
      set.add(use.item);
      st.vocabUsedInSession.set(use.session, set);
    }
  }
  st.profile = { goals: goals.value, interests: interests.value };
  return st;
}

function push<T>(m: Map<string, T[]>, k: string, v: T): void {
  const list = m.get(k);
  if (list) list.push(v); else m.set(k, [v]);
}

/** Visible sessions by last activity, newest first (R-05). */
export function visibleSessions(st: HistoryState, lang?: Lang): Session[] {
  return [...st.sessions.values()].filter((s) => !s.deleted && (lang === undefined || s.settings.lang === lang))
    .sort((a, b) => b.lastActivity - a.lastActivity || cmp(b.id, a.id));
}

/** All practice items of a language (or all): own items and ★ phrases; an own item hides a ★ phrase with the same key (VR-01a). */
export function vocabulary(st: HistoryState, lang?: Lang): VocabItem[] {
  const out = [...st.vocab.values()].filter((i) => lang === undefined || i.lang === lang);
  const own = new Set(out.map((i) => vocabKey(i.lang, i.text)));
  for (const i of st.starredStats.values()) if ((lang === undefined || i.lang === lang) && !own.has(vocabKey(i.lang, i.text))) out.push(i);
  return out.sort((a, b) => compareCodePoints(a.id, b.id));
}

/** Items with the statistics as they were before `session` (its own uses left out), so the targets stay stable within it (VR-06). */
export function vocabularyBefore(st: HistoryState, lang: Lang, session: string): VocabItem[] {
  const base = new Map(vocabulary(st, lang).map((i) => {
    const x: VocabItem = { ...i, offered: 0, used: 0, mistakes: 0 };
    delete x.lastPractised;
    return [i.id, x] as const;
  }));
  for (const u of st.vocabUses) if (u.session !== session) { const x = base.get(u.item); if (x) countUse(x, u); }
  return [...base.values()].sort((a, b) => compareCodePoints(a.id, b.id));
}

/** The session's targets (VR-06): 3, or 6 with the vocabulary focus; none when the vocabulary is off for the session. */
export function vocabTargets(st: HistoryState, session: string): VocabItem[] {
  const s = st.sessions.get(session);
  if (!s) return [];
  const focus = s.settings.vocabularyFocus === true && s.settings.mode === "questions";
  if (!focus && s.settings.useVocabulary === false) return [];
  return selectTargets(vocabularyBefore(st, s.settings.lang, session), s.settings.lang, st.vocabUsedInSession.get(session) ?? new Set(),
    focus ? WORDS_MODE_COUNT : ORDINARY_COUNT, s.settings.pinnedVocab);
}
