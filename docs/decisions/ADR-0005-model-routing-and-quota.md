# ADR-0005: Model routing, quota pools and multiple Groq accounts

Status: **accepted** (owner, 2026-10-26) · Context: [ARCHITECTURE §7](../architecture/ARCHITECTURE.md#7-model-routing-and-quota)

## Context
- Target load: **4 sessions × 30 min per day** (2 DE + 2 EN) ≈ 240 dialog turns + transcription + service requests, at $0.
- Groq free limits per organization **and per model** (public table, 2026-10-26): chat 30 RPM, 1 000 RPD, 8 000 TPM, 200 000 TPD; Whisper 20 RPM, 2 000 RPD, 7 200 audio s/hour, 28 800 audio s/day. Keys of one organization share one ceiling.
- Measured on the Mac (26.10): ≈ 1 965 input + 74 output tokens per dialog turn; the request reserved 962 output tokens (counted by Groq against TPM).
- Workers AI free: 10 000 neurons/day; gpt-oss-120b ≈ 31 818 neurons per M input tokens and 68 182 per M output; gpt-oss-20b ≈ 18 182 / 27 273 → a whole day on 20b ≈ 6 600 neurons, on 120b ≈ 11 100 (does not fit).
- Groq's Acceptable Use Policy (effective 2025-10-15) forbids exceeding published limits by registering multiple accounts or coordinating organizations.
- **Owner decision (2026-10-26):** "Several accounts at my own risk" — the owner wants keys of additional Groq accounts to be usable and accepts the risk that Groq may suspend those accounts and possibly the main one.

## Decision
1. **Pool** = one rate-limit ceiling: `provider:organization:model` (Workers AI: `workers-ai:model`). Keys are attached to a pool; several keys of one organization are one pool, never multiplied.
2. **Routes per purpose** (configurable, defaults):
   - `dialog`: groq:main:gpt-oss-120b → groq:main:gpt-oss-20b → workers-ai:gpt-oss-20b → workers-ai:gpt-oss-120b;
   - `transcribe`: groq:main:whisper-large-v3-turbo → workers-ai:whisper;
   - `summary`, `topic_phrases`, `hints`: groq:main:gpt-oss-20b → workers-ai:gpt-oss-20b (never the dialog's primary when it is short);
   - `recap`, weekly report: gpt-oss-120b when the day plan has room, else 20b;
   - `eval`: night only (23:00–08:00 local), explicit budget.
3. **Additional Groq organizations (owner risk):** supported as extra pools with `ownerRisk: true`. They are used **after** the main organization's pools and before Workers AI for `dialog`, are visible as such in the Resources screen and in ledger rows, and can be switched off with one setting. The UI and docs never describe them as "free extra quota". Agents must not create accounts or keys; only the owner adds keys.
4. **Reservation:** before each call reserve `estimated input + output reserve`; output reserve per purpose from the measured reply-length distribution (p99 + reasoning headroom; dialog target ≈ 300 instead of 962), revisited monthly; `finish_reason = length` is logged and raises the reserve. Settle with actual usage; unknown usage stays "uncertain", never zero.
5. **Day plan:** budgets per UTC day per pool; the Resources screen shows used/planned per pool and an honest message when every allowed route is exhausted ("paused until HH:MM" only if a provider reported it).
6. **Token economy:** compact system instructions (target ≤ 900 tokens), total input budget for instructions + memory + transcript, replies short by default, topic phrases once per session, summaries only on new turns.
7. **Headers:** `x-ratelimit-remaining-tokens` = per minute, `x-ratelimit-remaining-requests` = per day; daily tokens come from the ledger.

## Consequences
- On paper 120 minutes fit with the main organization alone only if the token economy lands and two Groq models + Workers AI 20b share the day; the full-day test decides.
- Using additional accounts may violate Groq's AUP; the owner accepted this risk explicitly. If Groq objects or suspends, set `ownerRisk` pools off and fall back to the main organization + Workers AI.
- The Mac app and the web share the main organization's ceiling until the Mac sends turns through the engine (LINGO-04); until then the Mac's usage is not visible to the engine's plan.
