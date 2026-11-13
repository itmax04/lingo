import { describe, expect, it } from "vitest";
import { EventType, KNOWN_EVENT_TYPES, parseReply, parseReplyOptions, ReplyStreamParser, spokenText, type Lang, type ReplyOption, type StreamItem } from "../src/index.js";
import type { JSONValue } from "../src/json.js";
import { characters } from "../src/index.js";
import { Payload } from "../src/events/payloads.js";
import { removingSilentLines } from "../src/protocol/reply.js";
import { readContract, readJSON } from "./contracts.js";
import { buildState } from "../src/index.js";
import { eventLine, readJournal } from "../src/index.js";

interface Case { name: string; studyLang: Lang; text: string; options: ReplyOption[]; spokenText: string; violations: number; hints: number }
const { cases } = readJSON<{ cases: Case[] }>("fixtures/protocol/reply-options.json");

function stream(chunks: string[], lang: Lang): StreamItem[] {
  const p = new ReplyStreamParser(lang);
  const items = chunks.flatMap((c) => p.feed(c));
  items.push(...p.finish());
  return items;
}

describe("@reply, the silent tag of reply options (LINGO-09 MR-50, MAC-31)", () => {
  it("has the cases", () => expect(cases.length).toBeGreaterThanOrEqual(10));

  it.each(cases.map((c) => [c.name, c] as const))("%s", (_n, c) => {
    expect(parseReplyOptions(c.text, c.studyLang)).toEqual(c.options);
    const parsed = parseReply(c.text, c.studyLang);
    expect(spokenText(parsed.segments, c.text).trim()).toBe(c.spokenText);
    expect(parsed.violations).toBe(c.violations);
    expect(parsed.segments.filter((s) => "hint" in s).length).toBe(c.hints);
    const whole = stream([c.text], c.studyLang);
    expect(stream(characters(c.text), c.studyLang)).toEqual(whole);
    for (const item of whole) if ("speak" in item) expect(item.speak[1]).not.toContain("|");
    if (!c.text.includes("<think>")) expect(removingSilentLines(c.text)).not.toContain("@reply");
  });
});

describe("reply.revealed (LINGO-09 MR-54)", () => {
  const ok = (v: JSONValue) => Payload.replyRevealed(v) !== null;
  it("is a known event type", () => {
    expect(EventType.replyRevealed).toBe("reply.revealed");
    expect(KNOWN_EVENT_TYPES.has("reply.revealed")).toBe(true);
  });
  it("decodes ids and numbers only; anything else is unknown", () => {
    expect(ok({ message: "m1", index: 0 })).toBe(true);
    expect(ok({ message: "m1", index: 2 })).toBe(true);
    expect(ok({ message: "m1", index: -1 })).toBe(false);
    expect(ok({ message: "m1" })).toBe(false);
    expect(ok({ message: 1, index: 0 })).toBe(false);
  });
});

describe("reply.revealed journal fixture (MR-44, MR-45)", () => {
  it("two valid events change nothing and three malformed ones count as unknown, in any order", () => {
    const text = readContract("fixtures/events/reply-revealed.jsonl");
    const events = readJournal(text).events;
    expect(events).toHaveLength(5);
    expect(events.map(eventLine).join("\n") + "\n").toBe(text);
    expect(buildState(events).unknownEvents).toBe(3);
    expect(buildState([...events].reverse()).unknownEvents).toBe(3);
  });
});
