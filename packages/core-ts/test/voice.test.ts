import { describe, expect, it } from "vitest";
import { parse } from "yaml";
import { EnergyVAD, runTimeline, TurnSegmenter, turnConfig, voiceDefaults, type Piece, type Span, type TurnEvent } from "../src/index.js";
import { readContract, readJSON } from "./contracts.js";

interface Fixture {
  turns: { id: string; spans: [number, number][] }[];
  scripts: { name: string; ops: [string, number][]; events: Record<string, unknown>[] }[];
  vad: { name: string; runs: [number, number][]; events: [boolean, number][] }[];
}
interface TurnCase { id: string; timeline: string[]; expect: [number, number][]; assistant_at?: number[]; silence?: number; merge?: number }

const fx = readJSON<Fixture>("fixtures/voice/turns.json");
const cases = parse(readContract("evals/turn/timelines.yaml")) as TurnCase[];
const pieces = (tl: string[]): Piece[] => tl.map((x) => { const [k, ms] = x.split(" "); return k === "speech" ? { speech: Number(ms) } : { silence: Number(ms) }; });
const ms = (s: Span): [number, number] => [Math.round(s.start * 1000), Math.round(s.end * 1000)];
const cfg = (c: TurnCase) => turnConfig(c.silence ?? 1.5, 0.3, c.merge ?? 2.0);

/** As Swift `TurnEval.score`: a cut — one expected utterance split; a false merge — several expected ones in one. */
function score(expected: [number, number][], got: [number, number][]) {
  let cuts = 0, merges = 0;
  for (const e of expected) if (got.filter((g) => g[0] < e[1] + 50 && g[1] > e[0] - 50).length > 1) cuts++;
  for (const g of got) { const inside = expected.filter((e) => g[0] < e[1] + 50 && g[1] > e[0] - 50).length; if (inside > 1) merges += inside - 1; }
  return { cuts, merges };
}

describe("turn timelines (Swift TurnTimeline.run)", () => {
  it("covers every eval timeline", () => expect(fx.turns.map((t) => t.id)).toEqual(cases.map((c) => c.id)));
  it.each(cases.map((c) => [c.id, c] as const))("%s", (id, c) => {
    expect(runTimeline(pieces(c.timeline), cfg(c), c.assistant_at ?? []).map(ms)).toEqual(fx.turns.find((t) => t.id === id)?.spans);
  });
  it("eval `turn`: cuts ≤ 10 %, false merges ≤ 5 %", () => {
    let n = 0, cuts = 0, merges = 0;
    for (const c of cases) {
      const r = score(c.expect, runTimeline(pieces(c.timeline), cfg(c), c.assistant_at ?? []).map(ms));
      n += c.expect.length; cuts += r.cuts; merges += r.merges;
    }
    expect(cuts / n).toBeLessThanOrEqual(0.1);
    expect(merges / n).toBeLessThanOrEqual(0.05);
  });
});

describe("segmenter event traces (Swift TurnSegmenter)", () => {
  const encode = (e: TurnEvent): Record<string, unknown> => {
    switch (e.type) {
      case "speechBegan": return { speechBegan: Math.round(e.at * 1000), merges: e.mergesWithPrevious };
      case "utterance": return { utterance: ms(e.span) };
      case "merged": return { merged: ms(e.span), previous: ms(e.previous) };
      case "discarded": return { discarded: ms(e.span) };
    }
  };
  it.each(fx.scripts.map((s) => [s.name, s] as const))("%s", (_n, s) => {
    const seg = new TurnSegmenter();
    const out: TurnEvent[] = [];
    for (const [op, t] of s.ops) {
      const sec = t / 1000;
      if (op === "speech") out.push(...seg.speechStarted(sec));
      else if (op === "silence") out.push(...seg.speechEnded(sec));
      else if (op === "advance") out.push(...seg.advance(sec));
      else if (op === "assistant") seg.assistantStartedSpeaking();
      else out.push(...seg.flush(sec));
    }
    expect(out.map(encode)).toEqual(s.events);
  });
});

describe("energy VAD (Swift EnergyVAD with VoiceDefaults.vad)", () => {
  it.each(fx.vad.map((v) => [v.name, v] as const))("%s", (_n, v) => {
    const vad = new EnergyVAD(voiceDefaults);
    const events: [boolean, number][] = [];
    let offset = 0;
    for (const [a, frames] of v.runs) {
      for (let i = 0; i < frames; i++) {
        for (const e of vad.processEvents(new Float32Array(vad.frameSize).fill(a))) events.push([e.isSpeech, offset + e.sampleOffset]);
        offset += vad.frameSize;
      }
    }
    expect(events).toEqual(v.events);
  });

  it("eval `turn` through the VAD on synthetic audio: cuts ≤ 10 %, false merges ≤ 5 %", () => {
    // As Swift `TurnEval.runThroughVAD`: a 220 Hz tone with a 4 Hz syllable envelope for speech, -52 dBFS noise for silence.
    let seed = 1;
    const noise = () => { seed = (seed * 1103515245 + 12345) % 2 ** 31; return (seed / 2 ** 30 - 1) * 0.0025; };
    let n = 0, cuts = 0, merges = 0;
    const lead = 1000, att = (voiceDefaults.attackFrames * voiceDefaults.frameMs) / 1000, hang = voiceDefaults.hangoverMs / 1000;
    for (const c of cases) {
      const vad = new EnergyVAD(voiceDefaults), seg = new TurnSegmenter(cfg(c));
      const spans: Span[] = [];
      const pending = [...(c.assistant_at ?? [])];
      const apply = (ev: TurnEvent[]) => { for (const e of ev) { if (e.type === "utterance") spans.push(e.span); else if (e.type === "merged") { spans.pop(); spans.push(e.span); } } };
      let t = 0;
      for (const p of [{ silence: lead }, ...pieces(c.timeline), { silence: 4000 }] as Piece[]) {
        const speech = "speech" in p, total = (speech ? p.speech : p.silence) * 16;
        for (let k = 0; k < total; k += 320, t += 320) {
          const block = Float32Array.from({ length: 320 }, (_, i) => {
            const s = t + i;
            return speech ? 0.1 * (0.55 + 0.45 * Math.sin((s / 16000) * 2 * Math.PI * 4)) * Math.sin((s / 16000) * 2 * Math.PI * 220) + noise() : noise();
          });
          for (const e of vad.processEvents(block)) {
            const sec = (t + e.sampleOffset) / 16000 - lead / 1000;
            apply(e.isSpeech ? seg.speechStarted(sec - att) : seg.speechEnded(sec - hang));
          }
          const now = t / 16 - lead;
          while (pending.length > 0 && (pending[0] as number) <= now) { seg.assistantStartedSpeaking(); pending.shift(); }
          apply(seg.advance(now / 1000));
        }
      }
      const r = score(c.expect, spans.map(ms));
      n += c.expect.length; cuts += r.cuts; merges += r.merges;
    }
    expect(cuts / n).toBeLessThanOrEqual(0.1);
    expect(merges / n).toBeLessThanOrEqual(0.05);
  });
});
