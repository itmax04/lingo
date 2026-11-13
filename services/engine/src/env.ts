/** Bindings, secrets and variables of the Worker. Everything is optional: a faulty release must answer 500, not crash or 401. */
export interface Env {
  DB?: D1Database;
  /** Secret: the HMAC key for link and session tokens (spec FR-02, FR-04). */
  PEPPER?: string;
  /** Secret: set only while the owner creates or recovers the admin (spec FR-11). */
  SETUP_SECRET?: string;
  INVITES_ENABLED?: string;
  RELAY_ENABLED?: string;
  /** Local development only (`.dev.vars`); never in wrangler.jsonc. */
  DEV_MODE?: string;
}

export interface Config {
  db: D1Database;
  pepper: string;
  /** `null` when not configured or too short: `/api/setup` then answers 404. */
  setupSecret: string | null;
  invitesEnabled: boolean;
  relayEnabled: boolean;
  /** Plain `lingo_session` cookie without `Secure`: only with DEV_MODE=1 and a plain-http localhost request. */
  devCookie: boolean;
}

/** 32 random bytes in base64url. A shorter secret counts as missing. */
export const MIN_SECRET_LENGTH = 43;

const usable = (secret: string | undefined): secret is string => typeof secret === "string" && secret.length >= MIN_SECRET_LENGTH;

/** Returns `null` when the database or the pepper is missing (answered as 500 `engine_misconfigured`). */
export function readConfig(env: Env, url: URL): Config | null {
  if (!env.DB || !usable(env.PEPPER)) return null;
  const localHttp = url.protocol === "http:" && (url.hostname === "localhost" || url.hostname === "127.0.0.1");
  return {
    db: env.DB,
    pepper: env.PEPPER,
    setupSecret: usable(env.SETUP_SECRET) ? env.SETUP_SECRET : null,
    invitesEnabled: env.INVITES_ENABLED === "1",
    relayEnabled: env.RELAY_ENABLED === "1",
    devCookie: env.DEV_MODE === "1" && localHttp,
  };
}
