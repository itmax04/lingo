# LINGO-08: Specification — my vocabulary and prompting v2

ID: LINGO-08-spec · Status: **draft for AI review** · Version: 2.1 (reviews: F-01…F-19, N-01…N-12) · Date: 2026-10-31 · Owner: itmax04 · Risk: R2
Links: [intent.md](intent.md) (decisions Q-01…Q-05, assumptions A-01…A-06) · [plan.md](plan.md) · [handoff.md](handoff.md) ·
[contracts](../../../packages/contracts/README.md) · [DESIGN.md](../../../DESIGN.md)
Requirements of this change are defined only here: VR (vocabulary), PR (prompting), VAC/PAC (acceptance). The iOS app is out of scope.
**Amends:** LINGO-01 R-03 (a vocabulary focus for the "Questions" mode), R-04 (a vocabulary block in the request), R-25 (new rules and
data tags), R-28 (★ phrases become vocabulary items); LINGO-03 MR-02 (P-1 carries out its open prompt compaction, plan step P-02b).
Item texts, translations, goals and interests are learner data: they are never written to logs (AGENTS.md §6) and never to the usage log.

## 1. Vocabulary
- **VR-01. Item.** `id` (the ULID of its `vocab.added` event), `lang` (en | de), `text` (1–120 characters), optional `translation`
  (Russian, ≤ 160), optional `note` (≤ 300), optional `example` (≤ 200), `source` (manual | list | starred), `createdAt`.
- **VR-01a. ★ phrases as items** (amends R-28). A ★ phrase (`phrase.starred`) is an item with id `star:<lang>:<normalised text>`
  (normalisation of VR-07a), `source = starred`, `createdAt` = its latest `phrase.starred` time. It cannot be edited; removing it un-stars it.
  If an own item has the same language and normalised text, only the own item is shown and used.
- **VR-02. Events** (journal schema v1, additive; older readers store and ignore unknown types):
  - `vocab.added` `{ item: { lang, text, translation?, note?, example?, source } }`, session `""`;
  - `vocab.updated` `{ item, text?, translation?, note?, example? }` — each present field last-writer-wins by (`lamport`, `device`);
  - `vocab.removed` `{ item }` — final: it removes every `vocab.added` with the same key (VR-07a) whose version (`lamport`, `device`,
    `id`) is below the removal's, and their later updates and uses are dropped; an add with a higher version (the learner adds the text
    again) is a new item;
  - `vocab.used` `{ item, message, by: learner | assistant, outcome: ok | mistake }`, session = where it happened, `message` = the id of
    the learner's message (by learner) or of the assistant's reply (by assistant). The reducer counts one event per (item, by, message);
    when such events disagree, `mistake` wins (a later "Reply again" with an `@fix` turns an `ok` into a mistake);
  - `profile.updated` `{ goals?, interests? }`, session `""`, each present field last-writer-wins.
  - Two live items with the same language and normalised text at add time (added on two devices) are one item: the earliest live
    `vocab.added` (by ts, device, seq, id) is kept, and the events of the other id count for it. An edited item keeps its add-time text
    as well, so adding that text again is reported as a duplicate (VR-03).
- **VR-03. Adding.** One item at a time, or a pasted list of at most 200 lines for the language chosen in the form (with the filter on "All",
  the form asks for the language). Per line: leading bullets and numbering (`-`, `•`, `*`, `1.`, `1)`) followed by a space are removed (`-5 Grad`, `1.5 kg` stay); the line is split at the
  first of ` — `, ` – `, ` - `, a tab or `: ` by position into text and translation; if the left side is Cyrillic and the right side is not,
  the sides are swapped; empty lines are skipped; a text over 120 characters is not added and is reported (also for a single item; an edit to over 120 characters is refused). An item whose key (VR-07a)
  already exists in that language (as the current text or the add-time text of an item) is not added again. The result reports added, duplicates and rejected.
- **VR-04. Editing and removing** own items: `vocab.updated` / `vocab.removed`; ★ items: VR-01a.
- **VR-05. Statistics per item**, derived from `vocab.used`: offered (by assistant), used (by learner, ok), mistakes (by learner, mistake),
  last practised. Shown on each item.
- **VR-06. Targets** (deterministic, the same in Swift and TypeScript; golden fixture `packages/contracts/fixtures/vocab/selection.json`).
  The statistics used for a session are those **before this session** (its own `vocab.used` events are left out), so the targets stay the
  same during a session. Candidates: items of the session language, minus the items the learner used correctly in this session. Sort by
  (1) used ascending, (2) mistakes descending, (3) offered ascending, (4) last practised ascending (never practised first),
  (5) `createdAt` descending, (6) `id` ascending (ULIDs are ASCII: byte order). Take **3**, or **6** with the vocabulary focus (VR-09).
  An optional **pinned** item (the "Practise" button, VR-11) comes first while it is a candidate.
- **VR-07. Usage detection** (local, no model call; A-03) after each turn, against **all** items of the session language (not only the
  targets): each item found in the learner's utterance gives `vocab.used by learner`, each item found in the assistant's `@say` lines
  gives `vocab.used by assistant`. Not counted: command utterances (R-14…R-22), Russian utterances, and turns whose reply failed for the
  assistant side (the learner side is still written). **Outcome:** `mistake` when an `@fix` of that turn has an `original` that contains
  the item and a `corrected` whose matched span differs (or does not contain the item); otherwise `ok`.
- **VR-07a. Text rules** (golden fixture `fixtures/vocab/text.json`): normalise = lower case; apostrophes (' ’ `) removed; every other
  character that is not a letter or digit becomes a space; spaces collapsed; umlauts and ß kept. Key = `<lang>:<normalised text>`.
- **VR-07b. Matching** (golden fixture `fixtures/vocab/matching.json`, with the known misses listed as accepted):
  - placeholders are dropped from the item before matching: de `sich jdm jdn jemandem jemanden etw etwas`, en `to` (leading),
    `sb sth someone something somebody ones oneself`;
  - a token matches a word if the word equals it, or equals its stem plus an allowed ending, where the stem drops the item token's own
    ending (de, tokens of at least 5 letters: `en`, else `n` or `e`; en, tokens of more than 3 letters: `e`) and the endings are
    de `e en n st t et est te ten tet er es em s ens` and en `s es ed ing er`;
    when an English `e` was dropped only `e es ed er ing` follow (so `care` ≠ `cars`);
    tokens of 3 letters or fewer must be equal; a German word of at least 6 letters starting with `ge` may drop it (participles: `kaufen` → `gekauft`);
  - German separable verbs: an item token `<prefix><verb>` (prefixes `ab an auf aus bei durch ein fest her hin los mit nach um vor vorbei
    weg weiter zu zurück zusammen`) also matches the verb part plus the separate prefix at most 10 words later in the same utterance (`anrufen` → `ich rufe
    dich morgen an`), the participle `<prefix>ge<verb form>` (`angerufen`, `eingekauft`) and the zu-infinitive `<prefix>zu<verb>` (`anzurufen`);
  - multi-token items: all tokens found in order with at most 3 other words between neighbours (any order for German);
  - accepted misses: vowel changes (`fahren` → `fährt`, `give` → `gave`), plurals with umlaut, irregular forms, English consonant
    doubling (`stop` → `stopped`) and y → i (`study` → `studied`); a German window start whose search exceeds 2 000 steps (a step is one
    utterance position tried for one item token; an item that repeats a word against a long reply); the learner can add the form they want to practise.
- **VR-07c. Recognition hint.** The session's targets are put first into the speech-recognition context (at most 30 words of it), so
  that rare own words are heard correctly.
- **VR-08. Per-session switch** `useVocabulary`, an optional field of `SessionSettings` (missing = on; old sessions decode unchanged),
  in the new-session screen and the session menu. Off: no vocabulary block, no `vocab.used` events for that session.
- **VR-09. "My words"** is the "Questions" mode with the optional field `vocabularyFocus = true` (no new mode value: older builds still
  read the session as "Questions"; an older build that edits such a session drops the two optional fields — accepted, one device today).
  Its default title is "My words: <topic>". It forces `useVocabulary` on, takes 6 targets and follows PR-03. Offered in the new-session screen as a
  separate choice "My words", only when the language has at least one item.
- **VR-10. Translation help.** In the add form, "Translate" fills the translation with one `translate` request; never automatic.
- **VR-11. Mac screen "Vocabulary"** (the sidebar entry that today shows "Coming soon"; layout from
  `design/redesign-2026/04-mac/mac-dictionary-starred-*-1536x1024.png`, tokens from DESIGN.md only): language filter German | English | All;
  search; add field with "Add", "Paste a list", "Translate"; one card per item with text, translation, statistics, ▶ listen (R-27),
  ★ marker for ★ items, edit and remove; the card button "Practise" starts a "My words" session in the item's language with this item as
  the first target; empty state with a short hint. Russian and English UI strings.
- **VR-12. Contracts.** `event.schema.json` lists the new types, payloads and the optional `SessionSettings` fields; golden fixtures for
  text rules, list parsing, matching, selection and events; README. The web implements the same rules from these files.

## 2. Prompting v2
- **PR-01. Learner profile** in a `<profile>` block of the system part, computed **once per session** from the journal as it was before
  the session started (so the system part stays identical during the session and can be cached): the session level; goals and interests
  (`profile.updated`, free text of at most 300 characters each, set in Settings; empty means "not stated"); up to 3 recurring mistakes in the session language — `fix.recorded`
  of non-deleted sessions in that language in the last 30 days, grouped by the normalised rule text (VR-07a), at least 2 occurrences, most
  frequent first, each shown as the rule with one short example `original → corrected` (at most 80 characters). Grouping by the
  rule text is best-effort (the model writes the rule); PAC-02 records how often a real journal yields at least one. The model uses them to create practice
  opportunities, never to lecture.
- **PR-02. Vocabulary block** — after `</transcript>` in the user message (the summary and transcript prefix stays cacheable), as
  `<vocabulary>` lines `text | translation | status`, where status is `new`, `practising` (used n times) or `needs work` (mistakes > used);
  at most 120 tokens: each text and translation is cut to 60 characters, then targets are dropped from the end until the block is at most
  420 characters (golden fixture `fixtures/vocab/block.json`). The rules about it are always in the system part when `useVocabulary` is on: at most one target per turn; weave it
  naturally into what you say (use it in context or ask a question that invites the learner to use it); prefer `new` and `needs work`;
  when the learner uses one, react briefly and naturally; a mistake with it follows the correction modes; never list the targets, never quiz
  in ordinary modes, never force an item that does not fit; a new question or subject from the learner comes first (rule 4b).
- **PR-03. Vocabulary focus ("My words").** Each turn practises one target: a short realistic situation or question that needs it, the
  learner uses it, a brief natural reaction, then the next target; vary the kind of task (situation, opinion, contrast with a similar word,
  personal example from the profile); explain meaning in the study language when asked; Russian only on an explicit request (rule 1).
- **PR-04. Conversation flow.** After a correction with a repeat request: if the learner repeats it correctly, acknowledge in a few words and
  move on — never ask to repeat the same phrase twice in a row; never repeat your previous question verbatim; build on what the learner just
  said; vary openings and reactions; one question per turn (rule 2).
- **PR-05. No filler.** (a) The `continue` command gets its own task line: the next step of the current thread (a new question or the next
  part of the topic), never a reply to the assistant's own last words and never filler. (b) When the last transcript line is the assistant's,
  the same task line is used.
- **PR-06. Purposeful opening.** When the assistant starts, it greets in one short sentence and asks one concrete question that sets up the
  topic, or without a topic an interest from the profile or a vocabulary target — not a generic "How are you today?".
- **PR-07. Misrecognition.** Rule 4a gets a concrete synthetic example ("Let's talk about maris" when the topic is films → the learner meant
  "movies": answer about movies, add `@heard`, no `@fix`).
- **PR-08. Structure and safety.** System part order: role and voice context → session → `<profile>` → rules (numbered; existing numbers
  kept, new ones 2a, 4c, …) → output protocol → custom instructions. Rule 7 treats `<profile>` and `<vocabulary>` as data too; closing tags
  are stripped from learner text, as for the transcript. All text in English; language data in the study language.
- **PR-09. Budget** (with MR-02): P-1 carries out the open prompt compaction of LINGO-03 (P-02b). Target: the system part ≤ 900 tokens of
  instructions as reported by the provider's `prompt_tokens` for a request with an empty transcript, a maximal profile and no custom prompt (the local `TokenEstimate` is only a
  guide); the vocabulary block ≤ 120 tokens. If the night evals show that 900 tokens cannot hold the rules' effect, the executor stops and
  asks the owner with the numbers. The usage log records input, cached and output tokens before and after (PAC-04).
- **PR-10. Evals** (`packages/contracts/evals`): the case format gets optional `vocabulary` (items with status), `profile` and an optional
  `user` (empty = the assistant starts); new automatic rules `uses_target` (a target appears in the reply, by the VR-07b matching), `no_target_list` (at most one
  target per reply), `no_repeat_request` (no request to repeat when the learner's last turn repeated the corrected phrase),
  `concrete_opening` (the opening has one question and none of the generic greetings listed in the README), `no_filler`. New categories:
  `vocab_weave` ≥ 8, `vocab_focus` ≥ 6, `repeat_loop` ≥ 4, `opening` ≥ 4, `continue_thread` ≥ 4, `data_injection` ≥ 2 (instructions hidden in
  an item or in the goals). Regression sample: 2 cases per existing category (ids listed in the README), thresholds unchanged.

## 3. Acceptance
| ID | Criterion | How |
|---|---|---|
| VAC-01 | Adding one item and a pasted list (bullets, separators, swap, empty and too-long lines, 200-line limit) and duplicates behave per VR-03 | unit tests + `fixtures/vocab/text.json` |
| VAC-02 | Events round-trip and merge per VR-02: per-field LWW, final removal, same text from two devices is one item, de-duplication per (item, by, message), profile | unit tests + `fixtures/vocab/events.jsonl` |
| VAC-03 | Targets equal the golden fixture (VR-06), including "statistics before this session" and "used in this session" | unit test |
| VAC-04 | Matching per VR-07b on the golden cases, including separable verbs, participles, placeholders, endings and the negative cases (`stand` ≠ `standard`) | unit test |
| VAC-05 | After a voice or text turn: learner and assistant use, the mistake outcome, no events for commands and Russian utterances, targets stay stable within a session and move on after use | DialogEngine / TurnController tests |
| VAC-06 | Old journals (`sample-journal.jsonl`, `merge-two-devices`) give the same state as before | unit test |
| VAC-07 | Vocabulary screen, per-session switch and "My words" work; RU and EN screenshots (the owner may look; no gate) | UI snapshot |
| PAC-01 | Prompt snapshots re-recorded; the diff matches PR-01…PR-08 | snapshot tests + review |
| PAC-02 | Profile (frozen per session), recurring mistakes and the vocabulary block are built as specified (empty and full cases, injection stripped) | unit tests |
| PAC-03 | Night eval batch: each new category ≥ 90 %, `no_pronunciation` 100 %, the regression sample at or above its thresholds | `--eval-dialog` at night, within budget |
| PAC-04 | Provider-reported system tokens (empty transcript) and median input / cached / output tokens of a dialog turn, before and after | usage log |
