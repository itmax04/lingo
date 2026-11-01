import { readdirSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { parse } from "yaml";
import { COMMAND_KINDS, detectCommand, isLocalCommand } from "../src/index.js";
import { EXACT, FILLERS, PREFIXES } from "../src/commands/vocabulary.js";
import { contractPath, readContract, readJSON } from "./contracts.js";

describe("command vocabulary", () => {
  it("is the Swift vocabulary (no drift)", () => {
    const v = readJSON<{ exact: Record<string, string[]>; prefixes: [string, string][]; fillers: string[] }>("fixtures/commands/vocabulary.json");
    expect(Object.fromEntries(Object.entries(EXACT).sort())).toEqual(Object.fromEntries(Object.entries(v.exact).sort()));
    expect(PREFIXES).toEqual(v.prefixes);
    expect([...FILLERS].sort()).toEqual([...v.fillers].sort());
  });
});

describe("detections written by Swift", () => {
  const rows = readJSON<{ text: string; kind: string | null; argument: string | null }[]>("fixtures/commands/detect.json");
  it("covers the eval set and the edge cases", () => expect(rows.length).toBeGreaterThanOrEqual(130));
  it.each(rows.map((r) => [r.text, r] as const))("%j", (_t, r) => {
    const m = detectCommand(r.text);
    expect(m?.kind ?? null).toBe(r.kind);
    expect(m?.argument ?? null).toBe(r.argument);
  });
});

describe("eval set `commands` (AC-04)", () => {
  const files = readdirSync(contractPath("evals/commands")).filter((f) => f.endsWith(".yaml")).sort();
  const cases = files.flatMap((f) => parse(readContract(`evals/commands/${f}`)) as { text: string; expect: string; argument?: string }[]);
  it("commands ≥ 95 %, false positives ≤ 3 %", () => {
    let correct = 0, negatives = 0, falsePositives = 0;
    for (const c of cases) {
      const m = detectCommand(c.text);
      const got = m?.kind ?? "none";
      if (got === c.expect && (c.argument === undefined || m?.argument?.toLowerCase() === c.argument.toLowerCase())) correct++;
      if (c.expect === "none") { negatives++; if (got !== "none") falsePositives++; }
    }
    expect(cases.length).toBeGreaterThanOrEqual(90);
    expect(correct / cases.length).toBeGreaterThanOrEqual(0.95);
    expect(negatives / cases.length).toBeGreaterThanOrEqual(0.25);
    expect(falsePositives / negatives).toBeLessThanOrEqual(0.03);
  });

  it("repeat and slower are local (never sent to a provider)", () => {
    expect(COMMAND_KINDS.filter(isLocalCommand)).toEqual(["repeat", "slower"]);
  });
});
