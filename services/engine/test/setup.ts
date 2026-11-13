import { applyD1Migrations, env } from "cloudflare:test";
import { beforeEach } from "vitest";

await applyD1Migrations(env.DB, env.TEST_MIGRATIONS);

// Every test starts with an empty database (foreign keys cascade from accounts).
beforeEach(async () => {
  await env.DB.batch(["accounts", "links", "attempts", "events"].map((t) => env.DB.prepare(`DELETE FROM ${t}`)));
});
