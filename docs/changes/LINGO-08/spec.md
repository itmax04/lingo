# LINGO-08: Specification — my vocabulary and prompting v2

ID: LINGO-08-spec · Status: **draft for AI review** · Version: 1 · Date: 2026-10-31 · Owner: itmax04 · Risk: R2
Links: [intent.md](intent.md) (decisions Q-01…Q-05, assumptions A-01…A-06) · [plan.md](plan.md) ·
[contracts](../../../packages/contracts/README.md) · [DESIGN.md](../../../DESIGN.md)
Requirements of this change are defined only here: VR (vocabulary), PR (prompting), VAC/PAC (acceptance). The iOS app is out of scope.

## 1. Vocabulary
- **VR-01. Item.** `id` (the ULID of its `vocab.added` event), `lang` (en | de), `text` (1–120 characters), optional `translation`
  (Russian, ≤ 160), optional `note` (≤ 300), optional `example` (≤ 200), `source` (manual | list | starred), `createdAt`.
  A ★ phrase (`phrase.starred`, R-28 of LINGO-01) is shown and selected as an item with `source = starred`; un-starring removes it.
- **VR-02. Events** (journal schema v1, additive; unknown types stay ignored by older readers):
  - `vocab.added` `{ item: { lang, text, translation?, note?, example?, source } }`, session `""`;
  - `vocab.updated` `{ item: <id>, text?, translation?, note?, example? }` — last writer wins by (`lamport`, `device`);
  - `vocab.removed` `{ item: <id> }` — a tombstone, last writer wins against `vocab.updated`;
  - `vocab.used` `{ item: <id>, by: learner | assistant, outcome: ok | mistake }`, session = the session where it happened.
- **VR-03. Adding.** One item at a time, or a pasted list: one item per line, split into text and translation by the first ` — `, ` – `,
  ` - `, `: ` or tab (A-01). Empty lines are skipped. An item whose normalised text (VR-07) already exists in that language is not added
  again; the result says how many were added and how many were duplicates.
- **VR-04. Editing and removing** an item: `vocab.updated` / `vocab.removed`; a removed item is no longer shown or selected.
- **VR-05. Statistics per item**, derived from `vocab.used`: offered (by assistant), used (by learner, ok), mistakes (by learner,
  mistake), last practised (the latest `vocab.used` time). Shown on each item.
- **VR-06. Selection** (deterministic, the same in Swift and TypeScript; golden fixture in `packages/contracts/fixtures/vocab/`):
  candidates are the items of the session language that are not removed; sort by (1) used ascending, (2) offered ascending,
  (3) last practised ascending (never practised first), (4) `createdAt` descending, (5) `id` ascending; skip an item the learner already
  used correctly in this session; take **3** (ordinary modes) or **6** (mode "My words"). Recomputed before every turn.
- **VR-07. Usage detection** (local, no model call; A-03): text is lower-cased, punctuation removed, whitespace collapsed (umlauts and ß
  kept). An item matches an utterance when its tokens appear in the same order with at most 2 other tokens between neighbours; a token
  matches equal text, or for tokens of ≥ 5 letters a common prefix of at least `max(5, length − 2)` letters (covers inflection such as
  "verabreden" → "verabredet"). After a turn: each target found in the learner's utterance gives `vocab.used by learner`, outcome
  `mistake` if an `@fix` of that turn contains the item, else `ok`; each target found in the assistant's `@say` lines gives
  `vocab.used by assistant`. At most one event per item, role and turn.
- **VR-08. Per-session switch** `useVocabulary` (on by default) in the new-session screen and the session menu. Off: no vocabulary block,
  no detection events for that session.
- **VR-09. Mode "My words"** (`words`): the conversation is built around the selected items (VR-06), see PR-03. Shown in the new-session
  screen with the other modes; available only when the language has at least one item.
- **VR-10. Translation help.** In the add form, "Translate" fills the translation with one `translate` request (the purpose of
  LINGO-03 H-1 findings); it never runs on its own.
- **VR-11. Mac screen "Vocabulary"** (the sidebar entry that today shows a "Coming soon" preview; layout from the LINGO-07 reference
  `mac-dictionary-overview`, tokens from DESIGN.md only): language filter, search, add field with "Add", "Paste a list", the list with text,
  translation, statistics, ★ marker for starred items, edit and remove. Russian and English UI strings.
- **VR-12. Contracts.** `event.schema.json` lists the new types and payloads and the new mode `words`; golden fixtures for the events and
  for the selection; README updated. The web (LINGO-03 Stage 2) implements the same rules from these files.

## 2. Prompting v2
- **PR-01. Learner profile** in the system part: the session level; goals and interests from `profile.updated` (free text, ≤ 300
  characters each, set in Settings; empty means "not stated"); up to 3 recurring mistakes in the session language: corrected forms that
  appear in `fix.recorded` at least twice in the last 30 days, most frequent first. The model uses them to create practice
  opportunities, never to lecture.
- **PR-02. Vocabulary block** — in the user message as data (`<vocabulary>` with `text | translation`), not in the system part, so the
  system prompt stays identical across the turns of a session (prompt cache). Rules: at most one target per turn; weave it naturally into
  what you say (use it in context or ask a question that invites the learner to use it); when the learner uses one, react briefly and
  naturally; a mistake with it follows the correction modes; never list the targets, never quiz in ordinary modes, never force an item
  that does not fit; a new question or subject from the learner comes first (rule 4b).
- **PR-03. Mode "My words".** Each turn practises one target: a short realistic situation or question that needs it, the learner uses it,
  then a brief natural reaction and the next target; vary the kind of task (situation, opinion, contrast with a similar word, personal
  example); explain meaning in the study language when asked; Russian only on an explicit request (rule 1).
- **PR-04. Conversation flow.** After a correction with a repeat request: if the learner repeats it correctly, acknowledge in a few words
  and move on — never ask to repeat the same phrase twice in a row; never repeat your previous question verbatim; build on what the
  learner just said; vary openings and reactions; keep one question per turn (rule 2).
- **PR-05. No empty turns.** When the last transcript line is the assistant's (no new learner turn), the task line asks for the next step
  of the current thread in one or two sentences — never a reply to the assistant's own words, never filler.
- **PR-06. Purposeful opening.** When the assistant starts, it greets in one short sentence and asks one concrete question that sets up the
  topic or, if there is no topic, an interest from the profile or a vocabulary target — not a generic "How are you today?".
- **PR-07. Misrecognition.** Rule 4a gets a concrete example taken from a real session ("Let's talk about maris" → meant "movies": answer
  about movies, add `@heard`, no `@fix`).
- **PR-08. Structure.** System part order: role and voice context → session → learner profile → rules (numbered, existing numbers kept,
  new ones 2a, 4c…) → output protocol → custom instructions. All text in English; language data in the study language.
- **PR-09. Budget.** The system part grows by at most 350 tokens over the current 21 snapshots; the measured median input of a dialog turn
  is recorded before and after (usage log).
- **PR-10. Evals.** New dialog categories with synthetic cases: `vocab_weave` ≥ 8, `vocab_mode` ≥ 6, `repeat_loop` ≥ 4, `opening` ≥ 4.
  Existing categories and thresholds unchanged.

## 3. Acceptance
| ID | Criterion | How |
|---|---|---|
| VAC-01 | Adding one item, a pasted list (separators, empty lines) and duplicates behave per VR-03 | unit tests |
| VAC-02 | Vocabulary events round-trip and merge per VR-02 (LWW, tombstone, two devices) | unit tests + contracts fixture |
| VAC-03 | Selection equals the golden fixture (VR-06), including "used in this session" | unit test reading `packages/contracts/fixtures/vocab/` |
| VAC-04 | Detection per VR-07: German and English inflection, gaps, no match on substrings or out-of-order words, mistake outcome | unit tests |
| VAC-05 | After a voice or text turn the statistics update (VR-05, VR-07) and the next selection moves on | DialogEngine / TurnController tests |
| VAC-06 | Vocabulary screen, per-session switch and mode "My words" work; RU and EN screenshots | UI snapshot + owner check |
| PAC-01 | The 21 prompt snapshots (+ the new mode) are re-recorded and the diff matches PR-01…PR-08 | snapshot tests + review |
| PAC-02 | Profile, recurring mistakes and the vocabulary block are built as specified (empty and full cases) | unit tests |
| PAC-03 | Night eval batch: each new category ≥ 90 %, `no_pronunciation` 100 %; a sample of existing categories does not drop below its threshold | `--eval-dialog` at night, within budget |
| PAC-04 | System part size and median dialog input before/after are recorded (PR-09) | snapshot sizes + usage log |
