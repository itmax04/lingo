import { array, attempt, bool, DecodeError, field, int, object, oneOf, optional, str, type Decoder } from "../model/decode.js";
import {
  decodeFix, decodePhrase, decodeSegment, decodeSettings, LANGS, MESSAGE_KINDS, ROLES, type Fix, type Lang, type MessageKind,
  type Phrase, type ReplySegment, type Role, type SessionSettings,
} from "../model/types.js";
import type { JSONValue } from "../json.js";

/** Event payloads (R-35), decoded with the strictness of Swift `Payload.*` (synthesized `Codable`). */
export interface SessionCreated { title: string; settings: SessionSettings }
export interface SessionUpdated { title?: string; settings?: SessionSettings }
export interface MessageCreated {
  role: Role; text: string; lang: Lang; segments?: ReplySegment[]; source?: string; kind?: MessageKind; replyTo?: string;
}
export interface SummaryUpdated { text: string; through?: string }
export interface ProfileUpdated { goals?: string; interests?: string }

function shape<T>(build: (o: Record<string, JSONValue>, p: string) => T): Decoder<T> {
  return (v, p) => build(object(v, p), p);
}
/** Drops `undefined` values so optional fields are absent, as in a Swift struct encoded back to JSON. */
function compact<T>(o: { [K in keyof T]-?: T[K] | undefined }): T {
  return Object.fromEntries(Object.entries(o).filter(([, x]) => x !== undefined)) as T;
}

const sessionCreated = shape<SessionCreated>((o, p) => ({ title: str(field(o, "title"), `${p}.title`), settings: decodeSettings(field(o, "settings"), `${p}.settings`) }));
const sessionUpdated = shape<SessionUpdated>((o, p) => compact({ title: optional(str)(field(o, "title"), `${p}.title`), settings: optional(decodeSettings)(field(o, "settings"), `${p}.settings`) }));
const messageCreated = shape<MessageCreated>((o, p) => compact({
  role: oneOf(ROLES)(field(o, "role"), `${p}.role`), text: str(field(o, "text"), `${p}.text`), lang: oneOf(LANGS)(field(o, "lang"), `${p}.lang`),
  segments: optional(array(decodeSegment))(field(o, "segments"), `${p}.segments`), source: optional(str)(field(o, "source"), `${p}.source`),
  kind: optional(oneOf(MESSAGE_KINDS))(field(o, "kind"), `${p}.kind`), replyTo: optional(str)(field(o, "replyTo"), `${p}.replyTo`),
}));
const messageEdited = shape((o, p) => ({ message: str(field(o, "message"), `${p}.message`), text: str(field(o, "text"), `${p}.text`) }));
const messageInterrupted = shape((o, p) => ({ message: str(field(o, "message"), `${p}.message`), at: int(field(o, "at"), `${p}.at`) }));
const summaryUpdated = shape<SummaryUpdated>((o, p) => compact({ text: str(field(o, "text"), `${p}.text`), through: optional(str)(field(o, "through"), `${p}.through`) }));
const fixRecorded = shape<{ message: string; fix: Fix }>((o, p) => ({ message: str(field(o, "message"), `${p}.message`), fix: decodeFix(field(o, "fix"), `${p}.fix`) }));
const phraseEvent = shape<{ phrase: Phrase }>((o, p) => ({ phrase: decodePhrase(field(o, "phrase"), `${p}.phrase`) }));
const profileUpdated = shape<ProfileUpdated>((o, p) => compact({ goals: optional(str)(field(o, "goals"), `${p}.goals`), interests: optional(str)(field(o, "interests"), `${p}.interests`) }));
// Vocabulary payloads (LINGO-08 VR-02): decoded here so that the unknown-event count matches Swift; their state is built in P-07c2.
const vocabDraft = shape((o, p) => ({ lang: oneOf(LANGS)(field(o, "lang"), `${p}.lang`), text: str(field(o, "text"), `${p}.text`),
  translation: optional(str)(field(o, "translation"), `${p}.translation`), note: optional(str)(field(o, "note"), `${p}.note`),
  example: optional(str)(field(o, "example"), `${p}.example`), source: oneOf(["manual", "list", "starred"] as const)(field(o, "source"), `${p}.source`) }));
const vocabAdded = shape((o, p) => ({ item: vocabDraft(field(o, "item"), `${p}.item`) }));
const vocabUpdated = shape((o, p) => ({ item: str(field(o, "item"), `${p}.item`), text: optional(str)(field(o, "text"), `${p}.text`),
  translation: optional(str)(field(o, "translation"), `${p}.translation`), note: optional(str)(field(o, "note"), `${p}.note`),
  example: optional(str)(field(o, "example"), `${p}.example`) }));
const vocabRemoved = shape((o, p) => ({ item: str(field(o, "item"), `${p}.item`) }));
const vocabUsed = shape((o, p) => ({ item: str(field(o, "item"), `${p}.item`), message: str(field(o, "message"), `${p}.message`),
  by: oneOf(["learner", "assistant"] as const)(field(o, "by"), `${p}.by`), outcome: oneOf(["ok", "mistake"] as const)(field(o, "outcome"), `${p}.outcome`) }));

// Card events (LINGO-05 CR-02): decoded so that the unknown-event count matches Swift; the schedule port comes with the web teacher (D-01).
const cardReviewed = shape((o, p) => ({ card: str(field(o, "card"), `${p}.card`),
  rating: oneOf(["again", "hard", "good", "easy"] as const)(field(o, "rating"), `${p}.rating`),
  source: oneOf(["warmup"] as const)(field(o, "source"), `${p}.source`), message: str(field(o, "message"), `${p}.message`) }));
const cardSuspended = shape((o, p) => ({ card: str(field(o, "card"), `${p}.card`), suspended: bool(field(o, "suspended"), `${p}.suspended`) }));
// The daily goal (LINGO-05 GR-02); statistics come with the web teacher (D-01).
const goalSet = shape((o, p) => ({ minutes: int(field(o, "minutes"), `${p}.minutes`) }));
// A completed scenario task (LINGO-05 SR-03).
const scenarioTask = shape((o, p) => {
  const task = int(field(o, "task"), `${p}.task`);
  if (task < 1) throw new DecodeError(`${p}.task`);  // Swift counts it as unknown too
  return { task, message: str(field(o, "message"), `${p}.message`) };
});

export const Payload = {
  sessionCreated: (v: JSONValue) => attempt(sessionCreated, v),
  sessionUpdated: (v: JSONValue) => attempt(sessionUpdated, v),
  messageCreated: (v: JSONValue) => attempt(messageCreated, v),
  messageEdited: (v: JSONValue) => attempt(messageEdited, v),
  messageInterrupted: (v: JSONValue) => attempt(messageInterrupted, v),
  summaryUpdated: (v: JSONValue) => attempt(summaryUpdated, v),
  fixRecorded: (v: JSONValue) => attempt(fixRecorded, v),
  phraseEvent: (v: JSONValue) => attempt(phraseEvent, v),
  profileUpdated: (v: JSONValue) => attempt(profileUpdated, v),
  vocabAdded: (v: JSONValue) => attempt(vocabAdded, v),
  vocabUpdated: (v: JSONValue) => attempt(vocabUpdated, v),
  vocabRemoved: (v: JSONValue) => attempt(vocabRemoved, v),
  vocabUsed: (v: JSONValue) => attempt(vocabUsed, v),
  cardReviewed: (v: JSONValue) => attempt(cardReviewed, v),
  cardSuspended: (v: JSONValue) => attempt(cardSuspended, v),
  goalSet: (v: JSONValue) => attempt(goalSet, v),
  scenarioTask: (v: JSONValue) => attempt(scenarioTask, v),
};
