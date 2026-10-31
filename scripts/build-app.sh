#!/usr/bin/env bash
# Builds dist/Lingo.app (ADR-0001 §2–3, plan.md P-01). Modelled on Interview Copilot (scripts/build-app.sh, commit cf0e764).
# Signed with a persistent local self-signed certificate (A-5) so macOS permissions (TCC) survive rebuilds.
# Search order: $CODESIGN_IDENTITY, "Lingo Dev", "InterviewCopilot".
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
"$ROOT/scripts/ensure-build-dir.sh"

APP_NAME="Lingo"
BUNDLE_ID="com.itmax04.lingo.mac"
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  CANDIDATES=("$CODESIGN_IDENTITY")
else
  CANDIDATES=("Lingo Dev" "InterviewCopilot")
fi
IDENTITY=""
for c in "${CANDIDATES[@]}"; do
  if security find-identity -p codesigning | grep -q "\"$c\""; then IDENTITY="$c"; break; fi
done
if [ -z "$IDENTITY" ]; then
  cat >&2 <<MSG
error: no code-signing certificate found (searched: ${CANDIDATES[*]}).
Create one as described in owner checkpoint H-0 (docs/changes/LINGO-01/plan.md):
Keychain Access → menu "Keychain Access" → "Certificate Assistant" → "Create a Certificate…",
name "Lingo Dev", identity type "Self-Signed Root", certificate type "Code Signing".
MSG
  exit 1
fi

DIST="$ROOT/dist"
FINAL_APP="$DIST/$APP_NAME.app"
# The bundle is built and signed in a temporary folder outside iCloud Drive: the Desktop is synced,
# File Provider adds extended attributes, and codesign fails ("detritus not allowed").
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/lingo-build.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/$APP_NAME.app"

echo "==> swift build -c release"
swift build -c release --product "$APP_NAME"
BIN="$(swift build -c release --show-bin-path)/$APP_NAME"

echo "==> packaging"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
# Build version (review F-05): the build number is the commit count, the revision is the commit (+ "-dirty" with uncommitted changes).
GIT_REV="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
[ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ] && GIT_REV="$GIT_REV-dirty"
BUILD_NO="$(git rev-list --count HEAD 2>/dev/null || echo 0)"
/usr/libexec/PlistBuddy -c "Add :LingoGitRevision string $GIT_REV" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NO" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LingoBuildDate string $(date -u +%Y-%m-%dT%H:%M:%SZ)" "$APP/Contents/Info.plist"
find "$ROOT/Resources" -maxdepth 1 -type f ! -name Info.plist -exec cp {} "$APP/Contents/Resources/" \;

xcrun xcstringstool compile "$ROOT/Resources/Localizable.xcstrings" --output-directory "$APP/Contents/Resources"
if [ -f "$ROOT/Resources/InfoPlist.xcstrings" ]; then
  xcrun xcstringstool compile "$ROOT/Resources/InfoPlist.xcstrings" --output-directory "$APP/Contents/Resources"
fi
# The icon is rendered at native sizes, then iconutil builds the .icns.
"$BIN" --export-iconset "$STAGE/AppIcon.iconset" --icon-source "$ROOT/Resources/AppIcon.png"
iconutil -c icns "$STAGE/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

# Native libraries (the whisper XCFramework), if any, go into Frameworks.
BIN_DIR="$(dirname "$BIN")"
if compgen -G "$BIN_DIR/*.framework" > /dev/null; then
  mkdir -p "$APP/Contents/Frameworks"
  cp -R "$BIN_DIR"/*.framework "$APP/Contents/Frameworks/"
fi

echo "==> signing with \"${IDENTITY}\""
xattr -cr "$APP"
if [ -d "$APP/Contents/Frameworks" ]; then
  find "$APP/Contents/Frameworks" -maxdepth 1 -name "*.framework" -exec \
    codesign --force --sign "$IDENTITY" --timestamp=none {} \;
fi
codesign --force --sign "$IDENTITY" --timestamp=none --identifier "$BUNDLE_ID" "$APP"
codesign --verify --strict "$APP"

mkdir -p "$DIST"
rm -rf "$FINAL_APP"
# ditto without extended attributes: the signature stays intact even in a folder under iCloud.
ditto --noextattr --noqtn "$APP" "$FINAL_APP"
echo "==> $FINAL_APP (build $BUILD_NO, $GIT_REV)"
codesign -dv "$FINAL_APP" 2>&1 | grep -E "Identifier|Authority|Signature" || true
