import { expect, it } from "vitest";
import { buildState, eventLine, readJournal } from "../src/index.js";
import { readContract } from "./contracts.js";

it("decodes all exam phases like Swift and preserves malformed events for future clients", () => {
  const text = readContract("fixtures/teacher/exam-events.jsonl");
  const events = readJournal(text).events;
  expect(events).toHaveLength(12);
  expect(events.map(eventLine).join("\n") + "\n").toBe(text);
  expect(buildState(events).unknownEvents).toBe(4);
  expect(buildState([...events].reverse()).unknownEvents).toBe(4);
});
