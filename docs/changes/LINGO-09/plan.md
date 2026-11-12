# LINGO-09: Plan

ID: LINGO-09-plan · Status: **draft**, waiting for the owner (H-09-0) · Version: 1 · Date: 2026-11-12 · Risk: R2 · Links: [intent.md](intent.md) · [spec.md](spec.md) · [handoff.md](handoff.md)

**No code before the owner accepts these documents (H-09-0).** One step = one issue and one PR (≤ 600 changed lines without snapshots,
fixtures and catalogue content), each with tests, an independent AI review and green CI before the merge. Swift work is done locally on
the owner's Mac (AGENTS.md §10). Batch macOS CI runs. Model calls during development: single daytime requests only, except step M-2.
Tier = model tier of the step: strong (only for a named reason), standard (implementation from this plan), light (mechanical edits, docs).

| Step | Content | Requirements | Checks | Tier |
|---|---|---|---|---|
| M-1a | Data, contracts and parsing: `tone` with tolerant decoding, presets, `local` message mark, silent tags `@next`, `@help`, `@tutor`, schema, fixtures, TypeScript decoders. No behaviour change | MR-01, MR-03, MR-11…MR-14 (parsing), MR-44, MR-45 | MAC-01, MAC-02, MAC-06, MAC-27 | standard |
| M-1b | Prompt: tone block, level sentences, limits, judge-first protocol, rule 6 wording, exclusions for warm-up and exams, blame filter, tone snapshots and the eval cases of M-2 | MR-02, MR-05…MR-10, MR-15, MR-47 | MAC-03, MAC-05, MAC-07 | strong: safety limits and the interplay with rule 7 are design with open trade-offs |
| M-2 | Model check: one live run, `evidence/model-check.md`, decision under MR-36; prompt fixes if required | MR-35, MR-36 | MAC-23 | standard |
| M-3a | Local lines: catalogue in German and English, export, deny-list test, independent review of the texts | MR-21 | MAC-12 | standard |
| M-3b | Drill and silence in the turn loop: comparison, flow, `drill.result`, card derivation, silence timers and settings | MR-16…MR-20 | MAC-08…MAC-11 | strong: concurrency in the turn loop (overlapping turns, cancellation) |
| M-4 | Interface and control: consent, Tone section, header label, live popover, Calm (button, key, command), prosody, Russian strings | MR-04, MR-26 (Tone section), MR-27, MR-28, MR-30 | MAC-04, MAC-15…MAC-17, MAC-19 | standard |
| M-5 | Help in three steps: panel, key, `help` command, `hint.shown` | MR-22, MR-23 | MAC-13 | standard |
| M-6 | Conflict scenarios: twelve scenarios, optional fields, export, Conflicts tab, Teacher card, two voices in a combined session | MR-24…MR-26, MR-31 | MAC-14, MAC-15, MAC-19 | standard |
| M-7 | Ending: debrief request and card, counts, self-rating | MR-29 | MAC-18 | standard |
| M-8 | Pauses and interjections: tail recognition, connective list, measurement, interjection rules | MR-33, MR-34 | MAC-21, MAC-22 | strong: audio and recognition concurrency with a kill criterion |
| M-9 | Voice probe (only with the owner's yes to each installation) | MR-32 | MAC-20 | light |
| **H-09-1** | **Owner: try a strict session, a conflict scenario and a combined session; decide on the voice and on starting the experiment** | | MAC-22, MAC-29 | owner |
| X-1 | Experiment protocol and material: `experiment-protocol.md`, 64 expressions with situations, seeded assignment | MR-37, MR-38 | MAC-24 | standard |
| **H-09-2** | **Owner: accept the experiment protocol** | | MAC-24 | owner |
| X-2 | Trial sessions: activity `trial`, blocks, fixed tone, timer, lock, abort | MR-39, MR-40 | MAC-25 | standard |
| X-3 | Test, blind grading, real-life mark, export and report script | MR-41…MR-43 | MAC-25, MAC-26 | standard |
| M-10 | Documents and `report.md` | MR-48 | MAC-28 | light |
| **H-09-3** | **Owner: accept LINGO-09** (the experiment's result follows later as a dated note) | | MAC-29 | owner |

Order: M-1a → M-1b → M-2 → M-3a → M-3b → M-4 → M-5 → M-6 → M-7 → M-8 → M-9 → H-09-1 → X-1 → H-09-2 → X-2 → X-3 → M-10 → H-09-3.
M-2 comes right after the prompt, because everything later is wasted if the free model does not play the role. M-3a comes before M-3b
and M-4, because their tests need the lines. M-8 comes late, because it carries a kill criterion and nothing depends on it. The
experiment starts only after the owner has tried the modes.

The owner may cut the plan at H-09-1 (modes only) or drop M-8 and M-9; the report then lists the dropped requirements as NOT RUN with
that decision.

## Risks
| Risk | Mitigation |
|---|---|
| The free model softens, refuses or leaves the role | M-2 before the rest; MR-36 thresholds; no attempt to defeat a refusal; the label on levels 4–5 |
| Invented mistakes to stay in character | Judge-first protocol (MR-10), blame filter (MR-15), ten correct turns in M-2 |
| Harsh content crosses the limits | MR-06 in the prompt, deny-list tests on every local text, independent review of M-1b and M-3a, Calm always available |
| Pronunciation remarks (rule never relaxed) | Rule 3 verbatim, deny-list with pronunciation words, `PronunciationFilter` on the debrief, the M-2 check |
| Quota: drills and pressure double the turns | Local comparison and lines (MR-18, MR-20), `@next` in the same reply, help without requests (MR-22) |
| The longer prompt and extra lines exceed the budget | MR-08 limits measured in tests; silent lines are short |
| A drill mistakes a real answer for a failed repeat | Three outcomes with "not a repeat" (MR-17), golden cases shared by Swift and TypeScript |
| Interjections are recognised as the learner's speech | Only with voice processing on (MR-34); the owner's listening check at H-09-1; "off" setting |
| Tail recognition is too slow on the owner's Mac | Kill criterion in MR-33; M-8 is last and optional |
| A second voice or another engine costs memory (budget 1.2 GB) | System voices only in this plan; the probe measures before any decision (MR-32) |
| Older build or rollback reading new sessions | Additive fields, tolerant decoding, test with the current decoders (MR-45) |
| The experiment is too small or biased | 2 × 32 in matched pairs, blind grading, protocol accepted first, exclusions recorded (MR-37…MR-42) |
