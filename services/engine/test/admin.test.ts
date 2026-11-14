import { env } from "cloudflare:test";
import { afterEach, describe, expect, it, vi } from "vitest";
import { hmacHex } from "../src/crypto";
import { routes } from "../src/routes";
import { call, cookieOf, count, errorCode, get, invite, joined, PEPPER, post, SETUP_SECRET } from "./helpers";

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;
const LINK_INVALID = { code: "link_invalid", message: "This link is no longer valid. Ask for a new one." };

interface Account {
  id: string;
  name: string;
  isAdmin: boolean;
  status: string;
  createdAt: number;
  lastSignInAt: number | null;
  deviceCount: number;
  storedBytes: number;
}
interface Invite {
  id: string;
  name: string;
  createdAt: number;
  expiresAt: number;
}
type Session = { cookie: string; accountId: string; deviceId: string };

async function admin(name = "Owner"): Promise<Session> {
  const response = await call(post("/api/setup", { secret: SETUP_SECRET, name }));
  expect(response.status).toBe(200);
  const body = (await response.json()) as { account: { id: string }; device: { id: string } };
  return { cookie: cookieOf(response), accountId: body.account.id, deviceId: body.device.id };
}

const as = (who: { cookie: string }) => ({ Cookie: who.cookie });

async function accounts(who: Session): Promise<{ accounts: Account[]; totalStoredBytes: number }> {
  const response = await call(get("/api/admin/accounts", as(who)));
  expect(response.status).toBe(200);
  return (await response.json()) as { accounts: Account[]; totalStoredBytes: number };
}

async function invites(who: Session): Promise<Invite[]> {
  const response = await call(get("/api/admin/invites", as(who)));
  expect(response.status).toBe(200);
  return ((await response.json()) as { invites: Invite[] }).invites;
}

async function newInvite(who: Session, name = "Friend"): Promise<{ token: string; invite: Invite }> {
  const response = await call(post("/api/admin/invites/create", { name }, as(who)));
  expect(response.status).toBe(200);
  return (await response.json()) as { token: string; invite: Invite };
}

async function signInLink(who: Session, accountId: string): Promise<{ token: string; expiresAt: number }> {
  const response = await call(post("/api/admin/sign-in-links", { accountId }, as(who)));
  expect(response.status).toBe(200);
  return (await response.json()) as { token: string; expiresAt: number };
}

const meStatus = async (who: { cookie: string }) => (await call(get("/api/me", as(who)))).status;
const store = (accountId: string, body: string) =>
  env.DB.batch([
    env.DB.prepare("INSERT INTO events (account_id, event_id, body) VALUES (?, ?, ?)").bind(accountId, crypto.randomUUID(), body),
    env.DB.prepare("UPDATE accounts SET stored_bytes = stored_bytes + ? WHERE id = ?").bind(body.length, accountId),
  ]);
/** Every row of every table, to prove that a refused request changed nothing. */
const snapshot = async () =>
  JSON.stringify(await Promise.all(["accounts", "devices", "sessions", "links", "events"].map(async (t) => (await env.DB.prepare(`SELECT * FROM ${t} ORDER BY 1`).all()).results)));

afterEach(() => {
  vi.useRealTimers();
});

describe("the admin API is the admin's only (FR-12, FAC-04)", () => {
  const adminRoutes = routes.filter((r) => r.path.startsWith("/api/admin/"));

  it("answers a signed-in friend 404 on every path, whatever the body, and changes nothing", async () => {
    const owner = await admin();
    const friend = await joined("Anna");
    const other = await joined("Boris");
    const pending = await newInvite(owner, "Clara");
    expect(adminRoutes.length).toBe(8);
    const before = await snapshot();
    // Bodies that would work for the admin, and one without the fields: the answer never depends on the body.
    const bodies = [{ accountId: other.accountId, name: "Boris", inviteId: pending.invite.id }, { accountId: friend.accountId, name: "Anna" }, {}];
    for (const route of adminRoutes) {
      for (const body of route.method === "GET" ? [null] : bodies) {
        const response = await call(body === null ? get(route.path, as(friend)) : post(route.path, body, as(friend)));
        expect([route.path, response.status]).toEqual([route.path, 404]);
        expect(await response.json()).toEqual({ code: "not_found", message: "Not found." });
      }
    }
    expect(await snapshot()).toBe(before);
  });

  it("answers 401 without a session and 401 for an ended one", async () => {
    const owner = await admin();
    await call(post("/api/sign-out", {}, as(owner)));
    for (const route of adminRoutes) {
      const none = await call(route.method === "GET" ? get(route.path) : post(route.path, {}));
      expect([route.path, await errorCode(none)]).toEqual([route.path, "not_signed_in"]);
      const ended = await call(route.method === "GET" ? get(route.path, as(owner)) : post(route.path, {}, as(owner)));
      expect([route.path, await errorCode(ended)]).toEqual([route.path, "session_ended"]);
    }
  });

  it("no request grants the admin flag", async () => {
    await admin();
    const friend = await joined("Anna");
    const extra = { isAdmin: true, is_admin: 1, admin: true, account: { isAdmin: true } };
    await call(post("/api/account/rename", { name: "Anna B", ...extra }, as(friend)));
    await call(post("/api/devices/rename", { deviceId: friend.deviceId, name: "Phone", ...extra }, as(friend)));
    await call(post("/api/pairings", extra, as(friend)));
    const me = (await (await call(get("/api/me", as(friend)))).json()) as { account: { isAdmin: boolean } };
    expect(me.account.isAdmin).toBe(false);
    expect((await call(get("/api/admin/accounts", as(friend)))).status).toBe(404);
    expect(await env.DB.prepare("SELECT COUNT(*) AS n FROM accounts WHERE is_admin = 1").first<number>("n")).toBe(1);
  });
});

describe("invites (FR-03, FR-12)", () => {
  it("creates an invite whose token joins once under the given name; only its hash is stored", async () => {
    const owner = await admin();
    const made = await newInvite(owner, "  Zoë  ");
    expect(made.token).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(made.invite.name).toBe("Zoë");
    expect(made.invite.expiresAt - made.invite.createdAt).toBe(7 * DAY);
    expect(await invites(owner)).toEqual([made.invite]);
    const hash = await hmacHex(PEPPER, made.token);
    // The id is a part of the hash: neither the token nor a value that can be redeemed.
    expect(made.invite.id).toBe(hash.slice(0, 32));
    expect(await snapshot()).not.toContain(made.token);
    expect((await call(post("/api/join", { token: made.invite.id }))).status).toBe(410);
    expect((await call(post("/api/join", { token: hash }))).status).toBe(410);

    const response = await call(post("/api/join", { token: made.token }));
    expect(response.status).toBe(200);
    expect(((await response.json()) as { account: { name: string; isAdmin: boolean } }).account).toMatchObject({ name: "Zoë", isAdmin: false });
    expect(await invites(owner)).toEqual([]);
  });

  it("lists unused, unexpired invites only, oldest first", async () => {
    const owner = await admin();
    const friend = await joined("Used");
    await invite({ name: "Expired", expiresIn: -1 });
    await invite({ name: "Revoked", revoked: true });
    await invite({ kind: "pair", accountId: friend.accountId });
    await invite({ kind: "signin", accountId: friend.accountId });
    vi.useFakeTimers({ toFake: ["Date"] });
    const first = await newInvite(owner, "First");
    vi.setSystemTime(Date.now() + 1000);
    const second = await newInvite(owner, "Second");
    expect((await invites(owner)).map((i) => i.name)).toEqual(["First", "Second"]);
    // One second before its end the first is listed, at its end it is not.
    vi.setSystemTime(first.invite.expiresAt - 1);
    expect((await invites(owner)).map((i) => i.name)).toEqual(["First", "Second"]);
    vi.setSystemTime(first.invite.expiresAt);
    expect(await invites(owner)).toEqual([second.invite]);
  });

  it("revokes an unused invite; a used invite, another link kind and an unknown id are 404", async () => {
    const owner = await admin();
    const made = await newInvite(owner, "Anna");
    const kept = await newInvite(owner, "Boris");
    const revoked = await call(post("/api/admin/invites/revoke", { inviteId: made.invite.id }, as(owner)));
    expect(revoked.status).toBe(200);
    expect(await revoked.json()).toEqual({ invites: [kept.invite] });
    const join = await call(post("/api/join", { token: made.token }));
    expect([join.status, await join.json()]).toEqual([410, LINK_INVALID]);

    const friend = await joined("Clara");
    const usedId = (await hmacHex(PEPPER, friend.token)).slice(0, 32);
    const pairToken = await invite({ kind: "pair", accountId: friend.accountId });
    const before = await snapshot();
    for (const inviteId of [usedId, (await hmacHex(PEPPER, pairToken)).slice(0, 32), "nope", made.invite.id]) {
      expect(await errorCode(await call(post("/api/admin/invites/revoke", { inviteId }, as(owner))))).toBe("not_found");
    }
    for (const inviteId of [undefined, 7, "", "x".repeat(65)]) {
      expect(await errorCode(await call(post("/api/admin/invites/revoke", { inviteId }, as(owner))))).toBe("invalid_request");
    }
    expect(await snapshot()).toBe(before);
  });

  it("refuses a bad name and the switched-off state without writing; creating removes expired links", async () => {
    const owner = await admin();
    for (const name of [undefined, "", "   ", "x".repeat(41), "a\u0000b", 5]) {
      expect(await errorCode(await call(post("/api/admin/invites/create", { name }, as(owner))))).toBe("invalid_request");
    }
    const off = await call(post("/api/admin/invites/create", { name: "Anna" }, as(owner)), { INVITES_ENABLED: "0" });
    expect([off.status, await errorCode(off)]).toEqual([503, "invites_disabled"]);
    expect(await count("links")).toBe(0);
    await invite({ name: "Expired", expiresIn: -1 });
    await newInvite(owner, "Anna");
    expect((await env.DB.prepare("SELECT name FROM links").all<{ name: string }>()).results.map((r) => r.name)).toEqual(["Anna"]);
  });
});

describe("sign-in link (FR-08, FAC-04)", () => {
  it("signs a new device in to the friend's account once; existing sessions stay", async () => {
    const owner = await admin();
    const friend = await joined("Anna");
    const link = await signInLink(owner, friend.accountId);
    expect(link.token).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(link.expiresAt - Date.now()).toBeGreaterThan(DAY - 60 * 1000);
    expect(link.expiresAt - Date.now()).toBeLessThanOrEqual(DAY);
    expect(await snapshot()).not.toContain(link.token);

    // A sign-in token is no invite and no pairing token, and the other kinds are not sign-in tokens.
    expect((await call(post("/api/join", { token: link.token }))).status).toBe(410);
    expect((await call(post("/api/pair", { token: link.token }))).status).toBe(410);
    const pairToken = await invite({ kind: "pair", accountId: friend.accountId });
    expect((await call(post("/api/sign-in", { token: pairToken }))).status).toBe(410);
    expect((await call(post("/api/sign-in", { token: await invite() }))).status).toBe(410);
    expect(await errorCode(await call(post("/api/sign-in", {})))).toBe("invalid_request");
    expect(await errorCode(await call(post("/api/sign-in", { token: link.token }, as(friend))))).toBe("already_signed_in");

    const response = await call(post("/api/sign-in", { token: link.token, deviceName: "New phone" }));
    expect(response.status).toBe(200);
    const body = (await response.json()) as { account: { id: string; name: string; isAdmin: boolean }; device: { id: string; name: string } };
    expect(body.account).toEqual({ id: friend.accountId, name: "Anna", isAdmin: false });
    expect(body.device.name).toBe("New phone");
    expect(await meStatus({ cookie: cookieOf(response) })).toBe(200);
    expect(await meStatus(friend)).toBe(200);
    expect(await env.DB.prepare("SELECT COUNT(*) AS n FROM devices WHERE account_id = ?").bind(friend.accountId).first<number>("n")).toBe(2);

    const again = await call(post("/api/sign-in", { token: link.token }));
    expect([again.status, await again.json()]).toEqual([410, LINK_INVALID]);
  });

  it("lives 24 hours", async () => {
    const owner = await admin();
    const friend = await joined("Anna");
    vi.useFakeTimers({ toFake: ["Date"] });
    const late = await signInLink(owner, friend.accountId);
    vi.setSystemTime(late.expiresAt);
    expect((await call(post("/api/sign-in", { token: late.token }))).status).toBe(410);
    vi.setSystemTime(Date.now() + HOUR);
    const inTime = await signInLink(owner, friend.accountId);
    vi.setSystemTime(inTime.expiresAt - 1);
    expect((await call(post("/api/sign-in", { token: inTime.token }))).status).toBe(200);
  });

  it("a new link cancels the account's previous unused one, and no other account's", async () => {
    const owner = await admin();
    const anna = await joined("Anna");
    const boris = await joined("Boris");
    const first = await signInLink(owner, anna.accountId);
    const forBoris = await signInLink(owner, boris.accountId);
    const second = await signInLink(owner, anna.accountId);
    expect((await call(post("/api/sign-in", { token: first.token }))).status).toBe(410);
    expect((await call(post("/api/sign-in", { token: second.token }))).status).toBe(200);
    const response = await call(post("/api/sign-in", { token: forBoris.token }));
    expect(((await response.json()) as { account: { id: string } }).account.id).toBe(boris.accountId);
  });

  it("is made for an active, existing friend's account only", async () => {
    const owner = await admin();
    const friend = await joined("Anna");
    await call(post("/api/admin/accounts/block", { accountId: friend.accountId }, as(owner)));
    const before = await snapshot();
    const blocked = await call(post("/api/admin/sign-in-links", { accountId: friend.accountId }, as(owner)));
    expect([blocked.status, await errorCode(blocked)]).toEqual([409, "account_not_active"]);
    // Not for the admin's own account: a 24-hour bearer link to it would be an admin credential (review N4, D-36).
    const self = await call(post("/api/admin/sign-in-links", { accountId: owner.accountId }, as(owner)));
    expect([self.status, await errorCode(self)]).toEqual([403, "admin_protected"]);
    expect(await errorCode(await call(post("/api/admin/sign-in-links", { accountId: "nope" }, as(owner))))).toBe("not_found");
    expect(await errorCode(await call(post("/api/admin/sign-in-links", {}, as(owner))))).toBe("invalid_request");
    expect(await snapshot()).toBe(before);
  });

  it("\"Sign out everywhere else\" cancels the unused sign-in link, and only the caller's (review N6)", async () => {
    const owner = await admin();
    const anna = await joined("Anna");
    const boris = await joined("Boris");
    const forAnna = await signInLink(owner, anna.accountId);
    const forBoris = await signInLink(owner, boris.accountId);
    expect((await call(post("/api/devices/sign-out-others", {}, as(anna)))).status).toBe(200);
    expect((await call(post("/api/sign-in", { token: forAnna.token }))).status).toBe(410);
    expect((await call(post("/api/sign-in", { token: forBoris.token }))).status).toBe(200);
  });
});

describe("block and unblock (FR-09, FAC-04)", () => {
  it("a blocked account is refused with its data kept; unblocking restores the same device", async () => {
    const owner = await admin();
    const friend = await joined("Anna");
    await store(friend.accountId, "kept");
    const blocked = await call(post("/api/admin/accounts/block", { accountId: friend.accountId }, as(owner)));
    expect(blocked.status).toBe(200);
    const list = (await blocked.json()) as { accounts: Account[] };
    expect(list.accounts.map((a) => [a.name, a.status])).toEqual([["Owner", "active"], ["Anna", "blocked"]]);

    const refused = await call(get("/api/me", as(friend)));
    expect([refused.status, await refused.json()]).toEqual([403, { code: "account_blocked", message: "This account is blocked." }]);
    expect(refused.headers.get("Set-Cookie")).toBeNull();
    expect(await errorCode(await call(post("/api/account/delete", { name: "Anna" }, as(friend))))).toBe("account_blocked");
    expect(await Promise.all(["accounts", "devices", "sessions", "events"].map(count))).toEqual([2, 2, 2, 1]);
    // Blocking again changes nothing.
    expect((await call(post("/api/admin/accounts/block", { accountId: friend.accountId }, as(owner)))).status).toBe(200);

    const unblocked = await call(post("/api/admin/accounts/unblock", { accountId: friend.accountId }, as(owner)));
    expect(((await unblocked.json()) as { accounts: Account[] }).accounts[1]!.status).toBe("active");
    expect(await meStatus(friend)).toBe(200);
  });

  it("unblocking restores the named account only", async () => {
    const owner = await admin();
    const anna = await joined("Anna");
    const boris = await joined("Boris");
    for (const friend of [anna, boris]) await call(post("/api/admin/accounts/block", { accountId: friend.accountId }, as(owner)));
    const response = await call(post("/api/admin/accounts/unblock", { accountId: anna.accountId }, as(owner)));
    expect(((await response.json()) as { accounts: Account[] }).accounts.map((a) => a.status)).toEqual(["active", "active", "blocked"]);
    expect([await meStatus(anna), await meStatus(boris)]).toEqual([200, 403]);
  });

  it("blocking removes the account's unused pairing record and sign-in link, so unblocking does not revive them", async () => {
    const owner = await admin();
    const anna = await joined("Anna");
    const boris = await joined("Boris");
    const link = await signInLink(owner, anna.accountId);
    const pairing = (await (await call(post("/api/pairings", {}, as(anna)))).json()) as { token: string };
    const forBoris = await signInLink(owner, boris.accountId);
    await call(post("/api/admin/accounts/block", { accountId: anna.accountId }, as(owner)));
    await call(post("/api/admin/accounts/unblock", { accountId: anna.accountId }, as(owner)));
    expect((await call(post("/api/sign-in", { token: link.token }))).status).toBe(410);
    expect((await call(post("/api/pair", { token: pairing.token }))).status).toBe(410);
    // The used invite of the account and the other account's link are untouched.
    expect(await env.DB.prepare("SELECT COUNT(*) AS n FROM links WHERE account_id = ? AND kind = 'invite'").bind(anna.accountId).first<number>("n")).toBe(1);
    expect((await call(post("/api/sign-in", { token: forBoris.token }))).status).toBe(200);
  });

  it("the admin cannot block the own account; an unknown account is 404", async () => {
    const owner = await admin();
    const pairing = (await (await call(post("/api/pairings", {}, as(owner)))).json()) as { token: string };
    const before = await snapshot();
    const self = await call(post("/api/admin/accounts/block", { accountId: owner.accountId }, as(owner)));
    expect([self.status, await self.json()]).toEqual([403, { code: "admin_protected", message: "This is not possible for the admin account." }]);
    for (const path of ["/api/admin/accounts/block", "/api/admin/accounts/unblock"]) {
      expect(await errorCode(await call(post(path, { accountId: "nope" }, as(owner))))).toBe("not_found");
      expect(await errorCode(await call(post(path, {}, as(owner))))).toBe("invalid_request");
    }
    expect(await snapshot()).toBe(before);
    expect(await meStatus(owner)).toBe(200);
    // The refused request left the admin's own pairing record alone.
    expect((await call(post("/api/pair", { token: pairing.token }))).status).toBe(200);
  });
});

describe("delete (FR-09, FR-10, FAC-04)", () => {
  it("the admin deletes a friend only with the friend's name typed; everything of the account goes", async () => {
    const owner = await admin();
    const anna = await joined("Anna");
    const boris = await joined("Boris");
    await store(anna.accountId, "anna-event");
    await store(boris.accountId, "boris-event");
    await signInLink(owner, anna.accountId);
    await call(post("/api/pairings", {}, as(anna)));
    await signInLink(owner, boris.accountId);

    const before = await snapshot();
    for (const name of ["Boris", "anna", "Ann", "Owner", ""]) {
      const wrong = await call(post("/api/admin/accounts/delete", { accountId: anna.accountId, name }, as(owner)));
      expect([name, wrong.status, await errorCode(wrong)]).toEqual([name, 400, "confirmation_mismatch"]);
    }
    for (const body of [{ accountId: anna.accountId }, { accountId: anna.accountId, name: 5 }, { name: "Anna" }]) {
      expect(await errorCode(await call(post("/api/admin/accounts/delete", body, as(owner))))).toBe("invalid_request");
    }
    expect(await errorCode(await call(post("/api/admin/accounts/delete", { accountId: "nope", name: "Anna" }, as(owner))))).toBe("not_found");
    expect(await snapshot()).toBe(before);

    const deleted = await call(post("/api/admin/accounts/delete", { accountId: anna.accountId, name: " Anna " }, as(owner)));
    expect(deleted.status).toBe(200);
    expect(((await deleted.json()) as { accounts: Account[] }).accounts.map((a) => a.name)).toEqual(["Owner", "Boris"]);
    for (const table of ["devices", "sessions", "links", "events"]) {
      expect([table, await env.DB.prepare(`SELECT COUNT(*) AS n FROM ${table} WHERE account_id = ?`).bind(anna.accountId).first<number>("n")]).toEqual([table, 0]);
    }
    expect(await snapshot()).not.toContain("Anna");
    const gone = await call(get("/api/me", as(anna)));
    expect([gone.status, await errorCode(gone)]).toEqual([401, "session_ended"]);
    // The other friend keeps the account, the device, the events and both links (used invite, sign-in link).
    expect(await meStatus(boris)).toBe(200);
    expect(await Promise.all(["accounts", "devices", "sessions", "links", "events"].map(count))).toEqual([2, 2, 2, 2, 1]);
  });

  it("the admin account is never deleted: not through the admin path, not through \"Delete my account\"", async () => {
    const owner = await admin();
    await store(owner.accountId, "owner-event");
    const before = await snapshot();
    for (const path of ["/api/admin/accounts/delete", "/api/account/delete"]) {
      for (const name of ["Owner", "wrong"]) {
        const response = await call(post(path, { accountId: owner.accountId, name }, as(owner)));
        expect([path, name, response.status, await errorCode(response)]).toEqual([path, name, 403, "admin_protected"]);
        expect(response.headers.get("Set-Cookie")).toBeNull();
      }
    }
    expect(await snapshot()).toBe(before);
    expect(await meStatus(owner)).toBe(200);
  });

  it("a friend deletes the own account with the name typed; the cookie is cleared and nobody else is touched", async () => {
    const owner = await admin();
    const anna = await joined("Anna");
    const boris = await joined("Boris");
    await store(anna.accountId, "anna-event");
    const before = await snapshot();
    for (const body of [{ name: "Boris" }, { name: "Owner" }, { name: "anna" }, { name: "" }]) {
      expect(await errorCode(await call(post("/api/account/delete", body, as(anna))))).toBe("confirmation_mismatch");
    }
    expect(await errorCode(await call(post("/api/account/delete", {}, as(anna))))).toBe("invalid_request");
    expect(await snapshot()).toBe(before);

    // An account id in the body is ignored: the account is the session's (FR-14).
    const deleted = await call(post("/api/account/delete", { name: "Anna", accountId: boris.accountId }, as(anna)));
    expect([deleted.status, await deleted.json()]).toEqual([200, {}]);
    expect(deleted.headers.get("Set-Cookie")).toBe("__Host-lingo_session=; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=0");
    expect(await errorCode(await call(get("/api/me", as(anna))))).toBe("session_ended");
    expect(await snapshot()).not.toContain("Anna");
    expect(await meStatus(boris)).toBe(200);
    expect((await accounts(owner)).accounts.map((a) => a.name)).toEqual(["Owner", "Boris"]);
    expect(await Promise.all(["accounts", "devices", "sessions", "links", "events"].map(count))).toEqual([2, 2, 2, 1, 0]);
  });
});

describe("own account: rename (FR-10)", () => {
  it("renames the caller's account only; the admin may rename itself", async () => {
    const owner = await admin();
    const anna = await joined("Anna");
    const boris = await joined("Boris");
    const renamed = await call(post("/api/account/rename", { name: "  Anna Maria ", accountId: boris.accountId }, as(anna)));
    expect(renamed.status).toBe(200);
    expect(await renamed.json()).toEqual({ account: { id: anna.accountId, name: "Anna Maria", isAdmin: false }, device: { id: anna.deviceId, name: "Browser" } });
    expect((await call(post("/api/account/rename", { name: "Boss" }, as(owner)))).status).toBe(200);
    expect((await accounts(owner)).accounts.map((a) => [a.name, a.isAdmin])).toEqual([["Boss", true], ["Anna Maria", false], ["Boris", false]]);
    // Deleting now needs the new name.
    expect(await errorCode(await call(post("/api/account/delete", { name: "Anna" }, as(anna))))).toBe("confirmation_mismatch");

    const before = await snapshot();
    for (const name of [undefined, "", " ", "x".repeat(41), "a‮b", 5]) {
      expect(await errorCode(await call(post("/api/account/rename", { name }, as(anna))))).toBe("invalid_request");
    }
    expect(await errorCode(await call(post("/api/account/rename", { name: "X" })))).toBe("not_signed_in");
    expect(await snapshot()).toBe(before);
  });
});

describe("accounts list and isolation (FR-12, FR-13, FR-14, FAC-05)", () => {
  it("returns name, times, device count, stored size and status — and the total", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    const t0 = new Date("2026-11-14T10:00:00Z").getTime();
    vi.setSystemTime(t0);
    const owner = await admin();
    vi.setSystemTime(t0 + 1000);
    const anna = await joined("Anna");
    vi.setSystemTime(t0 + 2000);
    const boris = await joined("Boris");
    vi.setSystemTime(t0 + 3000);
    const link = await signInLink(owner, anna.accountId);
    const second = await call(post("/api/sign-in", { token: link.token }));
    await store(anna.accountId, "x".repeat(700));
    await store(boris.accountId, "y".repeat(300));
    await call(post("/api/sign-out", {}, as(boris)));

    expect(await accounts(owner)).toEqual({
      accounts: [
        { id: owner.accountId, name: "Owner", isAdmin: true, status: "active", createdAt: t0, lastSignInAt: t0, deviceCount: 1, storedBytes: 0 },
        { id: anna.accountId, name: "Anna", isAdmin: false, status: "active", createdAt: t0 + 1000, lastSignInAt: t0 + 3000, deviceCount: 2, storedBytes: 700 },
        { id: boris.accountId, name: "Boris", isAdmin: false, status: "active", createdAt: t0 + 2000, lastSignInAt: null, deviceCount: 0, storedBytes: 300 },
      ],
      totalStoredBytes: 1000,
    });
    // A device whose session expired no longer counts.
    await env.DB.prepare("UPDATE sessions SET expires_at = ? WHERE device_id = ?").bind(t0, anna.deviceId).run();
    expect((await accounts(owner)).accounts[1]).toMatchObject({ deviceCount: 1, lastSignInAt: t0 + 3000 });
    expect(second.status).toBe(200);
  });

  it("no admin answer holds events, device or session data of a friend", async () => {
    const owner = await admin();
    const anna = await joined("Anna");
    await call(post("/api/devices/rename", { deviceId: anna.deviceId, name: "ANNA-DEVICE-NAME" }, as(anna)));
    const eventId = crypto.randomUUID();
    await env.DB.prepare("INSERT INTO events (account_id, event_id, body) VALUES (?, ?, ?)").bind(anna.accountId, eventId, '{"type":"session_started","title":"ANNA-SESSION-TITLE"}').run();
    const sessionHash = (await env.DB.prepare("SELECT hash FROM sessions WHERE account_id = ?").bind(anna.accountId).first<string>("hash"))!;
    const made = await newInvite(owner, "Clara");

    const answers: string[] = [];
    const say = async (request: Request) => {
      const response = await call(request);
      expect(response.status).toBe(200);
      answers.push(await response.text());
    };
    await say(get("/api/admin/accounts", as(owner)));
    await say(get("/api/admin/invites", as(owner)));
    await say(post("/api/admin/invites/revoke", { inviteId: made.invite.id }, as(owner)));
    await say(post("/api/admin/sign-in-links", { accountId: anna.accountId }, as(owner)));
    await say(post("/api/admin/accounts/block", { accountId: anna.accountId }, as(owner)));
    await say(post("/api/admin/accounts/unblock", { accountId: anna.accountId }, as(owner)));
    await say(get("/api/devices", as(owner)));
    await say(get("/api/me", as(owner)));
    await say(post("/api/admin/accounts/delete", { accountId: anna.accountId, name: "Anna" }, as(owner)));
    const all = answers.join("\n");
    for (const secret of ["ANNA-SESSION-TITLE", "session_started", eventId, "ANNA-DEVICE-NAME", anna.deviceId, sessionHash, anna.cookie.split("=")[1]!, anna.token]) {
      expect(all).not.toContain(secret);
    }
    const listed = JSON.parse(answers[0]!) as { accounts: Record<string, unknown>[] };
    for (const account of listed.accounts) {
      expect(Object.keys(account).sort()).toEqual(["createdAt", "deviceCount", "id", "isAdmin", "lastSignInAt", "name", "status", "storedBytes"]);
    }
  });

  it("no answer to a friend holds anything of another account or of the admin", async () => {
    const owner = await admin();
    const anna = await joined("Anna");
    const boris = await joined("Boris-Name");
    await call(post("/api/devices/rename", { deviceId: boris.deviceId, name: "BORIS-DEVICE" }, as(boris)));
    await call(post("/api/devices/rename", { deviceId: owner.deviceId, name: "OWNER-DEVICE" }, as(owner)));
    await store(boris.accountId, "BORIS-EVENT");
    await newInvite(owner, "PENDING-INVITE");
    await signInLink(owner, boris.accountId);

    const answers: string[] = [];
    const say = async (request: Request) => answers.push(await (await call(request)).text());
    const foreign = { accountId: boris.accountId, deviceId: boris.deviceId, inviteId: "x" };
    for (const route of routes) {
      // Sign-out and deletion last, so the session lasts for every other route.
      if (["/api/sign-out", "/api/account/delete", "/api/setup", "/api/join", "/api/pair", "/api/sign-in"].includes(route.path)) continue;
      await say(route.method === "GET" ? get(route.path, as(anna)) : post(route.path, { ...foreign, name: route.path === "/api/account/rename" ? "Anna 2" : "Boris-Name" }, as(anna)));
    }
    await say(post("/api/account/delete", { ...foreign, name: "Boris-Name" }, as(anna)));
    await say(post("/api/account/delete", { ...foreign, name: "Anna 2" }, as(anna)));
    expect(answers.length).toBe(routes.length - 4);
    const all = answers.join("\n");
    for (const other of [boris.accountId, boris.deviceId, "Boris-Name", "BORIS-DEVICE", "BORIS-EVENT", owner.accountId, owner.deviceId, "Owner", "OWNER-DEVICE", "PENDING-INVITE"]) {
      expect(all).not.toContain(other);
    }
    // Boris and the admin are as they were; Anna is gone.
    expect(await meStatus(boris)).toBe(200);
    expect((await accounts(owner)).accounts.map((a) => [a.name, a.status, a.deviceCount, a.storedBytes])).toEqual([["Owner", "active", 1, 0], ["Boris-Name", "active", 1, 11]]);
    expect(await count("links")).toBe(3);
  });
});
