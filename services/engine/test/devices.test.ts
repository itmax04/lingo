import { env } from "cloudflare:test";
import { afterEach, describe, expect, it, vi } from "vitest";
import { CODE_ALPHABET, codeHash } from "../src/auth";
import { hmacHex } from "../src/crypto";
import { CODES_BUCKET, clientKey } from "../src/attempts";
import { call, cookieOf, count, errorCode, get, invite, ip, joined, ORIGIN, PEPPER, post, randomSecret } from "./helpers";

const LINK_INVALID = { code: "link_invalid", message: "This link is no longer valid. Ask for a new one." };
const MINUTE = 60 * 1000;

interface Pairing {
  token: string;
  code: string;
  expiresAt: number;
}
interface Device {
  id: string;
  name: string;
  createdAt: number;
  lastSeenAt: number;
  current: boolean;
}

async function pairing(cookie: string): Promise<Pairing> {
  const response = await call(post("/api/pairings", {}, { Cookie: cookie }));
  expect(response.status).toBe(200);
  return (await response.json()) as Pairing;
}

async function devices(cookie: string): Promise<Device[]> {
  const response = await call(get("/api/devices", { Cookie: cookie }));
  expect(response.status).toBe(200);
  return ((await response.json()) as { devices: Device[] }).devices;
}

/** A second device of the account, paired by link. */
async function second(cookie: string, deviceName = "Second"): Promise<{ cookie: string; deviceId: string }> {
  const { token } = await pairing(cookie);
  const response = await call(post("/api/pair", { token, deviceName }));
  expect(response.status).toBe(200);
  return { cookie: cookieOf(response), deviceId: ((await response.json()) as { device: { id: string } }).device.id };
}

const attempts = async () => JSON.stringify((await env.DB.prepare("SELECT * FROM attempts ORDER BY bucket, window_start").all()).results);
const failures = async (bucket: string) => (await env.DB.prepare("SELECT COALESCE(SUM(failures), 0) AS n FROM attempts WHERE bucket = ?").bind(bucket).first<number>("n"))!;
/** A well-formed code that is not `not`. */
function wrongCode(not = ""): string {
  for (;;) {
    const code = [...crypto.getRandomValues(new Uint8Array(8))].map((b) => CODE_ALPHABET[b & 31]).join("");
    if (code !== not) return code;
  }
}

afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
});

describe("pairing (FR-05, FAC-02)", () => {
  it("by link: a second device and session in the same account", async () => {
    const first = await joined("Zoë");
    const made = await pairing(first.cookie);
    expect(made.token).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(made.code).toMatch(/^[A-HJ-NP-Z2-9]{8}$/);
    expect(made.expiresAt - Date.now()).toBeGreaterThan(9 * MINUTE);
    expect(made.expiresAt - Date.now()).toBeLessThanOrEqual(10 * MINUTE);

    const response = await call(post("/api/pair", { token: made.token, deviceName: "iPad" }));
    expect(response.status).toBe(200);
    const body = (await response.json()) as { account: { id: string; name: string; isAdmin: boolean }; device: { id: string; name: string } };
    expect(body.account).toEqual({ id: first.accountId, name: "Zoë", isAdmin: false });
    expect(body.device.name).toBe("iPad");
    expect(response.headers.get("Set-Cookie")).toMatch(/^__Host-lingo_session=[A-Za-z0-9_-]{43}; Path=\/; HttpOnly; Secure; SameSite=Lax; Max-Age=7776000$/);
    expect(await Promise.all(["accounts", "devices", "sessions"].map(count))).toEqual([1, 2, 2]);
    expect(((await (await call(get("/api/me", { Cookie: cookieOf(response) }))).json()) as typeof body).device.id).toBe(body.device.id);
    // The first device still works.
    expect((await call(get("/api/me", { Cookie: first.cookie }))).status).toBe(200);
  });

  it("by code: typed in lower case with spaces and hyphens; a success leaves no counted failure", async () => {
    const first = await joined();
    const { code } = await pairing(first.cookie);
    const typed = `${code.slice(0, 4).toLowerCase()} - ${code.slice(4)} `;
    const response = await call(post("/api/pair", { code: typed }, ip("203.0.113.7")));
    expect(response.status).toBe(200);
    expect(((await response.json()) as { account: { id: string } }).account.id).toBe(first.accountId);
    expect(await count("devices")).toBe(2);
    expect(await failures(CODES_BUCKET)).toBe(0);
    expect(await failures(await clientKey(PEPPER, new Request(ORIGIN, { headers: ip("203.0.113.7") })))).toBe(0);
  });

  it("refuses a reused, expired, cancelled and unknown record, another kind's token and a malformed code alike", async () => {
    const first = await joined();
    const used = await pairing(first.cookie);
    expect((await call(post("/api/pair", { token: used.token }))).status).toBe(200);
    const cancelled = await pairing(first.cookie);
    const live = await pairing(first.cookie);
    vi.useFakeTimers({ toFake: ["Date"] });
    const before = await Promise.all(["accounts", "devices", "sessions"].map(count));
    const bodies: Array<Record<string, string>> = [
      { token: used.token },
      { code: used.code },
      { token: cancelled.token },
      { code: cancelled.code },
      { token: randomSecret() },
      { code: wrongCode(live.code) },
      { token: "short" },
      { code: "ABCDEFG" },
      { code: "ABCDEFG1" },
      { code: "" },
      { token: await invite() },
      { token: await invite({ kind: "signin", accountId: first.accountId }) },
      // A code is not accepted where a token belongs, nor a token as a code.
      { token: live.code },
      { code: live.token },
    ];
    for (const [i, body] of bodies.entries()) {
      const response = await call(post("/api/pair", body, ip(`198.51.100.${i}`)));
      expect([i, response.status]).toEqual([i, 410]);
      expect(await response.json()).toEqual(LINK_INVALID);
      expect(response.headers.get("Set-Cookie")).toBeNull();
    }
    // A pairing token is not an invite.
    expect((await call(post("/api/join", { token: live.token }, ip("198.51.100.200")))).status).toBe(410);

    vi.setSystemTime(Date.now() + 10 * MINUTE + 1);
    for (const body of [{ token: live.token }, { code: live.code }]) {
      const response = await call(post("/api/pair", body, ip("198.51.100.201")));
      expect(response.status).toBe(410);
      expect(await response.json()).toEqual(LINK_INVALID);
    }
    expect(await Promise.all(["accounts", "devices", "sessions"].map(count))).toEqual(before);
  });

  it("one record is used once, whether by its token or by its code, also by concurrent requests", async () => {
    const first = await joined();
    const a = await pairing(first.cookie);
    const results = await Promise.all([
      call(post("/api/pair", { token: a.token }, ip("198.51.100.1"))),
      call(post("/api/pair", { code: a.code }, ip("198.51.100.2"))),
      call(post("/api/pair", { token: a.token }, ip("198.51.100.3"))),
      call(post("/api/pair", { code: a.code }, ip("198.51.100.4"))),
    ]);
    expect(results.map((r) => r.status).sort()).toEqual([200, 410, 410, 410]);
    expect(await count("devices")).toBe(2);
    expect(await count("sessions")).toBe(2);
  });

  it("stores neither the token nor the code in clear", async () => {
    const first = await joined();
    const { token, code } = await pairing(first.cookie);
    await call(post("/api/pair", { code: wrongCode(code) }));
    const dump = JSON.stringify(await Promise.all(["accounts", "devices", "sessions", "links", "attempts"].map((t) => env.DB.prepare(`SELECT * FROM ${t}`).all())));
    expect(dump).not.toContain(token);
    expect(dump).not.toContain(code);
    expect(dump).not.toContain(code.toLowerCase());
    const row = await env.DB.prepare("SELECT hash, code_hash FROM links WHERE kind = 'pair'").first<{ hash: string; code_hash: string }>();
    expect(row!.hash).toMatch(/^[0-9a-f]{64}$/);
    expect(row!.code_hash).toMatch(/^[0-9a-f]{64}$/);
    // The code is hashed in its own domain: the row does not hold the plain HMAC of the code.
    expect(row!.code_hash).toBe(await codeHash(PEPPER, code));
    expect(row!.code_hash).not.toBe(await hmacHex(PEPPER, code));
  });

  it("a new record cancels the account's previous unused one and removes expired links, not other accounts' live ones", async () => {
    const a = await joined("A");
    const b = await joined("B");
    const other = await pairing(b.cookie);
    const stale = await invite({ expiresIn: -1 });
    const pending = await invite();
    const old = await pairing(a.cookie);
    const fresh = await pairing(a.cookie);
    expect(await count("links")).toBe(3 + 2); // two used invites, one pending invite, B's record, A's fresh record
    expect((await call(post("/api/pair", { token: old.token }))).status).toBe(410);
    expect((await call(post("/api/join", { token: stale }))).status).toBe(410);
    expect((await call(post("/api/pair", { code: other.code }))).status).toBe(200);
    expect((await call(post("/api/pair", { token: fresh.token }))).status).toBe(200);
    expect((await call(post("/api/join", { token: pending }))).status).toBe(200);
  });

  it("needs a session to create, is refused for a blocked account, and a blocked account's record is not redeemed", async () => {
    expect(await errorCode(await call(post("/api/pairings", {})))).toBe("not_signed_in");
    const first = await joined();
    const made = await pairing(first.cookie);
    await env.DB.prepare("UPDATE accounts SET status = 'blocked'").run();
    expect(await errorCode(await call(post("/api/pairings", {}, { Cookie: first.cookie })))).toBe("account_blocked");
    for (const body of [{ token: made.token }, { code: made.code }]) {
      const response = await call(post("/api/pair", body));
      expect(response.status).toBe(410);
      expect(await response.json()).toEqual(LINK_INVALID);
    }
    expect(await count("devices")).toBe(1);
    // Unblocked within the record's life, it works again: the refusals did not use it up.
    await env.DB.prepare("UPDATE accounts SET status = 'active'").run();
    expect((await call(post("/api/pair", { code: made.code }, ip("192.0.2.9")))).status).toBe(200);
  });

  it("is not redeemed on a signed-in device and refuses bad bodies as invalid requests", async () => {
    const first = await joined();
    const other = await joined("Other");
    const made = await pairing(first.cookie);
    const signedIn = await call(post("/api/pair", { token: made.token }, { Cookie: other.cookie }));
    expect(signedIn.status).toBe(409);
    expect(await errorCode(signedIn)).toBe("already_signed_in");
    for (const body of [{}, { token: made.token, code: made.code }, { token: 1 }, { code: null }, { code: made.code, deviceName: "" }, { token: made.token, deviceName: "a\u0000b" }]) {
      const response = await call(post("/api/pair", body));
      expect(response.status).toBe(400);
    }
    expect(await count("attempts")).toBe(0);
    expect((await call(post("/api/pair", { token: made.token }))).status).toBe(200);
  });
});

describe("guessing limits (FR-06, FAC-02)", () => {
  it("a client's 11th typed code is refused with 429, writes nothing, and the limit is shared with link attempts", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(new Date("2026-11-14T10:01:00Z"));
    const first = await joined();
    const made = await pairing(first.cookie);
    const client = ip("203.0.113.7");
    for (let i = 0; i < 4; i++) expect((await call(post("/api/join", { token: randomSecret() }, client))).status).toBe(410);
    for (let i = 0; i < 6; i++) expect((await call(post("/api/pair", { code: wrongCode(made.code) }, client))).status).toBe(410);
    const before = await attempts();
    for (const body of [{ code: made.code }, { token: made.token }, { code: wrongCode(made.code) }]) {
      const refused = await call(post("/api/pair", body, client));
      expect(refused.status).toBe(429);
      expect(await refused.json()).toEqual(LINK_INVALID);
    }
    expect(await attempts()).toBe(before);
    expect(await count("devices")).toBe(1);
    // Another client is not affected; the first recovers after the two windows.
    vi.setSystemTime(new Date("2026-11-14T10:20:01Z"));
    expect((await call(post("/api/pair", { code: made.code }, client))).status).toBe(410); // the record has expired by now
    const again = await pairing(first.cookie);
    expect((await call(post("/api/pair", { code: again.code }, client))).status).toBe(200);
  });

  it("a burst of parallel wrong codes from one client cannot pass the limit (review B2/N1)", async () => {
    const first = await joined();
    const made = await pairing(first.cookie);
    const client = ip("2001:db8:1:2::1");
    const burst = await Promise.all(Array.from({ length: 30 }, (_, i) => call(post("/api/pair", { code: wrongCode(made.code) }, ip(`2001:db8:1:2:${i}::9`)))));
    const statuses = burst.map((r) => r.status);
    expect(statuses.filter((s) => s === 410).length).toBe(10);
    expect(statuses.filter((s) => s === 429).length).toBe(20);
    expect(await failures(await clientKey(PEPPER, new Request(ORIGIN, { headers: client })))).toBe(10);
    expect(await failures(CODES_BUCKET)).toBe(10);
  });

  it("over 100 failed typed codes of all clients, typed codes are refused for everybody while links keep working", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(new Date("2026-11-14T10:01:00Z"));
    const first = await joined();
    const made = await pairing(first.cookie);
    const burst = await Promise.all(Array.from({ length: 120 }, (_, i) => call(post("/api/pair", { code: wrongCode(made.code) }, ip(`198.51.${Math.floor(i / 100)}.${i % 100}`)))));
    expect(burst.filter((r) => r.status === 410).length).toBe(101);
    expect(burst.filter((r) => r.status === 429).length).toBe(19);
    expect(await failures(CODES_BUCKET)).toBe(101);

    const before = await attempts();
    const stranger = await call(post("/api/pair", { code: made.code }, ip("192.0.2.1")));
    expect(stranger.status).toBe(429);
    expect(await stranger.json()).toEqual(LINK_INVALID);
    expect(await attempts()).toBe(before);
    // The link token of the same record, and invites, still work for a client under its own limit.
    expect((await call(post("/api/pair", { token: made.token }, ip("192.0.2.1")))).status).toBe(200);
    expect((await call(post("/api/join", { token: await invite() }, ip("192.0.2.2")))).status).toBe(200);
    // Typed codes come back when the failures have left the two windows.
    vi.setSystemTime(new Date("2026-11-14T10:20:01Z"));
    const again = await pairing(first.cookie);
    expect((await call(post("/api/pair", { code: again.code }, ip("192.0.2.3")))).status).toBe(200);
    expect(await count("attempts")).toBe(0); // old windows are dropped by the successful redemption
  });
});

describe("devices (FR-07, FAC-03)", () => {
  it("lists the account's devices, oldest first, and marks the caller's own", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(new Date("2026-11-14T10:00:00Z"));
    const first = await joined();
    vi.setSystemTime(new Date("2026-11-14T10:05:00Z"));
    const other = await second(first.cookie, "Phone");
    const stranger = await joined("Stranger");
    const list = await devices(first.cookie);
    expect(list).toEqual([
      { id: first.deviceId, name: "Browser", createdAt: Date.parse("2026-11-14T10:00:00Z"), lastSeenAt: Date.parse("2026-11-14T10:00:00Z"), current: true },
      { id: other.deviceId, name: "Phone", createdAt: Date.parse("2026-11-14T10:05:00Z"), lastSeenAt: Date.parse("2026-11-14T10:05:00Z"), current: false },
    ]);
    expect((await devices(other.cookie)).map((d) => d.current)).toEqual([false, true]);
    expect((await devices(stranger.cookie)).map((d) => d.id)).toEqual([stranger.deviceId]);
    expect(await errorCode(await call(get("/api/devices")))).toBe("not_signed_in");
  });

  it("renames an own device only; another account's device is unknown", async () => {
    const first = await joined();
    const other = await second(first.cookie);
    const stranger = await joined("Stranger");
    const renamed = await call(post("/api/devices/rename", { deviceId: other.deviceId, name: "  Küche iPad " }, { Cookie: first.cookie }));
    expect(renamed.status).toBe(200);
    expect(((await renamed.json()) as { devices: Device[] }).devices.map((d) => d.name)).toEqual(["Browser", "Küche iPad"]);

    for (const cookie of [stranger.cookie]) {
      const refused = await call(post("/api/devices/rename", { deviceId: other.deviceId, name: "Mine" }, { Cookie: cookie }));
      expect(refused.status).toBe(404);
      expect(await errorCode(refused)).toBe("not_found");
    }
    expect((await call(post("/api/devices/rename", { deviceId: "nope", name: "X" }, { Cookie: first.cookie }))).status).toBe(404);
    for (const body of [{ deviceId: other.deviceId }, { deviceId: other.deviceId, name: "" }, { deviceId: other.deviceId, name: "x".repeat(41) }, { deviceId: other.deviceId, name: "a\nb" }, { name: "X" }, { deviceId: 5, name: "X" }]) {
      expect((await call(post("/api/devices/rename", body, { Cookie: first.cookie }))).status).toBe(400);
    }
    expect((await devices(first.cookie)).map((d) => d.name)).toEqual(["Browser", "Küche iPad"]);
    expect((await devices(stranger.cookie)).map((d) => d.name)).toEqual(["Browser"]);
  });

  it("signs another device out: its next request is session_ended; other devices and accounts are untouched", async () => {
    const first = await joined();
    const other = await second(first.cookie);
    const third = await second(first.cookie, "Third");
    const stranger = await joined("Stranger");

    const foreign = await call(post("/api/devices/sign-out", { deviceId: other.deviceId }, { Cookie: stranger.cookie }));
    expect(foreign.status).toBe(404);
    expect((await call(get("/api/me", { Cookie: other.cookie }))).status).toBe(200);

    const done = await call(post("/api/devices/sign-out", { deviceId: other.deviceId }, { Cookie: first.cookie }));
    expect(done.status).toBe(200);
    expect(done.headers.get("Set-Cookie")).toBeNull();
    expect(((await done.json()) as { devices: Device[] }).devices.map((d) => d.id)).toEqual([first.deviceId, third.deviceId]);
    const ended = await call(get("/api/me", { Cookie: other.cookie }));
    expect(ended.status).toBe(401);
    expect(await errorCode(ended)).toBe("session_ended");
    expect(ended.headers.get("Set-Cookie")).toMatch(/Max-Age=0$/);
    for (const cookie of [first.cookie, third.cookie, stranger.cookie]) expect((await call(get("/api/me", { Cookie: cookie }))).status).toBe(200);
    expect((await call(post("/api/devices/sign-out", { deviceId: other.deviceId }, { Cookie: first.cookie }))).status).toBe(404);
    expect((await call(post("/api/devices/sign-out", {}, { Cookie: first.cookie }))).status).toBe(400);
    expect(await count("sessions")).toBe(3);
    expect(await count("devices")).toBe(3);
  });

  it("signs this device out, by /api/sign-out and by its own id, and clears the cookie", async () => {
    const first = await joined();
    const other = await second(first.cookie);
    const cleared = "__Host-lingo_session=; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=0";

    const out = await call(post("/api/sign-out", {}, { Cookie: other.cookie }));
    expect(out.status).toBe(200);
    expect(await out.json()).toEqual({});
    expect(out.headers.get("Set-Cookie")).toBe(cleared);
    expect(await errorCode(await call(get("/api/me", { Cookie: other.cookie })))).toBe("session_ended");
    expect(await errorCode(await call(post("/api/sign-out", {}, { Cookie: other.cookie })))).toBe("session_ended");
    expect(await errorCode(await call(post("/api/sign-out", {})))).toBe("not_signed_in");

    const own = await call(post("/api/devices/sign-out", { deviceId: first.deviceId }, { Cookie: first.cookie }));
    expect(own.status).toBe(200);
    expect(own.headers.get("Set-Cookie")).toBe(cleared);
    expect(await count("devices")).toBe(0);
    expect(await count("sessions")).toBe(0);
    expect(await count("accounts")).toBe(1); // the account and its data stay
  });

  it("signs out everywhere else: only the caller's device stays, and a pending pairing record is cancelled", async () => {
    const first = await joined();
    const other = await second(first.cookie);
    const third = await second(first.cookie, "Third");
    const stranger = await joined("Stranger");
    const strangerPairing = await pairing(stranger.cookie);
    const pending = await pairing(first.cookie);

    const done = await call(post("/api/devices/sign-out-others", {}, { Cookie: other.cookie }));
    expect(done.status).toBe(200);
    expect(((await done.json()) as { devices: Device[] }).devices).toMatchObject([{ id: other.deviceId, current: true }]);
    expect((await call(get("/api/me", { Cookie: other.cookie }))).status).toBe(200);
    for (const cookie of [first.cookie, third.cookie]) expect(await errorCode(await call(get("/api/me", { Cookie: cookie })))).toBe("session_ended");
    expect((await call(post("/api/pair", { token: pending.token }))).status).toBe(410);
    expect((await call(get("/api/me", { Cookie: stranger.cookie }))).status).toBe(200);
    expect((await call(post("/api/pair", { token: strangerPairing.token }, ip("192.0.2.5")))).status).toBe(200);
  });

  it("does not list a device whose session has expired, and the next pairing record removes it", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(new Date("2026-01-01T00:00:00Z"));
    const first = await joined();
    const other = await second(first.cookie);
    vi.setSystemTime(new Date("2026-03-01T00:00:00Z"));
    expect((await call(get("/api/me", { Cookie: first.cookie }))).status).toBe(200); // extends the first device only
    vi.setSystemTime(new Date("2026-04-05T00:00:00Z"));
    expect((await devices(first.cookie)).map((d) => d.id)).toEqual([first.deviceId]);
    expect(await errorCode(await call(get("/api/me", { Cookie: other.cookie })))).toBe("session_ended");
    expect(await count("devices")).toBe(2);
    await pairing(first.cookie);
    expect(await count("devices")).toBe(1);
  });

  it("refuses every device operation of a blocked account and of a request from another origin", async () => {
    const first = await joined();
    for (const request of [
      post("/api/devices/sign-out-others", {}, { Cookie: first.cookie, Origin: "https://evil.example" }),
      post("/api/sign-out", {}, { Cookie: first.cookie, Origin: "https://evil.example" }),
    ]) {
      expect(await errorCode(await call(request))).toBe("origin_refused");
    }
    await env.DB.prepare("UPDATE accounts SET status = 'blocked'").run();
    for (const request of [
      get("/api/devices", { Cookie: first.cookie }),
      post("/api/devices/rename", { deviceId: first.deviceId, name: "X" }, { Cookie: first.cookie }),
      post("/api/devices/sign-out", { deviceId: first.deviceId }, { Cookie: first.cookie }),
      post("/api/devices/sign-out-others", {}, { Cookie: first.cookie }),
      post("/api/sign-out", {}, { Cookie: first.cookie }),
    ]) {
      const response = await call(request);
      expect(response.status).toBe(403);
      expect(await errorCode(response)).toBe("account_blocked");
    }
    expect(await count("devices")).toBe(1);
  });
});
