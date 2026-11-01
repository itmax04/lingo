/** End-of-utterance and merging parameters (R-10, R-11), as Swift `TurnConfig`. Times in seconds. */
export interface TurnConfig { silence: number; minSpeech: number; mergeGap: number }

export const SILENCE_RANGE = [0.6, 3.0] as const;
export const MERGE_RANGE = [0, 4] as const;
const clamp = (x: number, [lo, hi]: readonly [number, number]) => Math.min(Math.max(x, lo), hi);

/** T 1.5 s (0.6…3.0), minimum speech 0.3 s, G 2.0 s (0…4). */
export function turnConfig(silence = 1.5, minSpeech = 0.3, mergeGap = 2.0): TurnConfig {
  return { silence: clamp(silence, SILENCE_RANGE), minSpeech, mergeGap: clamp(mergeGap, MERGE_RANGE) };
}

export interface Span { start: number; end: number }

export type TurnEvent =
  /** Speech of a new utterance started (barge-in, UI). */
  | { type: "speechBegan"; at: number; mergesWithPrevious: boolean }
  /** The utterance is over (silence ≥ T). */
  | { type: "utterance"; span: Span }
  /** Over and merged with the previous one (R-11): cancel the pending request, send the combined text. */
  | { type: "merged"; previous: Span; span: Span }
  /** Speech shorter than the minimum: not an utterance. */
  | { type: "discarded"; span: Span };

const EPS = 1e-6;

/** Utterance boundaries from VAD events and the passage of time, as Swift `TurnSegmenter`; pure logic, time is passed in. */
export class TurnSegmenter {
  private inSpeech = false;
  private segStart = 0;
  private curStart: number | null = null;
  private lastSpeechEnd = 0;
  private speechSum = 0;
  private mergeCandidate = false;
  private previous: Span | null = null;
  private assistantStarted = false;

  constructor(public config: TurnConfig = turnConfig()) {}

  get isInUtterance(): boolean { return this.curStart !== null; }
  get isSpeaking(): boolean { return this.inSpeech; }

  speechStarted(t: number): TurnEvent[] {
    if (this.inSpeech) return [];
    this.inSpeech = true;
    this.segStart = t;
    if (this.curStart !== null) return [];
    this.curStart = t;
    this.speechSum = 0;
    const p = this.previous;
    this.mergeCandidate = p !== null && !this.assistantStarted && t - p.end <= this.config.mergeGap + EPS;
    return [{ type: "speechBegan", at: t, mergesWithPrevious: this.mergeCandidate }];
  }

  speechEnded(t: number): TurnEvent[] {
    if (!this.inSpeech) return [];
    this.inSpeech = false;
    this.speechSum += Math.max(0, t - this.segStart);
    this.lastSpeechEnd = t;
    return [];
  }

  /** Passage of time: closes the utterance after silence ≥ T. */
  advance(t: number): TurnEvent[] {
    const start = this.curStart;
    if (this.inSpeech || start === null || t - this.lastSpeechEnd < this.config.silence - EPS) return [];
    const span = { start, end: this.lastSpeechEnd };
    this.curStart = null;
    if (this.speechSum < this.config.minSpeech) return [{ type: "discarded", span }];
    this.assistantStarted = false;
    const p = this.previous;
    if (this.mergeCandidate && p) {
      const merged = { start: p.start, end: span.end };
      this.previous = merged;
      this.mergeCandidate = false;
      return [{ type: "merged", previous: p, span: merged }];
    }
    this.previous = span;
    return [{ type: "utterance", span }];
  }

  /** The assistant started speaking: the next utterance is a new turn, not a merge (R-11 → R-12). */
  assistantStartedSpeaking(): void {
    this.assistantStarted = true;
    this.mergeCandidate = false;
  }

  /** Forces the utterance to end (space released, the "Speak" button — R-06). */
  flush(t: number): TurnEvent[] {
    const out = this.speechEnded(t);
    const saved = this.config.silence;
    this.config = { ...this.config, silence: 0 };
    out.push(...this.advance(Math.max(t, this.lastSpeechEnd)));
    this.config = { ...this.config, silence: saved };
    return out;
  }

  reset(): void {
    Object.assign(this, new TurnSegmenter(this.config));
  }
}

export type Piece = { speech: number } | { silence: number };

/** Runs a speech/silence timeline (ms) through the segmenter, as Swift `TurnTimeline.run`: the final utterances after merges. */
export function runTimeline(pieces: readonly Piece[], config: TurnConfig = turnConfig(), assistantAt: readonly number[] = [], stepMs = 20): Span[] {
  const seg = new TurnSegmenter({ ...config });
  const spans: Span[] = [];
  const pending = [...assistantAt].sort((a, b) => a - b);
  const apply = (ev: TurnEvent[]) => {
    for (const e of ev) {
      if (e.type === "utterance") spans.push(e.span);
      else if (e.type === "merged") { spans.pop(); spans.push(e.span); }
    }
  };
  let t = 0;
  for (const p of pieces) {
    const speech = "speech" in p;
    const ms = speech ? p.speech : p.silence;
    apply(speech ? seg.speechStarted(t / 1000) : seg.speechEnded(t / 1000));
    for (let k = 0; k < ms;) {
      k += stepMs;
      const now = t + Math.min(k, ms);
      while (pending.length > 0 && (pending[0] as number) <= now) { seg.assistantStartedSpeaking(); pending.shift(); }
      apply(seg.advance(now / 1000));
    }
    t += ms;
  }
  apply(seg.speechEnded(t / 1000));
  apply(seg.advance(t / 1000 + 100));
  return spans;
}
