import { defineConfig } from "vitest/config";
import type { Reporter, TestModule } from "vitest/node";

/**
 * Profile T (upgrade plan §3): a run with a skipped or todo test, or with no passed test, is a failure, not a pass.
 * Empty files and `.only` already fail through `passWithNoTests` and `allowOnly`.
 */
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
    // A local name filter (`vitest run -t …`) skips the other tests on purpose; the T and C profiles never filter.
    const filtered = process.argv.some((a) => a === "-t" || a.startsWith("--testNamePattern"));
    if ((skipped.length > 0 && !filtered) || passed === 0) {
      process.exitCode = 1;
      console.error(skipped.length > 0 ? `Skipped or todo tests are not allowed: ${skipped.join("; ")}` : "No test passed.");
    }
  },
};

export default defineConfig({
  test: {
    include: ["test/**/*.test.ts"],
    passWithNoTests: false,
    allowOnly: false,
    reporters: ["default", noSkips],
  },
});
