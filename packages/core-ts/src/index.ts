import { JOURNAL_SCHEMA_VERSION } from "./events/event.js";

export { JOURNAL_SCHEMA_VERSION, EventType, KNOWN_EVENT_TYPES, EventParseError, formatTS, parseTS, parseEventLine, eventObject,
  eventLine, readJournal, type JournalEvent, type JournalReadResult } from "./events/event.js";
export { makeULID, ulidTime, isValidULID, cryptoRandom, type RandomSource } from "./events/ulid.js";
export { canonicalJSON, numberJSON, compareCodePoints, isSwiftCompatible, isJSONObject, type JSONValue, type JSONObject } from "./json.js";

/** A journal written with a higher schema version is opened read-only (R-39), as in the Swift `JournalStore`. */
export function isReadOnlyVersion(v: number): boolean {
  return v > JOURNAL_SCHEMA_VERSION;
}
export { buildState, visibleSessions, compareVersions, type HistoryState, type Session, type ChatMessage, type FixEntry,
  type ProfileUpdate, type Version } from "./events/merge.js";
export { phraseKey, CORRECTION_MODES, LANGS, type Lang, type SessionSettings, type Tone, TONE_PRESETS, decodeSettings, type Fix, type Phrase, type ReplySegment, type Role,
  type CorrectionMode, type SessionMode, type Starter, type PhraseSource, type MessageKind } from "./model/types.js";
export { parseReply, parseLine, parseFix, stripThinking, sayText, spokenText, ReplyStreamParser, type Parsed, type StreamItem } from "./protocol/reply.js";
export { characters, prefixCharacters, trimSpaces } from "./protocol/text.js";
export { detectCommand, normalizeCommand, levenshtein, type CommandMatch } from "./commands/detector.js";
export { COMMAND_KINDS, isLocalCommand, type CommandKind } from "./commands/kind.js";
export { TurnSegmenter, turnConfig, runTimeline, SILENCE_RANGE, MERGE_RANGE, type TurnConfig, type TurnEvent, type Span, type Piece } from "./voice/segmenter.js";
export { EnergyVAD, rmsDB, vadConfig, voiceDefaults, type VADConfig, type VADEvent } from "./voice/vad.js";
