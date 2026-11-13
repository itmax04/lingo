import { readConfig, type Config, type Env } from "./env";
import { ApiError, type ErrorCode } from "./http";

export interface Ctx {
  request: Request;
  url: URL;
  config: Config;
  /** The parsed JSON object of a POST; empty for GET. */
  body: Record<string, unknown>;
  now: number;
  /** Set by the session check; goes into the log line. */
  account: string | null;
}

export interface Route {
  method: "GET" | "POST";
  path: string;
  handler: (ctx: Ctx) => Promise<Response>;
}

/** Default body limit; sync (F-3) and the relay (F-4) bring their own. */
export const MAX_BODY_BYTES = 16 * 1024;

const fail = (code: ErrorCode): never => {
  throw new ApiError(code);
};

/** Spec FR-58: a state-changing request carries the site's own Origin and a JSON object. */
async function readBody(request: Request, url: URL): Promise<Record<string, unknown>> {
  if (request.headers.get("Origin") !== url.origin) fail("origin_refused");
  const type = (request.headers.get("Content-Type") ?? "").split(";")[0]!.trim().toLowerCase();
  if (type !== "application/json") fail("json_required");
  if (Number(request.headers.get("Content-Length") ?? 0) > MAX_BODY_BYTES) fail("body_too_large");
  const bytes = await request.arrayBuffer();
  if (bytes.byteLength > MAX_BODY_BYTES) fail("body_too_large");
  let value: unknown;
  try {
    value = JSON.parse(new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(bytes));
  } catch {
    fail("json_required");
  }
  if (typeof value !== "object" || value === null || Array.isArray(value)) fail("invalid_request");
  return value as Record<string, unknown>;
}

interface LogLine {
  rid: string;
  route: string;
  status: number;
  ms: number;
  account: string | null;
  error?: string;
}

async function dispatch(table: readonly Route[], request: Request, env: Env, log: LogLine): Promise<Response> {
  const url = new URL(request.url);
  const matches = table.filter((r) => r.path === url.pathname);
  if (matches.length === 0) fail("not_found");
  const route = matches.find((r) => r.method === request.method) ?? fail("method_not_allowed");
  log.route = `${route.method} ${route.path}`;
  const config = readConfig(env, url) ?? fail("engine_misconfigured");
  const body = route.method === "POST" ? await readBody(request, url) : {};
  const ctx: Ctx = { request, url, config, body, now: Date.now(), account: null };
  try {
    return await route.handler(ctx);
  } finally {
    log.account = ctx.account;
  }
}

export function createHandler(table: readonly Route[]) {
  return async (request: Request, env: Env): Promise<Response> => {
    const started = Date.now();
    // Spec FR-59: request id, route, status, duration, account id — and nothing of the request's content.
    const log: LogLine = { rid: crypto.randomUUID(), route: "unmatched", status: 0, ms: 0, account: null };
    let response: Response;
    try {
      response = await dispatch(table, request, env, log);
    } catch (e) {
      if (e instanceof ApiError) {
        response = e.response();
      } else {
        log.error = e instanceof Error ? e.name : "unknown";
        response = new ApiError("internal_error").response();
      }
    }
    log.status = response.status;
    log.ms = Date.now() - started;
    console.log(JSON.stringify(log));
    return response;
  };
}
