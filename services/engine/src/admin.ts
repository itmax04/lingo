import type { Ctx } from "./app";
import { nameField } from "./auth";
import { hmacHex, randomToken } from "./crypto";
import { ApiError, json } from "./http";
import { authenticate, type Me } from "./session";

/** An invite lives 7 days (spec FR-03), a sign-in link 24 hours (spec FR-08). */
export const INVITE_MS = 7 * 24 * 60 * 60 * 1000;
export const SIGNIN_MS = 24 * 60 * 60 * 1000;

const ok = (body: unknown, setCookie: string | null): Response => json(200, body, setCookie === null ? undefined : { "Set-Cookie": setCookie });

export function idField(value: unknown): string {
  if (typeof value !== "string" || value === "" || value.length > 64) throw new ApiError("invalid_request");
  return value;
}

/**
 * The admin's session, checked before anything of the request is looked at: any other signed-in account gets the answer
 * of an unknown path (spec FR-12).
 */
async function requireAdmin(ctx: Ctx): Promise<{ me: Me; setCookie: string | null }> {
  const session = await authenticate(ctx);
  if (!session.me.account.isAdmin) throw new ApiError("not_found");
  return session;
}

/** The public id of an invite: the first half of its token's HMAC. The token cannot be derived from it. */
const INVITE_ID = "substr(hash, 1, 32)";

async function inviteList(ctx: Ctx): Promise<{ invites: unknown[] }> {
  // Unused and unexpired only: expired rows are removed by housekeeping and must not appear or disappear at random
  // (review N3 of F-2a).
  const { results } = await ctx.config.db
    .prepare(`SELECT ${INVITE_ID} AS id, name, created_at, expires_at FROM links WHERE kind = 'invite' AND used_at IS NULL AND revoked_at IS NULL AND expires_at > ? ORDER BY created_at, hash`)
    .bind(ctx.now)
    .all<{ id: string; name: string; created_at: number; expires_at: number }>();
  return { invites: results.map((i) => ({ id: i.id, name: i.name, createdAt: i.created_at, expiresAt: i.expires_at })) };
}

/**
 * Every account for the admin page (spec FR-12). The columns are the whole answer: nothing is read from `events`, and
 * no session or settings data leaves the engine (spec FR-13). A device counts while its session works.
 */
async function accountList(ctx: Ctx): Promise<{ accounts: unknown[]; totalStoredBytes: number }> {
  const live = "FROM devices d JOIN sessions s ON s.device_id = d.id WHERE d.account_id = a.id AND s.revoked_at IS NULL AND s.expires_at > ?1";
  const { results } = await ctx.config.db
    .prepare(
      `SELECT a.id, a.name, a.is_admin, a.status, a.created_at, a.stored_bytes,
              (SELECT COUNT(*) ${live}) AS device_count, (SELECT MAX(d.created_at) ${live}) AS last_sign_in_at
       FROM accounts a ORDER BY a.created_at, a.id`,
    )
    .bind(ctx.now)
    .all<{ id: string; name: string; is_admin: number; status: string; created_at: number; stored_bytes: number; device_count: number; last_sign_in_at: number | null }>();
  return {
    accounts: results.map((a) => ({
      id: a.id,
      name: a.name,
      isAdmin: a.is_admin === 1,
      status: a.status,
      createdAt: a.created_at,
      lastSignInAt: a.last_sign_in_at,
      deviceCount: a.device_count,
      storedBytes: a.stored_bytes,
    })),
    totalStoredBytes: results.reduce((sum, a) => sum + a.stored_bytes, 0),
  };
}

/** Why a statement guarded on "exists and is not the admin" changed nothing. */
async function refusal(db: D1Database, accountId: string, otherwise: "confirmation_mismatch" | "account_not_active"): Promise<ApiError> {
  const row = await db.prepare("SELECT is_admin FROM accounts WHERE id = ?").bind(accountId).first<{ is_admin: number }>();
  if (row === null) return new ApiError("not_found");
  return new ApiError(row.is_admin === 1 ? "admin_protected" : otherwise);
}

/**
 * Deletes an account when the typed name equals its current name (spec FR-09, FR-10). Sessions, devices, events and
 * links go with the row (foreign keys cascade). The admin row is never deleted: migration 0002 does not stop it, this
 * condition does.
 */
export async function deleteAccount(db: D1Database, accountId: string, typedName: unknown): Promise<void> {
  if (typeof typedName !== "string") throw new ApiError("invalid_request");
  const result = await db.prepare("DELETE FROM accounts WHERE id = ? AND is_admin = 0 AND name = ?").bind(accountId, typedName.trim()).run();
  if (result.meta.changes === 0) throw await refusal(db, accountId, "confirmation_mismatch");
}

/** GET /api/admin/invites */
export async function listInvites(ctx: Ctx): Promise<Response> {
  const { setCookie } = await requireAdmin(ctx);
  return ok(await inviteList(ctx), setCookie);
}

/** POST /api/admin/invites/create — the token is returned once and stored as an HMAC (spec FR-03). */
export async function createInvite(ctx: Ctx): Promise<Response> {
  const { setCookie } = await requireAdmin(ctx);
  const { db, pepper } = ctx.config;
  if (!ctx.config.invitesEnabled) throw new ApiError("invites_disabled");
  const name = nameField(ctx.body.name);
  const token = randomToken();
  const hash = await hmacHex(pepper, token);
  const expiresAt = ctx.now + INVITE_MS;
  await db.batch([
    db.prepare("DELETE FROM links WHERE expires_at <= ?").bind(ctx.now),
    db.prepare("INSERT INTO links (hash, kind, name, created_at, expires_at) VALUES (?, 'invite', ?, ?, ?)").bind(hash, name, ctx.now, expiresAt),
  ]);
  return ok({ token, invite: { id: hash.slice(0, 32), name, createdAt: ctx.now, expiresAt } }, setCookie);
}

/** POST /api/admin/invites/revoke — an unused invite only; a used one belongs to its account. */
export async function revokeInvite(ctx: Ctx): Promise<Response> {
  const { setCookie } = await requireAdmin(ctx);
  const inviteId = idField(ctx.body.inviteId);
  const result = await ctx.config.db.prepare(`DELETE FROM links WHERE ${INVITE_ID} = ? AND kind = 'invite' AND used_at IS NULL`).bind(inviteId).run();
  if (result.meta.changes === 0) throw new ApiError("not_found");
  return ok(await inviteList(ctx), setCookie);
}

/** GET /api/admin/accounts */
export async function listAccounts(ctx: Ctx): Promise<Response> {
  const { setCookie } = await requireAdmin(ctx);
  return ok(await accountList(ctx), setCookie);
}

/**
 * POST /api/admin/sign-in-links — for an active friend's account; the previous unused link of that account is cancelled
 * (spec FR-08). The admin's own account is refused: a 24-hour bearer link to it would be an admin credential, and the
 * admin adds devices by pairing or by setup recovery (review N4 of F-2b, D-36).
 */
export async function createSignInLink(ctx: Ctx): Promise<Response> {
  const { setCookie } = await requireAdmin(ctx);
  const { db, pepper } = ctx.config;
  const accountId = idField(ctx.body.accountId);
  const token = randomToken();
  const expiresAt = ctx.now + SIGNIN_MS;
  const results = await db.batch([
    db.prepare("DELETE FROM links WHERE (account_id = ?1 AND kind = 'signin' AND used_at IS NULL) OR expires_at <= ?2").bind(accountId, ctx.now),
    db
      .prepare("INSERT INTO links (hash, kind, account_id, created_at, expires_at) SELECT ?1, 'signin', id, ?3, ?4 FROM accounts WHERE id = ?2 AND status = 'active' AND is_admin = 0")
      .bind(await hmacHex(pepper, token), accountId, ctx.now, expiresAt),
  ]);
  if (results[1]!.meta.changes === 0) throw await refusal(db, accountId, "account_not_active");
  return ok({ token, expiresAt }, setCookie);
}

/** POST /api/admin/accounts/block — the status, and the ways back in that are still unused (spec FR-09). */
export async function blockAccount(ctx: Ctx): Promise<Response> {
  const { setCookie } = await requireAdmin(ctx);
  const { db } = ctx.config;
  const accountId = idField(ctx.body.accountId);
  const friend = "EXISTS (SELECT 1 FROM accounts WHERE id = ?1 AND is_admin = 0)";
  const results = await db.batch([
    db.prepare("UPDATE accounts SET status = 'blocked', updated_at = ?2 WHERE id = ?1 AND is_admin = 0").bind(accountId, ctx.now),
    db.prepare(`DELETE FROM links WHERE account_id = ?1 AND kind IN ('pair', 'signin') AND used_at IS NULL AND ${friend}`).bind(accountId),
  ]);
  if (results[0]!.meta.changes === 0) throw await refusal(db, accountId, "account_not_active");
  return ok(await accountList(ctx), setCookie);
}

/** POST /api/admin/accounts/unblock — the sessions were kept, so the friend's devices work again. */
export async function unblockAccount(ctx: Ctx): Promise<Response> {
  const { setCookie } = await requireAdmin(ctx);
  const accountId = idField(ctx.body.accountId);
  const result = await ctx.config.db.prepare("UPDATE accounts SET status = 'active', updated_at = ?2 WHERE id = ?1").bind(accountId, ctx.now).run();
  if (result.meta.changes === 0) throw new ApiError("not_found");
  return ok(await accountList(ctx), setCookie);
}

/** POST /api/admin/accounts/delete — needs the friend's name as typed by the admin (spec FR-09). */
export async function deleteFriend(ctx: Ctx): Promise<Response> {
  const { setCookie } = await requireAdmin(ctx);
  await deleteAccount(ctx.config.db, idField(ctx.body.accountId), ctx.body.name);
  return ok(await accountList(ctx), setCookie);
}
