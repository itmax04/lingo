# LINGO-01: Specification v2 — MVP for the Mac

ID: LINGO-01-spec · Status: **accepted** (2026-10-25) · Version: 2.2 · Date: 2026-10-25 (2.1: R-24 `@heard`, R-51 — Q28; 2.2: R-04, R-52, AC-17 — Q29) · Owner: itmax04
Links: [intent.md](intent.md) (goal, boundaries, decisions Q1–Q27, assumptions A-1…A-9) · [ADR-0001](../../decisions/ADR-0001-stack.md) (stack) ·
[plan.md](plan.md) (implementation) · [evals/README.md](../../../evals/README.md) (sets and thresholds) · [DESIGN.md](../../../DESIGN.md) (tokens) ·
[pdf-patterns.md](../../reference/pdf-patterns.md) (patterns P1–P16)
Only this file sets requirements. plan.md and handoff.md only refer to the numbers R-, F-, AC-.

Translated to English in LINGO-03 P-06 (MR-08); the Russian original is in the Git history of this file. Utterances and UI texts that the user speaks or reads in Russian
are given in English and marked "(ru)"; the exact Russian phrase lists live in `packages/contracts/evals/commands/ru.yaml` and the dialog evals, and the Russian UI texts in
`apps/mac/Resources/Localizable.xcstrings`.

## 1. Terms
- **Study language** — `en` or `de`, set per session. **Explanation language** — `ru`.
- **Session** — a conversation with settings (R-02). It can be continued at any time on any device.
- **Utterance** — the user's continuous speech up to a pause, or one text message.
- **Turn** — an utterance sent to the model, together with the assistant's answer.
- **Session mode** — "Questions", "Free conversation" or "Custom prompt" (R-03).
- **Correction modes** — any non-empty combination: "as you go", "after the conversation", "on request" (R-20).
- **Command** — a control phrase: repeat, slower, how to say, explain, let's continue, were there mistakes, finish (R-14…R-22).
- **Chain** — an ordered list of "provider + model + key" steps with automatic fallback (R-29).
- **Device journal** — an event file that only one device writes to (R-34…R-37).
- **Sync folder** — a folder in iCloud Drive chosen by the user (R-36).
- **Utility app** — an iOS app for measurements on the iPhone (R-46). Built in LINGO-02, it is not the MVP.

## 2. Scenarios
All scenarios are implemented and checked in the Mac app (LINGO-01). The iPhone values are given for the future (LINGO-02).

- **S-01. New session.**
  When: the user presses "New session".
  Then the setup screen opens:
  - language (English/Deutsch, preselected from the sidebar);
  - mode;
  - topic, the partner's role, level;
  - a custom prompt (for the "Custom prompt" mode);
  - correction modes (several can be chosen; A-3);
  - who starts.

  "Start" is inactive until at least one correction mode is chosen. After "Start" the session appears in the list.
  If the assistant speaks first, it says its first utterance aloud.
- **S-02. Voice with a button.** The user holds the space bar (focus is not in an input field) or presses the microphone button and speaks.
  When they release (or press a second time), the utterance is transcribed and appears on the right in a blue bubble. Below it are the language and the time.
  Then the assistant's answer arrives: text on the left, spoken in the voice of the right language.
- **S-03. Continuous dialogue.** The user switches on continuous mode. The panel shows "Listening", the wave and the buttons "Pause" and "Finish".
  The utterance is sent after a pause T (a slider, R-10). Then "Thinking…", the answer is spoken, and listening resumes by itself.
- **S-04. Interrupting the assistant.** The assistant is speaking and the user starts to speak. The speech stops
  within 0.5 s at the latest on the Mac and 0.7 s on the iPhone. The unspoken part of the answer is marked "interrupted" in the text.
  The new utterance becomes the next turn. The assistant's own sound does not count as an interruption (R-12).
- **S-05. Adding to a phrase.** The user said "Am Wochenende gehe", fell silent, and after a second added "spazieren".
  The assistant has not started to speak yet, so the utterances are merged into one, and the unfinished request to the model is cancelled (R-11).
- **S-06. "Repeat".** The user says "nochmal, bitte", "again" or the Russian word for "repeat" (ru). The assistant's last answer is spoken again
  within 0.3 s at the latest, the model is not called (R-14).
- **S-07. "Slower".** The user says "langsamer", "slower" or the Russian word for "slower" (ru). The last answer is repeated at a pace of ×0.75
  with pauses between the parts of the phrase. A repeated request slows it down to ×0.6 (R-15).
- **S-08. "How to say".** The user says (ru) "How do I say 'I am on vacation right now'?".
  The assistant answers with:
  - a version in the study language, for example "Zurzeit habe ich Ferien";
  - a short translation;
  - a request to repeat.

  The phrase goes into the hints, into the "How to say" section (R-16, R-27).
- **S-09. Explanation in Russian.** The user says (ru) "explain in Russian" or "what did you ask?".
  The assistant briefly explains in Russian and gives an example in the study language. Then it returns to practice
  and repeats the last question in the study language (R-17).
- **S-10. A Russian utterance without a request.** The user says (ru) "No, I want to say that I am on vacation".
  The assistant does not switch to Russian. It gives a version in the study language and asks the user to repeat (R-18, A-2).
- **S-11. "Let's continue".** The user says "weiter", "let's continue" or the Russian phrase for "let's continue" (ru).
  The assistant returns to practice: the next question or a remark on the topic (R-19).
- **S-12. Mixed speech.** The user says (ru/de) "Dann musste, oh, no, no, from the very beginning. Dann muss ich zu Hause bleiben".
  The transcript keeps both parts as the engine gave them. The self-correction "oh, no, from the very beginning" is not counted as a mistake.
  The assistant answers to the last finished thought (R-08, R-21).
  If the mixed phrase was recognised badly:
  - the button "I speak Russian" recognises the next utterance as Russian;
  - a click on the bubble opens text editing;
  - "Answer again" recomputes the answer (R-09).
- **S-13. Correction as you go.** The "as you go" mode is on. The user says "Mir gefällt in Rostock, dass Meer hier hast".
  The assistant gives the natural version "Mir gefällt an Rostock, dass es hier das Meer gibt" and asks to repeat.
  The correction is highlighted in the bubble and goes into the hints, into the "Corrections" section (R-20).
- **S-14. Correction after the conversation.** Only the "after" mode is on. The assistant does not interrupt with corrections.
  On "Finish" or "that is all" a recap in Russian is shown: the 3–5 main mistakes with corrected versions and a short rule (R-20, R-23).
- **S-15. Correction on request.** The "on request" mode is on. The user asks "were there mistakes?", "korrigiere mich" or "any mistakes?".
  The assistant reviews the user's last utterances. Without a request there are no corrections (R-20).
- **S-16. Continuing a session.** The user opens the session "At the cafe" from 12 May. The whole history is visible.
  The assistant continues with the summary and the last utterances in mind. The header carries the hint: "The assistant remembers the summary and the last N utterances" (R-04).
- **S-17. No internet on the Mac.** The user opens the app without a network. The history, the hints, the vocabulary and listening to phrases work.
  Voice and text input are inactive, with the explanation "No network: model replies are unavailable" next to them (R-33).
- **S-18. All keys exhausted.** The whole chain returned 429 or errors.
  The assistant writes: "Models are unavailable: <reasons>. Try again in N min". The user's utterance is saved.
  "Answer again" is available (R-29).
- **S-19. Two edits at once.** On two devices without a network, 25 messages each are added to one session.
  In LINGO-01 the second device is `lingo-eval sync-write` with a different `deviceId`, in LINGO-02 it is the iPhone.
  After the network returns and iCloud syncs, both devices show all 50 messages in the same order, without duplicates and losses (R-37).
- **S-20. Folder unavailable.** The sync folder is deleted, renamed or access is not granted. Work continues locally.
  The status "Sync folder unavailable — choose again". The local history is not lost (R-34, R-38).

## 3. Requirements

### Sessions and modes
- **R-01. Session.** Fields:
  - id, study language, title (by default "<Mode>: <topic>", can be renamed);
  - mode, topic, the partner's role, level (A1, A2, B1, B2, C1, C2 or free text);
  - custom prompt, correction modes, who starts;
  - creation and last-activity dates, state: active or finished.

  A finished session can be continued, then it becomes active again.
- **R-02. Setting up a new session** — per S-01. Free conversation is possible without a topic and a role.
  The example prompt from the PDF (P1) is available as a placeholder hint. Nothing is substituted silently.
- **R-03. Modes:**
  - **Questions.** The assistant asks one question on the topic at a time, waits for the answer and reacts to it, then asks the next question.
    It builds long phrases in steps (P15).
  - **Free conversation.** A natural dialogue on a topic or without one. The assistant keeps the conversation going and asks counter-questions.
  - **Custom prompt.** The user's text is the instructions of this session, for example the role, the situation and the rules, as in P1.
    It is embedded in the system wrapper R-25. The wrapper keeps the reply protocol R-24, the language R-26 and the ban on assessing pronunciation R-21.
    If the user's prompt contradicts the wrapper, the wrapper wins; this is visible on the setup screen.
  In all modes the complexity and length of the assistant's phrases match the level of the session.
- **R-04. Model context.** The request carries:
  - the system wrapper;
  - the session summary;
  - the last N turns (N = 8, configurable from 6 to 40; Q29), but no more than a budget of ≈ 1800 tokens for history.

  The summary is updated by a separate request every 10 turns and when the session ends. It is stored as a journal event.
  The interface does not promise that the model remembers everything.
- **R-05. Session list.**
  - Sorted by last activity.
  - The English/Deutsch filter is a segment in the sidebar.
  - The "…" menu: rename, delete (with confirmation; deletion is a tombstone event and is synced), show in the journal.
  - A session row: icon, title, date and time as in the mockup.

### Voice: input
- **R-06. Voice with a button.** The microphone button, and also holding the space bar when focus is not in a text field.
  While recording, the wave and a timer are shown. Esc cancels the utterance.
- **R-07. Continuous mode.** The states "Listening", "Thinking…", "Speaking", "Pause".
  - "Pause" suspends listening and speech.
  - "Finish" ends the voice mode and the session per R-22.

  Visually it is the voice panel of the mockup.
- **R-08. Recognition.** Local, the engine per ADR-0001.
  - The language is determined for each utterance among {study language, ru}.
  - The detected language is shown as a label by the bubble.
  - If the engine supports mixed speech, the text is kept as is.
  - Audio is not written to disk. The in-memory buffer is at most 60 s.
- **R-09. Mixed speech, fallback paths:**
  - the button "I speak Russian" (a switch for one utterance; ⌥R on the Mac);
  - editing the transcript by clicking the bubble (the event `message.edited`);
  - "Answer again" recomputes the answer from the corrected text.
- **R-10. End of an utterance in continuous mode.**
  - Silence of at least T: 1.5 s by default, a slider from 0.6 to 3.0 s in steps of 0.1.
  - Speech of at least 0.3 s.
  - The threshold is checked by the `turn` eval (evals/README.md).
- **R-11. Merging.** A new utterance begins no later than G after the end of the previous one (G = 2.0 s, configurable from 0 to 4).
  If the assistant has not started to speak yet, the unfinished request is cancelled, the texts are joined with a space, and one new request is sent.
  If the assistant is already speaking, R-12 applies.

### Voice: output and barge-in
- **R-12. Barge-in.**
  - The user's speech during playback stops it: on the Mac within 0.5 s at the latest, on the iPhone within 0.7 s.
  - The echo of its own speech is suppressed by the system voice processing and does not count as barge-in.
  - A click on the panel, the space bar and Esc also stop the speech.
  - In the answer text the unspoken part is dimmed with the label "interrupted".
  - The next request to the model gets the mark `interrupted_at` (the position in the answer).
- **R-13. Speech synthesis.**
  - The answer segments (R-24) are spoken in the voice of their language.
  - The voice for each language and the base pace are chosen in the settings; by default the best installed voice (premium, then enhanced, then default).
  - The text appears as it is generated; speech starts with the first finished sentence.
  - If only a poor-quality voice is installed, the settings offer to download an enhanced voice, with instructions.

### Commands
Commands are recognised first by a local detector: rules and dictionaries for ru, de and en with tolerance to transcription errors.
If the detector is not sure, the utterance goes to the model as an ordinary one. The model also knows the commands from the wrapper R-25.
The check set is the `commands` eval.
- **R-14. "Repeat".** Examples: the Russian words for "repeat" and "once more" (ru), "nochmal", "noch einmal", "wiederhol", "again", "repeat", "say it again".
  The assistant's last answer is spoken again, without the model. Sound starts within 0.3 s at the latest after the end of the utterance.
- **R-15. "Slower".** Examples: the Russian words for "slower" and "a bit slower" (ru), "langsamer", "langsam bitte", "slower", "more slowly".
  The last answer is repeated at ×0.75 of the base pace. The phrase is split by punctuation and semantic groups, with a pause of 0.6 s between the parts.
  A repeated request — ×0.6, which is the minimum. The pace of the following answers does not change until the user switches on "Slow pace" in the session header.
- **R-16. "How to say".** Examples: the Russian phrases for "how to say …", "how will it be …", "how else can one say …" (ru), "wie sagt man …", "how do I say …".
  The assistant answers with:
  - 1–2 versions in the study language with a translation;
  - a request to repeat one of them.

  The versions go into the hints, into the "How to say" section.
- **R-17. "Explain" and an explicit request in Russian.** Examples: the Russian words for "explain", "in Russian", "what did you ask", "what does … mean", "why so", "translate" (ru),
  "erklär mal", "explain". The answer:
  - an explanation in Russian, no longer than 120 words;
  - an example in the study language;
  - a return to practice: a repeat of the last question or task in the study language.
- **R-18. A Russian utterance without an explicit request** — per A-2 and S-10.
- **R-19. "Let's continue".** Examples: the Russian phrases for "let's continue", "next", "let's go on", "ready" (ru), "weiter", "machen wir weiter", "let's continue", "go on".
  A return to practice according to the session mode.

### Error correction
- **R-20. Correction modes** are chosen before the session (S-01) and changed in the session header. Any combinations are possible:
  - **as you go** — no more than one main correction per turn, in the study language, on the pattern "More natural: „…“", then a request to repeat.
    An answer that is right in meaning but not to the question asked is also marked (P5);
  - **after the conversation** — the assistant does not interrupt the practice with corrections. For each turn the model returns hidden `@fix` records (R-24).
    They accumulate in the journal and are shown in the recap R-23;
  - **on request** — the commands "were there mistakes?", "check me" (ru), "korrigiere mich", "any mistakes?" start a review of the user's last 10 utterances
    (3–5 items in the study language; on an explicit request, in Russian).

  Without "as you go" the assistant does not correct in ordinary answers. The exception is not understanding: then it asks again.
- **R-21. What the assistant does not do:**
  - it does not comment on or assess pronunciation, neither directly nor by hints ("softer S", "a clear ck");
  - it does not count transcription artifacts as mistakes: broken words, duplicates, fragments, self-corrections;
  - if the transcript is unintelligible, it asks again instead of "correcting".

  Checked by the `dialog` eval: the rule `no_pronunciation` must hold in 100% of cases.
- **R-22. Ending.** The "Finish" button or the phrases "that is all", "let's finish" (ru), "das war's", "that's all".
  The assistant briefly says goodbye in the study language, and the session moves to the "finished" state.
  If the "after" mode is on, the recap R-23 is shown. The voice mode is switched off.
- **R-23. Session recap.** Shown in Russian, since the owner ordered it by choosing the mode:
  - the 3–5 main mistakes: "was → correct → why" (one line);
  - 3 phrases to repeat;
  - an offer to continue with something harder.

  The recap is stored as an event and shown as a card at the end of the session.

### Model reply
- **R-24. Reply protocol** — line by line, so that it can be parsed as it arrives:
  ```
  @say de: Fast perfekt! Natürlicher wäre: „Ich heiße Alex. Freut mich.“
  @say ru: (only on an explicit request) …
  @fix: Mir gefällt in Rostock → Mir gefällt an Rostock | an + place: "likes something in a city" (ru) — gefallen an
  @hint de: Freut mich, Sie kennenzulernen. | Nice to meet you. (ru)
  @say de: Sag das bitte noch einmal.
  ```
  - `@say` lines are spoken and shown.
  - `@fix` is shown in the "as you go" mode. In the other modes it is only stored.
  - `@hint` goes into the hints.
  - `@heard: <phrase>` (added 2026-10-25, Q28) — how the assistant understood the user's utterance given the context: only likely
    recognition errors (words that sound alike) are corrected, the user's grammar is kept. It is shown small under the user's bubble
    ("understood as: …"), and is not spoken. The line is not needed if the transcript is right as it is.

  A line without a tag is treated as `@say` in the study language. Parsing errors do not break the turn and are logged as the metric `protocol_violation`.
- **R-25. System wrapper** (`PromptBuilder`) contains:
  - the role of a teacher-conversation partner, the study language, the level, the mode, the correction modes, who starts;
  - the rules: one question per turn, short phrases for the level, Russian only per R-17, R-21, the protocol R-24;
  - a description of the commands.

  The user's custom prompt, the summary and the utterances are passed in data markup (`<session_prompt>`, `<summary>`, `<transcript>`).
- **R-26. Language discipline.** Without an explicit request `@say ru` segments are not allowed (the eval rule `lang_discipline`).
  If the model broke the rule, the answer is still shown and spoken, and the violation is counted in the metrics.

- **R-51. Understanding with context** (added 2026-10-25, Q28).
  - Recognition gets a hint from the context: the assistant's last utterance, the session topic, the hint phrases (together with a bilingual seed).
  - The wrapper R-25 tells the model that the transcript was made with an accent and may contain wrongly heard words: the model answers what
    the user meant to say, when in doubt briefly asks again in the study language, and does not count words that sound alike as mistakes (R-21).
  - Pronunciation is still not commented on (R-21, Q7). Checked by the `asr_accent` cases of the `dialog` eval.

- **R-52. Limits and usage** (Q29, external review 2026-10-25).
  - Each request to a model writes a safe usage record: time, purpose (dialog, phrases, summary, recap, eval), provider, model,
    status, the kind of limit (RPM/RPD/TPM/TPD), `retry-after`, input/output/cached tokens and the remainders from the headers — if the provider gave them;
    missing values stay empty. The text of the utterances and the keys are not written.
  - A refusal message names the kind of limit and the retry time from the provider's data; if there is no data, it says so.
  - The chain skips in advance a step whose remaining tokens per minute are less than the estimate of the request.
  - The dispatcher: the answer to the user's utterance always goes first; topic phrases, the summary and the recap wait for the end of the turn and start
    only if the quota is sufficient.
  - Evals: a budget per run (by default 10 cases of one model), a stop at `retry-after` > 60 s with a partial report, a correct cancel;
    mass runs only at night (Q29).
### Hints and vocabulary
- **R-27. The "Hints" panel** (the right column of the mockup). Four sections:
  - "Topic phrases" — 6–8 phrases with a translation. Generated by a separate background request at the start of the session and do not delay the first turn;
  - "Corrections" — from `@fix`;
  - "How to say" — from R-16;
  - "Vocabulary ★" — phrases marked with a star in all sessions.

  Each phrase has three actions:
  - ▶ listen: the voice of the phrase's language, works without a network;
  - translation: shown under the phrase;
  - ★ save to or remove from the vocabulary.

  Listening does not break the conversation: while listening, the microphone temporarily does not listen, and if the assistant is speaking, the phrase is queued.
  The panel is collapsed with a button with a book icon.
- **R-28. Vocabulary.** Shared by all sessions, with a language filter. Synced by the events `phrase.starred` and `phrase.unstarred`.

### Models and the chain
- **R-29. The chain** — a port of `ProviderChain` from Interview Copilot with the following differences:
  - a step is a "provider + model + key" triple. A provider has an **unlimited number of keys** (Q13); the steps are built in order: provider → model → key;
  - the move to the next step: 429, 5xx, a network error, a model refusal, no first token within 6 s (configurable from 2 to 15);
  - an invalid key (400, 401, 403) disables **this key**, not the provider. The key is marked "invalid" in the settings;
  - a pause for failed steps: for `retry-after` if the header is present, otherwise for 300 s. Counted per "key + model" pair;
  - parallel launch (hedge) is off by default.

  If the chain is exhausted — S-18. Each answer carries a small "provider · model" label.
- **R-30. Providers** — only free ones, through an OpenAI-compatible API:
  - **Groq** — main;
  - **Mistral** (free tier) and **OpenRouter** (`:free` models) — fallback;
  - **"Custom OpenAI-compatible address"**.

  Gemini is not used (EU). Providers that require a card are not used.
  The model list is requested from the provider (`GET /models`), not taken from memory. The key is checked with the "Check" button.
- **R-31. Local model (iPhone only, LINGO-02).**
  - The last step of the chain. Called when the cloud is unavailable, or manually through the source switch "On device".
  - GGUF format through llama.cpp. The concrete model is chosen by F-04 and F-07.
  - The model is downloaded inside the app over Wi-Fi with a SHA256 check, not embedded in the IPA.
  - The KV cache of the system wrapper is reused between turns. The context is at most 4096 tokens.
- **R-32. Source indicator** (the "On device ▾" badge on the mockup). Values:
  - "Groq · <model>";
  - "On device · <model>" (iPhone only);
  - "No network".

  On click — a choice: "Auto (chain)" or a concrete step.
- **R-33. The Mac without a network** — S-17. There is no local model on the Mac (Q19, confirmed in Q29).

### Storage and sync
- **R-34. Local storage.**
  - The source of truth on a device is its own journal (JSON Lines, append only) in Application Support.
  - Plus a local cache of the journals of other devices.
  - Writing: right after the event, with `fsync`.
  - The session index is built from the journals at start.

  The app does not depend on the availability of the sync folder.
- **R-35. Event.** Fields:
  - `v` — the schema version;
  - `id` — a ULID;
  - `device`, `seq` (grows on the device), `lamport`, `ts` (UTC);
  - `type`, `session`, `payload`.

  Types:
  - `session.created`, `session.updated`, `session.deleted`;
  - `message.created`, `message.edited`, `message.interrupted`;
  - `summary.updated`, `fix.recorded`, `hint.added`;
  - `phrase.starred`, `phrase.unstarred`;
  - `session.ended`, `session.resumed`.

  Unknown types and fields are kept and ignored.
- **R-36. Sync folder.**
  - The user chooses the folder through the system file picker: `UIDocumentPicker` on iOS, `NSOpenPanel` on the Mac.
  - Access is stored as a security-scoped bookmark. Paid developer features (iCloud entitlements, CloudKit) are not used.
  - Structure: `Lingo/v1/devices/<deviceId>/journal-<yyyy-mm>.jsonl` and `device.json` (the device name, the version).
  - Each device writes **only** to its own folder. Other journals are read through `NSFileCoordinator`,
    files not yet downloaded from iCloud are requested for download.
- **R-37. Merge.**
  - A union by the event `id`.
  - The order of messages: (`ts`, `device`, `seq`).
  - Changeable session fields (title, settings, deletion): the event with the larger `lamport` wins, on a tie the one with the larger `device`.
  - `message.edited` is applied to its message by the same rule.

  Messages are never overwritten and never lost. Duplicates are excluded by the unique `id`.
- **R-38. When to sync.** At launch, on returning to the active state, every 60 s while the app is active,
  after a session ends and on the "Sync" button.
  - The status in the sidebar: "Synced at HH:MM", "Waiting for iCloud", "Folder unavailable", "Not set up".
  - On own messages ✓ means saved locally, ✓✓ means written to the sync folder (the check marks of the mockup).
  - Sync never blocks the conversation.
  - The latency between devices is determined by iCloud. The interface does not promise instant delivery.
- **R-39. Resilience.** A truncated last line of a journal is ignored and rewritten at the next write.
  A corrupted line is skipped with a metric. A journal of a newer schema version is read in "read only" mode with a warning.

### The Mac interface (design: [lingo-mac.webp](../../design/lingo-mac.webp) + [DESIGN.md](../../../DESIGN.md))
- **R-40. A three-column window.**
  - **Left:** the Lingo logo, "+ New session", the English/Deutsch segment, "My sessions", the sync status at the bottom.
  - **Center:**
    - the header: the title, the subtitle "<mode> in <language>", the source badge R-32, the gear of the session settings;
    - the message feed;
    - the voice panel;
    - the input field with a send button.
  - **Right:** "Hints" (R-27).

  The minimum window size is 1100×700. Below a width of 1280 the right column collapses into a slide-over one. Colours, fonts, spacing and radii — only from DESIGN.md.
- **R-41. The feed.**
  - The user — on the right: a blue bubble, the time, ✓/✓✓, a language label, an avatar.
  - The assistant — on the left: a dark bubble, a robot avatar, the time, the label "provider · model".
  - A `@fix` correction in an answer — a highlighted block inside the bubble.
  - Russian segments (R-17) are marked with a dimmed background.
  - A click on the assistant's bubble repeats the speech, a click on the user's bubble edits it (R-09).
- **R-42. The voice panel.**
  - The states of R-07: a microphone icon, a caption "Listening" etc., a wave following the sound level.
  - The buttons: "Pause" (round grey), "Finish" (round red), "I speak Russian", "Slow pace".
  - The pause slider R-10 is in the session settings, not on the panel.
- **R-43. Text input.** An alternative to voice. Enter sends, ⇧Enter inserts a line break. Commands work by text too.
- **R-44. App settings:**
  - **Keys and models:** providers, an unlimited list of keys for each (add, check, delete), the chain order, models from `GET /models`, the first-token timeout;
  - **Voice:** the voice and pace for en, de, ru; the pause T; the merge G; the recognition engine, if there are several;
  - **Sync:** the folder, the status, "Sync now";
  - **Data:** the path to the local journal, export to ZIP, deleting the local history (with a confirmation and an explanation that copies on other devices remain).
- **R-45. First launch.** A wizard of three steps:
  1. permissions for the microphone and speech recognition;
  2. a Groq key (can be skipped, then voice is inactive);
  3. the sync folder (can be skipped).

### The iOS utility app (LINGO-02, draft)
Not built in LINGO-01. Of R-47, LINGO-01 uses only the turn marks — for AC-02 on the Mac.
- **R-46. The measurement screen** (not the MVP: without sessions and the hints of R-27). Contents:
  - a choice of the recognition engine and the answer source (the chain or a local candidate);
  - the language and the voice;
  - a "Speak" button and a continuous mode with barge-in (R-10…R-12);
  - a feed of the latest turns;
  - real-time metrics;
  - a run over a set of audio files (soak);
  - a choice of the iCloud folder and a view of the journal: the number of sessions and messages, a checksum;
  - build information: the version, the build number, the bundle ID, the signature expiry date if it can be read.

  It uses the same core and journal format (R-34…R-39) as the Mac.
- **R-47. Metrics** (JSON Lines, exported to the sync folder and through "Share"):
  - turn marks: `speech_end`, `stt_final`, `llm_first_token`, `first_audio`, `reply_end`;
  - memory: `phys_footprint` and `os_proc_available_memory` once a second;
  - `thermalState`;
  - exit reasons from MetricKit (`MXAppExitMetric`) and a flag "the previous launch ended abnormally".

  The text of utterances is not written to the metrics, only lengths and languages.

### Security and operation
- **R-48. Keys** are stored only in the Keychain. They are not logged, not shown after saving (only the last 4 characters) and are passed only in an HTTPS header.
- **R-49. Logs** — `os_log` (subsystem `com.itmax04.lingo`). The text of utterances and answers is not written to the logs, metrics and identifiers are.
- **R-50. Mac resources.** During a 20-minute voice session the whole app takes no more than 1.2 GB of memory.

### A mini threat model
| Asset | Threat | Measure |
|---|---|---|
| API keys | A leak into Git, logs, chat, the sync journal | Keychain (R-48), keys are never written to the journal, `scripts/secret-scan.sh` (AC-13), a rule in CLAUDE.md |
| The dialogue history | Passing to third parties | Accepted by the owner for the free providers (Q11); audio does not leave the device (R-08) |
| Journals in iCloud | A conflict, corruption, loss | One writer per file (R-36), a merge without overwriting (R-37), a local source of truth (R-34), resilience (R-39) |
| GGUF models | Substitution on download | SHA256 from the repository, only HTTPS and official repositories (R-31) |
| Model behaviour | A custom prompt or the utterance "ignore the instructions" | The model has no tools, the answer is only shown and spoken; the prompt and utterances are marked as data (R-25) |
| iOS signing | The 7-day period expired, the app does not start | Renewal in SideStore (F-02); the data stays in the container (F-03) |
| Groq accounts | A block for bypassing limits | The owner's decision and responsibility (A-4); on a block the chain moves on to other providers |

## 4. iPhone checks — a draft for LINGO-02
**Not executed in LINGO-01 (Q27).** The table is kept as a draft of the brief's requirements for the iPhone. The target iPhone is chosen in LINGO-02. The numbers P- and H- in the table are taken from plan v1 (commit `9e8daa0`); LINGO-02 will assign them anew.
They are carried out only on a physical iPhone with the app installed through SideStore. The simulator and a single run of the interface do not count as evidence.
Each check: a command or method → numbers → evidence (a screenshot, a metrics file) in `docs/changes/LINGO-02/evidence/`.
The **mandatory** checks are taken from the brief. If a mandatory check fails, the work of LINGO-02 stops and options are offered to the owner (section 6).

| F | Mand. | Check | PASS threshold | Method |
|---|---|---|---|---|
| F-01 | yes | Installation through SideStore | The utility app is installed from the IPA through SideStore on the iPhone Air and starts | H-1, H-3; screenshots of SideStore and the app, the SideStore and iOS versions |
| F-02 | yes | Renewing the signature without the Mac | "Refresh" in SideStore with the Mac switched off succeeds, the signature period moves by 7 days, the app starts | H-5; screenshots of the periods before and after |
| F-03 | yes | History survival | After a restart, an iPhone reboot, installing a new build over the old one and renewing the signature: the number of sessions, messages and the journal checksum match; access to the folder is restored by itself or by one repeated choice (record exactly how) | H-5; the journal screen R-46 before and after |
| F-04 | yes | The full local loop (airplane mode) | For the chosen model 3 runs × 50 turns (en, de, ru, mixed) with a context of ≈2000 tokens: 0 crashes and 0 terminations by the system; from `speech_end` to `first_audio` the median ≤ 8 s, p90 ≤ 10 s; the minimum of `os_proc_available_memory` ≥ 150 MB | P-08 soak + H-4; `scripts/metrics.py` |
| F-05 | no | The cloud loop on the iPhone | Median ≤ 8 s, p90 ≤ 10 s; with forced 429s and a wrong key the answer comes from the next step of the chain | P-08 + H-4 |
| F-06 | yes | Recognition of en, de, ru and mixed speech | Live phrases (H-4, `evals/live-script-ios.md`): 20 per language and 15 mixed. A phrase is understood if WER ≤ 25% or the owner accepted it. Threshold: ≥ 80% understood phrases in each language. Mixed: ≥ 60% in auto mode and ≥ 80% with the "I speak Russian" button. The language of pure phrases is detected correctly in ≥ 90% | P-04 synthetic + H-4 live |
| F-07 | yes | Answer quality | The `dialog` eval: the rules are met in ≥ 90% for the chain and in ≥ 70% for the chosen local model; `no_pronunciation` — 100%. The owner's blind assessment of 20 answers: "acceptable" ≥ 80% for the cloud and ≥ 60% for the local model | P-07 + H-6 |
| F-08 | yes | History through an iCloud Drive folder | The folder is chosen without paid entitlements; a write from the iPhone is visible on the Mac and back; the median appearance delay is recorded (no threshold); S-19: 0 losses and 0 duplicates | H-3, P-08; `scripts/sync-check.py` |
| F-09 | no | Barge-in | Through the speaker and through AirPods: the speech stops ≤ 0.7 s in ≥ 9 of 10 attempts; false stops from its own speech ≤ 1 per 10 answers | H-4 |
| F-10 | no | Locked screen | A cloud continuous dialogue works for 5 min with a locked screen. A local model in the background is a measurement (work without the GPU is expected), with the F-04 latency threshold as a guide | H-4 |

**Choosing the local model.** The candidates from ADR-0001 are compared by F-04 (latency, memory, stability) and F-07 (quality).
The choice, the table of measurements and the reasons are recorded in ADR-0001 and `feasibility-report.md`.
For each candidate the report shows the memory peak and the speed separately. They show which candidates may suit the iPhone 11 later (A-9).
Figures from the iPhone Air are not evidence that it works on the iPhone 11.
If no candidate passes F-04 and F-07 at the same time, that is a failure of a mandatory requirement, and section 6 applies.

## 5. Acceptance criteria of the MVP for the Mac
| AC | Criterion | How to check |
|---|---|---|
| AC-01 | The three modes and the session setup work per S-01, R-02, R-03; no "Thomas/A2" defaults | Unit tests of `PromptBuilder` and the setup screen + a live session H-4 in each mode |
| AC-02 | Voice by button and continuous mode: from `speech_end` to `first_audio` the median ≤ 8 s, p90 ≤ 10 s (on the Groq chain), the actual figures in the report | H-4 from `evals/live-script-mac.md`, `scripts/metrics.py` |
| AC-03 | Barge-in on the Mac: a stop ≤ 0.5 s in ≥ 9 of 10; merging per S-05 | H-4 + unit tests of `TurnController` |
| AC-04 | Commands: the detector ≥ 95% correct on the `commands` eval (≥ 90 phrases ru, de, en, including negative examples); "repeat" starts to sound ≤ 0.3 s | `scripts/run-evals.sh commands` + H-4 |
| AC-05 | Russian only on an explicit request, with a return to practice: the cases `explain`, `ru_utterance`, `lang_discipline` in the `dialog` eval ≥ 90% | `scripts/run-evals.sh dialog` |
| AC-06 | Correction modes and their combinations per S-13…S-15; the recap R-23 contains 3–5 items | Unit tests of the `@fix` aggregator + the `dialog` eval (the `correction_*` cases) + H-4 |
| AC-07 | Sessions are saved, continue with the context policy R-04, survive a restart | Unit tests of the storage + a manual restart |
| AC-08 | Sync of two writers in one iCloud folder (Lingo + `lingo-eval sync-write` as the second device): S-19 — 0 losses and 0 duplicates; the statuses R-38; S-20 without loss of the local history. A check with a real iPhone belongs to LINGO-02 | `scripts/sync-check.py` + P-10 |
| AC-09 | The chain: 429, a wrong key and a timeout lead to the next key or model with a label; an unlimited number of keys; S-18 | Unit tests with a mock provider + a manual check with a deliberately wrong key |
| AC-10 | Hints: four sections, listen, translation, ★; listening does not break the voice turn | H-4 + unit tests of the `@hint` parsing |
| AC-11 | The interface matches the mockup and DESIGN.md | A window screenshot next to `lingo-mac.webp` in report.md, the owner's assessment in H-4 |
| AC-12 | The Mac without a network: S-17 | A manual check with Wi-Fi switched off |
| AC-13 | The repository has no keys and personal data (`private/` in .gitignore) | `scripts/secret-scan.sh` = 0 findings |
| AC-14 | The build is reproducible: `swift build`, `swift test`, `scripts/build-app.sh`, `scripts/check-core-ios.sh` (the core builds for iOS) on a clean clone | The commands in report.md with their output |
| AC-15 | The Mac memory ≤ 1.2 GB over a 20-minute voice session (R-50) | `footprint` once a minute, the maximum in report.md |
| AC-17 | A control 30-minute session (Q29, the external review protocol): the conversation goes on for 30 minutes without a refusal from an exhausted quota; the number of turns, the latency, the token usage and the background requests are recorded; `retry-after` is respected, a cancel stops new calls | H-4, the usage log R-52, `scripts/metrics.py` |
| AC-16 | Recognition on the Mac: 20 live phrases for each of en, de, ru and 15 mixed. A phrase is understood if WER ≤ 25% or the owner accepted it. Threshold: ≥ 80% understood in each language; mixed — ≥ 60% in auto mode and ≥ 80% with the "I speak Russian" button; the language of pure phrases is detected correctly in ≥ 90% | H-2 and H-4 from `evals/live-script-mac.md` |

## 6. If a mandatory check fails
Relates to LINGO-02. In LINGO-01 the rows F-06 (for AC-16) and F-08 (for AC-08) apply in the same way.
The executor stops and shows concrete figures and evidence. Then it offers options from the table below or its own, with pros and cons.
Paid services, replacing the iPhone with a Mac client and passing the utility app off as the MVP **do not count** as options.

| Failure | Possible options (the owner decides) |
|---|---|
| F-01/F-02: SideStore does not work on the installed iOS | Wait for a SideStore fix (the release is tracked); another free installation method with renewal on the device, if there is one at the time of the check; a free signature from Xcode for 7 days — **breaks the independence from the Mac** and is offered only as a temporary measure |
| F-03: the history is lost on an update or a renewal | Move the local storage into the sync folder as the main place with a local cache; restore from the folder at start |
| F-04: the local loop does not fit the memory or the latency | A smaller model with worse quality; local mode only for short exercises; the local model only as a fallback path without a network with an explicit label; dropping the local loop (the owner's decision is needed: this changes the brief) |
| F-06: mixed speech | Only an explicit language switch with a button; recognising the Russian and foreign-language parts with different engines by segments (if the memory allows) |
| F-07: the quality of the local model | The same as for F-04; the cloud is the main path, the local model is the emergency one |
| F-08: the iCloud folder is unavailable without paid features | A manual export and import of the journal through "Files"; sync over the local Wi-Fi network between the devices (Bonjour); another free folder in "Files" |

## 7. Decisions and assumptions
- **Facts:**
  - environment: M1 8 GB, macOS 15.7.2, Xcode 26.3, ≈14 GB free, ffmpeg and gh are present (account itmax04) — checked 2026-10-25;
  - the iPhone belongs to LINGO-02 (Q27). The iPhone Air (iPhone18,4) on iOS 27.0 is paired with the Mac, "Developer Mode" is off — checked with `devicectl` on 2026-10-25;
  - the information on SideStore on iOS 27 and on the free tiers of Groq, Gemini, Cerebras, OpenRouter comes from third-party sources as of 2026-10-25, and P-00 re-checks it.
- **Owner decisions:** Q1–Q27 (intent.md).
- **Assumptions:** A-1…A-9 (intent.md). The executor's decisions made along the way are recorded in handoff.md.
