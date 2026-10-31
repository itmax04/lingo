#!/usr/bin/env bash
# Runs the evals (evals/README.md). Results go to packages/contracts/evals/out/ (in .gitignore).
#   apps/mac/scripts/run-evals.sh commands | turn | audio | dialog | all
# audio: synthetic recordings (scripts/make-audio-fixtures.sh) through whisper; Apple Speech — from Lingo.app (needs permission).
# dialog: needs a key — run from the signed dist/Lingo.app (Keychain, D-11).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
MAC="$ROOT/apps/mac"
EVALS="$ROOT/packages/contracts/evals"
cd "$MAC"
"$MAC/scripts/ensure-build-dir.sh"
WHAT="${1:-all}"
swift build -c release --product lingo-eval >/dev/null
EVAL="$(swift build -c release --show-bin-path)/lingo-eval"
cd "$ROOT"  # lingo-eval default paths (packages/contracts/evals/...) are relative to the repository root
MODELS="$HOME/Library/Application Support/Lingo/models"
rc=0
run() { echo "== $1"; shift; "$@" || rc=1; }

want() { [ "$WHAT" = all ] || [ "$WHAT" = "$1" ]; }
case "$WHAT" in commands|turn|audio|dialog|all) ;; *) echo "usage: apps/mac/scripts/run-evals.sh commands|turn|audio|dialog|all"; exit 2 ;; esac

if want commands; then run commands "$EVAL" commands; fi
if want turn; then run turn "$EVAL" turn; fi
if want audio; then
  [ -f "$EVALS/audio/manifest.json" ] || "$MAC/scripts/make-audio-fixtures.sh"
  "$EVAL" model-install --model ggml-large-v3-turbo-q5_0.bin >/dev/null
  run audio "$EVAL" stt --engine "whisper:$MODELS/ggml-large-v3-turbo-q5_0.bin@dual@512" --forced
fi
if want dialog; then
  APP="$ROOT/dist/Lingo.app/Contents/MacOS/Lingo"
  if [ -x "$APP" ] && "$APP" --help-eval >/dev/null 2>&1; then
    run dialog "$APP" --eval-dialog "$EVALS/dialog" "$EVALS/out"
  else
    echo "== dialog: NOT RUN here (use dist/Lingo.app --eval-dialog, see evals/README.md)"
  fi
fi
exit $rc
