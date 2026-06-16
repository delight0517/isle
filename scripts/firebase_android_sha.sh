#!/usr/bin/env bash
# Firebase / Google Sign-In용 Android SHA-1·SHA-256 출력
set -euo pipefail

MODE="${1:-debug}"
KEYSTORE="${2:-}"
ALIAS="${3:-androiddebugkey}"
STORE_PASS="${4:-android}"
KEY_PASS="${5:-android}"

if [[ "$MODE" == "debug" ]]; then
  KEYSTORE="${KEYSTORE:-$HOME/.android/debug.keystore}"
  echo "=== Debug keystore: $KEYSTORE ==="
elif [[ "$MODE" == "release" ]]; then
  if [[ -z "$KEYSTORE" ]]; then
    echo "Usage: $0 release /path/to.keystore alias [storepass] [keypass]"
    exit 1
  fi
  echo "=== Release keystore: $KEYSTORE (alias=$ALIAS) ==="
else
  echo "Usage: $0 debug | $0 release /path/to.keystore alias"
  exit 1
fi

if [[ ! -f "$KEYSTORE" ]]; then
  echo "Keystore not found: $KEYSTORE"
  echo "Create debug keystore: flutter run once, or:"
  echo "  keytool -genkey -v -keystore \"\$HOME/.android/debug.keystore\" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname CN=Android Debug,O=Android,C=US"
  exit 1
fi

keytool -list -v -keystore "$KEYSTORE" -alias "$ALIAS" -storepass "$STORE_PASS" -keypass "$KEY_PASS" 2>/dev/null | grep -E "SHA1:|SHA256:" || {
  echo "keytool failed — check alias/password"
  exit 1
}

echo ""
echo "Paste SHA-1 and SHA-256 into Firebase Console → Project settings → Your Android app."
