import { compareCodePoints } from "../json.js";
import type { Lang } from "../model/types.js";
import { vocabKey } from "./text.js";

/** One word, phrase or expression to practise (VR-01) with its statistics (VR-05), as Swift `VocabItem`. Times in ms. */
export interface VocabItem {
  id: string; lang: Lang; text: string; translation: string; note: string; example: string;
  source: "manual" | "list" | "starred"; createdAt: number;
  offered: number; used: number; mistakes: number; lastPractised?: number;
}

/** One counted use (VR-05), after de-duplication, with the canonical item id. */
export interface VocabUse { item: string; session: string; by: "learner" | "assistant"; outcome: "ok" | "mistake"; at: number }

/** Id of a ★ phrase shown as an item (VR-01a): `star:<lang>:<normalised text>`. */
export function starredID(lang: Lang, text: string): string {
  return `star:${vocabKey(lang, text)}`;
}

export function countUse(item: VocabItem, u: VocabUse): void {
  if (u.by === "assistant") item.offered++;
  else if (u.outcome === "ok") item.used++;
  else item.mistakes++;
  item.lastPractised = Math.max(item.lastPractised ?? -Infinity, u.at);
}

export const ORDINARY_COUNT = 3;
export const WORDS_MODE_COUNT = 6;

/** VR-06 order: used asc, mistakes desc, offered asc, last practised asc (never first), created desc, id bytes. */
function before(a: VocabItem, b: VocabItem): number {
  if (a.used !== b.used) return a.used - b.used;
  if (a.mistakes !== b.mistakes) return b.mistakes - a.mistakes;
  if (a.offered !== b.offered) return a.offered - b.offered;
  if (a.lastPractised === undefined && b.lastPractised !== undefined) return -1;
  if (a.lastPractised !== undefined && b.lastPractised === undefined) return 1;
  if (a.lastPractised !== undefined && b.lastPractised !== undefined && a.lastPractised !== b.lastPractised) return a.lastPractised - b.lastPractised;
  if (a.createdAt !== b.createdAt) return b.createdAt - a.createdAt;
  return compareCodePoints(a.id, b.id);
}

/** Which items the model practises next (VR-06), as Swift `VocabularySelection.select`; `pinned` comes first while it is a candidate. */
export function selectTargets(items: readonly VocabItem[], lang: Lang, usedInSession: ReadonlySet<string>, count: number, pinned?: string): VocabItem[] {
  const candidates = items.filter((i) => i.lang === lang && !usedInSession.has(i.id)).sort(before);
  const p = pinned === undefined ? -1 : candidates.findIndex((i) => i.id === pinned);
  if (p > 0) candidates.unshift(...candidates.splice(p, 1));
  return candidates.slice(0, Math.max(0, count));
}
