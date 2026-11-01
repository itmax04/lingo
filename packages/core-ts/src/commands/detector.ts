import { characters } from "../protocol/text.js";
import { COMMAND_KINDS, type CommandKind } from "./kind.js";
import { EXACT, FILLERS, PREFIXES } from "./vocabulary.js";

/** A recognised command; `argument` is "what to say" for "how to say …" or "what to explain" for "what does … mean". */
export interface CommandMatch { kind: CommandKind; argument?: string }

const CHAR_MAP: Record<string, string> = { "ё": "е", "ä": "a", "ö": "o", "ü": "u", "ß": "ss", "’": "'", "`": "'" };
/** Swift `CharacterSet.letters` (L*, M*) and `.decimalDigits` (Nd), plus the apostrophe. */
const KEEP = /[\p{L}\p{M}\p{Nd}']/u;

/** As Swift `CommandDetector.normalize`: lower case, umlauts folded, punctuation to spaces, inner apostrophes kept. */
export function normalizeCommand(s: string): string {
  const mapped = characters(s.toLowerCase()).map((c) => CHAR_MAP[c] ?? c).join("");
  const kept = Array.from(mapped, (c) => (KEEP.test(c) ? c : " ")).join("");
  return kept.replaceAll(" '", " ").replaceAll("' ", " ").split(" ").filter((w) => w !== "").join(" ").replace(/^[' ]+|[' ]+$/g, "");
}

/** Transcription typo tolerance: short commands match only exactly. */
function tolerance(s: string): number {
  const n = characters(s).length;
  return n < 5 ? 0 : n < 9 ? 1 : 2;
}

/** Edit distance over Characters (grapheme clusters), as Swift. */
export function levenshtein(a: string, b: string): number {
  const x = characters(a), y = characters(b);
  if (x.length === 0) return y.length;
  if (y.length === 0) return x.length;
  let prev = Array.from({ length: y.length + 1 }, (_, i) => i);
  let cur = new Array<number>(y.length + 1).fill(0);
  for (let i = 1; i <= x.length; i++) {
    cur[0] = i;
    for (let j = 1; j <= y.length; j++) {
      cur[j] = Math.min((prev[j] as number) + 1, (cur[j - 1] as number) + 1, (prev[j - 1] as number) + (x[i - 1] === y[j - 1] ? 0 : 1));
    }
    [prev, cur] = [cur, prev];
  }
  return prev[y.length] as number;
}

function stripPrefix(words: readonly string[], prefix: readonly string[]): string[] | null {
  // Leading fillers ("ну, как сказать …") are skipped.
  let i = 0;
  while (i < words.length && FILLERS.has(words[i] as string) && !prefix.includes(words[i] as string)) i++;
  const w = words.slice(i);
  if (w.length < prefix.length || prefix.some((p, k) => w[k] !== p)) return null;
  return w.slice(prefix.length);
}

const ARG_EDGES = /^[ ?!.,:;—-]+|[ ?!.,:;—-]+$/gu;
const ARG_QUOTES = /^["'«»„“”]+|["'«»„“”]+$/gu;

/** The argument from the original text (case and punctuation kept), without the command words. */
function argumentText(original: string, prefixWords: number): string | undefined {
  const words = original.split(" ").filter((w) => w !== "");
  while (words.length > 0 && FILLERS.has(normalizeCommand(words[0] as string))) words.shift();
  if (words.length <= prefixWords) return undefined;
  const cleaned = words.slice(prefixWords).join(" ").replace(ARG_EDGES, "").replace(ARG_QUOTES, "");
  return cleaned === "" ? undefined : cleaned;
}

/**
 * Local command detector (R-14…R-22), as Swift `CommandDetector.detect`: a command is the whole utterance (after fillers), not a
 * word inside a sentence; unsure → null, and the utterance goes to the model as usual.
 */
export function detectCommand(text: string): CommandMatch | null {
  const norm = normalizeCommand(text);
  if (norm === "") return null;
  const words = norm.split(" ");
  if (words.length > 12) return null;
  for (const [kind, p] of PREFIXES) {
    const pw = p.split(" ");
    const rest = stripPrefix(words, pw);
    if (!rest || rest.length === 0) continue;
    // "почему так" and "объясни по русски" are exact commands; "почему ты …" is a normal question for the model.
    if (kind === "explain" && p === "почему" && rest.length > 2) continue;
    if (kind === "explain" && (p === "объясни" || p === "explain") && rest.length > 4) continue;
    return { kind, argument: argumentText(text, pw.length) ?? rest.join(" ") };
  }
  const core = words.filter((w) => !FILLERS.has(w)).join(" ");
  const candidates = [...new Set([norm, core])].filter((c) => c !== "");
  let best: [CommandKind, number] | null = null;
  for (const kind of COMMAND_KINDS) {
    for (const p of EXACT[kind] ?? []) {
      const pn = normalizeCommand(p);
      for (const c of candidates) {
        const d = levenshtein(c, pn);
        if (d <= tolerance(pn) && (best === null || d < best[1])) best = [kind, d];
      }
    }
  }
  return best ? { kind: best[0] } : null;
}
