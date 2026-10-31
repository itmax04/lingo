import { JOURNAL_SCHEMA_VERSION } from "./events/event.js";

export { JOURNAL_SCHEMA_VERSION, EventType, KNOWN_EVENT_TYPES, EventParseError, formatTS, parseTS, parseEventLine, eventObject,
  eventLine, readJournal, type JournalEvent, type JournalReadResult } from "./events/event.js";
export { makeULID, ulidTime, isValidULID, cryptoRandom, type RandomSource } from "./events/ulid.js";
export { canonicalJSON, numberJSON, compareCodePoints, isSwiftCompatible, isJSONObject, type JSONValue, type JSONObject } from "./json.js";

/** A journal written with a higher schema version is opened read-only (R-39), as in the Swift `JournalStore`. */
export function isReadOnlyVersion(v: number): boolean {
  return v > JOURNAL_SCHEMA_VERSION;
}
