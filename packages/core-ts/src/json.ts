/** An arbitrary JSON value: unknown fields and event types survive without loss (R-35), as Swift `JSONValue`. */
export type JSONValue = null | boolean | number | string | JSONValue[] | { [key: string]: JSONValue };
export type JSONObject = { [key: string]: JSONValue };

export function isJSONObject(v: unknown): v is JSONObject {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

/**
 * A number as Swift's `JSONEncoder` writes a `Double`: like JavaScript, except that negative zero stays `-0` and a negative
 * exponent has at least two digits (`1.5e-07`).
 */
export function numberJSON(n: number): string {
  if (!Number.isFinite(n)) throw new TypeError("JSON numbers must be finite");
  if (Object.is(n, -0)) return "-0";
  return String(n).replace(/e-(\d)$/, "e-0$1");
}

/**
 * Canonical JSON, byte-identical to Swift `JSONEncoder` with `.sortedKeys` and `.withoutEscapingSlashes`: keys sorted by UTF-16
 * code units (the same order for the keys in use), strings escaped as `JSON.stringify` does (checked against Swift), no spaces.
 */
export function canonicalJSON(v: JSONValue): string {
  if (v === null) return "null";
  if (typeof v === "boolean") return v ? "true" : "false";
  if (typeof v === "number") return numberJSON(v);
  if (typeof v === "string") return JSON.stringify(v);
  if (Array.isArray(v)) return `[${v.map(canonicalJSON).join(",")}]`;
  const keys = Object.keys(v).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${canonicalJSON(v[k] as JSONValue)}`).join(",")}}`;
}
