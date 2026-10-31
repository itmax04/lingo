/** Journal schema version this core reads and writes (`v` in packages/contracts/events/event.schema.json). */
export const JOURNAL_SCHEMA_VERSION = 1;

/** A journal written with a higher schema version is opened read-only (R-39), as in the Swift `JournalStore`. */
export function isReadOnlyVersion(v: number): boolean {
  return v > JOURNAL_SCHEMA_VERSION;
}
