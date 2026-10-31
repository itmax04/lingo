import { defineConfig } from "vitest/config";

// An empty or skipped suite is a failure, not a pass (upgrade plan §3, profile T).
export default defineConfig({
  test: {
    include: ["test/**/*.test.ts"],
    passWithNoTests: false,
    allowOnly: false,
  },
});
