# LINGO-11: Specification — Lingo Web for friends

ID: LINGO-11-spec · Status: **draft**, waiting for the owner (H-11-0) · Version: 1 · Date: 2026-11-13 · Owner: itmax04 · Risk: R3
Links: [intent.md](intent.md) (decisions 1…16, assumptions A-01…A-16) · [plan.md](plan.md) · [handoff.md](handoff.md) ·
[ADR-0008](../../decisions/ADR-0008-web-for-friends.md) · [contracts](../../../packages/contracts/README.md) · [DESIGN.md](../../../DESIGN.md)

Requirements of this change live only here: **FR** (requirements) and **FAC** (acceptance). Behaviour that the Mac already has is
**not restated**: its requirements stay in the Mac specs ([LINGO-01](../LINGO-01/spec.md) R, [LINGO-08](../LINGO-08/spec.md) VR/PR,
[LINGO-05](../LINGO-05/spec.md), [LINGO-10](../LINGO-10/spec.md) BR) and the web must behave the same (FR-41). This spec replaces the
web requirements WR-01…WR-29 and WAC-01…WAC-14 of the LINGO-03 spec.

## 0. Definitions
- **Friend**: a person with an account. **Admin**: an account with the admin flag (the owner). An admin is also a friend.
- **Device**: one browser profile on one machine that holds a session. **Session**: the signed-in state of one device.
- **Link token**: the secret of an invite, pairing or sign-in link (FR-02). **Pairing code**: the short typed alias of a pairing link.
- **Engine**: the Cloudflare Worker with its D1 database. **Relay**: the engine's transit proxy for custom endpoints (FR-22).
- **Parity source**: the Mac app on `main` at the commit recorded in `handoff.md` when a port step starts.
- **Fixture**: a file in `packages/contracts/fixtures` (or `prompts`) written by a Swift test and read by a TypeScript test.

## 1. Accounts, links, devices
- **FR-01 No passwords, no e-mail.** The engine stores no password, e-mail address or third-party identity. An account has an id, a
  display name (1–40 characters), the admin flag, a status (`active`, `blocked`) and timestamps.
- **FR-02 Link tokens.** Invite, pairing and sign-in links have the form `https://<host>/<join|pair|signin>#<token>`. The token is 32
  random bytes, base64url. The engine stores only `HMAC-SHA-256(pepper, token)`, the kind, the target, the expiry and the time of use.
  The page reads the fragment, removes it from the address bar, and sends the token in a `POST` body only after the person presses a
  button. No `GET` request changes state. A token works once; a second use, an expired, revoked or unknown token all give the same
  answer: "This link is no longer valid. Ask for a new one."
- **FR-03 Invite.** An admin creates an invite with the friend's name; it is valid 7 days and can be revoked while unused. Redeeming
  it creates, in one transaction, the account (with that name), its first device and a session, and marks the invite used. The link is
  shown to the admin once, with a Copy button.
- **FR-04 Session.** A 32-byte random token; only its HMAC with the pepper is stored. Cookie `lingo_session`:
  `HttpOnly; Secure; SameSite=Lax; Path=/`. Sliding expiry 90 days; the expiry is extended at most once per day. Local development
  over plain `http://localhost` may drop `Secure` behind an explicit development variable that the production configuration cannot set.
- **FR-05 Add a device.** Settings → Devices → "Add a device" creates a pairing record valid 10 minutes and shows a QR code of the
  pairing link and an 8-character code (32-symbol alphabet without look-alike characters). The other device opens the link or types
  the code on `/pair` and presses "Sign in"; the engine creates a device and a session for the same account. Creating a new pairing
  record cancels the previous unused one of that account.
- **FR-06 Guessing limits.** Failed redemptions are counted in D1: at most 10 per client address in 10 minutes for all link kinds
  together; at more than 100 failed typed codes in 10 minutes over all clients, typed codes are refused for 10 minutes while QR and
  link tokens keep working. A refused attempt gets the FR-02 answer and status 429.
- **FR-07 Devices in Settings.** The list shows each device's name (default from the browser and system family, editable), the time
  it was added and last seen, and marks the current one. Actions: "Sign out" (this device), "Sign out" on another device, "Sign out
  everywhere else". A revoked session stops working on its next request.
- **FR-08 One-time sign-in link.** An admin creates it for an existing active account; valid 24 hours; a new one cancels the previous
  unused one. Redeeming creates a device and a session; existing sessions stay.
- **FR-09 Block and delete.** Blocking sets the status: every API request of that account answers 403 and the app shows "This account
  is blocked." The data stays; unblocking restores access. Deleting removes the account, its sessions, devices, events and unused
  links, cannot be undone, and requires the admin to type the friend's name. An admin cannot block or delete the own account while it
  is the only admin.
- **FR-10 Own account.** A friend can rename the account and delete it (Settings → Data → "Delete my account", typed confirmation).
  Deleting removes the server data (FR-09) and clears this device's local copy and keys.
- **FR-11 First admin.** `POST /api/setup` with the setup secret creates the first admin account, device and session. It answers 404
  when an admin exists or the secret is not configured, compares in constant time and counts as a link attempt (FR-06). The owner
  types the secret on `/setup`; the deploy guide tells him to delete the Worker secret afterwards.

## 2. Admin
- **FR-12 Admin page** (`/admin`, linked from Settings only for admins; other accounts get 404 from the page's API):
  invites (create, list of unused ones with expiry, revoke) and friends (name, created, last sign-in, device count, stored size,
  status) with the actions sign-in link, block or unblock, delete.
- **FR-13 No view of conversations.** No admin operation returns events, settings, session titles or counts of sessions of another
  account. "Stored size" is the number of bytes of the account's events.
- **FR-14 Isolation.** Every engine query that reads or writes account data takes the account id from the session, never from the
  request. A test suite with two accounts and an admin calls every endpoint and proves that no response contains the other account's
  data.

## 3. Keys and providers
- **FR-15 Keys stay on the device.** API keys are stored in the IndexedDB of the browser where they were entered. They never appear
  in events, sync requests, exports, the engine's database, logs, URLs or error texts. After entry a key is shown masked (last four
  characters). Removing a key deletes it from the device.
- **FR-16 Providers and chain as on the Mac:** Groq, Mistral, OpenRouter and a custom OpenAI-compatible endpoint (base URL); chain
  entries (provider, model, key) with order and a pinned entry; organization labels and pools, with the "at your own risk" mark on
  additional organizations; the first-token timeout; the list of known models; fallback on 429, 5xx, network errors and timeouts with
  cooldowns; the key check including the probe for endpoints that answer 404 or 405 on the model list. The TypeScript chain gives the
  same decisions as Swift `ProviderChain`, `LLMSettings`, `KeyVerifier` on shared fixtures (FR-42).
- **FR-17 Direct calls.** Requests to Groq, Mistral and OpenRouter go from the browser to the provider. The engine never sees them.
- **FR-18 Custom endpoints go through the relay** (FR-22), always. The settings row of the custom endpoint says: "Requests to a custom
  endpoint pass through the Lingo server. The key is not stored."
- **FR-19 Rate limits.** Where the browser can read the provider's rate-limit headers, the web uses them as the Mac does. Where it
  cannot, a pool is paused from the wait time in the 429 message (Swift `tryAgainSeconds`) or, without one, for the Mac's default
  pause; the Quota screen then shows only the locally counted usage and says "The provider does not report the remaining quota to the
  browser." Which case holds for each provider is measured with a real key and recorded (plan F-11).
- **FR-20 Usage log.** Requests, tokens and failures are counted on the device as on the Mac (per device, not synced), without
  utterance text or keys.
- **FR-21 Onboarding wizard.** After the first sign-in on a device without keys: name → how to get a free Groq key (link to the Groq
  console and the steps in words) → paste and check the key → microphone permission and a voice test → first session. Each step can be
  skipped; "Use another provider" opens the key settings. A hint recommends adding the app to the home screen.
- **FR-22 Relay.** `POST /api/relay` forwards one request to the account's custom endpoint and streams the answer back.
  - Signed-in, active accounts only; `Origin` check as for every state-changing request.
  - Target: the base URL sent with the request plus one of the suffixes `/chat/completions` or `/models`; scheme `https` only; the
    host must not be an IP literal, `localhost`, a name without a dot, or the engine's own host; redirects are not followed.
  - Forwarded: method, the `Authorization` and `Content-Type` headers and the body. No cookie and no engine header is forwarded.
  - Limits: body ≤ 256 KB; at most 600 relay requests per account per hour.
  - The upstream status, body and rate-limit headers are passed back. Nothing of the request or the response is stored. The log line
    has the account id, status, duration and byte counts — not the host, the key, or any body text.

## 4. History, sync, export
- **FR-23 Journal.** The web writes the same events as the Mac (journal schema v1, `packages/contracts/events`). The browser's
  IndexedDB journal is the working copy: every screen is built from it with the `core-ts` reducer, and reading history works offline.
- **FR-24 Sync.** `POST /api/sync` pushes the device's unsent events and pulls the account's events after the device's cursor, in
  batches of at most 500. Pushing is idempotent by (account, event id). The engine checks each event with the strict reader of
  `core-ts`, rejects events over 64 KB, and accepts the `device` field of the pushing device only, except in an import (FR-27). Sync
  runs on opening the app, when the page becomes visible or the network returns, after each turn, and every 30 seconds while visible.
- **FR-25 Merge.** Two devices of one account that worked offline end with the same state after both synced (the reducer's existing
  golden fixtures stay the proof; a two-browser test repeats it end to end).
- **FR-26 Storage cap.** An account may hold 20 MB of event bodies. A push that would exceed it is refused with a clear message
  ("Storage is full. Export your history and delete old sessions."); local work continues.
- **FR-27 Export and import.** Settings → Data → "Export to ZIP" writes the journals in the Mac backup layout
  (`Lingo-history/devices/<device>/journal-*.jsonl`, RELEASE.md), so the Mac's "Restore from ZIP" accepts it. "Import from ZIP" accepts
  a Mac or web export under the Mac restore rules (only journal paths at the expected depth, no links, size limits, undecodable lines
  skipped and counted), adds the events locally and pushes them as an import. Importing twice changes nothing. Keys and settings are
  never in a ZIP.
- **FR-28 Lost local copy.** If the local journal is empty and the account has events on the server, the app pulls everything. The
  app asks the browser for persistent storage. If the keys are gone, the wizard's key step is shown.
- **FR-29 Device-local data.** Keys, the chain, voice settings, the learner's own scenarios and the usage log are per device and are
  not synced (A-06, A-07).
- **FR-30 Audio** is never written to IndexedDB, sent to the engine, or logged.

## 5. Voice
- **FR-31 Capture and segmentation.** The microphone is opened by a user gesture with echo cancellation requested. Utterance start,
  end and merging use the `core-ts` VAD and segmenter with the Mac's defaults. Modes: push-to-talk (hold Space, or hold the button on
  touch screens) and continuous.
- **FR-32 Recognition.** An utterance is sent from the browser to Groq `whisper-large-v3-turbo` with the device's Groq key, with the
  Mac's recognition context and its rule for the language label. Without a Groq key, or when Groq refuses (401, 429, network), the
  browser's built-in recognition is used in the study language if the browser has it; the voice panel shows which recogniser is
  active. With neither, the voice panel explains why and typing still works. Settings → Voice notes in one line that the built-in
  recognition sends audio to the browser's vendor.
- **FR-33 Speech.** `speechSynthesis` with the device's voices: one voice per language chosen automatically (best quality the browser
  reports), changeable in Settings; rate setting and "slower"; a streamed reply is spoken sentence by sentence as on the Mac.
- **FR-34 Barge-in and stop.** Speaking over Lingo stops the speech and the stream and marks the reply interrupted at the spoken
  position, as on the Mac; Esc or a tap on the voice panel does the same. Late fragments of a stopped turn are ignored.
- **FR-35 Voice states and commands.** The states idle, recording, listening, thinking, speaking and paused, and the voice commands
  (`core-ts` detector: repeat, slower, how do I say, explain, continue, any mistakes, finish) behave as the Mac's `TurnController`.
- **FR-36 Screen awake.** A Wake Lock is held while a voice session is active and taken again when the page becomes visible.
- **FR-37 Device limits.** If continuous mode or barge-in is unreliable on a device family (decided from the H-11-1 device results),
  that family uses push-to-talk and tap-to-stop, and the voice panel says so. A locked phone screen stops the session (LINGO-06 topic).
- **FR-38 Metrics.** The Mac's turn marks (`speech_end`, `stt_final`, `llm_first_token`, `first_audio`, `reply_end`) are recorded on
  the device without text and can be exported from Settings. Target on a phone: median `speech_end → first_audio` ≤ 4 s; measured and
  reported, not a release blocker.

## 6. Parity with the Mac
- **FR-39 Prompts.** For the same input the TypeScript prompt builder returns text byte-identical to the Swift one. The proof is every
  snapshot in `packages/contracts/prompts`, with the inputs of each snapshot recorded by Swift as a fixture.
- **FR-40 Requests.** For every request purpose (`dialog`, `summary`, `topicPhrases`, `recap`, `judge`, `translate`, `examFeedback`,
  `weeklyReport`, `memory`) the request body (messages, model parameters, limits) equals the Swift one on recorded cases.
- **FR-41 Parity inventory.** `docs/changes/LINGO-11/parity.md` lists every requirement id of the Mac specs named above, each with one
  of: `port` (with the plan step and, at the end, the evidence), `not ported` (only items of FR-53) or `n/a` (Mac platform matter,
  with a reason). The change is complete only when every `port` row is PASS.
- **FR-42 Fixture first.** A module is ported only after a Swift test writes its fixture into `packages/contracts`; the TypeScript
  test reads the same file. Existing fixtures are reused (events, protocol, commands, voice, vocab, teacher).
- **FR-43 Conversation.** New session (language, mode, level, topic, role, correction modes, who starts, vocabulary use), the session
  list with the language filter, rename and delete, the feed with inline and separate corrections and the correction detail, edit a
  message, reply again, copy, translate to Russian, "In Russian", Finish with the local goodbye, the finished card (continue, new
  session), summary and recap.
- **FR-44 Hints and vocabulary.** The hints panel with Topic phrases, Corrections, How to say and Vocabulary ★ with playback and
  starring; the Vocabulary screen and the vocabulary in prompts as LINGO-08.
- **FR-45 Teacher** as LINGO-05: review cards with FSRS and the warm-up; Today with the goal ring, streak and plan; scenarios from the
  shared catalogue and the learner's own scenarios; the B1 and IELTS exams with timed parts and the debrief; Progress and the weekly
  report; memory (view, edit, delete, switch off). Catalogues are read from `packages/contracts/teacher`. Charts are drawn with own
  SVG, no chart package.
- **FR-46 Goethe B1** as LINGO-10: Training per Teil, the Mock exam with preparation, notes and the partner's talk, Debriefs, A–E
  letters and points computed by the app from the shared scoring fixture. The partner speaks in a second German voice when the device
  has one, otherwise in the same voice with a label.
- **FR-47 Strict tutor and reply options** (LINGO-09) are ported last, after the owner's decision at H-11-2, from whatever is then on
  the Mac's `main` (A-08).
- **FR-48 No pronunciation assessment** anywhere: the Mac's filters are ported with their tests, and the `no_pronunciation` cases stay
  at 100 %.

## 7. Interface
- **FR-49 English only.** Interface strings are English literals; there is no language setting and no i18n package. Language data
  (commands, prompt headings, Russian explanations, glosses) is unchanged.
- **FR-50 Dark only.** Colours are the Dark column of DESIGN.md §2 as CSS custom properties; German amber and English teal accents
  with explicit DE/EN labels. No theme setting. DESIGN.md §9 is rewritten on the v2 tokens before the first screen is built.
- **FR-51 Layouts.** Wide (≥ 1100 px): sidebar, conversation, hints; the hints column becomes a slide-over below 1280 px. Narrow:
  one column with the bottom navigation Today / Conversations / Vocabulary / Progress, Teacher and Settings reachable from Today and
  the header, hints as a sheet, voice controls within thumb reach. Touch targets ≥ 44 px; safe-area insets respected; the voice panel
  and the input stay above the on-screen keyboard.
- **FR-52 Installable.** A web app manifest and a service worker that caches the app shell: an installed app opens without a network
  and shows the local history. A new version is taken on the next start.
- **FR-53 Not in the web** (the complete list): on-device recognition (whisper.cpp, Apple speech) and model download; the speech
  recognition check window and command-line diagnostic modes; folder sync and daily folder backups; Premium voice management; the
  Russian interface and the language setting; the light theme and the theme setting; the daily reminder; Mac keyboard shortcuts that
  browsers reserve (the web keeps Space, Esc and Enter).
- **FR-54 Accessibility.** Visible keyboard focus, labels on icon buttons, `prefers-reduced-motion` honoured (no breathing mark, a
  level bar instead of the waveform), text contrast ≥ 4.5:1 on the dark tokens.

## 8. Security and privacy
Threats and measures:
| Threat | Measure |
|---|---|
| Script injection reads keys from the page | FR-55, FR-56, FR-57 |
| A stranger finds or guesses a link or code | FR-02, FR-06; tokens of 256 bits; short lives |
| A link preview or a prefetch uses up a link | FR-02 (fragment, button, `POST`) |
| A stolen session cookie | `HttpOnly`, `Secure`; device list and remote sign-out (FR-07); admin block (FR-09) |
| Cross-site request with the friend's cookie | FR-58 |
| One friend reads another's history | FR-14 |
| The admin reads conversations through the product | FR-13 (the database owner still can; ADR-0008 Consequences) |
| The relay used as an open proxy or to reach internal hosts | FR-22 |
| Keys or speech in logs, exports or the database | FR-15, FR-27, FR-30, FR-59 |
| A database leak reveals working tokens | FR-02, FR-04 (only HMACs stored; the pepper is a Worker secret) |
| One account fills the database | FR-24 (event size), FR-26 |
| A lost or evicted browser store | FR-28; server copy; export |

- **FR-55 Content-Security-Policy** on every page: scripts only from the site itself, no inline or evaluated script; connections only
  to the site, `api.groq.com`, `api.mistral.ai` and `openrouter.ai`; no framing by other sites; `Referrer-Policy: no-referrer`;
  `X-Content-Type-Options: nosniff`.
- **FR-56 No third parties.** No external script, font, image, analytics or error-reporting service. Dependencies only from the
  ADR-0002 allow-list as amended by ADR-0008.
- **FR-57 No raw HTML.** Model output, journal text and imported data are rendered as text. The code base has no
  `dangerouslySetInnerHTML`, `innerHTML` or `eval`; a lint rule or test enforces it.
- **FR-58 Request origin.** Every state-changing request must carry the site's own `Origin` and a JSON body; others get 403.
- **FR-59 Logs.** Engine logs hold request id, route, status, duration and account id. Never: link tokens, session tokens, pairing
  codes, keys, event bodies, utterance text. The browser console logs no keys and no utterance text in production builds.
- **FR-60 Secrets.** The engine has two secrets, both entered by the owner: the pepper and the setup secret. Tests use generated
  values; nothing secret is in the repository or the client bundle.
- **FR-61 Bundle scan.** CI scans the built site for key-shaped strings and fails on a finding.

## 9. Running, limits, release
- **FR-62 Local run.** One documented command set starts the site and the engine with a local D1 on the owner's Mac; the whole app
  works on `http://localhost` with a development setup secret from a git-ignored file.
- **FR-63 Phones before deployment.** The local site is reachable from a phone through a temporary cloudflared quick tunnel (HTTPS, so
  the microphone works). The executor asks before installing cloudflared and stops the tunnel after the test.
- **FR-64 Free plan.** The design stays inside the limits recorded in WEB.md §6 (D1 500 MB, 100 k rows written and 5 M read per day;
  Workers 100 k requests per day, 10 ms CPU per request). Expected load for 20 friends is stated with the measured numbers in the
  report. The engine makes no model calls.
- **FR-65 Deploy guide.** RELEASE.md gets a step-by-step guide the owner can follow alone: create the D1 database, apply migrations,
  set the two secrets, deploy, open `/setup`, delete the setup secret, create the first invite, and the checks after each release.
- **FR-66 Owner's history.** The owner imports the Mac ZIP export into the own web account (FR-27); the number of sessions and
  messages after the import equals the Mac's.
- **FR-67 Release statement.** Only after FAC-01…FAC-19 are PASS (or NOT RUN with a reason the owner accepted) and the deployed site
  passed the post-deploy checks does the executor tell the owner, in Russian, that the link can be sent to friends.

## 10. Acceptance
Checks are automated unless marked (owner) or (device). Engine tests run in the Workers runtime with a local D1; provider calls in
tests are mocked.

| ID | Criterion | Covers |
|---|---|---|
| FAC-01 | Invite: create → open link → button → new empty account with a session; second use, expired, revoked and unknown tokens give the same refusal; a `GET` of the link changes nothing; the token is not in D1 in clear | FR-01…FR-04 |
| FAC-02 | Pairing by link and by code signs a second device into the same account; an expired or reused record is refused; attempt limits trigger and recover | FR-05, FR-06 |
| FAC-03 | Devices list, remote sign-out and "everywhere else" end the right sessions; sliding expiry extends at most once a day; a 91-day-old session is refused | FR-04, FR-07 |
| FAC-04 | Admin: sign-in link, block, unblock and delete behave as specified; non-admins get 404; the last admin cannot remove itself; setup works once and is 404 afterwards | FR-08…FR-12 |
| FAC-05 | Isolation suite: two accounts and an admin against every endpoint — no response contains another account's data; the admin API returns no events | FR-13, FR-14 |
| FAC-06 | Keys: after entering, checking and using a key, it is absent from every engine request, the D1 database, the export ZIP and the logs; the relay test proves a custom key is forwarded and not stored or logged | FR-15, FR-18, FR-22, FR-59 |
| FAC-07 | Relay refuses: no session, blocked account, `http`, IP literal, `localhost`, the engine's host, a path outside the suffixes, an oversized body, the 601st request in an hour | FR-22 |
| FAC-08 | Chain fixtures: the TypeScript chain, pools, cooldowns and key check give the Swift results on the recorded cases; the rate-limit behaviour per provider is recorded from single real requests | FR-16, FR-19, FR-20 |
| FAC-09 | Sync: idempotent push, cursor pull, 500-event batches, strict validation, foreign `device` refused outside import, cap refusal; two browsers that worked offline converge | FR-23…FR-26 |
| FAC-10 | Export from the web restores on the Mac (`HistoryBackupTests` layout); a Mac export imports into the web, twice without duplicates; hostile ZIP cases are refused | FR-27 |
| FAC-11 | A cleared browser store is rebuilt from the server; missing keys bring back the key step | FR-28 |
| FAC-12 | Every prompt snapshot is reproduced byte for byte; request bodies equal Swift's for all nine purposes | FR-39, FR-40 |
| FAC-13 | `parity.md` has a row for every Mac requirement id, and every `port` row is PASS with evidence | FR-41, FR-43…FR-47 |
| FAC-14 | Every ported module has a Swift-written fixture and a TypeScript test reading it; `swift test` and `npm test` are green on the same commit | FR-42 |
| FAC-15 | Voice with fake audio: segmentation, push-to-talk and continuous mode, sentence-wise speech, barge-in, commands, recognition fallback order, Wake Lock calls | FR-31…FR-36 |
| FAC-16 | `no_pronunciation` cases and the ported filter tests pass at 100 % | FR-48 |
| FAC-17 | Playwright screenshots at 390×844, 820×1180 and 1280×800 for every screen use only DESIGN.md dark tokens; keyboard and reduced-motion checks pass; the installed app opens offline | FR-49…FR-54 |
| FAC-18 | Security headers present on every response; requests with a foreign `Origin` are refused; no raw-HTML API in the code; the bundle scan and `secret-scan` find nothing | FR-55…FR-61 |
| FAC-19 | Local run from a clean clone by the documented commands; a phone reaches it through the tunnel | FR-62, FR-63 |
| FAC-20 | (owner, device) H-11-1: the core on the Mac browser and on the owner's phones — 10 voice turns each in German and English, barge-in, pairing by QR, latency numbers recorded | FR-31…FR-38, FR-05 |
| FAC-21 | (owner) H-11-3: deployment by the guide alone; the import of the Mac history shows the same session and message counts | FR-65, FR-66 |
| FAC-22 | (owner, device) after deployment: invite a second test account on another device, one voice session, admin block and delete; free-plan usage of the day read from the Cloudflare dashboard by the owner | FR-64, FR-67 |
