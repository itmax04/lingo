# LINGO-03: Specification — Mac stabilisation, Lingo Engine and Lingo Web

P-00 decision record (2026-10-29): DG-02 accepts these LINGO-03 documents at H-0; runtime/product completion is not asserted. MR-03 is unchanged: D01-01 confirms Russian first-run with explicit Russian/English/System. The draft redesign still defaults to System; no code correction is claimed. Process review follows [D04-01](../P-00/review-policy-2026-10-29.md).

ID: LINGO-03-spec · Status: **accepted at H-0 in DG-02 on 2026-10-29** · Version: 2 · Date: 2026-10-26 · Owner: itmax04
Links: [intent.md](intent.md) (decisions O-01…O-22) · [plan.md](plan.md) · [ARCHITECTURE](../../architecture/ARCHITECTURE.md) · [contracts](../../../packages/contracts/README.md) ·
[LINGO-01 spec](../LINGO-01/spec.md) (conversation behaviour R-01…R-52 reused by reference; translation to English pending)

IDs: `MR-` Mac requirements, `WR-` web/engine requirements, `WS-` scenarios, `WAC-` acceptance criteria. Conversation behaviour that is the same
as on the Mac is referenced as "as R-nn" (LINGO-01 spec is the source of truth for those details).

## 1. Scenarios
- **WS-01 First sign-in.** On an iPhone the owner opens the site, taps "Sign in with GitHub", approves, and lands in Lingo. A first-run screen explains what is stored and sent (WR-24), checks the microphone and plays a test voice.
- **WS-02 Same history on web devices.** A session started on the iPad appears on the iPhone within 10 s of opening it (or pressing "Sync"), in the same order.
- **WS-03 Voice turn on a phone.** Push-to-talk or continuous mode; the utterance becomes a bubble with its language; the reply streams and is spoken by the device voice; median `speech_end → audible_start` ≤ 4 s.
- **WS-04 Barge-in on a phone.** The owner talks over the assistant; speech stops (target ≤ 0.7 s); the next utterance continues the same context; late fragments of the old reply never play.
- **WS-05 Offline open.** Without a network the PWA opens from cache and shows history, hints and vocabulary; voice and input explain why they are disabled.
- **WS-06 Foreign computer.** On a Windows PC the owner signs in with GitHub, practises, then signs out; nothing stays except what the browser keeps until sign-out clears it.
- **WS-07 Limits.** When every allowed route is exhausted, the reply is not faked: the app saves everything, names the limit, and shows the recovery time only if a provider reported it.
- **WS-08 Two devices at once.** A turn running on the iPad blocks a parallel turn in the same session on the phone; the phone offers "take over".
- **WS-09 Two devices offline.** A test harness seeds each of two browsers with 25 synthetic queued messages for one session while offline; after reconnecting both show all 50 in the same order, no duplicates or losses. This is a sync fixture, not a user-facing offline composer; WS-05 remains read-only.
- **WS-10 Delete my data.** Settings → Delete my data removes server events, attempts and budgets of the account; local copies are cleared.
- **WS-11 Full day.** 2 German + 2 English sessions of 30 minutes in one day, on the phone and the Mac, without a quota refusal; repeated on a second day.
- All conversation scenarios of LINGO-01 (S-01, S-05…S-16) apply to the web client unchanged.

## 2. Requirements

### Stage 0 — Mac and repository
- **MR-01 Monorepo.** The Swift package moves to `apps/mac`; prompt snapshots and eval sets move to `packages/contracts`; scripts and docs updated; no behaviour change; `swift test` and `build-app.sh` pass (ADR-0004).
- **MR-02 Token economy.** Output reserve per purpose from the measured distribution (dialog ≈ 300 instead of 962), `finish_reason=length` logged; compact system instructions (target ≤ 900 tokens) without losing the rules' effect; total input budget for instructions + summary + transcript. Prompt snapshots re-recorded; a night `dialog` eval batch shows thresholds held (all rules ≥ 90 %, `no_pronunciation` 100 %).
- **MR-03 Russian UI.** String Catalog with Russian translations for every UI string, compiled into the app; an in-app "Interface language" setting (Russian default, English, System) that works although macOS prefers en-US; a check that fails on missing translations.
- **MR-04 History safety.** Export of the Mac history (ZIP) on demand and a daily automatic export to a user-chosen folder; restore documented.
- **MR-05 Voice stability.** `--audio-stability` accepts a duration; a 30-minute run and a 30-minute live session (AC-17 of LINGO-01) pass without capture loss.
- **MR-06 Key check.** A custom endpoint that has no `GET /models` (HTTP 404/405) is reported as "key works, no model list", verified by a one-token test request.
- **MR-07 Key pools on the Mac.** Keys show their organization label; keys of one organization are one pool; extra organizations are marked "owner risk" (ADR-0005).
- **MR-08 English repository.** Remaining Russian documents translated (LINGO-01 docs, ADR-0001, DESIGN.md if still Russian, evals descriptions, references); `scripts/check-english.sh` in CI with an allow-list for language data.

### Accounts and access (engine)
- **WR-01 Sign-in.** GitHub OAuth (ADR-0003): `/auth/login`, `/auth/callback`, `/auth/logout`; signed `state`; allow-list by numeric GitHub id; 403 for others with no account created.
- **WR-02 Sessions.** 256-bit token, stored hashed with a pepper; cookie `HttpOnly; Secure; SameSite=Lax`; 30-day sliding expiry; "Sign out" and "Sign out everywhere".
- **WR-03 Isolation.** Every query is scoped by account id; tests prove no cross-account read or write.
- **WR-04 Origin check.** State-changing requests require `Origin` = the site origin; size and rate limits per OpenAPI.

### Sync and storage
- **WR-05 Event format.** Schema v1 of `packages/contracts/events/event.schema.json`; unknown types and fields preserved; validated on the engine.
- **WR-06 Server store.** D1 `events` with a unique (account, id) and a per-account `server_seq` cursor; idempotent writes.
- **WR-07 Sync API.** `POST /api/sync` per OpenAPI; batches ≤ 500; returns other devices' events after the cursor.
- **WR-08 Merge.** The TypeScript reducer reproduces `packages/contracts/fixtures/events/merge-two-devices.expected.json` and passes commutativity/idempotency property tests.
- **WR-09 Local store.** IndexedDB copy of events + sync queue; UI renders from local state; sync on open, on visibility, after a turn, every 30 s while visible, and on "Sync".
- **WR-10 Storage hygiene.** Archive (export + compaction) before D1 reaches 400 MB; `navigator.storage.persist()` requested; export available in Settings.

### Turns, models and quota (engine)
- **WR-11 Turn API.** `POST /api/turn` per OpenAPI: structured input only (no free-form system prompt), server-side prompt from the TS port of `PromptBuilder` (snapshots byte-identical), SSE stream with `meta / delta / sentence / segment / usage / done / error`.
- **WR-12 Idempotency and states.** `turn_id` + `attempt_id`; attempt states `reserved → in_flight → completed | failed | cancelled | uncertain`; `GET /api/turn/{id}` reconciles; unknown usage never recorded as zero; cancel endpoint.
- **WR-13 Lease.** One active turn per session across devices (60 s lease, take-over).
- **WR-14 Routing.** Pools and per-purpose routes per ADR-0005, including owner-risk pools after the main organization; fallback on 429/5xx/network/refusal/first-token timeout; `retry-after` honoured.
- **WR-15 Day plan and budgets.** Reservation before each call, settlement after; per-pool daily usage; `/api/budget`; honest exhaustion messages (WS-07).
- **WR-16 Token economy.** Same rules as MR-02 on the engine.
- **WR-17 Transcription.** `POST /api/transcribe` per OpenAPI: Groq whisper-large-v3-turbo with bilingual prompt + context hint, Workers AI fallback, ≤ 4 MB / ≤ 60 s, language label by script, audio never stored or logged; audio seconds counted conservatively (≥ 10 s per clip).
- **WR-18 Secrets.** Keys only as Worker secrets; a CI step scans the built client and the repository for key patterns.

### Web client
- **WR-19 Layout.** DESIGN.md tokens; ≥ 1100 px: three columns (sidebar | feed + voice panel + input | hints); narrower: one column with slide-over panels; touch targets ≥ 44 px; respects safe areas and the on-screen keyboard.
- **WR-20 Voice.** `getUserMedia` with echo cancellation, noise suppression, auto gain; visible input level; push-to-talk (button, space, Esc) and continuous mode; the TS port of `EnergyVAD` + `TurnSegmenter` (pause T, merge G) passing the `turn` eval; MediaRecorder per utterance with MIME chosen by support; barge-in with a raised threshold while speaking; `speechSynthesis` sentence by sentence; Wake Lock during a session; honest states: mic not allowed / ready / hearing sound / recording / uploading / recognising / preparing reply / speaking / paused / error.
- **WR-21 Behaviour.** Commands (TS port of `CommandDetector`, ≥ 95 % on the `commands` eval), correction modes, recap, `@heard`, four hint sections, vocabulary ★ — as R-14…R-28 and R-51.
- **WR-22 PWA.** Manifest, icons, service worker; installs to the home screen on iOS and Android; app shell and history work offline.
- **WR-23 Languages.** UI in Russian (default) and English.
- **WR-24 Privacy note and deletion.** First-run note (what is stored; audio → Groq for recognition; text → model providers incl. fallback), Delete my data (WS-10), export.
- **WR-25 Settings.** Voices per language and rate, pause T and merge G, mic mode, UI language, sign-out, sessions list of signed-in devices, Resources (today's usage per pool).
- **WR-26 Metrics.** Stage timings per turn (ARCHITECTURE §5.3) and a post-session comfort note (cut-offs, false barge-ins, too-long replies); exportable without utterance text.

### Operations
- **WR-27 Deployment.** One Worker (static assets + API) and one D1 database; migrations versioned; deploy reproducible from a clean clone (RELEASE.md).
- **WR-28 Logs.** Request id, status, latency, pool, model, account id; never utterance text, audio or keys.
- **WR-29 CI.** GitHub Actions: Swift tests (macOS, path-filtered), TS tests (Linux), secret scan, language check, bundle scan; PR template.

## 3. Threat model
| Asset | Threat | Measure |
|---|---|---|
| Groq keys | leak via client, logs, repo, chat | Worker secrets (WR-18), bundle scan, secret-scan, rules in AGENTS.md |
| Owner's quota | burnt by a stolen session or a bug loop | allow-list (WR-01), sessions revocable (WR-02), rate limits (WR-04), structured turns only (WR-11), budgets (WR-15) |
| History | another account reads it | account-scoped queries + tests (WR-03) |
| Session cookie | theft on a foreign computer | HttpOnly/Secure/SameSite, sign-out clears local data, "sign out everywhere" |
| Audio | stored or logged | in-memory only, never logged (WR-17) |
| Sync data | duplicates, losses, conflicts | idempotent writes (WR-06), shared merge rules (WR-08), WS-09 test |
| Extra Groq accounts | suspension under Groq's AUP | owner-risk pools can be switched off; main org + Workers AI keep working (ADR-0005) |

## 4. Acceptance criteria
| AC | Criterion | Evidence |
|---|---|---|
| WAC-01 | Stage 0: MR-01…MR-08 done; Mac 30-minute session without quota refusal or capture loss; UI Russian | tests + owner checkpoint report |
| WAC-02 | Sign-in only for the allow-listed GitHub id; forged cookie, missing state, wrong origin, foreign id rejected | engine tests + manual sign-in on two devices |
| WAC-03 | Isolation: no cross-account access | engine integration tests |
| WAC-04 | Sync: WS-02 within 10 s; WS-09 zero losses/duplicates; merge parity fixtures pass in TS | tests + two-browser run |
| WAC-05 | Voice on iPhone Air, iPhone 11, iPad, Android, Windows: push-to-talk and continuous work; median `speech_end → audible_start` ≤ 4 s (ceiling p90 10 s) | device checkpoint with exported metrics |
| WAC-06 | Barge-in: phones ≤ 0.7 s in ≥ 8/10; Mac browser ≤ 0.5 s in ≥ 9/10; otherwise the limitation and fallback documented | device checkpoint |
| WAC-07 | Parity: prompt snapshots byte-identical; `commands` ≥ 95 %; `turn` thresholds; reply-protocol tests ported | `npm test`, `swift test` |
| WAC-08 | Quality: `dialog` eval via the engine: all rules ≥ 90 %, `no_pronunciation` 100 %; language set (20 EN + 20 DE + 20 RU switches) reviewed | night eval report |
| WAC-09 | Full day (WS-11): 4 × 30 min on two different days without refusal; ledger shows every attempt; headroom after the 4th session documented | ledger export + owner report |
| WAC-10 | No secrets in bundle, repo, history, logs; secret-scan 0 findings | CI |
| WAC-11 | PWA installs on iOS and Android; offline open works (WS-05) | device checkpoint |
| WAC-12 | UI follows DESIGN.md at 1280×800 and 390×844; Russian and English | screenshots in report.md |
| WAC-13 | Deletion (WS-10) removes only that account's server data | engine test + manual |
| WAC-14 | Reproducible: clean clone → `npm ci && npm test && npm run build`, `swift test --package-path apps/mac`, deploy per RELEASE.md | report.md |
