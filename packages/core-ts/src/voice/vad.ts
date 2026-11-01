/** Energy VAD configuration, as Swift `EnergyVAD.Config`; `voiceDefaults` is Swift `VoiceDefaults.vad` (ADR-0001 §8). */
export interface VADConfig {
  sampleRate: number; frameMs: number; minSpeechDB: number; marginDB: number; attackFrames: number; hangoverMs: number; noiseWindowMs: number;
}

/** Swift `EnergyVAD.Config()` (hangover 300 ms): the default of `new EnergyVAD()`, as in Swift. */
export const vadConfig: VADConfig = {
  sampleRate: 16_000, frameMs: 20, minSpeechDB: -50, marginDB: 10, attackFrames: 3, hangoverMs: 300, noiseWindowMs: 3000,
};

/** Swift `VoiceDefaults.vad` (hangover 200 ms), used by the voice loop. */
export const voiceDefaults: VADConfig = {
  sampleRate: 16_000, frameMs: 20, minSpeechDB: -50, marginDB: 10, attackFrames: 3, hangoverMs: 200, noiseWindowMs: 3000,
};

const f = Math.fround;

/** Frame level in dBFS with Swift `Float` (32-bit) arithmetic, so thresholds decide the same way as on the Mac. */
export function rmsDB(frame: ArrayLike<number>, from = 0, to = frame.length): number {
  if (to <= from) return -120;
  let sum = 0;
  for (let i = from; i < to; i++) { const s = f(frame[i] as number); sum = f(sum + f(s * s)); }
  const rms = f(Math.sqrt(f(sum / f(to - from))));
  return rms > 0 ? Math.max(-120, f(20 * f(Math.log10(rms)))) : -120;
}

/** A transition: `true` speech started, `false` speech ended; `sampleOffset` — end of the frame relative to the start of this block. */
export interface VADEvent { isSpeech: boolean; sampleOffset: number }

/**
 * Energy-based VAD with an adaptive threshold, as Swift `EnergyVAD`: 20 ms frames; the noise floor is the minimum frame level over a
 * sliding window, so speech (with dips between words) is detected and constant noise (a fan) is not.
 */
export class EnergyVAD {
  isSpeech = false;
  noiseFloorDB = -60;
  lastFrameDB = -120;
  private extraDB = 0;
  private above = 0;
  private belowMs = 0;
  private pending: number[] = [];
  private history: number[] = [];
  private historyIndex = 0;

  constructor(readonly config: VADConfig = vadConfig) {}

  /** Extra margin while the assistant speaks (R-12); a Swift `Float`. */
  get extraMarginDB(): number { return this.extraDB; }
  set extraMarginDB(db: number) { this.extraDB = f(db); }

  /** Samples per frame, an integer division as in Swift. */
  get frameSize(): number { return Math.trunc((this.config.sampleRate * this.config.frameMs) / 1000); }

  processEvents(samples: ArrayLike<number>): VADEvent[] {
    const carried = this.pending.length;
    for (let i = 0; i < samples.length; i++) this.pending.push(samples[i] as number);
    const changes: VADEvent[] = [];
    const n = this.frameSize;
    let offset = 0;
    while (this.pending.length - offset >= n) {
      const db = rmsDB(this.pending, offset, offset + n);
      offset += n;
      const change = this.processFrame(db);
      if (change !== null) changes.push({ isSpeech: change, sampleOffset: offset - carried });
    }
    this.pending.splice(0, offset);
    return changes;
  }

  private processFrame(db: number): boolean | null {
    this.lastFrameDB = db;
    const windowFrames = Math.max(1, Math.trunc(this.config.noiseWindowMs / this.config.frameMs));
    if (this.history.length < windowFrames) this.history.push(db);
    else { this.history[this.historyIndex] = db; this.historyIndex = (this.historyIndex + 1) % windowFrames; }
    let min = db;
    for (const h of this.history) if (h < min) min = h;
    this.noiseFloorDB = Math.max(-90, min);
    const threshold = f(f(Math.max(f(this.config.minSpeechDB), f(this.noiseFloorDB + f(this.config.marginDB)))) + this.extraDB);
    if (db > threshold) {
      this.above++;
      this.belowMs = 0;
      if (!this.isSpeech && this.above >= this.config.attackFrames) { this.isSpeech = true; return true; }
    } else {
      this.above = 0;
      this.belowMs += this.config.frameMs;
      if (this.isSpeech && this.belowMs >= this.config.hangoverMs) { this.isSpeech = false; return false; }
    }
    return null;
  }

  reset(): void {
    this.isSpeech = false; this.above = 0; this.belowMs = 0; this.pending = []; this.history = []; this.historyIndex = 0;
  }
}
