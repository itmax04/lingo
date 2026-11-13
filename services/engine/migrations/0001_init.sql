-- LINGO-11 F-1: accounts by invite (ADR-0008). Times are milliseconds since the Unix epoch.
-- Tokens and codes are never stored: `hash` columns hold hex(HMAC-SHA-256(pepper, token)) (spec FR-02, FR-04).

CREATE TABLE accounts (
  id           TEXT PRIMARY KEY,
  name         TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 40),
  is_admin     INTEGER NOT NULL DEFAULT 0 CHECK (is_admin IN (0, 1)),
  status       TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'blocked')),
  -- Bytes of the account's event bodies, kept by the batch that stores events (spec FR-26).
  stored_bytes INTEGER NOT NULL DEFAULT 0,
  created_at   INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL
);
-- Exactly one admin (spec FR-09): a second row with is_admin = 1 is refused by the database.
CREATE UNIQUE INDEX accounts_one_admin ON accounts (is_admin) WHERE is_admin = 1;

CREATE TABLE devices (
  id           TEXT PRIMARY KEY,
  account_id   TEXT NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
  name         TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 40),
  created_at   INTEGER NOT NULL,
  last_seen_at INTEGER NOT NULL
);
CREATE INDEX devices_account ON devices (account_id);

-- One session per device (spec FR-04). Sliding expiry: `extended_at` limits the extension to once a day.
CREATE TABLE sessions (
  hash        TEXT PRIMARY KEY,
  account_id  TEXT NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
  device_id   TEXT NOT NULL UNIQUE REFERENCES devices (id) ON DELETE CASCADE,
  created_at  INTEGER NOT NULL,
  expires_at  INTEGER NOT NULL,
  extended_at INTEGER NOT NULL,
  revoked_at  INTEGER
);
CREATE INDEX sessions_account ON sessions (account_id);

-- Invite, pairing and sign-in links (spec FR-02). `used_by` is the random stamp of the request that used the link:
-- the inserts of that request are guarded on it, so concurrent redemptions create one session.
CREATE TABLE links (
  hash       TEXT PRIMARY KEY,
  -- Pairing only: the HMAC of the typed 8-character code (spec FR-05).
  code_hash  TEXT UNIQUE,
  kind       TEXT NOT NULL CHECK (kind IN ('invite', 'pair', 'signin')),
  -- Pairing and sign-in: the target account. Invite: NULL until it is used, then the account it created, so that deleting
  -- the account removes the invite row and the name in it (spec FR-09).
  account_id TEXT REFERENCES accounts (id) ON DELETE CASCADE,
  name       TEXT CHECK (name IS NULL OR length(name) BETWEEN 1 AND 40),
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  used_at    INTEGER,
  used_by    TEXT,
  revoked_at INTEGER,
  CHECK (kind = 'invite' OR account_id IS NOT NULL),
  CHECK (kind <> 'invite' OR account_id IS NULL OR used_at IS NOT NULL),
  CHECK (code_hash IS NULL OR kind = 'pair'),
  CHECK (kind <> 'invite' OR name IS NOT NULL)
);

-- Failed redemptions per bucket and 10-minute window (spec FR-06). No request content is stored.
CREATE TABLE attempts (
  bucket       TEXT NOT NULL,
  window_start INTEGER NOT NULL,
  failures     INTEGER NOT NULL,
  PRIMARY KEY (bucket, window_start)
) WITHOUT ROWID;

-- Journal events (schema v1), plaintext (ADR-0008 §9). `seq` is the pull cursor; an event is one row and two indexes
-- (spec FR-27). Filled by /api/sync in step F-3.
CREATE TABLE events (
  seq        INTEGER PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
  event_id   TEXT NOT NULL,
  body       TEXT NOT NULL,
  UNIQUE (account_id, event_id)
);
CREATE INDEX events_account_seq ON events (account_id, seq);
