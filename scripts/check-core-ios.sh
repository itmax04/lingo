#!/usr/bin/env bash
# LINGO-02 readiness check: LingoCore builds for iOS (A-6, plan.md "Checks").
# Builds only the LingoCore target for arm64-apple-ios17.0 with the iOS SDK from Xcode, without signing and without an iOS app.
# Why not xcodebuild: Xcode 26.3 on this Mac does not have the iOS 26.2 platform component installed
# ("iOS 26.2 is not installed", Xcode → Settings → Components), but the iphoneos SDK is present. SwiftPM builds with it directly
# (decision D-03 in handoff.md). If the platform is installed, xcodebuild is run as well.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
SCRATCH="$HOME/Library/Caches/com.itmax04.lingo/ios-build"
echo "==> swift build --target LingoCore --triple arm64-apple-ios17.0 (SDK $(xcrun --sdk iphoneos --show-sdk-version))"
# pipefail (set -o above): the exit code of swift build is not lost in the pipeline with tail.
if ! swift build --target LingoCore --triple arm64-apple-ios17.0 --sdk "$SDK" --scratch-path "$SCRATCH" 2>&1 | tail -20; then
  echo "check-core-ios: FAIL"; exit 1
fi
OBJ="$(find "$SCRATCH/arm64-apple-ios/debug/LingoCore.build" -name '*.o' | head -1)"
[ -n "$OBJ" ] || { echo "check-core-ios: FAIL (no object files)"; exit 1; }
PLATFORM="$(otool -l "$OBJ" | awk '/LC_BUILD_VERSION/{f=1} f&&/platform/{print $2; exit}')"
[ "$PLATFORM" = "2" ] || { echo "check-core-ios: FAIL (platform=$PLATFORM, expected 2 = iOS)"; exit 1; }
echo "objects: $(find "$SCRATCH/arm64-apple-ios/debug/LingoCore.build" -name '*.o' | wc -l | tr -d ' '), LC_BUILD_VERSION platform=2 (iOS)"

if xcodebuild -showdestinations -scheme LingoCore 2>/dev/null | grep -q "platform:iOS, id:dvtdevice-DVTiPhonePlaceholder-iphoneos:placeholder, name:Any iOS Device }"; then
  echo "==> xcodebuild generic/platform=iOS"
  xcodebuild -scheme LingoCore -destination 'generic/platform=iOS' -derivedDataPath "$HOME/Library/Caches/com.itmax04.lingo/ios-derived" \
    CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|^\*\* BUILD" | head -20
fi
echo "check-core-ios: PASS"
