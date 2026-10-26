#!/usr/bin/env bash
# Runs the evals (evals/README.md). Results go to evals/out/ (in .gitignore).
#   scripts/run-evals.sh commands | turn | audio | dialog | all
# audio: synthetic recordings (scripts/make-audio-fixtures.sh) through whisper; Apple Speech — from Lingo.app (needs permission).
# dialog: needs a key — run from the signed dist/Lingo.app (Keychain, D-11).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
"$ROOT/scripts/ensure-build-dir.sh"
WHAT="${1:-all}"
swift build -c release --product lingo-eval >/dev/null
EVAL="$(swift build -c release --show-bin-path)/lingo-eval"
MODELS="$HOME/Library/Application Support/Lingo/models"
rc=0
run() { echo "== $1"; shift; "$@" || rc=1; }

want() { [ "$WHAT" = all ] || [ "$WHAT" = "$1" ]; }
case "$WHAT" in commands|turn|audio|dialog|all) ;; *) echo "usage: scripts/run-evals.sh commands|turn|audio|dialog|all"; exit 2 ;; esac

if want commands; then run commands "$EVAL" commands; fi
if want turn; then run turn "$EVAL" turn; fi
if want audio; then
  [ -f evals/audio/manifest.json ] || scripts/make-audio-fixtures.sh
  "$EVAL" model-install --model ggml-large-v3-turbo-q5_0.bin >/dev/null
  run audio "$EVAL" stt --engine "whisper:$MODELS/ggml-large-v3-turbo-q5_0.bin@dual@512" --forced
fi
if want dialog; then
  if [ -x dist/Lingo.app/Contents/MacOS/Lingo ] && dist/Lingo.app/Contents/MacOS/Lingo --help-eval >/dev/null 2>&1; then
    run dialog dist/Lingo.app/Contents/MacOS/Lingo --eval-dialog "$ROOT/evals/dialog" "$ROOT/evals/out"
  else
    echo "== dialog: NOT RUN here (use dist/Lingo.app --eval-dialog, see evals/README.md)"
  fi
fi
exit $rc
