import { describe, expect, it } from "vitest";
import {
  buildState, canonicalJSON, CORRECTION_MODES, eventLine, formatTS, parseEventLine, readJournal, visibleSessions,
  type HistoryState, type JournalEvent, type JSONValue,
} from "../src/index.js";
import { readContract, readJSON } from "./contracts.js";

/** The same neutral projection as the Swift `MergerContractTests` golden. */
function projection(st: HistoryState): JSONValue {
  const obj = <T>(m: Map<string, T>, f: (v: T) => unknown): unknown => Object.fromEntries([...m].map(([k, v]) => [k, f(v)]));
  return JSON.parse(JSON.stringify({
    sessions: [...st.sessions.values()].sort((a, b) => (a.id < b.id ? -1 : 1)).map((s) => ({
      id: s.id, title: s.title, createdAt: formatTS(s.createdAt), lastActivity: formatTS(s.lastActivity), state: s.state,
      deleted: s.deleted, summary: s.summary, summaryThrough: s.summaryThrough ?? null,
      settings: { ...s.settings, corrections: CORRECTION_MODES.filter((c) => s.settings.corrections.includes(c)) },
    })),
    visibleSessions: visibleSessions(st).map((s) => s.id),
    messages: obj(st.messages, (list) => list.map((m) => ({
      id: m.id, role: m.role, text: m.text, lang: m.lang, heard: m.heard ?? null, segments: m.segments, createdAt: formatTS(m.createdAt),
      source: m.source ?? null, interruptedAt: m.interruptedAt ?? null, kind: m.kind,
    }))),
    fixes: obj(st.fixes, (list) => list.map((f) => ({ message: f.message, fix: f.fix, ts: formatTS(f.ts) }))),
    hints: obj(st.hints, (list) => list),
    starred: obj(st.starred, (p) => p),
    profile: st.profile, eventCount: st.eventCount, maxLamport: st.maxLamport,
    lastSeq: Object.fromEntries(st.lastSeq), unknownEvents: st.unknownEvents,
  })) as JSONValue;
}

const journal = (name: string) => readJournal(readContract(`fixtures/events/${name}.jsonl`)).events;

/** Deterministic shuffle (mulberry32), so a failure can be reproduced from the seed. */
function shuffled<T>(xs: readonly T[], seed: number): T[] {
  let a = seed >>> 0;
  const rnd = () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 2 ** 32; };
  const out = [...xs];
  for (let i = out.length - 1; i > 0; i--) { const j = Math.floor(rnd() * (i + 1)); [out[i], out[j]] = [out[j] as T, out[i] as T]; }
  return out;
}

describe("golden state written by Swift Merger.build", () => {
  it.each([["sample-journal", "sample-journal"], ["merge-two-devices.input", "merge-two-devices"]])("%s", (input, golden) => {
    expect(projection(buildState(journal(input)))).toEqual(readJSON(`fixtures/events/${golden}.state.json`));
  });

  it("matches the older merge-two-devices expectation (visible sessions, messages, starred keys)", () => {
    const st = buildState(journal("merge-two-devices.input"));
    const want = readJSON<{ visibleSessions: { id: string; title: string }[]; starred: string[]; messages: Record<string, { id: string; heard?: string; interruptedAt?: number }[]> }>("fixtures/events/merge-two-devices.expected.json");
    expect(visibleSessions(st).map((s) => ({ id: s.id, lang: s.settings.lang, title: s.title }))).toEqual(want.visibleSessions);
    expect([...st.starred.keys()].sort()).toEqual(want.starred);
    for (const [sid, list] of Object.entries(want.messages)) {
      expect(st.messages.get(sid)?.map((m) => m.id)).toEqual(list.map((m) => m.id));
      expect(st.messages.get(sid)?.map((m) => m.heard)).toEqual(list.map((m) => m.heard));
    }
  });
});

describe("merging is commutative and idempotent", () => {
  const all = [...journal("sample-journal"), ...journal("merge-two-devices.input")];
  const want = canonicalJSON(projection(buildState(all)));
  it.each([1, 2, 3, 42, 2026, 31337])("shuffled with seed %i and with duplicates", (seed) => {
    const input = shuffled([...all, ...all.slice(0, seed % all.length)], seed);
    expect(canonicalJSON(projection(buildState(input)))).toBe(want);
    expect(canonicalJSON(projection(buildState([...input, ...input])))).toBe(want);
  });
});

describe("rules", () => {
  const ev = (o: Partial<JournalEvent> & Pick<JournalEvent, "id" | "type" | "payload">): JournalEvent =>
    ({ v: 1, device: "mac-aaaa", seq: 1, lamport: 1, ts: 1_792_900_000_000, session: "s1", extra: {}, ...o });
  const created = ev({ id: "01M5VJ1KF80KH70QYS833AQ700", type: "session.created", payload: {
    title: "T", settings: { lang: "de", mode: "free", topic: "", role: "", level: "", customPrompt: "", corrections: ["inline"], starter: "user" } } });

  it("a deleted session is a tombstone: kept in state, not visible", () => {
    const del = ev({ id: "01M5VJ1KF80KH70QYS833AQ701", type: "session.deleted", payload: {}, seq: 2, lamport: 2, ts: created.ts + 1 });
    const st = buildState([del, created]);
    expect(st.sessions.get("s1")?.deleted).toBe(true);
    expect(visibleSessions(st)).toEqual([]);
  });

  it("equal timestamps are ordered by device, then seq, then id", () => {
    const msg = (id: string, device: string, seq: number) => ev({ id, device, seq, type: "message.created", payload: { role: "user", text: id, lang: "de" } });
    const st = buildState([msg("01M5VJ1KF80KH70QYS833AQ7B3", "web-bbbb", 1), msg("01M5VJ1KF80KH70QYS833AQ7A2", "mac-aaaa", 2), msg("01M5VJ1KF80KH70QYS833AQ7A1", "mac-aaaa", 1), created]);
    expect(st.messages.get("s1")?.map((m) => m.text)).toEqual(["01M5VJ1KF80KH70QYS833AQ7A1", "01M5VJ1KF80KH70QYS833AQ7A2", "01M5VJ1KF80KH70QYS833AQ7B3"]);
  });

  it("last writer wins by lamport, then device; an undecodable payload counts as unknown", () => {
    const rename = (id: string, device: string, lamport: number, title: string) =>
      ev({ id, device, lamport, seq: lamport, ts: created.ts + lamport, type: "session.updated", payload: { title } });
    const st = buildState([created, rename("01M5VJ1KF80KH70QYS833AQ7C1", "web-zzzz", 5, "web"), rename("01M5VJ1KF80KH70QYS833AQ7C2", "mac-aaaa", 5, "mac"),
      rename("01M5VJ1KF80KH70QYS833AQ7C3", "mac-aaaa", 4, "old"), ev({ id: "01M5VJ1KF80KH70QYS833AQ7C4", type: "session.updated", payload: { title: 5 } }),
      ev({ id: "01M5VJ1KF80KH70QYS833AQ7C5", type: "future.thing", payload: {} })]);
    expect(st.sessions.get("s1")?.title).toBe("web");
    expect(st.unknownEvents).toBe(2);
  });

  it("keeps parse → serialize → parse stable for every fixture event", () => {
    for (const e of journal("sample-journal")) expect(parseEventLine(eventLine(e))).toEqual(e);
  });
});
