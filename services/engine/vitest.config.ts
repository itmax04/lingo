import { cloudflareTest, readD1Migrations } from "@cloudflare/vitest-pool-workers";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";
import type { Reporter, TestModule } from "vitest/node";

/** Profile T, as in packages/core-ts: a skipped or todo test, or a run without a passed test, is a failure. */
const noSkips: Reporter = {
  onTestRunEnd(modules: ReadonlyArray<TestModule>) {
    let passed = 0;
    const skipped: string[] = [];
    for (const m of modules) {
      for (const t of m.children.allTests()) {
        const state = t.result().state;
        if (state === "passed") passed++;
        else if (state === "skipped" || state === "pending") skipped.push(t.fullName);
      }
    }
    const filtered = process.argv.some((a) => a === "-t" || a.startsWith("--testNamePattern"));
    if ((skipped.length > 0 && !filtered) || passed === 0) {
      process.exitCode = 1;
      console.error(skipped.length > 0 ? `Skipped or todo tests are not allowed: ${skipped.join("; ")}` : "No test passed.");
    }
  },
};

export default defineConfig(async () => ({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: "./wrangler.jsonc" },
      // Tests build their own env (test/helpers.ts); only the database and the migrations come from here.
      miniflare: { bindings: { TEST_MIGRATIONS: await readD1Migrations(fileURLToPath(new URL("./migrations", import.meta.url))) } },
    }),
  ],
  test: {
    include: ["test/**/*.test.ts"],
    setupFiles: ["./test/setup.ts"],
    silent: "passed-only",
    passWithNoTests: false,
    allowOnly: false,
    reporters: ["default", noSkips],
  },
}));
