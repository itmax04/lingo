// Creates the git-ignored `.dev.vars` for local development (spec FR-62): a generated pepper, a generated setup secret and
// DEV_MODE=1. Never overwrites an existing file and never prints a value; the owner reads the setup secret from the file.
import { randomBytes } from "node:crypto";
import { existsSync, writeFileSync } from "node:fs";

const file = new URL("../.dev.vars", import.meta.url);
if (existsSync(file)) {
  console.log(".dev.vars exists; left unchanged.");
} else {
  const secret = () => randomBytes(32).toString("base64url");
  writeFileSync(file, `PEPPER=${secret()}\nSETUP_SECRET=${secret()}\nDEV_MODE=1\n`, { mode: 0o600 });
  console.log("Created services/engine/.dev.vars (git-ignored). The setup secret for /setup is the SETUP_SECRET line in it.");
}
