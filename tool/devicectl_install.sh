#!/usr/bin/env bash
# devicectl install — 5분 멈춤 감지 (Delete Fix / agent_build 공용)
# Usage: devicectl_install.sh <device-udid> <Runner.app path>
set -euo pipefail

DEVICE="${1:?device required}"
APP="${2:?Runner.app path required}"
TIMEOUT_SEC="${ISLE_INSTALL_TIMEOUT_SEC:-300}"
LOG_TAG="[devicectl_install]"

log() { echo "$LOG_TAG $*"; }

if [[ ! -d "$APP" ]]; then
  log "ERROR: not a directory: $APP"
  exit 2
fi

run_install() {
  xcrun devicectl device install app --device "$DEVICE" "$APP"
}

log "install → $DEVICE (${TIMEOUT_SEC}s cap)"
if command -v timeout >/dev/null 2>&1; then
  timeout "$TIMEOUT_SEC" run_install && exit 0
  ec=$?
  if [[ "$ec" -eq 124 ]]; then
    log "ERROR: install hung >${TIMEOUT_SEC}s — USB·신뢰·잠금·용량 확인"
    exit 124
  fi
  exit "$ec"
fi
if command -v gtimeout >/dev/null 2>&1; then
  gtimeout "$TIMEOUT_SEC" run_install && exit 0
  ec=$?
  [[ "$ec" -eq 124 ]] && log "ERROR: install hung >${TIMEOUT_SEC}s"
  exit "$ec"
fi

run_install
