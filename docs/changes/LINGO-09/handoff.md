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
- Not done here by design: DESIGN.md §5 entry, interface, refresh request, token evidence (M-11b).

## Next step
Step M-11b (#140): reply options interface (block under the anchor, first words and reveal, ▶ ★ Insert, refresh, `reply.revealed` written, DESIGN.md §5, screenshots, token evidence; MR-51…MR-54). Tier: standard. Start: "Continue LINGO-09 with M-11b (#140) from
docs/changes/LINGO-09/handoff.md", branch from `feat/139-reply-options-data` until it is merged.

## Review of 2026-11-12 (sdlc:reviewer, Opus, commit 0bd3b37)
Verdict changes-required: P1 F1 (token budget made relative), F2 (help and calm detected only in tone sessions); P2 F3–F11 and P3 F12–F16 fixed in the follow-up commit (step order M-1a → M-3a → M-1b, buffering rule, local messages out of the context window, experiment arms differ only in tone, new events, risk row and O-6). Milestone and issues #120–#138 created; stop at H-09-0 (#135).

## Review of 2026-11-13, v1.1 reply options (sdlc:reviewer, Sonnet, uncommitted diff on 9be612b)
Verdict approve-with-notes: no P0/P1. P2 F1–F8 fixed in the same commit: the anchor message and ended sessions (MR-49, MR-51), the
block's life around a turn and a failed turn, ▶ without the microphone, prompt and completion tokens with two refreshes per anchor and a
100-token threshold, the trial check moved to MAC-25, M-11 split into M-11a and M-11b, `@reply` beside `@hint`, reopening. P3 F9–F12
fixed: older build wording, shortcut ⌘⇧R and Calm, DESIGN.md §8 evidence, first-word rule.
