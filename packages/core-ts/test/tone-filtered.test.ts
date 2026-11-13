import { describe, expect, it } from "vitest";
import { buildState, eventLine, EventType, KNOWN_EVENT_TYPES, readJournal } from "../src/index.js";
import type { JSONValue } from "../src/json.js";
import { Payload } from "../src/events/payloads.js";
import { readContract } from "./contracts.js";

describe("tone.filtered (LINGO-09 MR-15)", () => {
  const ok = (v: JSONValue) => Payload.toneFiltered(v) !== null;
  it("is a known event type", () => {
    expect(EventType.toneFiltered).toBe("tone.filtered");
    expect(KNOWN_EVENT_TYPES.has("tone.filtered")).toBe(true);
  });
  it("decodes a message id and a count of at least one; anything else is unknown", () => {
    expect(ok({ message: "m1", removed: 1 })).toBe(true);
    expect(ok({ message: "m1", removed: 3 })).toBe(true);
    expect(ok({ message: "m1", removed: 0 })).toBe(false);
    expect(ok({ message: "m1" })).toBe(false);
    expect(ok({ message: 7, removed: 1 })).toBe(false);
  });
  it("journal fixture: two valid events change nothing and three malformed ones count as unknown, in any order", () => {
    const text = readContract("fixtures/events/tone-filtered.jsonl");
    const events = readJournal(text).events;
    expect(events).toHaveLength(5);
    expect(events.map(eventLine).join("\n") + "\n").toBe(text);
    expect(buildState(events).unknownEvents).toBe(3);
    expect(buildState([...events].reverse()).unknownEvents).toBe(3);
  });
});
