// Starts the Worker with `wrangler dev` on a throw-away local D1 and checks what unit tests cannot see: the entry module
// loads in the real runtime, the platform applies `_headers` to static files, API answers carry the same headers
// (spec FR-55, FAC-18), and the local run works end to end: migrations, setup, session cookie, me, pairing by code, devices,
// sign-out (spec FR-62, FAC-19).
import { execFileSync, spawn } from "node:child_process";
import { randomBytes } from "node:crypto";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const port = 8797;
const base = `http://localhost:${port}`;
const expected = Object.fromEntries(
  readFileSync(new URL("../../../apps/web/public/_headers", import.meta.url), "utf8")
    .split("\n")
    .filter((l) => l.startsWith("  "))
    .map((l) => [l.slice(0, l.indexOf(":")).trim().toLowerCase(), l.slice(l.indexOf(":") + 1).trim()]),
);
const state = mkdtempSync(join(tmpdir(), "lingo-smoke-"));
const secret = () => randomBytes(32).toString("base64url");
const setupSecret = secret();
const failures = [];
const check = (ok, text) => (ok ? console.log(`ok   ${text}`) : (console.log(`FAIL ${text}`), failures.push(text)));
const json = { Origin: base, "Content-Type": "application/json" };

execFileSync("npx", ["wrangler", "d1", "migrations", "apply", "lingo", "--local", "--persist-to", state], { stdio: "ignore" });
// Its own process group: `npx` does not pass SIGTERM on to wrangler and workerd on Linux, whose open pipes kept the script
// (and the CI step) running after the checks.
const child = spawn(
  "npx",
  ["wrangler", "dev", "--port", String(port), "--persist-to", state, "--var", `PEPPER:${secret()}`, "--var", `SETUP_SECRET:${setupSecret}`, "--var", "DEV_MODE:1"],
  { stdio: ["ignore", "pipe", "pipe"], detached: true },
);
let output = "";
child.stdout.on("data", (d) => (output += d));
child.stderr.on("data", (d) => (output += d));

try {
  let up = false;
  for (let i = 0; i < 60 && !up; i++) {
    await new Promise((r) => setTimeout(r, 500));
    up = await fetch(base + "/").then(() => true, () => false);
  }
  if (!up) throw new Error("wrangler dev did not start");

  check(Object.keys(expected).length === 3, "_headers lists three headers");
  for (const [path, status, type] of [["/", 200, "text/html"], ["/join", 200, "text/html"], ["/api/nope", 404, "application/json"], ["/api/me", 401, "application/json"]]) {
    const r = await fetch(base + path);
    const headersOk = Object.entries(expected).every(([name, value]) => r.headers.get(name) === value);
    check(r.status === status && (r.headers.get("content-type") ?? "").startsWith(type) && headersOk, `GET ${path} → ${status} ${type} with the security headers`);
  }

  const foreign = await fetch(base + "/api/setup", { method: "POST", headers: { ...json, Origin: "https://evil.example" }, body: JSON.stringify({ secret: setupSecret }) });
  check(foreign.status === 403, "POST /api/setup with a foreign Origin → 403");
  const wrong = await fetch(base + "/api/setup", { method: "POST", headers: json, body: JSON.stringify({ secret: secret() }) });
  check(wrong.status === 403, "POST /api/setup with a wrong secret → 403");
  const setup = await fetch(base + "/api/setup", { method: "POST", headers: json, body: JSON.stringify({ secret: setupSecret }) });
  const cookie = (setup.headers.get("set-cookie") ?? "").split(";")[0];
  check(setup.status === 200 && cookie.startsWith("lingo_session="), "POST /api/setup → 200 and the development cookie");
  const me = await fetch(base + "/api/me", { headers: { Cookie: cookie } });
  check(me.status === 200 && (await me.json()).account.isAdmin === true, "GET /api/me with the cookie → the admin");
  // Pairing end to end on the real runtime: migration 0002's triggers, the conditional counter statement and the batch.
  const pairing = await (await fetch(base + "/api/pairings", { method: "POST", headers: { ...json, Cookie: cookie }, body: "{}" })).json();
  const wrongCode = await fetch(base + "/api/pair", { method: "POST", headers: json, body: JSON.stringify({ code: pairing.code === "AAAAAAAA" ? "BBBBBBBB" : "AAAAAAAA" }) });
  check(wrongCode.status === 410, "POST /api/pair with a wrong code → 410");
  const paired = await fetch(base + "/api/pair", { method: "POST", headers: json, body: JSON.stringify({ code: pairing.code, deviceName: "Smoke" }) });
  const second = (paired.headers.get("set-cookie") ?? "").split(";")[0];
  check(paired.status === 200 && second.startsWith("lingo_session=") && second !== cookie, "POST /api/pair with the typed code → 200 and a second session");
  const list = await (await fetch(base + "/api/devices", { headers: { Cookie: second } })).json();
  check(list.devices?.length === 2 && list.devices[1].current === true, "GET /api/devices → two devices, the second is the caller's");
  const out = await fetch(base + "/api/sign-out", { method: "POST", headers: { ...json, Cookie: second }, body: "{}" });
  const after = await fetch(base + "/api/me", { headers: { Cookie: second } });
  check(out.status === 200 && after.status === 401, "POST /api/sign-out → 200, then GET /api/me → 401");
  const join = await fetch(base + "/api/join", { method: "POST", headers: json, body: JSON.stringify({ token: secret() }) });
  check(join.status === 410, "POST /api/join with an unknown token → 410");
} catch (e) {
  failures.push(String(e));
} finally {
  try {
    process.kill(-child.pid, "SIGTERM");
  } catch {
    child.kill("SIGTERM");
  }
  rmSync(state, { recursive: true, force: true });
}
if (failures.length > 0) {
  console.error(output.replaceAll(setupSecret, "<setup secret>").slice(-2000));
  console.error("smoke: FAIL\n" + failures.join("\n"));
  process.exit(1);
}
console.log("smoke: PASS");
process.exit(0);
