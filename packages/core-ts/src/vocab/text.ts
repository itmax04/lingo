import { characters } from "../protocol/text.js";
import type { Lang } from "../model/types.js";

/** Swift `Character.isLetter` (Alphabetic first scalar) and `isNumber` (\p{N}), checked against Swift. */
const LETTER = /^\p{Alphabetic}/u;
const NUMBER = /^\p{N}/u;
const lower = (s: string) => Array.from(s, (c) => c.toLowerCase()).join("");

/** VR-07a: lower case, apostrophes dropped ("let's" → "lets"), other non-letters/digits to spaces, collapsed; as Swift `VocabularyText`. */
export function normalizeVocab(s: string): string {
  let out = "";
  for (const ch of characters(lower(s.normalize("NFC")))) {
    if (ch === "'" || ch === "’" || ch === "`") continue;
    out += LETTER.test(ch) || NUMBER.test(ch) ? ch : " ";
  }
  return out.split(" ").filter((w) => w !== "").join(" ");
}

export function vocabTokens(s: string): string[] {
  const n = normalizeVocab(s);
  return n === "" ? [] : n.split(" ");
}

/** Duplicate key: language + normalised text. */
export function vocabKey(lang: Lang, text: string): string {
  return `${lang}:${normalizeVocab(text)}`;
}

export const MAX_LIST_LINES = 200;
export const MAX_TEXT_CHARACTERS = 120;
export const MAX_TRANSLATION_CHARACTERS = 160;

export interface ParsedList { entries: { text: string; translation: string }[]; rejected: number }

const WS_TRIM = /^[\t\p{Zs}]+|[\t\p{Zs}]+$/gu;
const trim = (s: string) => s.replace(WS_TRIM, "");
const isWhitespace = (c: string | undefined) => c !== undefined && /^\p{White_Space}/u.test(c);

/** A bullet or a number is removed only when a space follows it, so "-5 Grad" and "1.5 kg" stay as they are. */
function stripBullet(line: string): string {
  const ch = characters(line);
  if (ch.length > 0 && "-•*–—".includes(ch[0] as string) && isWhitespace(ch[1])) return trim(ch.slice(1).join(""));
  let d = 0;
  while (d < ch.length && NUMBER.test(ch[d] as string)) d++;
  if (d > 0 && (ch[d] === "." || ch[d] === ")") && isWhitespace(ch[d + 1])) return trim(ch.slice(d + 1).join(""));
  return trim(line);
}

/** Mostly Cyrillic letters (Swift: `CharacterSet.letters` scalars, U+0400–U+04FF). */
function isCyrillic(s: string): boolean {
  const letters = Array.from(s).filter((c) => /^[\p{L}\p{M}]$/u.test(c));
  if (letters.length === 0) return false;
  const cyr = letters.filter((c) => { const v = c.codePointAt(0) as number; return v >= 0x0400 && v <= 0x04ff; }).length;
  return cyr * 2 > letters.length;
}

/**
 * A pasted list (VR-03), as Swift `VocabularyText.parseList`: one item per line; bullets and numbering removed; split at the first of
 * " — ", " – ", " - ", tab or ": " by position; a Cyrillic left side with a non-Cyrillic right side is swapped; empty lines skipped;
 * texts over 120 Characters and lines beyond 200 rejected.
 */
export function parseList(pasted: string): ParsedList {
  const separators = [" — ", " – ", " - ", "\t", ": "];
  const out: ParsedList = { entries: [], rejected: 0 };
  let lines = 0;
  for (const raw of pasted.split(/[\n\u000B\u000C\r\u0085\u2028\u2029]/u)) {
    let line = trim(raw);
    if (line === "") continue;
    lines++;
    if (lines > MAX_LIST_LINES) { out.rejected++; continue; }
    line = stripBullet(line);
    let text = line, translation = "";
    const hits = separators.map((s) => [s, line.indexOf(s)] as const).filter(([, i]) => i >= 0).sort((a, b) => a[1] - b[1]);
    const first = hits[0];
    if (first) {
      text = trim(line.slice(0, first[1]));
      translation = trim(line.slice(first[1] + first[0].length));
    }
    if (isCyrillic(text) && translation !== "" && !isCyrillic(translation)) [text, translation] = [translation, text];
    if (normalizeVocab(text) === "") continue;
    if (characters(text).length > MAX_TEXT_CHARACTERS) { out.rejected++; continue; }
    out.entries.push({ text, translation: characters(translation).slice(0, MAX_TRANSLATION_CHARACTERS).join("") });
  }
  return out;
}
