# LINGO-01: Intent — Mac MVP

ID: LINGO-01-intent · Status: **accepted** (2026-10-25) · Version: 2 · Date: 2026-10-25
Result owner: itmax04 · Links: [spec.md](spec.md), [plan.md](plan.md), [ADR-0001](../../decisions/ADR-0001-stack.md),
[original brief](../../reference/owner-brief.md), [PDF patterns](../../reference/pdf-patterns.md), [DESIGN.md](../../../DESIGN.md)
Source of decisions: a brainstorm in a Claude Code session on 2026-10-25, answers Q1–Q29 (table below).
Approval: the owner accepted the v2 set (intent, spec, plan, ADR-0001, evals/README, DESIGN.md, executor-prompt) with assumptions A-1…A-9 —
the answer "let's start" in the Claude Code session on 2026-10-25 after commit `2458d1e`.
Version 2: the owner decided to start with the Mac and adapt for the iPhone later (Q27). Version 1 is in Git, commit `9e8daa0`.
Language: the repository is in English since 2026-10-26; the owner's quotes are translated from Russian.

## Problem
The owner is learning German (currently living in Germany) and English. Today they practise speaking in ChatGPT's voice mode
(example: a 16-page PDF). The downsides of this approach:
- the service is paid;
- the role and rules have to be set with a long prompt every time;
- the assistant "rates pronunciation" from the speech-recognition transcript;
- there is no convenient personal phrase vocabulary;
- there is no shared history between the MacBook and the iPhone without a subscription.

## Desired outcome
Two separately installable **Lingo** apps (macOS and iOS) for **voice** conversation practice in English and German:
1. The owner speaks, the assistant answers by voice. There is a push-to-talk button and a continuous dialogue; the assistant can be interrupted.
2. On an explicit request the assistant explains in Russian and returns to the practice.
3. Commands "repeat", "slower", "how do I say", "explain", "let's continue".
4. Error correction in the chosen modes: as we go, after the conversation, on request.
5. Sessions are saved and can be continued. History is shared between devices through an iCloud Drive folder.
6. Everything is free.

Voice works as a pipeline: on-device speech recognition → language model reply → on-device speech synthesis (Q24).

### What LINGO-01 delivers
**A Mac MVP** — a complete app following the [lingo-mac.webp](../../design/lingo-mac.webp) mockup with every feature from the brief:
three modes, push-to-talk and a continuous dialogue with barge-in, Russian on request, commands, correction modes,
continuable sessions, hints and a vocabulary, history in an iCloud Drive folder.
The `LingoCore` core is written so that it also builds for iOS. Then the iPhone app in LINGO-02 is added without reworking the logic or the history format.

### What LINGO-01 does NOT deliver
**Everything about the iPhone is LINGO-02** (Q27). That includes:
- choosing the target iPhone: iPhone Air or iPhone 11;
- feasibility checks on a real device: SideStore, the local loop, languages, iCloud, persistence — spec section 4, F-01…F-10;
- choosing a local model by measurements;
- the UI according to the owner's design (Q16).

The observable metrics and checks of this intent are AC-01…AC-17 in spec.md.

## Users and systems
- **User:** one, the owner. Languages: Russian — native; German and English — being learned.
- **Devices:**
  - MacBook Air M1 8 GB, macOS 15.7.2, ≈14 GB free (as of 2026-10-25), Xcode 26.3;
  - iPhone — in LINGO-02 (Q27). For reference, as of 2026-10-25:
    - **iPhone Air** (iPhone18,4) on iOS 27.0, connects over USB-C, Developer Mode off, paired with the Mac;
    - **iPhone 11** (A13, 4 GB) from the original brief: there is no Lightning cable (Q26).
- **Systems:**
  - the owner's iCloud Drive;
  - Groq API, free tier, the owner's keys;
  - other free OpenAI-compatible providers per ADR-0001;
  - Hugging Face — for the whisper speech-recognition models;
  - GitHub, the private repository `itmax04/lingo`.
- **Reuse:** the model layer is ported from Interview Copilot:
  - `ProviderChain`, `ProviderHealth`, `SSEClient`, `KeyVerifier`, `KeychainStore`;
  - source `~/Desktop/InterviewCopilot-redesign/Результат-ImageGen/source/Sources/CopilotCore/LLM`, the branch with commit `cf0e764`.

## Scope
In LINGO-01:
- the shared `LingoCore` core: session model, event journal and sync, model chain, reply protocol,
  commands, context policy;
- macOS: the Lingo app per the mockup — sessions, three modes, voice, commands, corrections, hints, vocabulary,
  sync, settings, keys;
- evals: dialogue quality (a set based on the PDF patterns), commands, end of utterance, recognition (synthetic recordings), sync (merging).

Not in LINGO-01 (candidates for the next intents):
- the iPhone app, the F-01…F-10 checks and a local model for the iPhone (LINGO-02, Q27);
- pronunciation assessment in any form (Q7);
- a local model on the Mac: offline, only the history is available on the Mac (Q19);
- languages other than en, de and ru;
- paid providers, subscriptions, App Store or TestFlight distribution, notarization.

## Constraints
- **Budget:** $0. Paid APIs, subscriptions and a paid Apple developer account are excluded.
  If a provider requires a card, it is not used.
- **Mac:** 8 GB of memory; offline only the history works (Q19; confirmed in Q29). The whole app uses at most 1.2 GB of memory (R-50).
- **The brief's iPhone requirements** (independence from the Mac, SideStore, a fully local loop) remain and are checked in LINGO-02.
- **Latency:** reply quality comes first. A pause of up to 8–10 s from the end of an utterance to the start of the reply is acceptable (Q3).
- **Data:** dialogue text may be sent to a free provider, even if it stores it or trains on it (Q11).
  Audio never leaves the device and is never written to disk, except synthetic recordings for evals.
- **EU region (Q10):** the free Gemini API is not used.
- **Keys:** only in the Keychain. They never get into the repository, logs or chat.
- **Sync:** not instant. iCloud sets the timing, and the UI says so honestly.
  History is kept locally even when sync is unavailable.
- **Model memory:** limited. The assistant sees a session summary and the last utterances, not the whole history. The UI says so.
- **Mac disk:** ≈14 GB free. Models used for measurements are deleted after the choice, except the chosen one.
- **Git:** a private repository; work happens on a feature branch (`feat/lingo-01`, then `main-en` since 2026-10-26), no force-push and no merge into `main` without the owner's decision (Q22).
- **Executor:** Claude Code, `claude-opus-5-5`, effort high. Questions to the owner are asked only at checkpoints H-0…H-5.

## Owner decisions (brainstorm 2026-10-25)
| # | Question | Decision |
|---|---|---|
| Q1 | SideStore on the iPhone | Not installed. The owner installs it following the executor's instructions |
| Q2 | A cable for measurements | Available (clarified in Q26: USB-C for the iPhone Air; no Lightning for the iPhone 11) |
| Q3 | Acceptable reply latency | Quality matters most; a pause of up to 8–10 s is acceptable |
| Q4 | How voice practice happens | With headphones (AirPods), through the speaker, with the screen locked — all are needed |
| Q5 | Mixed speech if recognition is poor | Both options: the language is detected per utterance automatically + an "I'm speaking Russian" button; the transcript can be fixed by hand |
| Q6 | When to switch to Russian | Only on an explicit request |
| Q7 | Pronunciation | Do not comment on it |
| Q8 | The model on the Mac | Instead of a local one — a free cloud API (for example, Groq) |
| Q9 | API architecture | As in Interview Copilot: on a limit — automatic fallback to the next key or model |
| Q10 | Region | EU (Germany) |
| Q11 | Dialogue text at the provider | Allowed; these are practice dialogues |
| Q12 | Session parameters | Three modes (questions, free conversation, custom prompt) + the user's own settings |
| Q13 | Groq keys | Any number of keys per provider |
| Q14 | Error-correction mode | Before a session starts the user chooses one or more modes |
| Q15 | Design | DESIGN.md from the Lingo mockup |
| Q16 | iPhone UI | Only the Mac for now. The iPhone comes later; the owner will send the design |
| Q17 | Order of work | First an iPhone check, then the Mac MVP |
| Q18 | The "Hints" panel | Topic phrases, corrected phrases, "how to say" answers, a personal vocabulary with a star. Each phrase: play, translation, save. The panel does not get in the way of the voice conversation |
| Q19 | The Mac offline | Only the history, no local model |
| Q20 | End of utterance in continuous mode | A pause whose length is set with a slider |
| Q21 | A local model on the iPhone | Stays the last link of the chain; the fully local loop is checked per the brief |
| Q22 | Repository | `~/Desktop/1/lingo` + a private GitHub repository |
| Q23 | Process | SDLC documents, as in Interview Copilot |
| Q24 | "It must be a voice model" | Confirmed: a voice app on a "recognition → model → synthesis" pipeline ("yes, prepare the SDLC documents") |
| Q25 | Target iPhone | "I want it on the Air, and then we adapt it for the iPhone 11 if needed". Replaced by Q27: the iPhone moved entirely to LINGO-02 |
| Q26 | Cable | There is no Lightning cable for the iPhone 11; the iPhone Air connects to the Mac over USB-C without problems |
| Q27 | Order of work (replaces Q17 and Q25) | "Let's start with the Mac after all, and then adapt it for the right iPhone". LINGO-01 is only the Mac MVP, the iPhone is LINGO-02 |
| Q28 | Recognition with an accent (after H-2, 2026-10-25) | The owner's proposal: "do not stop at word-for-word recognition, use the context so the model understands what the user meant", as in Interview Copilot. Accepted ("yes, I fully agree"): (1) the conversation context in the recognition prompt; (2) the model reconstructs the meaning from context and does not treat similar-sounding words as mistakes; (3) a `@heard` line — "understood as" under the user's utterance (R-24, R-51) |
| Q29 | Free cloud limits (after the external review, 2026-10-25) | The owner's goal is "no limits at all". Accepted: stage 1 — limit and usage diagnostics, an eval budget (only at night, in small batches), an 8-turn context + a token budget, a dispatcher (dialogue first), chain order by caching; stage 2 — Cloudflare Workers AI as a second free provider (the owner registers); stage 3 (a local model on the Mac) was first accepted, then cancelled by the owner ("I changed my mind, don't install a local model on the Mac") — **Q19 stays in force**, AC-15 unchanged. Colab Pro — not taken (paid; Colab's terms forbid service APIs). A 30-minute control session — the day after stage 1 |
| Q30 | Repository language (2026-10-26) | "The whole repository must be in English", with a branch where a person or another AI agent can easily understand the project. Accepted: branch `main-en` in `itmax04/lingo` (private), UI strings in a String Catalog (English in code, Russian translation), work continues on `main-en` |

## Assumptions (non-blocking; can be corrected at acceptance)
- **A-1.** Q24 is read as: a speech-to-speech model is not required. There are no free options available in the EU, and such models do not fit on the device.
- **A-2.** A Russian utterance without a request for an explanation (like P8 in the PDF) is an attempt to express a thought. The assistant:
  - gives a version in the target language;
  - asks the learner to repeat it;
  - does not switch to Russian itself.

  Explicit requests are: "explain", "in Russian", "what did you ask", "what does … mean", "why is it so", "translate".
- **A-3.** Correction modes are not preselected in the first session. Later sessions prefill the previous choice, but it is visible and can be changed on the setup screen.
  A session cannot start until at least one mode is selected.
- **A-4.** The owner is responsible for complying with Groq's terms when using several keys (Q13).
  As far as is known, keys of one organization share a common limit, and limits are counted per model.
  The executor does not create accounts and does not circumvent limits.
- **A-5.** The Mac app is signed with a local self-signed certificate, as in Interview Copilot.
  By default the existing "InterviewCopilot" certificate is used. The owner may create a separate "Lingo Dev" one at H-0.
- **A-6.** `LingoCore` builds for iOS from the first step (`scripts/check-core-ios.sh`). The journal format (R-34…R-39) is shared by the Mac and the future iPhone app.
- **A-7.** The AC thresholds were proposed by the executor based on Q3 and the brief. The owner accepts them together with the spec. The F-01…F-10 thresholds are a draft for LINGO-02.
- **A-8.** Level (A1–C2 or "custom text"), role and topic are set per session. There are no Thomas and A2 defaults.
- **A-9.** The iPhone decisions from the brainstorm (Q1, Q4, Q21, Q25, Q26) are kept as inputs for LINGO-02. The target iPhone is chosen there.
  According to the data found, Apple's built-in model does not support Russian and exists only on devices with Apple Intelligence.
  So the main local path for the iPhone is llama.cpp.

## Open questions
No blockers for the documents. Measurements will answer:
- which recognition engine on the Mac handles en/de/ru and mixed speech better: whisper.cpp or Apple (P-04);
- which free Groq models give the best quality on the `dialog` eval (P-05);
- whether macOS gives an app without a sandbox access to an iCloud Drive folder without extra permissions (P-10, H-3);
- whether system echo cancellation is enough to interrupt the assistant without headphones on the MacBook speakers (P-07, P-11).
