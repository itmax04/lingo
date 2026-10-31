#!/usr/bin/env bash
# Render only synthetic presentation fixtures; never starts journal observers, voice or provider calls.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
MAC="$ROOT/apps/mac"
APP="$ROOT/dist/Lingo.app/Contents/MacOS/Lingo"
OUTPUT="${1:-$ROOT/design/redesign-2026/10-comparison/implementation}"
[ -x "$APP" ] || { echo 'Build the signed app with scripts/build-app.sh first.' >&2; exit 1; }
mkdir -p "$OUTPUT"
for THEME in dark light; do
  "$APP" --ui-snapshot "$OUTPUT/mac-conversation-speaking-$THEME-1280x800.png" \
    --ui-theme "$THEME" --ui-language ru --ui-all yes
done
"$APP" --ui-snapshot "$OUTPUT/mac-english-dark-1280x800.png" --ui-theme dark --ui-language en
"$APP" --ui-click-test
