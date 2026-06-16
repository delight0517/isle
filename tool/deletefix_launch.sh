#!/usr/bin/env bash
# Delete Fix entry point — Flutter iOS standalone launch (Profile, never Debug+devicectl)
# Blueprint: isle/blueprints/DELETE_FIX_FLUTTER_IOS_LAUNCH.md
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEVICE="${1:-}"
LOG_TAG="[deletefix_launch]"

log() { echo "$LOG_TAG $*"; }

# Delete Fix 백업(.deletefixbak.*)이 pod 소스에 섞이면 arm64 빌드 실패
purge_deletefix_pub_cache_backups() {
  local cache="${PUB_CACHE:-$HOME/.pub-cache}/hosted/pub.dev"
  [[ -d "$cache" ]] || return 0
  find "$cache" -name '*.deletefixbak.*' -print -delete 2>/dev/null || true
}

if [[ -z "$DEVICE" ]]; then
  log "No device id. Connected devices:"
  flutter devices || true
  echo ""
  echo "Usage: $0 <device-udid>"
  echo "Example: $0 FF688590-6923-5264-8C92-DEA3F99775A5"
  exit 1
fi

if [[ ! -f pubspec.yaml ]] || [[ ! -d ios/Runner ]]; then
  log "ERROR: Not a Flutter iOS project (expected pubspec.yaml + ios/Runner)"
  exit 2
fi

log "Flutter pub get"
purge_deletefix_pub_cache_backups
flutter pub get

log "Profile build (standalone-safe; Debug+devicectl crashes with SIGSEGV)"
flutter build ios --profile

# Newer Flutter/Xcode no longer create the build/ios/iphoneos symlink reliably.
# Resolve the freshly built artifact directly from the per-configuration directory.
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
  log "ERROR: Runner.app not found under build/ios/{iphoneos,Profile-iphoneos,Release-iphoneos}"
  exit 3
fi
log "Artifact: $APP"

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist" 2>/dev/null || true)"
if [[ -z "$BUNDLE_ID" ]]; then
  log "ERROR: Could not read CFBundleIdentifier from $APP/Info.plist"
  exit 4
fi
log "Bundle id: $BUNDLE_ID"

log "Install → $DEVICE"
xcrun devicectl device install app --device "$DEVICE" "$APP"

log "Launch $BUNDLE_ID (console attached until app exits)"
exec xcrun devicectl device process launch --console --device "$DEVICE" "$BUNDLE_ID"
