import { isJSONObject, type JSONObject, type JSONValue } from "../json.js";

/**
 * Small decoders with the strictness of Swift's synthesized `Codable` (LINGO-03 P-07c): a required field must be present with the
 * right type, an optional one may be missing or `null`, enum values must be known, integers must be whole, extra fields are ignored.
 * A failed decode makes the reducer count the event as unknown, as Swift `try? decode` does.
 */
export class DecodeError extends Error {
  constructor(readonly path: string) {
    super(`cannot decode ${path}`);
    this.name = "DecodeError";
  }
}

export type Decoder<T> = (v: JSONValue | undefined, path: string) => T;

export const str: Decoder<string> = (v, p) => {
  if (typeof v !== "string") throw new DecodeError(p);
  return v;
};

/** A whole number in the Int64 range: Swift decodes an `Int` field from such a JSON number (via Double). */
export const int: Decoder<number> = (v, p) => {
  if (typeof v !== "number" || !Number.isInteger(v) || Math.abs(v) >= 2 ** 63) throw new DecodeError(p);
  return v;
};

export const bool: Decoder<boolean> = (v, p) => {
  if (typeof v !== "boolean") throw new DecodeError(p);
  return v;
};

export function oneOf<T extends string>(values: readonly T[]): Decoder<T> {
  return (v, p) => {
    if (typeof v !== "string" || !(values as readonly string[]).includes(v)) throw new DecodeError(p);
    return v as T;
  };
}

export function array<T>(item: Decoder<T>): Decoder<T[]> {
  return (v, p) => {
    if (!Array.isArray(v)) throw new DecodeError(p);
    return v.map((x, i) => item(x, `${p}[${i}]`));
  };
}

/** A missing or `null` value is `undefined` (Swift `decodeIfPresent`). */
export function optional<T>(d: Decoder<T>): Decoder<T | undefined> {
  return (v, p) => (v === undefined || v === null ? undefined : d(v, p));
}

export function object(v: JSONValue | undefined, p: string): JSONObject {
  if (!isJSONObject(v)) throw new DecodeError(p);
  return v;
}

/** Field `k` of an object (own properties only). */
export function field(o: JSONObject, k: string): JSONValue | undefined {
  return Object.hasOwn(o, k) ? o[k] : undefined;
}

/** Decodes, or returns null when the value does not fit (Swift `try? decode`). */
export function attempt<T>(d: Decoder<T>, v: JSONValue | undefined): T | null {
  try {
    return d(v, "$");
  } catch (e) {
    if (e instanceof DecodeError) return null;
    throw e;
  }
}
