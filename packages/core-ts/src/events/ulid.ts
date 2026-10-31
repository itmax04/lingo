/** ULID (R-35): 48 bits of time (ms) + 80 bits of randomness, Crockford Base32, 26 characters; as Swift `ULID`. */
const ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
const VALID = /^[0-9A-HJKMNP-TV-Z]{26}$/;

/** A source of random integers; only the low 5 bits of each value are used (Swift `rng.next() & 31`). */
export type RandomSource = () => number;

/** Web Crypto, present in browsers, Workers and Node ≥ 19; declared here because core-ts uses no DOM or Node types. */
declare const crypto: { getRandomValues<T extends Uint32Array>(array: T): T };

export const cryptoRandom: RandomSource = () => crypto.getRandomValues(new Uint32Array(1))[0] ?? 0;

/** The first 10 characters: the time in milliseconds, so sorting the strings sorts by creation time. */
export function ulidTime(ms: number): string {
  let t = Math.max(0, Math.floor(ms));
  let out = "";
  for (let i = 0; i < 10; i++) {
    out = ALPHABET.charAt(t % 32) + out;
    t = Math.floor(t / 32);
  }
  return out;
}

export function makeULID(ms: number = Date.now(), random: RandomSource = cryptoRandom): string {
  let out = ulidTime(ms);
  for (let i = 0; i < 16; i++) out += ALPHABET.charAt(random() & 31);
  return out;
}

export function isValidULID(s: string): boolean {
  return VALID.test(s);
}
