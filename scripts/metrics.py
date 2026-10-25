#!/usr/bin/env python3
"""Метрики голосового цикла (R-47; AC-02, AC-03, AC-15; evals/README.md «Метрики задержки и памяти»).

    scripts/metrics.py [файлы metrics-*.jsonl ...]   (по умолчанию — ~/Library/Application Support/Lingo/metrics/*.jsonl)

Ход: speech_end → stt_final, stt_final → llm_first_token, speech_end → first_audio, speech_end → reply_end — медиана и p90.
Порог AC-02: speech_end → first_audio медиана ≤ 8 с, p90 ≤ 10 с. Память: пик footprint_mb (AC-15 ≤ 1200 МБ).
Команды «повтори»/«медленнее» (без модели) считаются отдельно (R-14: ≤ 0,3 с до звука).
"""
import glob, json, os, statistics, sys


def pct(xs, p):
    if not xs:
        return None
    xs = sorted(xs)
    k = min(len(xs) - 1, max(0, int(round(p * (len(xs) - 1)))))
    return xs[k]


def fmt(x):
    return "—" if x is None else f"{x:.2f} с"


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
    print(f"файлов: {len(files)}; ходов: {len(turns)} (с моделью {len(model_turns)}, локальных команд {len(local)}, ошибок цепочки {sum(1 for t in turns if 'failed' in t)})")
    res = {}
    for a, b in pairs:
        xs = [t[b] - t[a] for t in model_turns if a in t and b in t]
        res[(a, b)] = xs
        print(f"  {a} → {b}: n={len(xs)} медиана {fmt(statistics.median(xs) if xs else None)} p90 {fmt(pct(xs, 0.9))}")
    fa = res[("speech_end", "first_audio")]
    if fa:
        med, p90 = statistics.median(fa), pct(fa, 0.9)
        ok = med <= 8 and p90 <= 10
        print(f"AC-02: speech_end → first_audio медиана {med:.2f} с (≤ 8), p90 {p90:.2f} с (≤ 10) → {'PASS' if ok else 'FAIL'}")
    else:
        print("AC-02: NOT RUN (нет ходов с first_audio)")
    lx = [t["first_audio"] - t["stt_final"] for t in local if "first_audio" in t and "stt_final" in t]
    if lx:
        print(f"R-14 «повтори»/«медленнее»: stt_final → first_audio медиана {statistics.median(lx):.2f} с, макс {max(lx):.2f} с (≤ 0,3)")
    inter = [t for t in turns if "interrupt" in t]
    print(f"перебиваний: {len(inter)} ({', '.join(sorted(set(t['interrupt'] for t in inter)))})" if inter else "перебиваний: 0")
    if mem:
        print(f"память: пик {max(mem)} МБ, медиана {int(statistics.median(mem))} МБ, замеров {len(mem)} → AC-15 {'PASS' if max(mem) <= 1200 else 'FAIL'} (≤ 1200 МБ)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
