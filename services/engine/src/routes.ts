import { deleteOwnAccount, renameAccount } from "./account";
import { blockAccount, createInvite, createSignInLink, deleteFriend, listAccounts, listInvites, revokeInvite, unblockAccount } from "./admin";
import type { Route } from "./app";
import { join, me, pair, setup, signIn } from "./auth";
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
  { method: "POST", path: "/api/sign-in", handler: signIn },
  { method: "POST", path: "/api/account/rename", handler: renameAccount },
  { method: "POST", path: "/api/account/delete", handler: deleteOwnAccount },
  { method: "GET", path: "/api/admin/invites", handler: listInvites },
  { method: "POST", path: "/api/admin/invites/create", handler: createInvite },
  { method: "POST", path: "/api/admin/invites/revoke", handler: revokeInvite },
  { method: "GET", path: "/api/admin/accounts", handler: listAccounts },
  { method: "POST", path: "/api/admin/sign-in-links", handler: createSignInLink },
  { method: "POST", path: "/api/admin/accounts/block", handler: blockAccount },
  { method: "POST", path: "/api/admin/accounts/unblock", handler: unblockAccount },
  { method: "POST", path: "/api/admin/accounts/delete", handler: deleteFriend },
];
