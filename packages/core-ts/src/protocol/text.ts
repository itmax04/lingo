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

/** Swift `split(separator:maxSplits: 1)` with empty pieces omitted. */
export function splitOnce(s: string, sep: string): string[] {
  const i = s.indexOf(sep);
  const parts = i < 0 ? [s] : [s.slice(0, i), s.slice(i + sep.length)];
  return parts.filter((p) => p !== "");
}

/** The first `n` Characters — Swift `String(s.prefix(n))`; interruption offsets (R-12) count Characters. */
export function prefixCharacters(s: string, n: number): string {
  return characters(s).slice(0, Math.max(0, n)).join("");
}
