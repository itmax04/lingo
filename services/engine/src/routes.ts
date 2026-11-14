import type { Route } from "./app";
import { join, me, pair, setup } from "./auth";
import { createPairing, listDevices, renameDevice, signOut, signOutDevice, signOutOthers } from "./devices";

/** The engine's API. Every path here is described in packages/contracts/api/openapi.yaml first. */
export const routes: readonly Route[] = [
  { method: "POST", path: "/api/setup", handler: setup },
  { method: "POST", path: "/api/join", handler: join },
  { method: "GET", path: "/api/me", handler: me },
  { method: "POST", path: "/api/pairings", handler: createPairing },
  { method: "POST", path: "/api/pair", handler: pair },
  { method: "GET", path: "/api/devices", handler: listDevices },
  { method: "POST", path: "/api/devices/rename", handler: renameDevice },
  { method: "POST", path: "/api/devices/sign-out", handler: signOutDevice },
  { method: "POST", path: "/api/devices/sign-out-others", handler: signOutOthers },
  { method: "POST", path: "/api/sign-out", handler: signOut },
];
