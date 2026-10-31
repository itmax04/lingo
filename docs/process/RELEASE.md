# Lingo — build, deploy and operate

## Lingo for Mac
```bash
swift build --package-path apps/mac && swift test --package-path apps/mac   # until P-01: run at the repo root without --package-path
apps/mac/scripts/build-app.sh      # builds and signs dist/Lingo.app (self-signed cert "Lingo Dev" or "InterviewCopilot")
open dist/Lingo.app
```
- The build number is the commit count; the revision (with `-dirty`) is shown in Settings → Quota.
- Keys live in the Keychain; checks that need keys run through the signed binary (`dist/Lingo.app/Contents/MacOS/Lingo --check-keys`).
- Whisper model: downloaded on first use into `~/Library/Application Support/Lingo/models` with a SHA256 check.

## Lingo Web + Engine (Cloudflare)

### One-time setup — owner only (checkpoint)
1. `wrangler login` in the terminal (browser OAuth to the owner's Cloudflare account).
2. GitHub OAuth App (github.com → Settings → Developer settings → OAuth Apps → New):
   homepage `https://<name>.workers.dev`, callback `https://<name>.workers.dev/auth/callback`. A second app for local dev with `http://localhost:8787/auth/callback`.
3. Secrets (typed in the terminal, never in chat):
   ```bash
   cd services/engine
   npx wrangler secret put GITHUB_CLIENT_SECRET
   npx wrangler secret put SESSION_PEPPER        # any long random string
   npx wrangler secret put GROQ_KEY_MAIN
   npx wrangler secret put GROQ_KEY_EXTRA_1      # optional, owner-risk pool (ADR-0005)
   ```
4. Vars in `wrangler.jsonc` (not secret): `GITHUB_CLIENT_ID`, `ALLOWED_GITHUB_IDS`, pool configuration.
5. Groq console: consider enabling Zero Data Retention.

### Every release
```bash
npm ci && npm test && npm run build                              # all workspaces
npx wrangler d1 migrations apply lingo --remote                  # from services/engine
npx wrangler deploy                                              # from services/engine
```
- Migrations are additive; destructive changes need a backup export first (`/api/export` or `wrangler d1 export`).
- Never point local dev or tests at the production D1 database.
- After deploy: sign in on a phone, one text turn, one voice turn, check `/api/budget`.

### Local development
```bash
npm run dev -w apps/web                 # Vite on :5173, proxies /api and /auth to :8787
npx wrangler dev                         # from services/engine; local D1 + .dev.vars with test secrets (git-ignored)
```

## Operations
- **Free-tier watch:** Resources screen (`/api/budget`), Cloudflare dashboard analytics, Groq console limits.
- **Storage:** D1 ≤ 400 MB before archiving old events (export + compaction); D1 hard limit 500 MB per database.
- **Incidents:** if a provider changes limits or removes a model, update the pool configuration (no code change) and note it in the current `handoff.md`.
- **Data deletion:** Settings → "Delete my data" removes server events, attempts, budgets; local copies are cleared on each device when it next opens.

## Mac history: backup and restore (MR-04)
A backup is a ZIP with one folder `Lingo-history/` that holds only journals (`devices/<id>/journal-*.jsonl` of this Mac and `cache/<id>/journal-*.jsonl` copies of other devices). Keys, settings, device identity and sync state are never included.

- **Back up:** Lingo → Settings → Data → "Export to ZIP…". The default name is `Lingo-history-<yyyy-mm-dd>.zip`.
- **Restore:** Lingo → Settings → Data → "Restore from ZIP…" and pick the file. Journals of this Mac go back to `devices/<this device>`; journals of any other device become cache copies. Existing files are never overwritten, so restoring twice changes nothing. The banner reports restored, already-present and skipped files.
- **New Mac or wiped history:** install Lingo, open it once (creates the device), restore the ZIP, then connect the sync folder. The old Mac's history appears as another device's cache and merges by event id.
- **Test it without touching real data:** `swift test --package-path apps/mac --filter HistoryBackupTests` exports a store, restores it into a fresh base and compares the state.
- **Daily automatic backup:** `HistoryBackup.dailyBackupIfDue` writes one ZIP per day and keeps the newest 14. It is not scheduled yet: the owner chooses the folder first (P-04b).
