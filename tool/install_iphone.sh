#!/usr/bin/env bash
# Isle → 연결된 iPhone에 빌드·설치 (Delete Fix 우회)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEVICE="${1:-${DEVICE_ID:-${DELETEFIX_DEVICE_ID:-}}}"
if [[ -z "$DEVICE" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    DEVICE="$(flutter devices --machine 2>/dev/null | python3 -c "
import json, sys
try:
    for d in json.load(sys.stdin):
        if d.get('platform') == 'ios' and d.get('isSupported'):
            print(d.get('id', ''))
            break
except Exception:
    pass
" 2>/dev/null || true)"
  fi
  if [[ -z "$DEVICE" ]]; then
    DEVICE="$(flutter devices 2>/dev/null | awk -F'•' '/ios/ {gsub(/^[ \t]+|[ \t]+$/, \"\", \$2); print \$2; exit}')"
  fi
fi
if [[ -z "$DEVICE" ]]; then
  echo "연결된 iPhone 없음. USB 연결 후:"
  echo "  flutter devices"
  echo "  $0 <device-id>"
  exit 1
fi

echo "▶ Isle iPhone 설치 · device=$DEVICE"

find "${PUB_CACHE:-$HOME/.pub-cache}/hosted/pub.dev" -name '*.deletefixbak.*' -print -delete 2>/dev/null || true

flutter pub get
echo "▌ flutter build ios --profile (Runner-Profile-Dev)"
flutter build ios --profile

APP=""
for candidate in \
  "$ROOT/build/ios/iphoneos/Runner.app" \
  "$ROOT/build/ios/Profile-iphoneos/Runner.app" \
  "$ROOT/build/ios/Release-iphoneos/Runner.app"
do
  if [[ -d "$candidate" ]]; then
    APP="$candidate"
    break
  fi
done

if [[ -z "$APP" ]]; then
  echo "FAIL: Runner.app 없음 (build/ios/Profile-iphoneos 확인)"
  exit 2
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist" 2>/dev/null || true)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist" 2>/dev/null || echo ?)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist" 2>/dev/null || echo ?)"
echo "▌ artifact: $APP"
echo "▌ bundle: $BUNDLE_ID · v${VERSION}+${BUILD}"

echo "▌ devicectl install…"
"$(dirname "$0")/devicectl_install.sh" "$DEVICE" "$APP"

echo "▌ launch…"
if xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE_ID"; then
  echo "OK: Isle 설치·실행 완료 — 홈 화면에서도 열 수 있어요."
else
  echo "▌ 설치는 완료 — 자동 실행만 실패. iPhone 홈에서 앱을 탭하세요."
fi
