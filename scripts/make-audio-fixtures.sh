#!/usr/bin/env bash
# Synthetic recordings for the `audio` eval (evals/README.md): macOS `say` → 16 kHz mono WAV; mixed ones are joined with ffmpeg.
# Reads evals/audio/phrases.yaml, writes evals/audio/{en,de,ru,mixed}/<id>.wav and manifest.json. Audio is not stored in Git.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/evals/audio"
python3 -I - <<'PY'
import json, os, subprocess, tempfile, re
# A tiny parser for our YAML (only the phrases.yaml format), so Python needs no dependencies.
cur = None
data = {}
for line in open("phrases.yaml", encoding="utf-8"):
    s = line.rstrip("\n")
    if not s.strip() or s.lstrip().startswith("#"):
        continue
    if re.match(r"^[a-z]+:\s*$", s):
        cur = s[:-1].strip(); data[cur] = []; continue
    m = re.match(r"^\s*-\s*\{(.*)\}\s*$", s)
    if m and cur:
        body = m.group(1)
        item = {}
        pm = re.search(r"parts:\s*\[(.*)\]\s*$", body)
        if pm:
            parts = re.findall(r'\[(\w+),\s*"([^"]*)"\]', pm.group(1))
            item["parts"] = [list(p) for p in parts]
            body = body[:pm.start()]
        for k, q in re.findall(r'(\w+):\s*("[^"]*"|\w+)', body):
            item[k] = q.strip('"')
        data[cur].append(item)

def say(voice, text, out):
    aiff = out + ".aiff"
    subprocess.run(["say", "-v", voice, "-o", aiff, text], check=True)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", aiff, "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le", out], check=True)
    os.remove(aiff)

manifest = []
for set_name, items in data.items():
    os.makedirs(set_name, exist_ok=True)
    for it in items:
        out = os.path.join(set_name, it["id"] + ".wav")
        if "parts" in it:
            tmp = tempfile.mkdtemp()
            files = []
            for i, (voice, text) in enumerate(it["parts"]):
                f = os.path.join(tmp, f"{i}.wav"); say(voice, text, f); files.append(f)
            lst = os.path.join(tmp, "list.txt")
            with open(lst, "w") as fh:
                for f in files: fh.write(f"file '{f}'\n")
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", out], check=True)
            ref = " ".join(t for _, t in it["parts"])
            manifest.append({"set": set_name, "id": it["id"], "file": out, "ref": ref, "study": it["study"], "lang": "mixed"})
        else:
            if not os.path.exists(out):
                say(it["voice"], it["text"], out)
            study = it.get("study", set_name)
            manifest.append({"set": set_name, "id": it["id"], "file": out, "ref": it["text"], "study": study, "lang": set_name})
json.dump(manifest, open("manifest.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"make-audio-fixtures: {len(manifest)} files, manifest.json")
PY
