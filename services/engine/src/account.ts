import { deleteAccount } from "./admin";
import type { Ctx } from "./app";
import { nameField } from "./auth";
import { json } from "./http";
import { authenticate, clearedCookie } from "./session";

/** POST /api/account/rename — the caller's own account; the id comes from the session only (spec FR-10, FR-14). */
export async function renameAccount(ctx: Ctx): Promise<Response> {
  const { me, setCookie } = await authenticate(ctx);
  const name = nameField(ctx.body.name);
  await ctx.config.db.prepare("UPDATE accounts SET name = ?, updated_at = ? WHERE id = ?").bind(name, ctx.now, me.account.id).run();
  return json(200, { ...me, account: { ...me.account, name } }, setCookie === null ? undefined : { "Set-Cookie": setCookie });
}

/** POST /api/account/delete — "Delete my account" with the name typed as confirmation; refused for the admin (spec FR-09, FR-10). */
export async function deleteOwnAccount(ctx: Ctx): Promise<Response> {
  const { me } = await authenticate(ctx);
  await deleteAccount(ctx.config.db, me.account.id, ctx.body.name);
  return json(200, {}, { "Set-Cookie": clearedCookie(ctx.config) });
}
