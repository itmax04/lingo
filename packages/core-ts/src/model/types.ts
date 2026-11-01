import { array, bool, DecodeError, field, object, oneOf, optional, str, type Decoder } from "./decode.js";

export const LANGS = ["en", "de", "ru"] as const;
export type Lang = (typeof LANGS)[number];
export const SESSION_MODES = ["questions", "free", "custom"] as const;
export type SessionMode = (typeof SESSION_MODES)[number];
/** In `CorrectionMode.allCases` order. */
export const CORRECTION_MODES = ["inline", "after", "on_demand"] as const;
export type CorrectionMode = (typeof CORRECTION_MODES)[number];
export const STARTERS = ["assistant", "user"] as const;
export type Starter = (typeof STARTERS)[number];
export const PHRASE_SOURCES = ["topic", "correction", "how_to_say", "hint"] as const;
export type PhraseSource = (typeof PHRASE_SOURCES)[number];
export const ROLES = ["user", "assistant"] as const;
export type Role = (typeof ROLES)[number];
export const MESSAGE_KINDS = ["normal", "summary", "error"] as const;
export type MessageKind = (typeof MESSAGE_KINDS)[number];

/** Session settings (R-01), as Swift `SessionSettings`; `corrections` is a set (its JSON order is not meaningful). */
export interface SessionSettings {
  lang: Lang;
  mode: SessionMode;
  topic: string;
  role: string;
  level: string;
  customPrompt: string;
  corrections: CorrectionMode[];
  starter: Starter;
  useVocabulary?: boolean;
  vocabularyFocus?: boolean;
  pinnedVocab?: string;
}

export interface Fix { original: string; corrected: string; rule: string }
export interface Phrase { lang: Lang; text: string; translation: string; source: PhraseSource }

/** A reply segment in Swift's synthesized enum encoding (`{"say":{"_0":"de","_1":"…"}}`), part of the contract. */
export type ReplySegment =
  | { say: { _0: Lang; _1: string } }
  | { fix: { _0: Fix } }
  | { hint: { _0: Phrase } }
  | { heard: { _0: string } };

const lang = oneOf(LANGS);

export const decodeSettings: Decoder<SessionSettings> = (v, p) => {
  const o = object(v, p);
  const s: SessionSettings = {
    lang: lang(field(o, "lang"), `${p}.lang`),
    mode: oneOf(SESSION_MODES)(field(o, "mode"), `${p}.mode`),
    topic: str(field(o, "topic"), `${p}.topic`),
    role: str(field(o, "role"), `${p}.role`),
    level: str(field(o, "level"), `${p}.level`),
    customPrompt: str(field(o, "customPrompt"), `${p}.customPrompt`),
    corrections: [...new Set(array(oneOf(CORRECTION_MODES))(field(o, "corrections"), `${p}.corrections`))],
    starter: oneOf(STARTERS)(field(o, "starter"), `${p}.starter`),
  };
  const useVocabulary = optional(bool)(field(o, "useVocabulary"), `${p}.useVocabulary`);
  const vocabularyFocus = optional(bool)(field(o, "vocabularyFocus"), `${p}.vocabularyFocus`);
  const pinnedVocab = optional(str)(field(o, "pinnedVocab"), `${p}.pinnedVocab`);
  if (useVocabulary !== undefined) s.useVocabulary = useVocabulary;
  if (vocabularyFocus !== undefined) s.vocabularyFocus = vocabularyFocus;
  if (pinnedVocab !== undefined) s.pinnedVocab = pinnedVocab;
  return s;
};

export const decodeFix: Decoder<Fix> = (v, p) => {
  const o = object(v, p);
  return { original: str(field(o, "original"), `${p}.original`), corrected: str(field(o, "corrected"), `${p}.corrected`),
    rule: str(field(o, "rule"), `${p}.rule`) };
};

export const decodePhrase: Decoder<Phrase> = (v, p) => {
  const o = object(v, p);
  return { lang: lang(field(o, "lang"), `${p}.lang`), text: str(field(o, "text"), `${p}.text`),
    translation: str(field(o, "translation"), `${p}.translation`), source: oneOf(PHRASE_SOURCES)(field(o, "source"), `${p}.source`) };
};

/** Swift's synthesized enum decoder: exactly one known case key (other keys are ignored), associated values as `_0`, `_1`. */
const SEGMENT_CASES = new Set(["say", "fix", "hint", "heard"]);
export const decodeSegment: Decoder<ReplySegment> = (v, p) => {
  const o = object(v, p);
  const keys = Object.keys(o).filter((k) => SEGMENT_CASES.has(k));
  if (keys.length !== 1) throw new DecodeError(p);
  const k = keys[0] as string;
  const inner = object(o[k], `${p}.${k}`);
  switch (k) {
    case "say": return { say: { _0: lang(field(inner, "_0"), `${p}.say._0`), _1: str(field(inner, "_1"), `${p}.say._1`) } };
    case "fix": return { fix: { _0: decodeFix(field(inner, "_0"), `${p}.fix._0`) } };
    case "hint": return { hint: { _0: decodePhrase(field(inner, "_0"), `${p}.hint._0`) } };
    case "heard": return { heard: { _0: str(field(inner, "_0"), `${p}.heard._0`) } };
    default: throw new DecodeError(p);
  }
};

/** Stable phrase key for ★ and de-duplication (R-28), as Swift `Phrase.key`: language + lower case, whitespace collapsed, trimmed. */
export function phraseKey(l: Lang, text: string): string {
  // Lower case per code point (no context rule such as the final sigma, like Swift), Swift's `.whitespacesAndNewlines`, and NFC,
  // because Swift compares and hashes strings by canonical equivalence (an NFD "café" is the same key as NFC).
  const lower = Array.from(text, (c) => c.toLowerCase()).join("");
  const norm = lower.split(/[\t-\r\u0085\p{Z}\u200B]+/u).filter((x) => x !== "").join(" ").replace(TRIM, "");
  return `${l}:${norm}`.normalize("NFC");
}
const TRIM_CHARS = ".!?…,;:«»\"“”„' ";
const TRIM = new RegExp(`^[${escapeClass(TRIM_CHARS)}]+|[${escapeClass(TRIM_CHARS)}]+$`, "gu");
function escapeClass(s: string): string {
  return s.replace(/[\\\]^-]/g, "\\$&");
}
