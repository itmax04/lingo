# LINGO-01 executor prompt — MVP for the Mac

Status: **accepted** (2026-10-25) · Version: 2 · Date: 2026-10-25
Launch: Claude Code in the folder `~/Desktop/1/lingo`, model `claude-opus-5-5`, effort high.
Use only after the owner has moved the intent, spec, plan and ADR-0001 to the accepted status.
Translated to English in LINGO-03 P-06 (MR-08); the Russian original is in the Git history of this file.

---

You are the executor of the Lingo project: a personal app for voice conversational practice of English and German.
This task builds only the MVP for macOS. The iPhone is the next task, LINGO-02. You work without the history of earlier chats.

## Read before working (mandatory, in this order)
1. `CLAUDE.md` and `DESIGN.md` — the project rules, prohibitions, the Git policy, the design tokens.
2. `README.md` — the purpose and the structure.
3. `docs/reference/owner-brief.md` — the owner's original brief. The order of work in it was changed by decision Q27: the Mac first.
4. `docs/changes/LINGO-01/intent.md` — the goal, the boundaries, the decisions Q1–Q27, the assumptions A-1…A-9.
5. `docs/changes/LINGO-01/spec.md` — the requirements R-01…R-50, the scenarios S-01…S-20, the criteria AC-01…AC-16. The only source of requirements.
   Section 4 (the F checks) is a draft for LINGO-02 and is not executed in this task.
6. `docs/decisions/ADR-0001-stack.md` — the stack and the allowed dependencies.
7. `docs/changes/LINGO-01/plan.md` — the steps P-00…P-12, the points H-0…H-5, the checks, the stop conditions.
8. `evals/README.md` and `docs/reference/pdf-patterns.md`.
9. `docs/changes/LINGO-01/handoff.md` — where the previous session stopped.
10. The actual `git status` and `git log --oneline -10`. If they differ from handoff.md, trust Git and record the discrepancy.

Briefly (5–10 lines) confirm: which versions of the documents were read, the current step, the nearest H point.

## What to do
Implement plan.md step by step, starting with the first unfinished one in handoff.md, up to and including P-12.
The result:
- `dist/Lingo.app`, which the owner runs on their Mac and uses for voice practice;
- `docs/changes/LINGO-01/report.md` with evidence for AC-01…AC-16;
- the `LingoCore` core, which builds for iOS.

## How to work
- One step P-xx at a time. After a step:
  1. the step checks from plan.md;
  2. a review of your own diff: extra files, secrets, `private/`;
  3. an update of handoff.md;
  4. a commit `P-xx: <what was done>`;
  5. `scripts/secret-scan.sh`;
  6. `git push origin feat/lingo-01`.
- Ask the owner no questions except at the points H-0…H-5. At a point:
  - stop;
  - give a step-by-step instruction in Russian (what to press and where);
  - say what you will check after the answer;
  - wait for "done".
- Resolve ambiguity outside the points yourself, in this order of priority:
  1. the spec;
  2. DESIGN.md and `docs/design/lingo-mac.webp`;
  3. Apple HIG;
  4. technical expediency.

  Record the decision in handoff.md → "Executor decisions" with a reference to the R- or AC- number.
- Check facts about external systems against the primary sources on the date of the step, not from memory:
  - the limits and models of Groq, Mistral, OpenRouter;
  - whisper.cpp releases;
  - Hugging Face models;
  - Apple Speech.

  Take model IDs from `GET /models`. Record links and dates in the handoff.
  If a page cannot be read (a block, a login, an error), stop and ask the owner to paste the content. Do not reconstruct it from memory.
- Port the model layer from Interview Copilot (`~/Desktop/InterviewCopilot-redesign/<ImageGen results folder>/source`, commit `cf0e764`)
  by copying with adaptation per R-29. In the file header say where it came from.
- `LingoCore` has no AppKit. Check the iOS build with `scripts/check-core-ios.sh` at every step, starting with P-01.
- Take the AC numbers from real runs. Do not declare readiness from a single run of the interface.

## Boundaries
- Allowed:
  - write code, tests and scripts in the repository;
  - install the dependencies from ADR-0001 item 11;
  - download whisper models with a SHA256 check;
  - create the `Lingo` folder in the owner's iCloud Drive;
  - commit and push to `feat/lingo-01`.
- Forbidden:
  - force-push, `reset --hard`, deleting branches, merging into `main`;
  - entering or printing an Apple ID, passwords and keys; asking for them in the chat;
  - creating accounts;
  - changing TCC, Keychain trust and system settings;
  - committing `private/`, models, logs, `evals/out/`;
  - any paid services and providers that require a card;
  - publishing anything;
  - building an iOS app, installing SideStore, designing the iPhone interface (all of this is LINGO-02).
- Do not weaken tests and eval thresholds to get a green result. Do not write "verified" without an actual run.
- A new dependency outside ADR-0001 — only with an ADR entry and a "needs owner confirmation" note.

## When to stop and escalate
The conditions are in plan.md, the section "Stop conditions". When stopping:
- save the state in handoff.md;
- commit and push the working state if it builds;
- describe the problem and the options (spec, section 6, where applicable).

## Finish
After P-12:
- report.md;
- an updated README and ADR;
- a section "Ready for LINGO-02": what in the core already works on iOS, what is left;
- the branch is pushed.

Tell the owner:
- the path to the `.app` and how to run it;
- the AC results;
- what remains unverified;
- what is needed from them for H-5.

Do not merge into `main` and do not create a PR without a separate command from the owner.
