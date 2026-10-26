#!/usr/bin/env bash
# The repository lives on the Desktop, which is synced with iCloud Drive.
# The .build directory is moved to ~/Library/Caches (a symlink): otherwise iCloud uploads hundreds of megabytes,
# and File Provider changes files during the build ("modified during the build").
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$HOME/Library/Caches/com.itmax04.lingo/build"
if [ ! -L "$ROOT/.build" ]; then
  mkdir -p "$CACHE"
  [ -d "$ROOT/.build" ] && rm -rf "$ROOT/.build"
  ln -s "$CACHE" "$ROOT/.build"
  echo "ensure-build-dir: .build -> $CACHE"
fi
