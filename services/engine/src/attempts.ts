/** Failed redemptions (spec FR-06): counted per bucket in 10-minute windows; no request content is stored. */
export const WINDOW_MS = 10 * 60 * 1000;
/** Per client address, all link kinds and setup together. */
export const CLIENT_LIMIT = 10;
/** Failed setup attempts of all clients together (executor decision, spec FR-11). */
export const SETUP_GLOBAL_LIMIT = 20;
export const SETUP_BUCKET = "setup";

/** The client's bucket: the address Cloudflare reports; an IPv6 address counts by its /64 prefix. */
export function clientBucket(request: Request): string {
  const ip = (request.headers.get("CF-Connecting-IP") ?? "").trim().toLowerCase();
  if (ip === "") return "ip:unknown";
  if (!ip.includes(":")) return `ip:${ip}`;
  if (ip.includes(".")) return `ip:${ip.slice(ip.lastIndexOf(":") + 1)}`; // IPv4-mapped
  const [head = "", tail] = ip.split("::");
  const left = head === "" ? [] : head.split(":");
  const right = tail === undefined || tail === "" ? [] : tail.split(":");
  const groups = tail === undefined ? left : [...left, ...Array<string>(Math.max(0, 8 - left.length - right.length)).fill("0"), ...right];
  return `ip6:${groups.slice(0, 4).map((g) => (Number.parseInt(g, 16) || 0).toString(16)).join(":")}`;
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
