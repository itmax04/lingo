const encoder = new TextEncoder();

/** Link and session tokens: 32 random bytes in base64url, 43 characters (spec FR-02, FR-04). */
export const TOKEN_PATTERN = /^[A-Za-z0-9_-]{43}$/;

export function randomToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

const hex = (buffer: ArrayBuffer): string => [...new Uint8Array(buffer)].map((b) => b.toString(16).padStart(2, "0")).join("");

/** The only form in which a token reaches the database: hex(HMAC-SHA-256(pepper, token)). */
export async function hmacHex(pepper: string, value: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", encoder.encode(pepper), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return hex(await crypto.subtle.sign("HMAC", key, encoder.encode(value)));
}

/** Constant-time comparison of two strings of any length: both are hashed first, the digests are compared (spec FR-11). */
export async function secretsEqual(a: string, b: string): Promise<boolean> {
  const [x, y] = await Promise.all([crypto.subtle.digest("SHA-256", encoder.encode(a)), crypto.subtle.digest("SHA-256", encoder.encode(b))]);
  return crypto.subtle.timingSafeEqual(x, y);
}
