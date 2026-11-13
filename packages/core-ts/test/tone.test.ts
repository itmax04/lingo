import { describe, expect, it } from "vitest";
import { decodeSettings, TONE_PRESETS, type Tone } from "../src/index.js";
import type { JSONValue } from "../src/json.js";
import { readJSON } from "./contracts.js";

interface Fixture { base: Record<string, JSONValue>; cases: { name: string; extra: Record<string, JSONValue>; tone: Tone | null }[] }
const fx = readJSON<Fixture>("fixtures/events/tone-settings.json");

describe("tone in session settings (LINGO-09 MR-01, MR-45)", () => {
  it("has the cases", () => expect(fx.cases.length).toBeGreaterThanOrEqual(10));

  it.each(fx.cases.map((c) => [c.name, c] as const))("%s", (_n, c) => {
    const s = decodeSettings({ ...fx.base, ...c.extra }, "$");
    expect(s.tone ?? null).toEqual(c.tone);
    expect(s.lang).toBe("de");
  });

  it("presets are the documented constants", () => {
    expect(Object.values(TONE_PRESETS).map((t) => [t.harshness, t.hostility, t.profanity])).toEqual([[0, 0, false], [3, 0, false], [0, 3, false], [3, 3, false]]);
  });
});
