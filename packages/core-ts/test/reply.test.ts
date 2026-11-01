import { describe, expect, it } from "vitest";
import { characters, parseReply, prefixCharacters, ReplyStreamParser, spokenText, type Lang, type ReplySegment, type StreamItem } from "../src/index.js";
import { readJSON } from "./contracts.js";

interface Case {
  name: string; studyLang: Lang; text: string; interruptedAt?: number;
  segments: ReplySegment[]; violations: number; items: StreamItem[]; spokenText: string; spokenPrefix?: string;
}
const { cases } = readJSON<{ cases: Case[] }>("fixtures/protocol/replies.json");

function stream(chunks: string[], lang: Lang): { items: StreamItem[]; violations: number } {
  const p = new ReplyStreamParser(lang);
  const items = chunks.flatMap((c) => p.feed(c));
  items.push(...p.finish());
  return { items, violations: p.violations };
}

describe("reply protocol fixture written by Swift", () => {
  it("has the cases", () => expect(cases.length).toBeGreaterThanOrEqual(15));

  it.each(cases.map((c) => [c.name, c] as const))("%s: segments, violations and spoken text", (_n, c) => {
    const parsed = parseReply(c.text, c.studyLang);
    expect(parsed.segments).toEqual(c.segments);
    expect(parsed.violations).toBe(c.violations);
    expect(spokenText(parsed.segments, c.text)).toBe(c.spokenText);
    if (c.interruptedAt !== undefined) expect(prefixCharacters(c.spokenText, c.interruptedAt)).toBe(c.spokenPrefix);
  });

  it.each(cases.map((c) => [c.name, c] as const))("%s: streamed items do not depend on chunk boundaries", (_n, c) => {
    const whole = stream([c.text], c.studyLang);
    expect(whole.items).toEqual(c.items);
    expect(whole.violations).toBe(c.violations);
    const chars = characters(c.text);
    for (let i = 0; i <= chars.length; i++) {
      expect(stream([chars.slice(0, i).join(""), chars.slice(i).join("")], c.studyLang).items).toEqual(c.items);
    }
    expect(stream(chars, c.studyLang).items).toEqual(c.items);
    // Speech comes only from @say segments: the spoken parts before each say segment join to its text.
    let parts: string[] = [];
    for (const item of whole.items) {
      if ("speak" in item) { parts.push(item.speak[1]); continue; }
      if ("say" in item.segment) expect(parts.join(" ")).toBe(item.segment.say._1); else expect(parts).toEqual([]);
      parts = [];
    }
  });
});

describe("streaming details", () => {
  it("speaks the first sentence before the line ends", () => {
    const p = new ReplyStreamParser("en");
    expect(p.feed("@say en: Hello there. How")).toEqual([{ speak: ["en", "Hello there."] }]);
    expect(p.feed(" are you?\n")).toEqual([{ speak: ["en", "How are you?"] }, { segment: { say: { _0: "en", _1: "Hello there. How are you?" } } }]);
  });

  it("holds a possible <think> start until the next chunk", () => {
    const p = new ReplyStreamParser("en");
    expect(p.feed("@say en: Hi. <thi")).toEqual([{ speak: ["en", "Hi."] }]);
    expect(p.feed("nk>secret</think>Bye.")).toEqual([]);
    expect(p.finish()).toEqual([{ speak: ["en", "Bye."] }, { segment: { say: { _0: "en", _1: "Hi. Bye." } } }]);
  });
});
