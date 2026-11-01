import { describe, expect, it } from "vitest";
import { containsItem, eventLine, normalizeVocab, parseEventLine, parseList, selectTargets, useOutcome, vocabKey, type Lang, type VocabItem } from "../src/index.js";
import { readContract, readJSON } from "./contracts.js";

describe("vocabulary text rules (fixtures/vocab/text.json)", () => {
  const f = readJSON<{ normalize: { in: string; out: string }[]; key: { lang: Lang; text: string; out: string }[];
    parseList: { in: string; entries: { text: string; translation: string }[]; rejected: number } }>("fixtures/vocab/text.json");
  it("normalise and key", () => {
    for (const c of f.normalize) expect(normalizeVocab(c.in)).toBe(c.out);
    for (const c of f.key) expect(vocabKey(c.lang, c.text)).toBe(c.out);
  });
  it("pasted list", () => {
    const r = parseList(f.parseList.in);
    expect(r.entries).toEqual(f.parseList.entries);
    expect(r.rejected).toBe(f.parseList.rejected);
  });
  it("long lines and the line limit", () => {
    expect(parseList(`${"x".repeat(121)} — translation\nok`).rejected).toBe(1);
    const r = parseList(Array.from({ length: 205 }, (_, i) => `word${i + 1}`).join("\n"));
    expect(r.entries.length).toBe(200);
    expect(r.rejected).toBe(5);
  });
});

describe("matching (fixtures/vocab/matching.json)", () => {
  const f = readJSON<{ cases: { lang: Lang; item: string; utterance: string; expected: boolean }[] }>("fixtures/vocab/matching.json");
  it.each(f.cases.map((c) => [`${c.item} in ${c.utterance}`, c] as const))("%s", (_n, c) => {
    expect(containsItem(c.item, c.utterance, c.lang)).toBe(c.expected);
  });
  it("mistake outcome follows the fix span", () => {
    const item = { text: "seit zwei Jahren", lang: "de" as Lang };
    expect(useOutcome(item, [{ original: "Ich wohne in Hamburg seit zwei Jahren und arbeite viel", corrected: "Ich wohne seit zwei Jahren in Hamburg und arbeite viel", rule: "" }])).toBe("ok");
    expect(useOutcome({ text: "seit zwei Jahre", lang: "de" }, [{ original: "Ich wohne seit zwei Jahre hier", corrected: "Ich wohne seit zwei Jahren hier", rule: "" }])).toBe("mistake");
  });
  it("a repeated-word item does not stall", () => {
    const t0 = Date.now();
    expect(containsItem("die die die die die die x", "die und ".repeat(60) + "y ".repeat(25) + "x", "de")).toBe(false);
    expect(containsItem("a a a a a a a a a a a a b", "a ".repeat(90) + "y ".repeat(25) + "b", "en")).toBe(false);
    expect(Date.now() - t0).toBeLessThan(1000);
  });
});

describe("selection (fixtures/vocab/selection.json)", () => {
  const f = readJSON<{ cases: { name: string; lang: Lang; count: number; usedInSession: string[]; pinned: string | null;
    items: { id: string; lang: Lang; text: string; createdAt: string; offered: number; used: number; mistakes: number; lastPractised: string | null }[]; expected: string[] }[] }>("fixtures/vocab/selection.json");
  it.each(f.cases.map((c) => [c.name, c] as const))("%s", (_n, c) => {
    const items: VocabItem[] = c.items.map((i) => {
      const x: VocabItem = { id: i.id, lang: i.lang, text: i.text, translation: "", note: "", example: "", source: "manual", createdAt: Date.parse(i.createdAt),
        offered: i.offered, used: i.used, mistakes: i.mistakes };
      if (i.lastPractised) x.lastPractised = Date.parse(i.lastPractised);
      return x;
    });
    expect(selectTargets(items, c.lang, new Set(c.usedInSession), c.count, c.pinned ?? undefined).map((i) => i.id)).toEqual(c.expected);
  });
});

describe("vocabulary events (fixtures/vocab/events.jsonl)", () => {
  it("round-trip byte for byte", () => {
    for (const l of readContract("fixtures/vocab/events.jsonl").split("\n").filter((x) => x !== "")) expect(eventLine(parseEventLine(l))).toBe(l);
  });
});
