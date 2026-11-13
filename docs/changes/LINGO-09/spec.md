# LINGO-09: Specification — harsh tutor and conflict practice on the Mac

ID: LINGO-09-spec · Status: **draft**, waiting for the owner (H-09-0) · Version: 1.1 · Date: 2026-11-13 · Owner: itmax04 · Risk: R2
Links: [intent.md](intent.md) (decisions B-01…B-19, proposals O-1…O-7, assumptions A-01…A-08) · [plan.md](plan.md) ·
[handoff.md](handoff.md) · [contracts](../../../packages/contracts/README.md) · [DESIGN.md](../../../DESIGN.md)
Requirements of this change are defined only here: MR (requirements), MAC (acceptance). The web and iOS clients are out of scope.
**Amends:** LINGO-05 CR-01 (a failed drill makes a mistake card, MR-19) and SR-01 (optional scenario fields, MR-24); LINGO-08 PR-09
(prompt budget of a tone session, MR-08). Everything else of LINGO-05, LINGO-08 and LINGO-10 is unchanged.

Common definitions:
- **Tone**: `harshness` 0–5 (how the tutor reacts to mistakes), `hostility` 0–5 (how the character behaves in its role), `profanity`
  (on or off). **Level** L = max(harshness, hostility). A **tone session** has L ≥ 1.
- **Local line**: fixed catalogue text spoken by the app without a model request.
- **Combined**: a tone session with harshness ≥ 1 and hostility ≥ 1; the tutor and the character are two voices.
- **Trial session**: a session of the personal experiment (§10).

## 1. Settings and data
- **MR-01 Field.** `SessionSettings.tone` is optional: `{ harshness: 0…5, hostility: 0…5, profanity: bool }`. Missing means 0/0/off. It
  is written only when L ≥ 1, so a session without a tone encodes exactly as today. Decoding is tolerant: a malformed object or a value
  out of range gives no tone and never fails the session.
- **MR-02 Where.** A tone can be set on ordinary sessions (Questions, Free, Custom prompt, "My words") and on scenario sessions
  (catalogue, the learner's own, conflict). A warm-up or an exam never has one: the start paths do not offer it, and the prompt builder
  ignores a tone on those activities.
- **MR-03 Presets.** Off (0/0), Strict teacher (3/0), Conflict (0/3), Combined (3/3). Presets are constants; the last values used are
  remembered on this Mac only (`AppSettings`), never in the journal.
- **MR-04 Consent.** The first time a level ≥ 1 is chosen on this Mac, a sheet says in plain words what the tone does, what it never
  does (MR-06) and how to stop it (MR-28). Without the confirmation the levels stay at 0. The date is stored on this Mac only.
  Profanity is a separate switch, off by default.
- **MR-05 Meaning of the levels.** One sentence per level, used by the prompt (MR-08) and shown under the sliders.

  | L | Harshness (tutor) | Hostility (character) |
  |---|---|---|
  | 0 | today's friendly tutor | friendly partner |
  | 1 | firm and direct, no praise padding | cool and formal |
  | 2 | strict, short, impatient; demands a repeat | impatient and unhelpful |
  | 3 | harsh: irritated, sarcastic, sharp about the answer | hostile: dismissive, pushes back |
  | 4 | very harsh: angry, personal jabs at effort and skill | aggressive: accuses, everyday threats |
  | 5 | maximum: furious; with profanity on, swears | maximum: furious, personal insults; with profanity on, swears |

- **MR-06 Limits at every level.** Never: threats of physical violence; insults or contempt by nationality, ethnic origin, race,
  religion, sex, sexual orientation or disability; sexual content; encouraging self-harm; any remark on pronunciation, accent or
  sounds (O-1); attempts to get around a provider's refusal. Allowed from the level that names them: profanity (only with the switch
  on), personal insults about effort, skill and behaviour, pressure, everyday threats (police, ban from the premises, dismissal,
  eviction, fees), contempt for language skill in general. Aggression only answers a real learner utterance: never a technical error,
  an empty or unintelligible transcript, a rule 4a case, or microphone silence caused by a fault.

## 2. Prompt and protocol
- **MR-07 No tone, no change.** With L = 0 and the reply options switch off (MR-49) the system prompt, the requests and the protocol
  are byte-identical to today's. No existing prompt snapshot is re-recorded.
- **MR-08 Tone block.** In a tone session the first line drops "friendly" and states that the learner chose harsh practice for
  training. The default role line ("a friendly conversation partner") is replaced when hostility ≥ 1. A `# Tone` block follows the
  session block: the two levels with their MR-05 sentences (only the chosen ones), profanity yes or no, and the MR-06 limits. The block
  is ≤ 170 estimated tokens (`TokenEstimate`, chars/3.5), and a tone prompt is at most the same session's prompt without a tone plus
  170 (estimate). There is no absolute ceiling: today's prompts already exceed 1 100 estimated tokens (LINGO-08 Q-06). M-2 also records
  the provider's `prompt_tokens` and the extra output tokens per turn (`@fix`, `@help`, `@hint`, `@next`) in `evidence/model-check.md`.
- **MR-09 Rules kept.** Rules 1–5 and 7–9 stay word for word. Rule 3 (pronunciation) is unchanged. `tone` is a setting: the
  `<session_prompt>` block cannot raise or lower it. With harshness ≥ 2 and "As we go" corrections, rule 6 says: give the correct
  form and demand a repeat.
- **MR-10 Judge first.** In a tone session the protocol asks for the `@fix` lines before the first spoken line, and a new rule says:
  criticise only what a `@fix` of this reply records; with no mistake, continue without blame. The example of the protocol shows this
  order.
- **MR-11 `@next <lang>:`** (harshness ≥ 2 with inline corrections). The question the tutor will ask after the repeat. Silent.
- **MR-12 `@help:`** `<strategy in Russian> | <first words of a possible answer>`. One per reply in a tone session; the reply also
  carries at least one `@hint` with a full phrase. Silent.
- **MR-13 `@tutor <lang>:`** (combined only). A line spoken by the tutor outside the scene: the correction and the demand to repeat.
  The character speaks the `@say` lines.
- **MR-14 Storage of the new tags.** `@next` and `@help` are silent tags like `@grade` and `@task` (LINGO-05 PX-01): never spoken,
  never a segment, read from the raw reply text. `@tutor` is stored as an ordinary `say` segment; the voice is chosen from the raw
  text (MR-31). No new segment type is introduced.
- **MR-15 Blame filter.** Applies to tutor speech only: all `@say` lines when hostility = 0, the `@tutor` lines in a combined session,
  nothing when harshness = 0. If the reply has no `@fix`, every sentence of that speech containing a blame marker is removed before it
  is spoken, shown or stored as a segment. If nothing remains, a neutral local line replaces it. The markers are a list per language
  in a contracts fixture (for example falsch, Fehler, wrong, mistake). The count is recorded as `tone.filtered`
  `{session, message, removed}`; no text. The raw reply text is stored as always. Tutor speech is buffered: `@say` lines of tutor speech are held until the first `@fix` or
  the end of the stream, because the filter can only be decided then (this belongs to the judge-first order of MR-10; ordinary
  sessions still speak lines as they arrive). M-2 measures the effect on speech_end → first audio (MAC.md target 3.5 s median).

## 3. Local drive
- **MR-16 Drill start.** In a tone session with harshness ≥ 2 and inline corrections, a reply with at least one `@fix` starts a
  repeat drill. The expected phrase is the corrected text of the first `@fix`.
- **MR-17 Comparison.** The next learner utterance is compared on the Mac. Both texts are normalised (Unicode NFC, lower case,
  punctuation and quotes removed, spaces collapsed). With W = word error rate against the expected phrase: **pass** if W ≤ 0.2 or the
  expected words appear in order inside the utterance; **miss** if 0.2 < W ≤ 0.6; otherwise **not a repeat**. A command detected
  locally is handled first and ends the drill. Golden cases live in `packages/contracts/fixtures/teacher/drill.json`.
- **MR-18 Flow.** Pass: a local "at last" line. Miss: a local "again" line and the expected phrase once more; a second miss ends the
  drill with a local "move on" line. After the end, the `@next` question is spoken as a new assistant message; without `@next` the app
  sends the ordinary "next step" request. "Not a repeat" ends the drill silently and the utterance goes to the model as an ordinary
  turn (rule 4b). Local lines and the `@next` question are journaled as assistant messages, so the transcript stays whole. A drill
  makes no model request for the attempts. `local` messages (and the `@next` question) are excluded from the ContextPolicy window of
  eight turns and from the LINGO-05 counted-message statistics; they are shown in the transcript only. MAC-09 tests both.
- **MR-19 Result and card.** `drill.result` `{session, message, attempts: 1…2, ok}`. The card of a failed drill uses `createdAt` = the `drill.result` timestamp, a key with the prefix `drill:` plus the normalised
  corrected text (never equal to a rule key), and the first `@fix` of the message identified by its index in `drill.result.message`.
  A failed drill makes a mistake card at once: the
  card derivation (CR-01) counts that fix as recurring, keyed by its rule, or by the normalised corrected text when the rule is empty.
- **MR-20 Silence.** In a tone session with L ≥ 2, when Lingo has finished speaking and the learner is expected to answer: after 8 s
  without speech a local pressure line of the level; after 8 s more, help step 1 is revealed (MR-22); then nothing. The timers stop
  while the session is paused, while the learner types, during a drill's own speech and after a technical failure of the last turn.
  Settings → Voice: "Pressure, then help" (default), "Only pressure", "Wait silently"; the delay is 5–20 s.
- **MR-21 Local lines.** A catalogue in LingoCore, written to `packages/contracts/teacher/tone-lines.json` by the tests. Kinds:
  pressure, again, pass, move on, calm, neutral, interjection. Per language (de, en) and band (L 1, 2, 3, 4, 5; at L 1 only the neutral and calm kinds); profane variants are
  separate and used only with profanity on. At least four lines per kind, language and band; a line is not used twice in a row. All
  lines are original and meet MR-06; a test checks them against a deny-list (violence, protected traits, pronunciation words).

## 4. Help in three steps
- **MR-22 Steps.** In a tone session the Hints panel shows "Help". Each press of the key or each use of the help word reveals the next
  step for the current turn: 1 the strategy (Russian), 2 the first words, 3 the full phrase (the first `@hint`). Text only; a ▶ button
  speaks steps 2 and 3. If the last reply has no `@help`, steps 1 and 2 are skipped; with no `@hint` either, the panel says there is no
  help for this turn. No model request is made. Sessions without a tone keep today's Hints panel.
- **MR-23 Record.** Each reveal appends `help.revealed` `{session, message, step}`. The debrief (MR-29) counts the turns answered without
  help. The help word is a new local command (`help`) in the commands fixture, Swift and TypeScript. It is detected only in tone
  sessions; in a 0/0 session "help me" or "Hilfe" is ordinary speech. Negative fixture cases: "Can you help me", "Ich brauche Hilfe
  beim Umzug".

## 4a. Reply options (sessions without a tone; added in version 1.1, B-19, O-7)
- **MR-49 Switch.** A "Reply options" toggle in the existing chip row of the voice panel next to Continuous, In Russian and Slow (the
  panel stays 112 pt high), plus a menu command with the shortcut ⌘⇧R. Off by default. The state is remembered on this Mac only
  (`AppSettings`), never in the journal, and applies from the next request; the running reply is not cut. It is offered in open
  ordinary and scenario sessions without a tone. In a tone session (Help of MR-22 serves there), a trial or trial-test session (MR-39,
  MR-41), a warm-up, an exam, and an ended or read-only session it is hidden and has no effect. After Calm (MR-28) the session is
  ordinary, and the switch applies from the next request.
- **MR-50 Tag `@reply <lang>:`** `<a short answer the learner could give> | <Russian translation>`. With the switch on, the output
  protocol lists the tag and one rule: two or three lines that answer the last question or task of this reply, in the first person,
  different in content, at the session's level and within its word limit, and not repeating an `@hint` of the same reply. `@hint`
  keeps its meaning and still feeds the Hints panel. The added prompt text is ≤ 40 estimated tokens. `reply` joins the silent tags
  (like `@next` and `@help`, MR-14): never spoken, never a segment, read from the raw reply text; the parser returns the language and
  the two parts. An older build never asks for the tag and reads only the stored segments, of which `@reply` is none. Lines without
  the `|` separator or with an empty phrase are skipped; more than three lines keep the first three.
- **MR-51 Place and life.** The block belongs to the **anchor**: the latest model-generated assistant message of the open session
  (never a `local` message of MR-18, the fixed farewell of MR-29 or an error). Earlier messages show no options. The block appears when
  the anchor has finished speaking (at once if it is not spoken) and hides when the learner's next turn starts (speech detected or a
  message sent). If that turn fails without a new assistant message, the block returns as it was. When a session is reopened, the block
  is derived from the raw text of the anchor; refreshed options and reveals are not restored. Header "Reply options" with refresh
  (MR-53) and collapse; the collapsed state is remembered on this Mac. An anchor without valid `@reply` lines shows "No options for
  this turn" with the refresh button. DESIGN.md tokens only; DESIGN.md §5 gets a "Reply options" entry in the same PR; every string in
  English and Russian; accessibility labels and keyboard focus on every row. The component has no reference image: its evidence is
  implementation screenshots in both themes plus the contrast check; the ±4 pt criterion of DESIGN.md §8 is not claimed for it.
- **MR-52 Reveal and use.** Each option first shows only its first words (split on whitespace: two words; one if the phrase has fewer
  than four) followed by "…", and no translation. Activating a focused row (click, or Return or Space while the row has keyboard
  focus) reveals the full phrase and the translation; "Show all" reveals every row. A revealed option has ▶ (speaks it in its
  language with the voice and pace set in Settings, Slow included), ★ (saves it to the vocabulary, as the Hints panel does) and, while
  the keyboard input is open, "Insert" (puts the text into the message field). ▶ uses the playback path without the microphone:
  capture pauses while the phrase plays and continuous mode resumes listening after it; ▶ is disabled while Lingo speaks or the
  learner is being recorded. An option is never sent automatically: the learner says it or sends it.
- **MR-53 Refresh.** One request (purpose `replyOptions`: the session prompt with the switch on, the ContextPolicy window and one
  instruction) returns two or three new `@reply` lines that replace the shown ones. Its input is about the size of an ordinary turn.
  It is not a message and is not journaled; it goes through the usual router and usage ledger. At most two refreshes per anchor; the
  button is disabled while a turn runs, offline and without a key; a quota or network failure shows explicit text and an error symbol
  (DESIGN.md §5).
- **MR-54 Record and cost.** Each reveal appends `reply.revealed` `{session, message, index}` (ids and numbers only, MR-46). Step M-11b
  records in `evidence/reply-options.md` the provider's `prompt_tokens` and `completion_tokens` of six single daytime requests (three
  replies with the switch on and three with it off, on the same turns) and of one refresh. If the median completion increase is above
  100 tokens per turn (three lines with Russian translations are expected near 75–100), the rule asks for two options instead of
  three, and the evidence says so.

## 5. Conflict scenarios
- **MR-24 Catalogue.** `Scenario` gets two optional fields: `group` (`authorities`, `housing`, `work`, `services`) and `hostility`
  (1–5, the suggested level). Twelve conflict scenarios: eight German (two per group) and four English (one per group), levels B1 and
  B2. Each has a role, a situation, three or four communicative goals (state the position, set a boundary, ask for a name, a superior
  or a written answer, propose an alternative, leave politely) and four phrases with Russian translations. The export
  `scenarios.json` carries the new fields.
- **MR-25 Start.** A conflict scenario starts with hostility = its suggested level and harshness = 0; both can be changed before the
  start. The prompt is the existing scenario block plus the tone block; `@task` marks the goals as in LINGO-05.
- **MR-26 Interface.** Teacher gets a "Stand your ground" card that opens the scenario picker on a third tab, "Conflicts", grouped by
  `group`. The new-session sheet and the start of any scenario get a "Tone" section: preset menu, two sliders with the MR-05 sentence
  of the chosen level, the profanity switch. The session header names the tone in words ("Tone 3/0"), not by colour alone. DESIGN.md
  tokens only; every string in English and Russian; controls have accessibility labels.

## 6. Control, calm and ending
- **MR-27 Live control.** The voice panel has a Tone button with a popover: the two sliders, profanity and, in a Custom prompt
  session, the prompt field. Save cuts the current reply (the existing interrupt), appends `session.updated` with the new settings and
  the next request uses them. The popover shows the number of settings changes in this session. Not available in a trial session.
- **MR-28 Calm.** A "Calm down" button, a key and a local command (`calm`; the words per language in the commands fixture, O-5).
  Effect: speech stops, a drill and the silence timers are cancelled, the tone becomes 0/0/off through `session.updated`, a calm local
  line is spoken and the session continues as an ordinary one. It always works in a tone or trial session (MR-39); in a 0/0 session it is detected only if a tone was used earlier in the same
  session, otherwise the words are ordinary speech (negative fixture cases as for `help`). The commands are part of the MR-07
  invariant: with L = 0 and no earlier tone, detection and requests are byte-identical to today's.
- **MR-29 Ending.** The farewell of every session is today's fixed neutral line, never a tone line. A finished session that ever had
  L ≥ 3 offers a debrief: one request (purpose `toneDebrief`) built from the summary, the fixes and the scenario goals. It returns, in
  Russian: two things that worked, three phrases to keep (study language with translation) and one next step. No score, no
  pronunciation (`PronunciationFilter` is applied). Next to it: counts computed on the Mac (turns, turns without help, drills passed
  and failed, goals reached) and a self-rating slider 0–10, stored as `tone.rated` `{session, confidence}`. The debrief is stored and
  shown again the way the LINGO-05 exam debrief is.

## 7. Voice
- **MR-30 Prosody.** System voices. The speech rate and pitch follow the level of the speaker (harshness for the tutor, hostility for
  the character): L 0–1 unchanged; 2: rate ×1.05; 3: ×1.10, pitch 1.05; 4: ×1.15, pitch 1.10; 5: ×1.20, pitch 1.15. The factor is
  applied on top of the learner's pace; "slower" and replay keep their own rate.
- **MR-31 Two voices.** In a combined session the character speaks with a different installed voice of the language, chosen as the
  partner voice of LINGO-10 BR-23, generalised per language (an English partner voice is chosen the same way); the tutor uses the learner's voice. With one installed voice both use it.
- **MR-32 Voice probe.** No product code. `evidence/voice-probe.md` compares the same ten German lines through the system voice,
  Piper `thorsten_emotional` and Chatterbox Multilingual: time to first audio, peak memory on the owner's Mac, size, licence. Each tool
  is installed only after the owner's explicit yes. Using one of them in the app needs an ADR-0001 entry and its own step, outside
  this plan.

## 8. Pauses and interjections
- **MR-33 Pause after a connective.** In a tone session (with the segmenter pause T > 0.6 s; otherwise the check runs at T − 0.2 s), at a pause of 0.6 s inside an utterance the last ≤ 3 s of audio are
  recognised. If the last word is in the connective list of the language (contracts fixture: weil, dass, ob, wenn, und, aber,
  articles, common prepositions and auxiliaries; because, that, and, the, to …), the pause that ends this utterance becomes 3.0 s. The
  tail audio is never stored. **Kill criterion:** if the median tail recognition on the owner's Mac is above 500 ms, the feature
  ships switched off and the report says so.
- **MR-34 Interjection.** Conditions: hostility ≥ 3, voice processing on, the utterance has run ≥ 12 s, a pause of ≥ 0.6 s whose tail
  is not a connective (MR-33; without MR-33 no interjections). Then one local interjection of at most four words is played without
  ending the utterance. At most one per utterance and one per 45 s ("rare", default) or 20 s ("often"); "off" in Settings → Voice. It
  is recorded as `tone.interjected` `{session, lineId}` (ids and numbers only, MR-46; a schema test checks that the new payloads carry no free text) and is not a message. An interjection never produces a `@fix`.

## 9. Model check
- **MR-35 One small live run** (B-10, O-2) before anything after M-1 is built: at most 40 requests on the 20b model through
  `--eval-dialog` with `--models` and `--budget`. Cases in `packages/contracts/evals/dialog/`: both languages, levels 1, 3 and 5 of
  each axis, at least ten learner turns that contain no mistake. Checks: valid protocol; no blame on the correct turns before the
  filter; no pronunciation remark; no hit of the MR-06 deny-list; refusals and out-of-role replies counted by reading the outputs.
- **MR-36 Consequences.** Blame on correct turns above 2 of 10, any pronunciation remark, or any deny-list hit stops the plan for a
  prompt fix and one more run on another day. If more than 20 % of the replies at level 5 (cases at levels 1, 3, 5 plus two at level 4) are softened or refused, the plan continues
  and the sliders say "the model may soften this level". Lingo never retries or rewrites a request to defeat a refusal.

## 10. Personal experiment
- **MR-37 Protocol first.** `experiment-protocol.md` in this folder: the question, the primary measure (share of expressions used
  correctly without help at the test), the rule of conclusion, the schedule and the exclusions. The owner accepts it (H-09-2) before
  the first trial session; later changes are dated amendments.
- **MR-38 Material.** 64 German expressions (O-4) in 32 pairs matched by length (±2 words) and function; each has one training
  situation and one different test situation. Within a pair a seeded shuffle, recorded in the protocol, assigns the condition (calm or
  harsh) and, the test day (7 or 21) is assigned to the pair, so both members are tested on the same day and the day is balanced across pairs.
- **MR-39 Trial session.** A new activity kind `trial` `{set, block, condition, cards}`. Eight blocks of eight expressions in the
  order A B B A A B B A. Calm is tone 0/0; harsh is harshness 4, hostility 0, with profanity fixed for the whole experiment in the
  protocol. Both show the same 20 s answer timer. Drills, silence pressure, help reveals and the Help panel are off in both arms, so the two
  conditions differ only in tone. Live control is off. If Calm (MR-28) is used, the session is marked aborted
  (`trial.aborted`) and its expressions are excluded.
- **MR-40 Lock.** Until an expression is tested it does not appear in the warm-up queue, in "My words" or in the `<vocabulary>` block.
- **MR-41 Test and blind grading.** On day 7 (±1) and day 21 (±2) Today shows that a test is due. The test session has no tone, no
  help and no feedback: one new situation per expression, one answer each. Grading is a separate request (purpose `trialGrade`, eight
  expressions per request) that sees the target expression, the situation and the answer, never the condition. Result per expression:
  correct, partial, not used; stored as `trial.graded`.
- **MR-42 Met in real life.** The owner can mark an expression as met outside Lingo; marked expressions are excluded; the mark is stored as `trial.met`.
- **MR-43 Export.** `--trial-export <csv>`: one row per expression (ids, pair, condition, block, dates, test day, result, highest help
  step, exclusions), no utterance text. `scripts/trial-report.py` prints the paired difference and an exact sign test.

## 11. Contracts, compatibility and privacy
- **MR-44 Additive.** New optional fields (`tone`, `Scenario.group`, `Scenario.hostility`, the `local` mark of a message), a new
  activity kinds (`trial` and `trialTest`, the test session of MR-41), new events (`tone.filtered`, `drill.result`, `help.revealed`, `tone.interjected`, `tone.rated`,
  `trial.aborted`, `trial.graded`, `trial.met`, `trial.debriefed`, `reply.revealed`), new silent tags (including `@reply`), a new
  request purpose (`replyOptions`) and two local commands. `event.schema.json`, the fixtures and the TypeScript
  decoders change in the same PR as the Swift code (AGENTS.md §6.9). Prompt snapshots are added for a strict session, a conflict
  scenario, a combined session, profanity on and an ordinary session with reply options on.
- **MR-45 Older build.** The build before this change opens a tone or trial session as an ordinary session and can continue it; it
  ignores the new events. A test decodes the new fixtures with the current decoders.
- **MR-46 Privacy.** New events carry ids and numbers only. Logs contain no utterance text. Audio is never stored (the MR-33 tail
  included).
- **MR-47 No pronunciation.** The local lines, the scenarios and the debrief contain no pronunciation assessment; the
  `no_pronunciation` cases stay at 100 %.
- **MR-48 Documents.** `MAC.md`, `CODEBASE.md`, `ROADMAP.md`, `GLOSSARY.md`, the contracts README, the completion plan and
  `report.md` with evidence for every MAC.

## 12. Acceptance
| ID | Check | Requirements |
|---|---|---|
| MAC-01 | A session without a tone encodes as before; existing prompt snapshots are unchanged (no file of `packages/contracts/prompts` modified) | MR-01, MR-07 |
| MAC-02 | Malformed and out-of-range tone objects decode as no tone; the session opens | MR-01, MR-45 |
| MAC-03 | A warm-up and both exams ignore a tone in settings (prompt equal to the one without it) | MR-02 |
| MAC-04 | Without consent the levels cannot be raised; with it the presets set the documented values | MR-03, MR-04 |
| MAC-05 | Tone snapshots exist; the tone block is ≤ 170 estimated tokens and a tone prompt ≤ the same session's prompt without a tone + 170; rules 3 and 7 are present verbatim; a `<session_prompt>` that asks for a harsher tone changes nothing in the block | MR-05, MR-06, MR-08, MR-09 |
| MAC-06 | Protocol tests: `@next`, `@help` are never spoken and never segments; `@tutor` becomes a `say` segment; a reply with them decodes with the previous decoder | MR-10…MR-14, MR-45 |
| MAC-07 | Blame filter: golden cases per language (blame without `@fix` removed; with `@fix` kept; character speech untouched; empty result replaced) | MR-15 |
| MAC-08 | Drill golden cases pass in Swift and TypeScript: pass, miss, not a repeat, command first | MR-16, MR-17 |
| MAC-09 | Engine tests: pass, two misses and "not a repeat" produce the documented messages and events and no model request for attempts; with and without `@next` | MR-18, MR-19 |
| MAC-10 | A failed drill yields a mistake card; a passed one does not change the cards | MR-19 |
| MAC-11 | Silence: lines at 8 s and help at 16 s on a fake clock; nothing while paused, typing or after a technical failure; the three settings | MR-20 |
| MAC-12 | Line catalogue: counts per kind, language and band; export equals `tone-lines.json`; deny-list test passes; profane lines only with the switch | MR-06, MR-21, MR-47 |
| MAC-13 | Help reveals steps in order without a model request; `help.revealed` per reveal; fallbacks without `@help` or `@hint` | MR-22, MR-23 |
| MAC-14 | Conflict catalogue: twelve scenarios with the required fields; export equals `scenarios.json`; independent review of originality and level recorded | MR-24 |
| MAC-15 | Screenshots in both themes, Russian and English: Tone section, consent sheet, Conflicts tab, Teacher card, live popover, header label; `check-design` passes | MR-25, MR-26, MR-27 |
| MAC-16 | Live change: the running reply is cut, `session.updated` is appended, the next request carries the new tone | MR-27 |
| MAC-17 | Calm by button, key and command: tone 0/0, drill and timers cancelled, calm line spoken, next prompt equals the ordinary one | MR-28 |
| MAC-18 | Ending: neutral farewell in a tone session; debrief request within its limits; pronunciation filter applied; `tone.rated` stored; counts match a fixture journal | MR-29 |
| MAC-19 | Rate and pitch per level in a unit test; two voices chosen when two are installed, one otherwise | MR-30, MR-31 |
| MAC-20 | `evidence/voice-probe.md` with real measurements, or NOT RUN with the owner's answer | MR-32 |
| MAC-21 | Connective list fixture; the pause becomes 3.0 s after a connective in a segmenter test; measured tail recognition time recorded; the kill criterion applied | MR-33 |
| MAC-22 | Interjection conditions and limits on a fake clock; no interjection with voice processing off; no `@fix` from one; owner's listening check at H-09-1 | MR-34 |
| MAC-23 | `evidence/model-check.md`: the run's command, budget, counts per check and the decision under MR-36 | MR-35, MR-36 |
| MAC-24 | Protocol accepted by the owner before the first trial session (date in handoff); assignment reproducible from the seed | MR-37, MR-38 |
| MAC-25 | Trial tests: block order, fixed tone, lock in warm-up, "My words" and `<vocabulary>`, abort on Calm, due dates on a fake clock; reply options hidden and without effect in trial and trial-test sessions | MR-39, MR-40, MR-41, MR-49 |
| MAC-26 | The grading request contains no condition (snapshot); export columns match a fixture; the report script runs on it | MR-41, MR-42, MR-43 |
| MAC-27 | `swift test`, `npm test`, `check-core-ios.sh`, `check-design.py`, `check-english.sh`, `secret-scan.sh` pass; schema and fixtures updated with each step | MR-44, MR-46 |
| MAC-28 | Documents updated; `report.md` lists every MAC as PASS, FAIL or NOT RUN with real output | MR-48 |
| MAC-29 | Owner: tries a strict session, a conflict scenario and a combined session on the Mac (H-09-1) and accepts the change (H-09-3) | all |
| MAC-30 | Switch: off by default; with it off the prompt equals today's; with it on the snapshot has the tag and the rule (≤ 40 estimated tokens added); hidden and without effect in tone, warm-up, exam, ended and read-only sessions (trial sessions: MAC-25) | MR-49, MR-50 |
| MAC-31 | Protocol golden cases in Swift and TypeScript: `@reply` is silent, never spoken and never a segment; language and both parts returned; malformed lines skipped; at most three kept | MR-50, MR-44, MR-45 |
| MAC-32 | View tests and screenshots in both themes, Russian and English: only under the anchor, after its speech; hidden when the next turn starts and back after a failed turn; derived from raw text on reopen; first words without translation, reveal, Show all, ▶ (capture paused, disabled while speaking or recording), ★, Insert; nothing sent automatically; `reply.revealed` per reveal; `check-design` passes | MR-51, MR-52, MR-54 |
| MAC-33 | Refresh: one request per press, at most two per anchor, disabled states and error text; `evidence/reply-options.md` with real prompt and completion tokens and the MR-54 decision | MR-53, MR-54 |
