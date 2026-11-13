import { env } from "cloudflare:test";
import { afterEach, describe, expect, it, vi } from "vitest";
import { createHandler } from "../src/app";
import { clientBucket } from "../src/attempts";
import { hmacHex } from "../src/crypto";
import { routes } from "../src/routes";
import { errorCode, get, ORIGIN, PEPPER, post, randomSecret, SETUP_SECRET, testEnv } from "./helpers";

const handle = createHandler(routes);
const call = (request: Request, overrides = {}) => handle(request, testEnv(overrides));
const DAY = 24 * 60 * 60 * 1000;
const LINK_INVALID = { code: "link_invalid", message: "This link is no longer valid. Ask for a new one." };

const count = async (table: string) => (await env.DB.prepare(`SELECT COUNT(*) AS n FROM ${table}`).first<number>("n"))!;
const counts = async () => Promise.all(["accounts", "devices", "sessions"].map(count));
const ip = (address: string) => ({ "CF-Connecting-IP": address });

async function invite(options: { name?: string; kind?: string; expiresIn?: number; revoked?: boolean; accountId?: string } = {}): Promise<string> {
  const token = randomSecret();
  const kind = options.kind ?? "invite";
  await env.DB.prepare("INSERT INTO links (hash, kind, account_id, name, created_at, expires_at, revoked_at) VALUES (?, ?, ?, ?, ?, ?, ?)")
    .bind(await hmacHex(PEPPER, token), kind, options.accountId ?? null, kind === "invite" ? (options.name ?? "Friend") : null,
      Date.now(), Date.now() + (options.expiresIn ?? 7 * DAY), options.revoked ? Date.now() : null)
    .run();
  return token;
}

/** `name=value` of the session cookie an answer sets, ready for a `Cookie` header. */
function cookieOf(response: Response): string {
  return (response.headers.get("Set-Cookie") ?? "").split(";")[0]!;
}

async function joined(name = "Friend"): Promise<{ cookie: string; token: string; accountId: string }> {
  const token = await invite({ name });
  const response = await call(post("/api/join", { token }));
  expect(response.status).toBe(200);
  const body = (await response.json()) as { account: { id: string } };
  return { cookie: cookieOf(response), token, accountId: body.account.id };
}

afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
});

describe("POST /api/join (FAC-01)", () => {
  it("redeems an invite: a new account with the invite's name, a device and a session", async () => {
    const token = await invite({ name: "Zoë Müller" });
    const response = await call(post("/api/join", { token, deviceName: "Safari on iPhone" }));
    expect(response.status).toBe(200);
    const body = (await response.json()) as { account: { id: string; name: string; isAdmin: boolean }; device: { id: string; name: string } };
    expect(body.account).toMatchObject({ name: "Zoë Müller", isAdmin: false });
    expect(body.device.name).toBe("Safari on iPhone");
    expect(response.headers.get("Set-Cookie")).toMatch(/^__Host-lingo_session=[A-Za-z0-9_-]{43}; Path=\/; HttpOnly; Secure; SameSite=Lax; Max-Age=7776000$/);
    expect(await counts()).toEqual([1, 1, 1]);
    expect(await count("events")).toBe(0);

    const me = await call(get("/api/me", { Cookie: cookieOf(response) }));
    expect(me.status).toBe(200);
    expect(await me.json()).toEqual(body);
  });

  it("gives one and the same refusal for a used, expired, revoked, unknown, malformed token and a token of another kind", async () => {
    const used = await invite();
    expect((await call(post("/api/join", { token: used }))).status).toBe(200);
    const owner = (await env.DB.prepare("SELECT id FROM accounts").first<string>("id"))!;
    const before = await counts();
    const tokens = [
      used,
      await invite({ expiresIn: -1 }),
      await invite({ revoked: true }),
      randomSecret(),
      "short",
      await invite({ kind: "pair", accountId: owner }),
      await invite({ kind: "signin", accountId: owner }),
    ];
    for (const [i, token] of tokens.entries()) {
      const response = await call(post("/api/join", { token }, ip(`198.51.100.${i}`)));
      expect(response.status).toBe(410);
      expect(await response.json()).toEqual(LINK_INVALID);
      expect(response.headers.get("Set-Cookie")).toBeNull();
    }
    expect(await counts()).toEqual(before);
    expect(await env.DB.prepare("SELECT COUNT(*) AS n FROM links WHERE kind <> 'invite' AND used_at IS NOT NULL").first("n")).toBe(0);
  });

  it("two concurrent redemptions of one token create one account and one session", async () => {
    const token = await invite();
    const responses = await Promise.all([1, 2, 3, 4].map((i) => call(post("/api/join", { token }, ip(`198.51.100.${i}`)))));
    expect(responses.map((r) => r.status).sort()).toEqual([200, 410, 410, 410]);
    expect(await counts()).toEqual([1, 1, 1]);
  });

  it("a GET changes nothing", async () => {
    const token = await invite();
    const response = await call(get(`/api/join?token=${token}`));
    expect(response.status).toBe(405);
    expect(await counts()).toEqual([0, 0, 0]);
    expect(await env.DB.prepare("SELECT used_at FROM links").first("used_at")).toBeNull();
  });

  it("stores no link or session token in clear", async () => {
    const { token, cookie } = await joined();
    const session = cookie.split("=")[1]!;
    expect(session).toMatch(/^[A-Za-z0-9_-]{43}$/);
    const dump = JSON.stringify(
      await Promise.all(["accounts", "devices", "sessions", "links", "attempts"].map((t) => env.DB.prepare(`SELECT * FROM ${t}`).all())),
    );
    expect(dump).not.toContain(token);
    expect(dump).not.toContain(session);
    expect(dump).toContain(await hmacHex(PEPPER, token));
    expect(dump).toContain(await hmacHex(PEPPER, session));
  });

  it("deleting the account leaves no row with its name, the used invite included", async () => {
    const { accountId } = await joined("Unique Friend Name");
    expect(await env.DB.prepare("SELECT account_id FROM links").first("account_id")).toBe(accountId);
    await env.DB.prepare("DELETE FROM accounts WHERE id = ?").bind(accountId).run();
    const dump = JSON.stringify(
      await Promise.all(["accounts", "devices", "sessions", "links", "events"].map((t) => env.DB.prepare(`SELECT * FROM ${t}`).all())),
    );
    expect(dump).not.toContain("Unique Friend Name");
    expect(await count("links")).toBe(0);
  });

  it("is not redeemed on a signed-in device; the link stays usable", async () => {
    const { cookie } = await joined();
    const token = await invite({ name: "Second" });
    const refused = await call(post("/api/join", { token }, { Cookie: cookie }));
    expect(refused.status).toBe(409);
    expect(await errorCode(refused)).toBe("already_signed_in");
    expect(await count("accounts")).toBe(1);
    expect((await call(post("/api/join", { token }))).status).toBe(200);
  });

  it("is refused while invites are switched off, and the link stays unused", async () => {
    const token = await invite();
    for (const value of ["0", "", undefined, "true"]) {
      const response = await call(post("/api/join", { token }), { INVITES_ENABLED: value });
      expect(response.status).toBe(503);
      expect(await errorCode(response)).toBe("invites_disabled");
    }
    expect(await count("accounts")).toBe(0);
    expect((await call(post("/api/join", { token }))).status).toBe(200);
  });

  it("refuses a missing token and a bad device name as invalid requests", async () => {
    const token = await invite();
    for (const body of [{}, { token: 5 }, { token, deviceName: "" }, { token, deviceName: "x".repeat(41) }, { token, deviceName: 7 }]) {
      const response = await call(post("/api/join", body));
      expect(response.status).toBe(400);
    }
    expect(await count("attempts")).toBe(0);
    expect((await call(post("/api/join", { token, deviceName: "ü".repeat(40) }))).status).toBe(200);
  });

  it("limits failed attempts per client: the 11th is refused with 429 and writes nothing (FR-06)", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(new Date("2026-11-13T10:01:00Z"));
    const client = ip("203.0.113.7");
    for (let i = 0; i < 10; i++) expect((await call(post("/api/join", { token: randomSecret() }, client))).status).toBe(410);
    const attempts = async () => JSON.stringify((await env.DB.prepare("SELECT * FROM attempts ORDER BY bucket, window_start").all()).results);
    const before = await attempts();

    const valid = await invite();
    for (const token of [randomSecret(), valid]) {
      const refused = await call(post("/api/join", { token }, client));
      expect(refused.status).toBe(429);
      expect(await refused.json()).toEqual(LINK_INVALID);
    }
    expect(await attempts()).toBe(before);
    expect(await count("accounts")).toBe(0);

    // Still refused in the next window (no 10 minutes hold more than 10 failures), free again after it.
    vi.setSystemTime(new Date("2026-11-13T10:10:30Z"));
    expect((await call(post("/api/join", { token: randomSecret() }, client))).status).toBe(429);
    vi.setSystemTime(new Date("2026-11-13T10:20:01Z"));
    expect((await call(post("/api/join", { token: valid }, client))).status).toBe(200);
  });

  it("counts an IPv6 /64 as one client and other clients separately", async () => {
    for (let i = 0; i < 10; i++) {
      expect((await call(post("/api/join", { token: randomSecret() }, ip(`2001:db8:1:2:${i}::${i + 1}`)))).status).toBe(410);
    }
    expect((await call(post("/api/join", { token: randomSecret() }, ip("2001:db8:1:2:ffff::1")))).status).toBe(429);
    expect((await call(post("/api/join", { token: randomSecret() }, ip("2001:db8:1:3::1")))).status).toBe(410);
    expect((await call(post("/api/join", { token: randomSecret() }, ip("203.0.113.9")))).status).toBe(410);

    const bucket = (address: string) => clientBucket(new Request(ORIGIN, { headers: ip(address) }));
    expect(bucket("2001:DB8:1:2::1")).toBe("ip6:2001:db8:1:2");
    expect(bucket("2001:db8:1:2:3:4:5:6")).toBe("ip6:2001:db8:1:2");
    expect(bucket("::1")).toBe("ip6:0:0:0:0");
    expect(bucket("2001:db8::")).toBe("ip6:2001:db8:0:0");
    expect(bucket("::ffff:203.0.113.9")).toBe("ip:203.0.113.9");
    expect(bucket("203.0.113.9")).toBe("ip:203.0.113.9");
    expect(clientBucket(new Request(ORIGIN))).toBe("ip:unknown");
  });
});

describe("POST /api/setup (FR-11)", () => {
  const setup = (secret: unknown, headers: Record<string, string> = {}, extra: Record<string, unknown> = {}) =>
    post("/api/setup", { secret, ...extra }, headers);

  it("answers 404 without a setup secret or with one shorter than 32 bytes", async () => {
    for (const value of [undefined, "", "x".repeat(42)]) {
      const response = await call(setup(value ?? SETUP_SECRET), { SETUP_SECRET: value });
      expect(response.status).toBe(404);
      expect(await errorCode(response)).toBe("not_found");
    }
    expect(await count("accounts")).toBe(0);
    expect(await count("attempts")).toBe(0);
  });

  it("creates the admin once, then signs the same admin in on a new device and creates nothing else", async () => {
    const friend = await joined("Friend");
    const first = await call(setup(SETUP_SECRET, {}, { name: "Max", deviceName: "Mac" }));
    expect(first.status).toBe(200);
    const admin = (await first.json()) as { account: { id: string; name: string; isAdmin: boolean }; device: { id: string } };
    expect(admin.account).toMatchObject({ name: "Max", isAdmin: true });
    expect(first.headers.get("Set-Cookie")).toMatch(/^__Host-lingo_session=[A-Za-z0-9_-]{43}; /);

    const again = await call(setup(SETUP_SECRET, {}, { name: "Other name" }));
    expect(again.status).toBe(200);
    const recovered = (await again.json()) as typeof admin;
    expect(recovered.account).toEqual(admin.account);
    expect(recovered.device.id).not.toBe(admin.device.id);
    expect(await counts()).toEqual([2, 3, 3]);
    expect(await env.DB.prepare("SELECT COUNT(*) AS n FROM accounts WHERE is_admin = 1").first("n")).toBe(1);

    for (const response of [first, again]) {
      const me = await call(get("/api/me", { Cookie: cookieOf(response) }));
      expect(((await me.json()) as typeof admin).account.id).toBe(admin.account.id);
    }
    const friendMe = (await (await call(get("/api/me", { Cookie: friend.cookie }))).json()) as typeof admin;
    expect(friendMe.account).toMatchObject({ id: friend.accountId, isAdmin: false });
  });

  it("concurrent first setups create one admin", async () => {
    const responses = await Promise.all([1, 2, 3].map(() => call(setup(SETUP_SECRET))));
    expect(responses.map((r) => r.status)).toEqual([200, 200, 200]);
    expect(await counts()).toEqual([1, 3, 3]);
  });

  it("refuses a wrong secret and counts it against the client", async () => {
    for (const wrong of [randomSecret(), SETUP_SECRET.slice(0, -1), SETUP_SECRET + "x", ""]) {
      const response = await call(setup(wrong, ip("203.0.113.7")));
      expect(response.status).toBe(403);
      expect(await errorCode(response)).toBe("secret_invalid");
      expect(response.headers.get("Set-Cookie")).toBeNull();
    }
    expect(await count("accounts")).toBe(0);
    const rows = (await env.DB.prepare("SELECT bucket, failures FROM attempts ORDER BY bucket").all()).results;
    expect(rows).toEqual([{ bucket: "ip:203.0.113.7", failures: 4 }, { bucket: "setup", failures: 4 }]);
  });

  it("shares the client limit with link attempts and has a global limit of 20 failures; refusals write nothing", async () => {
    const client = ip("203.0.113.7");
    for (let i = 0; i < 6; i++) await call(post("/api/join", { token: randomSecret() }, client));
    for (let i = 0; i < 4; i++) expect((await call(setup(randomSecret(), client))).status).toBe(403);
    const refused = await call(setup(SETUP_SECRET, client));
    expect(refused.status).toBe(429);
    expect(await errorCode(refused)).toBe("too_many_attempts");

    for (let i = 0; i < 16; i++) expect((await call(setup(randomSecret(), ip(`198.51.100.${i}`)))).status).toBe(403);
    const attempts = async () => JSON.stringify((await env.DB.prepare("SELECT * FROM attempts ORDER BY bucket").all()).results);
    const before = await attempts();
    const stranger = await call(setup(SETUP_SECRET, ip("192.0.2.1")));
    expect(stranger.status).toBe(429);
    expect(await attempts()).toBe(before);
    expect(await count("accounts")).toBe(0);
    // Link attempts of other clients are not affected by the global setup limit.
    expect((await call(post("/api/join", { token: await invite() }, ip("192.0.2.1")))).status).toBe(200);
  });

  it("is not used on a signed-in device and refuses bad fields", async () => {
    const { cookie } = await joined();
    const refused = await call(setup(SETUP_SECRET, { Cookie: cookie }));
    expect(refused.status).toBe(409);
    for (const body of [{}, { secret: 1 }, { secret: SETUP_SECRET, name: "" }, { secret: SETUP_SECRET, name: "x".repeat(41) }]) {
      expect((await call(post("/api/setup", body))).status).toBe(400);
    }
    expect(await env.DB.prepare("SELECT COUNT(*) AS n FROM accounts WHERE is_admin = 1").first("n")).toBe(0);
  });
});

describe("sessions (FR-04, FR-07, FAC-03)", () => {
  it("no cookie: 401 not_signed_in and no cookie change", async () => {
    const response = await call(get("/api/me"));
    expect(response.status).toBe(401);
    expect(await errorCode(response)).toBe("not_signed_in");
    expect(response.headers.get("Set-Cookie")).toBeNull();
  });

  it("an unknown, malformed or revoked session: 401 session_ended and the cookie is cleared", async () => {
    const { cookie } = await joined();
    const check = async (value: string) => {
      const response = await call(get("/api/me", { Cookie: value }));
      expect(response.status).toBe(401);
      expect(await errorCode(response)).toBe("session_ended");
      expect(response.headers.get("Set-Cookie")).toBe("__Host-lingo_session=; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=0");
    };
    await check(`__Host-lingo_session=${randomSecret()}`);
    await check("__Host-lingo_session=garbage");
    await check("__Host-lingo_session=");
    expect((await call(get("/api/me", { Cookie: `theme=dark; ${cookie}; other=1` }))).status).toBe(200);
    await env.DB.prepare("UPDATE sessions SET revoked_at = ?").bind(Date.now()).run();
    await check(cookie);
  });

  it("extends the expiry at most once a day and refuses a session unused for 91 days", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    const start = new Date("2026-11-13T10:00:00Z").getTime();
    vi.setSystemTime(start);
    const { cookie } = await joined();
    const row = () => env.DB.prepare("SELECT s.expires_at, s.extended_at, d.last_seen_at FROM sessions s JOIN devices d ON d.id = s.device_id").first();
    expect(await row()).toEqual({ expires_at: start + 90 * DAY, extended_at: start, last_seen_at: start });

    vi.setSystemTime(start + 23 * 60 * 60 * 1000);
    const sameDay = await call(get("/api/me", { Cookie: cookie }));
    expect(sameDay.status).toBe(200);
    expect(sameDay.headers.get("Set-Cookie")).toBeNull();
    expect(await row()).toEqual({ expires_at: start + 90 * DAY, extended_at: start, last_seen_at: start });

    const nextDay = start + DAY + 1000;
    vi.setSystemTime(nextDay);
    const extended = await call(get("/api/me", { Cookie: cookie }));
    expect(extended.status).toBe(200);
    expect(extended.headers.get("Set-Cookie")).toBe(`${cookie}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=7776000`);
    expect(await row()).toEqual({ expires_at: nextDay + 90 * DAY, extended_at: nextDay, last_seen_at: nextDay });
    expect((await call(get("/api/me", { Cookie: cookie }))).headers.get("Set-Cookie")).toBeNull();

    vi.setSystemTime(nextDay + 90 * DAY - 1000);
    expect((await call(get("/api/me", { Cookie: cookie }))).status).toBe(200);
    vi.setSystemTime(nextDay + 90 * DAY - 1000 + 91 * DAY);
    const expired = await call(get("/api/me", { Cookie: cookie }));
    expect(expired.status).toBe(401);
    expect(await errorCode(expired)).toBe("session_ended");
  });

  it("a blocked account: 403 account_blocked, the cookie stays, and unblocking restores access", async () => {
    const { cookie, accountId } = await joined();
    await env.DB.prepare("UPDATE accounts SET status = 'blocked' WHERE id = ?").bind(accountId).run();
    const blocked = await call(get("/api/me", { Cookie: cookie }));
    expect(blocked.status).toBe(403);
    expect(await errorCode(blocked)).toBe("account_blocked");
    expect(blocked.headers.get("Set-Cookie")).toBeNull();
    await env.DB.prepare("UPDATE accounts SET status = 'active' WHERE id = ?").bind(accountId).run();
    expect((await call(get("/api/me", { Cookie: cookie }))).status).toBe(200);
  });

  it("a missing pepper or database gives 500, not 401, to a signed-in device", async () => {
    const { cookie } = await joined();
    for (const overrides of [{ PEPPER: undefined }, { DB: undefined }]) {
      const response = await call(get("/api/me", { Cookie: cookie }), overrides);
      expect(response.status).toBe(500);
      expect(await errorCode(response)).toBe("engine_misconfigured");
      expect(response.headers.get("Set-Cookie")).toBeNull();
    }
    // Another pepper is another key: the session is unknown to it (the deploy guide warns that this signs everyone out).
    expect(await errorCode(await call(get("/api/me", { Cookie: cookie }), { PEPPER: randomSecret() }))).toBe("session_ended");
  });

  it("uses the plain development cookie only on http://localhost with DEV_MODE=1", async () => {
    const local = "http://localhost:8787";
    const token = await invite();
    const response = await call(post("/api/join", { token }, {}, local), { DEV_MODE: "1" });
    expect(response.headers.get("Set-Cookie")).toMatch(/^lingo_session=[A-Za-z0-9_-]{43}; Path=\/; HttpOnly; SameSite=Lax; Max-Age=7776000$/);
    const value = cookieOf(response).split("=")[1]!;
    expect((await call(get("/api/me", { Cookie: `lingo_session=${value}` }, local), { DEV_MODE: "1" })).status).toBe(200);
    // Production reads only the prefixed cookie; development reads only the plain one.
    expect((await call(get("/api/me", { Cookie: `lingo_session=${value}` }))).status).toBe(401);
    expect((await call(get("/api/me", { Cookie: `lingo_session=${value}` }, local))).status).toBe(401);
    expect((await call(get("/api/me", { Cookie: `__Host-lingo_session=${value}` }))).status).toBe(200);
    expect(await errorCode(await call(get("/api/me", { Cookie: `__Host-lingo_session=${value}` }, local), { DEV_MODE: "1" }))).toBe("not_signed_in");
  });
});

describe("logs (FR-59)", () => {
  it("hold the account id and no token, secret or name", async () => {
    const lines: string[] = [];
    vi.spyOn(console, "log").mockImplementation((line: string) => void lines.push(line));
    const { token, cookie, accountId } = await joined("Secret Name");
    await call(get("/api/me", { Cookie: cookie }));
    await call(post("/api/setup", { secret: SETUP_SECRET, name: "Owner Name" }));
    await call(post("/api/setup", { secret: "wrong-secret-value" }));
    const text = lines.join("\n");
    expect(lines).toHaveLength(4);
    expect(JSON.parse(lines[0]!)).toMatchObject({ route: "POST /api/join", status: 200, account: accountId });
    expect(JSON.parse(lines[1]!)).toMatchObject({ route: "GET /api/me", status: 200, account: accountId });
    for (const secret of [token, cookie.split("=")[1]!, SETUP_SECRET, PEPPER, "wrong-secret-value", "Secret Name", "Owner Name"]) {
      expect(text).not.toContain(secret);
    }
  });
});
