// Starts the Worker with `wrangler dev` (local D1, the real asset routing) and checks what unit tests cannot see:
// the entry module loads, static files carry the headers of `_headers`, API answers carry the same ones (spec FR-55, FAC-18).
import { spawn } from "node:child_process";
import { readFileSync } from "node:fs";

const port = 8797;
const base = `http://localhost:${port}`;
const expected = Object.fromEntries(
  readFileSync(new URL("../../../apps/web/public/_headers", import.meta.url), "utf8")
    .split("\n")
    .filter((l) => l.startsWith("  "))
    .map((l) => [l.slice(0, l.indexOf(":")).trim().toLowerCase(), l.slice(l.indexOf(":") + 1).trim()]),
);
const child = spawn("npx", ["wrangler", "dev", "--port", String(port)], { stdio: ["ignore", "pipe", "pipe"] });
let output = "";
child.stdout.on("data", (d) => (output += d));
child.stderr.on("data", (d) => (output += d));

const failures = [];
try {
  let up = false;
  for (let i = 0; i < 60 && !up; i++) {
    await new Promise((r) => setTimeout(r, 500));
    up = await fetch(base + "/").then(() => true, () => false);
  }
  if (!up) throw new Error("wrangler dev did not start");
  const cases = [
    ["/", 200, "text/html"],
    ["/join", 200, "text/html"],
    ["/api/nope", 404, "application/json"],
  ];
  for (const [path, status, type] of cases) {
    const r = await fetch(base + path);
    if (r.status !== status) failures.push(`${path}: status ${r.status}, expected ${status}`);
    if (!(r.headers.get("content-type") ?? "").startsWith(type)) failures.push(`${path}: content type ${r.headers.get("content-type")}`);
    for (const [name, value] of Object.entries(expected)) {
      if (r.headers.get(name) !== value) failures.push(`${path}: header ${name} is ${r.headers.get(name)}`);
    }
    console.log(`${path} → ${r.status} ${r.headers.get("content-type")}`);
  }
  if (Object.keys(expected).length !== 3) failures.push("_headers: expected three headers");
} catch (e) {
  failures.push(String(e));
} finally {
  child.kill("SIGTERM");
}
if (failures.length > 0) {
  console.error(output.slice(-2000));
  console.error("smoke: FAIL\n" + failures.join("\n"));
  process.exit(1);
}
console.log("smoke: PASS");
