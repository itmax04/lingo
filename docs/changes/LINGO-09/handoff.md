# LINGO-09 handoff: harsh tutor and conflict practice on the Mac

Status: documents v1 written on 2026-11-12, v1.1 (reply options) on 2026-11-13; accepted at H-09-0 on 2026-11-13. M-1a (#120) built on `feat/120-tone-data` (PR #141); M-11a (#139) built on `feat/139-reply-options-data` (cut from it); next M-11b (#140).

## Identity
- Change: LINGO-09 (completion plan row B). Risk: R2. Milestone: "LINGO-09 · Modes".
- Branch `docs/lingo-09-documents` from `origin/main` `5144f77`. One docs PR; see "Done".

## Goal and scope
Two levels on any session (tutor harshness 0–5, character hostility 0–5), a profanity switch and presets; conflict scenarios; local
drills, pressure and help; live control, Calm and a debrief; a personal experiment. See [intent.md](intent.md).

Hard constraints: $0; no pronunciation assessment (AGENTS.md §6.7); MR-06 limits; additive data; level 0/0 is byte-identical to today.

## Source of the owner's decisions
B-01…B-18 come from the brainstorm of 2026-11-01. They were kept outside the repository (the executor's notes and an audit file in the
owner's Downloads folder, which no longer exists there). On 2026-11-12 they were recovered from the stored session of that brainstorm
and copied into [intent.md](intent.md) without change. The owner's concept papers (two PDF files) are not in the repository.

## Done
| Step | PR | Checks | Notes |
|---|---|---|---|
| Documents v1 | see the PR of branch `docs/lingo-09-documents` | `check-english`, `secret-scan`; independent AI review recorded in the PR | intent, spec (MR-01…MR-48, MAC-01…MAC-29), plan (M-1a…M-10, X-1…X-3, H-09-1…H-09-3) |
| Documents v1.1: reply options | same PR | `check-english`, `secret-scan`; independent AI review recorded below | owner decision B-19 (2026-11-13); spec §4a MR-49…MR-54, MAC-30…MAC-33; steps M-11a (#139) and M-11b (#140) after M-1a; proposal O-7 |

## Executor decisions
- D-01: O-1 — remarks on accent or pronunciation are not built, although B-03 allowed them; AGENTS.md §6.7 wins. Open for the owner.
- D-02: The model check (M-2) runs before any step after the prompt, so that a model that refuses the role is found early.
- D-03: Help in three steps comes with every reply of a tone session (`@help` plus `@hint`), so that help and silence cost no request.
- D-04: The follow-up question travels with the correcting reply (`@next`), so that a passed repeat costs no request.
- D-05: The blame filter covers tutor speech only; a hostile character may say that the learner is wrong about the matter.
- D-06: The FSRS grading of the warm-up is not changed; independence is recorded (`help.revealed`) and used by the debrief and the experiment.
- D-07: The experiment is part of this change as steps X-1…X-3 after H-09-1; acceptance does not wait for its 21 days (A-07).
- D-08: Reply options come in the same reply as a silent `@reply` tag, so a turn costs no extra request; only refresh is a request.
  They sit under the latest assistant message, open from the first words and are never sent automatically (O-7).
- D-09: Reply options are hidden in tone sessions, so the learner never sees two help mechanisms at once; Help (MR-22) serves there.

## Open
- H-09-0: accepted by the owner on 2026-11-13 in chat (executor session): documents v1.1 and O-1…O-7 exactly as proposed in [intent.md](intent.md). Recorded here because the docs branch is checked out in another worktree; the owner merges PR #119 (this branch is cut from it).
- The owner's two concept papers could be added to `design/` if the owner wants them kept with the project.

## Done: M-1a (#120)
`Tone` and `SessionSettings.tone` (tolerant decoding, dropped at level 0), presets, the `local` mark of `message.created` / `ChatMessage`, silent tags `@next` and `@help`, `@tutor` as a `say` segment (parsing only, no caller yet), schema, fixtures (`events/tone-settings.json`, four cases in `protocol/replies.json`), TypeScript decoders. No prompt, request or UI change; no prompt snapshot touched (MAC-01).
- D-10: `@tutor` with an empty body is a violation and produces no segment, like `@say`. `local` is false when missing; nothing sets it yet (M-3a drill lines will).
- Check note: `swift test` ends with exit 1 after all 448 tests pass: `GGML_ASSERT([rsets->data count] == 0)` in ggml-metal while the process exits (whisper teardown). Not caused by this change; not compared against `main`.

## M-1a delivery state (2026-11-13)
- Branch `feat/120-tone-data`, commit a647018 on top of 9dc3705 (docs v1.1). Not pushed, PR not opened.
- Verified at a647018: swift build PASS; swift test 448 passed (exit 1 from the ggml-metal exit assert); check-core-ios PASS; npm test 327 passed; check-english PASS; secret-scan 0 findings.
- Independent review (sdlc:reviewer): approve-with-notes, no P0/P1. F2 (range check in `normalized`) fixed. Left open: F1 `local` has no merger-state test in Swift/TS (add in M-3a, the first step that sets it); F3 `decodeTone` not exported (only if needed); F4 `@tutor` is accepted in any session by the parser — the caller must gate it to combined sessions (MR-13) in the prompt/engine step.

## Done: M-11a (#139)
Branch `feat/139-reply-options-data`, cut from `feat/120-tone-data` (PR #141, not merged at the time): retarget the PR to `main` after #141 merges.
- `@reply` is a silent tag (Swift `ReplyProtocol.silentTags`, TS `SILENT_TAGS`): never spoken, never a segment, never a violation. `ReplyOptions.parse` / `parseReplyOptions` read the raw text: language (missing or unknown = study language), phrase, translation; lines without `|` or with an empty phrase are skipped, an empty translation is kept, at most three kept (MR-50). Shared fixture `protocol/reply-options.json` (11 cases).
- Switch: `AppSettings.replyOptions` (device-local, tolerant, off by default). `ReplyOptions.isOffered(settings, ended:)`: ordinary and scenario sessions only; hidden in tone, warm-up, exam (incl. Goethe training) and ended sessions (MR-49). Trial sessions join the hidden list in X-2 (MAC-25).
- Prompt: `PromptBuilder.system(…, replyOptions:)` and `dialogRequest(…, replyOptions:)` add one protocol line (`@reply <lang>: … | <Russian> (2–3 lines, different, their level, not an @hint, not spoken)`), 131 characters ≈ 37 estimated tokens (≤ 40, MAC-30). With the switch off or hidden the text is identical to today's (tested; the 30 existing snapshots are untouched). New snapshot `prompt-free-inline-replyoptions.txt`.
- `DialogEngine.setReplyOptions(_:)` carries the switch into the request; nothing calls it yet (M-11b adds the control and the block).
- `LLMPurpose.replyOptions` (MR-53, the refresh request itself is M-11b) with a usage label and Russian string.
- `reply.revealed` `{message, index}`: `EventType`, `Payload.ReplyRevealed`, merger (no state, malformed = unknown), schema, TS decoder, journal fixture `events/reply-revealed.jsonl`.
- D-11: `@reply` is parsed only from the raw reply text (like `@next`), so an older build that never asks for it and reads stored segments is unaffected (MR-45); no segment is stored for it.
- D-12: an empty translation after `|` is kept (the spec skips only a missing separator or empty phrase); the UI of M-11b decides how to show it.
- Independent review (sdlc:reviewer, Sonnet, 0d699e0): approve-with-notes, no P0/P1. F1 (P3): `DialogEngine.setReplyOptions` has no caller — M-11b must wire `AppSettings.replyOptions` to it at engine start and on every settings change. F2, F3: no change needed.
- Not done here by design: DESIGN.md §5 entry, interface, refresh request, token evidence (M-11b).

## Done: M-11b (#140)
- Block under the anchor (`ReplyOptionsBlock`, `ReplyOptions.anchor`/`firstWords`), chip "Reply options" in the voice panel, menu Conversation → Reply options ⌘⇧R, collapse remembered (`AppSettings.replyOptionsCollapsed`).
- Reveal, Show all, ▶ (Slow included, mic paused), ★, Insert; `reply.revealed` written per reveal; refresh (`DialogEngine.refreshReplyOptions`, purpose `replyOptions`, not journaled, ≤ 2 per anchor, disabled offline/no key/while a turn runs, error text with symbol).
- F1 of the M-11a review closed: `updateSettings` and `start()` push the switch into `DialogEngine.setReplyOptions`.
- DESIGN.md §5 entry; screenshots (English, both themes) and `evidence/reply-options.md`.
- Tests: swift 472 passed (known ggml exit signal after the run), npm 342, check-design/english/secret-scan/check-core-ios PASS.
- NOT RUN / open: Russian screenshots (debug build has no String Catalog) and the MR-54 token measurement (needs the signed app and real keys); both are in `evidence/reply-options.md`. The owner's rebuild must record them.

## Done: M-3a (#121)
Branch `feat/121-local-lines`, cut from `feat/140-reply-options-ui` (PRs #141, #142, #143 not merged at the time; retarget after they merge).
- `ToneLines` (`Sources/LingoCore/Teacher/ToneLines.swift`): kinds pressure, again, pass, moveOn, calm, neutral, interjection; de and en; bands L1–L5 (L1 only neutral and calm); 4 lines per cell (240 plain lines). Profane variants are a separate table, band 5 only, for pressure, again, pass, moveOn, interjection (4 per kind and language); `lines(…, profane:)` is the only way to read them. `ToneLinePicker` never returns the same line twice in a row per language and kind; levels are clamped to 1…5.
- Export `packages/contracts/teacher/tone-lines.json` written by `ToneLinesTests` (`LINGO_RECORD_FIXTURES=1`); deny-list `packages/contracts/fixtures/teacher/tone-deny-list.json` (violence, protected traits, sexual content, self-harm, pronunciation; whole words, `*` = stem).
- F1 of the M-1a review closed: `theLocalMarkSurvivesTheMerger` (Swift). The TypeScript decoders do not expose `local` yet, so no TS test.
- D-13: nothing speaks these lines yet; the callers are M-1b (neutral), M-3b (drill: pass/again/moveOn), M-4 (pressure, calm, interjection). The catalogue has no pronunciation remark at any band (MR-47), checked by the deny-list.
- Verified: swift test 479 passed (known ggml exit signal 6 after the run), check-core-ios, check-english, secret-scan (0). npm test not run: no TypeScript change.
- Independent review of the texts (sdlc:reviewer, Sonnet): approve-with-notes, no P0/P1. Fixed: F1/F2 deny-list extended (separable verbs, slurs, indirect pronunciation cues), F3 matcher tests, F4 new `profanity` category applied to plain lines only, F6 three clumsy lines reworded, L4 "again" lines no longer say "correctly". Left: F5 (calm lines repeat across bands; harmless).

## Done: M-1b (#122)
Branch `feat/122-tone-prompt`, cut from `feat/121-local-lines` (PRs #141…#144 not merged at the time; retarget after they merge).
- `TonePrompt` (`Dialogue/TonePrompt.swift`): effective tone (nil for warm-up, exams and Goethe training, MR-02), MR-05 sentences, the `# Tone` block (only the chosen levels, `Swearing: yes|no`, the MR-06 limits), intro line, role line, rule 6 wording for harshness ≥ 2, rule `6a` (judge first), protocol lines `@next`, `@help`, `@tutor` and the judge-first example. `PromptBuilder.system` calls it only when a tone is active; no existing snapshot changed (MR-07).
- `BlameFilter` and `BlameGate` (`Dialogue/BlameFilter.swift`, MR-15): markers per language (exported to `fixtures/teacher/blame-markers.json`), sentence filter on the raw reply, neutral local line when no tutor speech is left; the streaming gate holds spoken sentences until the first `@fix` or the end. `DialogEngine` wires both and writes `tone.filtered {message, removed}` (new event: Swift, TypeScript, schema, fixture `events/tone-filtered.jsonl`).
- Snapshots `prompt-tone-{strict,conflict,combined,max}-{de,en}.txt`; eval cases `evals/dialog/08-tone.yaml` (26 cases for M-2; new rules `no_blame_without_fix`, `has_help`, `judge_first`; case field `session.tone`).
- Tests: `TonePromptTests` (MAC-03, MAC-05), `BlameFilterTests` (MAC-07: 23 golden cases, gate, engine turns, fixture). Swift 502 passed (known ggml exit signal 6 after the run), npm 345, check-design, check-english, secret-scan (0), check-core-ios PASS.
- D-14: in a session with harshness ≥ 1 the gate holds **all** spoken sentences (the character's too) until the first `@fix` or the end, so the order of the two voices never changes; the spec holds only tutor lines. Judge-first puts the `@fix` first, so the hold is normally empty. M-2 measures the delay.
- D-15: MR-08 measured over every mode × correction set × level pair × profanity: the block is ≤ 170 estimated tokens and the whole tone addition is ≤ 170 (worst 166 after the review fixes, German questions inline 3/4; block 120; measured over both languages, with and without a scenario, reply options off and on). To stay inside it the limits are compact (no "dodging a refusal": that MR-06 item binds the app, which never retries with a rephrased prompt, MR-36), one `Swearing:` line carries the switch, the protocol footer "not spoken" is unchanged (the parser, not the footer, keeps `@next` and `@help` silent), rule 6a is "@fix lines first; blame only what they record." and the intro says "…practising spoken German who chose harsh practice." Rule 7 is untouched; the block does not mention `<session_prompt>`, because the block is the app's own text and rule 7 already makes the session prompt data (tested: two custom prompts give the same block).
- D-16: Russian lines (explanations on request) are never filtered; markers are whole words with a few stems (`falsch*`, `mistake*`); `Fehlerfrei` and `wrongly` are not blame.
- D-17: the filter acts on tutor speech only: harshness only → every study-language `@say` or untagged line; combined → `@tutor` lines; hostility only or no tone → nothing.
- Tier: the plan row says strong (safety limits), the previous handoff said standard; built on Sonnet 5.5, with the independent review on a stronger model (verdict below).
- Independent review (sdlc:reviewer, Opus, 28bbaa9): changes-required, one P1. Fixed in 4ba0821 and the following commit:
  - F1 (P1) while the gate holds, streamed partials hide tutor speech (`BlameFilter.heldPartial`); a reply held to the end is shown once more from the filtered text before `.finished`. Test `partialsNeverShowRemovedBlame` (harshness only and combined).
  - F2 (P2) `Swearing: yes` only when a level of 5 names it; 3/0 and 0/3 with profanity give `no` (`swearingNeedsTheLevelThatNamesIt`).
  - F3 (P2) the limits hold every MR-06 item the model can act on again (contempt, ethnic origin, urging self-harm, empty or unintelligible transcript); tokens found in the intro, rule 6a, the `@help`/`@tutor` lines and rule 6 for tone ("then continue" dropped: the drill and `@next` continue). Test lists every item.
  - F4 (P2) the combined example is `@fix` → `@tutor` (correction) → `@say` (character).
  - F5 (P2) eval `no_blame_without_fix` reads every study-language spoken line whatever the axes (hostility-only cases now measure the character).
  - F6 (P3) `no_blame_without_fix`, `has_help`, `judge_first` are in `DialogRules.all` (the report lists them) and in the evals README.
  - F7 (P3) `BlameFilter.hasFix` counts a fix only when `parseLine` reads a `.fix` (the gate's test); golden cases for a fix without a colon and inside `<think>`.
  - F8 (P3) German compound markers (`*fehler`, `*fehlern`) and "stimmt so nicht"; golden cases for blame in `<think>` and a `- @say` line.
  - F9 (P3) the budget test covers both languages, scenario and reply-options sessions; headroom above (D-15).
  - F10 (P3) open: the owner confirms D-16 (Russian lines unfiltered) at H-09.
  - Left open for M-2: a model that invents an `@fix` on a correct turn passes `no_blame_without_fix` (consider a `no_fix` rule for `tone_correct`); `fehler`/`mistake*` also match praise ("No mistakes"); the tone example has no `@help` (watch `has_help`). Not checked: barge-in offsets with a filtered reply; other views that render the raw `message.text` (copy, export).
- NOT RUN: any live model call (M-2, at night only); the TypeScript side has no prompt builder or filter yet (web paused), so only the event is mirrored.

## Next step
Step M-2 (plan order … M-1b → M-2 → M-3b …). Tier: standard. Start: "Continue LINGO-09 with M-2 from docs/changes/LINGO-09/handoff.md", branch from `feat/122-tone-prompt` until the earlier PRs merge. M-2 needs the signed app with real keys and runs only at night (23:00–08:00 Europe/Berlin, at most 40 requests, with the models and budget options of the dialogue eval, on `packages/contracts/evals/dialog/08-tone.yaml`); it records `evidence/model-check.md` and decides under MR-36.
