#!/usr/bin/env bash
# Прогон evals (evals/README.md). Результаты — evals/out/ (в .gitignore).
#   scripts/run-evals.sh commands | turn | audio | dialog | all
# audio: синтетические записи (scripts/make-audio-fixtures.sh) через whisper; Apple Speech — из Lingo.app (нужно разрешение).
# dialog: нужен ключ — запускается из подписанного dist/Lingo.app (Связка ключей, D-11).
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
    echo "== dialog: NOT RUN (появится в P-05: dist/Lingo.app --eval-dialog)"
  fi
fi
exit $rc
