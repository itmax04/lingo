import { env } from "cloudflare:test";
import { afterEach, describe, expect, it, vi } from "vitest";
import staticHeaders from "../../../apps/web/public/_headers?raw";
import openapi from "../../../packages/contracts/api/openapi.yaml?raw";
import wranglerConfig from "../wrangler.jsonc?raw";
import { createHandler, MAX_BODY_BYTES, type Route } from "../src/app";
import { ERRORS, json, SECURITY_HEADERS } from "../src/http";
import { routes } from "../src/routes";
import { errorCode, get, ORIGIN, post, testEnv } from "./helpers";

const table: Route[] = [
  { method: "GET", path: "/api/t/ok", handler: async () => json(200, { ok: true }) },
  { method: "POST", path: "/api/t/echo", handler: async (ctx) => json(200, ctx.body) },
  { method: "POST", path: "/api/t/boom", handler: async () => Promise.reject(new TypeError("secret detail")) },
  { method: "GET", path: "/api/t/who", handler: async (ctx) => ((ctx.account = "acc-1"), json(200, { dev: ctx.config.devCookie })) },
];
const handle = createHandler(table);
const call = (request: Request, overrides = {}) => handle(request, testEnv(overrides));

afterEach(() => vi.restoreAllMocks());

describe("security headers (FR-55, FAC-18)", () => {
  it("are on every response: success, refusal, unknown path and failure", async () => {
    const responses = await Promise.all([
      call(get("/api/t/ok")),
      call(post("/api/t/echo", {}, { Origin: "https://evil.example" })),
      call(get("/api/nope")),
      call(get("/elsewhere")),
      call(post("/api/t/boom", {})),
      call(get("/api/t/ok"), { PEPPER: undefined }),
    ]);
    expect(responses.map((r) => r.status)).toEqual([200, 403, 404, 404, 500, 500]);
    for (const r of responses) {
      for (const [name, value] of Object.entries(SECURITY_HEADERS)) expect(r.headers.get(name)).toBe(value);
      expect(r.headers.get("Cache-Control")).toBe("no-store");
    }
  });

  it("are the same in the static site's _headers file", () => {
    const lines = staticHeaders.split("\n").filter((l) => l.trim() !== "" && !l.startsWith("#"));
    expect(lines[0]).toBe("/*");
    const parsed = Object.fromEntries(lines.slice(1).map((l) => [l.slice(0, l.indexOf(":")).trim(), l.slice(l.indexOf(":") + 1).trim()]));
    expect(parsed).toEqual(SECURITY_HEADERS);
  });

  it("allow scripts from the site only and connections to the three providers only", () => {
    const csp = SECURITY_HEADERS["Content-Security-Policy"]!;
    expect(csp).toContain("script-src 'self';");
    expect(csp).toContain("connect-src 'self' https://api.groq.com https://api.mistral.ai https://openrouter.ai;");
    expect(csp).toContain("frame-ancestors 'none'");
    expect(csp).not.toMatch(/unsafe|\*|data:|blob:/);
  });
});

describe("request origin and JSON body (FR-58)", () => {
  it("accepts a JSON object from the site's own origin", async () => {
    const r = await call(post("/api/t/echo", { a: 1 }));
    expect(r.status).toBe(200);
    expect(await r.json()).toEqual({ a: 1 });
  });

  it("refuses a missing, foreign or null Origin", async () => {
    const noOrigin = new Request(ORIGIN + "/api/t/echo", { method: "POST", headers: { "Content-Type": "application/json" }, body: "{}" });
    for (const request of [
      noOrigin,
      post("/api/t/echo", {}, { Origin: "https://evil.example" }),
      post("/api/t/echo", {}, { Origin: "null" }),
      post("/api/t/echo", {}, { Origin: ORIGIN.replace("https", "http") }),
    ]) {
      const r = await call(request);
      expect(r.status).toBe(403);
      expect(await errorCode(r)).toBe("origin_refused");
    }
  });

  it("accepts a charset parameter and any case of the media type", async () => {
    for (const type of ["application/json; charset=utf-8", "application/json;charset=UTF-8", "Application/JSON ; charset=utf-8"]) {
      const r = await call(post("/api/t/echo", { a: "ü" }, { "Content-Type": type }));
      expect(r.status).toBe(200);
      expect(await r.json()).toEqual({ a: "ü" });
    }
    expect(await errorCode(await call(post("/api/t/echo", {}, { "Content-Type": "application/jsonx" })))).toBe("json_required");
    expect(await errorCode(await call(post("/api/t/echo", {}, { "Content-Type": "text/plain; charset=application/json" })))).toBe("json_required");
  });

  it("refuses bytes that are not UTF-8 and an empty body; a byte order mark is ignored", async () => {
    const raw = (bytes: number[]) => new Request(ORIGIN + "/api/t/echo", { method: "POST", headers: { Origin: ORIGIN, "Content-Type": "application/json" }, body: new Uint8Array(bytes) });
    const text = (t: string) => [...new TextEncoder().encode(t)];
    const cases: Array<[string, number[]]> = [
      ["invalid byte", [...text('{"a":"'), 0xff, 0xfe, ...text('"}')]],
      ["truncated sequence", [...text('{"a":"'), 0xc3, ...text('"}')]],
      ["empty", []],
    ];
    for (const [label, bytes] of cases) {
      const r = await call(raw(bytes));
      expect([label, r.status]).toEqual([label, 403]);
      expect(await errorCode(r)).toBe("json_required");
    }
    // RFC 8259 lets a parser ignore a leading byte order mark; the decoder strips it.
    const bom = await call(raw([0xef, 0xbb, 0xbf, ...text('{"a":1}')]));
    expect(bom.status).toBe(200);
    expect(await bom.json()).toEqual({ a: 1 });
  });

  it("refuses a body that is not JSON", async () => {
    for (const request of [
      post("/api/t/echo", "a=1", { "Content-Type": "application/x-www-form-urlencoded" }),
      post("/api/t/echo", "{}", { "Content-Type": "text/plain" }),
      post("/api/t/echo", "{not json"),
    ]) {
      const r = await call(request);
      expect(r.status).toBe(403);
      expect(await errorCode(r)).toBe("json_required");
    }
  });

  it("refuses JSON that is not an object, and an oversized body", async () => {
    for (const body of ["[1]", "null", '"text"']) expect(await errorCode(await call(post("/api/t/echo", body)))).toBe("invalid_request");
    const big = await call(post("/api/t/echo", { pad: "x".repeat(MAX_BODY_BYTES) }));
    expect(big.status).toBe(413);
    expect(await errorCode(big)).toBe("body_too_large");
  });
});

describe("routing and failures", () => {
  it("answers 404 for an unknown path and 405 for another method", async () => {
    expect(await errorCode(await call(get("/api/nope")))).toBe("not_found");
    const wrong = await call(get("/api/t/echo"));
    expect(wrong.status).toBe(405);
    expect(await errorCode(wrong)).toBe("method_not_allowed");
    // The engine has GET and POST only (D-06): every other method on a known path is 405, with or without a body.
    for (const method of ["OPTIONS", "PUT", "PATCH", "DELETE", "HEAD"]) {
      for (const path of ["/api/t/ok", "/api/t/echo"]) {
        const headers = { Origin: ORIGIN, "Content-Type": "application/json" };
        const withBody = method === "PUT" || method === "PATCH" || method === "DELETE";
        const r = await call(new Request(ORIGIN + path, withBody ? { method, headers, body: "{}" } : { method, headers }));
        expect(r.status).toBe(405);
      }
    }
    expect((await call(new Request(ORIGIN + "/api/nope", { method: "DELETE" }))).status).toBe(404);
  });

  it("answers 500, never 401, when the pepper or the database is missing or the pepper is short (FR-07, FAC-03)", async () => {
    for (const overrides of [{ PEPPER: undefined }, { PEPPER: "short" }, { PEPPER: "x".repeat(42) }, { DB: undefined }]) {
      const r = await call(get("/api/t/ok"), overrides);
      expect(r.status).toBe(500);
      expect(await errorCode(r)).toBe("engine_misconfigured");
    }
  });

  it("hides an unexpected failure behind internal_error", async () => {
    const r = await call(post("/api/t/boom", {}));
    expect(r.status).toBe(500);
    expect(await r.text()).not.toContain("secret detail");
  });

  it("the shipped Worker answers an unknown API path with a typed 404", async () => {
    const worker = (await import("../src/index")).default;
    const r = await worker.fetch(get("/api/nope"), testEnv());
    expect(r.status).toBe(404);
  });

  it("the route table and openapi.yaml list the same operations", () => {
    const described = [...openapi.matchAll(/^  (\/api\/[^:\n]+):\n    (get|post):/gm)].map((m) => `${m[2]!.toUpperCase()} ${m[1]}`);
    expect(described.length).toBeGreaterThan(3);
    expect(described.sort()).toEqual(routes.map((r) => `${r.method} ${r.path}`).sort());
    // One method per path, so the pattern above sees every operation.
    expect([...openapi.matchAll(/^  \/api\//gm)].length).toBe(described.length);
    expect(openapi).not.toMatch(/^    (put|patch|delete|options|head):/m);
  });
});

describe("log line (FR-59)", () => {
  it("holds request id, route, status, duration and account id — nothing of the request", async () => {
    const lines: string[] = [];
    vi.spyOn(console, "log").mockImplementation((line: string) => void lines.push(line));
    await call(get("/api/t/who", { Cookie: "lingo_session=cookie-value" }));
    await call(post("/api/t/boom", { token: "body-value" }));
    await call(get("/api/unknown/path-value?q=query-value"));
    const logs = lines.map((l) => JSON.parse(l) as Record<string, unknown>);
    expect(logs.map((l) => [l.route, l.status, l.account])).toEqual([
      ["GET /api/t/who", 200, "acc-1"],
      ["POST /api/t/boom", 500, null],
      ["unmatched", 404, null],
    ]);
    expect(logs[1]!.error).toBe("TypeError");
    for (const l of logs) {
      expect(Object.keys(l).filter((k) => k !== "error").sort()).toEqual(["account", "ms", "rid", "route", "status"]);
    }
    expect(lines.join("\n")).not.toMatch(/cookie-value|body-value|path-value|query-value|secret detail/);
  });
});

describe("development cookie mode (FR-04)", () => {
  it("needs DEV_MODE=1 and a plain-http localhost request", async () => {
    const dev = async (origin: string, overrides = {}) =>
      ((await (await call(get("/api/t/who", {}, origin), overrides)).json()) as { dev: boolean }).dev;
    expect(await dev("http://localhost:8787", { DEV_MODE: "1" })).toBe(true);
    expect(await dev("http://127.0.0.1:8787", { DEV_MODE: "1" })).toBe(true);
    expect(await dev("http://localhost:8787")).toBe(false);
    expect(await dev("http://localhost:8787", { DEV_MODE: "true" })).toBe(false);
    expect(await dev("https://lingo.test", { DEV_MODE: "1" })).toBe(false);
    expect(await dev("http://localhost.evil.example", { DEV_MODE: "1" })).toBe(false);
  });
});

describe("configuration and contract", () => {
  it("the production configuration cannot set DEV_MODE, keeps platform logging off and names both switches", () => {
    expect(wranglerConfig).not.toContain("DEV_MODE\"");
    expect(wranglerConfig).toMatch(/"observability":\s*\{\s*"enabled":\s*false\s*\}/);
    expect(wranglerConfig).toContain('"preview_urls": false');
    expect(wranglerConfig).toContain('"INVITES_ENABLED": "1"');
    expect(wranglerConfig).toContain('"RELAY_ENABLED": "1"');
    expect(wranglerConfig).not.toMatch(/PEPPER"|SETUP_SECRET"/);
  });

  it("the error codes of the engine and of openapi.yaml are the same list", () => {
    const block = openapi.slice(openapi.indexOf("        code:\n"), openapi.indexOf("        message: { type: string }"));
    const listed = [...block.matchAll(/^\s+- (\w+)$/gm)].map((m) => m[1]);
    expect(listed).toEqual(Object.keys(ERRORS));
  });
});

describe("migration 0001", () => {
  const account = (id: string, admin: number) =>
    env.DB.prepare("INSERT INTO accounts (id, name, is_admin, created_at, updated_at) VALUES (?, 'N', ?, 1, 1)").bind(id, admin);

  it("a session belongs to its device's account; the admin flag is fixed and the admin is never blocked (0002, review R8)", async () => {
    const device = (id: string, acc: string) => env.DB.prepare("INSERT INTO devices (id, account_id, name, created_at, last_seen_at) VALUES (?, ?, 'D', 1, 1)").bind(id, acc);
    const session = (hash: string, acc: string, dev: string) =>
      env.DB.prepare("INSERT INTO sessions (hash, account_id, device_id, created_at, expires_at, extended_at) VALUES (?, ?, ?, 1, 2, 1)").bind(hash, acc, dev);
    await env.DB.batch([account("a", 0), account("b", 0), account("root", 1), device("da", "a"), device("db", "b"), session("ha", "a", "da")]);
    await expect(session("hx", "a", "db").run()).rejects.toThrow(/session account/);
    await expect(env.DB.prepare("UPDATE sessions SET account_id = 'b' WHERE hash = 'ha'").run()).rejects.toThrow(/session account/);
    await expect(env.DB.prepare("UPDATE sessions SET device_id = 'db' WHERE hash = 'ha'").run()).rejects.toThrow(/session account/);
    await expect(env.DB.prepare("UPDATE devices SET account_id = 'b' WHERE id = 'da'").run()).rejects.toThrow(/does not change/);
    await env.DB.prepare("UPDATE sessions SET expires_at = 3 WHERE hash = 'ha'").run();
    await env.DB.prepare("UPDATE devices SET name = 'E' WHERE id = 'da'").run();

    await expect(env.DB.prepare("UPDATE accounts SET status = 'blocked' WHERE id = 'root'").run()).rejects.toThrow(/admin/);
    await expect(env.DB.prepare("UPDATE accounts SET is_admin = 0 WHERE id = 'root'").run()).rejects.toThrow(/admin/);
    await expect(env.DB.prepare("UPDATE accounts SET is_admin = 1 WHERE id = 'a'").run()).rejects.toThrow(/admin flag is fixed/);
    await expect(env.DB.prepare("INSERT INTO accounts (id, name, is_admin, status, created_at, updated_at) VALUES ('x', 'N', 1, 'blocked', 1, 1)").run()).rejects.toThrow(/admin cannot be blocked/);
    await env.DB.prepare("UPDATE accounts SET status = 'blocked' WHERE id = 'a'").run();
    await env.DB.prepare("UPDATE accounts SET status = 'active', name = 'M' WHERE id = 'a'").run();
    await env.DB.prepare("UPDATE accounts SET name = 'Root' WHERE id = 'root'").run();
    expect(await env.DB.prepare("SELECT COUNT(*) AS n FROM accounts WHERE is_admin = 1 AND status = 'active'").first("n")).toBe(1);
    // Without an admin row the unique index cannot be what refuses a blocked admin.
    await env.DB.prepare("DELETE FROM accounts WHERE id = 'root'").run();
    await expect(env.DB.prepare("INSERT INTO accounts (id, name, is_admin, status, created_at, updated_at) VALUES ('x', 'N', 1, 'blocked', 1, 1)").run()).rejects.toThrow(/admin cannot be blocked/);
  });

  it("creates the six tables", async () => {
    const { results } = await env.DB.prepare(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_cf_%' AND name NOT LIKE 'd1_%' ORDER BY name",
    ).all<{ name: string }>();
    expect(results.map((r) => r.name)).toEqual(["accounts", "attempts", "devices", "events", "links", "sessions"]);
  });

  it("allows one admin only", async () => {
    await env.DB.batch([account("a", 1), account("b", 0), account("c", 0)]);
    await expect(account("d", 1).run()).rejects.toThrow(/UNIQUE/);
  });

  it("deleting an account removes its devices, sessions, links and events", async () => {
    await env.DB.batch([
      account("a", 0),
      env.DB.prepare("INSERT INTO devices (id, account_id, name, created_at, last_seen_at) VALUES ('d', 'a', 'D', 1, 1)"),
      env.DB.prepare("INSERT INTO sessions (hash, account_id, device_id, created_at, expires_at, extended_at) VALUES ('h', 'a', 'd', 1, 2, 1)"),
      env.DB.prepare("INSERT INTO links (hash, kind, account_id, created_at, expires_at) VALUES ('l', 'signin', 'a', 1, 2)"),
      env.DB.prepare("INSERT INTO events (account_id, event_id, body) VALUES ('a', 'e', '{}')"),
      env.DB.prepare("DELETE FROM accounts WHERE id = 'a'"),
    ]);
    for (const t of ["devices", "sessions", "links", "events"]) {
      expect(await env.DB.prepare(`SELECT COUNT(*) AS n FROM ${t}`).first("n")).toBe(0);
    }
  });

  it("an invite has a name and no account; other links have an account", async () => {
    const link = (kind: string, accountId: string | null, name: string | null) =>
      env.DB.prepare("INSERT INTO links (hash, kind, account_id, name, created_at, expires_at) VALUES (?, ?, ?, ?, 1, 2)").bind(
        crypto.randomUUID(), kind, accountId, name);
    await account("a", 0).run();
    await link("invite", null, "Friend").run();
    await link("pair", "a", null).run();
    await expect(link("invite", "a", "Friend").run()).rejects.toThrow(/CHECK/);
    // A used invite points at the account it created and goes away with it, name included.
    await env.DB.prepare("UPDATE links SET used_at = 1, account_id = 'a' WHERE kind = 'invite'").run();
    await env.DB.prepare("DELETE FROM accounts WHERE id = 'a'").run();
    expect(await env.DB.prepare("SELECT COUNT(*) AS n FROM links").first("n")).toBe(0);
    await expect(env.DB.prepare("INSERT INTO links (hash, code_hash, kind, name, created_at, expires_at) VALUES ('x', 'c', 'invite', 'F', 1, 2)").run()).rejects.toThrow(/CHECK/);
    await expect(link("invite", null, null).run()).rejects.toThrow(/CHECK/);
    await expect(link("signin", null, null).run()).rejects.toThrow(/CHECK/);
  });
});
