/** An arbitrary JSON value: unknown fields and event types survive without loss (R-35), as Swift `JSONValue`. */
export type JSONValue = null | boolean | number | string | JSONValue[] | { [key: string]: JSONValue };
export type JSONObject = { [key: string]: JSONValue };

export function isJSONObject(v: unknown): v is JSONObject {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

const LONE_SURROGATE = /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/;

/** Swift `JSONDecoder` rejects ill-formed strings and numbers out of the Double range; so does this check (keys included). */
export function isSwiftCompatible(v: JSONValue): boolean {
  if (typeof v === "number") return Number.isFinite(v);
  if (typeof v === "string") return !LONE_SURROGATE.test(v);
  if (Array.isArray(v)) return v.every(isSwiftCompatible);
  if (isJSONObject(v)) return Object.entries(v).every(([k, x]) => !LONE_SURROGATE.test(k) && isSwiftCompatible(x));
  return true;
}

/**
 * A number as Swift's `JSONEncoder` writes a `Double` (checked against Swift 6.2): the shortest round-trip digits, in exponent form
 * above 2^53 and below 1e-4 (JavaScript switches only at 1e21 and 1e-6), a two-digit negative exponent (`1e-05`), and `-0`.
 */
export function numberJSON(n: number): string {
  if (!Number.isFinite(n)) throw new TypeError("JSON numbers must be finite");
  if (Object.is(n, -0)) return "-0";
  const a = Math.abs(n);
  const s = a > 2 ** 53 || (a > 0 && a < 1e-4) ? n.toExponential() : String(n);
  return s.replace(/e([+-])(\d)$/, "e$10$2");
}

/** Code-point order, as Swift sorts dictionary keys (JavaScript `sort()` compares UTF-16 units, which differs for astral keys). */
export function compareCodePoints(a: string, b: string): number {
  const x = Array.from(a), y = Array.from(b);
  for (let i = 0; i < Math.min(x.length, y.length); i++) {
    const d = (x[i]?.codePointAt(0) ?? 0) - (y[i]?.codePointAt(0) ?? 0);
    if (d !== 0) return d;
  }
  return x.length - y.length;
}

/**
 * Canonical JSON, byte-identical to Swift `JSONEncoder` with `.sortedKeys` and `.withoutEscapingSlashes`: keys in code-point order,
 * strings escaped as `JSON.stringify` does (the same as Swift), no spaces. Ill-formed strings are refused, as Swift refuses them.
 */
export function canonicalJSON(v: JSONValue): string {
  if (v === null) return "null";
  if (typeof v === "boolean") return v ? "true" : "false";
  if (typeof v === "number") return numberJSON(v);
  if (typeof v === "string") return quote(v);
  if (Array.isArray(v)) return `[${v.map(canonicalJSON).join(",")}]`;
  const keys = Object.keys(v).sort(compareCodePoints);
  return `{${keys.map((k) => `${quote(k)}:${canonicalJSON(v[k] as JSONValue)}`).join(",")}}`;
}

function quote(s: string): string {
  if (LONE_SURROGATE.test(s)) throw new TypeError("ill-formed string (lone surrogate)");
  return JSON.stringify(s);
}
