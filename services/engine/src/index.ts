/** Lingo Engine entry (WR-27): API and sign-in routes here, every other path is a static asset of the web client. */
export interface Env {
  DB: D1Database;
  ASSETS: Fetcher;
}

const SECURITY_HEADERS: Record<string, string> = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "x-content-type-options": "nosniff",
  "referrer-policy": "no-referrer",
};

export function json(body: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...SECURITY_HEADERS, ...headers } });
}

/** Error body shape shared by every API route (the OpenAPI `Error` schema). */
export function error(status: number, code: string, message: string, headers: Record<string, string> = {}): Response {
  return json({ error: { code, message } }, status, headers);
}

export function isApiPath(path: string): boolean {
  return path === "/api" || path.startsWith("/api/") || path === "/auth" || path.startsWith("/auth/");
}

async function api(request: Request, env: Env, url: URL): Promise<Response> {
  if (url.pathname === "/api/health") {
    if (request.method !== "GET") return error(405, "method_not_allowed", "Use GET.", { allow: "GET" });
    // A trivial query proves the D1 binding without touching learner data.
    const row = await env.DB.prepare("SELECT 1 AS ok").first<{ ok: number }>();
    return json({ ok: row?.ok === 1 });
  }
  return error(404, "not_found", "No such API route.");
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (isApiPath(url.pathname)) return api(request, env, url);
    return env.ASSETS.fetch(request);
  },
} satisfies ExportedHandler<Env>;
