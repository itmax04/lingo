#!/usr/bin/env bash
# Keep a separate cache for every checkout; compiler module caches contain absolute paths.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
MAC="$ROOT/apps/mac"
CHECKOUT_ID="$(printf '%s' "$ROOT" | shasum -a 256 | cut -c1-16)"
CACHE="$HOME/Library/Caches/com.itmax04.lingo/checkouts/$CHECKOUT_ID"
if [ -L "$MAC/.build" ]; then exit 0; fi
mkdir -p "$(dirname "$CACHE")"
if [ -d "$MAC/.build" ]; then
  # Existing local caches remain usable; never delete a checkout's build directory.
  exit 0
fi
mkdir -p "$CACHE"
ln -s "$CACHE" "$MAC/.build"
echo "ensure-build-dir: isolated checkout cache $CHECKOUT_ID"
