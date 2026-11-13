import type { Ctx } from "./app";
import type { Config } from "./env";
import { hmacHex, TOKEN_PATTERN } from "./crypto";
import { ApiError } from "./http";

const DAY_MS = 24 * 60 * 60 * 1000;
/** Sliding expiry without use (spec FR-04). */
export const SESSION_MS = 90 * DAY_MS;

/** `__Host-lingo_session` with `Secure`; the plain development cookie only on http://localhost with DEV_MODE=1. */
const cookieName = (config: Config): string => (config.devCookie ? "lingo_session" : "__Host-lingo_session");
const cookie = (config: Config, value: string, maxAge: number): string =>
  `${cookieName(config)}=${value}; Path=/; HttpOnly; ${config.devCookie ? "" : "Secure; "}SameSite=Lax; Max-Age=${maxAge}`;

export const sessionCookie = (config: Config, token: string): string => cookie(config, token, SESSION_MS / 1000);
export const clearedCookie = (config: Config): string => cookie(config, "", 0);

function readToken(request: Request, config: Config): string | null {
  const name = cookieName(config);
  for (const part of (request.headers.get("Cookie") ?? "").split(";")) {
    const at = part.indexOf("=");
    if (at > 0 && part.slice(0, at).trim() === name) return part.slice(at + 1).trim();
  }
  return null;
}

interface Row {
  account_id: string;
  device_id: string;
  expires_at: number;
  extended_at: number;
  revoked_at: number | null;
  name: string;
  is_admin: number;
  status: string;
  device_name: string;
}

type Lookup = { state: "none" | "ended" } | { state: "ok" | "blocked"; row: Row; hash: string; token: string };

/** Reads the request's session without changing anything. */
export async function lookupSession(ctx: Ctx): Promise<Lookup> {
  const token = readToken(ctx.request, ctx.config);
  if (token === null) return { state: "none" };
  if (!TOKEN_PATTERN.test(token)) return { state: "ended" };
  const hash = await hmacHex(ctx.config.pepper, token);
  const row = await ctx.config.db
    .prepare(
      `SELECT s.account_id, s.device_id, s.expires_at, s.extended_at, s.revoked_at, a.name, a.is_admin, a.status, d.name AS device_name
       FROM sessions s JOIN accounts a ON a.id = s.account_id JOIN devices d ON d.id = s.device_id WHERE s.hash = ?`,
    )
    .bind(hash)
    .first<Row>();
  if (row === null || row.revoked_at !== null || row.expires_at <= ctx.now) return { state: "ended" };
  return { state: row.status === "blocked" ? "blocked" : "ok", row, hash, token };
}

export interface Me {
  account: { id: string; name: string; isAdmin: boolean };
  device: { id: string; name: string };
}

/**
 * The signed-in account of the request, or a typed refusal (spec FR-07): `not_signed_in` without a cookie, `session_ended`
 * for an unknown, revoked or expired session (the cookie is cleared), `account_blocked`. A used session is extended to 90
 * days at most once a day; `setCookie` is then the refreshed cookie for the answer.
 */
export async function authenticate(ctx: Ctx): Promise<{ me: Me; setCookie: string | null }> {
  const found = await lookupSession(ctx);
  if (!("row" in found)) {
    if (found.state === "none") throw new ApiError("not_signed_in");
    throw new ApiError("session_ended", { headers: { "Set-Cookie": clearedCookie(ctx.config) } });
  }
  const { row } = found;
  ctx.account = row.account_id;
  if (found.state === "blocked") throw new ApiError("account_blocked");
  let setCookie: string | null = null;
  if (ctx.now - row.extended_at >= DAY_MS) {
    const { db } = ctx.config;
    await db.batch([
      db.prepare("UPDATE sessions SET expires_at = ?, extended_at = ? WHERE hash = ?").bind(ctx.now + SESSION_MS, ctx.now, found.hash),
      db.prepare("UPDATE devices SET last_seen_at = ? WHERE id = ?").bind(ctx.now, row.device_id),
    ]);
    setCookie = sessionCookie(ctx.config, found.token);
  }
  return {
    me: { account: { id: row.account_id, name: row.name, isAdmin: row.is_admin === 1 }, device: { id: row.device_id, name: row.device_name } },
    setCookie,
  };
}
