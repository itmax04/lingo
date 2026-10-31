# Glossary

| Term | Meaning |
|---|---|
| **Owner** | itmax04 — the only user and decision maker |
| **Executor** | the agent or person implementing a change |
| **Change** (`LINGO-NN`) | a unit of work with intent/spec/plan/handoff/report in `docs/changes/` |
| **Owner checkpoint** (`H-x`) | a plan point where the owner must act or decide |
| **Step** (`P-xx`) | one plan item = one GitHub issue |
| **Target language** | `en` or `de`, set per session |
| **Explanation language** | `ru`, used only on explicit request |
| **Session** | one conversation with settings (mode, topic, role, level, correction modes, who starts); continuable on any device |
| **Utterance** | continuous learner speech until a pause (or one typed message) |
| **Turn** | an utterance sent to the model together with the assistant's reply; `turn_id` identifies it end to end |
| **Attempt** | one provider call within a turn (`attempt_id`); states reserved, in_flight, completed, failed, cancelled, uncertain |
| **Pause T** | silence that ends an utterance in continuous mode (default 1.5 s) |
| **Merge G** | a new utterance starting within G of the previous one (and before the assistant speaks) is merged with it |
| **Barge-in** | the learner speaks over the assistant; speech stops |
| **Reply protocol** | the model's line format: `@say <lang>:`, `@fix:`, `@hint <lang>:`, `@heard:` |
| **Commands** | repeat, slower, how do I say, explain, continue, any mistakes, finish — detected locally first |
| **Correction modes** | inline ("as we go"), after (recap at the end), on demand |
| **Event / journal** | immutable history records (schema v1) — the source of truth for history |
| **Device** | one writer of events: `mac-…`, `web-…`, later `ios-…` |
| **Cursor** | per-account `server_seq` used by sync |
| **Lease** | the right of one device to generate a turn in a session (60 s) |
| **Pool** | one rate-limit ceiling: `provider:organization:model` |
| **Owner-risk pool** | a pool from an additional Groq account (ADR-0005) |
| **Route** | ordered pools for a purpose (dialog, transcribe, summary, hints, recap, eval) |
| **Day plan / budget** | per-day reservation and usage per pool for 4 × 30 minutes |
| **Engine** | the Cloudflare Worker + D1 serving the web (and the Mac from LINGO-04) |
| **Contracts** | `packages/contracts`: schemas and golden fixtures shared by Swift and TypeScript |
| **Evals** | `commands`, `turn`, `audio`, `dialog` test sets with thresholds |
| **Full day** | the acceptance test: 2 DE + 2 EN sessions of 30 minutes |
| **PWA** | the website installed to the home screen |
