#!/usr/bin/env bash
# Репозиторий лежит на «Рабочем столе», который синхронизируется с iCloud Drive.
# Каталог сборки .build выносится в ~/Library/Caches (симлинк): иначе iCloud выгружает сотни мегабайт,
# а File Provider меняет файлы во время сборки («modified during the build»).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$HOME/Library/Caches/com.itmax04.lingo/build"
if [ ! -L "$ROOT/.build" ]; then
  mkdir -p "$CACHE"
  [ -d "$ROOT/.build" ] && rm -rf "$ROOT/.build"
  ln -s "$CACHE" "$ROOT/.build"
  echo "ensure-build-dir: .build -> $CACHE"
fi
