/** Spec FR-55. `apps/web/public/_headers` carries the same values for static files; a test compares the two. */
export const SECURITY_HEADERS: Readonly<Record<string, string>> = {
  "Content-Security-Policy": [
    "default-src 'none'",
    "script-src 'self'",
    "style-src 'self'",
    "img-src 'self'",
    "font-src 'self'",
    "connect-src 'self' https://api.groq.com https://api.mistral.ai https://openrouter.ai",
    "manifest-src 'self'",
    "worker-src 'self'",
    "base-uri 'none'",
    "form-action 'none'",
    "frame-ancestors 'none'",
  ].join("; "),
  "Referrer-Policy": "no-referrer",
  "X-Content-Type-Options": "nosniff",
};

/** Stable error codes (packages/contracts/api/openapi.yaml) with their status and English message. */
export const ERRORS = {
  not_found: [404, "Not found."],
  method_not_allowed: [405, "Method not allowed."],
  origin_refused: [403, "This request did not come from the Lingo site."],
  json_required: [403, "A JSON body is required."],
  body_too_large: [413, "The request is too large."],
  invalid_request: [400, "The request is not valid."],
  engine_misconfigured: [500, "The server is not configured."],
  internal_error: [500, "Something went wrong on the server."],
  not_signed_in: [401, "Not signed in."],
  session_ended: [401, "This device was signed out."],
  account_blocked: [403, "This account is blocked."],
  already_signed_in: [409, "This browser is already signed in. Sign out first."],
  link_invalid: [410, "This link is no longer valid. Ask for a new one."],
  invites_disabled: [503, "Invites are switched off."],
  secret_invalid: [403, "The setup secret is not correct."],
  too_many_attempts: [429, "Too many attempts. Try again later."],
  admin_protected: [403, "The admin account cannot be blocked or deleted."],
  confirmation_mismatch: [400, "The typed name does not match the account's name."],
  account_not_active: [409, "This account is blocked. Unblock it first."],
} as const satisfies Record<string, readonly [number, string]>;

export type ErrorCode = keyof typeof ERRORS;

export function json(status: number, body: unknown, extra?: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...SECURITY_HEADERS, "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store", ...extra },
  });
}

/** A refusal with a typed code. `status` overrides the code's own status (429 with the `link_invalid` answer, spec FR-06). */
export class ApiError extends Error {
  constructor(
    readonly code: ErrorCode,
    readonly options: { status?: number; headers?: Record<string, string> } = {},
  ) {
    super(code);
  }

  response(): Response {
    const [status, message] = ERRORS[this.code];
    return json(this.options.status ?? status, { code: this.code, message }, this.options.headers);
  }
}
