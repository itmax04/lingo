/** Swift `String` semantics used by the reply protocol: Characters are grapheme clusters, `.whitespaces` is tab + space separators. */
const segmenter = new Intl.Segmenter(undefined, { granularity: "grapheme" });

/** Grapheme clusters — Swift `Array(string)`. */
export function characters(s: string): string[] {
  return Array.from(segmenter.segment(s), (x) => x.segment);
}

/** Swift `Character.isNewline` ("\r\n" is one Character). */
const NEWLINES = new Set(["\n", "\r", "\r\n", "\u000B", "\u000C", "\u0085", " ", " "]);
export function isNewline(c: string): boolean {
  return NEWLINES.has(c);
}

/** Swift `trimmingCharacters(in: .whitespaces)`. */
export function trimSpaces(s: string): string {
  return s.replace(/^[\t\p{Zs}]+|[\t\p{Zs}]+$/gu, "");
}

/** Swift `split(separator:maxSplits: 1)`: empty pieces are omitted and do not count, so leading separators are skipped first. */
export function splitOnce(s: string, sep: string): string[] {
  let start = 0;
  while (s.startsWith(sep, start)) start += sep.length;
  const rest = s.slice(start);
  const i = rest.indexOf(sep);
  const parts = i < 0 ? [rest] : [rest.slice(0, i), rest.slice(i + sep.length)];
  return parts.filter((p) => p !== "");
}

/** Code-unit index of the first Character equal to `c` (Swift `firstIndex(of:)` compares whole Characters), or -1. */
export function indexOfCharacter(s: string, c: string): number {
  let at = 0;
  for (const g of characters(s)) {
    if (g === c) return at;
    at += g.length;
  }
  return -1;
}

/** The first `n` Characters — Swift `String(s.prefix(n))`; interruption offsets (R-12) count Characters. */
export function prefixCharacters(s: string, n: number): string {
  return characters(s).slice(0, Math.max(0, n)).join("");
}
