import { LANGS, type Fix, type Lang, type ReplySegment } from "../model/types.js";
import { characters, indexOfCharacter, isNewline, splitOnce, trimSpaces } from "./text.js";

/** The model reply protocol (R-24), as Swift `ReplyProtocol`: one tagged item per line; an untagged line is `@say` and a violation. */
export interface Parsed { segments: ReplySegment[]; violations: number }

const lang = (s: string | undefined): Lang | null => ((LANGS as readonly string[]).includes(s ?? "") ? (s as Lang) : null);
const say = (l: Lang, t: string): ReplySegment => ({ say: { _0: l, _1: t } });

export function sayText(s: ReplySegment): string | undefined {
  return "say" in s ? s.say._1 : undefined;
}

/** Text for display and speech: the `@say` lines joined with spaces (Swift `ChatMessage.spokenText` of an assistant message). */
export function spokenText(segments: readonly ReplySegment[], raw: string): string {
  return segments.length === 0 ? removingSilentLines(raw) : segments.flatMap((s) => sayText(s) ?? []).join(" ");
}

/** Tags parsed silently (LINGO-05 PX-01; LINGO-09 MR-11, MR-12, MR-14 add `next` and `help`, MR-50 `reply`): never spoken, never a segment. */
export const SILENT_TAGS: ReadonlySet<string> = new Set(["grade", "task", "next", "help", "reply"]);

/** The tag (lower case) and body of a tagged line after the `parseLine` clean-up; null for an untagged line. */
function tagged(raw: string): { tag: string; body: string; lang: string | null } | null {
  let line = trimSpaces(raw);
  while (line !== "" && "-*•>".includes(characters(line)[0] as string)) line = trimSpaces(line.slice((characters(line)[0] as string).length));
  line = line.replaceAll("**", "");
  if (characters(line)[0] !== "@") return null;
  const colon = indexOfCharacter(line, ":");
  if (colon < 0) {
    // No colon: the first word is the tag, the rest the body ("@grade good").
    const words = line.slice(1).split(" ").filter((x) => x !== "");
    if (words.length === 0) return null;
    return { tag: (words[0] as string).toLowerCase(), body: trimSpaces(words.slice(1).join(" ")), lang: null };
  }
  const head = line.slice(1, colon).toLowerCase().split(" ").filter((x) => x !== "");
  return { tag: head[0] ?? "", body: trimSpaces(line.slice(colon + 1)), lang: head[1] ?? null };
}

/** The raw text without silent-tag lines (Swift `ReplyProtocol.removingSilentLines`). */
export function removingSilentLines(text: string): string {
  return text.split("\n").filter((l) => { const t = tagged(l); return t === null || !SILENT_TAGS.has(t.tag); }).join("\n");
}

/** One answer the learner could give (LINGO-09 MR-50). */
export interface ReplyOption { lang: Lang; text: string; translation: string }

/** More `@reply` lines than this keep the first three (MR-50). */
export const MAX_REPLY_OPTIONS = 3;

/**
 * The options of a raw reply, as Swift `ReplyOptions.parse`: from the raw text like every silent tag; a line without the `|` separator
 * or with an empty phrase is skipped; a missing or unknown language means the study language.
 */
export function parseReplyOptions(raw: string, studyLang: Lang): ReplyOption[] {
  const out: ReplyOption[] = [];
  // Lines split on every newline Character, as `parseReply` ("\r\n" is one), so a CRLF reply loses no trailing "\r" into a translation.
  const lines: string[] = [];
  let cur = "";
  for (const c of characters(stripThinking(raw))) { if (isNewline(c)) { lines.push(cur); cur = ""; } else cur += c; }
  lines.push(cur);
  for (const line of lines) {
    const t = tagged(line);
    if (t === null || t.tag !== "reply") continue;
    const bar = t.body.indexOf("|");
    if (bar < 0) continue;
    const text = trimSpaces(t.body.slice(0, bar));
    if (text === "") continue;
    out.push({ lang: lang(t.lang ?? undefined) ?? studyLang, text, translation: trimSpaces(t.body.slice(bar + 1)) });
    if (out.length === MAX_REPLY_OPTIONS) break;
  }
  return out;
}

/** Removes `<think>…</think>` reasoning blocks; an unterminated block is cut to the end. */
export function stripThinking(s: string): string {
  let out = s;
  for (let a = out.indexOf("<think>"); a >= 0; a = out.indexOf("<think>")) {
    const b = out.indexOf("</think>", a + 7);
    out = b < 0 ? out.slice(0, a) : out.slice(0, a) + out.slice(b + 8);
  }
  return out;
}

export function parseReply(text: string, studyLang: Lang): Parsed {
  const segments: ReplySegment[] = [];
  let violations = 0;
  let line = "";
  const flush = () => {
    if (line === "") return;
    const [seg, bad] = parseLine(line, studyLang);
    if (bad) violations++;
    if (seg) segments.push(seg);
    line = "";
  };
  for (const c of characters(stripThinking(text))) {
    if (isNewline(c)) flush(); else line += c;
  }
  flush();
  return { segments, violations };
}

/** One line → segment (or none) and whether it violates the protocol. */
export function parseLine(raw: string, studyLang: Lang): [ReplySegment | null, boolean] {
  let line = trimSpaces(raw);
  // Models sometimes format lines as a list or in bold: "- @say de: …", "**@say de:** …".
  while (line !== "" && "-*•>".includes(characters(line)[0] as string)) line = trimSpaces(line.slice((characters(line)[0] as string).length));
  line = line.replaceAll("**", "");
  if (line === "") return [null, false];
  // Character comparisons, as Swift: "@" followed by a combining mark is a different Character.
  if (characters(line)[0] !== "@") return [say(studyLang, line), true];
  // A silent tag stays silent even without its colon ("@grade good").
  const silent = tagged(line);
  if (silent !== null && SILENT_TAGS.has(silent.tag)) return [null, false];
  const colon = indexOfCharacter(line, ":");
  if (colon < 0) return [say(studyLang, line.slice(1)), true];
  const head = line.slice(1, colon).toLowerCase().split(" ").filter((x) => x !== "");
  const body = trimSpaces(line.slice(colon + 1));
  const tag = head[0] ?? "";
  const l = head.length > 1 ? lang(head[1]) : null;
  const langBad = head.length > 1 && l === null;
  switch (tag) {
    case "say":
      return body === "" ? [null, true] : [say(l ?? studyLang, body), langBad];
    case "fix": {
      const fix = parseFix(body);
      return fix ? [{ fix: { _0: fix } }, false] : [null, true];
    }
    case "heard":
      return body === "" ? [null, true] : [{ heard: { _0: body } }, false];
    case "grade":
    case "task":
    case "next":
    case "help":
    case "reply":
      return [null, false];
    case "tutor":
      // LINGO-09 MR-13/MR-14: the tutor's line outside the scene is an ordinary say segment.
      return body === "" ? [null, true] : [say(l ?? studyLang, body), langBad];
    case "hint": {
      const parts = splitOnce(body, "|").map(trimSpaces);
      const phrase = parts[0];
      if (!phrase) return [null, true];
      return [{ hint: { _0: { lang: l ?? studyLang, text: phrase, translation: parts[1] ?? "", source: "hint" } } }, langBad];
    }
    default:
      return [say(studyLang, body), true];
  }
}

const QUOTES = /^["'«»„“”‚‘’ ]+|["'«»„“”‚‘’ ]+$/gu;

/** "wrong → right | rule"; arrows "→", "->", "=>". */
export function parseFix(body: string): Fix | null {
  const parts = splitOnce(body, "|").map(trimSpaces);
  const pair = parts[0];
  if (pair === undefined) return null;
  for (const arrow of ["→", "->", "=>"]) {
    const i = pair.indexOf(arrow);
    if (i < 0) continue;
    const a = trimSpaces(pair.slice(0, i)), b = trimSpaces(pair.slice(i + arrow.length));
    if (a === "" || b === "") return null;
    return { original: a.replace(QUOTES, ""), corrected: b.replace(QUOTES, ""), rule: parts[1] ?? "" };
  }
  return null;
}

/** A streamed item: a finished `@say` sentence ready to be spoken (R-13), or a finished protocol line. */
export type StreamItem = { speak: [Lang, string] } | { segment: ReplySegment };

/**
 * Streaming parser, as Swift `ReplyStreamParser`. The items never depend on how the reply is cut into chunks: a sentence of a
 * `@say` line is spoken once it ends with ".", "!", "?" or "…" followed by a space; the rest when the line ends.
 */
export class ReplyStreamParser {
  private line = "";
  /** How many Characters of the current `@say` body have been sent to speech. */
  private spokenUpTo = 0;
  private inThink = false;
  private pending = "";
  text = "";
  violations = 0;

  constructor(readonly studyLang: Lang) {}

  feed(chunk: string): StreamItem[] {
    this.text += chunk;
    const out: StreamItem[] = [];
    this.pending += chunk;
    for (;;) {
      if (this.inThink) {
        const end = this.pending.indexOf("</think>");
        if (end < 0) return out;
        this.pending = this.pending.slice(end + 8);
        this.inThink = false;
      }
      const start = this.pending.indexOf("<think>");
      if (start >= 0) {
        this.consume(this.pending.slice(0, start), out);
        this.pending = this.pending.slice(start + 7);
        this.inThink = true;
        continue;
      }
      // A possible start of "<think>" at the end of a chunk — wait for the next chunk.
      const lt = this.pending.lastIndexOf("<");
      if (lt >= 0 && "<think>".startsWith(this.pending.slice(lt))) {
        this.consume(this.pending.slice(0, lt), out);
        this.pending = this.pending.slice(lt);
      } else {
        this.consume(this.pending, out);
        this.pending = "";
      }
      return out;
    }
  }

  finish(): StreamItem[] {
    const out: StreamItem[] = [];
    if (!this.inThink && this.pending !== "") this.consume(this.pending, out);
    this.pending = "";
    this.emitSentences(out);
    this.completeLine(out);
    return out;
  }

  private consume(s: string, out: StreamItem[]): void {
    for (const c of characters(s)) {
      if (isNewline(c)) {
        this.emitSentences(out);
        this.completeLine(out);
      } else {
        this.line += c;
      }
    }
    this.emitSentences(out);
  }

  /** Body of an unfinished `@say` line (or an untagged line) once its start is clear. */
  private sayBody(): [Lang, string] | null {
    const t = trimSpaces(this.line);
    if (t === "") return null;
    // A line with list or quote markup ("- ", "* ", "• ", "> ") is never streamed: `parseLine` strips the markup when it completes.
    const first = characters(t)[0] as string;
    if (first !== "@" && !"-*•>".includes(first)) return [this.studyLang, this.line];
    const colon = indexOfCharacter(this.line, ":");
    if (characters(t.toLowerCase()).slice(0, 4).join("") !== "@say" || colon < 0) return null;
    const head = this.line.slice(0, colon).toLowerCase().split(" ").filter((x) => x !== "");
    return [head.length > 1 ? (lang(head[1]) ?? this.studyLang) : this.studyLang, this.line.slice(colon + 1)];
  }

  private emitSentences(out: StreamItem[]): void {
    const b = this.sayBody();
    if (!b) return;
    const [l, body] = b;
    const chars = characters(body);
    let lastCut = this.spokenUpTo;
    for (let i = this.spokenUpTo; i < chars.length - 1; i++) {
      if (".!?…".includes(chars[i] as string) && chars[i + 1] === " ") {
        // `**` is removed as `parseLine` removes it, so a spoken sentence matches the displayed segment text.
        const sentence = trimSpaces(chars.slice(lastCut, i + 1).join("").replaceAll("**", ""));
        if (sentence !== "") out.push({ speak: [l, sentence] });
        lastCut = i + 1;
      }
    }
    this.spokenUpTo = lastCut;
  }

  private completeLine(out: StreamItem[]): void {
    const line = this.line;
    const b = this.sayBody();
    const spoken = this.spokenUpTo;
    this.line = "";
    this.spokenUpTo = 0;
    if (trimSpaces(line) === "") return;
    const [seg, bad] = parseLine(line, this.studyLang);
    if (bad) this.violations++;
    if (!seg) return;
    if ("say" in seg) {
      const l = seg.say._0;
      if (b) {
        const rest = trimSpaces(characters(b[1]).slice(spoken).join(""));
        const cleaned = (() => { const p = parseLine(`@say ${l}: ${rest}`, this.studyLang)[0]; return (p && sayText(p)) ?? rest; })();
        if (cleaned !== "") out.push({ speak: [l, cleaned] });
      } else {
        // A formatted line ("- @say en: …", "**@say en:** …") is not streamed; it is spoken whole once it is complete.
        out.push({ speak: [l, seg.say._1] });
      }
    }
    out.push({ segment: seg });
  }
}
