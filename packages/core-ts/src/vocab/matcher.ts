import { characters } from "../protocol/text.js";
import type { Fix, Lang } from "../model/types.js";
import { vocabTokens } from "./text.js";

/** VR-07b matching, as Swift `VocabularyMatcher` (golden cases: `fixtures/vocab/matching.json`). */
export const MAX_GAP = 3;
const MAX_STEPS = 2_000;
const PLACEHOLDERS: Record<string, ReadonlySet<string>> = {
  de: new Set(["sich", "jdm", "jdn", "jemandem", "jemanden", "etw", "etwas"]),
  en: new Set(["sb", "sth", "someone", "something", "somebody", "ones", "oneself"]),
};
const ENDINGS: Record<string, ReadonlySet<string>> = {
  de: new Set(["", "e", "en", "n", "st", "t", "et", "est", "te", "ten", "tet", "er", "es", "em", "s", "ens"]),
  en: new Set(["", "s", "es", "ed", "ing", "er"]),
};
const DROPPED_E_ENDINGS = new Set(["e", "es", "ed", "er", "ing"]);
/** Longest first, so that `vorbei` is tried before `vor`. */
const SEPARABLE = ["zusammen", "zurück", "vorbei", "weiter", "durch", "fest", "nach", "auf", "aus", "bei", "ein", "her", "hin", "los", "mit",
  "vor", "weg", "ab", "an", "um", "zu"];

const len = (s: string) => characters(s).length;
const drop = (s: string, n: number) => characters(s).slice(n).join("");
const dropLast = (s: string, n: number) => { const c = characters(s); return c.slice(0, c.length - n).join(""); };

/** Item tokens without placeholders (and without a leading English "to"). */
export function itemTokens(text: string, lang: Lang): string[] {
  const t = vocabTokens(text).filter((w) => !(PLACEHOLDERS[lang]?.has(w) ?? false));
  if (lang === "en" && t[0] === "to" && t.length > 1) t.shift();
  return t;
}

function stem(t: string, lang: Lang): string {
  if (lang === "de") {
    // At least 5 letters, so that short nouns keep their ending ("Rose" does not become "Ros" + "t").
    if (len(t) >= 5 && t.endsWith("en")) return dropLast(t, 2);
    if (len(t) >= 5 && (t.endsWith("n") || t.endsWith("e"))) return dropLast(t, 1);
    return t;
  }
  return len(t) > 3 && t.endsWith("e") ? dropLast(t, 1) : t;
}

/** One item token against one word: equal, or stem + allowed ending; short tokens must be equal; German participles may drop `ge`. */
export function wordMatches(token: string, word: string, lang: Lang): boolean {
  if (token === word) return true;
  if (len(token) <= 3) return false;
  const s = stem(token, lang);
  const candidates = [word];
  if (lang === "de" && word.startsWith("ge") && len(word) >= 6) candidates.push(drop(word, 2));
  // An English item that lost its `e` takes only vowel endings (`care` → `cares`, `caring`, but not `cars`).
  const allowed = lang === "en" && s !== token ? DROPPED_E_ENDINGS : (ENDINGS[lang] ?? new Set<string>());
  return candidates.some((w) => w.startsWith(s) && allowed.has(drop(w, len(s))));
}

/** Indices of the utterance words that realise one item token at `i` (two for a separated German verb), or null. */
function tokenAt(token: string, words: readonly string[], i: number, lang: Lang): number[] | null {
  const word = words[i] as string;
  if (wordMatches(token, word, lang)) return [i];
  if (lang !== "de") return null;
  for (const p of SEPARABLE) {
    if (!token.startsWith(p) || len(token) <= len(p) + 3) continue;
    const verb = drop(token, len(p));
    // Participle `angerufen` and zu-infinitive `anzurufen`: the prefix stays in front of the verb form.
    if (word.startsWith(p) && len(word) > len(p) + 3) {
      let rest = drop(word, len(p));
      if (rest.startsWith("zu") && len(rest) > 4 && wordMatches(verb, drop(rest, 2), lang)) return [i];
      if (rest.startsWith("ge")) rest = drop(rest, 2);
      if (wordMatches(verb, rest, lang)) return [i];
    }
    // Split form: `ich rufe dich morgen an`.
    if (wordMatches(verb, word, lang)) {
      const j = words.indexOf(p, i + 1);
      if (j > i && j - i <= 10) return [i, j];
    }
  }
  return null;
}

/** The utterance word indices that realise the item, or null; the same search, memo and step budget as Swift. */
export function matchItem(itemText: string, utterance: string, lang: Lang): number[] | null {
  const a = itemTokens(itemText, lang), b = vocabTokens(utterance);
  if (a.length === 0 || b.length === 0) return null;
  const hits = a.map((t) => { const m = new Map<number, number[]>(); b.forEach((_, i) => { const h = tokenAt(t, b, i, lang); if (h) m.set(i, h); }); return m; });
  if (hits.some((m) => m.size === 0)) return null;
  if (lang === "de") {
    const width = a.length + MAX_GAP * (a.length - 1);
    let steps = 0;
    const assign = (k: number, lo: number, hi: number, used: ReadonlySet<number>): number[] | null => {
      if (k === a.length) return [];
      for (let i = lo; i < hi; i++) {
        if (used.has(i)) continue;
        if (++steps > MAX_STEPS) return null;
        const hit = hits[k]?.get(i);
        if (!hit || hit.some((x) => used.has(x))) continue;
        const rest = assign(k + 1, lo, hi, new Set([...used, ...hit]));
        if (rest) return [...hit, ...rest];
      }
      return null;
    };
    for (let start = 0; start < b.length; start++) {
      steps = 0;
      const span = assign(0, start, Math.min(b.length, start + width), new Set());
      if (span) return span.sort((x, y) => x - y);
    }
    return null;
  }
  const failed = new Set<number>();
  const place = (k: number, prev: number): number[] | null => {
    if (k === a.length) return [];
    const memo = k * (b.length + 1) + prev + 1;
    if (failed.has(memo)) return null;
    const lo = k === 0 ? 0 : prev + 1, hi = k === 0 ? b.length : Math.min(b.length, prev + 2 + MAX_GAP);
    for (let j = lo; j < hi; j++) {
      const hit = hits[k]?.get(j);
      if (!hit) continue;
      const rest = place(k + 1, hit[0] as number);
      if (rest) return [...hit, ...rest];
    }
    failed.add(memo);
    return null;
  };
  return place(0, -1);
}

export function containsItem(itemText: string, utterance: string, lang: Lang): boolean {
  return matchItem(itemText, utterance, lang) !== null;
}

/** VR-07 outcome: a mistake when an `@fix` original contains the item and the corrected text realises it differently (or not at all). */
export function useOutcome(item: { text: string; lang: Lang }, fixes: readonly Fix[]): "ok" | "mistake" {
  for (const f of fixes) {
    const o = matchItem(item.text, f.original, item.lang);
    if (!o) continue;
    const ow = vocabTokens(f.original), cw = vocabTokens(f.corrected);
    const c = matchItem(item.text, f.corrected, item.lang);
    if (!c) return "mistake";
    if (o.map((i) => ow[i]).join("\u0000") !== c.map((i) => cw[i]).join("\u0000")) return "mistake";
  }
  return "ok";
}
