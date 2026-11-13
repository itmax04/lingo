import type { Ctx } from "./app";
import { CLIENT_LIMIT, clientBucket, failureCounts, recordFailure, SETUP_BUCKET, SETUP_GLOBAL_LIMIT } from "./attempts";
import { hmacHex, randomToken, secretsEqual, TOKEN_PATTERN } from "./crypto";
import { ApiError, json } from "./http";
import { authenticate, lookupSession, sessionCookie, SESSION_MS, type Me } from "./session";

/** An optional display name of 1–40 characters (spec FR-01); anything else is `invalid_request`. */
function nameField(value: unknown, fallback: string): string {
  if (value === undefined) return fallback;
  const name = typeof value === "string" ? value.trim() : "";
  const length = [...name].length;
  if (length < 1 || length > 40) throw new ApiError("invalid_request");
  return name;
}

/** Links are not redeemed on a device that holds a working session (spec FR-02). */
async function refuseSignedIn(ctx: Ctx): Promise<void> {
  if ((await lookupSession(ctx)).state === "ok") throw new ApiError("already_signed_in");
}

function signedIn(ctx: Ctx, me: Me, token: string): Response {
  ctx.account = me.account.id;
  return json(200, me, { "Set-Cookie": sessionCookie(ctx.config, token) });
}

/** POST /api/setup — the first admin, or a new device for the existing admin (spec FR-11). */
export async function setup(ctx: Ctx): Promise<Response> {
  const { config, body, now } = ctx;
  const { db } = config;
  if (config.setupSecret === null) throw new ApiError("not_found");
  if (typeof body.secret !== "string") throw new ApiError("invalid_request");
  const name = nameField(body.name, "Admin");
  const deviceName = nameField(body.deviceName, "Browser");
  await refuseSignedIn(ctx);

  const buckets = [clientBucket(ctx.request), SETUP_BUCKET];
  const [client = 0, all = 0] = await failureCounts(db, buckets, now);
  if (client >= CLIENT_LIMIT || all >= SETUP_GLOBAL_LIMIT) throw new ApiError("too_many_attempts");
  if (!(await secretsEqual(body.secret, config.setupSecret))) {
    await recordFailure(db, buckets, now);
    throw new ApiError("secret_invalid");
  }

  // One batch (a transaction): the account is created only when no admin exists; the device and the session always go to
  // the one admin. First setup and recovery are the same path, and concurrent first setups create one account.
  const token = randomToken();
  const deviceId = crypto.randomUUID();
  const results = await db.batch<{ id: string; name: string }>([
    db
      .prepare("INSERT INTO accounts (id, name, is_admin, created_at, updated_at) SELECT ?1, ?2, 1, ?3, ?3 WHERE NOT EXISTS (SELECT 1 FROM accounts WHERE is_admin = 1)")
      .bind(crypto.randomUUID(), name, now),
    db.prepare("INSERT INTO devices (id, account_id, name, created_at, last_seen_at) SELECT ?1, id, ?2, ?3, ?3 FROM accounts WHERE is_admin = 1").bind(deviceId, deviceName, now),
    db
      .prepare("INSERT INTO sessions (hash, account_id, device_id, created_at, expires_at, extended_at) SELECT ?1, id, ?2, ?3, ?4, ?3 FROM accounts WHERE is_admin = 1")
      .bind(await hmacHex(config.pepper, token), deviceId, now, now + SESSION_MS),
    db.prepare("SELECT id, name FROM accounts WHERE is_admin = 1"),
  ]);
  const admin = results[3]!.results[0]!;
  return signedIn(ctx, { account: { id: admin.id, name: admin.name, isAdmin: true }, device: { id: deviceId, name: deviceName } }, token);
}

/** POST /api/join — redeem an invite: account, first device and session in one atomic batch (spec FR-02, FR-03). */
export async function join(ctx: Ctx): Promise<Response> {
  const { config, body, now } = ctx;
  const { db } = config;
  if (!config.invitesEnabled) throw new ApiError("invites_disabled");
  if (typeof body.token !== "string") throw new ApiError("invalid_request");
  const deviceName = nameField(body.deviceName, "Browser");
  await refuseSignedIn(ctx);

  const buckets = [clientBucket(ctx.request)];
  const [client = 0] = await failureCounts(db, buckets, now);
  // Over the limit: the common refusal with status 429, decided from the read alone (spec FR-06).
  if (client >= CLIENT_LIMIT) throw new ApiError("link_invalid", { status: 429 });

  if (TOKEN_PATTERN.test(body.token)) {
    const linkHash = await hmacHex(config.pepper, body.token);
    const stamp = crypto.randomUUID();
    const guard = "EXISTS (SELECT 1 FROM links WHERE hash = ?1 AND used_by = ?2)";
    const token = randomToken();
    const accountId = crypto.randomUUID();
    const deviceId = crypto.randomUUID();
    // The update matches only an unused, unrevoked, unexpired invite; every insert is guarded on this request's stamp, so
    // a request whose update matched nothing inserts nothing, and of two concurrent requests one wins.
    const results = await db.batch<{ name: string }>([
      db
        .prepare("UPDATE links SET used_at = ?3, used_by = ?2 WHERE hash = ?1 AND kind = 'invite' AND used_at IS NULL AND revoked_at IS NULL AND expires_at > ?3")
        .bind(linkHash, stamp, now),
      db.prepare("INSERT INTO accounts (id, name, created_at, updated_at) SELECT ?3, name, ?4, ?4 FROM links WHERE hash = ?1 AND used_by = ?2").bind(linkHash, stamp, accountId, now),
      db.prepare(`INSERT INTO devices (id, account_id, name, created_at, last_seen_at) SELECT ?3, ?4, ?5, ?6, ?6 WHERE ${guard}`).bind(linkHash, stamp, deviceId, accountId, deviceName, now),
      db
        .prepare(`INSERT INTO sessions (hash, account_id, device_id, created_at, expires_at, extended_at) SELECT ?3, ?4, ?5, ?6, ?7, ?6 WHERE ${guard}`)
        .bind(linkHash, stamp, await hmacHex(config.pepper, token), accountId, deviceId, now, now + SESSION_MS),
      // The used invite points at its account, so deleting the account removes the invite and the name in it (FR-09).
      db.prepare("UPDATE links SET account_id = ?3 WHERE hash = ?1 AND used_by = ?2").bind(linkHash, stamp, accountId),
      db.prepare("SELECT name FROM links WHERE hash = ?1 AND used_by = ?2").bind(linkHash, stamp),
    ]);
    const invite = results[5]!.results[0];
    if (invite) return signedIn(ctx, { account: { id: accountId, name: invite.name, isAdmin: false }, device: { id: deviceId, name: deviceName } }, token);
  }
  await recordFailure(db, buckets, now);
  throw new ApiError("link_invalid");
}

/** GET /api/me */
export async function me(ctx: Ctx): Promise<Response> {
  const { me, setCookie } = await authenticate(ctx);
  return json(200, me, setCookie === null ? undefined : { "Set-Cookie": setCookie });
}
