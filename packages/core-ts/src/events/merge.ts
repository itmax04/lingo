import { EventType, KNOWN_EVENT_TYPES, type JournalEvent } from "./event.js";
import { Payload, type SummaryUpdated } from "./payloads.js";
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

/** History state built from a set of events (R-37), as Swift `HistoryState` without the vocabulary (P-07c2). */
export interface HistoryState {
  sessions: Map<string, Session>;
  /** Session messages in (`ts`, `device`, `seq`, `id`) order. */
  messages: Map<string, ChatMessage[]>;
  fixes: Map<string, FixEntry[]>;
  /** Session hints (`hint.added`), de-duplicated by phrase key. */
  hints: Map<string, Phrase[]>;
  /** Vocabulary ★ (R-28): phrase key → phrase. */
  starred: Map<string, Phrase>;
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
        if (reg.version && compareVersions(reg.version, ver) === 0) starPhrase.set(key, p.phrase);
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
      // The vocabulary state comes in P-07c2; the payloads are checked so that the unknown-event count matches Swift.
      case EventType.vocabAdded: if (!Payload.vocabAdded(e.payload)) st.unknownEvents++; break;
      case EventType.vocabUpdated: if (!Payload.vocabUpdated(e.payload)) st.unknownEvents++; break;
      case EventType.vocabRemoved: if (!Payload.vocabRemoved(e.payload)) st.unknownEvents++; break;
      case EventType.vocabUsed: if (!Payload.vocabUsed(e.payload)) st.unknownEvents++; break;
      case EventType.cardReviewed: if (!Payload.cardReviewed(e.payload)) st.unknownEvents++; break;
      case EventType.cardSuspended: if (!Payload.cardSuspended(e.payload)) st.unknownEvents++; break;
      case EventType.goalSet: if (!Payload.goalSet(e.payload)) st.unknownEvents++; break;
      case EventType.scenarioTask: if (!Payload.scenarioTask(e.payload)) st.unknownEvents++; break;
      case EventType.reportWeekly: if (!Payload.reportWeekly(e.payload)) st.unknownEvents++; break;
      case EventType.examPart: if (!Payload.examPart(e.payload)) st.unknownEvents++; break;
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
