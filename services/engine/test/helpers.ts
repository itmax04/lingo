import { env } from "cloudflare:test";
import { expect } from "vitest";
import { createHandler } from "../src/app";
import { hmacHex } from "../src/crypto";
import type { Env } from "../src/env";
import { routes } from "../src/routes";

export const ORIGIN = "https://lingo.test";

/** 32 random bytes, base64url: the shape of every secret and token. Generated per run; nothing secret is in the repository. */
export function randomSecret(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

export const PEPPER = randomSecret();
export const SETUP_SECRET = randomSecret();

/** A complete production-like env. Tests override single fields; nothing is read from `.dev.vars`. */
export function testEnv(overrides: Partial<Record<keyof Env, unknown>> = {}): Env {
  return { DB: env.DB, PEPPER, SETUP_SECRET, INVITES_ENABLED: "1", RELAY_ENABLED: "1", ...overrides } as Env;
}

export function get(path: string, headers: Record<string, string> = {}, origin = ORIGIN): Request {
  return new Request(origin + path, { headers });
}

export function post(path: string, body: unknown, headers: Record<string, string> = {}, origin = ORIGIN): Request {
  return new Request(origin + path, {
    method: "POST",
    headers: { Origin: origin, "Content-Type": "application/json", ...headers },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

export async function errorCode(response: Response): Promise<string> {
  return ((await response.json()) as { code: string }).code;
}

const handle = createHandler(routes);
/** The shipped route table with a production-like env. */
export const call = (request: Request, overrides = {}): Promise<Response> => handle(request, testEnv(overrides));

export const count = async (table: string): Promise<number> => (await env.DB.prepare(`SELECT COUNT(*) AS n FROM ${table}`).first<number>("n"))!;
export const ip = (address: string): Record<string, string> => ({ "CF-Connecting-IP": address });

/** Inserts a link row directly and returns its token. */
export async function invite(options: { name?: string; kind?: string; expiresIn?: number; revoked?: boolean; accountId?: string } = {}): Promise<string> {
  const token = randomSecret();
  const kind = options.kind ?? "invite";
  await env.DB.prepare("INSERT INTO links (hash, kind, account_id, name, created_at, expires_at, revoked_at) VALUES (?, ?, ?, ?, ?, ?, ?)")
    .bind(await hmacHex(PEPPER, token), kind, options.accountId ?? null, kind === "invite" ? (options.name ?? "Friend") : null,
      Date.now(), Date.now() + (options.expiresIn ?? 7 * 24 * 60 * 60 * 1000), options.revoked ? Date.now() : null)
    .run();
  return token;
}

/** `name=value` of the session cookie an answer sets, ready for a `Cookie` header. */
export function cookieOf(response: Response): string {
  return (response.headers.get("Set-Cookie") ?? "").split(";")[0]!;
}

/** A new account signed in on its first device. */
export async function joined(name = "Friend"): Promise<{ cookie: string; token: string; accountId: string; deviceId: string }> {
  const token = await invite({ name });
  const response = await call(post("/api/join", { token }));
  expect(response.status).toBe(200);
  const body = (await response.json()) as { account: { id: string }; device: { id: string } };
  return { cookie: cookieOf(response), token, accountId: body.account.id, deviceId: body.device.id };
}
