import type { Route } from "./app";
import { join, me, setup } from "./auth";

/** The engine's API. Every path here is described in packages/contracts/api/openapi.yaml first. */
export const routes: readonly Route[] = [
  { method: "POST", path: "/api/setup", handler: setup },
  { method: "POST", path: "/api/join", handler: join },
  { method: "GET", path: "/api/me", handler: me },
];
