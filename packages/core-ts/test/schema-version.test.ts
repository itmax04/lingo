import { describe, expect, it } from "vitest";
import { JOURNAL_SCHEMA_VERSION, isReadOnlyVersion } from "../src/index.js";
import { readContract, readJSON } from "./contracts.js";

describe("journal schema version", () => {
  it("matches the contract schema", () => {
    const schema = readJSON<{ properties: { v: { const: number } } }>("events/event.schema.json");
    expect(schema.properties.v.const).toBe(JOURNAL_SCHEMA_VERSION);
  });

  it("is the version of every line of the golden journal", () => {
    const lines = readContract("fixtures/events/sample-journal.jsonl").split("\n").filter((l) => l.trim() !== "");
    expect(lines.length).toBeGreaterThan(0);
    for (const line of lines) expect((JSON.parse(line) as { v: number }).v).toBe(JOURNAL_SCHEMA_VERSION);
  });

  it("opens a newer journal read-only", () => {
    expect(isReadOnlyVersion(JOURNAL_SCHEMA_VERSION)).toBe(false);
    expect(isReadOnlyVersion(JOURNAL_SCHEMA_VERSION + 1)).toBe(true);
  });
});
