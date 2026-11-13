import { env } from "cloudflare:test";
import type { Env } from "../src/env";

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
