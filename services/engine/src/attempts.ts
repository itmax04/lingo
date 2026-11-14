import { hmacHex } from "./crypto";

/** Failed redemptions (spec FR-06): counted per bucket in 10-minute windows; no request content is stored. */
export const WINDOW_MS = 10 * 60 * 1000;
/** Per client address, all link kinds and setup together. */
export const CLIENT_LIMIT = 10;
/** Failed setup attempts of all clients together (executor decision, spec FR-11). */
export const SETUP_GLOBAL_LIMIT = 20;
export const SETUP_BUCKET = "setup";
/** Failed typed pairing codes of all clients together (spec FR-06): above this, typed codes are refused for everybody. */
export const CODES_GLOBAL_LIMIT = 100;
export const CODES_BUCKET = "codes";

/** The client's bucket: the address Cloudflare reports; an IPv6 address counts by its /64 prefix. */
export function clientBucket(request: Request): string {
  const ip = (request.headers.get("CF-Connecting-IP") ?? "").trim().toLowerCase();
  if (ip === "") return "ip:unknown";
  if (!ip.includes(":")) return `ip:${ip}`;
  const [head = "", tail] = ip.split("::");
  const left = head === "" ? [] : head.split(":");
  const right = tail === undefined || tail === "" ? [] : tail.split(":");
  // An embedded dotted IPv4 tail takes two groups.
  const rightGroups = right.length > 0 && right[right.length - 1]!.includes(".") ? right.length + 1 : right.length;
  const groups = tail === undefined ? left : [...left, ...Array<string>(Math.max(0, 8 - left.length - rightGroups)).fill("0"), ...right];
  const hex = groups.map((g) => (g.includes(".") ? g : (Number.parseInt(g, 16) || 0).toString(16)));
  // IPv4-mapped (::ffff:a.b.c.d or ::ffff:hhhh:hhhh) counts as the IPv4 address; other embedded forms keep their /64.
  if (hex.slice(0, 5).every((g) => g === "0") && hex[5] === "ffff") {
    const v4 = hex.slice(6).join(":");
    if (v4.includes(".")) return `ip:${v4}`;
    const n = (Number.parseInt(hex[6] ?? "0", 16) << 16) | Number.parseInt(hex[7] ?? "0", 16);
    return `ip:${[24, 16, 8, 0].map((s) => (n >>> s) & 255).join(".")}`;
  }
  return `ip6:${hex.slice(0, 4).join(":")}`;
}

/**
 * The client's bucket as it is stored: a keyed hash, so that the table holds no client address (review R5 of F-1a).
 * The global buckets keep their plain names.
 */
export async function clientKey(pepper: string, request: Request): Promise<string> {
  return (await hmacHex(pepper, clientBucket(request))).slice(0, 32);
}

const windowStart = (now: number): number => Math.floor(now / WINDOW_MS) * WINDOW_MS;

/**
 * Failures of each bucket in the current and the previous window: a bucket below its limit here had fewer failures than the
 * limit in every 10 minutes that end now. One read, no write — a client over its limit is refused from this alone.
 */
export async function failureCounts(db: D1Database, buckets: readonly string[], now: number): Promise<number[]> {
  const { results } = await db
    .prepare(`SELECT bucket, SUM(failures) AS n FROM attempts WHERE window_start >= ? AND bucket IN (${buckets.map(() => "?").join(", ")}) GROUP BY bucket`)
    .bind(windowStart(now) - WINDOW_MS, ...buckets)
    .all<{ bucket: string; n: number }>();
  return buckets.map((b) => results.find((r) => r.bucket === b)?.n ?? 0);
}

export async function recordFailure(db: D1Database, buckets: readonly string[], now: number): Promise<void> {
  const start = windowStart(now);
  await db.batch([
    ...buckets.map((b) =>
      db
        .prepare("INSERT INTO attempts (bucket, window_start, failures) VALUES (?, ?, 1) ON CONFLICT (bucket, window_start) DO UPDATE SET failures = failures + 1")
        .bind(b, start),
    ),
    db.prepare("DELETE FROM attempts WHERE window_start < ?").bind(start - WINDOW_MS),
  ]);
}

/**
 * Typed codes (about 40 bits): the attempt is counted before the code is looked at, by one statement that writes only
 * while the client and all clients together are within their limits. Requests that arrive together are serialized by
 * the database, so a burst cannot pass a limit (review B2/N1 of F-1b), and a refused request writes nothing.
 * Returns false when refused. A successful redemption takes the count back with `refundCodeAttempt` in its own batch.
 */
export async function reserveCodeAttempt(db: D1Database, client: string, now: number): Promise<boolean> {
  const start = windowStart(now);
  const sum = "(SELECT COALESCE(SUM(failures), 0) FROM attempts WHERE bucket = ?1 AND window_start >= ?3)";
  const result = await db
    .prepare(
      `INSERT INTO attempts (bucket, window_start, failures)
       SELECT b, ?4, 1 FROM (SELECT ?1 AS b UNION ALL SELECT ?2)
       WHERE ${sum} < ?5 AND ${sum.replace("?1", "?2")} <= ?6
       ON CONFLICT (bucket, window_start) DO UPDATE SET failures = failures + 1`,
    )
    .bind(client, CODES_BUCKET, start - WINDOW_MS, start, CLIENT_LIMIT, CODES_GLOBAL_LIMIT)
    .run();
  return result.meta.changes > 0;
}

/** Undoes `reserveCodeAttempt` when `guard` (an SQL condition over ?1, ?2) holds; also drops windows that no longer count. */
export function refundCodeAttempt(db: D1Database, client: string, now: number, guard: string, guardValues: readonly [string, string]): D1PreparedStatement[] {
  const start = windowStart(now);
  return [
    db
      .prepare(`UPDATE attempts SET failures = failures - 1 WHERE bucket IN (?3, ?4) AND window_start = ?5 AND failures > 0 AND ${guard}`)
      .bind(...guardValues, client, CODES_BUCKET, start),
    // Rows the refund emptied go too, so a successful pairing leaves nothing behind.
    db.prepare("DELETE FROM attempts WHERE window_start < ? OR failures <= 0").bind(start - WINDOW_MS),
  ];
}
