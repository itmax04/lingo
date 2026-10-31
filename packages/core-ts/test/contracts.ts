import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

/** Absolute path inside packages/contracts, the shared source of truth with the Swift LingoCore. */
export function contractPath(relative: string): string {
  return fileURLToPath(new URL(`../../contracts/${relative}`, import.meta.url));
}

export function readContract(relative: string): string {
  return readFileSync(contractPath(relative), "utf8");
}

export function readJSON<T = unknown>(relative: string): T {
  return JSON.parse(readContract(relative)) as T;
}
