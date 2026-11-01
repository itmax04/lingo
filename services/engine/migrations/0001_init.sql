-- Lingo Engine schema v1 (ARCHITECTURE §6.2, WR-06). Never edit an applied migration; add 0002_… instead.
-- Every table that holds learner data is keyed by account (WR-03).

CREATE TABLE accounts (
  id INTEGER PRIMARY KEY,                 -- internal account id
  github_id INTEGER NOT NULL UNIQUE,      -- numeric GitHub id (the allow-list key, ADR-0003)
  login TEXT NOT NULL,
  created_at INTEGER NOT NULL             -- ms since 1970
);

CREATE TABLE auth_sessions (
  token_hash TEXT PRIMARY KEY,            -- SHA-256 of the session token with the pepper (WR-02); the token itself is never stored
  account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  device_label TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  last_seen_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);
CREATE INDEX auth_sessions_account ON auth_sessions(account_id);

CREATE TABLE devices (
  account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  id TEXT NOT NULL,                       -- device id of the journal (`web-…`, `mac-…`)
  kind TEXT NOT NULL CHECK (kind IN ('web', 'mac', 'ios')),
  label TEXT NOT NULL DEFAULT '',
  last_cursor INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (account_id, id)
);

CREATE TABLE events (
  account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  server_seq INTEGER NOT NULL,            -- monotonic per account: the sync cursor (WR-07)
  id TEXT NOT NULL,                       -- ULID, unique per account (idempotent writes)
  device TEXT NOT NULL,
  seq INTEGER NOT NULL,
  lamport INTEGER NOT NULL,
  ts INTEGER NOT NULL,                    -- ms since 1970
  type TEXT NOT NULL,
  session TEXT NOT NULL,
  line TEXT NOT NULL,                     -- the canonical JSON line, so unknown fields survive (WR-05)
  PRIMARY KEY (account_id, server_seq),
  UNIQUE (account_id, id)
);

CREATE TABLE turns (
  account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  id TEXT NOT NULL,                       -- turn id from the client (idempotency key)
  session TEXT NOT NULL,
  device TEXT NOT NULL,
  state TEXT NOT NULL CHECK (state IN ('pending', 'streaming', 'done', 'failed', 'cancelled')),
  created_at INTEGER NOT NULL,
  PRIMARY KEY (account_id, id)
);

CREATE TABLE attempts (
  account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  id TEXT NOT NULL,
  turn_id TEXT,
  purpose TEXT NOT NULL CHECK (purpose IN ('dialog', 'transcribe', 'summary', 'hints', 'recap', 'translate', 'eval')),
  pool TEXT NOT NULL,
  model TEXT NOT NULL,
  state TEXT NOT NULL CHECK (state IN ('reserved', 'in_flight', 'completed', 'failed', 'cancelled', 'uncertain')),
  reserved_tokens INTEGER NOT NULL DEFAULT 0,
  actual_tokens INTEGER,
  reserved_audio_ms INTEGER NOT NULL DEFAULT 0,
  actual_audio_ms INTEGER,
  status INTEGER,
  limit_kind TEXT,
  retry_after_ms INTEGER,
  latency_ms INTEGER,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (account_id, id)
);
CREATE INDEX attempts_turn ON attempts(account_id, turn_id);

CREATE TABLE leases (
  account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  session TEXT NOT NULL,
  device TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  PRIMARY KEY (account_id, session)
);

CREATE TABLE budgets (
  day TEXT NOT NULL,                      -- UTC date, YYYY-MM-DD
  pool TEXT NOT NULL,
  planned_tokens INTEGER NOT NULL DEFAULT 0,
  used_tokens INTEGER NOT NULL DEFAULT 0,
  requests INTEGER NOT NULL DEFAULT 0,
  audio_ms INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (day, pool)
);
