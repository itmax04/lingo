import { canonicalJSON, isJSONObject, type JSONObject, type JSONValue } from "../json.js";

/** Current schema version; a journal with a newer version is opened read-only (R-39). */
export const JOURNAL_SCHEMA_VERSION = 1;

/** A journal event (R-35), as Swift `Event`. Unknown types and fields are kept (`extra`, `payload`) and ignored by the reducer. */
export interface JournalEvent {
  v: number;
  id: string;
  device: string;
  seq: number;
  lamport: number;
  /** Milliseconds since 1970 (UTC), the ordering unit (R-37). */
  ts: number;
  type: string;
  session: string;
  payload: JSONValue;
  /** Top-level fields this schema version does not know. */
  extra: JSONObject;
}

/** Event types (R-35); the list matches Swift `EventType.all`. */
export const EventType = {
  sessionCreated: "session.created",
  sessionUpdated: "session.updated",
  sessionDeleted: "session.deleted",
  sessionEnded: "session.ended",
  sessionResumed: "session.resumed",
  messageCreated: "message.created",
  messageEdited: "message.edited",
  messageInterrupted: "message.interrupted",
  summaryUpdated: "summary.updated",
  fixRecorded: "fix.recorded",
  hintAdded: "hint.added",
  phraseStarred: "phrase.starred",
  phraseUnstarred: "phrase.unstarred",
  vocabAdded: "vocab.added",
  vocabUpdated: "vocab.updated",
  vocabRemoved: "vocab.removed",
  vocabUsed: "vocab.used",
  profileUpdated: "profile.updated",
} as const;
export const KNOWN_EVENT_TYPES: ReadonlySet<string> = new Set(Object.values(EventType));

const KNOWN_FIELDS = new Set(["v", "id", "device", "seq", "lamport", "ts", "type", "session", "payload"]);
/** `ts` as the contract schema allows it: UTC with optional milliseconds. */
const TS = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{3}))?Z$/;

export class EventParseError extends Error {
  constructor(readonly reason: "notJSON" | "notObject" | "missingField", readonly field?: string) {
    super(field ? `${reason}: ${field}` : reason);
    this.name = "EventParseError";
  }
}

/** "2026-10-25T13:01:02.123Z" (ISO 8601 UTC with milliseconds). */
export function formatTS(ms: number): string {
  return new Date(ms).toISOString();
}

/** Milliseconds, or null when the text is not a valid contract timestamp. */
export function parseTS(s: string): number | null {
  const m = TS.exec(s);
  if (!m) return null;
  const n = (i: number): number => Number(m[i] ?? 0);
  const t = Date.UTC(n(1), n(2) - 1, n(3), n(4), n(5), n(6), n(7));
  // Date.UTC rolls over invalid parts (month 13, day 32); a valid timestamp formats back to the same fields.
  return formatTS(t).slice(0, 19) === s.slice(0, 19) ? t : null;
}

/** One journal line (JSON Lines row) → event. Missing or ill-typed required fields are rejected; unknown data is kept. */
export function parseEventLine(line: string): JournalEvent {
  let raw: unknown;
  try {
    raw = JSON.parse(line);
  } catch {
    throw new EventParseError("notJSON");
  }
  if (!isJSONObject(raw)) throw new EventParseError("notObject");
  const o = raw;
  const int = (k: string): number => {
    const x = o[k];
    if (typeof x !== "number" || !Number.isInteger(x)) throw new EventParseError("missingField", k);
    return x;
  };
  const str = (k: string): string => {
    const x = o[k];
    if (typeof x !== "string") throw new EventParseError("missingField", k);
    return x;
  };
  const ts = parseTS(str("ts"));
  if (ts === null) throw new EventParseError("missingField", "ts");
  const extra: JSONObject = {};
  for (const [k, x] of Object.entries(o)) if (!KNOWN_FIELDS.has(k)) extra[k] = x;
  return {
    v: int("v"),
    id: str("id"),
    device: str("device"),
    seq: int("seq"),
    lamport: int("lamport"),
    ts,
    type: str("type"),
    session: typeof o["session"] === "string" ? o["session"] : "",
    payload: o["payload"] ?? {},
    extra,
  };
}

/** The event as a JSON object: unknown top-level fields first, known fields on top (as Swift `jsonObject()`). */
export function eventObject(e: JournalEvent): JSONObject {
  return {
    ...e.extra,
    v: e.v,
    id: e.id,
    device: e.device,
    seq: e.seq,
    lamport: e.lamport,
    ts: formatTS(e.ts),
    type: e.type,
    session: e.session,
    payload: e.payload,
  };
}

/** One line without a newline, keys sorted: byte-identical to Swift `Event.line()`. */
export function eventLine(e: JournalEvent): string {
  return canonicalJSON(eventObject(e));
}

/** A journal file (JSON Lines) → events; empty lines are skipped. */
export function parseJournal(text: string): JournalEvent[] {
  return text.split("\n").filter((l) => l.trim() !== "").map(parseEventLine);
}
