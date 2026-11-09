import { expect, it } from "vitest";
import { buildState, eventLine, readJournal } from "../src/index.js";
import { readContract } from "./contracts.js";

it("decodes all exam phases like Swift and preserves malformed events for future clients", () => {
  const text = readContract("fixtures/teacher/exam-events.jsonl");
  const events = readJournal(text).events;
  expect(events).toHaveLength(16);
  expect(events.map(eventLine).join("\n") + "\n").toBe(text);
  expect(buildState(events).unknownEvents).toBe(4);
  expect(buildState([...events].reverse()).unknownEvents).toBe(4);
});

it("decodes memory.* like Swift: valid payloads, else unknown", () => {
  const text = readContract("fixtures/teacher/memory-events.jsonl");
  const events = readJournal(text).events;
  expect(events).toHaveLength(9);
  expect(events.map(eventLine).join("\n") + "\n").toBe(text);
  expect(buildState(events).unknownEvents).toBe(4);
  expect(buildState([...events].reverse()).unknownEvents).toBe(4);
});

it("decodes report.weekly like Swift: a valid ISO week with text, else unknown", () => {
  const text = readContract("fixtures/teacher/weekly-events.jsonl");
  const events = readJournal(text).events;
  expect(events).toHaveLength(4);
  expect(events.map(eventLine).join("\n") + "\n").toBe(text);
  expect(buildState(events).unknownEvents).toBe(2);
  expect(buildState([...events].reverse()).unknownEvents).toBe(2);
});
