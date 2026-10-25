#!/usr/bin/env bash
# Сборка dist/Lingo.app (ADR-0001 п. 2–3, plan.md P-01). По образцу Interview Copilot (scripts/build-app.sh, коммит cf0e764).
# Подпись — постоянным локальным самоподписанным сертификатом (A-5), чтобы разрешения macOS (TCC) не сбрасывались при пересборке.
# Порядок поиска: $CODESIGN_IDENTITY, «Lingo Dev», «InterviewCopilot».
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
error: сертификат подписи не найден (искали: ${CANDIDATES[*]}).
Создайте его по инструкции точки H-0 (docs/changes/LINGO-01/plan.md):
«Связка ключей» → меню «Связка ключей» → «Ассистент сертификации» → «Создать сертификат…»,
имя «Lingo Dev», тип удостоверения «Самоподписанный корневой», тип сертификата «Подписание кода».
MSG
  exit 1
fi

DIST="$ROOT/dist"
FINAL_APP="$DIST/$APP_NAME.app"
# Бандл собирается и подписывается во временной папке вне iCloud Drive: «Рабочий стол» синхронизируется,
# File Provider добавляет расширенные атрибуты, и codesign падает («detritus not allowed»).
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/lingo-build.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/$APP_NAME.app"

echo "==> swift build -c release"
swift build -c release --product "$APP_NAME"
BIN="$(swift build -c release --show-bin-path)/$APP_NAME"

echo "==> упаковка"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
# Версия сборки (ревью F-05): номер сборки — число коммитов, ревизия — commit (+ «-dirty», если есть незакоммиченные изменения).
GIT_REV="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
[ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ] && GIT_REV="$GIT_REV-dirty"
BUILD_NO="$(git rev-list --count HEAD 2>/dev/null || echo 0)"
/usr/libexec/PlistBuddy -c "Add :LingoGitRevision string $GIT_REV" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NO" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LingoBuildDate string $(date -u +%Y-%m-%dT%H:%M:%SZ)" "$APP/Contents/Info.plist"
find "$ROOT/Resources" -maxdepth 1 -type f ! -name Info.plist -exec cp {} "$APP/Contents/Resources/" \;

# Иконка рисуется самим приложением, затем iconutil собирает .icns.
"$BIN" --export-iconset "$STAGE/AppIcon.iconset"
iconutil -c icns "$STAGE/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

# Нативные библиотеки (whisper XCFramework), если есть, кладутся в Frameworks.
BIN_DIR="$(dirname "$BIN")"
if compgen -G "$BIN_DIR/*.framework" > /dev/null; then
  mkdir -p "$APP/Contents/Frameworks"
  cp -R "$BIN_DIR"/*.framework "$APP/Contents/Frameworks/"
fi

echo "==> подпись «${IDENTITY}»"
xattr -cr "$APP"
if [ -d "$APP/Contents/Frameworks" ]; then
  find "$APP/Contents/Frameworks" -maxdepth 1 -name "*.framework" -exec \
    codesign --force --sign "$IDENTITY" --timestamp=none {} \;
fi
codesign --force --sign "$IDENTITY" --timestamp=none --identifier "$BUNDLE_ID" "$APP"
codesign --verify --strict "$APP"

mkdir -p "$DIST"
rm -rf "$FINAL_APP"
# ditto без расширенных атрибутов: подпись остаётся целой и в папке под iCloud.
ditto --noextattr --noqtn "$APP" "$FINAL_APP"
echo "==> $FINAL_APP (build $BUILD_NO, $GIT_REV)"
codesign -dv "$FINAL_APP" 2>&1 | grep -E "Identifier|Authority|Signature" || true
