#!/usr/bin/env python3
"""Voice loop metrics (R-47; AC-02, AC-03, AC-15; evals/README.md "Latency and memory metrics").

    scripts/metrics.py [metrics-*.jsonl files ...]   (default — ~/Library/Application Support/Lingo/metrics/*.jsonl)

A turn: speech_end → stt_final, stt_final → llm_first_token, speech_end → first_audio, speech_end → reply_end — median and p90.
AC-02 threshold: speech_end → first_audio median ≤ 8 s, p90 ≤ 10 s. Memory: peak footprint_mb (AC-15 ≤ 1200 MB).
The "repeat"/"slower" commands (no model) are counted separately (R-14: ≤ 0.3 s until audio).
"""
import glob, json, os, statistics, sys


def pct(xs, p):
    if not xs:
        return None
    xs = sorted(xs)
    k = min(len(xs) - 1, max(0, int(round(p * (len(xs) - 1)))))
    return xs[k]


def fmt(x):
    return "—" if x is None else f"{x:.2f} s"


def main():
    files = sys.argv[1:] or sorted(glob.glob(os.path.expanduser("~/Library/Application Support/Lingo/metrics/metrics-*.jsonl")))
    turns, mem = [], []
    for f in files:
        for ln in open(f, encoding="utf-8"):
            ln = ln.strip()
            if not ln:
                continue
            try:
                o = json.loads(ln)
            except json.JSONDecodeError:
                continue
            if o.get("type") == "turn":
                turns.append(o)
            if "footprint_mb" in o:
                mem.append(o["footprint_mb"])
    model_turns = [t for t in turns if "command" not in t and "failed" not in t]
    local = [t for t in turns if t.get("command") in ("repeat", "slower")]
    pairs = [("speech_end", "stt_final"), ("stt_final", "llm_first_token"), ("speech_end", "first_audio"), ("speech_end", "reply_end")]
    print(f"files: {len(files)}; turns: {len(turns)} (with the model {len(model_turns)}, local commands {len(local)}, chain errors {sum(1 for t in turns if 'failed' in t)})")
    res = {}
    for a, b in pairs:
        xs = [t[b] - t[a] for t in model_turns if a in t and b in t]
        res[(a, b)] = xs
        print(f"  {a} → {b}: n={len(xs)} median {fmt(statistics.median(xs) if xs else None)} p90 {fmt(pct(xs, 0.9))}")
    fa = res[("speech_end", "first_audio")]
    if fa:
        med, p90 = statistics.median(fa), pct(fa, 0.9)
        ok = med <= 8 and p90 <= 10
        print(f"AC-02: speech_end → first_audio median {med:.2f} s (≤ 8), p90 {p90:.2f} s (≤ 10) → {'PASS' if ok else 'FAIL'}")
    else:
        print("AC-02: NOT RUN (no turns with first_audio)")
    lx = [t["first_audio"] - t["stt_final"] for t in local if "first_audio" in t and "stt_final" in t]
    if lx:
        print(f"R-14 \"repeat\"/\"slower\": stt_final → first_audio median {statistics.median(lx):.2f} s, max {max(lx):.2f} s (≤ 0.3)")
    inter = [t for t in turns if "interrupt" in t]
    print(f"barge-ins: {len(inter)} ({', '.join(sorted(set(t['interrupt'] for t in inter)))})" if inter else "barge-ins: 0")
    if mem:
        print(f"memory: peak {max(mem)} MB, median {int(statistics.median(mem))} MB, samples {len(mem)} → AC-15 {'PASS' if max(mem) <= 1200 else 'FAIL'} (≤ 1200 MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
