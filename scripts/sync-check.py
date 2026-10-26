#!/usr/bin/env python3
"""Sync folder check (AC-08, S-19, plan.md P-02/P-10).

    scripts/sync-check.py <folder> [--local <JournalStore base> ...] [--session <id> --expect N]

<folder> — the chosen sync folder (or its "Lingo" subfolder). All journals
Lingo/v1/devices/*/journal-*.jsonl are read. Checks:
  * duplicates: the same event id on different lines or in different files;
  * each device writes only to its own folder (the device field matches the folder name);
  * --session/--expect: number of messages in the session;
  * --local: the device's local base (devices/* + cache/*) contains every message of the folder (losses)
    and gives the same order (ts, device, seq) — R-37.
Exit code 0 — 0 losses and 0 duplicates. Message texts are not printed.
"""
import argparse, glob, json, os, sys


def read_dir(pattern):
    events, bad = [], 0
    for path in sorted(glob.glob(pattern)):
        with open(path, encoding="utf-8") as f:
            data = f.read()
        lines = data.split("\n")
        if lines and lines[-1] != "":
            lines = lines[:-1]  # a cut-off last line (R-39)
        for ln in lines:
            if not ln.strip():
                continue
            try:
                e = json.loads(ln)
                e["_file"] = path
                events.append(e)
            except json.JSONDecodeError:
                bad += 1
    return events, bad


def order_key(e):
    return (e["ts"], e["device"], e["seq"], e["id"])


def messages_by_session(events):
    seen, out = set(), {}
    for e in sorted(events, key=order_key):
        if e["id"] in seen:
            continue
        seen.add(e["id"])
        if e.get("type") == "message.created":
            out.setdefault(e.get("session", ""), []).append(e["id"])
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("--local", action="append", default=[])
    ap.add_argument("--session")
    ap.add_argument("--expect", type=int)
    a = ap.parse_args()

    root = a.folder.rstrip("/")
    if os.path.basename(root) != "Lingo":
        root = os.path.join(root, "Lingo")
    devices_dir = os.path.join(root, "v1", "devices")
    if not os.path.isdir(devices_dir):
        print(f"FAIL: no folder {devices_dir}")
        return 1

    events, bad = read_dir(os.path.join(devices_dir, "*", "journal-*.jsonl"))
    problems = 0
    ids = {}
    for e in events:
        ids.setdefault(e["id"], []).append(e)
    dups = {k: v for k, v in ids.items() if len(v) > 1}
    wrong_owner = [e for e in events if os.path.basename(os.path.dirname(e["_file"])) != e["device"]]
    per_dev = {}
    for e in events:
        per_dev[e["device"]] = per_dev.get(e["device"], 0) + 1
    msgs = messages_by_session(events)
    print(f"folder: {devices_dir}")
    print(f"devices: {', '.join(f'{d}={n}' for d, n in sorted(per_dev.items()))}; events={len(events)} corrupted_lines={bad}")
    print(f"duplicates: {len(dups)}")
    print(f"wrong_owner: {len(wrong_owner)}")
    problems += len(dups) + len(wrong_owner)
    for s, lst in sorted(msgs.items()):
        print(f"session {s}: {len(lst)} messages")
    if a.session is not None and a.expect is not None:
        n = len(msgs.get(a.session, []))
        ok = n == a.expect
        print(f"expect {a.session}={a.expect}: {'PASS' if ok else 'FAIL'} ({n})")
        problems += 0 if ok else 1

    for base in a.local:
        local, lbad = read_dir(os.path.join(base, "devices", "*", "journal-*.jsonl"))
        cache, cbad = read_dir(os.path.join(base, "cache", "*", "journal-*.jsonl"))
        lm = messages_by_session(local + cache)
        lost = extra = order = 0
        for s, lst in msgs.items():
            have = lm.get(s, [])
            lost += len(set(lst) - set(have))
            extra += len(set(have) - set(lst))
            common = [i for i in have if i in set(lst)]
            if common != [i for i in lst if i in set(have)]:
                order += 1
        ldups = sum(len(v) - len(set(v)) for v in lm.values())
        print(f"local {base}: lost={lost} not_in_folder={extra} order_mismatch_sessions={order} dup={ldups}")
        problems += lost + order + ldups

    print("RESULT: " + ("PASS (0 losses, 0 duplicates)" if problems == 0 else f"FAIL ({problems} problems)"))
    return 0 if problems == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
