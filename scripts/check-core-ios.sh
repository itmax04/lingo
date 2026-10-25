#!/usr/bin/env bash
# Проверка готовности к LINGO-02: LingoCore собирается для iOS (A-6, plan.md «Проверки»).
# Сборка только цели LingoCore под arm64-apple-ios17.0 с iOS SDK из Xcode, без подписи и без iOS-приложения.
# Почему не xcodebuild: в Xcode 26.3 на этом Mac не установлен компонент платформы iOS 26.2
# («iOS 26.2 is not installed», Xcode → Settings → Components), а SDK iphoneos есть. SwiftPM собирает с ним напрямую
# (решение D-03 в handoff.md). Если платформа установлена, дополнительно запускается xcodebuild.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
SCRATCH="$HOME/Library/Caches/com.itmax04.lingo/ios-build"
echo "==> swift build --target LingoCore --triple arm64-apple-ios17.0 (SDK $(xcrun --sdk iphoneos --show-sdk-version))"
# pipefail (set -o выше): код возврата swift build не теряется в конвейере с tail.
if ! swift build --target LingoCore --triple arm64-apple-ios17.0 --sdk "$SDK" --scratch-path "$SCRATCH" 2>&1 | tail -20; then
  echo "check-core-ios: FAIL"; exit 1
fi
OBJ="$(find "$SCRATCH/arm64-apple-ios/debug/LingoCore.build" -name '*.o' | head -1)"
[ -n "$OBJ" ] || { echo "check-core-ios: FAIL (нет объектных файлов)"; exit 1; }
PLATFORM="$(otool -l "$OBJ" | awk '/LC_BUILD_VERSION/{f=1} f&&/platform/{print $2; exit}')"
[ "$PLATFORM" = "2" ] || { echo "check-core-ios: FAIL (platform=$PLATFORM, ожидалось 2 = iOS)"; exit 1; }
echo "objects: $(find "$SCRATCH/arm64-apple-ios/debug/LingoCore.build" -name '*.o' | wc -l | tr -d ' '), LC_BUILD_VERSION platform=2 (iOS)"

if xcodebuild -showdestinations -scheme LingoCore 2>/dev/null | grep -q "platform:iOS, id:dvtdevice-DVTiPhonePlaceholder-iphoneos:placeholder, name:Any iOS Device }"; then
  echo "==> xcodebuild generic/platform=iOS"
  xcodebuild -scheme LingoCore -destination 'generic/platform=iOS' -derivedDataPath "$HOME/Library/Caches/com.itmax04.lingo/ios-derived" \
    CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|^\*\* BUILD" | head -20
fi
echo "check-core-ios: PASS"
