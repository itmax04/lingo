# LINGO-08: Intent — my vocabulary, used by the model, and prompting v2

ID: LINGO-08-intent · Status: **accepted** (owner brainstorm 2026-10-31) · Version: 1 · Date: 2026-10-31 · Owner: itmax04 · Risk: **R2**
Links: [spec.md](spec.md) · [plan.md](plan.md) · prior: [LINGO-03](../LINGO-03/intent.md) (Stage 0 accepted at H-1), [LINGO-07](../LINGO-07-redesign/intent.md)

## Problem
The learner cannot bring their own material. Words, phrases and expressions they want to learn live outside Lingo, and the model never
practises them. The only personal store is the ★ list of hint phrases, and the model does not see it. The prompting has no memory across
sessions (no goals, no recurring mistakes), repeats "please say it again" after a correct repetition, sometimes "corrects" misrecognised
words, answers an empty "continue" with filler, and opens a free session with a generic greeting.

## Desired outcome
1. **My vocabulary.** The learner adds their own words, phrases and expressions (one by one or a pasted list, with an optional translation
   and note), per study language; the ★ phrases are part of the same list. Each item shows how often it was practised.
2. **The model uses it.** In every session (unless switched off for that session) the model weaves a few of the learner's items into the
   conversation naturally, invites the learner to use them, and notices when they do. A dedicated session mode, "My words", builds the
   whole conversation around the list. Items the learner has not used yet, or rarely, come first.
3. **Prompting v2.** One clear system wrapper with a learner profile (level, goals, interests, recurring mistakes across sessions), the
   vocabulary block, tighter conversation-flow rules (no repeat loops, no filler, follow the learner's lead, a purposeful opening), and the
   existing rules kept. Measured by eval sets, not by impression.
4. **Same experience on the web later.** Vocabulary events, the selection rule and the prompt text are contracts in `packages/contracts`,
   so Lingo Web (LINGO-03 Stage 2) reuses them unchanged.

## Scope
- In: Lingo for Mac; `packages/contracts` (event types, payloads, golden fixtures, prompt snapshots, eval sets); docs.
- Out: the iOS app (no change in this change, owner decision Q-03); building Lingo Web or the Engine (stays LINGO-03 Stage 2);
  spaced repetition / FSRS (stays LINGO-05, owner decision Q-02); paid services.

## Owner decisions (brainstorm 2026-10-31)
| ID | Question | Owner's answer (translated from Russian) | Effect |
|---|---|---|---|
| Q-01 | How to keep the web consistent while it does not exist yet? | "Mac + shared contracts" | Mac implementation; formats, selection and prompts in `packages/contracts` |
| Q-02 | How to track that an item is learned? | "Simple tracking" | Counters per item (offered by the model, used by the learner, mistakes); FSRS stays in LINGO-05 |
| Q-03 | How should the model use the items? | "Everywhere + a separate mode" | Woven into every session (per-session switch, on by default) and a new mode "My words" |
| Q-04 | Stage 0 (H-1) is not accepted yet | "Accept H-1 now" | H-1 recorded as accepted 2026-10-31 without the 30-minute live session, backup walk-through and RU/EN check |
| Q-05 | Platforms of this stage | "macOS and the web version only; no iOS changes" (the stage brief) | iOS untouched |

## Assumptions (executor, R2: recorded, not blocking)
- A-01: An item has a language (en/de), a text, an optional Russian translation, an optional note and an optional example; adding a pasted
  list splits it by lines and by the first " — ", " - ", "–", ":" or tab into text and translation.
- A-02: The ★ phrases (`phrase.starred`) are shown in the same list and selected for practice like the learner's own items; no migration.
- A-03: "Used by the learner" is detected locally after each turn (normalised text match of the item in the learner's utterance); a turn
  with an `@fix` on that phrase counts as a mistake. No model call is spent on detection.
- A-04: 3 items per ordinary session and up to 6 in "My words"; the selection is deterministic so the web gives the same result.
- A-05: The learner profile (goals, interests) is stored in the journal (`profile.updated`) so that it syncs with the web later.
- A-06: The new mode `words` and the new event types are additive; an older Lingo build reading a newer journal ignores unknown types,
  but a session in the new mode needs this build or later (only one device today).

## Definition of done
All VAC/PAC criteria of [spec.md](spec.md) have evidence (PASS, or NOT RUN with a reason); `swift test`, `check-design`, `check-english`,
`secret-scan` pass; an independent AI review has no open P0/P1 on each PR; the night eval batch for the new categories is run within the
quota rules (23:00–08:00 Berlin) and its result is recorded. No owner gate is required for R2 beyond the brainstorm (profile rule).
