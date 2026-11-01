import { describe, expect, it } from "vitest";
import {
  EventParseError, EventType, KNOWN_EVENT_TYPES, canonicalJSON, eventLine, formatTS, isValidULID, makeULID, numberJSON,
  parseEventLine, readJournal, parseTS, ulidTime,
} from "../src/index.js";
import { readContract } from "./contracts.js";

const journals = ["fixtures/events/sample-journal.jsonl", "fixtures/events/merge-two-devices.input.jsonl", "fixtures/vocab/events.jsonl"];
const lines = (path: string) => readContract(path).split("\n").filter((l) => l.trim() !== "");

describe("journal lines written by Swift", () => {
  it.each(journals)("%s round-trips byte for byte", (path) => {
    const all = lines(path);
    expect(all.length).toBeGreaterThan(0);
    for (const line of all) expect(eventLine(parseEventLine(line))).toBe(line);
  });

  it("covers every known event type and nothing unknown", () => {
    const types = new Set(journals.flatMap((p) => readJournal(readContract(p)).events.map((e) => e.type)));
    for (const t of types) expect(KNOWN_EVENT_TYPES.has(t)).toBe(true);
    for (const t of [EventType.sessionCreated, EventType.messageCreated, EventType.vocabUsed, EventType.profileUpdated]) expect(types.has(t)).toBe(true);
  });

  it("ids are ULIDs whose time part is the event time (sorting ids sorts by time)", () => {
    for (const e of readJournal(readContract("fixtures/events/sample-journal.jsonl")).events) {
      expect(isValidULID(e.id)).toBe(true);
      expect(e.id.slice(0, 10)).toBe(ulidTime(e.ts));
    }
  });
});

describe("unknown data is kept", () => {
  it("keeps unknown top-level fields, unknown types and unknown payload fields", () => {
    const line = canonicalJSON({
      v: 1, id: "01M5VJ1KF80KH70QYS833AQ708", device: "web-abcd", seq: 3, lamport: 9, ts: "2026-10-26T07:33:21.007Z",
      type: "future.thing", session: "s1", payload: { a: [1, 2.5, null, true], nested: { "z/y": "é \u2028 😀" } },
      zzz: { kept: true }, aaa: -0,
    });
    const e = parseEventLine(line);
    expect(e.extra).toEqual({ zzz: { kept: true }, aaa: -0 });
    expect(eventLine(e)).toBe(line);
  });

  it("keeps an unknown __proto__ field and a null payload", () => {
    const line = '{"__proto__":{"x":1},"device":"mac-abcd","id":"01M5VJ1KF80KH70QYS833AQ708","lamport":1,"payload":null,"seq":1,"session":"","ts":"2026-10-26T07:33:21.000Z","type":"x","v":1}';
    const e = parseEventLine(line);
    expect(Object.keys(e.extra)).toEqual(["__proto__"]);
    expect(e.payload).toBeNull();
    expect(eventLine(e)).toBe(line);
  });

  it("defaults a missing session to an empty string and a missing payload to an empty object, as Swift does", () => {
    const e = parseEventLine('{"device":"mac-abcd","id":"01M5VJ1KF80KH70QYS833AQ708","lamport":1,"seq":1,"ts":"2026-10-26T07:33:21Z","type":"x","v":1}');
    expect(e.session).toBe("");
    expect(e.payload).toEqual({});
    expect(eventLine(e)).toContain('"ts":"2026-10-26T07:33:21.000Z"');
  });
});

describe("reading a journal file (Swift JournalReader.parse)", () => {
  const line = lines("fixtures/events/sample-journal.jsonl")[0] as string;
  it("ignores a torn last line, skips and counts corrupted lines, flags a newer schema", () => {
    const newer = line.replace('"v":1', '"v":2');
    const r = readJournal(`${line}\n{broken\n\n  \n${newer}\n${line.slice(0, 20)}`);
    expect(r.events.length).toBe(2);
    expect(r.corruptedLines).toBe(1);
    expect(r.tornTail).toBe(true);
    expect(r.newerSchema).toBe(true);
    expect(readJournal("")).toEqual({ events: [], tornTail: false, corruptedLines: 0, newerSchema: false });
  });
});

describe("time", () => {
  it("odd milliseconds round-trip in the shared fixture", () => {
    for (const l of lines("fixtures/events/timestamps.jsonl")) expect(eventLine(parseEventLine(l))).toBe(l);
    expect(() => formatTS(Date.UTC(10000, 0, 1))).toThrow();
    expect(parseTS("0050-01-01T00:00:00.000Z")).toBe(Date.parse("0050-01-01T00:00:00.000Z"));
  });

  it("keeps milliseconds", () => {
    const ms = parseTS("2026-10-26T07:33:21.007Z");
    expect(ms).toBe(Date.UTC(2026, 9, 26, 7, 33, 21, 7));
    expect(formatTS(ms as number)).toBe("2026-10-26T07:33:21.007Z");
  });

  it.each(["2026-10-26 07:33:21Z", "2026-10-26T07:33:21+01:00", "2026-13-01T00:00:00Z", "2026-02-30T00:00:00Z", "2026-10-26T07:33:21.0001Z", ""])(
    "rejects %j", (s) => expect(parseTS(s)).toBeNull());
});

describe("invalid lines are rejected", () => {
  const good = { v: 1, id: "01M5VJ1KF80KH70QYS833AQ708", device: "mac-abcd", seq: 1, lamport: 1, ts: "2026-10-26T07:33:21.000Z", type: "x", session: "", payload: {} };
  it.each([
    ["not JSON", "{", "notJSON", undefined],
    ["an array", "[1]", "notObject", undefined],
    ["missing id", JSON.stringify({ ...good, id: undefined }), "missingField", "id"],
    ["seq as a string", JSON.stringify({ ...good, seq: "1" }), "missingField", "seq"],
    ["fractional lamport", JSON.stringify({ ...good, lamport: 1.5 }), "missingField", "lamport"],
    ["bad ts", JSON.stringify({ ...good, ts: "yesterday" }), "missingField", "ts"],
    ["missing v", JSON.stringify({ ...good, v: undefined }), "missingField", "v"],
    ["an unsafe integer", JSON.stringify({ ...good, seq: 2 ** 60 }), "missingField", "seq"],
    ["a lone surrogate (Swift rejects it)", JSON.stringify({ ...good, payload: { text: "a\ud83d" } }), "notSwiftCompatible", undefined],
    ["a number beyond Double", JSON.stringify(good).replace('"payload":{}', '"payload":{"n":1e400}'), "notSwiftCompatible", undefined],
  ])("%s", (_name, line, reason, field) => {
    let err: unknown;
    try { parseEventLine(line); } catch (e) { err = e; }
    expect(err).toBeInstanceOf(EventParseError);
    expect((err as EventParseError).reason).toBe(reason);
    expect((err as EventParseError).field).toBe(field);
  });
});

describe("canonical JSON matches Swift JSONEncoder", () => {
  it("numbers", () => {
    // Swift output for the same Doubles: {"a":0.1,"b":1,"c":1e+21,"d":-0,"e":123456789012,"f":1.5e-07,"g":3.14159}
    expect(canonicalJSON({ g: 3.14159, f: 1.5e-7, e: 123456789012, d: -0, c: 1e21, b: 1, a: 0.1 }))
      .toBe('{"a":0.1,"b":1,"c":1e+21,"d":-0,"e":123456789012,"f":1.5e-07,"g":3.14159}');
    expect(() => numberJSON(Number.NaN)).toThrow();
    // Swift switches to exponent form above 2^53 and below 1e-4 (values checked against Swift 6.2).
    const swift: [number, string][] = [[2 ** 53, "9007199254740992"], [9007199254740994, "9.007199254740994e+15"], [1e16, "1e+16"],
      [0.0001, "0.0001"], [0.000099, "9.9e-05"], [0.00001, "1e-05"], [5e-324, "5e-324"], [-1e16, "-1e+16"]];
    for (const [n, out] of swift) expect(numberJSON(n)).toBe(out);
  });

  it("refuses lone surrogates and sorts astral keys by code point, as Swift does", () => {
    expect(() => canonicalJSON({ s: "\ud800" })).toThrow();
    expect(canonicalJSON({ "\uffff": 1, "😀": 2, "": 3 })).toBe('{"":3,"\uffff":1,"😀":2}');
  });

  it("strings and key order", () => {
    // Swift output: {"s":"a\u0001\u001fé/  \"\\\t\n\r\b\f😀"} and {"B":5,"Z":1,"_":3,"a":2,"é":4}
    expect(canonicalJSON({ s: "a\u0001\u001f\u007fé/\u2028\u2029\"\\\t\n\r\b\f😀" })).toBe('{"s":"a\\u0001\\u001f\u007fé/\u2028\u2029\\"\\\\\\t\\n\\r\\b\\f😀"}');
    expect(canonicalJSON({ Z: 1, a: 2, _: 3, é: 4, B: 5 })).toBe('{"B":5,"Z":1,"_":3,"a":2,"é":4}');
  });
});

describe("ULID", () => {
  it("is 26 Crockford characters with the time first, as Swift ULID.make(ms:using:)", () => {
    let i = 0;
    const id = makeULID(1_792_900_000_123, () => i++);
    expect(id).toBe(ulidTime(1_792_900_000_123) + "0123456789ABCDEF");
    expect(isValidULID(id)).toBe(true);
    expect(isValidULID(id.toLowerCase())).toBe(false);
    expect(isValidULID(id.replace("A", "I"))).toBe(false);
  });

  it("sorts by time", () => {
    const made = [5, 1, 3, 2, 4].map((ms) => ({ ms, id: makeULID(1_792_900_000_000 + ms) }));
    const byID = [...made].sort((a, b) => (a.id < b.id ? -1 : 1)).map((x) => x.ms);
    expect(byID).toEqual([1, 2, 3, 4, 5]);
    expect(ulidTime(0)).toBe("0000000000");
  });
});
