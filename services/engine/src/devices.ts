import { idField } from "./admin";
import type { Ctx } from "./app";
import { codeHash, nameField, randomCode } from "./auth";
import { hmacHex, randomToken } from "./crypto";
import { ApiError, json } from "./http";
import { authenticate, clearedCookie, type Me } from "./session";

/** A pairing record lives 10 minutes (spec FR-05). */
export const PAIRING_MS = 10 * 60 * 1000;

const ok = (body: unknown, setCookie: string | null): Response => json(200, body, setCookie === null ? undefined : { "Set-Cookie": setCookie });

/** The account's devices with a working session, oldest first (spec FR-07). */
async function deviceList(ctx: Ctx, me: Me): Promise<{ devices: unknown[] }> {
  const { results } = await ctx.config.db
    .prepare(
      `SELECT d.id, d.name, d.created_at, d.last_seen_at FROM devices d JOIN sessions s ON s.device_id = d.id
       WHERE d.account_id = ? AND s.revoked_at IS NULL AND s.expires_at > ? ORDER BY d.created_at, d.id`,
    )
    .bind(me.account.id, ctx.now)
    .all<{ id: string; name: string; created_at: number; last_seen_at: number }>();
  return {
    devices: results.map((d) => ({ id: d.id, name: d.name, createdAt: d.created_at, lastSeenAt: d.last_seen_at, current: d.id === me.device.id })),
  };
}

/** POST /api/pairings — a pairing record with its link token and typed code, both stored as HMACs only (spec FR-05). */
export async function createPairing(ctx: Ctx): Promise<Response> {
  const { me, setCookie } = await authenticate(ctx);
  const { db, pepper } = ctx.config;
  const token = randomToken();
  const code = randomCode();
  const expiresAt = ctx.now + PAIRING_MS;
  const results = await db.batch([
    // The previous unused record of the account is cancelled; expired links of every kind and devices whose session
    // ended go with it, so neither table grows (review R5 of F-1a).
    db.prepare("DELETE FROM links WHERE (account_id = ?1 AND kind = 'pair' AND used_at IS NULL) OR expires_at <= ?2").bind(me.account.id, ctx.now),
    db.prepare("DELETE FROM devices WHERE account_id = ?1 AND id IN (SELECT device_id FROM sessions WHERE account_id = ?1 AND (revoked_at IS NOT NULL OR expires_at <= ?2))").bind(me.account.id, ctx.now),
    // Only while the account is active: a block that lands between the session check and this batch leaves no record
    // that an unblock would revive (review N3 of F-2b).
    db
      .prepare("INSERT INTO links (hash, code_hash, kind, account_id, created_at, expires_at) SELECT ?1, ?2, 'pair', id, ?4, ?5 FROM accounts WHERE id = ?3 AND status = 'active'")
      .bind(await hmacHex(pepper, token), await codeHash(pepper, code), me.account.id, ctx.now, expiresAt),
  ]);
  if (results[2]!.meta.changes === 0) throw new ApiError("account_blocked");
  return ok({ token, code, expiresAt }, setCookie);
}

/** GET /api/devices */
export async function listDevices(ctx: Ctx): Promise<Response> {
  const { me, setCookie } = await authenticate(ctx);
  return ok(await deviceList(ctx, me), setCookie);
}

/** POST /api/devices/rename */
export async function renameDevice(ctx: Ctx): Promise<Response> {
  const { me, setCookie } = await authenticate(ctx);
  const deviceId = idField(ctx.body.deviceId);
  const name = nameField(ctx.body.name);
  const result = await ctx.config.db.prepare("UPDATE devices SET name = ? WHERE id = ? AND account_id = ?").bind(name, deviceId, me.account.id).run();
  if (result.meta.changes === 0) throw new ApiError("not_found");
  return ok(await deviceList(ctx, me), setCookie);
}

/** POST /api/devices/sign-out — removes a device of the account; its session goes with it (spec FR-07). */
export async function signOutDevice(ctx: Ctx): Promise<Response> {
  const { me, setCookie } = await authenticate(ctx);
  const deviceId = idField(ctx.body.deviceId);
  const result = await ctx.config.db.prepare("DELETE FROM devices WHERE id = ? AND account_id = ?").bind(deviceId, me.account.id).run();
  if (result.meta.changes === 0) throw new ApiError("not_found");
  return ok(await deviceList(ctx, me), deviceId === me.device.id ? clearedCookie(ctx.config) : setCookie);
}

/**
 * POST /api/devices/sign-out-others — every other device, and every unused way in that somebody else may hold: the
 * pairing record and the sign-in link (review N6 of F-2a). The admin can make a new sign-in link.
 */
export async function signOutOthers(ctx: Ctx): Promise<Response> {
  const { me, setCookie } = await authenticate(ctx);
  const { db } = ctx.config;
  await db.batch([
    db.prepare("DELETE FROM devices WHERE account_id = ? AND id <> ?").bind(me.account.id, me.device.id),
    db.prepare("DELETE FROM links WHERE account_id = ? AND kind IN ('pair', 'signin') AND used_at IS NULL").bind(me.account.id),
  ]);
  return ok(await deviceList(ctx, me), setCookie);
}

/** POST /api/sign-out — this device. */
export async function signOut(ctx: Ctx): Promise<Response> {
  const { me } = await authenticate(ctx);
  await ctx.config.db.prepare("DELETE FROM devices WHERE id = ? AND account_id = ?").bind(me.device.id, me.account.id).run();
  return ok({}, clearedCookie(ctx.config));
}
