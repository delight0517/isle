#!/usr/bin/env bash
# Isle — iPhone 실기기 Profile 설치 (Delete Fix / devicectl / 홈 화면 실행용)
# Debug는 devicectl 단독 실행 시 SIGSEGV — Profile만 단독 실행 가능 (Flutter iOS 14+)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== Isle Profile build (com.isle.app.isle.dev) =="
flutter pub get
flutter build ios --profile

APP="build/ios/iphoneos/Runner.app"
if [[ ! -d "$APP" ]]; then
  echo "Missing $APP"
  exit 1
fi

DEVICE="${1:-}"
if [[ -z "$DEVICE" ]]; then
  echo "Connected devices:"
  flutter devices
  echo ""
  echo "Usage: ./tool/ios_device_profile.sh <device-id>"
  echo "  e.g. ./tool/ios_device_profile.sh 00008120-000C0DA902D8C01E"
  exit 0
fi

echo "Installing to $DEVICE ..."
xcrun devicectl device install app --device "$DEVICE" "$APP"

echo "Launching com.isle.app.isle.dev (Profile) ..."
xcrun devicectl device process launch --device "$DEVICE" com.isle.app.isle.dev

echo "Done. For hot reload use: flutter run --profile -d $DEVICE"
